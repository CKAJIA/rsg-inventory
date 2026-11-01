local RSGCore = exports['rsg-core']:GetCoreObject()
-- Освобождение открытых контейнеров при выходе игрока.
AddEventHandler('playerDropped', function()
    for invId, inv in pairs(Inventories) do
        if inv.isOpen == source then
            inv.isOpen = false
            MySQL.prepare('INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?',
                { invId, json.encode(inv.items), json.encode(inv.items) })
        end
    end
end)

-- Сохранение открытых хранилищ перед штатным завершением сервера.
AddEventHandler('txAdmin:events:serverShuttingDown', function()
    for inventory, data in pairs(Inventories) do
        if data.isOpen then
            MySQL.prepare('INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?', { inventory, json.encode(data.items), json.encode(data.items) })
        end
    end
end)

-- После входа строим индекс и подключаем совместимые Player.Functions, включая HasItem и CanAddItem.
AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    local src = Player.PlayerData.source
    Inventory.BuildNameIndex(src, Player.PlayerData.items)
    if Inventory.ItemStates then Inventory.ItemStates.OnInventoryChanged(src) end

    -- Подключаем методы инвентаря к объекту игрока.
    local methods = {
        AddItem = function(item, amount, slot, info, reason)
            return Inventory.AddItem(src, item, amount, slot, info, reason)
        end,
        RemoveItem = function(item, amount, slot, reason)
            return Inventory.RemoveItem(src, item, amount, slot, reason)
        end,
        HasItem = function(items, amount, anyItem) return Inventory.HasItem(src, items, amount, anyItem) end,
        GetItemCount = function(item) return Inventory.GetItemCount(src, item) end,
        CanAddItem = function(item, amount, info) return Inventory.CanAddItem(src, item, amount, info) end,
        GetItemBySlot = function(slot)
            return Inventory.GetItemBySlot(src, slot)
        end,
        GetItemByName = function(item)
            return Inventory.GetItemByName(src, item)
        end,
        GetItemsByName = function(item)
            return Inventory.GetItemsByName(src, item)
        end,
        ClearInventory = function(filterItems)
            Inventory.ClearInventory(src, filterItems)
        end,
        SetInventory = function(items)
            Inventory.SetInventory(src, items)
        end
    }

    for methodName, methodFunc in pairs(methods) do
        RSGCore.Functions.AddPlayerMethod(src, methodName, methodFunc)
    end
end)

-- При перезапуске ресурса восстанавливаем индекс и Player.Functions уже подключённых игроков.
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    local Players = RSGCore.Functions.GetRSGPlayers()
    for k in pairs(Players) do
        Inventory.BuildNameIndex(k, Players[k].PlayerData.items)
        if Inventory.ItemStates then Inventory.ItemStates.OnInventoryChanged(k) end
        local methods = {
            AddItem = function(item, amount, slot, info, reason)
                return Inventory.AddItem(k, item, amount, slot, info, reason)
            end,
            RemoveItem = function(item, amount, slot, reason)
                return Inventory.RemoveItem(k, item, amount, slot, reason)
            end,
            HasItem = function(items, amount, anyItem) return Inventory.HasItem(k, items, amount, anyItem) end,
            GetItemCount = function(item) return Inventory.GetItemCount(k, item) end,
            CanAddItem = function(item, amount, info) return Inventory.CanAddItem(k, item, amount, info) end,
            GetItemBySlot = function(slot)
                return Inventory.GetItemBySlot(k, slot)
            end,
            GetItemByName = function(item)
                return Inventory.GetItemByName(k, item)
            end,
            GetItemsByName = function(item)
                return Inventory.GetItemsByName(k, item)
            end,
            ClearInventory = function(filterItems)
                Inventory.ClearInventory(k, filterItems)
            end,
            SetInventory = function(items)
                Inventory.SetInventory(k, items)
            end
        }

        for methodName, methodFunc in pairs(methods) do
            RSGCore.Functions.AddPlayerMethod(k, methodName, methodFunc)
        end

        -- Снимаем busy после перезапуска ресурса.
        Player(k).state.inv_busy = false
    end
end)
