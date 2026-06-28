RegisterNUICallback('AcceptTradeRequest', function(data, cb)
    if not data or not data.initiatorId or not data.token or not ValidateInventoryCbToken(data.token) then
        cb(false)
        return
    end
	
	hideTradeInvite()
    TriggerServerEvent('rsg-inventory:server:acceptTradeRequest', data.initiatorId)
    cb(true)
end)

RegisterNUICallback('DeclineTradeRequest', function(data, cb)
    if not data or not data.initiatorId or not data.token or not ValidateInventoryCbToken(data.token) then
        cb(false)
        return
    end

	hideTradeInvite()
    TriggerServerEvent('rsg-inventory:server:declineTradeRequest', data.initiatorId)
    cb(true)
end)




RegisterNUICallback('AddTradeItem', function(data, cb)
	if not data or not data.item or not data.amount or not data.token or not ValidateInventoryCbToken(data.token) then
        cb({ ok = false })
        return
    end

	local success = lib.callback.await('rsg-inventory:server:addTradeItem', false, data.tradeId, data.item, data.amount)
    cb({ ok = success == true })
end)

RegisterNUICallback('RemoveTradeItem', function(data, cb)
    if not data or not data.tradeId or not data.tradeSlot or not data.token or not ValidateInventoryCbToken(data.token) then
        cb(false)
        return
    end
	
    local tradeId = data.tradeId
    local tradeSlot = tonumber(data.tradeSlot)
    local targetSlot = tonumber(data.targetSlot)
    local amount = tonumber(data.amount) or 1

    if not tradeSlot or not targetSlot or amount < 1 then
        cb(false)
        return
    end

    local success = lib.callback.await('rsg-inventory:server:removeTradeItem', false, tradeId, tradeSlot, targetSlot, amount)
    cb(success == true)
end)

RegisterNUICallback('ConfirmTrade', function(data, cb)
    if not data or not data.tradeId or not data.token or not ValidateInventoryCbToken(data.token) then
        cb('ok')
        return
    end
    TriggerServerEvent('rsg-inventory:server:confirmTrade', data.tradeId)
    cb('ok')
end)

RegisterNUICallback('CancelTrade', function(data, cb)
    if not data or not data.tradeId or not data.token or not ValidateInventoryCbToken(data.token) then
        cb('ok')
        return
    end
    TriggerServerEvent('rsg-inventory:server:cancelTrade', data.tradeId)
    cb('ok')
end)

RegisterNUICallback('InitiateTrade', function(data, cb)
    if not data or not data.targetId or not data.token or not ValidateInventoryCbToken(data.token) then
        cb('ok')
        return
    end
    TriggerServerEvent('rsg-inventory:server:initiateTrade', data.targetId)
    cb('ok')
end)
