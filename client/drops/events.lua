-- Сумки и их взаимодействия инициализируются только для вошедшего персонажа.
InventorySession.OnStart(function(session)
    Drops.ResetPlayerState()
    Drops.GetDrops(session)
end)

-- Ожидание стриминга допустимо только в текущей сессии и отменяется удалением сумки.
local pendingTargets = {}
InventorySession.OnStop(function() pendingTargets = {} end)

---Removes the target interaction from a dropped bag entity.
---@param dropId number Network ID of the entity that needs to have its ox_target removed
RegisterNetEvent('rsg-inventory:client:removeDropTarget', function(dropId)
    pendingTargets[dropId] = nil
    -- Если объект не стримится, удалять локальную привязку не нужно; ожидание не создаём.
    if not InventorySession.IsActive() or not NetworkDoesNetworkIdExist(dropId) then return end
    local bag = NetworkGetEntityFromNetworkId(dropId)
    if bag and bag ~= 0 and DoesEntityExist(bag) then exports.ox_target:removeLocalEntity(bag) end
end)

---Adds ox_target interactions (open / pickup) to a dropped bag entity.
---@param dropId number Network ID of the bag entity
RegisterNetEvent('rsg-inventory:client:setupDropTarget', function(dropId)
    -- Рассылка мировых сумок приходит и на экран входа: до загрузки её пропускаем.
    if not InventorySession.IsActive() then return end
    local session, token = InventorySession.GetGeneration(), {}
    pendingTargets[dropId] = token
    local bag
    while InventorySession.IsCurrent(session) and pendingTargets[dropId] == token do
        if NetworkDoesNetworkIdExist(dropId) then
            local entity = NetworkGetEntityFromNetworkId(dropId)
            if entity and entity ~= 0 and DoesEntityExist(entity) then bag = entity; break end
        end
        Wait(250)
    end
    if pendingTargets[dropId] == token then pendingTargets[dropId] = nil end
    if not bag or not InventorySession.IsCurrent(session) then return end

    local newDropId = Helpers.CreateDropId(dropId)

    exports.ox_target:addLocalEntity(bag, {
        {
            -- Open bag interaction
            name     = 'open_drop_' .. newDropId,
            icon     = 'fas fa-box',
            label    = locale('info.o_bag'),
            distance = 2.5,
            canInteract = function() return InventorySession.IsActive() end,
            onSelect = function()
                if not InventorySession.IsActive() then return end
                TriggerServerEvent('rsg-inventory:server:openDrop', newDropId)
                LocalPlayer.state.currentDrop = newDropId
            end,
        },
        {
            -- Pickup bag interaction
            name     = 'pickup_drop_' .. newDropId,
            icon     = 'fas fa-hand-pointer',
            label    = locale('info.Pickup_bag'),
            distance = 2.5,
            canInteract = function() return InventorySession.IsActive() end,
            onSelect = function()
                if not InventorySession.IsActive() then return end
                local interactionSession = InventorySession.GetGeneration()
                local weapon = GetPedCurrentHeldWeapon(PlayerPedId())

                -- Prevent picking up while holding weapon or another drop
                if weapon ~= `WEAPON_UNARMED` then
                    return lib.notify({
                        title       = locale('error.error'),
                        description = locale('error.error_gun_and_bag'),
                        type        = 'error',
                        duration    = 5500
                    })
                end
                if LocalPlayer.state.holdingDrop then
                    return lib.notify({
                        title       = locale('error.error'),
                        description = locale('error.error_already_holding_bag'),
                        type        = 'error',
                        duration    = 5500
                    })
                end

                -- Play pickup animation
                Citizen.InvokeNative(0x524B54361229154F, PlayerPedId(), GetHashKey("RANSACK_FALLBACK_PICKUP_CROUCH"), 0, 1, GetHashKey("RANSACK_PICKUP_H_0m0_FALLBACK_CROUCH"), -1.0, 0)

                Wait(1000)
                if not InventorySession.IsCurrent(interactionSession) or not DoesEntityExist(bag) then return end

                -- Attach bag to player's bone
                local config    = require 'shared.config'
                local boneIndex = GetEntityBoneIndexByName(PlayerPedId(), config.ItemDropObjectBone)

                AttachEntityToEntity(
                    bag,
                    PlayerPedId(),
                    boneIndex,
                    config.ItemDropObjectOffset[1].x,
                    config.ItemDropObjectOffset[1].y,
                    config.ItemDropObjectOffset[1].z,
                    config.ItemDropObjectOffset[2].x,
                    config.ItemDropObjectOffset[2].y,
                    config.ItemDropObjectOffset[2].z,
                    true, true, false, true, 1, true
                )

                -- Set client state
                LocalPlayer.state.dropBagObject = bag
                LocalPlayer.state.holdingDrop   = true
                LocalPlayer.state.heldDrop      = newDropId
            end
        }
    })
end)
