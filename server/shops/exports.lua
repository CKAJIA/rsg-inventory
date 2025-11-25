Shops = Shops or {}

--- @param shopData table The data of the shop to create or update.
Shops.CreateShop = function(shopData)
    if shopData.name then
        if RegisteredShops[shopData.name] then
            local old = RegisteredShops[shopData.name]
            old.items = Shops.SetupShopItems(shopData.items, shopData)
            old.slots = #shopData.items
            old.persistentStock = shopData.persistentStock ~= nil and shopData.persistentStock or old.persistentStock
            return
        end

        RegisteredShops[shopData.name] = {
            name = shopData.name,
            label = shopData.label,
            coords = shopData.coords,
            slots = #shopData.items,
            items = Shops.SetupShopItems(shopData.items, shopData),
            persistentStock = shopData.persistentStock,
        }
    else
        for key, data in pairs(shopData) do
            if type(data) == 'table' then
                if data.name then
                    local shopName = type(key) == 'number' and data.name or key
                    if RegisteredShops[shopName] then
                        local old = RegisteredShops[shopName]
                        old.items = Shops.SetupShopItems(data.items, data)
                        old.slots = #data.items
                        old.persistentStock = data.persistentStock ~= nil and data.persistentStock or old.persistentStock
                        goto continue
                    end

                    RegisteredShops[shopName] = {
                        name = shopName,
                        label = data.label,
                        coords = data.coords,
                        slots = #data.items,
                        items = Shops.SetupShopItems(data.items, data),
                        persistentStock = data.persistentStock,
                    }
                else
                    Shops.CreateShop(data)
                end
            end
            ::continue::
        end
    end
end

exports('CreateShop', Shops.CreateShop)

--- @param source number The player's server ID.
--- @param name string The identifier of the inventory to open.
Shops.OpenShop = function(source, name)
    if not name then return end
    local RSGCore = exports['rsg-core']:GetCoreObject()
    local player = RSGCore.Functions.GetPlayer(source)
    if not player then return end
    
    local shopData = RegisteredShops[name]
    if not shopData then return end

    -- Дистанция
    local ped = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(ped)
    if shopData.coords then
        if #(playerCoords - vector3(shopData.coords.x, shopData.coords.y, shopData.coords.z)) > Inventory.MAX_DIST then return end
    end
	
    -- ОПТИМИЗАЦИЯ: Создаем карту цен магазина
    local shopPriceMap = {}
    -- Используем shopData.items, как в оригинале
    if shopData.items then
        for _, item in pairs(shopData.items) do
            if item and item.name and item.buyPrice then
                shopPriceMap[item.name] = item.buyPrice
            end
        end
    end

    local EnrichedPlayerItems = {}
    local playerItems = player.PlayerData.items

    if playerItems then
        for _, item in pairs(playerItems) do
            if item then
                -- Клонируем
                local newItem = {}
                for k, v in pairs(item) do newItem[k] = v end

                -- Быстрая подстановка цены
                if newItem.name and shopPriceMap[newItem.name] then
                    newItem.buyPrice = shopPriceMap[newItem.name]
                end

                table.insert(EnrichedPlayerItems, newItem)
            end
        end
    end

    local formattedInventory = {
        name = 'shop-' .. shopData.name,
        label = shopData.label,
        maxweight = 500000,
        slots = math.max(math.ceil(#shopData.items / 5) * 5, 25),
        inventory = shopData.items, -- Оригинальный список товаров
        persistentStock = shopData.persistentStock,
    }
	
	--print("PlayerITEMS = " .. json.encode(EnrichedPlayerItems))
	--print("ShopITEMS = " .. json.encode(player.PlayerData.items))

    Player(source).state.inv_busy = true
    Inventory.CheckPlayerItemsDecay(player)
    
	--TriggerClientEvent('rsg-inventory:client:openInventory', source, player.PlayerData.items, formattedInventory)
    TriggerClientEvent('rsg-inventory:client:openInventory', source, EnrichedPlayerItems, formattedInventory)
end

local function cloneTable(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = v
    end
    return copy
end

function GetPlayerItems(player)
	local items = player.PlayerData.items
	return items
end

exports('OpenShop', Shops.OpenShop)

--- @param shopName string Name of the shop
--- @param percentage int Percentage of default amount to restock (for example 10% of default stock). Default 100
Shops.RestockShop = function(shopName, percentage)    
    shopData = RegisteredShops[shopName]
    if not shopData then return false end

    percentage = percentage or 100
    local mult = percentage / 100
    
    for slot, item in pairs(shopData.items) do 
        if item.amount then 
            local restock = math.round(item.defaultstock * mult, 0)
            item.amount = math.min(item.defaultstock, item.amount + restock)
        end
    end
end

exports('RestockShop', Shops.RestockShop)

--- Check if a shop exists in the registry.
--- @param shopName string Name of the shop
--- @return boolean True if the shop exists, false otherwise
function Shops.DoesShopExist(shopName)
    if type(shopName) ~= "string" then return false end
    return RegisteredShops and RegisteredShops[shopName] ~= nil
end

exports('DoesShopExist', Shops.DoesShopExist)