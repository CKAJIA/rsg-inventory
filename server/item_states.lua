local RSGCore = exports['rsg-core']:GetCoreObject()

Inventory = Inventory or {}

--[[
    Item States
    ===========

    Модуль хранит "логические состояния", зависящие от предметов игрока.

    Примеры состояний:
    - inventory.hasWatch
    - inventory.hasMap
    - quest.hasRequiredItems
    - camp.canSetup

    Важно:
    1. Состояние рассчитывается на сервере.
    2. Одинаковая проверка регистрируется один раз.
    3. Любой ресурс может слушать одно и то же состояние.
    4. Обычные состояния уведомляют только при true <-> false.
	5. Состояния с trackProgress = true уведомляют также при изменении количества.
	6. При AddItem / RemoveItem пересчитываются только состояния,
		в которых присутствует изменённый предмет.
]]

Inventory.ItemStates = Inventory.ItemStates or {}

--[[
    Rules[stateName] = {
        name = 'inventory.hasWatch',
        mode = 'any',
        items = { 'pocketwatch1', 'pocketwatch2' }
    }

    mode:
    - 'any'          = достаточно любого предмета из массива
    - 'all'          = нужны все предметы из массива
    - 'requirements' = нужна таблица вида { bread = 5, water = 2 }
]]
Inventory.ItemStates.Rules = Inventory.ItemStates.Rules or {}

--[[
    RulesByItem[itemName][stateName] = true

    Обратный индекс:
    позволяет при изменении "bread" пересчитать только те состояния,
    где участвует "bread", а не все правила сервера.
]]
Inventory.ItemStates.RulesByItem = Inventory.ItemStates.RulesByItem or {}

--[[
    PlayerValues[source][stateName] = {
        value = true/false,
        progress = nil | {
            itemName = {
                amount = number
            }
        }
    }

    Здесь хранится последнее рассчитанное значение правила у игрока.
    Благодаря этому не отправляем одинаковые события повторно.
]]
Inventory.ItemStates.PlayerValues = Inventory.ItemStates.PlayerValues or {}

local ItemStates = Inventory.ItemStates

-- Приводит имя предмета к одному виду.
local function NormalizeItemName(itemName)
    if type(itemName) ~= 'string' then
        return nil
    end

    return itemName:lower()
end

-- Проверяет, что stateName можно использовать как ключ.
local function IsValidStateName(stateName)
    return type(stateName) == 'string' and stateName ~= ''
end

--[[
    Возвращает суммарное количество предмета у игрока.

function ItemStates.GetItemAmount(source, itemName)
	local Player = RSGCore.Functions.GetPlayer(source)
	if not Player or not Player.PlayerData then
        return 0
    end
	
    itemName = NormalizeItemName(itemName)
    if not itemName then
        return 0
    end
	
	--local source = Player.PlayerData.source
    local itemIndex = Inventory.GetNameIndex(source)

    -- Если индекс ещё не создан, строим его один раз.
    if not itemIndex then
        itemIndex = Inventory.BuildNameIndex(source, Player.PlayerData.items or {})
    end

    local itemStacks = itemIndex and itemIndex[itemName]
	
    if not itemStacks then
        return 0
    end

    local amount = 0

    -- У предмета может быть несколько stack/slot.
    for _, itemData in pairs(itemStacks) do
        amount = amount + (tonumber(itemData.amount) or 0)
    end	

    return amount
end
--]]

--[[
    Проверяет условие конкретного состояния.

    Примеры:
    any:
        { mode = 'any', items = { 'pocketwatch1', 'pocketwatch2' } }

    all:
        { mode = 'all', items = { 'tent', 'bedroll', 'firekit' } }

    requirements:
        { mode = 'requirements', items = { carrot = 5, bread = 2 } }
]]
function ItemStates.Evaluate(source, rule)
    -- any: игрок должен иметь хотя бы один предмет из списка.
    if rule.mode == 'any' then
        for _, itemName in ipairs(rule.items) do
            if Inventory.GetItemAmountIndex(source, itemName) > 0 then
                return true
            end
        end

        return false
    end

    -- all: игрок должен иметь каждый предмет из списка.
    if rule.mode == 'all' then
        for _, itemName in ipairs(rule.items) do
            if Inventory.GetItemAmountIndex(source, itemName) <= 0 then
                return false
            end
        end

        return true
    end

    -- requirements: требуется конкретное количество каждого предмета.
    if rule.mode == 'requirements' then
        for itemName, requiredAmount in pairs(rule.items) do
            local amount = Inventory.GetItemAmountIndex(source, itemName)

            if amount < (tonumber(requiredAmount) or 1) then
                return false
            end
        end

        return true
    end

    return false
end

--[[
    Возвращает актуальные количества предметов для правила.

    Формат результата:

    {
        bread = {
            amount = 4,
        },

        water = {
            amount = 1,
        }
    }

    Модуль item_states отдаёт только текущие количества.
]]
function ItemStates.GetProgress(source, rule)
    if not rule then
        return {}
    end

    local progress = {}

    -- requirements:
    -- { bread = 2, water = 3 }
    if rule.mode == 'requirements' then
        for itemName in pairs(rule.items) do
            progress[itemName] = { amount = Inventory.GetItemAmountIndex(source, itemName) }
        end

        return progress
    end

    -- any / all:
    -- { 'pocketwatch1', 'pocketwatch2' }
    for _, itemName in ipairs(rule.items) do
        progress[itemName] = { amount = Inventory.GetItemAmountIndex(source, itemName) }
    end

    return progress
end

--[[
    Отправляет изменение состояния.

    Серверное событие:
        rsg-inventory:server:itemStateChanged

    Клиентское событие:
        rsg-inventory:client:itemStateChanged

    Любой ресурс может слушать одно состояние:
        if stateName == 'inventory.hasWatch' then ...
]]
function ItemStates.Notify(source, stateName, value, progress)
    -- Для серверных скриптов.
    TriggerEvent('rsg-inventory:server:itemStateChanged', source, stateName, value, progress)

    -- Для клиентских скриптов игрока.
    TriggerClientEvent('rsg-inventory:client:itemStateChanged', source, stateName, value, progress)
end

--[[
    Пересчитывает одно правило для игрока.

    Событие отправляется:
    - при первом расчёте после входа;
    - если bool-состояние изменилось;
	- если изменились количества нужных предметов.
	
	Последнее важно для коллекций и UI прогресса:
    2/10 -> 3/10 должно прийти на клиент,
    даже если итоговое состояние всё ещё false.

    Если игрок уже имеет часы и получает вторые часы,
    для state без trackProgress новое событие не отправляется.
]]
function ItemStates.RecheckState(source, stateName)
    local rule = ItemStates.Rules[stateName]

    if not rule then
        return false
    end

    ItemStates.PlayerValues[source] = ItemStates.PlayerValues[source] or {}

    local newValue = ItemStates.Evaluate(source, rule)
    local oldState = ItemStates.PlayerValues[source][stateName]
    local oldValue = oldState and oldState.value

    -- Для обычного boolean-state progress вообще не считаем.
    local progress = nil
    local progressChanged = false

    if rule.trackProgress then
        progress = ItemStates.GetProgress(source, rule)

        local oldProgress = oldState and oldState.progress

        if not oldProgress then
            progressChanged = true
        else
            for itemName, currentData in pairs(progress) do
                local previousData = oldProgress[itemName]

                if not previousData or previousData.amount ~= currentData.amount then
                    progressChanged = true
                    break
                end
            end

            -- Защита на случай смены состава правила в будущем.
            if not progressChanged then
                for itemName in pairs(oldProgress) do
                    if not progress[itemName] then
                        progressChanged = true
                        break
                    end
                end
            end
        end
    end

    -- Сохраняем минимальные данные для обычного boolean state.
    ItemStates.PlayerValues[source][stateName] = {
        value = newValue,
        progress = progress
    }

    -- Boolean state: event только при true <-> false.
    -- Progress state: event также при 2/10 -> 3/10.
    if oldValue == nil or oldValue ~= newValue or progressChanged then
        ItemStates.Notify(source, stateName, newValue, progress)

        return true, newValue, progress
    end

    return false, newValue, progress
end

--[[
    Пересчитывает только правила, связанные с изменённым предметом.

    Например:
    ItemChanged(source, 'bread')

    Не пересчитывает inventory.hasWatch, если часы не содержат bread.
]]
function ItemStates.RecheckByItem(source, itemName)
    itemName = NormalizeItemName(itemName)

    if not itemName then
        return
    end

    local stateNames = ItemStates.RulesByItem[itemName]

    if not stateNames then
        return
    end

    for stateName in pairs(stateNames) do
        ItemStates.RecheckState(source, stateName)
    end
end

--[[
    Пересчитывает все зарегистрированные правила игрока.

    Использовать только когда заменился весь инвентарь:
    - вход игрока;
    - SetInventory;
    - ClearInventory;
    - удаление через decay;
    - админская полная замена инвентаря.
]]
function ItemStates.RecheckAll(source)
    for stateName in pairs(ItemStates.Rules) do
        ItemStates.RecheckState(source, stateName)
    end
end

--[[
    Вызывать после успешного AddItem / RemoveItem.

    Перед вызовом:
    - PlayerData.items должен быть уже обновлён;
    - itemsByName должен быть уже обновлён.

    Не пересчитывает лишние правила.
]]
function ItemStates.OnItemChanged(source, itemName)
    if not source or not itemName then
        return
    end
	
    ItemStates.RecheckByItem(source, itemName)
end

--[[
    Вызывать после замены всего inventory.

    Примеры:
    - SetInventory
    - ClearInventory
    - login игрока
    - массовое удаление decay-предметов
]]
function ItemStates.OnInventoryChanged(source, player)
    if not source then
        return
    end

    ItemStates.RecheckAll(source, player)
end

--[[
    Удаляет старые состояния игрока.

    Вызывается автоматически при выходе игрока,
    чтобы source другого игрока не получил прежний кэш.
]]
AddEventHandler('playerDropped', function()
    ItemStates.PlayerValues[source] = nil
end)

--[[
    Регистрация логического состояния.

    Пример:

    exports['rsg-inventory']:RegisterItemState('inventory.hasWatch', {
        mode = 'any',
        items = {
            'pocketwatch1',
            'pocketwatch2',
            'pocketwatch3'
        }
    })

    Другой пример:

    exports['rsg-inventory']:RegisterItemState('quest.hasSupplies', {
        mode = 'requirements',
        items = {
            bread = 2,
            water = 3
        }
    })
]]
function ItemStates.Register(stateName, rule)
    if not IsValidStateName(stateName) then
        return false, 'stateName must be a non-empty string'
    end

    if type(rule) ~= 'table' or type(rule.items) ~= 'table' then
        return false, 'rule.items must be a table'
    end

    local mode = rule.mode or 'any'
	
	local trackProgress = rule.trackProgress == true

    if mode ~= 'any' and mode ~= 'all' and mode ~= 'requirements' then
        return false, 'mode must be any, all or requirements'
    end

    -- Не разрешаем одному stateName означать разные условия.
    if ItemStates.Rules[stateName] then
        return false, 'stateName is already registered; use another name'
    end

    local normalizedItems = {}

    if mode == 'requirements' then
        -- Формат: { bread = 2, water = 3 }
        for itemName, requiredAmount in pairs(rule.items) do
            itemName = NormalizeItemName(itemName)

            if itemName then
                normalizedItems[itemName] = tonumber(requiredAmount) or 1
            end
        end
    else
        -- Формат: { 'pocketwatch1', 'pocketwatch2' }
        for _, itemName in ipairs(rule.items) do
            itemName = NormalizeItemName(itemName)

            if itemName then
                normalizedItems[#normalizedItems + 1] = itemName
            end
        end
    end

    -- Не регистрируем пустую проверку.
    if not next(normalizedItems) then
        return false, 'rule.items cannot be empty'
    end

    ItemStates.Rules[stateName] = {
		name = stateName,
		mode = mode,
		items = normalizedItems,
		
		-- false по умолчанию:
		-- обычные состояния не считают и не рассылают progress.
		trackProgress = trackProgress
	}

    -- Создаём обратный индекс: предмет -> состояния.
    if mode == 'requirements' then
        for itemName in pairs(normalizedItems) do
            ItemStates.RulesByItem[itemName] = ItemStates.RulesByItem[itemName] or {}
            ItemStates.RulesByItem[itemName][stateName] = true
        end
    else
        for _, itemName in ipairs(normalizedItems) do
            ItemStates.RulesByItem[itemName] = ItemStates.RulesByItem[itemName] or {}
            ItemStates.RulesByItem[itemName][stateName] = true
        end
    end

    -- Если правило зарегистрировано после того,
    -- как игроки уже вошли, сразу вычисляем им состояние.
    --for _, playerId in ipairs(GetPlayers()) do
    --    ItemStates.RecheckState(tonumber(playerId), stateName)
    --end

    return true
end

-- Вызывает любой серверный ресурс.
exports('RegisterItemState', ItemStates.Register)

--[[
    Возвращает текущее закэшированное значение.

    Если оно ещё не было рассчитано, пересчитываем его.
]]
function ItemStates.Get(source, stateName)
    if not IsValidStateName(stateName) then
        return nil
    end

    if not ItemStates.Rules[stateName] then
        return nil
    end

    ItemStates.PlayerValues[source] = ItemStates.PlayerValues[source] or {}

    if ItemStates.PlayerValues[source][stateName] == nil then
        ItemStates.RecheckState(source, stateName)
    end
	
	local state = ItemStates.PlayerValues[source][stateName]

    return state and state.value or false
end

-- Экспорт получения текущего состояния игрока.
-- local hasWatch = exports['rsg-inventory']:GetItemState(source, 'inventory.hasWatch')
exports('GetItemState', ItemStates.Get)



--[[
    Возвращает текущий progress конкретного состояния.

    Пример:
    local progress = exports['rsg-inventory']:GetItemStateProgress(
        source,
        'collection.herbs'
    )

    local yarrowAmount = progress.yarrow.amount
]]
function ItemStates.GetStateProgress(source, stateName)
    if not IsValidStateName(stateName) then
        return nil
    end

	-- Progress запрашивается только для правил,
    -- которые явно зарегистрированы с trackProgress = true.
    local rule = ItemStates.Rules[stateName]
	if not rule or not rule.trackProgress then
		return nil
	end

    ItemStates.PlayerValues[source] = ItemStates.PlayerValues[source] or {}

    if not ItemStates.PlayerValues[source][stateName] then
        ItemStates.RecheckState(source, stateName)
    end

    local state = ItemStates.PlayerValues[source][stateName]

    if not state then
        return nil
    end

    return state.progress
end

exports('GetItemStateProgress', ItemStates.GetStateProgress)


--инвент чтобы проверить при загрузке инвентаря
AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    if not Player or not Player.PlayerData then
        return
    end

    -- У игрока уже есть PlayerData.items и itemsByName.
    -- Выполнится первичный расчёт всех зарегистрированных состояний.
    Inventory.ItemStates.OnInventoryChanged(Player.PlayerData.source)
end)

--[[
CreateThread(function()
    -- Любые часы.
    exports['rsg-inventory']:RegisterItemState('inventory.hasWatch', {
        mode = 'any',
        items = {
            'pocketwatch1',
            'pocketwatch2',
            'pocketwatch3'
        }
    })

    -- Карта.
    exports['rsg-inventory']:RegisterItemState('inventory.hasMap', {
        mode = 'any',
        items = {
            'map'
        }
    })

    -- Компас.
    exports['rsg-inventory']:RegisterItemState('inventory.hasCompass', {
        mode = 'any',
        items = {
            'compass'
        }
    })

    -- Все вещи нужны одновременно.
    exports['rsg-inventory']:RegisterItemState('camp.canSetup', {
        mode = 'all',
        items = {
            'tent',
            'bedroll',
            'firekit'
        }
    })

    -- Нужны конкретные количества.
    exports['rsg-inventory']:RegisterItemState('quest.hasSupplies', {
        mode = 'requirements',
        items = {
            bread = 2,
            water = 3
        }
    })
	
	-- Коллекция — с количеством
	exports['rsg-inventory']:RegisterItemState('collection.herbs', {
    mode = 'requirements',

    -- Только это состояние будет получать progress.
    trackProgress = true,

    items = {
        yarrow = 5,
        sage = 3,
        ginseng = 1
    }
})
end)


Сервер: получить boolean
local hasWatch = exports['rsg-inventory']:GetItemState(
    source,
    'inventory.hasWatch'
)

if hasWatch then
    print(('Игрок %s имеет часы'):format(source))
end


Сервер: слушать изменения
AddEventHandler('rsg-inventory:server:itemStateChanged', function(source, stateName, value)
    if stateName ~= 'inventory.hasWatch' then
        return
    end

    if value then
        print(('Игрок %s получил часы'):format(source))
    else
        print(('Игрок %s потерял последние часы'):format(source))
    end
end)


Клиент: HUD часов
local hasWatch = false

RegisterNetEvent('rsg-inventory:client:itemStateChanged', function(stateName, value)
    if stateName ~= 'inventory.hasWatch' then
        return
    end

    hasWatch = value == true

    -- Твоя функция HUD.
    -- SetWatchVisible(hasWatch)
end)


--Сервер: получить прогресс коллекции
local completed = exports['rsg-inventory']:GetItemState(
    source,
    'collection.herbs'
)

local progress = exports['rsg-inventory']:GetItemStateProgress(
    source,
    'collection.herbs'
)

if progress then
    print(('Ты собрал тысячелистник: %s'):format(progress.yarrow.amount))
end

if completed then
    print('Коллекция трав завершена')
end

--Клиент: обновить интерфейс коллекции
RegisterNetEvent('rsg-inventory:client:itemStateChanged', function(stateName, value, progress)
    if stateName ~= 'collection.herbs' then
        return
    end
	
	if not progress then
        return
    end

    local yarrow = progress.yarrow
    local sage = progress.sage
    local ginseng = progress.ginseng

    -- UpdateCollectionUI('yarrow', yarrow.amount)
    -- UpdateCollectionUI('sage', sage.amount)
    -- UpdateCollectionUI('ginseng', ginseng.amount)

    print(('Ты собрал тысячелистник: %s'):format(yarrow.amount))

    if value then
        print('Коллекция трав завершена')
    end
end)
--]]

--[[
CreateThread(function()
    -- Любые часы.
    local ok, err = exports['rsg-inventory']:RegisterItemState('hasWatch', {
        mode = 'any',
        items = {   'pocketwatch1', 
					'pocketwatch2', 
					'pocketwatch3', 
					'pocketwatch4', 
					'pocketwatch5', 
					'pocketwatch6', 
					'pocketwatch7', 
					'pocketwatch8', 
					'pocketwatch9'
        }
    })
	
	if not ok then
        print(('[rsg-hud] RegisterItemState failed: %s'):format(err or 'unknown'))
    end
end)
--]]