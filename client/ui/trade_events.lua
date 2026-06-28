local RSGCore = exports['rsg-core']:GetCoreObject()
local config = require 'shared.config'

local tradeInviteActive = false
local tradeInviteInitiatorId = nil
local tradeInviteInitiatorName = nil

local tradePromptGroup = GetRandomIntInRange(0, 0xFFFFFF)
local tradePromptGroupText = CreateVarString(10, 'LITERAL_STRING', 'Trade Request')

local acceptPrompt = nil
local declinePrompt = nil

local function createPrompt(control, text)
    local str = CreateVarString(10, 'LITERAL_STRING', text)
    local prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, control)
    PromptSetText(prompt, str)
    PromptSetEnabled(prompt, false)
    PromptSetVisible(prompt, false)
    PromptSetStandardMode(prompt, true)
    PromptSetGroup(prompt, tradePromptGroup)
    PromptRegisterEnd(prompt)
    return prompt
end

local function ensureTradePrompts()
    if acceptPrompt and declinePrompt then
        return
    end

    acceptPrompt = createPrompt(`INPUT_FRONTEND_ACCEPT`, locale('ui.accept'))
    declinePrompt = createPrompt(`INPUT_FRONTEND_CANCEL`, locale('ui.cancel'))
end

function setTradePromptsVisible(state, initiatorName)
    ensureTradePrompts()

    PromptSetEnabled(acceptPrompt, state)
    PromptSetVisible(acceptPrompt, state)

    PromptSetEnabled(declinePrompt, state)
    PromptSetVisible(declinePrompt, state)

    if initiatorName and state then
        tradePromptGroupText = CreateVarString(10, 'LITERAL_STRING', initiatorName .. locale('ui.trade_request'))
    else
        tradePromptGroupText = CreateVarString(10, 'LITERAL_STRING', 'Trade Request')
    end
end

function hideTradeInvite()
    tradeInviteActive = false
    tradeInviteInitiatorId = nil
    tradeInviteInitiatorName = nil

    setTradePromptsVisible(false)

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
    tradeInviteInitiatorName = initiatorName

    setTradePromptsVisible(true, initiatorName)

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
    ensureTradePrompts()

    while true do
        if tradeInviteActive and tradeInviteInitiatorId then
            Wait(0)

            PromptSetActiveGroupThisFrame(tradePromptGroup, tradePromptGroupText)

            if PromptHasStandardModeCompleted(acceptPrompt) then
                local initiatorId = tradeInviteInitiatorId
                hideTradeInvite()
                TriggerServerEvent('rsg-inventory:server:acceptTradeRequest', initiatorId)
            elseif PromptHasStandardModeCompleted(declinePrompt) then
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

    if acceptPrompt then
        PromptDelete(acceptPrompt)
        acceptPrompt = nil
    end

    if declinePrompt then
        PromptDelete(declinePrompt)
        declinePrompt = nil
    end
end)
