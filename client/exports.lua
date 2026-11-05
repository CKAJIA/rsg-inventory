local RSGCore = exports['rsg-core']:GetCoreObject()

--- Проверяет локальный инвентарь по автоматическому кешу сумм всех стаков.
--- @param items string|table Имя, список имён или требования { bread = 2 }.
--- @param amount number|nil Минимум для строки или каждого имени в списке.
--- @param anyItem boolean|nil true: достаточно любого требования; иначе нужны все.
--- @return boolean
function HasItem(items, amount, anyItem)
    -- Используем тот же локальный снимок, что CanAddItem: без копирования PlayerData из ядра.
    local playerData = GetInventoryPlayerData()
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

    local amountsByName = GetInventoryItemAmounts()

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
                    return true, itemName
                end
            end

            return false, nil
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