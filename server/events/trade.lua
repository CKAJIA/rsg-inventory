local RSGCore = exports['rsg-core']:GetCoreObject()
local config    = require 'shared.config'
Trades = Trades or {}
local pendingRequests = {}

local function getCharName(source)
    local player = RSGCore.Functions.GetPlayer(source)
    if not player then return GetPlayerName(source) end
    local char = player.PlayerData.charinfo
    if char and char.firstname then
        return char.firstname .. ' ' .. char.lastname
    end
    return GetPlayerName(source)
end

-- Rate limiting
local tradeCooldowns = {}
local function isOnCooldown(src)
    local now = GetGameTimer()
    if tradeCooldowns[src] and now - tradeCooldowns[src] < 200 then return true end
    tradeCooldowns[src] = now
    return false
end

-- Возвращает весь tradeItem обратно его владельцу.
local function returnTradeItemToOwner(ownerId, tradeItem, reason)
    if not tradeItem or not tradeItem.name or not tradeItem.amount or tradeItem.amount <= 0 then
        return true
    end

    local ok = Inventory.AddItem(ownerId, tradeItem.name, tradeItem.amount, false, tradeItem.info, reason)
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
        executing = false
    }

    pendingRequests[initiatorId] = nil

    local initiatorItems = initiator.PlayerData.items
    local targetItems = player.PlayerData.items
    
    TriggerClientEvent('rsg-inventory:client:openTrade', initiatorId, tradeId, src, getCharName(src), initiatorItems, player.PlayerData)
    TriggerClientEvent('rsg-inventory:client:openTrade', src, tradeId, initiatorId, getCharName(initiatorId), targetItems, initiator.PlayerData)
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
    if not trade then return end
    if trade.initiator ~= src and trade.target ~= src then return end

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

    -- ESCROW: Remove item from player inventory immediately
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
    
    TriggerClientEvent('rsg-inventory:client:updateTrade', trade.initiator, tradeData)
    TriggerClientEvent('rsg-inventory:client:updateTrade', trade.target, tradeData)
end)
--]]

--RegisterNetEvent('rsg-inventory:server:addTradeItem', function(tradeId, item, amount)
lib.callback.register('rsg-inventory:server:addTradeItem', function(source, tradeId, item, amount)
    local src = source

    if isOnCooldown(src) then return false end

    local trade = Trades[tradeId]
    if not trade then return false end
    if trade.initiator ~= src and trade.target ~= src then return false end

    local side = src == trade.initiator and 'initiator' or 'target'
    local otherSide = src == trade.initiator and 'target' or 'initiator'

    if trade[side .. 'Accepted'] then return false end

    local player = RSGCore.Functions.GetPlayer(src)
    if not player then return false end
    
    amount = tonumber(amount) or 1
    if amount < 1 then return false end

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

            if tradeItem and not tradeItem.unique and tradeItem.name == invItem.name and tradeQuality == invQuality then
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

    -- ESCROW: Remove item from player inventory immediately
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
    
    TriggerClientEvent('rsg-inventory:client:updateTrade', trade.initiator, tradeData)
    TriggerClientEvent('rsg-inventory:client:updateTrade', trade.target, tradeData)
    
    return true
end)

lib.callback.register('rsg-inventory:server:removeTradeItem', function(source, tradeId, tradeSlot, targetSlot, amount)
    local src = source
    if isOnCooldown(src) then return false end
    if not tradeId then return false end

    tradeSlot = tonumber(tradeSlot)
    targetSlot = tonumber(targetSlot)
    amount = tonumber(amount) or 1

    if not tradeSlot or tradeSlot < 1 or not targetSlot or targetSlot < 1 then return false end

    local trade = Trades[tradeId]
    if not trade then return false end
    if trade.initiator ~= src and trade.target ~= src then return false end

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

    local added = Inventory.AddItem(src, escrowedItem.name, amount, targetSlot, escrowedItem.info, 'trade remove return')
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
    if not trade then return end

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

    Inventory.AddItem(src, escrowedItem.name, escrowedItem.amount, false, escrowedItem.info, 'trade remove return')

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

    TriggerClientEvent('rsg-inventory:client:updateTrade', trade.initiator, tradeData)
    TriggerClientEvent('rsg-inventory:client:updateTrade', trade.target, tradeData)
end)
--]]
RegisterNetEvent('rsg-inventory:server:confirmTrade', function(tradeId)
    local src = source
    if isOnCooldown(src) then return end

    local trade = Trades[tradeId]
    if not trade then return end
    if trade.initiator ~= src and trade.target ~= src then return end

    local side = src == trade.initiator and 'initiator' or 'target'
    --local otherSide = src == trade.initiator and 'target' or 'initiator'

    trade[side .. 'Accepted'] = true

    local tradeData = {
        id = tradeId,
        initiator = trade.initiator,
        initiatorItems = trade.initiatorItems,
        targetItems = trade.targetItems,
        initiatorAccepted = trade.initiatorAccepted,
        targetAccepted = trade.targetAccepted
    }
    TriggerClientEvent('rsg-inventory:client:updateTrade', trade.initiator, tradeData)
    TriggerClientEvent('rsg-inventory:client:updateTrade', trade.target, tradeData)

    if not (trade.initiatorAccepted and trade.targetAccepted) then
        return
    end
    
    local initiatorPlayer = RSGCore.Functions.GetPlayer(trade.initiator)
    local targetPlayer = RSGCore.Functions.GetPlayer(trade.target)
    
    if not initiatorPlayer or not targetPlayer then
        TriggerClientEvent('rsg-inventory:client:cancelTrade', trade.initiator)
        TriggerClientEvent('rsg-inventory:client:cancelTrade', trade.target)
        Trades[tradeId] = nil
        return
    end
    
    if #(GetEntityCoords(GetPlayerPed(trade.initiator)) - GetEntityCoords(GetPlayerPed(trade.target))) > Inventory.MAX_DIST then
        TriggerClientEvent('ox_lib:notify', trade.initiator, { title = locale('error.error'), description = locale('error.player_too_far'), type = 'error', duration = 5000 })
        TriggerClientEvent('ox_lib:notify', trade.target, { title = locale('error.error'), description = locale('error.player_too_far'), type = 'error', duration = 5000 })
        -- Return escrowed items
        for _, item in pairs(trade.initiatorItems) do
            returnTradeItemToOwner(trade.initiator, item, 'trade distance return')
        end
        for _, item in pairs(trade.targetItems) do
            returnTradeItemToOwner(trade.target, item, 'trade distance return')
        end
        TriggerClientEvent('rsg-inventory:client:cancelTrade', trade.initiator)
        TriggerClientEvent('rsg-inventory:client:cancelTrade', trade.target)
        Trades[tradeId] = nil
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
        TriggerClientEvent('rsg-inventory:client:updateTrade', trade.initiator, failedTradeData)
        TriggerClientEvent('rsg-inventory:client:updateTrade', trade.target, failedTradeData)
		
        local itemLabel = errorItem and RSGCore.Shared.Items[errorItem] and RSGCore.Shared.Items[errorItem].label or 'item'
        TriggerClientEvent('ox_lib:notify', trade.initiator, { title = 'Trade', description = 'Trade failed - ' .. itemLabel .. ' could not be transferred', type = 'error', duration = 5000 })
        TriggerClientEvent('ox_lib:notify', trade.target, { title = 'Trade', description = 'Trade failed - ' .. itemLabel .. ' could not be transferred', type = 'error', duration = 5000 })
    end

end)

RegisterNetEvent('rsg-inventory:server:cancelTrade', function(tradeId)
    local src = source
    if isOnCooldown(src) then return end

    local trade = Trades[tradeId]
    if not trade then return end
    if trade.initiator ~= src and trade.target ~= src then return end
	
	local otherPlayer = (trade.initiator == src) and trade.target or trade.initiator

    -- Return escrowed items
    for _, item in pairs(trade.initiatorItems) do
        returnTradeItemToOwner(trade.initiator, item, 'trade cancel return')
    end
    for _, item in pairs(trade.targetItems) do
        returnTradeItemToOwner(trade.target, item, 'trade cancel return')
    end

    TriggerClientEvent('rsg-inventory:client:cancelTrade', trade.initiator)
    TriggerClientEvent('rsg-inventory:client:cancelTrade', trade.target)
    
	TriggerClientEvent('ox_lib:notify', src, { title = locale('ui.trade'), description = locale('info.trade_cancelled'), type = 'info', duration = 5000 })
	TriggerClientEvent('ox_lib:notify', otherPlayer, { title = locale('ui.trade'), description = locale('info.trade_cancelled'), type = 'info', duration = 5000 })
    
	Trades[tradeId] = nil
end)

function Inventory.ExecuteTrade(trade)
    local initiatorPlayer = RSGCore.Functions.GetPlayer(trade.initiator)
    local targetPlayer = RSGCore.Functions.GetPlayer(trade.target)

    if not initiatorPlayer or not targetPlayer then
        -- Items are in escrow, return them safely
        for _, item in pairs(trade.initiatorItems) do
            returnTradeItemToOwner(trade.initiator, item, 'trade rollback')
        end
        for _, item in pairs(trade.targetItems) do
            returnTradeItemToOwner(trade.target, item, 'trade rollback')
        end
        Trades[trade.id] = nil
        return false, 'player not found'
    end

    -- Items are already in escrow (removed from source inventories).
    -- Track successful transfers for clean rollback on failure.
    local transferred = {}

    -- Phase 1: Transfer initiator's items to target
    for _, tradeItem in pairs(trade.initiatorItems) do
        if Inventory.AddItem(trade.target, tradeItem.name, tradeItem.amount, false, tradeItem.info, ('trade from %s'):format(trade.initiator)) then
            transferred[#transferred+1] = { name = tradeItem.name, amount = tradeItem.amount, info = tradeItem.info, fromId = trade.initiator, toId = trade.target }
        else
            -- Rollback: undo all transfers, return all escrowed items to original owners
            for _, t in ipairs(transferred) do
                Inventory.RemoveItem(t.toId, t.name, t.amount, false, 'trade rollback', true)
                Inventory.AddItem(t.fromId, t.name, t.amount, false, t.info, 'trade rollback')
            end
            for _, item in pairs(trade.initiatorItems) do
                returnTradeItemToOwner(trade.initiator, item, 'trade rollback')
            end
            for _, item in pairs(trade.targetItems) do
                returnTradeItemToOwner(trade.target, item, 'trade rollback')
            end
            Trades[trade.id] = nil
            return false, tradeItem.name
        end
    end

    -- Phase 2: Transfer target's items to initiator
    for _, tradeItem in pairs(trade.targetItems) do
        if Inventory.AddItem(trade.initiator, tradeItem.name, tradeItem.amount, false, tradeItem.info, ('trade from %s'):format(trade.target)) then
            transferred[#transferred+1] = { name = tradeItem.name, amount = tradeItem.amount, info = tradeItem.info, fromId = trade.target, toId = trade.initiator }
        else
            -- Rollback: undo ALL transfers (including phase 1), return all escrowed items
            for _, t in ipairs(transferred) do
                Inventory.RemoveItem(t.toId, t.name, t.amount, false, 'trade rollback', true)
                Inventory.AddItem(t.fromId, t.name, t.amount, false, t.info, 'trade rollback')
            end
            for _, item in pairs(trade.initiatorItems) do
                returnTradeItemToOwner(trade.initiator, item, 'trade rollback')
            end
            for _, item in pairs(trade.targetItems) do
                returnTradeItemToOwner(trade.target, item, 'trade rollback')
            end
            Trades[trade.id] = nil
            return false, tradeItem.name
        end
    end

    local msgItems1, msgItems2 = {}, {}
    for _, item in pairs(trade.initiatorItems) do msgItems1[#msgItems1+1] = item.name .. ' x' .. item.amount end
    for _, item in pairs(trade.targetItems) do msgItems2[#msgItems2+1] = item.name .. ' x' .. item.amount end
    TriggerEvent('rsg-log:server:CreateLog', 'playerinventory', 'Trade Completed', 'green',
        ('**%s (%s)** gave: %s\n**%s (%s)** gave: %s')
            :format(getCharName(trade.initiator), trade.initiator, table.concat(msgItems1, ', '),
                    getCharName(trade.target), trade.target, table.concat(msgItems2, ', ')))

    Trades[trade.id] = nil
    return true
end

AddEventHandler('playerDropped', function()
    local src = source

    for id, trade in pairs(Trades) do
        if trade.executing then
            -- ExecuteTrade is in progress and has its own rollback.
            -- Notify the other player; ExecuteTrade will clean up the trade.
            local other = trade.initiator == src and trade.target or trade.initiator
            TriggerClientEvent('rsg-inventory:client:cancelTrade', other)
        elseif trade.initiator == src or trade.target == src then
            -- Return escrowed items to the disconnecting player
            if trade.initiator == src then
                for _, item in pairs(trade.initiatorItems) do
                    returnTradeItemToOwner(src, item, 'trade disconnect return')
                end
            end
            if trade.target == src then
                for _, item in pairs(trade.targetItems) do
                    returnTradeItemToOwner(src, item, 'trade disconnect return')
                end
            end

            TriggerClientEvent('rsg-inventory:client:cancelTrade', trade.initiator)
            TriggerClientEvent('rsg-inventory:client:cancelTrade', trade.target)
            Trades[id] = nil
        end
    end
    for initiatorId, targetId in pairs(pendingRequests) do
        if initiatorId == src or targetId == src then
            TriggerClientEvent('rsg-inventory:client:tradeRequestCancelled', initiatorId)
            TriggerClientEvent('rsg-inventory:client:tradeRequestCancelled', targetId)
            pendingRequests[initiatorId] = nil
        end
    end
end)
