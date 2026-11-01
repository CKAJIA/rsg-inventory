local RSGCore = exports['rsg-core']:GetCoreObject()
-- Возвращает клиенту актуальные сумки в мире.
lib.callback.register('rsg-inventory:server:GetCurrentDrops', function(source)
    return Drops -- Все активные сумки.
end)

-- Общее создание сумок для ручного выброса и выдачи наград.
-- Создаёт объект и проверяет сетевой ID до списания ручного выброса.
-- Ручной выброс берёт настоящий предмет и info из серверного слота.
-- preparedItems используется только внутренней выдачей награды для нескольких unique-предметов.
local function CreateItemDrop(coords, itemData, shouldRemoveFromInventory, source, preparedItems)
    local config = require 'shared.config'
    if type(itemData) ~= 'table' or type(itemData.name) ~= 'string' then return false end
    local amount = Inventory.ValidAmount(itemData.amount)
    if not amount then return false end
    itemData = Inventory.CopyItemData(itemData)
    itemData.amount = amount
    if shouldRemoveFromInventory and not Inventory.ValidAmount(itemData.fromSlot) then return false end


    -- Сначала создаём объект; до подтверждения предмет остаётся у игрока.
    local bag = CreateObjectNoOffset(
        config.ItemDropObject,
        coords.x + 0.5,
        coords.y + 0.5,
        coords.z,
        true, true, false
    )

    -- Ожидание появления объекта ограничено по времени.
    local timeout = 100
    while not DoesEntityExist(bag) and timeout > 0 do
        Wait(50)
        timeout -= 1
    end

    if not DoesEntityExist(bag) then return false end

    local networkId = NetworkGetNetworkIdFromEntity(bag)
    if not networkId or networkId == 0 or Drops[Helpers.CreateDropId(networkId)] then
        DeleteEntity(bag)
        return false
    end

    -- Списываем только после появления объекта и проверки его сетевого ID.
    if shouldRemoveFromInventory and source then
        -- Получаем настоящий серверный предмет по слоту, не доверяя метаданным клиента.
        local realItem = Inventory.GetItemBySlot(source, itemData.fromSlot)
        if not realItem or realItem.name:lower() ~= itemData.name:lower() or realItem.amount < itemData.amount then
            DeleteEntity(bag)
            return false
        end

        -- Все свойства и info копируются из настоящего серверного стака.
        local requestedAmount, fromSlot = itemData.amount, itemData.fromSlot
        itemData = Inventory.CopyItemData(realItem)
        itemData.amount, itemData.fromSlot, itemData.slot = requestedAmount, fromSlot, 1

        local isMove = realItem.type == 'weapon'
        if isMove then
            Inventory.CheckWeapon(source, itemData)
        end

        if not Inventory.RemoveItem(source, realItem.name, itemData.amount, itemData.fromSlot, 'dropped item', isMove) then
            DeleteEntity(bag)
            return false
        end

        -- Анимацию запускает клиент после подтверждения. Серверный TaskPlayAnim здесь
        -- вызывал RPC-ошибку уже после списания и до регистрации содержимого сумки.
        -- Между успешным списанием и записью Drops не выполняем косметических нативов.
    end

    -- Создаём идентификатор сумки из уже проверенного сетевого ID.
    local newDropId = Helpers.CreateDropId(networkId)

    -- Внутренняя награда может содержать несколько заранее подготовленных unique-предметов.
    local itemsTable = not shouldRemoveFromInventory and preparedItems or { itemData }

    -- Регистрируем содержимое сумки в серверной таблице Drops.
    if not Drops[newDropId] then
        Drops[newDropId] = {
            name = newDropId,
            label = 'Drop',
            items = itemsTable,
            entityId = networkId,
            createdTime = os.time(),
            coords = coords,
            maxweight = config.DropSize.maxweight,
            slots = config.DropSize.slots,
            isOpen = false
        }

        -- Создаём взаимодействие с сумкой у клиентов.
        TriggerClientEvent('rsg-inventory:client:setupDropTarget', -1, networkId)
    else
        -- Дополнение уже зарегистрированной сумки.
        table.insert(Drops[newDropId].items, itemData)
    end

    return networkId
end

Helpers.CreateItemDrop = CreateItemDrop

-- Ограничение частоты ручного создания сумок.
local dropCooldowns = {}

-- Ручной выброс: количество и исходный слот дополнительно проверяются сервером.
lib.callback.register('rsg-inventory:server:createDrop', function(source, item)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end

    -- Проверяем задержку между запросами.
    local now = os.time()
    if dropCooldowns[source] and now - dropCooldowns[source] < 1 then return false end
    dropCooldowns[source] = now

    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)

    -- Используем общий путь создания и проверки сумки.
    return CreateItemDrop(playerCoords, item, true, source)
end)
