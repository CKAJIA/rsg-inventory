local RSGCore = exports['rsg-core']:GetCoreObject()
--- @param items string|table - The item(s) to check for. Can be a table of items or a single item as a string.
--- @param amount number [optional] - The minimum amount required for each item. If not provided, any amount greater than 0 will be considered.
--- @return boolean - Returns true if the player has the item(s) with the specified amount, false otherwise.
--[[
function HasItem(items, amount)
    local function isArray(t)
        if type(t) ~= 'table' then return false end
        if table.type then return table.type(t) == 'array' end
        local n = 0
        for k in pairs(t) do
            if type(k) ~= 'number' then return false end
            if k > n then n = k end
        end
        return n == #t
    end

    local playerData = RSGCore.Functions.GetPlayerData()
    local inv = playerData and playerData.items
    if not inv then return false end

    local itemsType = type(items)

    if itemsType ~= 'table' then
        for _, item in pairs(inv) do
            if item and item.name == items and (amount == nil or item.amount >= amount) then
                return true
            end
        end
        return false
    end


    local maxByName = {}
    for _, item in pairs(inv) do
        if item and item.name then
            local amt = item.amount or 0
            if not maxByName[item.name] or amt > maxByName[item.name] then
                maxByName[item.name] = amt
            end
        end
    end

    if isArray(items) then
        for _, name in ipairs(items) do
            local have = maxByName[name]
            if have == nil or (amount ~= nil and have < amount) then
                return false
            end
        end
        return true
    else
        for name, reqAmount in pairs(items) do
            local have = maxByName[name]
            if have == nil or (reqAmount ~= nil and have < reqAmount) then
                return false
            end
        end
        return true
    end
end

exports('HasItem', HasItem)
--]]

--- Checks local player inventory.
--- @param items string|table
--- @param amount number|nil Required amount for string or every array item
--- @param anyItem boolean|nil True = enough to have any one item from array/map
--- @return boolean
function HasItem(items, amount, anyItem)
    local playerData = RSGCore.Functions.GetPlayerData()
    local inventory = playerData and playerData.items

    if not inventory then
        return false
    end

    local function isArray(tbl)
        if type(tbl) ~= 'table' then
            return false
        end

        if table.type then
            return table.type(tbl) == 'array'
        end

        local count = 0

        for key in pairs(tbl) do
            if type(key) ~= 'number' then
                return false
            end

            count = count + 1
        end

        return count == #tbl
    end

    -- Строим временный индекс количества по имени.
    -- Клиент не хранит PlayerData.itemsByName, поэтому собираем только sums.
    local amountsByName = {}

    for _, item in pairs(inventory) do
        if item and item.name then
            local name = item.name:lower()
            amountsByName[name] = (amountsByName[name] or 0) + (tonumber(item.amount) or 0)
        end
    end

    local function hasAmount(itemName, requiredAmount)
        local name = tostring(itemName):lower()
        local total = amountsByName[name] or 0

        return total >= (tonumber(requiredAmount) or 1)
    end

    -- Один предмет
    if type(items) == 'string' then
        return hasAmount(items, amount)
    end

    if type(items) ~= 'table' then
        return false
    end

    -- Массив:
    -- { 'bread', 'water' }
    if isArray(items) then
        local requiredAmount = tonumber(amount) or 1

        -- Достаточно одного подходящего предмета из списка
        if anyItem then
            for _, itemName in ipairs(items) do
                if hasAmount(itemName, requiredAmount) then
                    return true
                end
            end

            return false
        end

        -- Нужны все предметы списка
        for _, itemName in ipairs(items) do
            if not hasAmount(itemName, requiredAmount) then
                return false
            end
        end

        return true
    end

    -- Map:
    -- { bread = 5, water = 2 }
    if anyItem then
        for itemName, requiredAmount in pairs(items) do
            if hasAmount(itemName, requiredAmount) then
                return true
            end
        end

        return false
    end

    for itemName, requiredAmount in pairs(items) do
        if not hasAmount(itemName, requiredAmount) then
            return false
        end
    end

    return true
end

exports('HasItem', HasItem)


--[[
function HasItem(items, amount, any)
    local function isArray(t)
        if type(t) ~= 'table' then return false end
        if table.type then return table.type(t) == 'array' end
        local count = 0
        for k in pairs(t) do
            if type(k) ~= 'number' then return false end
            if k > count then count = k end
        end
        return count == #t
    end

    local playerData = RSGCore.Functions.GetPlayerData()
    local inv = playerData and playerData.items
    if not inv then return false end

    -- Считаем кол-во каждого предмета
    local maxByName = {}
    for _, item in pairs(inv) do
        if item and item.name then
            local amt = item.amount or 0
            maxByName[item.name] = math.max(maxByName[item.name] or 0, amt)
        end
    end

    -- Приводим одиночный предмет к таблице
    if type(items) ~= 'table' then
        items = { [items] = amount }
        any = true -- Один предмет — эквивалент OR-логики
    elseif isArray(items) then
        local t = {}
        for _, name in ipairs(items) do
            t[name] = amount
        end
        items = t
    end

    -- Объединённая проверка
    local foundCount = 0
    local totalRequired = 0

    for name, reqAmount in pairs(items) do
        totalRequired = totalRequired + 1
        local have = maxByName[name]
        if have ~= nil and (reqAmount == nil or have >= reqAmount) then
            foundCount = foundCount + 1
            if any then return true end
        elseif not any then
            return false
        end
    end

    return not any and foundCount == totalRequired
end

exports('HasItem', HasItem)
--]]