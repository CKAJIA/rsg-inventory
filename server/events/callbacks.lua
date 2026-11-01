local RSGCore = exports['rsg-core']:GetCoreObject()

lib.callback.register('rsg-inventory:server:getPlayerName', function(source, targetId)
    local Player = RSGCore.Functions.GetPlayer(targetId)
    if not Player then return GetPlayerName(targetId) end
    local char = Player.PlayerData.charinfo
    if char and char.firstname then
        return char.firstname .. ' ' .. char.lastname
    end
    return GetPlayerName(targetId)
end)

-- Обычная передача: сначала строим планы обоих инвентарей, затем применяем вместе.
-- Если получатель заполнен, отправитель сохраняет предмет и оба видят уведомление.
-- Предмет и его info берутся из серверного слота, а не из присланных клиентом метаданных.
lib.callback.register('rsg-inventory:server:giveItem', function(source, target, item, amount, slot)
    target, amount, slot = Inventory.ValidAmount(target), Inventory.ValidAmount(amount), Inventory.ValidAmount(slot)
    if not target or target == source or not amount or not slot or type(item) ~= 'string' then return false end
    item = item:lower()
    local player, recipient = RSGCore.Functions.GetPlayer(source), RSGCore.Functions.GetPlayer(target)
    if not player or not recipient then return false end
    for _, current in ipairs({player, recipient}) do
        local meta = current.PlayerData.metadata
        if meta.isdead or meta.inlaststand or meta.ishandcuffed then return false end
    end
    if #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(GetPlayerPed(target))) > Inventory.MAX_DIST then return false end
    local definition = RSGCore.Shared.Items[item]
    local invItem = Inventory.GetItemBySlot(source, slot)
    if not definition or not invItem or invItem.name:lower() ~= item or invItem.amount < amount then return false end
    local info = Inventory.CopyItemData(invItem.info or {})
    Inventory.CheckPlayerItemsDecay(recipient)
    local sourcePlan = Inventory.PlanRemoveItem(player.PlayerData.items, item, amount, slot)
    if not sourcePlan then return false end
    local targetPlan, reason = Inventory.PlanAddItem(recipient.PlayerData.items, recipient.PlayerData.weight,
        recipient.PlayerData.slots, item, amount, false, info)
    if not targetPlan then Inventory.NotifyTransferFull(source, target, reason); return false end
    -- Применяем оба плана до вызова подписчиков, чтобы они видели согласованные остатки.
    player.PlayerData.items, recipient.PlayerData.items = sourcePlan, targetPlan
    Inventory.SetInventory(source, sourcePlan)
    Inventory.SetInventory(target, targetPlan)
    local isWeapon = definition.type == 'weapon'
    if isWeapon then
        Inventory.CheckWeapon(source, item)
        TriggerClientEvent('rsg-core:client:RemoveWeaponFromTab', source, item)
    end
    Inventory.NotifyItemChanged(source, item, {action = 'remove', amount = amount, slot = slot, reason = 'give item', info = info})
    Inventory.NotifyItemChanged(target, item, {action = 'add', amount = amount, reason = 'give item', info = info})
    TriggerEvent('rsg-inventory:server:itemRemovedFromPlayerInventory', source, item,
        {amount = amount, slot = slot, info = info}, 'give item', isWeapon)
    TriggerEvent('rsg-inventory:server:updateHotbar', source)
    TriggerEvent('rsg-inventory:server:updateHotbar', target)
    TriggerClientEvent('rsg-inventory:client:giveAnim', source)
    TriggerClientEvent('rsg-inventory:client:ItemBox', source, definition, 'remove', amount)
    TriggerClientEvent('rsg-inventory:client:giveAnim', target)
    TriggerClientEvent('rsg-inventory:client:ItemBox', target, definition, 'add', amount)
    if Player(target).state.inv_busy then TriggerClientEvent('rsg-inventory:client:updateInventory', target) end
    return true
end)
