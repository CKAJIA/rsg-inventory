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

-- Находит предмет в игроке или контейнере напрямую по слоту.
-- Перебор остаётся как совместимость со старыми таблицами, где ключ и item.slot различаются.
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

    slot = tonumber(slot)
    if items[slot] and items[slot].slot == slot then return items[slot] end
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
--- @return boolean expired Whether the item has reached 0% and should be deleted.
-- Перед расчётом нормализует info: у старых предметов вместо таблицы могла быть строка.
Inventory.CheckItemDecay = function(item, itemInfo, currentTime, decayRateModifier)
    item.info = type(item.info) == 'table' and item.info or {}
    itemInfo = itemInfo or RSGCore.Shared.Items[item.name:lower()]
    local minutes = InventoryRules.GetDecayMinutes(itemInfo)
    if not minutes then return false, nil, false end
    currentTime = currentTime or os.time()
    local info = item.info
    local updated = InventoryRules.ApplyDecay(info, minutes, currentTime, decayRateModifier)
    return updated, info.quality, itemInfo.delete == true and info.quality == 0
end

--- Applies decay to all items in an inventory.
--- @param items table<number, table> Inventory items (indexed by slot).
--- @param decayRateModifier number|nil Optional modifier for configured decay rate
--- @param slots table|nil Optional index of perishable slots.
--- @return boolean needsUpdate Returns true if any item was updated or deleted.
--- @return table removedItems Returns removed items.
Inventory.CheckItemsDecay = function(items, decayRateModifier, slots)
    local needsUpdate = false
    local currentTime = os.time()
    local removedItems = {}

    for slot in pairs(slots or items) do
        local item = items[slot]
        if item then
            local updated, _, expired = Inventory.CheckItemDecay(item, nil, currentTime, decayRateModifier)
            if expired then
                removedItems[slot] = item
                items[slot] = nil
            end
            needsUpdate = needsUpdate or updated or expired
        end
    end

    return needsUpdate, removedItems
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







-- Сообщает об успешном изменении одного имени; total уже посчитан индексом.
Inventory.NotifyItemChanged = function(source, itemName, payload)
    if not source or not itemName then return end
    payload = payload or {}
    payload.item = tostring(itemName):lower()

    local total = Inventory.GetIndexedAmount(source, payload.item)

    payload.total = total

    TriggerEvent('rsg-inventory:server:itemChanged', source, payload.item, payload)
    TriggerClientEvent('rsg-inventory:client:itemChanged', source, payload.item, payload)
end

-- Оповещает серверные и клиентские подписки о замене всего инвентаря.
-- Вызывается после обновления PlayerData и индекса; payload содержит контекст изменения.
Inventory.NotifyInventoryChanged = function(source, payload)
    if not source then return end
    payload = payload or {}

    TriggerEvent('rsg-inventory:server:inventoryChanged', source, payload)
    TriggerClientEvent('rsg-inventory:client:inventoryChanged', source, payload)
end

-- Список ограниченных хранилищ по префиксу identifier.
-- Используется и в SetInventoryData (перемещение предметов), и в openStash (открытие).
Inventory.RESTRICTED_STASH_PATTERNS = {
    { pattern = '^police%-',   type = 'police'   },
    { pattern = '^marshal%-',  type = 'marshal'  },
    { pattern = '^gang%-',     type = 'gang'     },
    { pattern = '^admin%-',    type = 'admin'    },
    { pattern = '^evidence%-', type = 'evidence' },
}

-- Возвращает тип ограниченного хранилища по его identifier, либо nil, если оно не ограничено.
function Inventory.GetRestrictedStashType(identifier)
    for _, entry in ipairs(Inventory.RESTRICTED_STASH_PATTERNS) do
        if identifier:match(entry.pattern) then
            return entry.type
        end
    end
    return nil
end

-- Проверяет доступ игрока к хранилищу данного ограниченного типа.
-- stashType == nil (хранилище не ограничено) никогда не вызывается отдельно — проверяется на месте вызова.
function Inventory.HasStashAccess(src, identifier, Player, stashType)
    if stashType == 'police' or stashType == 'marshal' then
        return RSGCore.Functions.HasPermission(src, 'police')
            or Player.PlayerData.job.name == 'police'
            or Player.PlayerData.job.name == 'marshal'
    elseif stashType == 'gang' then
        local gangName = identifier:match('gang%-(.+)%-')
        return Player.PlayerData.gang and Player.PlayerData.gang.name == gangName
    end
    -- admin и evidence используют одинаковую проверку, как и раньше (else-ветка в обоих местах).
    return RSGCore.Functions.HasPermission(src, 'admin')
end
