local RSGCore = exports['rsg-core']:GetCoreObject()
local indexedItems, amounts, namedItems, stackChecks = nil, {}, {}, {}
local usedSlots, totalWeight = 0, 0
local playerData, initialized = nil, false

-- Один проход по слотам при синхронизации PlayerData вместо прохода при каждом запросе.
-- Индекс автоматически содержит все предметы: предварительная регистрация имён не нужна.
local function rebuild(items)
    indexedItems, amounts, namedItems, stackChecks = items, {}, {}, {}
    usedSlots, totalWeight = 0, 0
    for _, item in pairs(items or {}) do
        if item and item.name then
            local name = item.name:lower()
            local amount = tonumber(item.amount) or 0
            amounts[name] = (amounts[name] or 0) + amount
            totalWeight = totalWeight + (tonumber(item.weight) or 0) * amount
            usedSlots = usedSlots + 1
            namedItems[name] = namedItems[name] or {}
            namedItems[name][#namedItems[name] + 1] = item
        end
    end
end

-- Межресурсный GetPlayerData возвращает сериализованную копию, а не общую таблицу.
-- Поэтому получаем её только при первом обращении/входе, затем принимаем события ядра.
-- В горячем пути нет вызова rsg-core и сравнения с заново полученной копией items.
local function getData()
    if not initialized then
        playerData = RSGCore.Functions.GetPlayerData()
        initialized = true
    end
    local items = playerData and playerData.items
    if items ~= indexedItems then rebuild(items) end
    return playerData
end

-- Только для функций этого ресурса: внешний экспорт не выдаёт весь снимок PlayerData.
function GetInventoryPlayerData()
    return getData()
end

-- Внутренний доступ HasItem к готовым суммам; вызывающие ресурсы получают только числа.
function GetInventoryItemAmounts()
    getData()
    return amounts
end

-- Число экземпляров по всем стакам локального игрока. Чтение не перебирает слоты.
exports('GetItemCount', function(name)
    return GetInventoryItemAmounts()[tostring(name):lower()] or 0
end)

-- Снимок вместимости локального игрока по последней синхронизации с сервером.
-- Возвращается новая таблица: внешний ресурс не может испортить внутренний кеш.
exports('GetInventoryStats', function()
    local data = getData()
    if not data or type(data.items) ~= 'table' or not data.slots or not data.weight then return nil end
    return {
        usedSlots = usedSlots, freeSlots = math.max(0, data.slots - usedSlots), maxSlots = data.slots,
        weight = totalWeight, freeWeight = math.max(0, data.weight - totalWeight), maxWeight = data.weight
    }
end)

-- Быстрая клиентская подсказка для композитов, промптов и кнопок интерфейса.
-- Проверяет вес, слоты, unique и совместимость info; ничего не выдаёт и не вызывает сервер.
-- При полном инвентаре первый запрос проверяет только стаки нужного имени и кеширует ответ.
-- Повторный запрос с теми же info использует кеш до следующего обновления PlayerData.
-- Это предварительный ответ: сервер повторно проверяет актуальные данные при AddItemStrict.
exports('CanAddItem', function(name, amount, info)
    if type(name) ~= 'string' then return false, 'item' end
    name, amount = name:lower(), InventoryRules.ValidAmount(amount, 1)
    local definition = RSGCore.Shared.Items[name]
    if not definition or not amount then return false, 'item' end
    local data = getData()
    if not data or type(data.items) ~= 'table' or not data.weight or not data.slots then return false, 'inventory' end
    if totalWeight + (definition.weight or 0) * amount > data.weight then return false, 'weight' end

    local free = data.slots - usedSlots
    if definition.unique then
        local prepared = InventoryRules.PrepareItemInfo(definition, info)
        if amount > 1 and prepared.serie then return false, 'invalid_amount' end
        return free >= amount, free < amount and 'slots' or nil
    end
    if free > 0 then return true end

    local cached = stackChecks[name]
    if cached and cached.definition == definition and cached.defaultInfo and info == nil then
        return cached.fits, not cached.fits and 'slots' or nil
    end
    local prepared = InventoryRules.PrepareItemInfo(definition, info)
    if cached and cached.definition == definition
        and InventoryRules.SameMetadata(cached.info, prepared, definition.decay ~= nil and definition.decay ~= false) then
        return cached.fits, not cached.fits and 'slots' or nil
    end
    local fits = false
    for _, existing in ipairs(namedItems[name] or {}) do
        if InventoryRules.CanStackItem(existing, name, prepared, definition) then fits = true; break end
    end
    stackChecks[name] = { definition = definition, info = prepared, defaultInfo = info == nil, fits = fits }
    return fits, not fits and 'slots' or nil
end)

-- Полная синхронизация обновляет кеш даже при сохранении прежней ссылки на таблицу items.
RegisterNetEvent('RSGCore:Player:SetPlayerData', function(data)
    playerData, initialized = data, true
    rebuild(data and data.items)
end)
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    playerData, initialized = RSGCore.Functions.GetPlayerData(), true
    rebuild(playerData and playerData.items)
end)
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    -- После выхода не подтягиваем старый снимок из ядра при очередном вызове композита.
    playerData, initialized = nil, true
    rebuild(nil)
end)
