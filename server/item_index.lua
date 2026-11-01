local RSGCore = exports['rsg-core']:GetCoreObject()
Inventory.PlayerIndexes = {}
Inventory.IndexByItems = setmetatable({}, { __mode = 'k' })
local decayCheckedAt = {}
local checkingDecay = {}

-- Вычитает старый снимок слота из количества, веса и занятости.
-- Снимок нужен, даже если исходная таблица предмета уже была изменена внешним кодом.
local function unindexSlot(index, slot)
    local old = index.snapshots[slot]
    if not old then return end
    index.counts[old.name] = (index.counts[old.name] or 0) - old.amount
    if index.counts[old.name] <= 0 then index.counts[old.name] = nil end
    index.weight = index.weight - old.weight * old.amount
    index.usedSlots = index.usedSlots - 1
    local named = index.names[old.name]
    if named then named[slot] = nil; if not next(named) then index.names[old.name] = nil end end
    if index.firstSlots[old.name] == slot then
        index.firstSlots[old.name] = nil
        for candidate in pairs(index.names[old.name] or {}) do
            if not index.firstSlots[old.name] or candidate < index.firstSlots[old.name] then index.firstSlots[old.name] = candidate end
        end
    end
    index.snapshots[slot], index.decaying[slot] = nil, nil
end

-- Вносит актуальный слот в индекс: имя → стаки, сумма, первый слот, вес и decay.
-- Повторное добавление сначала убирает прежний снимок, поэтому количество не задваивается.
local function indexSlot(index, slot, item)
    unindexSlot(index, slot)
    if not item or not item.name then return end
    local name = item.name:lower()
    local amount, weight = tonumber(item.amount) or 0, tonumber(item.weight) or 0
    index.snapshots[slot] = { name = name, amount = amount, weight = weight }
    index.names[name] = index.names[name] or {}
    index.names[name][slot] = item
    if not index.firstSlots[name] or slot < index.firstSlots[name] then index.firstSlots[name] = slot end
    index.counts[name] = (index.counts[name] or 0) + amount
    index.usedSlots = index.usedSlots + 1
    index.weight = index.weight + weight * amount
    local definition = RSGCore.Shared.Items[name]
    if definition and definition.decay then index.decaying[slot] = true end
end

-- Полностью пересобирает индекс игрока после загрузки или замены items.
-- Это единственный общий проход при синхронизации; любые имена попадают сюда автоматически.
-- Слабая таблица IndexByItems позволяет GetTotalWeight узнавать уже посчитанный инвентарь.
function Inventory.BuildNameIndex(source, items)
    source = tonumber(source) or source
    items = items or {}
    local old = Inventory.PlayerIndexes[source]
    if old then Inventory.IndexByItems[old.items] = nil end
    local index = { items = items, names = {}, counts = {}, firstSlots = {}, snapshots = {}, decaying = {}, weight = 0, usedSlots = 0 }
    for slot, item in pairs(items) do indexSlot(index, slot, item) end
    Inventory.PlayerIndexes[source] = index
    Inventory.PlayerNameIndexes[source] = index.names
    Inventory.IndexByItems[items] = index
    return index.names
end

-- Возвращает индекс по source без запроса всего объекта игрока при каждом чтении.
-- Ссылки items из разных GetPlayer несопоставимы: Cfx передаёт копии между ресурсами.
-- Актуальность поддерживают SetPlayerData, штатные операции и очистка при выходе ниже.
function Inventory.GetPlayerIndex(source)
    source = tonumber(source) or source
    local index = Inventory.PlayerIndexes[source]
    if index then return index end
    local player = RSGCore.Functions.GetPlayer(source)
    if not player then return nil end
    Inventory.BuildNameIndex(source, player.PlayerData.items)
    return Inventory.PlayerIndexes[source]
end

-- Возвращает внутренние группы слотов по имени для существующих интеграций.
function Inventory.GetNameIndex(source)
    local index = Inventory.GetPlayerIndex(source)
    return index and index.names
end

-- Читает готовую сумму по имени за O(1), без прохода по слотам или стакам.
function Inventory.GetIndexedAmount(source, name)
    local index = Inventory.GetPlayerIndex(source)
    return index and index.counts[tostring(name):lower()] or 0
end

-- Обновляет один слот после изменения предмета, сохраняя остальные группы индекса.
function Inventory.NameIndexAdd(source, item)
    if not item or not item.slot then return end
    local index = Inventory.GetPlayerIndex(source)
    if index then indexSlot(index, item.slot, item) end
end

-- Удаляет снимок конкретного слота после удаления предмета из живого инвентаря.
function Inventory.NameIndexRemove(source, name, slot)
    local index = Inventory.GetPlayerIndex(source)
    if index then unindexSlot(index, tonumber(slot) or slot) end
end

Inventory.NameIndexUpdate = Inventory.NameIndexAdd

-- Проверяет только слоты портящихся предметов, не чаще одного раза в серверную секунду.
-- Защита checkingDecay не даёт обработчикам состояний рекурсивно запустить ту же проверку.
function Inventory.CheckPlayerItemsDecay(player)
    local src, now = player.PlayerData.source, os.time()
    if checkingDecay[src] or decayCheckedAt[src] == now then return end
    local index = Inventory.GetPlayerIndex(src)
    if not index then return end
    checkingDecay[src], decayCheckedAt[src] = true, now
    local changed, removed = false, {}
    for slot in pairs(index.decaying) do
        local item = player.PlayerData.items[slot]
        if item then
            local updated, quality, delete = Inventory.CheckItemDecay(item, nil, now)
            changed = changed or updated
            if updated and delete and quality <= 0 then
                player.PlayerData.items[slot] = nil
                unindexSlot(index, slot)
                removed[#removed + 1] = item
            end
        end
    end
    if changed then player.Functions.SetPlayerData('items', player.PlayerData.items) end
    checkingDecay[src] = nil
    for _, item in ipairs(removed) do
        if Inventory.ItemStates then Inventory.ItemStates.OnItemChanged(src, item.name) end
        Inventory.NotifyItemChanged(src, item.name, { action = 'remove', amount = item.amount, slot = item.slot, reason = 'decay' })
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item.name], 'remove', item.amount)
    end
end

-- Очищает индекс и ограничения decay при выходе; новый игрок с тем же source начнёт с нуля.
local function clear(source)
    source = tonumber(source) or source
    local index = Inventory.PlayerIndexes[source]
    if index then Inventory.IndexByItems[index.items] = nil end
    Inventory.PlayerIndexes[source], Inventory.PlayerNameIndexes[source] = nil, nil
    decayCheckedAt[source], checkingDecay[source] = nil, nil
end

-- Учитывает внешние SetPlayerData/UpdatePlayerData, включая изменения денег-предметов.
AddEventHandler('RSGCore:Player:SetPlayerData', function(data)
    if data and data.source and type(data.items) == 'table' then Inventory.BuildNameIndex(data.source, data.items) end
end)
AddEventHandler('RSGCore:Server:OnPlayerUnload', clear)
AddEventHandler('playerDropped', function() clear(source) end)
