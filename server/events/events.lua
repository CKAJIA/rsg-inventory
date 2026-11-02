--[[ 
    Server Event: Close a player's inventory
    Handles regular inventories, other player inventories, shops, and dropped items.
--]]
local RSGCore = exports['rsg-core']:GetCoreObject()

RegisterNetEvent('rsg-inventory:server:closeInventory', function(inventory)
    local src = source
    local RSGPlayer = RSGCore.Functions.GetPlayer(src)
    if not RSGPlayer then return end

    -- Освобождаем флаг занятости инвентаря игрока.
    Player(src).state.inv_busy = false

    -- Для магазина закрытие контейнера не требуется.
    if inventory:find('shop-') then return end

    -- Освобождаем просмотренный инвентарь другого игрока.
    if inventory:find('otherplayer-') then
        local targetId = tonumber(inventory:match('otherplayer%-(.+)'))
--        Player(targetId).state.inv_busy = false

        -- Снимаем чужой busy только рядом с целью, проверяя подставленный otherplayer-ID.
        local targetPed = GetPlayerPed(targetId)
        local srcPed = GetPlayerPed(src)
        if targetPed and DoesEntityExist(targetPed) and DoesEntityExist(srcPed) then
            if #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed)) <= Inventory.MAX_DIST then
                Player(targetId).state.inv_busy = false
            end
        end

        return
    end

    -- Закрываем сумку в игровом мире.
    if Drops[inventory] then
        Drops[inventory].isOpen = false
        if next(Drops[inventory].items) == nil and not Drops[inventory].isOpen then 
            TriggerClientEvent('rsg-inventory:client:removeDropTarget', -1, Drops[inventory].entityId)
            Wait(500)
            -- После ожидания снова проверяем состояние: сумку мог открыть другой игрок.
            if not Drops[inventory] or Drops[inventory].isOpen then return end
            local entity = NetworkGetEntityFromNetworkId(Drops[inventory].entityId)
            if DoesEntityExist(entity) then DeleteEntity(entity) end
            Drops[inventory] = nil
        end
        return
    end

    -- Сохраняем постоянное хранилище.
    if not Inventories[inventory] then return end
    Inventories[inventory].isOpen = false
    MySQL.prepare('INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?', 
        { inventory, json.encode(Inventories[inventory].items), json.encode(Inventories[inventory].items) })
end)

--[[ 
    Server Event: Use an item from player's inventory
    Handles weapons, throwable weapons, equipment, and regular items
--]]
RegisterNetEvent('rsg-inventory:server:useItem', function(item)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    local itemData = Inventory.GetItemBySlot(src, item.slot)
    if not itemData then return end
    local itemInfo = RSGCore.Shared.Items[itemData.name]
    local allowedDuringMelee = {
        weapon = true,
        weapon_thrown = true,
        -- equipment = true  you can add more 
    }

    local inMelee = lib.callback.await('rsg-inventory:client:isInMelee', src)
    if inMelee and not allowedDuringMelee[itemData.type] then
        TriggerClientEvent('lib:notify', src, {
            title = 'Inventory',
            description = locale('error.error'),
            type = 'error'
        })
        return
    end
    if itemData.type == 'weapon' then
        local result = MySQL.Sync.fetchAll(
            'SELECT * FROM player_weapons WHERE serial = @serial and citizenid = @citizenid',
            { serial = itemData.info.serie, citizenid = Player.PlayerData.citizenid }
        )
        if not result[1] then
            MySQL.Sync.execute(
                'INSERT INTO player_weapons (serial, citizenid) VALUES (@serial, @citizenid)',
                { serial = itemData.info.serie, citizenid = Player.PlayerData.citizenid }
            )
            --Wait(1000)
        end
        TriggerClientEvent('rsg-weapons:client:UseWeapon', src, itemData)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, itemInfo, 'use')

    elseif itemData.type == 'weapon_thrown' then
        TriggerClientEvent('rsg-weapons:client:UseThrownWeapon', src, itemData)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, itemInfo, 'use')

    elseif itemData.type == 'equipment' then
        TriggerClientEvent('rsg-weapons:client:UseEquipment', src, itemData)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, itemInfo, 'use')

    else
        Inventory.UseItem(itemData.name, src, itemData)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, itemInfo, 'use')
    end
end)

--[[ 
    Server Event: Update player's hotbar
    Sends the first 5 inventory slots to the client for UI update
--]]
RegisterNetEvent('rsg-inventory:server:updateHotbar', function(identifier)
    local src = identifier or source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local items = {}
    for slot = 1, 5 do
        items[slot] = Player.Functions.GetItemBySlot(slot)
    end

    TriggerClientEvent('rsg-inventory:client:updateHotbar', src, items)
end)

-- Ограничиваем частые перемещения, разделение и обмен слотов.
local setInventoryCooldowns = {}

--[[ 
    Server Event: Move or swap items between inventories
    Handles stacking, splitting, moving, and swapping items between inventories
--]]
-- Проверяет типы, положительное целое количество, границы слотов и сторону игрока.
-- При перемещениях используются строгие добавления без автоматических сумок;
-- для объединения нужны совместимые метаданные, совпадения имени недостаточно.
RegisterNetEvent('rsg-inventory:server:SetInventoryData', function(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount)
    -- Задержка между перемещениями одного игрока — 100 мс.
    local src = source
    local now = GetGameTimer()
    if setInventoryCooldowns[src] and now - setInventoryCooldowns[src] < 100 then return end
    setInventoryCooldowns[src] = now

    if type(fromInventory) ~= 'string' or type(toInventory) ~= 'string' then return end
    -- Нельзя передавать предмет в магазин обычным перемещением.
    if toInventory:find('shop-') then return end
    if not fromInventory or not toInventory or not fromSlot or not toSlot or not fromAmount or not toAmount then return end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local isMove = false
    fromSlot, toSlot, fromAmount, toAmount = tonumber(fromSlot), tonumber(toSlot), tonumber(fromAmount), tonumber(toAmount)
    -- NUI присылает fromAmount как ОСТАТОК исходного стака после визуального переноса.
    -- При переносе целого предмета он равен 0. Это допустимый остаток, а не количество выдачи.
    -- Сам перенос toAmount остаётся положительным; доступное количество берём с сервера ниже.
    local validRemainder = fromAmount == 0 or Inventory.ValidAmount(fromAmount)
    if not Inventory.ValidAmount(fromSlot) or not Inventory.ValidAmount(toSlot)
        or not validRemainder or not Inventory.ValidAmount(toAmount) then return end
    if fromInventory ~= 'player' and toInventory ~= 'player' then return end

    -- Проверяем дистанцию и состояние цели для доступа к чужому инвентарю.
    local function getOtherPlayerId(inv)
        if inv:find('otherplayer-') then
            return tonumber(inv:match('otherplayer%-(.+)'))
        end
    end
    local targetId = getOtherPlayerId(fromInventory) or getOtherPlayerId(toInventory)
    if targetId then
        local Target = RSGCore.Functions.GetPlayer(targetId)
        if not Target then
            Inventory.CloseInventory(src, fromInventory)
            Inventory.CloseInventory(src, toInventory)
            return
        end
        local srcPed, targetPed = GetPlayerPed(src), GetPlayerPed(targetId)
        if #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed)) > 3.0 then
            Inventory.CloseInventory(src, fromInventory)
            Inventory.CloseInventory(src, toInventory)
            TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = locale('error.player_too_far'), type = 'error', duration = 5000 })
            return
        end
        local targetMeta = Target.PlayerData.metadata
        if not targetMeta.isdead and not targetMeta.ishandcuffed then
            Inventory.CloseInventory(src, fromInventory)
            Inventory.CloseInventory(src, toInventory)
            TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = locale('error.target_needs_restrained'), type = 'error', duration = 5000 })
            return
        end
        local hasPerm = RSGCore.Functions.HasPermission(src, 'police') or Player.PlayerData.job.name == 'police' or Player.PlayerData.job.name == 'marshal'
        if not hasPerm and not targetMeta.isdead then
            Inventory.CloseInventory(src, fromInventory)
            Inventory.CloseInventory(src, toInventory)
            return
        end
    end

	-- Применяем существующие ограничения хранилищ по префиксам (общая проверка в server/functions.lua).
    for _, invName in pairs({ fromInventory, toInventory }) do
        local stashType = Inventory.GetRestrictedStashType(invName)
        if stashType and not Inventory.HasStashAccess(src, invName, Player, stashType) then
            Inventory.CloseInventory(src, invName)
            TriggerClientEvent('ox_lib:notify', src, { title = 'Access Denied', description = 'No permission', type = 'error', duration = 5000 })
            return
        end
    end

    local fromId, fromType = Inventory.GetIdentifier(fromInventory, src)
    local toId, toType = Inventory.GetIdentifier(toInventory, src)
    if fromId ~= toId then isMove = true end
    local fromItems, _, fromSlots = Inventory.GetContainerData(fromId)
    local toItems, _, toSlots = Inventory.GetContainerData(toId)
    if not fromItems or not toItems or fromSlot > fromSlots or toSlot > toSlots then return end

    -- Проверяем дистанцию, кроме разрешённого административного доступа.
    if not RSGCore.Functions.HasPermission(src, 'admin') then
        local srcCoords = GetEntityCoords(GetPlayerPed(src))
        local maxDist = Inventory.MAX_DIST
        local isInventoryTooFar = function(inventoryCoords)
            return inventoryCoords and #(srcCoords - inventoryCoords) > maxDist
        end
        local fromTooFar = isInventoryTooFar(Inventory.GetCoords(fromInventory, src))
        local toTooFar = isInventoryTooFar(Inventory.GetCoords(toInventory, src))
        if fromTooFar or toTooFar then
            Inventory.CloseInventory(src, fromId)
            Inventory.CloseInventory(src, toId)
            local message = fromTooFar and locale('error.source_inv_too_far') or locale('error.target_inv_too_far')
            TriggerClientEvent('ox_lib:notify', src, { title = message, type = 'error', duration = 5000 })
            return
        end
    end

    local fromItem = Inventory.GetItem(fromInventory, src, fromSlot)
    local toItem = Inventory.GetItem(toInventory, src, toSlot)

    if fromItem then
        -- Нельзя переместить больше, чем есть в исходном слоте.
        if not toItem and toAmount > fromItem.amount then return end

        -- При передаче оружия убираем его активное представление у игрока.
        if fromInventory == 'player' and toInventory ~= 'player' then
            isMove = true
            Inventory.CheckWeapon(src, fromItem)
        end

        -- Объединяем только совместимые стаки: имя, unique и все значимые метаданные.
        if toItem and Inventory.CanStackItem(toItem, fromItem.name, fromItem.info) then
            Inventory.TryStackItems(src, fromId, toId, fromSlot, toSlot, fromItem, toItem, toAmount, isMove)
        -- Перемещаем только выбранную часть стака.
        elseif not toItem and toAmount < fromItem.amount then
            Inventory.TrySplitItem(src, fromId, toId, fromSlot, toSlot, fromItem, toAmount, isMove)
        -- Меняем предметы местами.
        elseif toItem then
            Inventory.TrySwapItems(src, fromId, toId, fromSlot, toSlot, fromItem, toItem, isMove)
        -- Перемещаем предмет в пустой слот.
        else
            Inventory.TryMoveItem(src, fromId, toId, fromSlot, toSlot, fromItem, toAmount, isMove)
        end
    end
end)

RegisterNetEvent('rsg-inventory:server:openPlayerInventory', function(targetId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Target = RSGCore.Functions.GetPlayer(targetId)

    if not Player or not Target then return end

    -- Security checks
    local srcPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)
    local srcCoords = GetEntityCoords(srcPed)
    local targetCoords = GetEntityCoords(targetPed)
    local distance = #(srcCoords - targetCoords)

    -- Check if target is close enough (max 3.0 units)
    if distance > 3.0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('error.error'),
            description = locale('error.player_too_far'),
            type = 'error',
            duration = 5000
        })
        return
    end

    -- Check if target player is unconscious/dead (required for looting)
    local targetMeta = Target.PlayerData.metadata
    if not targetMeta.isdead and not targetMeta.ishandcuffed then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('error.error'),
            description = locale('error.target_needs_restrained'),
            type = 'error',
            duration = 5000
        })
        return
    end

    -- Additional permission check for law enforcement
    local hasPermission = RSGCore.Functions.HasPermission(src, 'police') or
                         Player.PlayerData.job.name == 'police' or
                         Player.PlayerData.job.name == 'marshal'

    if not hasPermission and not targetMeta.isdead then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('error.error'),
            description = 'Insufficient permissions',
            type = 'error',
            duration = 5000
        })
        return
    end

    Inventory.OpenInventoryById(src, targetId)
end)

RegisterNetEvent('rsg-inventory:server:openStash', function(stashId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if not Player then return end

    -- Basic validation
    if not stashId or type(stashId) ~= 'string' then
        return TriggerClientEvent('ox_lib:notify', src, {
            title = locale('error.error'),
            description = locale('error.invalid_stash_identifier'),
            type = 'error',
            duration = 5000
        })
    end

    -- Ограниченные хранилища (общая проверка в server/functions.lua): police-, marshal-, gang-, admin-, evidence-.
    local stashType = Inventory.GetRestrictedStashType(stashId)
    if stashType and not Inventory.HasStashAccess(src, stashId, Player, stashType) then
        return TriggerClientEvent('ox_lib:notify', src, {
            title = locale('error.access_denied'),
            description = locale('error.no_permission_stash'),
            type = 'error',
            duration = 5000
        })
    end

    -- Additional distance check for world stashes
    local stashCoords = Inventory.GetCoords(stashId, src)
    if stashCoords then
        local playerCoords = GetEntityCoords(GetPlayerPed(src))
        local distance = #(playerCoords - stashCoords)

        if distance > Inventory.MAX_DIST then
            return TriggerClientEvent('ox_lib:notify', src, {
                title = locale('error.error'),
                description = locale('error.stash_too_far'),
                type = 'error',
                duration = 5000
            })
        end
    end

    Inventory.OpenInventory(src, stashId)
end)

AddEventHandler('playerDropped', function()
    local src = source
    for dropId, drop in pairs(Drops) do
        if drop.openedBy == src then
            drop.isOpen = false
            drop.openedBy = nil
        end
    end
end)
