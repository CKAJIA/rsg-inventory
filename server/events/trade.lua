local RSGCore = exports['rsg-core']:GetCoreObject()
local config    = require 'shared.config'
Trades = Trades or {}
local pendingRequests = {}
local returnEscrow

local function getCharName(source)
    local player = RSGCore.Functions.GetPlayer(source)
    if not player then return GetPlayerName(source) end
    local char = player.PlayerData.charinfo
    if char and char.firstname then
        return char.firstname .. ' ' .. char.lastname
    end
    return GetPlayerName(source)
end

-- Ограничивает частые повторные действия с трейдом.
local tradeCooldowns = {}
local function isOnCooldown(src)
    local now = GetGameTimer()
    if tradeCooldowns[src] and now - tradeCooldowns[src] < 200 then return true end
    tradeCooldowns[src] = now
    return false
end

-- Проверяет участника и citizenid: новый персонаж с прежним source не получит чужие предметы.
local function ownsTrade(trade, src)
    local side = trade.initiator == src and 'initiator' or (trade.target == src and 'target' or nil)
    if not side then return false end
    local player = RSGCore.Functions.GetPlayer(src)
    local expected = trade.ownerCitizenIds and trade.ownerCitizenIds[side]
    return player and (not expected or player.PlayerData.citizenid == expected)
end

-- Планирует приём целых предложений обеими сторонами без реальной выдачи.
-- Исходящие предметы уже находятся в escrow; проверяется итоговый вес и слоты.
-- Возвращает данные для формы и два готовых плана для завершения обмена.
function Inventory.GetTradeCapacity(trade)
    if not ownsTrade(trade, trade.initiator) or not ownsTrade(trade, trade.target) then
        return {initiatorCanReceive = false, targetCanReceive = false,
            initiatorMessage = locale('error.trade_recipient_full'), targetMessage = locale('error.trade_recipient_full')}
    end
    local first, firstReason = Inventory.PlanIncomingItems(trade.initiator, trade.targetItems)
    local second, secondReason = Inventory.PlanIncomingItems(trade.target, trade.initiatorItems)
    local canFirst, canSecond = first ~= nil, second ~= nil
    local capacity = {
        initiatorCanReceive = canFirst, targetCanReceive = canSecond,
        initiatorReason = firstReason, targetReason = secondReason,
        initiatorMessage = not canSecond and locale('error.trade_recipient_full') or (not canFirst and locale('error.trade_your_full') or ''),
        targetMessage = not canFirst and locale('error.trade_recipient_full') or (not canSecond and locale('error.trade_your_full') or '')
    }
    return capacity, first, second
end

-- Добавляет вместимость в сообщение формы и сбрасывает согласие при переполнении.
-- Ранее нажатое «Принять» не должно подтверждать уже недопустимое предложение.
local function addCapacity(trade, data)
    data.capacity = Inventory.GetTradeCapacity(trade)
    trade.capacity = data.capacity
    if not data.capacity.initiatorCanReceive or not data.capacity.targetCanReceive then
        trade.initiatorAccepted, trade.targetAccepted = false, false
        data.initiatorAccepted, data.targetAccepted = false, false
    end
    return data
end

-- Отправляет участникам одну актуальную версию предложений и причин блокировки.
local function publishTrade(trade)
    local data = addCapacity(trade, {
        id = trade.id, initiator = trade.initiator,
        initiatorItems = trade.initiatorItems, targetItems = trade.targetItems,
        initiatorAccepted = trade.initiatorAccepted, targetAccepted = trade.targetAccepted
    })
    TriggerClientEvent('rsg-inventory:client:updateTrade', trade.initiator, data)
    TriggerClientEvent('rsg-inventory:client:updateTrade', trade.target, data)
end

local pendingCapacityChecks = {}
-- Пересчитывает открытые трейды только при изменении инвентаря участника.
-- Несколько событий одного действия объединяются в один отложенный пересчёт; постоянного цикла нет.
local function queueCapacityCheck(src)
    if pendingCapacityChecks[src] then return end
    pendingCapacityChecks[src] = true
    SetTimeout(0, function()
        pendingCapacityChecks[src] = nil
        for _, trade in pairs(Trades) do
            if not trade.executing and (trade.initiator == src or trade.target == src) then publishTrade(trade) end
        end
    end)
end
AddEventHandler('rsg-inventory:server:itemChanged', queueCapacityCheck)
AddEventHandler('rsg-inventory:server:inventoryChanged', queueCapacityCheck)

-- Возвращает весь tradeItem обратно его владельцу.
-- Сначала возвращает строго в инвентарь, а при переполнении явно создаёт одну сумку.
-- При полном отказе возвращает false: запись escrow сохраняется для повторной попытки.
local function returnTradeItemToOwner(ownerId, tradeItem, reason)
    if not tradeItem or not tradeItem.name or not tradeItem.amount or tradeItem.amount <= 0 then
        return true
    end

    local ok = Inventory.AddItemStrict(ownerId, tradeItem.name, tradeItem.amount, false, tradeItem.info, reason)
    if not ok and RSGCore.Functions.GetPlayer(ownerId) then
        ok = Inventory.ForceDropItem(ownerId, tradeItem.name, tradeItem.amount, tradeItem.info, reason)
    end
    if not ok then
        print(('[TRADE][RETURN][FAIL] owner=%s item=%s amount=%s reason=%s')
            :format(ownerId, tradeItem.name, tradeItem.amount, reason))
        return false
    end

    return true
end

--Инициализация трейда
RegisterNetEvent('rsg-inventory:server:initiateTrade', function(targetId)
    local src = source
    targetId = Inventory.ValidAmount(targetId)
    if not targetId or targetId == src then return end
    if isOnCooldown(src) then return end

    local player = RSGCore.Functions.GetPlayer(src)
    if not player then return end
    if player.PlayerData.metadata.isdead or player.PlayerData.metadata.inlaststand or player.PlayerData.metadata.ishandcuffed then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('error.error'), description = locale('error.error'), type = 'error', duration = 5000 })
        return
    end

    local Target = RSGCore.Functions.GetPlayer(targetId)
    if not Target then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('error.error'), description = locale('error.no_player_nearby'), type = 'error', duration = 5000 })
        return
    end
    if Target.PlayerData.metadata.isdead or Target.PlayerData.metadata.inlaststand or Target.PlayerData.metadata.ishandcuffed then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('error.error'), description = locale('error.error'), type = 'error', duration = 5000 })
        return
    end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(targetId))) > Inventory.MAX_DIST then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('error.error'), description = locale('error.player_too_far'), type = 'error', duration = 5000 })
        return
    end

    for _, trade in pairs(Trades) do
        if trade.initiator == src or trade.target == src then
            TriggerClientEvent('ox_lib:notify', src, { title = locale('error.error'), description = locale('info.already_trade'), type = 'error', duration = 5000 })
            return
        end
        if trade.initiator == targetId or trade.target == targetId then
            TriggerClientEvent('ox_lib:notify', src, { title = locale('error.error'), description = locale('info.other_already_trade'), type = 'error', duration = 5000 })
            return
        end
    end

	--Инициализируем таймер для окна приглашения
    local requestId = ('%s:%s:%s'):format(src, targetId, os.clock())
	pendingRequests[src] = {
		targetId = targetId,
		requestId = requestId
	}
	SetTimeout(30000, function()
		local req = pendingRequests[src]
		if req and req.targetId == targetId and req.requestId == requestId then
			pendingRequests[src] = nil
			
			TriggerClientEvent('rsg-inventory:client:tradeRequestCancelled', src)
			TriggerClientEvent('rsg-inventory:client:tradeRequestCancelled', targetId)
	
			TriggerClientEvent('ox_lib:notify', src, {title = locale('ui.trade'), description = locale('error.trade_request_expired'), type = 'error', duration = 5000})
		end
	end)

    TriggerClientEvent('rsg-inventory:client:tradeRequest', targetId, src, getCharName(src))
    TriggerClientEvent('ox_lib:notify', src, { title = locale('ui.trade'), description = locale('error.trade_sent_to') .. getCharName(targetId), type = 'info', duration = 5000 })
end)

--Принятие трейда
RegisterNetEvent('rsg-inventory:server:acceptTradeRequest', function(initiatorId)
    local src = source
    if isOnCooldown(src) then return end
    local req = pendingRequests[initiatorId]
	if not req or req.targetId ~= src then return end

    local player = RSGCore.Functions.GetPlayer(src)
    local initiator = RSGCore.Functions.GetPlayer(initiatorId)
    if not player or not initiator then return end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(initiatorId))) > Inventory.MAX_DIST then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('error.error'), description = locale('error.player_too_far'), type = 'error', duration = 5000 })
        pendingRequests[initiatorId] = nil
        return
    end

    local tradeId = 'trade-' .. initiatorId .. '-' .. src
    Trades[tradeId] = {
        id = tradeId,
        initiator = initiatorId,
        target = src,
        initiatorItems = {},
        targetItems = {},
        initiatorAccepted = false,
        targetAccepted = false,
        nextSlot = { initiator = 1, target = 1 },
        executing = false,
        ownerCitizenIds = {initiator = initiator.PlayerData.citizenid, target = player.PlayerData.citizenid}
    }

    pendingRequests[initiatorId] = nil

    local initiatorItems = initiator.PlayerData.items
    local targetItems = player.PlayerData.items
    
    TriggerClientEvent('rsg-inventory:client:openTrade', initiatorId, tradeId, src, getCharName(src), initiatorItems, player.PlayerData)
    TriggerClientEvent('rsg-inventory:client:openTrade', src, tradeId, initiatorId, getCharName(initiatorId), targetItems, initiator.PlayerData)
    publishTrade(Trades[tradeId])
end)

--Отмена трейда
RegisterNetEvent('rsg-inventory:server:declineTradeRequest', function(initiatorId)
    local src = source
    local req = pendingRequests[initiatorId]
	
	if req and req.targetId == src then
        TriggerClientEvent('ox_lib:notify', initiatorId, {title = locale('ui.trade'), description = locale('ui.trade_declin'), type = 'error', duration = 5000})

        pendingRequests[initiatorId] = nil
        TriggerClientEvent('rsg-inventory:client:tradeRequestCancelled', initiatorId)
        TriggerClientEvent('rsg-inventory:client:tradeRequestCancelled', src)
    end
end)
--[[
RegisterNetEvent('rsg-inventory:server:addTradeItem', function(tradeId, item, amount)
    local src = source

    if isOnCooldown(src) then return end

    local trade = Trades[tradeId]
    if not trade or trade.executing then return end
    if not ownsTrade(trade, src) then return end

    local side = src == trade.initiator and 'initiator' or 'target'
    local otherSide = src == trade.initiator and 'target' or 'initiator'

    if trade[side .. 'Accepted'] then return end

    local player = RSGCore.Functions.GetPlayer(src)
    if not player then return end

    local invItem = Inventory.GetItemBySlot(src, item.slot)
    if not invItem or invItem.name ~= item.name or invItem.amount < amount then return end
    
    --не даем переносить больше 10 предметов за раз
    local MAX_TRADE_SLOTS = 10
    local tradeItems = trade[side .. 'Items']
    
    local tradeSlot = nil
    for i = 1, MAX_TRADE_SLOTS do
        if not tradeItems[i] then
            tradeSlot = i
            break
        end
    end
    
    if not tradeSlot then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Trade', description = 'You can only offer up to 10 items', type = 'error', duration = 5000 })
        return
    end
    ------------------------------------------------

    -- Временно изымаем предмет из слотов игрока в предложение обмена (escrow).
    if not Inventory.RemoveItem(src, invItem.name, amount, item.slot, 'trade escrow', true) then return end

    trade[side .. 'Accepted'] = false
    trade[otherSide .. 'Accepted'] = false

    --local tradeItems = trade[side .. 'Items']
    --local tradeSlot = trade.nextSlot[side]
    tradeItems[tradeSlot] = {
        name = invItem.name,
        amount = amount,
        slot = tradeSlot,
        fromSlot = invItem.slot,
        info = invItem.info,
        label = invItem.label,
        description = invItem.description,
        weight = invItem.weight,
        type = invItem.type,
        unique = invItem.unique,
        useable = invItem.useable,
        squality = invItem.squality,
        image = invItem.image,
        shouldClose = invItem.shouldClose,
        combinable = invItem.combinable
    }
    --trade.nextSlot[side] = tradeSlot + 1

    local tradeData = {
        id = tradeId,
        initiator = trade.initiator,
        initiatorItems = trade.initiatorItems,
        targetItems = trade.targetItems,
        initiatorAccepted = trade.initiatorAccepted,
        targetAccepted = trade.targetAccepted
    }
    
    print('TRADE SLOT KEY', tradeSlot, 'ITEM SLOT FIELD', tradeItems[tradeSlot].slot, 'FROM', tradeItems[tradeSlot].fromSlot)
    
    addCapacity(trade, tradeData)
    TriggerClientEvent('rsg-inventory:client:updateTrade', trade.initiator, tradeData)
    TriggerClientEvent('rsg-inventory:client:updateTrade', trade.target, tradeData)
end)
--]]

--RegisterNetEvent('rsg-inventory:server:addTradeItem', function(tradeId, item, amount)
-- Переносит проверенный серверный слот в escrow и пересчитывает вместимость всего предложения.
lib.callback.register('rsg-inventory:server:addTradeItem', function(source, tradeId, item, amount)
    local src = source

    if isOnCooldown(src) then return false end

    local trade = Trades[tradeId]
    if not trade or trade.executing then return false end
    if not ownsTrade(trade, src) then return false end

    local side = src == trade.initiator and 'initiator' or 'target'
    local otherSide = src == trade.initiator and 'target' or 'initiator'

    if trade[side .. 'Accepted'] then return false end

    local player = RSGCore.Functions.GetPlayer(src)
    if not player then return false end
    
    amount = Inventory.ValidAmount(amount)
    if not amount or type(item) ~= 'table' or not Inventory.ValidAmount(item.slot) then return false end

    local invItem = Inventory.GetItemBySlot(src, item.slot)
    if not invItem or invItem.name ~= item.name or invItem.amount < amount then return false end
    
    --не даем переносить запрещенные предметы
    if config.TradeBlockedItems and config.TradeBlockedItems[invItem.name] then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Trade', description = 'This item cannot be traded', type = 'error', duration = 5000})
        return false
    end
    
    -- не даем переносить больше 10 предметов за раз
    local MAX_TRADE_SLOTS = config.MaxTradeSlots or 10
    local tradeItems = trade[side .. 'Items']

    local existingTradeSlot = nil
    local invQuality = invItem.info and invItem.info.quality or nil

    if not invItem.unique then
        for i = 1, MAX_TRADE_SLOTS do
            local tradeItem = tradeItems[i]
            local tradeQuality = tradeItem and tradeItem.info and tradeItem.info.quality or nil

            if tradeItem and Inventory.CanStackItem(tradeItem, invItem.name, invItem.info) then
                existingTradeSlot = i
                break
            end
        end
    end
    
    local tradeSlot = existingTradeSlot

    if not tradeSlot then
        for i = 1, MAX_TRADE_SLOTS do
            if not tradeItems[i] then
                tradeSlot = i
                break
            end
        end
    end
    
    if not tradeSlot then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('ui.trade'), description = locale('info.trade_max_slots'):format(MAX_TRADE_SLOTS), type = 'error', duration = 5000})
        return false
    end
    ------------------------------------------------

    -- Временно изымаем предмет из слотов игрока в предложение обмена (escrow).
    if not Inventory.RemoveItem(src, invItem.name, amount, item.slot, 'trade escrow', true) then return false end

    trade[side .. 'Accepted'] = false
    trade[otherSide .. 'Accepted'] = false

    if existingTradeSlot then
		tradeItems[tradeSlot].amount = tradeItems[tradeSlot].amount + amount
	else
		tradeItems[tradeSlot] = {
			name = invItem.name,
			amount = amount,
			slot = tradeSlot,
			fromSlot = invItem.slot,
			info = invItem.info,
			label = invItem.label,
			description = invItem.description,
			weight = invItem.weight,
			type = invItem.type,
			unique = invItem.unique,
			useable = invItem.useable,
			squality = invItem.squality,
			image = invItem.image,
			shouldClose = invItem.shouldClose,
			combinable = invItem.combinable
		}
	end

    local tradeData = {
        id = tradeId,
        initiator = trade.initiator,
        initiatorItems = trade.initiatorItems,
        targetItems = trade.targetItems,
        initiatorAccepted = trade.initiatorAccepted,
        targetAccepted = trade.targetAccepted
    }
    
    addCapacity(trade, tradeData)
    TriggerClientEvent('rsg-inventory:client:updateTrade', trade.initiator, tradeData)
    TriggerClientEvent('rsg-inventory:client:updateTrade', trade.target, tradeData)
    
    return true
end)

-- Возвращает позицию из escrow строго в инвентарь; при отказе предложение сохраняется.
lib.callback.register('rsg-inventory:server:removeTradeItem', function(source, tradeId, tradeSlot, targetSlot, amount)
    local src = source
    if isOnCooldown(src) then return false end
    if not tradeId then return false end

    tradeSlot = tonumber(tradeSlot)
    targetSlot = tonumber(targetSlot)
    amount = Inventory.ValidAmount(amount, 1)
    if not amount then return false end

    if not tradeSlot or tradeSlot < 1 or not targetSlot or targetSlot < 1 then return false end

    local trade = Trades[tradeId]
    if not trade or trade.executing then return false end
    if not ownsTrade(trade, src) then return false end

    local side = (src == trade.initiator) and 'initiator' or 'target'
    local otherSide = (src == trade.initiator) and 'target' or 'initiator'

    if trade[side .. 'Accepted'] then return false end

    local tradeItems = trade[side .. 'Items']
    local escrowedItem = tradeItems[tradeSlot]
    if not escrowedItem then return false end

    if amount < 1 then amount = 1 end
    if amount > escrowedItem.amount then
        amount = escrowedItem.amount
    end

    local toItem = Inventory.GetItemBySlot(src, targetSlot)
    local escrowQuality = escrowedItem.info and escrowedItem.info.quality or nil
    local toQuality = toItem and toItem.info and toItem.info.quality or nil
    
    -- Если слот занят другим предметом или тем же предметом, но другим quality или предмет уникальный
    if toItem then
        if toItem.unique or escrowedItem.unique then
            return false
        end

        if toItem.name ~= escrowedItem.name or toQuality ~= escrowQuality then
            return false
        end
    end

    local added = Inventory.AddItemStrict(src, escrowedItem.name, amount, targetSlot, escrowedItem.info, 'trade remove return')
    if not added then
        print('FAIL_ADD_ITEM')
        return false
    end

    trade[side .. 'Accepted'] = false
    trade[otherSide .. 'Accepted'] = false
    
    local remaining = escrowedItem.amount - amount
    if remaining <= 0 then
        tradeItems[tradeSlot] = nil
    else
        tradeItems[tradeSlot].amount = remaining
    end

    local tradeData = {
        id = tradeId,
        initiator = trade.initiator,
        initiatorItems = trade.initiatorItems,
        targetItems = trade.targetItems,
        initiatorAccepted = trade.initiatorAccepted,
        targetAccepted = trade.targetAccepted
    }

    addCapacity(trade, tradeData)
    TriggerClientEvent('rsg-inventory:client:updateTrade', trade.initiator, tradeData)
    TriggerClientEvent('rsg-inventory:client:updateTrade', trade.target, tradeData)

    return true
end)

--Для теста- функция которая после удаления будет смещать предметы без пустот
--[[
RegisterNetEvent('rsg-inventory:server:removeTradeItem', function(tradeId, tradeSlot)
    local src = source
    if isOnCooldown(src) then return end

    local trade = Trades[tradeId]
    if not trade or trade.executing then return end

    local side = src == trade.initiator and 'initiator' or 'target'
    local otherSide = src == trade.initiator and 'target' or 'initiator'

    if trade[side .. 'Accepted'] then return end

    local tradeItems = trade[side .. 'Items']
    local escrowedItem = tradeItems[tradeSlot]
    if not escrowedItem then return end

    table.remove(tradeItems, tradeSlot)

    for i = 1, #tradeItems do
        tradeItems[i].slot = i
    end

    Inventory.AddItemStrict(src, escrowedItem.name, escrowedItem.amount, false, escrowedItem.info, 'trade remove return')

    trade[side .. 'Accepted'] = false
    trade[otherSide .. 'Accepted'] = false

    local tradeData = {
        id = tradeId,
        initiator = trade.initiator,
        initiatorItems = trade.initiatorItems,
        targetItems = trade.targetItems,
        initiatorAccepted = trade.initiatorAccepted,
        targetAccepted = trade.targetAccepted
    }

    addCapacity(trade, tradeData)
    TriggerClientEvent('rsg-inventory:client:updateTrade', trade.initiator, tradeData)
    TriggerClientEvent('rsg-inventory:client:updateTrade', trade.target, tradeData)
end)
--]]
-- Проверяет вместимость на сервере, даже если клиент обошёл блокировку кнопки формы.
RegisterNetEvent('rsg-inventory:server:confirmTrade', function(tradeId)
    local src = source
    if isOnCooldown(src) then return end

    local trade = Trades[tradeId]
    if not trade or trade.executing then return end
    if not ownsTrade(trade, src) then return end

    local side = src == trade.initiator and 'initiator' or 'target'
    --local otherSide = src == trade.initiator and 'target' or 'initiator'

    local capacity = Inventory.GetTradeCapacity(trade)
    if not capacity.initiatorCanReceive or not capacity.targetCanReceive then
        if not capacity.targetCanReceive then Inventory.NotifyTransferFull(trade.initiator, trade.target) end
        if not capacity.initiatorCanReceive then Inventory.NotifyTransferFull(trade.target, trade.initiator) end
        publishTrade(trade)
        return
    end

    trade[side .. 'Accepted'] = true

    local tradeData = {
        id = tradeId,
        initiator = trade.initiator,
        initiatorItems = trade.initiatorItems,
        targetItems = trade.targetItems,
        initiatorAccepted = trade.initiatorAccepted,
        targetAccepted = trade.targetAccepted
    }
    addCapacity(trade, tradeData)
    TriggerClientEvent('rsg-inventory:client:updateTrade', trade.initiator, tradeData)
    TriggerClientEvent('rsg-inventory:client:updateTrade', trade.target, tradeData)

    if not (trade.initiatorAccepted and trade.targetAccepted) then
        return
    end
    
    local initiatorPlayer = RSGCore.Functions.GetPlayer(trade.initiator)
    local targetPlayer = RSGCore.Functions.GetPlayer(trade.target)
    
    if not initiatorPlayer or not targetPlayer then
        returnEscrow(trade, 'trade player unavailable return')
        return
    end
    if #(GetEntityCoords(GetPlayerPed(trade.initiator)) - GetEntityCoords(GetPlayerPed(trade.target))) > Inventory.MAX_DIST then
        returnEscrow(trade, 'trade distance return')
        return
    end

    trade.executing = true
	
    local success, errorItem = Inventory.ExecuteTrade(trade)
    if success then
        TriggerClientEvent('rsg-inventory:client:completeTrade', trade.initiator)
        TriggerClientEvent('rsg-inventory:client:completeTrade', trade.target)
        TriggerClientEvent('ox_lib:notify', trade.initiator, { title = 'Trade', description = 'Trade completed successfully', type = 'success', duration = 5000 })
        TriggerClientEvent('ox_lib:notify', trade.target, { title = 'Trade', description = 'Trade completed successfully', type = 'success', duration = 5000 })
    else
        trade.initiatorAccepted = false
        trade.targetAccepted = false

        local failedTradeData = {
            id = tradeId,
            initiator = trade.initiator,
            initiatorItems = trade.initiatorItems,
            targetItems = trade.targetItems,
            initiatorAccepted = false,
            targetAccepted = false
        }
        addCapacity(trade, failedTradeData)
        TriggerClientEvent('rsg-inventory:client:updateTrade', trade.initiator, failedTradeData)
        TriggerClientEvent('rsg-inventory:client:updateTrade', trade.target, failedTradeData)
		
        local itemLabel = errorItem and RSGCore.Shared.Items[errorItem] and RSGCore.Shared.Items[errorItem].label or 'item'
        TriggerClientEvent('ox_lib:notify', trade.initiator, { title = 'Trade', description = 'Trade failed - ' .. itemLabel .. ' could not be transferred', type = 'error', duration = 5000 })
        TriggerClientEvent('ox_lib:notify', trade.target, { title = 'Trade', description = 'Trade failed - ' .. itemLabel .. ' could not be transferred', type = 'error', duration = 5000 })
    end

end)

-- Возвращает временно изъятые предложения владельцам при отмене или выходе.
-- Удаляет из escrow только успешно возвращённые записи, чтобы повторная попытка не задваивала их.
returnEscrow = function(trade, reason)
    trade.executing = true
    local complete = true
    for _, side in ipairs({'initiator', 'target'}) do
        for slot, item in pairs(trade[side .. 'Items']) do
            if ownsTrade(trade, trade[side]) and returnTradeItemToOwner(trade[side], item, reason) then trade[side .. 'Items'][slot] = nil
            else complete = false end
        end
    end
    trade.executing = false
    if complete then
        TriggerClientEvent('rsg-inventory:client:cancelTrade', trade.initiator)
        TriggerClientEvent('rsg-inventory:client:cancelTrade', trade.target)
        Trades[trade.id] = nil
    else
        trade.initiatorAccepted, trade.targetAccepted = false, false
        publishTrade(trade)
    end
    return complete
end

RegisterNetEvent('rsg-inventory:server:cancelTrade', function(tradeId)
    local src = source
    if isOnCooldown(src) then return end
    local trade = Trades[tradeId]
    if not trade or trade.executing or not ownsTrade(trade, src) then return end
    returnEscrow(trade, 'trade cancel return')
end)

-- Повторно проверяет вместимость перед обменом и применяет оба готовых плана.
-- Нет промежуточной частичной выдачи: при отказе предложения остаются в escrow.
-- После успешного применения очищает трейд и обновляет состояния, интерфейс и горячие слоты.
function Inventory.ExecuteTrade(trade)
    local firstPlayer = RSGCore.Functions.GetPlayer(trade.initiator)
    local secondPlayer = RSGCore.Functions.GetPlayer(trade.target)
    if not firstPlayer or not secondPlayer then trade.executing = false; return false, 'player not found' end
    local capacity, firstPlan, secondPlan = Inventory.GetTradeCapacity(trade)
    if not firstPlan or not secondPlan then
        trade.executing = false
        -- Предложения остаются в escrow: ни один инвентарь назначения ещё не изменён.
        return false, 'inventory full'
    end
    -- Оба плана проверены; между применениями нет ожиданий нативов или callback.
    firstPlayer.PlayerData.items, secondPlayer.PlayerData.items = firstPlan, secondPlan
    Inventory.SetInventory(trade.initiator, firstPlan)
    Inventory.SetInventory(trade.target, secondPlan)
    for _, pair in ipairs({{trade.initiator, trade.targetItems}, {trade.target, trade.initiatorItems}}) do
        for _, item in pairs(pair[2]) do
            Inventory.NotifyItemChanged(pair[1], item.name, {action = 'add', amount = item.amount, reason = 'trade'})
        end
        TriggerEvent('rsg-inventory:server:updateHotbar', pair[1])
    end
    TriggerEvent('rsg-log:server:CreateLog', 'playerinventory', 'Trade Completed', 'green',
        ('Trade %s between %s and %s completed'):format(trade.id, trade.initiator, trade.target))
    Trades[trade.id] = nil
    return true
end

AddEventHandler('playerDropped', function()
    local src = source
    for _, trade in pairs(Trades) do
        if (trade.initiator == src or trade.target == src) and not trade.executing then
            returnEscrow(trade, 'trade disconnect return')
        end
    end
    for initiatorId, request in pairs(pendingRequests) do
        if initiatorId == src or request.targetId == src then
            TriggerClientEvent('rsg-inventory:client:tradeRequestCancelled', initiatorId)
            TriggerClientEvent('rsg-inventory:client:tradeRequestCancelled', request.targetId)
            pendingRequests[initiatorId] = nil
        end
    end
    tradeCooldowns[src] = nil
end)
