-- Регистрация взаимодействия выполняется один раз после входа.
local targetRegistered = false
InventorySession.OnStart(function(session)
    if targetRegistered then return end
    Wait(5000)
    if not InventorySession.IsCurrent(session) then return end

    local ok = pcall(function()
        return exports.ox_target.addGlobalPlayer
    end)
    if not ok then return end

    exports.ox_target:addGlobalPlayer({
        {
            name = 'trade',
            label = locale('ui.trade') or 'Trade',
            icon = 'fas fa-handshake',
            canInteract = function() return InventorySession.IsActive() end,
            onSelect = function(data)
                if not InventorySession.IsActive() then return end
                local entity = data.entity
                if IsPedAPlayer(entity) then
                    local playerIndex = NetworkGetPlayerIndexFromPed(entity)
                    local serverId = GetPlayerServerId(playerIndex)
                    if serverId then
                        TriggerServerEvent('rsg-inventory:server:initiateTrade', serverId)
                    end
                end
            end,
        },
    }, 2.5)
    targetRegistered = true
end)
