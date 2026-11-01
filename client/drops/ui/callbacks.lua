-- Только внешний вид уже подтверждённого сервером выброса.
-- Ошибка анимации или ожидания стриминга не отменяет успешно созданную сумку.
local function placeConfirmedDrop(dropId, session)
    if not InventorySession.IsCurrent(session) then return end
    ClearPedTasksImmediately(cache.ped)
    TaskStartScenarioInPlaceHash(
        cache.ped,
        GetHashKey('RANSACK_FALLBACK_PICKUP_CROUCH'),
        0, true,
        GetHashKey('RANSACK_PICKUP_H_0m0_FALLBACK_CROUCH'),
        -1.0, false
    )

    -- Ограниченное ожидание нужно только для размещения объекта, не для подтверждения выдачи.
    local timeout = 100
    while not NetworkDoesNetworkIdExist(dropId) and timeout > 0 do
        Wait(50)
        if not InventorySession.IsCurrent(session) then return end
        timeout -= 1
    end
    if not NetworkDoesNetworkIdExist(dropId) then return end
    local bag = NetworkGetEntityFromNetworkId(dropId)
    if not bag or bag == 0 or not DoesEntityExist(bag) then return end

    -- Этот натив принимает хеш модели, а не идентификатор объекта.
    SetModelAsNoLongerNeeded(GetEntityModel(bag))
    local coords = GetEntityCoords(cache.ped)
    local forward = GetEntityForwardVector(cache.ped)
    local dropCoords = coords + forward * 0.57
    SetEntityCoords(bag, dropCoords.x, dropCoords.y, dropCoords.z - 0.9, false, false, false, false)
    SetEntityRotation(bag, 0.0, 0.0, 0.0, 2)
    PlaceObjectOnGroundProperly(bag)
    FreezeEntityPosition(bag, true)
end

-- Сервер единолично списывает предмет и регистрирует содержимое сумки.
-- После успешного ответа подтверждаем NUI ровно один раз, до косметических действий.
RegisterNUICallback('DropItem', function(data, cb)
    if not InventorySession.IsActive() then cb(false); return end
    local session = InventorySession.GetGeneration()
    if not data or not data.token or not ValidateInventoryCbToken(data.token) then
        cb(false)
        return
    end
    local dropId = lib.callback.await('rsg-inventory:server:createDrop', false, data)
    if not dropId then
        cb(false)
        return
    end

    cb(Helpers.CreateDropId(dropId))
    CreateThread(function()
        -- Предмет уже находится в Drops: сбой оформления нельзя сообщать как отказ выдачи.
        local ok, errorMessage = pcall(placeConfirmedDrop, dropId, session)
        if not ok then
            print(('[rsg-inventory] Сумка %s создана; ошибка анимации/размещения: %s')
                :format(tostring(dropId), tostring(errorMessage)))
        end
    end)
end)

-- Callback triggered when dropping an item fails (e.g., invalid or blocked)
RegisterNUICallback('PlayDropFail', function(data, cb)
    if not data or not data.token or not ValidateInventoryCbToken(data.token) then
        cb('ok')
        return
    end
    -- Play a failure sound to notify the player
    PlaySound(-1, 'Place_Prop_Fail', 'DLC_Dmod_Prop_Editor_Sounds', 0, 0, 1)
    cb('ok') -- Return success to the UI even though the drop failed
end)
