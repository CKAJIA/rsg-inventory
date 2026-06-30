local RSGCore = exports['rsg-core']:GetCoreObject()
local config = require 'shared.config'

local tradeInviteActive = false
local tradeInviteInitiatorId = nil

function hideTradeInvite()
    tradeInviteActive = false
    tradeInviteInitiatorId = nil

    local token = exports['rsg-core']:GenerateCSRFToken()
    local invToken = GenerateInventoryCbToken()

    SendNUIMessage({
        action = 'hideTradeInvite',
        token = token,
        invToken = invToken,
    })
end

local function showTradeInvite(initiatorId, initiatorName)
    tradeInviteActive = true
    tradeInviteInitiatorId = initiatorId

    local token = exports['rsg-core']:GenerateCSRFToken()
    local invToken = GenerateInventoryCbToken()

    SendNUIMessage({
        action = 'showTradeInvite',
        initiatorId = initiatorId,
        initiatorName = initiatorName,
        duration = 30000,
		labels = buildLabels(),
        token = token,
        invToken = invToken,
    })
end
--[[
RegisterNetEvent('rsg-inventory:client:tradeRequest', function(initiatorId, initiatorName)
    lib.registerContext({
        id = 'trade_request',
        title = 'Trade Request',
        options = {
            {
                title = 'Accept trade from ' .. initiatorName,
                onSelect = function()
                    TriggerServerEvent('rsg-inventory:server:acceptTradeRequest', initiatorId)
                end
            },
            {
                title = 'Decline trade from ' .. initiatorName,
                onSelect = function()
                    TriggerServerEvent('rsg-inventory:server:declineTradeRequest', initiatorId)
                end
            }
        }
    })
    lib.showContext('trade_request')
end)
--]]

RegisterNetEvent('rsg-inventory:client:tradeRequest', function(initiatorId, initiatorName)
    showTradeInvite(initiatorId, initiatorName)
end)

RegisterNetEvent('rsg-inventory:client:tradeRequestCancelled', function()
    hideTradeInvite()
end)
--[[
RegisterNetEvent('rsg-inventory:client:tradeRequestCancelled', function()

    lib.hideContext()
end)
--]]
RegisterNetEvent('rsg-inventory:client:openTrade', function(tradeId, partnerId, partnerName, items, partnerData)
	hideTradeInvite()
	
    local token = exports['rsg-core']:GenerateCSRFToken()
    local invToken = GenerateInventoryCbToken()
    local Player = RSGCore.Functions.GetPlayerData()

    if not IsNuiFocused() then
        SetNuiFocus(true, true)
    end

    local myId = Player.source or Player.id or Player.citizenid

    SendNUIMessage({
        action = 'openTrade',
        tradeId = tradeId,
        partnerId = partnerId,
        partnerName = partnerName,
        inventory = items or Player.items,
        slots = Player.slots,
        maxweight = Player.weight,
		maxTradeSlots = config.MaxTradeSlots or 10,
        playerId = myId,
        playerName = (Player.charinfo and Player.charinfo.firstname)
            and (Player.charinfo.firstname .. ' ' .. Player.charinfo.lastname)
            or myId,
        cash = Player.money and Player.money.cash or 0,
        labels = buildLabels(),
        token = token,
        invToken = invToken,
    })
end)

RegisterNetEvent('rsg-inventory:client:updateTrade', function(tradeData)

    local token = exports['rsg-core']:GenerateCSRFToken()
    local invToken = GenerateInventoryCbToken()
    SendNUIMessage({
        action = 'updateTrade',
        tradeData = tradeData,
        token = token,
        invToken = invToken,
    })
end)

RegisterNetEvent('rsg-inventory:client:cancelTrade', function()

    local token = exports['rsg-core']:GenerateCSRFToken()
    local invToken = GenerateInventoryCbToken()
    SendNUIMessage({
        action = 'cancelTrade',
        token = token,
        invToken = invToken,
    })
end)

RegisterNetEvent('rsg-inventory:client:completeTrade', function()

    local token = exports['rsg-core']:GenerateCSRFToken()
    local invToken = GenerateInventoryCbToken()
    SendNUIMessage({
        action = 'completeTrade',
        token = token,
        invToken = invToken,
    })
end)

CreateThread(function()
    while true do
        if tradeInviteActive and tradeInviteInitiatorId then
            Wait(0)

            DisableControlAction(0, `INPUT_FRONTEND_PAUSE_ALTERNATE`, true)
            DisableControlAction(0, `INPUT_FRONTEND_ACCEPT`, true)
            DisableControlAction(0, `INPUT_FRONTEND_CANCEL`, true)

            if IsDisabledControlJustPressed(0, `INPUT_FRONTEND_ACCEPT`) then
                local initiatorId = tradeInviteInitiatorId
                hideTradeInvite()
                TriggerServerEvent('rsg-inventory:server:acceptTradeRequest', initiatorId)
            elseif IsDisabledControlJustPressed(0, `INPUT_FRONTEND_CANCEL`)
                or IsDisabledControlJustPressed(0, `INPUT_FRONTEND_PAUSE_ALTERNATE`) then
                local initiatorId = tradeInviteInitiatorId
                hideTradeInvite()
                TriggerServerEvent('rsg-inventory:server:declineTradeRequest', initiatorId)
            end
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

end)
