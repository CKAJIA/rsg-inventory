local RSGCore = exports['rsg-core']:GetCoreObject()
local config = require 'shared.config'
Inventory = Inventory or {}

-- Общие правила вынесены в shared, чтобы клиентская подсказка и серверная выдача
-- одинаково учитывали количество, значения info по умолчанию и совместимость стаков.
Inventory.ValidAmount = InventoryRules.ValidAmount
Inventory.CopyItemData = InventoryRules.CopyItemData
Inventory.PrepareItemInfo = InventoryRules.PrepareItemInfo

-- Проверяет возможность объединения с конкретным существующим стаком.
function Inventory.CanStackItem(existing, name, info)
    return InventoryRules.CanStackItem(existing, name, info, RSGCore.Shared.Items[name])
end

-- Находит содержимое и лимиты игрока, хранилища или сумки.
-- Четвёртый результат — объект игрока, если identifier относится к игроку.
function Inventory.GetContainerData(identifier)
    local player = RSGCore.Functions.GetPlayer(identifier)
    if player then return player.PlayerData.items, player.PlayerData.weight, player.PlayerData.slots, player end
    local container = Inventories[identifier] or Drops[identifier]
    local limits = Drops[identifier] and config.DropSize or config.StashSize
    if container then return container.items, container.maxweight or limits.maxweight, container.slots or limits.slots end
end

-- Копирует таблицу слотов; изменяемые стаки затем копируются отдельно.
-- Неизменяемые предметы можно безопасно переиспользовать до применения готового плана.
local function shallowCopy(items)
    local result = {}
    for slot, item in pairs(items) do result[slot] = item end
    return result
end

-- Готовит новое содержимое инвентаря, не изменяя живые items.
-- Возвращает plan, первый слот либо nil, причину отказа.
-- Сначала проверяет вес и все нужные слоты; unique создаёт отдельный предмет на единицу.
-- У оружия без serie создаётся серийный номер; метаданные разных экземпляров независимы.
function Inventory.PlanAddItem(items, maxWeight, maxSlots, name, amount, slot, info)
    if type(name) ~= 'string' or type(items) ~= 'table' then return nil, 'invalid_item' end
    name, amount = name:lower(), Inventory.ValidAmount(amount, 1)
    local definition = RSGCore.Shared.Items[name]
    if not definition or not amount then return nil, 'invalid_amount' end
    if slot then
        slot = Inventory.ValidAmount(slot)
        if not slot or slot > maxSlots then return nil, 'invalid_slot' end
    end
    if Inventory.GetTotalWeight(items) + (definition.weight or 0) * amount > maxWeight then return nil, 'weight' end
    info = Inventory.PrepareItemInfo(definition, info)
    if definition.unique and amount > 1 and info.serie then return nil, 'invalid_amount' end
    local plan = shallowCopy(items)
    local firstSlot
    if not definition.unique then
        if not slot then
            for i = 1, maxSlots do
                if Inventory.CanStackItem(plan[i], name, info) then slot = i; break end
            end
        end
        if slot and Inventory.CanStackItem(plan[slot], name, info) then
            local stack = Inventory.CopyItemData(plan[slot])
            stack.amount = stack.amount + amount
            plan[slot] = stack
            return plan, slot
        end
    end
    local units = definition.unique and amount or 1
    for i = 1, units do
        local target = i == 1 and slot or nil
        if not target or plan[target] then target = Inventory.GetFirstFreeSlot(plan, maxSlots) end
        if not target then return nil, 'slots' end
        local metadata = Inventory.CopyItemData(info)
        if definition.type == 'weapon' then
            metadata.serie = metadata.serie or tostring(RSGCore.Shared.RandomInt(2) .. RSGCore.Shared.RandomStr(3)
                .. RSGCore.Shared.RandomInt(1) .. RSGCore.Shared.RandomStr(2)
                .. RSGCore.Shared.RandomInt(3) .. RSGCore.Shared.RandomStr(4))
            metadata.quality = metadata.quality or 100
        end
        plan[target] = {
            name = name, amount = definition.unique and 1 or amount, slot = target, info = metadata,
            label = definition.label, description = definition.description or '', weight = definition.weight or 0,
            type = definition.type, unique = definition.unique, useable = definition.useable,
            squality = definition.squality, image = definition.image, shouldClose = definition.shouldClose,
            combinable = definition.combinable
        }
        firstSlot = firstSlot or target
    end
    return plan, firstSlot
end

-- Готовит полное списание количества из указанного слота или нескольких стаков.
-- При нехватке не списывает ничего; это предотвращает потерю части предметов при отказе.
-- Возвращает plan, последний затронутый предмет и слот либо nil при отказе.
function Inventory.PlanRemoveItem(items, name, amount, slot)
    amount = Inventory.ValidAmount(amount, 1)
    if type(name) ~= 'string' or not amount then return nil end
    name = name:lower()
    local candidates, total = {}, 0
    if slot then
        slot = Inventory.ValidAmount(slot)
        if not slot then return nil end
        local key, item = slot, items[slot]
        if not item or item.slot ~= slot then
            item = nil
            for k, value in pairs(items) do if value.slot == slot then key, item = k, value; break end end
        end
        if not item or item.name:lower() ~= name or item.amount < amount then return nil end
        candidates[1] = key
    else
        for key, item in pairs(items) do
            if item.name:lower() == name then candidates[#candidates + 1] = key; total = total + item.amount end
        end
        if total < amount then return nil end
    end
    local plan, lastItem, remaining = shallowCopy(items), nil, amount
    for _, key in ipairs(candidates) do
        local item = items[key]
        local take = math.min(item.amount, remaining)
        lastItem = item
        if item.amount == take then plan[key] = nil
        else plan[key] = Inventory.CopyItemData(item); plan[key].amount = item.amount - take end
        remaining = remaining - take
        if remaining == 0 then break end
    end
    return plan, lastItem, slot or 'Multiple'
end

-- Проверяет целое предложение трейда: следующий предмет добавляется в предыдущий план.
-- Так несколько по отдельности допустимых предметов не переполнят инвентарь вместе.
function Inventory.PlanIncomingItems(identifier, offered)
    local items, weight, slots, player = Inventory.GetContainerData(identifier)
    if not items then return nil, 'inventory' end
    if player then Inventory.CheckPlayerItemsDecay(player); items = player.PlayerData.items end
    local plan = items
    for _, item in pairs(offered or {}) do
        local nextPlan, result = Inventory.PlanAddItem(plan, weight, slots, item.name, item.amount, false, item.info)
        if not nextPlan then return nil, result, item.name end
        plan = nextPlan
    end
    return plan
end

-- Отправляет уведомление обоим участникам неудачной передачи.
-- Отправитель видит, что заполнен получатель, а получатель — что заполнен его инвентарь.
function Inventory.NotifyTransferFull(sender, recipient, reason)
    TriggerClientEvent('ox_lib:notify', sender, {
        title = locale('ui.trade'), type = 'error', duration = 5000,
        description = locale('error.recipient_inventory_full')
    })
    TriggerClientEvent('ox_lib:notify', recipient, {
        title = locale('ui.trade'), type = 'error', duration = 5000,
        description = locale('error.your_inventory_full')
    })
end
