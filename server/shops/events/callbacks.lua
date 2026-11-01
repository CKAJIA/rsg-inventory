local RSGCore = exports['rsg-core']:GetCoreObject()
local config = require 'shared.config'

-- Ограничивает повторные запросы покупки и продажи.
local purchaseCooldowns = {}

-- Единое уведомление игрока об отказе или результате операции.
local function notifyPlayer(source, messageKey, type)
    TriggerClientEvent('ox_lib:notify', source, { title = locale(messageKey), type = type or 'error', duration = 5000 })
end

-- Покупка и продажа используют серверные данные магазина и фактического слота.
-- Продажа оплачивается после успешного списания. При отказе строгой выдачи покупки деньги возвращаются.
lib.callback.register('rsg-inventory:server:attemptPurchase', function(source, data)
    -- Ограничение частоты запросов.
    local now = os.time()
    if purchaseCooldowns[source] and now - purchaseCooldowns[source] < 1 then return false end
    purchaseCooldowns[source] = now

    if type(data) ~= 'table' or type(data.item) ~= 'table' or type(data.shop) ~= 'string' then return false end
    local itemInfo      = data.item
    local amount        = Inventory.ValidAmount(data.amount)
    if not amount or type(itemInfo.name) ~= 'string' then return false end
    local definition = RSGCore.Shared.Items[itemInfo.name:lower()]
    if not definition then return false end
    local shopName      = string.gsub(data.shop, '^shop%-', '')
    local sourceInvType = data.sourceinvtype
    --local targetSlot    = data.targetslot

    -- Количество должно быть положительным целым числом.
    if amount <= 0 then return false end

    -- В одной операции магазина уникальный предмет покупается по одной единице.
    if definition.unique and amount > 1 then amount = 1 end

    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end

    local shopInfo = RegisteredShops[shopName]
    if not shopInfo then return false end

	if not checkShopMode(source, data, sourceInvType) then return false end

    -- Проверяем расстояние до магазина, если у него заданы координаты.
    if shopInfo.coords then
        local playerCoords = GetEntityCoords(GetPlayerPed(source))
        local shopCoords   = vector3(shopInfo.coords.x, shopInfo.coords.y, shopInfo.coords.z)
        if #(playerCoords - shopCoords) > 10.0 then return false end
    end

    -- Продажа предмета игроком магазину.
    if sourceInvType == 'player' then
        for _, shopItem in ipairs(shopInfo.items) do
            if itemInfo.name == shopItem.name and shopItem.buyPrice then
                -- Берём настоящий предмет по серверному слоту, включая качество и количество.
                local realItem = Inventory.GetItemBySlot(source, itemInfo.slot)
                if not realItem or realItem.name ~= itemInfo.name or realItem.amount < amount then
                    notifyPlayer(source, 'error.not_enough_items') return false
                end
                local realQuality = realItem.info.quality or 100

                -- Проверяем минимально допустимое качество.
                if realQuality < (shopItem.minQuality or 1) then
                    notifyPlayer(source, 'error.quality_too_low') return false
                end

                -- Проверяем допустимый остаток товара магазина.
                if shopItem.maxStock and shopItem.maxStock < (shopItem.amount + amount) then
                    notifyPlayer(source, 'error.shop_fully_stocked') return false
                end

                -- Проверяем наличие нужного количества у игрока.
                if not Inventory.HasItem(source, itemInfo.name, amount) then
                    notifyPlayer(source, 'error.not_enough_items') return false
                end

                -- Выплата учитывает настоящее серверное качество, остаток меняется после списания.
                -- До успешного списания предметов остаток магазина не меняется.
                local buyPrice = shopItem.buyPrice * amount * (realQuality / 100)
                buyPrice = math.max(0.01, math.round(buyPrice, 2))
				
				if not Inventory.RemoveItem(source, itemInfo.name, amount, itemInfo.slot, 'shop-sell') then return false end
                if shopItem.amount then shopItem.amount = shopItem.amount + amount end
				Player.Functions.AddMoney('cash', buyPrice, 'shop-sell')
				--TriggerClientEvent('rsg-inventory:client:updateInventory', source)
				TriggerClientEvent('rsg-inventory:client:updateShopInventory', source, shopInfo.items)
				return true
            end
        end

        notifyPlayer(source, 'error.shop_does_not_buy') return false
    end

    -- Покупка предмета игроком у магазина.
    local shopSlot = shopInfo.items[itemInfo.slot]
    if not shopSlot or shopSlot.name ~= itemInfo.name then return false end

    if shopSlot.amount and amount > shopSlot.amount then
        notifyPlayer(source, 'error.cannot_purchase_more_than_stock') return false
    end

    if not Inventory.CanAddItem(source, itemInfo.name, amount, shopSlot.info) then
        notifyPlayer(source, 'error.cannot_carry') return false
    end

    if not shopSlot.price then
        notifyPlayer(source, 'info.no_price_or_not_for_sale') return false
    end

    local price = math.round(shopSlot.price * amount, 2)
    if Player.PlayerData.money.cash < price then
        notifyPlayer(source, 'error.not_enough_money') return false
    end

    if not Player.Functions.RemoveMoney('cash', price, 'shop-purchase') then return false end
    if not Inventory.AddItemStrict(source, itemInfo.name, amount, false, shopSlot.info or {}, 'shop-purchase') then
        Player.Functions.AddMoney('cash', price, 'shop-purchase refund')
        notifyPlayer(source, 'error.cannot_carry')
        return false
    end
    if shopSlot.amount then shopSlot.amount = shopSlot.amount - amount end
	TriggerClientEvent('rsg-inventory:client:updateShopInventory', source, shopInfo.items)
    return true
end)

lib.callback.register('rsg-inventory:server:checkPurchase', function(source, data)
	local itemInfo 		= data.item
	local amount        = 1 --проверяем хотябы для 1 единицы
	local shop 			= string.gsub(data.shop, '^shop%-', '')
    local sourceInvType = data.sourceinvtype
    local targetSlot 	= data.targetslot
	
	local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end
	
	local shopInfo = RegisteredShops[shop]
    if not shopInfo then return false end
	
	if not checkShopMode(source, data, sourceInvType) then return false end
	
	-- Продажа предмета игроком магазину.
	if sourceInvType == 'player' then
        for slot, shopItem in ipairs(shopInfo.items) do 
            if itemInfo.name == shopItem.name and shopItem.buyPrice ~= nil then 
				-- Проверяем минимально допустимое качество.
                if itemInfo.info.quality and itemInfo.info.quality < (shopItem.minQuality or 1) then
					notifyPlayer(source, 'error.quality_too_low') return false
                end
				
				-- Проверяем допустимый остаток товара магазина.
                if shopItem.maxStock and shopItem.maxStock < (shopItem.amount + amount) then
                    notifyPlayer(source, 'error.shop_fully_stocked') return false
                end

                if Inventory.HasItem(source, itemInfo.name, amount) then
                    return true
                end
				
				-- Рассчитываем цену приёма предмета магазином.
                if shopItem.amount then shopItem.amount = shopItem.amount + amount end
                local buyPrice = shopItem.buyPrice * amount
                if itemInfo.info.quality then
                    buyPrice = buyPrice * (itemInfo.info.quality / 100)
                end
                buyPrice = math.round(buyPrice, 2)

                if buyPrice < 0.01 then
                    notifyPlayer(source, 'error.worthless_item') return false
                end
            end
        end

		notifyPlayer(source, 'error.shop_does_not_buy') return false
    end
	--TODO: Надо тут посидеть подумать чтобы если мы продаем в магазин почему не можем продать при перетаскивании.
	-- Покупка предмета игроком у магазина.
    local shopSlot = shopInfo.items[itemInfo.slot]
    if not shopSlot or shopSlot.name ~= itemInfo.name then return false end

    if shopSlot.amount and amount > shopSlot.amount then
        notifyPlayer(source, 'error.cannot_purchase_more_than_stock') return false
    end

    if not Inventory.CanAddItem(source, itemInfo.name, amount) then
        notifyPlayer(source, 'error.cannot_carry') return false
    end

    if not shopSlot.price then
        notifyPlayer(source, 'info.no_price_or_not_for_sale') return false
    end

    local price = math.round(shopSlot.price * amount, 2)
    if Player.PlayerData.money.cash < price then
        notifyPlayer(source, 'error.not_enough_money') return false
    end
	
	return true
end)

-- 🔹 Проверка режима
function checkShopMode(source, data, sourceInvType)
	-- 🔹 Проверка режима
	if data.shopMode and not config.IgnoreShopCategory then
		if sourceInvType == "player" and data.shopMode == "buy" then
			notifyPlayer(source, 'error.shopmodebuy') return false
		end
	
		if sourceInvType == "other" and data.shopMode == "sell" then
			notifyPlayer(source, 'error.shopmodesell') return false
		end
	end
	
	return true
end
