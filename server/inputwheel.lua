local RSGCore = exports['rsg-core']:GetCoreObject()
-- server/inputwheel.lua
-- Internal input-wheel module for rsg-inventory.
-- Must load after server/functions.lua and server/exports.lua.
local InputWheelConfig = require 'shared.inputwheelconfig'

local WheelItems = InputWheelConfig.WheelItems or {}
local SyncConfig = InputWheelConfig.Sync or {}

local Wheel = {
    lastSignature = {},
    lastUseAt = {},
}

local function debugPrint(...)
    if InputWheelConfig.Debug then
        print('[rsg-inventory:inputwheel]', ...)
    end
end

local function normalizeItemName(itemName)
    if type(itemName) ~= 'string' then
        return nil
    end

    return itemName:lower()
end

local function getWheelItemConfig(itemName)
    itemName = normalizeItemName(itemName)

    if not itemName then
        return nil
    end

    return WheelItems and WheelItems[itemName] or nil
end

local function buildWheelSnapshot(source)
    local Player = RSGCore.Functions.GetPlayer(source)

    if not Player or not Player.PlayerData then
        return {}
    end

    -- Проверяем decay один раз на весь snapshot, а не на каждый wheel-item.
    -- В Inventory.GetItemAmountIndex этот check должен быть закомментирован/удалён.
    Inventory.CheckPlayerItemsDecay(Player)

    local snapshot = {}

    for itemName in pairs(WheelItems) do
        snapshot[itemName] = Inventory.GetItemAmountIndex(source, itemName)
    end

    return snapshot
end

local function buildSnapshotSignature(snapshot)
    local names = {}

    for itemName in pairs(WheelItems) do
        names[#names + 1] = itemName
    end

    table.sort(names)

    local parts = {}

    for _, itemName in ipairs(names) do
        parts[#parts + 1] = ('%s:%s'):format(
            itemName,
            tonumber(snapshot[itemName]) or 0
        )
    end

    return table.concat(parts, '|')
end

RegisterNetEvent('rsg-inventory:server:requestSync', function(force)
    Inventory.SyncInputWheel(source, force)
end)

function Inventory.SyncInputWheel(source, force)
    if not source then return false end

    local snapshot = buildWheelSnapshot(source)
    local signature = buildSnapshotSignature(snapshot)

    if force or Wheel.lastSignature[source] ~= signature then
        Wheel.lastSignature[source] = signature

        TriggerClientEvent('rsg-inventory:client:applySnapshot', source, snapshot)
        debugPrint('snapshot synced for player', source)
        return true
    end

    return false
end

function Inventory.UseInputWheelItem(source, itemName)
    source = tonumber(source)
    itemName = normalizeItemName(itemName)

    if not source or not itemName then
        return false
    end

    -- Клиент может отправить любое имя: разрешаем только предметы из WheelItems.
    if not getWheelItemConfig(itemName) then
        debugPrint('blocked non-wheel item', source, tostring(itemName))
        Inventory.SyncInputWheel(source, true)

        return false
    end

    local now = GetGameTimer()
    local cooldown = tonumber(SyncConfig and SyncConfig.UseCooldownMs) or 350
    local lastUse = Wheel.lastUseAt[source]

    if lastUse and (now - lastUse) < cooldown then
        return false
    end

    -- Готовая inventory-функция:
    -- GetNameIndex -> BuildNameIndex fallback -> itemName -> минимальный slot.
    local indexedItem = Inventory.GetItemByName(source, itemName)

    if not indexedItem
        or not indexedItem.slot
        or (tonumber(indexedItem.amount) or 0) < 1 then
        Inventory.SyncInputWheel(source, true)

        return false
    end

    -- Получаем реальный предмет из PlayerData и одновременно выполняем
    -- стандартную single-item decay-проверку перед фактическим use.
    local actualItem = Inventory.GetItemBySlot(source, indexedItem.slot)

    if not actualItem
        or not actualItem.name
        or actualItem.name:lower() ~= itemName
        or (tonumber(actualItem.amount) or 0) < 1 then
        Inventory.SyncInputWheel(source, true)

        return false
    end

    Wheel.lastUseAt[source] = now

    -- Запускает callback, зарегистрированный через RSGCore.Functions.CreateUseableItem.
    -- Предмет снимается или изменяется внутри его штатного use-callback.
    Inventory.UseItem(actualItem.name, source, actualItem)
	
	TriggerClientEvent('rsg-inventory:client:showUsedNotification', source, itemName, 1)

    -- Callback может изменить amount, удалить стек, создать replacement-item и т.д.
    -- Поэтому после use отправляем новое состояние wheel.
    local syncDelay = tonumber(SyncConfig and SyncConfig.RequestAfterUseMs) or 700

    SetTimeout(syncDelay, function()
        if GetPlayerName(source) then
            Inventory.SyncInputWheel(source, true)
        end
    end)

    return true
end

--RegisterNetEvent('rsg-inventory:server:inputWheelRequestSync', function()
--    Inventory.SyncInputWheel(source, true)
--end)

RegisterNetEvent('rsg-inventory:server:inputWheelUseItem', function(itemName)
    Inventory.UseInputWheelItem(source, itemName)
end)

AddEventHandler('playerDropped', function()
    Wheel.lastSignature[source] = nil
    Wheel.lastUseAt[source] = nil
end)

--[[
CreateThread(function()
    local pollMs = tonumber(SyncConfig and SyncConfig.ServerPollMs) or 2000

    while true do
        Wait(pollMs)

        for _, playerId in ipairs(GetPlayers()) do
            local source = tonumber(playerId)

            if source then
                Inventory.SyncInputWheel(source, false)
            end
        end
    end
end)
--]]

AddEventHandler('rsg-inventory:server:itemChanged', function(source, itemName, payload)
    if not source or not getWheelItemConfig(itemName) then return end

    Inventory.SyncInputWheel(source, true)
end)

AddEventHandler('rsg-inventory:server:inventoryChanged', function(source, payload)
    if not source then return end

    Inventory.SyncInputWheel(source, true)
end)



CreateThread(function()
	--регистрируем наши часы для использования
    for _,data in pairs(InputWheelConfig.PocketWatches) do
        RSGCore.Functions.CreateUseableItem(data.item, function(source, item)
            local src = source
            TriggerClientEvent('rsg-inventory:client:inspectwatch', src, data)
        end)
    end

end)