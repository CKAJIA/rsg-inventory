-- Toggle the hotbar UI with given items
local RSGCore = exports['rsg-core']:GetCoreObject()

-- @param items: table of items to display on the hotbar
RegisterNetEvent('rsg-inventory:client:hotbar', function(items)
    local token = exports['rsg-core']:GenerateCSRFToken() -- CSRF token for NUI security
    LocalPlayer.state.hotbarShown = not LocalPlayer.state.hotbarShown -- toggle state
    SendNUIMessage({
        action = 'toggleHotbar',
        open = LocalPlayer.state.hotbarShown,
        items = items,
        token = token,
    })
end)

-- Close the inventory UI
RegisterNetEvent('rsg-inventory:client:closeInv', function()
    SendNUIMessage({
        action = 'close',
    })
end)

-- Update the player's inventory UI with current items
RegisterNetEvent('rsg-inventory:client:updateInventory', function()
    local token = exports['rsg-core']:GenerateCSRFToken()
    local playerData = RSGCore.Functions.GetPlayerData() -- fetch current player data
    SendNUIMessage({
        action = 'update',
        inventory = playerData.items,
        cash = playerData.money.cash,
        token = token,
    })
end)

RegisterNetEvent('rsg-inventory:client:updateShopInventory', function(shopItems)
    local token = exports['rsg-core']:GenerateCSRFToken()
    local playerData = RSGCore.Functions.GetPlayerData()
	local playerItems = playerData.items
	local EnrichedPlayerItems = {}
	
	if shopItems then
		for _, playerItem in pairs(playerItems) do
			-- Проходим по предметам магазина (RegisteredShops[name].items)
			local newItem = {}
			for k, v in pairs(playerItem) do
				newItem[k] = v
			end
			if playerItem and playerItem.name then			
				for _, shopItem in pairs(shopItems) do
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
		playerItems = EnrichedPlayerItems
	end
	
	--print("Items = " .. json.encode(playerItems))
	
    SendNUIMessage({
        action = 'update',
        inventory = playerItems,
        token = token,
    })
end)

-- Show an item box notification for adding/removing items
-- @param itemData: table with item info
-- @param type: string, type of update ('add', 'remove', 'info', etc.)
-- @param amount: number of items affected
RegisterNetEvent('rsg-inventory:client:ItemBox', function(itemData, type, amount)
    local function sendItemBox()
        SendNUIMessage({
            action = 'itemBox',
            item = itemData,
            type = type,
            amount = amount,
            labels = buildLabels()
        })

        -- Update server hotbar if items were added or removed
        if type == 'remove' or type == 'add' then
            TriggerServerEvent('rsg-inventory:server:updateHotbar')
        end
    end

    -- Throttle item box display to avoid spamming
    local lastItemBoxCall = LocalPlayer.state.lastItemBoxCall or 0
    local currentTime = GetGameTimer()
    local timeElapsed = currentTime - lastItemBoxCall

    if timeElapsed >= 1000 then
        sendItemBox()
        lastItemBoxCall = currentTime
    else
        local delay = 1000 - timeElapsed
        lib.timer(delay, function()
            sendItemBox()
        end, true)
        lastItemBoxCall = currentTime + delay
    end

    LocalPlayer.state.lastItemBoxCall = lastItemBoxCall
end)

-- Update hotbar UI with new items
-- @param items: table of items to display
RegisterNetEvent('rsg-inventory:client:updateHotbar', function(items)
    local token = exports['rsg-core']:GenerateCSRFToken()
    SendNUIMessage({
        action = 'updateHotbar',
        items = items,
        token = token,
    })
end)

local function L(k, d) return locale(k) or d end

function buildLabels()
    return {
        title   = L('ui.title', 'RSG Inventory'),
        close   = L('ui.close', 'Close'),
        close_aria = L('ui.close_aria', 'Close inventory'),
        use     = L('ui.use', 'Use'),
        give    = L('ui.give', 'Give'),
        single  = L('ui.single', 'Single'),
        half    = L('ui.half', 'Half'),
        all     = L('ui.all', 'All'),
        split   = L('ui.split', 'Split'),
        amount  = L('ui.amount', 'Amount'),
        amount_placeholder = L('ui.amount_placeholder', 'amount'),
        drop    = L('ui.drop', 'Drop'),
        copy_serial = L('ui.copy_serial', 'Copy Serial'),
        sell    = L('ui.sell', 'Sell'),
        satchel = L('ui.satchel', 'Satchel'),
        weight  = L('ui.weight', 'Weight'),
        id      = L('ui.id', 'ID'),
        cash    = L('ui.cash', 'Cash'),
        received = L('ui.received', 'Received'),
        used     = L('ui.used', 'Used'),
        removed  = L('ui.removed', 'Removed'),
		amount_start = L('ui.amount_start', 'Amount:'),
		amount_end = L('ui.amount_end', ''),
		quality = L('ui.quality', 'Quality:'),
		quality_full = L('ui.quality_full', 'Quality:'),
		serial = L('ui.serial', 'Serial Number:'),
		buy_price = L('ui.buy_price', 'Buy Price'),
		sell_price = L('ui.sell_price', 'Sell Price'),
		buy = L('ui.buy', 'Buy'),
		sellable = L('ui.sellable', 'Sellable'),
		price = L('ui.price', 'Price'),
		value = L('ui.value', 'Value'),
		modifications = L('ui.modifications', 'Modifications'),
		enter_ammount = L('ui.enter_ammount', 'Enter amount'),
		confirm = L('ui.confirm', 'Confirm'),
		cancel = L('ui.cancel', 'Cancel'),
		
		categories = {
			all = L('ui.categories.all', 'All'),
			clothes = L('ui.categories.clothes', 'Clothes'),
			weapons = L('ui.categories.weapons', 'Weapons'),
			provision = L('ui.categories.provision', 'Provision'),
			remedies = L('ui.categories.remedies', 'Remedies'),
			ingridient = L('ui.categories.ingridient', 'Ingridient'),
			material = L('ui.categories.material', 'Material'),
			kit = L('ui.categories.kit', 'Kit'),
			valuable = L('ui.categories.valuable', 'Valuable'),
			documents = L('ui.categories.documents', 'Documents'),
			herbs = L('ui.categories.herbs', 'Herbs'),
			animals = L('ui.categories.animals', 'Animals'),
			collections = L('ui.categories.collections', 'Collections'),
			horse = L('ui.categories.horse', 'Horse'),
			sell = L('ui.categories.sell', 'Sell'),
			misc = L('ui.categories.misc', 'Misc'),
		}
    }
end

-- Open the inventory UI with specified items and optional extra context
-- @param items: table of inventory items
-- @param other: optional table with extra info (trunk, stash, etc.)
RegisterNetEvent('rsg-inventory:client:openInventory', function(items, other)
    local token = exports['rsg-core']:GenerateCSRFToken()
    local Player = RSGCore.Functions.GetPlayerData()
    local config = require 'shared.config'
    local function L(k, d) return locale(k) or d end
    local labels = buildLabels()
    SetNuiFocus(true, true) -- focus mouse and keyboard on NUI

    SendNUIMessage({
        action    = 'open',
        inventory = items,
        slots     = Player.slots,          -- max inventory slots
        maxweight = Player.weight,     -- max inventory weight
        playerId  = Player.source or Player.id or Player.citizenid, -- unique player identifier
        other     = other,                 -- context, e.g., trunk inventory
        token     = token,
        closeKey  = config.Keybinds.Close,
        cash      = Player.money.cash,         -- player's money
        labels    = labels,
    })
end)