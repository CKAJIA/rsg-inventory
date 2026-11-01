local RSGCore = exports['rsg-core']:GetCoreObject()
Inventory = Inventory or {}
local config = require 'shared.config'
-- Загружает сохранённые предметы и создаёт индекс, в том числе для пустого инвентаря.
Inventory.LoadInventory = function(source, citizenid)
    local inventory = MySQL.prepare.await('SELECT inventory FROM players WHERE citizenid = ?', { citizenid })
    inventory = json.decode(inventory)
    if not inventory or not next(inventory) then
        local empty = {}
        Inventory.BuildNameIndex(source, empty)
        return empty
    end

    local loadedInventory = {}
    local missingItems = {}

    local currentTime = os.time()

    for _, item in pairs(inventory) do
        if item and item.name then
            local itemInfo = RSGCore.Shared.Items[item.name:lower()]
            local updated, quality, delete = Inventory.CheckItemDecay(item, itemInfo, currentTime, config.ItemsDecayWhileOffline and 1 or 0)
            local check = not (updated and delete and quality <= 0)

            if itemInfo and check then
                loadedInventory[item.slot] = {
                    name = itemInfo['name'],
                    amount = item.amount,
                    info = item.info or '',
                    label = itemInfo['label'],
                    description = itemInfo['description'] or '',
                    weight = itemInfo['weight'],
                    type = itemInfo['type'],
                    unique = itemInfo['unique'],
                    useable = itemInfo['useable'],
                    squality = itemInfo['squality'],
                    image = itemInfo['image'],
                    shouldClose = itemInfo['shouldClose'],
                    slot = item.slot,
                    combinable = itemInfo['combinable']
                }
            else
                missingItems[#missingItems + 1] = item.name:lower()
            end
        end
    end

    if #missingItems > 0 then
        print(('The following items were removed for player %s as they no longer exist: %s'):format(GetPlayerName(source), table.concat(missingItems, ', ')))
    end
	
	Inventory.BuildNameIndex(source, loadedInventory)

    return loadedInventory
end

exports('LoadInventory', Inventory.LoadInventory)

Inventory.SaveInventory = function(source, offline)
    local PlayerData
    if offline then
        PlayerData = source
    else
        local Player = RSGCore.Functions.GetPlayer(source)
        if not Player then return end
        PlayerData = Player.PlayerData
    end

    local items = PlayerData.items
    local ItemsJson = {}

    if items and next(items) then
        for slot, item in pairs(items) do
            if item then
                ItemsJson[#ItemsJson + 1] = {
                    name = item.name,
                    amount = item.amount,
                    info = type(item.info) == "table" and item.info or {},
                    type = item.type,
                    slot = slot,
                }
            end
        end
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode(ItemsJson), PlayerData.citizenid })
    else
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?', { '[]', PlayerData.citizenid })
    end
end

exports('SaveInventory', Inventory.SaveInventory)

--- Заменяет содержимое инвентаря игрока.
--- @param source number
--- @param items table
-- Заменяет все items, пересобирает индекс и оповещает состояния и подписчиков.
-- Используйте этот API для массовых изменений вместо прямого редактирования PlayerData.items.
Inventory.SetInventory = function(source, items)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end

	-- Строим индекс переданной таблицы перед синхронизацией PlayerData.
	Inventory.BuildNameIndex(source, items)
	---------------------------------------------------------------
    Player.Functions.SetPlayerData('items', items)
	
	if Inventory.ItemStates then
		Inventory.ItemStates.OnInventoryChanged(source)
	end
	
	Inventory.NotifyInventoryChanged(source, {action = 'set'})

    if not Player.Offline then
        local logMessage = string.format('**%s (citizenid: %s | id: %s)** items set: %s', GetPlayerName(source), Player.PlayerData.citizenid, source, json.encode(items))
        TriggerEvent('rsg-log:server:CreateLog', 'playerinventory', 'SetInventory', 'blue', logMessage)
    end
end

exports('SetInventory', Inventory.SetInventory)

-- Меняет значение поля предмета игрока.
--- @param source number
--- @param itemName string
--- @param key string
--- @param val any
--- @return boolean|nil
-- Меняет поле первого найденного предмета и синхронизирует индекс.
-- Поля name и slot запрещены: они меняют структуру индекса. Для метаданных передайте key = info.
Inventory.SetItemData = function(source, itemName, key, val)
    if not itemName or not key then return false end
    if key == 'name' or key == 'slot' then return false end

    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end

    local item = Inventory.GetItemByName(source, itemName)
    if not item then return false end

    item[key] = val
    Player.PlayerData.items[item.slot] = item
    Inventory.NameIndexUpdate(source, item)
	if Inventory.ItemStates then
		Inventory.ItemStates.OnItemChanged(source, item.name)
	end

    Player.Functions.SetPlayerData('items', Player.PlayerData.items)
    return true
end

exports('SetItemData', Inventory.SetItemData)

--- Возвращает вес единицы предмета из общего описания.
--- @param itemName string
--- @return number|nil
Inventory.GetItemWeight = function(itemName)
    itemName = itemName:lower()
    local itemInfo = RSGCore.Shared.Items[itemName]
    if itemInfo then
        return itemInfo.weight
    else
        return nil
    end
end

exports('GetItemWeight', Inventory.GetItemWeight)

Inventory.UseItem = function(itemName, ...)
    local itemData = RSGCore.Functions.CanUseItem(itemName)
    local callback = type(itemData) == 'table' and (rawget(itemData, '__cfx_functionReference') and itemData or itemData.cb or itemData.callback) or type(itemData) == 'function' and itemData
    if not callback then return end
    callback(...)
end

exports('UseItem', Inventory.UseItem)

-- Возвращает слоты указанного имени из переданной таблицы.
--- @param items table
--- @param itemName string
--- @return table
Inventory.GetSlotsByItem = function(items, itemName)
    local slotsFound = {}
    if not items then return slotsFound end
    for slot, item in pairs(items) do
        if item.name:lower() == itemName:lower() then
            slotsFound[#slotsFound + 1] = slot
        end
    end
    return slotsFound
end

exports('GetSlotsByItem', Inventory.GetSlotsByItem)

-- Возвращает первый найденный слот указанного имени.
--- @param items table
--- @param itemName string
--- @return number|nil
Inventory.GetFirstSlotByItem = function(items, itemName)
    if not items then return end
    for slot, item in pairs(items) do
        if item.name:lower() == itemName:lower() then
            return tonumber(slot)
        end
    end
    return nil
end

exports('GetFirstSlotByItem', Inventory.GetFirstSlotByItem)

--- Возвращает предмет игрока из указанного слота.
--- @param source number
--- @param slot number
--- @return table|nil
Inventory.GetItemBySlot = function(source, slot)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    local item = Player.PlayerData.items[tonumber(slot)]
    if not item then return end
    return Inventory.CheckPlayerItemDecay(Player, item)
end

exports('GetItemBySlot', Inventory.GetItemBySlot)

-- Для известной таблицы игрока читает готовый вес из индекса.
-- Для произвольного контейнера вычисляет вес проходом по его предметам.
Inventory.GetTotalWeight = function(items)
    if not items then return 0 end
    local cached = Inventory.IndexByItems and Inventory.IndexByItems[items]
    if cached then return cached.weight end
    local weight = 0
    for _, item in pairs(items) do
        weight = weight + (item.weight * item.amount)
    end
    return tonumber(weight)
end

exports('GetTotalWeight', Inventory.GetTotalWeight)

-- Возвращает первый предмет игрока по имени.
--- @param source number
--- @param item string
--- @return table|nil
--[[
Inventory.GetItemByName = function(source, item)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    local items = Player.PlayerData.items
    local slot = Inventory.GetFirstSlotByItem(items, tostring(item):lower())
    return items[slot]
end
--]]
-- Находит первый слот по имени через индекс; перед возвратом учитывает порчу предметов.
Inventory.GetItemByName = function(source, item)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end

    Inventory.CheckPlayerItemsDecay(Player)
    local index = Inventory.GetNameIndex(source)
    if not index then        
        index = Inventory.BuildNameIndex(source, Player.PlayerData.items)
    end

    local indexedItems = index and index[tostring(item):lower()]
    if not indexedItems then return end

    local totals = Inventory.GetPlayerIndex(source)
    return totals and indexedItems[totals.firstSlots[tostring(item):lower()]]
end


exports('GetItemByName', Inventory.GetItemByName)

-- Возвращает список стаков игрока по имени.
--- @param source number
--- @param item string
--- @return table|nil
--[[
Inventory.GetItemsByName = function(source, item)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    local PlayerItems = Player.PlayerData.items
    item = tostring(item):lower()
    local items = {}
    for _, slot in pairs(Inventory.GetSlotsByItem(PlayerItems, item)) do
        if slot then
            items[#items + 1] = PlayerItems[slot]
        end
    end
    return items
end
--]]
-- Собирает результат только из стаков нужного имени, без перебора остального инвентаря.
Inventory.GetItemsByName = function(source, item)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end

    Inventory.CheckPlayerItemsDecay(Player)
    local index = Inventory.GetNameIndex(source)
    if not index then
        index = Inventory.BuildNameIndex(source, Player.PlayerData.items)
    end

    local itemStacks = index and index[tostring(item):lower()]
    if not itemStacks then return {} end

    local items = {}

    for _, itemData in pairs(itemStacks) do
        items[#items + 1] = itemData
    end

    return items
end

exports('GetItemsByName', Inventory.GetItemsByName)

--- Возвращает число занятых и свободных слотов.
--- @param identifier number|string
--- @return number, number - The total count of used slots and the total count of free slots. If no inventory is found, returns 0 and the maximum slots.
-- Возвращает занятые и свободные слоты: для игрока берёт готовые счётчики.
-- Слоты сами по себе не показывают вместимость: для выдачи используйте CanAddItem с весом и info.
Inventory.GetSlots = function(identifier)
    local inventory, _, maxSlots, player = Inventory.GetContainerData(identifier)
    if not inventory then return 0, 0 end
    if player then
        Inventory.CheckPlayerItemsDecay(player)
        local index = Inventory.GetPlayerIndex(identifier)
        return index.usedSlots, math.max(0, maxSlots - index.usedSlots)
    end
    local used = 0
    for _ in pairs(inventory) do used = used + 1 end
    return used, math.max(0, maxSlots - used)
end

exports('GetSlots', Inventory.GetSlots)

--- Возвращает суммарное количество запрошенных предметов игрока.
--- @param source number
--- @param items table|string
--- @return number|nil
-- Суммирует количество запрошенного имени или списка имён по готовым счётчикам.
-- Одно имя не требует регистрации; повторённые в списке имена не удваивают результат.
Inventory.GetItemCount = function(source, items)
    local player = RSGCore.Functions.GetPlayer(source)
    if not player then return 0 end
    Inventory.CheckPlayerItemsDecay(player)
    if type(items) == 'string' then return Inventory.GetIndexedAmount(source, items) end
    local total, seen = 0, {}
    for _, name in pairs(type(items) == 'table' and items or {}) do
        name = tostring(name):lower()
        if not seen[name] then total = total + Inventory.GetIndexedAmount(source, name); seen[name] = true end
    end
    return total
end

exports('GetItemCount', Inventory.GetItemCount)


--- Получаем количество предмета по имени быстро из индексированой таблицы 
--- Возвращает сохранённую сумму всех стаков этого имени без повторного сложения.
-- Быстрый одиночный запрос количества по имени; сумма всех стаков уже хранится в индексе.
Inventory.GetItemAmountIndex = function(source, itemName)
    local player = RSGCore.Functions.GetPlayer(source)
    if not player then return 0 end
    Inventory.CheckPlayerItemsDecay(player)
    return Inventory.GetIndexedAmount(source, itemName)
end

exports('GetItemAmountIndex', Inventory.GetItemAmountIndex)


--- Проверяет вместимость без изменения инвентаря.
--- @param source number
--- @param item string
--- @param amount number
--- @return boolean
--- @return string|nil
-- Проверяет строгое размещение в инвентаре без выдачи и без сумки на землю.
-- Учитывает количество, вес, unique, свободные слоты и точную совместимость info.
-- Для игрока вес и занятость читаются из кеша; при полном инвентаре проверяются стаки этого имени.
-- Возвращает true либо false, причину: item, inventory, weight, slots, invalid_amount.
Inventory.CanAddItem = function(source, item, amount, info)
    if type(item) ~= 'string' then return false, 'item' end
    item, amount = item:lower(), Inventory.ValidAmount(amount, 1)
    local definition = RSGCore.Shared.Items[item]
    if not definition or not amount then return false, 'item' end
    local items, maxWeight, maxSlots, player = Inventory.GetContainerData(source)
    if not items then return false, 'inventory' end
    if player then Inventory.CheckPlayerItemsDecay(player); items = player.PlayerData.items end
    local index = player and Inventory.GetPlayerIndex(source)
    -- Таблица items из GetPlayer может быть копией: вес игрока читаем по source из индекса.
    local weight = index and index.weight or Inventory.GetTotalWeight(items)
    if weight + (definition.weight or 0) * amount > maxWeight then return false, 'weight' end
    local used = index and index.usedSlots or 0
    if not index then for _ in pairs(items) do used = used + 1 end end
    local free = maxSlots - used
    if definition.unique then
        local prepared = Inventory.PrepareItemInfo(definition, info)
        if amount > 1 and prepared.serie then return false, 'invalid_amount' end
        return free >= amount, free < amount and 'slots' or nil
    end
    if free > 0 then return true end
    info = Inventory.PrepareItemInfo(definition, info)
    local candidates = index and index.names[item] or items
    for _, existing in pairs(candidates or {}) do
        if Inventory.CanStackItem(existing, item, info) then return true end
    end
    return false, 'slots'
end

exports('CanAddItem', Inventory.CanAddItem)

--- Возвращает свободный вес игрока.
--- @param source number
--- @return number
-- Возвращает остаток веса из индекса игрока после проверки порчи предметов.
Inventory.GetFreeWeight = function(source)
    if not source then
        warn('Source was not passed into GetFreeWeight')
        return 0
    end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return 0 end

    Inventory.CheckPlayerItemsDecay(Player)
    -- Не ищем копию таблицы items в слабом индексе: source остаётся стабильным ключом.
    local totalWeight = Inventory.GetPlayerIndex(source).weight
    local freeWeight = Player.PlayerData.weight - totalWeight
    return freeWeight
end

exports('GetFreeWeight', Inventory.GetFreeWeight)

-- Очищает инвентарь с возможным фильтром сохранения и пересобирает индекс и состояния.
Inventory.ClearInventory = function(source, filterItems)
    local player = RSGCore.Functions.GetPlayer(source)
    local savedItemData = {}
    if filterItems then
        if type(filterItems) == 'string' then
            local item = Inventory.GetItemByName(source, filterItems)
            if item then savedItemData[item.slot] = item end
        elseif type(filterItems) == 'table' then
            for _, itemName in ipairs(filterItems) do
                local item = Inventory.GetItemByName(source, itemName)
                if item then savedItemData[item.slot] = item end
            end
        end
    end
	Inventory.BuildNameIndex(source, savedItemData)
    player.Functions.SetPlayerData('items', savedItemData)
	-- Инвентарь заменён целиком: пересчитываем все правила.
	if Inventory.ItemStates then
		Inventory.ItemStates.OnInventoryChanged(source)
	end
	Inventory.NotifyInventoryChanged(source, {action = 'clear'})
	
    if not player.Offline then
        local logMessage = string.format('**%s (citizenid: %s | id: %s)** inventory cleared', GetPlayerName(source), player.PlayerData.citizenid, source)
        TriggerEvent('rsg-log:server:CreateLog', 'playerinventory', 'ClearInventory', 'red', logMessage)
        local ped = GetPlayerPed(source)
        local weapon = GetSelectedPedWeapon(ped)
        if weapon ~= `WEAPON_UNARMED` then
            RemoveWeaponFromPed(ped, weapon)
        end
        if Player(source).state.inv_busy then TriggerClientEvent('rsg-inventory:client:updateInventory', source) end
    end
end

exports('ClearInventory', Inventory.ClearInventory)

--- Проверяет наличие одного или нескольких предметов.
--- @param source number
--- @param items string|table
--- @param amount number
--- @return boolean
--[[
Inventory.HasItem = function(source, items, amount)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end
    Inventory.CheckPlayerItemsDecay(Player)

    local isTable = type(items) == 'table'
    local isArray = isTable and table.type(items) == 'array' or false
    local totalItems = isArray and #items or 0
    local count = 0

    if isTable and not isArray then
        for _ in pairs(items) do totalItems = totalItems + 1 end
    end

    for _, itemData in pairs(Player.PlayerData.items) do
        if isTable then
            for k, v in pairs(items) do
                if itemData and itemData.name == (isArray and v or k) and ((amount and itemData.amount >= amount) or (not isArray and itemData.amount >= v) or (not amount and isArray)) then
                    count = count + 1
                    if count == totalItems then
                        return true
                    end
                end
            end
        else -- Одно имя строкой.
            if itemData and itemData.name == items and (not amount or (itemData and amount and itemData.amount >= amount)) then
                return true
            end
        end
    end

    return false
end
--]]

--- Проверяет наличие через индекс суммарных количеств.
--- @param source number
--- @param amount number|nil
--- @return boolean
-- Проверяет готовые суммы по всем стакам: строка, список имён или таблица требований.
-- anyItem = true означает «достаточно одного требования», иначе нужны все.
-- Регистрация ItemState для обычных HasItem и GetItemCount не требуется.
Inventory.HasItem = function(source, items, amount, anyItem)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end
    Inventory.CheckPlayerItemsDecay(Player)
    local function hasAmount(itemName, requiredAmount)
        requiredAmount = tonumber(requiredAmount) or 1
        return requiredAmount >= 0 and Inventory.GetIndexedAmount(source, itemName) >= requiredAmount
    end

    -- Один предмет
    if type(items) == 'string' then
        return hasAmount(items, tonumber(amount) or 1)
    end

    if type(items) ~= 'table' then
        return false
    end

    local isArray = table.type(items) == 'array'

    -- Массив имён:
    -- { 'bread', 'water', 'coffee' }
    if isArray then
        local requiredAmount = tonumber(amount) or 1

        -- Нужно хотя бы одно имя из списка
        if anyItem then
            for _, itemName in ipairs(items) do
                if hasAmount(itemName, requiredAmount) then
                    return true
                end
            end

            return false
        end

        -- Нужны все имена из списка
        for _, itemName in ipairs(items) do
            if not hasAmount(itemName, requiredAmount) then
                return false
            end
        end

        return true
    end

    -- Таблица требований:
    -- { bread = 5, water = 2 }
    -- Здесь anyItem тоже можно поддержать логично:
    -- true = достаточно выполнить хотя бы одно требование.
    if anyItem then
        for itemName, requiredAmount in pairs(items) do
            if hasAmount(itemName, tonumber(requiredAmount) or 1) then
                return true
            end
        end

        return false
    end

    -- Нужны все требования таблицы
    for itemName, requiredAmount in pairs(items) do
        if not hasAmount(itemName, tonumber(requiredAmount) or 1) then
            return false
        end
    end

    return true
end

--[[
-- Есть ли хотя бы 1 bread
Player.Functions.HasItem('bread')
-- Один конкретный предмет: минимум 5 суммарно по всем стакам
Player.Functions.HasItem('bread', 5)
-- Все предметы списка: по 1 каждого
Player.Functions.HasItem({'bread', 'water', 'coffee'})
-- Все предметы списка: минимум по 3 каждого
Player.Functions.HasItem({'bread', 'water', 'coffee'}, 3)
-- Любой один предмет из списка: минимум 1
Player.Functions.HasItem({'pocketwatch1', 'pocketwatch2'}, 1, true)
-- Нужны все требования
Player.Functions.HasItem({bread = 5, water = 2})
-- Достаточно выполнить одно требование
Player.Functions.HasItem({goldbar = 1, moneybag = 5}, nil, true)
--]]



exports('HasItem', Inventory.HasItem)

-- Закрывает интерфейс игрока и освобождает указанный контейнер.
-- Снимает флаг isOpen контейнера.
-- Снимает флаг inv_busy игрока.
-- Отправляет клиенту событие закрытия.
Inventory.CloseInventory = function(source, identifier)
    if identifier and Inventories[identifier] then
        Inventories[identifier].isOpen = false
    end
    Player(source).state.inv_busy = false
    TriggerClientEvent('rsg-inventory:client:closeInv', source)
end

exports('CloseInventory', Inventory.CloseInventory)

-- Открывает чужой инвентарь по ID; права должен проверить вызывающий серверный ресурс.
--- @param source number
--- @param targetId number
Inventory.OpenInventoryById = function(source, targetId)
    local RSGPlayer = RSGCore.Functions.GetPlayer(source)
    local TargetPlayer = RSGCore.Functions.GetPlayer(tonumber(targetId))
    if not RSGPlayer or not TargetPlayer then return end
    if Player(targetId).state.inv_busy then Inventory.CloseInventory(targetId) end
    Inventory.CheckPlayerItemsDecay(RSGPlayer)
    Inventory.CheckPlayerItemsDecay(TargetPlayer)
    local playerItems = RSGPlayer.PlayerData.items
    local targetItems = TargetPlayer.PlayerData.items
    local formattedInventory = {
        name = 'otherplayer-' .. targetId,
        label = (TargetPlayer.PlayerData.charinfo and TargetPlayer.PlayerData.charinfo.firstname)
            and (TargetPlayer.PlayerData.charinfo.firstname .. ' ' .. TargetPlayer.PlayerData.charinfo.lastname)
            or GetPlayerName(targetId),
        maxweight = TargetPlayer.PlayerData.weight,
        slots = TargetPlayer.PlayerData.slots,
        inventory = targetItems
    }
    Wait(1500)
    Player(targetId).state.inv_busy = true
    TriggerClientEvent('rsg-inventory:client:openInventory', source, playerItems, formattedInventory)
end

exports('OpenInventoryById', Inventory.OpenInventoryById)

-- Очищает содержимое существующего хранилища и обновляет его строку БД.
--- @param identifier string
Inventory.ClearStash = function(identifier)
    if not identifier then return end
    local inventory = Inventories[identifier]
    if not inventory then return end
    inventory.items = {}
    MySQL.prepare('UPDATE inventories SET items = ? WHERE identifier = ?', { json.encode(inventory.items), identifier })
end

exports('ClearStash', Inventory.ClearStash)

-- Сохраняет содержимое хранилища в БД.
--- @param identifier string
Inventory.SaveStash = function(identifier)
    if not identifier then return end
    local inventory = Inventories[identifier]
    if not inventory then return end
    local items = json.encode(inventory.items)
    MySQL.prepare("INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?",
        { identifier, items, items })
end

exports("SaveStash", Inventory.SaveStash)

--- @param source number
--- @param identifier string|nil
--- @param data table|nil
Inventory.OpenInventory = function (source, identifier, data)
    if Player(source).state.inv_busy then return end
    local RSGPlayer = RSGCore.Functions.GetPlayer(source)
    if not RSGPlayer then return end

    if not identifier then
        Player(source).state.inv_busy = true
        Inventory.CheckPlayerItemsDecay(RSGPlayer)
        TriggerClientEvent('rsg-inventory:client:openInventory', source, RSGPlayer.PlayerData.items)
        return
    end

    if type(identifier) ~= 'string' then
        print('Inventory tried to open an invalid identifier')
        return
    end

    local inventory = Inventories[identifier]

    if inventory and inventory.isOpen then
        TriggerClientEvent('ox_lib:notify', source, { title = locale('error.access_denied') or locale('error.error'), type = 'error', duration = 5000 })
        return
    end

    if not inventory then 
        inventory = Inventory.InitializeInventory(identifier, data) 
    else
        local decayRate = Helpers.ParseDecayRate(identifier)
        Inventory.CheckItemsDecay(inventory.items, decayRate or 1)
    end
    inventory.maxweight = (data and data.maxweight) or (inventory and inventory.maxweight) or config.StashSize.maxweight
    inventory.slots = (data and data.slots) or (inventory and inventory.slots) or config.StashSize.slots
    inventory.label = (data and data.label) or (inventory and inventory.label) or identifier
    inventory.isOpen = source

    local formattedInventory = {
        name = identifier,
        label = inventory.label,
        maxweight = inventory.maxweight,
        slots = inventory.slots,
        inventory = inventory.items
    }
    
    Player(source).state.inv_busy = true
    Inventory.CheckPlayerItemsDecay(RSGPlayer)
    TriggerClientEvent('rsg-inventory:client:openInventory', source, RSGPlayer.PlayerData.items, formattedInventory)
end

exports('OpenInventory', Inventory.OpenInventory)

-- Выдаёт новую награду в сумку у игрока; не списывает её из его инвентаря.
-- Сначала готовит все предметы сумки, включая отдельные слоты unique и номера оружия.
-- Создание сумки считается успехом только после получения сетевого ID.
-- Возвращает networkId либо false; функция не удаляет предметы из инвентаря игрока.
Inventory.ForceDropItem = function(source, item, amount, info, reason)
    amount = Inventory.ValidAmount(amount, 1)
    if not amount or type(item) ~= 'string' then return false end
    item = item:lower()
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)

    -- Получаем описание предмета из RSG Core.
    local itemInfo = RSGCore.Shared.Items[item:lower()]
    if not itemInfo then return false end

    -- Подготавливаем награду целиком до создания сумки. Для unique выделяются отдельные
    -- слоты и номера оружия; если награда не помещается в сумку, частичной выдачи нет.
    local dropItems = Inventory.PlanAddItem({}, config.DropSize.maxweight, config.DropSize.slots,
        item, amount, false, info)
    if not dropItems then return false end
    local itemData = dropItems[1]
    local networkId = Helpers.CreateItemDrop(coords, itemData, false, nil, dropItems)

    if not networkId then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            title = locale('error.error'),
            description = locale('error.inventory_force_drop_failed'),
            duration = 7000
        })
        return false
    end

    -- Записываем выдачу награды в сумку в журнал.
    local logMessage = string.format('**%s (citizenid: %s | id: %s)** item force dropped due to full inventory: %s x%s at %s',
        GetPlayerName(source), Player.PlayerData.citizenid, source, item, amount, coords)
    TriggerEvent('rsg-log:server:CreateLog', 'playerinventory', 'Force Drop', 'orange', logMessage)

    -- Сообщаем игроку, что награда находится в сумке на земле.
    TriggerClientEvent('ox_lib:notify', source, {
        type = 'warning',
        title = locale('error.inventory_full'),
        description = locale('error.inventory_force_drop'),
        duration = 5000
    })

    return networkId
end

exports('ForceDropItem', Inventory.ForceDropItem)

--- Выдаёт предмет игроку или в существующий контейнер.
--- @param identifier string
--- @param item string
--- @param amount number
--- @param slot number
--- @param info table
--- @param reason string
--- @param allowDrop boolean|nil
--- @return boolean
--- @return string
--- @return number|nil
-- Выдаёт предмет в инвентарь; обычная награда при переполнении может попасть в сумку.
-- Успех: true, inventory либо true, dropped, networkId. Отказ: false, причина.
-- Нельзя повторять выдачу/откатывать исходный предмет после true, dropped — награда уже выдана.
-- allowDrop = false запрещает сумку; для операций с чужими предметами используйте AddItemStrict.
Inventory.AddItem = function(identifier, item, amount, slot, info, reason, allowDrop)
    if type(item) ~= 'string' then return false end
    item, amount = item:lower(), Inventory.ValidAmount(amount, 1)
    if not amount or not RSGCore.Shared.Items[item] then return false end
    local inventory, inventoryWeight, inventorySlots, player = Inventory.GetContainerData(identifier)
    if not inventory then return false end
    if player then Inventory.CheckPlayerItemsDecay(player); inventory = player.PlayerData.items
    else Inventory.CheckItemsDecay(inventory, Helpers.ParseDecayRate(tostring(identifier)) or 1) end
    local plan, result = Inventory.PlanAddItem(inventory, inventoryWeight, inventorySlots, item, amount, slot, info)
    if not plan then
        if player and allowDrop ~= false and config.AutoDropOnFull ~= false
            and (result == 'weight' or result == 'slots') then
            local dropId = Inventory.ForceDropItem(identifier, item, amount, info, reason or 'reward overflow')
            if dropId then return true, 'dropped', dropId end
            return false, 'drop_failed'
        end
        return false, result
    end
    inventory, slot = plan, result
    if player then
        player.PlayerData.items = inventory
        Inventory.BuildNameIndex(identifier, inventory)
    elseif Inventories[identifier] then Inventories[identifier].items = inventory
    else Drops[identifier].items = inventory end

    if player then
		-- slot уже содержит либо новый предмет, либо обновлённый стак
		local indexedItem = inventory[slot]
	
		if indexedItem then
			Inventory.NameIndexAdd(identifier, indexedItem)
		end
		--------------------------------------------------------------
		player.Functions.SetPlayerData('items', inventory)
		--проверка состояния нужных предметов(есть ли они в инвентаре)
		--нужно именно здесь
		if player and Inventory.ItemStates then
			Inventory.ItemStates.OnItemChanged(identifier, item)
		end
		
		Inventory.NotifyItemChanged(identifier, item, {
			action = 'add',
			amount = amount,
			slot = slot,
			reason = reason,
			info = inventory[slot] and inventory[slot].info
		})
		
		TriggerEvent('rsg-inventory:server:updateHotbar', identifier)
	end
    local invName = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
    local addReason = reason or 'No reason specified'
    local resourceName = GetInvokingResource() or 'rsg-inventory'
    TriggerEvent(
        'rsg-log:server:CreateLog',
        'playerinventory',
        'Item Added',
        'green',
        '**Inventory:** ' .. invName .. ' (Slot: ' .. slot .. ')\n' ..
        '**Item:** ' .. item .. '\n' ..
        '**Amount:** ' .. amount .. '\n' ..
        '**Reason:** ' .. addReason .. '\n' ..
        '**Resource:** ' .. resourceName
    )

    return true, 'inventory'
end

exports('AddItem', Inventory.AddItem)

-- Передача, покупка и перемещение не должны создавать неявную сумку при отказе.
-- Та же сигнатура первых шести аргументов, что у AddItem.
-- При нехватке места возвращает false и не создаёт предмет в мире.
-- Подходит для сбора с блокировкой, покупок и перемещений; проверяйте результат выдачи.
Inventory.AddItemStrict = function(identifier, item, amount, slot, info, reason)
    return Inventory.AddItem(identifier, item, amount, slot, info, reason, false)
end
exports('AddItemStrict', Inventory.AddItemStrict)


-- Удаляет указанное количество предмета.
--- @param identifier string
--- @param item string
--- @param amount number
--- @param slot number
--- @param reason string
--- @return boolean
-- Сначала планирует всё списание, затем применяет его и обновляет индекс и события.
-- Если количества не хватает, исходные items не меняются. slot ограничивает списание этим слотом.
Inventory.RemoveItem = function(identifier, item, amount, slot, reason, isMove)
    if type(item) ~= 'string' then return false end
    item, amount = item:lower(), Inventory.ValidAmount(amount, 1)
    if not amount or not RSGCore.Shared.Items[item] then return false end
    local inventory, _, _, player = Inventory.GetContainerData(identifier)
    if not inventory then return false end
    if player then Inventory.CheckPlayerItemsDecay(player); inventory = player.PlayerData.items
    else Inventory.CheckItemsDecay(inventory, Helpers.ParseDecayRate(tostring(identifier)) or 1) end
    local plan, inventoryItem, removedSlot = Inventory.PlanRemoveItem(inventory, item, amount, slot)
    if not plan then return false end
    inventory, slot = plan, removedSlot
    if player then
        player.PlayerData.items = inventory
        Inventory.BuildNameIndex(identifier, inventory)
    elseif Inventories[identifier] then Inventories[identifier].items = inventory
    else Drops[identifier].items = inventory end

    if RSGCore.Shared.Items[item:lower()]['type'] == 'weapon' and player and isMove then
        TriggerClientEvent('rsg-core:client:RemoveWeaponFromTab', identifier, item)
    end

    if player then 
        player.Functions.SetPlayerData('items', inventory)
		--проверка состояния нужных предметов(есть ли они в инвентаре)
		--нужно именно здесь
		if player and Inventory.ItemStates then
			Inventory.ItemStates.OnItemChanged(identifier, item)
		end
		
		Inventory.NotifyItemChanged(identifier, item, {
			action = 'remove',
			amount = amount,
			slot = slot,
			reason = reason,
			isMove = isMove
		})
		
		
		
		
        -- Хук для сторонних ресурсов после успешного списания предмета.
        -- Подписчик получает количество, слот, info, причину и признак перемещения.
        local data = {
            amount = amount,
            slot = slot,
            info = inventoryItem.info
        }
        TriggerEvent("rsg-inventory:server:itemRemovedFromPlayerInventory", identifier, item, data, reason, isMove)
		TriggerEvent('rsg-inventory:server:updateHotbar', identifier)
    end

    local invName = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
    local removeReason = reason or 'No reason specified'
    local resourceName = GetInvokingResource() or 'rsg-inventory'

    TriggerEvent(
        'rsg-log:server:CreateLog',
        'playerinventory',
        'Item Removed',
        'red',
        '**Inventory:** ' .. invName .. ' (Slot: ' .. slot .. ')\n' ..
        '**Item:** ' .. item .. '\n' ..
        '**Amount:** ' .. amount .. '\n' ..
        '**Reason:** ' .. removeReason .. '\n' ..
        '**Resource:** ' .. resourceName
    )
	
    return true
end

exports('RemoveItem', Inventory.RemoveItem)

Inventory.GetInventory = function(identifier)
    if not Inventories[identifier] then
        return nil
    end
    local decayRate = Helpers.ParseDecayRate(identifier)
    Inventory.CheckItemsDecay(Inventories[identifier].items, decayRate or 1)
    return Inventories[identifier]
end

exports('GetInventory', Inventory.GetInventory)

--- Создаёт или обновляет параметры контейнера.
--- @param identifier string
--- @param data table
Inventory.CreateInventory = function (identifier, data)
    if Inventories[identifier] then 
        if data.label then
            Inventories[identifier].label = data.label
        end

        if data.maxweight then
            Inventories[identifier].maxweight = data.maxweight
        end

        if data.slots then
            Inventories[identifier].slots = data.slots
        end
    else
        Inventories[identifier] = Inventory.InitializeInventory(identifier, data)
    end
end

exports('CreateInventory', Inventory.CreateInventory)

-- Удаляет контейнер из памяти Inventories, не из БД.
--- @param identifier string
Inventory.DeleteInventory = function(identifier)
    if Inventories[identifier] then
        Inventories[identifier] = nil
        print('[rsg-inventory] Deleted inventory: ' .. identifier)
        return true
    end
    return false
end

exports('DeleteInventory', Inventory.DeleteInventory)
-- Возвращает снимок слотов и веса игрока из кеша либо nil, если игрок не найден.
-- Предварительно проверяет decay, чтобы удалённые предметы не занимали место в результате.
Inventory.GetInventoryStats = function(source)
    local player = RSGCore.Functions.GetPlayer(source)
    if not player then return nil end
    Inventory.CheckPlayerItemsDecay(player)
    local index = Inventory.GetPlayerIndex(source)
    return {
        usedSlots = index.usedSlots, freeSlots = math.max(0, player.PlayerData.slots - index.usedSlots),
        maxSlots = player.PlayerData.slots, weight = index.weight, maxWeight = player.PlayerData.weight,
        freeWeight = math.max(0, player.PlayerData.weight - index.weight)
    }
end
exports('GetInventoryStats', Inventory.GetInventoryStats)
-- Восстанавливает только серверный индекс после нестандартной внешней правки.
-- Не синхронизирует клиента и не пересчитывает ItemState; обычным операциям этот вызов не нужен.
exports('RebuildInventoryIndex', function(source)
    local player = RSGCore.Functions.GetPlayer(source)
    if not player then return false end
    Inventory.BuildNameIndex(source, player.PlayerData.items)
    return true
end)
