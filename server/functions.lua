local RSGCore = exports['rsg-core']:GetCoreObject()
Inventory = Inventory or {}
Inventory.PlayerNameIndexes = Inventory.PlayerNameIndexes or {}
local config = require 'shared.config'

Inventory.TYPES = {
    PLAYER = 1,
    OTHER_PLAYER = 2,
    DROP = 3,
    STASH = 4,
}
Inventory.MAX_DIST = 5.0

Inventory.InitializeInventory = function(inventoryId, data)
    Inventories[inventoryId] = {
        coords = data and data.coords,
        items = {},
        isOpen = false,
        label = data and data.label or inventoryId,
        maxweight = data and data.maxweight or config.StashSize.maxweight,
        slots = data and data.slots or config.StashSize.slots
    }
    return Inventories[inventoryId]
end

Inventory.GetItem = function(inventoryId, src, slot)
    local items = {}
    if inventoryId == 'player' then
        local Player = RSGCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData.items then
            items = Player.PlayerData.items
        end
    elseif inventoryId:find('otherplayer-') then
        local targetId = tonumber(inventoryId:match('otherplayer%-(.+)'))
        local targetPlayer = RSGCore.Functions.GetPlayer(targetId)
        if targetPlayer and targetPlayer.PlayerData.items then
            items = targetPlayer.PlayerData.items
        end
    elseif inventoryId:find('drop-') == 1 then
        if Drops[inventoryId] and Drops[inventoryId]['items'] then
            items = Drops[inventoryId]['items']
        end
    else
        if Inventories[inventoryId] and Inventories[inventoryId]['items'] then
            items = Inventories[inventoryId]['items']
        end
    end

    for _, item in pairs(items) do
        if item.slot == slot then
            return item
        end
    end
    return nil
end

Inventory.GetFirstFreeSlot = function(items, maxSlots)
    for i = 1, maxSlots do
        if items[i] == nil then
            return i
        end
    end
    return nil
end

Inventory.GetIdentifier = function(inventoryId, src)
    if inventoryId == 'player' then
        return src, Inventory.TYPES.PLAYER
    elseif inventoryId:find('otherplayer-') then
        return tonumber(inventoryId:match('otherplayer%-(.+)')), Inventory.TYPES.OTHER_PLAYER
    elseif inventoryId:find('drop-') then
        return inventoryId, Inventory.TYPES.DROP
    else
        return inventoryId, Inventory.TYPES.STASH
    end
end

Inventory.CheckWeapon = function(source, item)
    local currentWeapon = type(item) == 'table' and item.name or item
    local ped = GetPlayerPed(source)
    local weapon = GetSelectedPedWeapon(ped)
    local weaponInfo = RSGCore.Shared.Weapons[weapon]
    if weaponInfo and weaponInfo.name == currentWeapon then
        RemoveWeaponFromPed(ped, weapon)
        TriggerClientEvent('rsg-weapons:client:UseWeapon', source, { name = currentWeapon }, false)
    end
end

-- Retrieves the first slot number that contains an item with the specified name and matches quality
--- @param items table The table of items to search through.
--- @param itemName string The name of the item to search for.
--- @param quality number item quality to match
--- @return number|nil - The slot number of the first matching item, or nil if no match is found.
Inventory.GetFirstSlotByItemWithQuality = function(items, itemName, quality)
    if not items then return end
    for slot, item in pairs(items) do
        if item.name:lower() == itemName:lower() and item.info.quality == quality then
            return tonumber(slot)
        end
    end
    return nil
end

--- Checks and applies item decay over time.
--- @param item table The item table.
--- @param itemInfo table|nil Optional item definition from RSGCore.Shared.Items.
--- @param currentTime number|nil Optional timestamp (defaults to os.time()).
--- @param decayRateModifier number|nil Optional modifier for configured decay rate
--- @return boolean shouldUpdate Whether the item metadata was updated.
--- @return number|nil newQuality The new quality of the item after decay.
--- @return boolean shouldDelete Whether the item should be deleted when quality reaches 0.
Inventory.CheckItemDecay = function(item, itemInfo, currentTime, decayRateModifier)
    itemInfo = itemInfo or RSGCore.Shared.Items[item.name:lower()]
    currentTime = currentTime or os.time()

    if not itemInfo or not itemInfo.decay then return false, nil, false end

    if not item.info.quality or not item.info.lastUpdate then
        item.info.quality = item.info.quality or 100
        item.info.lastUpdate = currentTime
        return true, item.info.quality, itemInfo.delete == true
    end
    decayRateModifier = decayRateModifier or 1
    local timeElapsed = currentTime - item.info.lastUpdate
    local decayRate = (100 / (itemInfo.decay * 60)) * decayRateModifier
    local newQuality = math.max(0, item.info.quality - timeElapsed * decayRate)
    item.info.quality = math.round(newQuality, 1)
	--item.info.quality = math.floor(newQuality + 0.5) --так получаем качество округленное без дробей
    item.info.lastUpdate = currentTime

    return true, item.info.quality, itemInfo.delete == true
end

--- Applies decay to all items in an inventory.
--- @param items table<number, table> Inventory items (indexed by slot).
--- @param decayRateModifier number|nil Optional modifier for configured decay rate
--- @return boolean needsUpdate Returns true if any item was updated or deleted.
--- @return table removedItems Returns removed items.
Inventory.CheckItemsDecay = function(items, decayRateModifier)
    local needsUpdate = false
    local currentTime = os.time()
    local removedItems = {}

    for slot, item in pairs(items) do
        local updated, quality, delete = Inventory.CheckItemDecay(item, nil, currentTime, decayRateModifier)
        if updated then
            if delete and quality <= 0 then
                removedItems[slot] = items[slot]
                items[slot] = nil
            end
            needsUpdate = true
        end
    end

    return needsUpdate, removedItems
end

--- Applies decay to all items in a player's inventory and updates their data.
--- @param player table The player object.
Inventory.CheckPlayerItemsDecay = function(player)
    local needsUpdate, removedItems = Inventory.CheckItemsDecay(player.PlayerData.items)
	local src = player.PlayerData.source
	
    if needsUpdate then
		player.Functions.SetPlayerData('items', player.PlayerData.items)
		-------------------------------------------------------------
		-- Удаляем из индекса только реально удалённые decay-предметы
		for slot, item in pairs(removedItems) do
			if item then				
				Inventory.NameIndexRemove(src, item.name, slot)
				-- Предмет исчез из-за decay.
                -- Проверяем только правила, где он участвует.
                Inventory.ItemStates.OnItemChanged(src, item.name)
				
				Inventory.NotifyItemChanged(src, item.name, {
					action = 'remove',
					amount = item.amount,
					slot = slot,
					reason = 'decay'
				})
				
				TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item.name], 'remove', item.amount)
			end
		end
    end
end

--- Applies decay to single item in a player's inventory and updates their data.
--- @param player table The player object.
--- @param item table item object.
Inventory.CheckPlayerItemDecay = function(player, item) 
    local updated, quality, delete = Inventory.CheckItemDecay(item)
	local src = player.PlayerData.source
    if updated then
        if delete and quality <= 0 then
            player.PlayerData.items[item.slot] = nil
			-------------------------------------------------------
			Inventory.NameIndexRemove(src, item.name, item.slot)
			-------------------------------------------------------
			-- Последний экземпляр этого предмета мог исчезнуть.
			player.Functions.SetPlayerData('items', player.PlayerData.items)
			
			Inventory.ItemStates.OnItemChanged(src, item.name, player)
			
			Inventory.NotifyItemChanged(src, item.name, {
				action = 'remove',
				amount = item.amount,
				slot = item.slot,
				reason = 'decay'
			})
			
            TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item.name], 'remove', item.amount)
        end
        
        player.Functions.SetPlayerData('items', player.PlayerData.items)
    end

    return player.PlayerData.items[item.slot]
end

--- @param inventoryId string
--- @param src? any
--- @return vector3|nil
Inventory.GetCoords = function(inventoryId, src)
    local _,inventoryType = Inventory.GetIdentifier(inventoryId)
    if inventoryType == Inventory.TYPES.PLAYER then
        local ped = GetPlayerPed(src)
        return DoesEntityExist(ped) and GetEntityCoords(ped)
    elseif inventoryType == Inventory.TYPES.OTHER_PLAYER then
        local ped = GetPlayerPed(_)
        return DoesEntityExist(ped) and GetEntityCoords(ped)
    elseif inventoryType == Inventory.TYPES.DROP then
        return Drops[inventoryId]?.coords
    elseif inventoryType == Inventory.TYPES.STASH then
        return Inventories[inventoryId]?.coords
    else
        warn(("Unexpected inventory type - '%s'"):format(inventoryType))
    end
end







Inventory.GetNameIndex = function(source)
    return Inventory.PlayerNameIndexes[source]
end

Inventory.BuildNameIndex = function(source, items)
    local index = {}

    for slot, item in pairs(items or {}) do
        if item and item.name then
            local name = item.name:lower()
            index[name] = index[name] or {}
            index[name][slot] = item
        end
    end
	
	Inventory.PlayerNameIndexes[source] = index
	return index
end

--- Adds or updates an item reference in the player name index.
--- @param player table RSGCore player object
--- @param item table Item data
Inventory.NameIndexAdd = function(source, item)
    if not source or not item or not item.name or not item.slot then
        return
    end

    local index = Inventory.PlayerNameIndexes[source]
    if not index then
        index = {}
        Inventory.PlayerNameIndexes[source] = index
    end

    local name = item.name:lower()
	index[name] = index[name] or {}
    index[name][item.slot] = item
end

--- Removes an item slot from the player name index.
--- @param player table RSGCore player object
--- @param itemName string Item name
--- @param slot number Item slot
Inventory.NameIndexRemove = function(source, itemName, slot)
    if not source or not itemName or not slot then
        return
    end

    local index = Inventory.PlayerNameIndexes[source]
    if not index then return end

    local name = itemName:lower()
    local itemsBySlot = index[name]

    if not itemsBySlot then return end

    itemsBySlot[tonumber(slot)] = nil

    -- Удаляем ключ имени, если предметов этого типа больше нет
    if not next(itemsBySlot) then
        index[name] = nil
    end
end

--- Replaces the indexed reference after amount/info update.
--- Нужен для полной ясности, хотя при ссылке на ту же таблицу часто не обязателен.
--- @param player table RSGCore player object
--- @param item table Item data
Inventory.NameIndexUpdate = function(source, item)
    Inventory.NameIndexAdd(source, item)
end


AddEventHandler('playerDropped', function()
    Inventory.PlayerNameIndexes[source] = nil
end)




--На будущее для чека изменений в инвентаре
Inventory.NotifyItemChanged = function(source, itemName, payload)
    if not source or not itemName then return end
    payload = payload or {}
    payload.item = tostring(itemName):lower()

    local total = 0
    local index = Inventory.GetNameIndex(source)
    local stacks = index and index[payload.item]

    if stacks then
        for _, itemData in pairs(stacks) do
            total = total + (tonumber(itemData.amount) or 0)
        end
    end

    payload.total = total

    TriggerEvent('rsg-inventory:server:itemChanged', source, payload.item, payload)
    TriggerClientEvent('rsg-inventory:client:itemChanged', source, payload.item, payload)
end

Inventory.NotifyInventoryChanged = function(source, payload)
    if not source then return end
    payload = payload or {}

    TriggerEvent('rsg-inventory:server:inventoryChanged', source, payload)
    TriggerClientEvent('rsg-inventory:client:inventoryChanged', source, payload)
end
