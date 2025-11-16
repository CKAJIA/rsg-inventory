local RSGCore = exports['rsg-core']:GetCoreObject()
--- @param items string|table - The item(s) to check for. Can be a table of items or a single item as a string.
--- @param amount number [optional] - The minimum amount required for each item. If not provided, any amount greater than 0 will be considered.
--- @return boolean - Returns true if the player has the item(s) with the specified amount, false otherwise.
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






--[[
function HasItem(items, amount, any)
    local isTable = type(items) == "table"
    local isArray = isTable and table.type(items) == "array"
    local requiredItems = isArray and #items or (isTable and table.count(items) or 1)
    local foundItems = 0

    playerData = RSGCore.Functions.GetPlayerData()

    for _, item in pairs(playerData.items) do
        if not item then goto continue end

        if isTable then
            for key, value in pairs(items) do
                local itemName = isArray and value or key
                local requiredAmount = isArray and amount or value

                if item.name == itemName and (not requiredAmount or item.amount >= requiredAmount) then
                    if any then
						return true
					else	
						foundItems = foundItems + 1						
						if foundItems == requiredItems then return true end
					end
                end
            end
        elseif item.name == items and (not amount or item.amount >= amount) then
            return true
        end

        ::continue::
    end

    return false
end
exports('HasItem', HasItem)
--]]