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
    if not RegisteredShops[name] then return end
    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    local tslots = math.max(#RegisteredShops[name].items, 25) --чтобы всегда клеток было минимум 25
	local EnrichedPlayerItems = {}
    if RegisteredShops[name].coords then
        local shopDistance = vector3(RegisteredShops[name].coords.x, RegisteredShops[name].coords.y, RegisteredShops[name].coords.z)
        if shopDistance then
            local distance = #(playerCoords - shopDistance)
            if distance > Inventory.MAX_DIST then return end
        end
    end
    local formattedInventory = {
        name = 'shop-' .. RegisteredShops[name].name,
        label = RegisteredShops[name].label,
        maxweight = 500000,
        --slots = #RegisteredShops[name].items,
		slots = tslots,
        inventory = RegisteredShops[name].items,
        persistentStock = RegisteredShops[name].persistentStock,
    }
	
	for _, playerItem in pairs(player.PlayerData.items) do
		-- Проходим по предметам магазина (RegisteredShops[name].items)
		local newItem = {}
        for k, v in pairs(playerItem) do
            newItem[k] = v
        end
		if playerItem and playerItem.name then			
			for _, shopItem in pairs(RegisteredShops[name].items) do
				-- Если имя предмета совпадает
				if shopItem and shopItem.name and playerItem.name == shopItem.name then
					-- Добавляем цену и цену покупки в предмет игрока
					if shopItem.buyPrice then
						newItem.buyPrice = shopItem.buyPrice
					end
					break -- Выходим из внутреннего цикла, совпадение найдено
				end
			end			
		end
		table.insert(EnrichedPlayerItems, newItem)
	end
	
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