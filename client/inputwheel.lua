local RSGCore = exports['rsg-core']:GetCoreObject()

local InputWheelConfig = require 'shared.inputwheelconfig'

local WheelItems = InputWheelConfig.WheelItems or {}
local SyncConfig = InputWheelConfig.Sync or {}
local NotifyConfig = InputWheelConfig.Notify or {}

local DEBUG_PREFIX = '^3[AWZ WHEEL]^7 '

local function dbg(...)
    if InputWheelConfig.Debug then
        print(DEBUG_PREFIX, ...)
    end
end

local function toHex(v)
    if type(v) ~= 'number' then
        return tostring(v)
    end

    if v < 0 then
        v = 0x100000000 + v
    end

    return string.format('0x%08X', v)
end

local function safeHash(nameOrHash)
    if type(nameOrHash) == 'number' then
        return nameOrHash
    end
    return GetHashKey(tostring(nameOrHash))
end

local function itemNameOrDefault(idx, args, fallback)
    return tostring(args[idx] or fallback)
end

local function qtyOrDefault(idx, args, fallback)
    local n = tonumber(args[idx] or fallback)
    if not n or n < 1 then
        return fallback
    end
    return math.floor(n)
end

local PedWheelWeapons = {}
-- Хеши понадобятся только после входа; при загрузке файлов нативы не вызываем.
local PedWheelWeaponNames = {
    'WEAPON_KIT_BINOCULARS',
    'WEAPON_KIT_BINOCULARS_IMPROVED',
    'WEAPON_KIT_CAMERA',
    'WEAPON_KIT_CAMERA_ADVANCED',
    'WEAPON_KIT_DETECTOR',
    'WEAPON_KIT_METAL_DETECTOR',
    -- 'WEAPON_MELEE_LANTERN',
    -- 'WEAPON_MELEE_DAVY_LANTERN',
    -- 'WEAPON_MELEE_LANTERN_HALLOWEEN',
    -- 'WEAPON_MELEE_LANTERN_ELECTRIC',
}

local WheelHook = {
    enabled = true,
    isOpen = false,
    currentWheel = 0, -- 0 weapons, 1 items, 2 horse
    selectedItem = 0,
    lastSelectedItem = 0,
    currentUsableItem = 0,
    currentUsableCoreItem = nil,
    lastUseAt = 0,
    useCooldownMs = (SyncConfig and SyncConfig.UseCooldownMs) or 350,
}

local WheelState = {
    desiredCounts = {},     -- [vorpItemName] = count
    appliedCounts = {},     -- [vorpItemName] = count
    nativeHashToVorp = {},  -- [nativeHash] = vorpItemName
}

local function buildNativeIndex()
    PedWheelWeapons = {}
    for _, name in ipairs(PedWheelWeaponNames) do PedWheelWeapons[safeHash(name)] = true end
    WheelState.nativeHashToVorp = {}

    for vorpItem, data in pairs(WheelItems or {}) do
        local nativeHash = safeHash(data.nativeName)
        WheelState.nativeHashToVorp[nativeHash] = vorpItem
    end
end

local function resetWheelMirrorState()
    WheelState.desiredCounts = {}
    WheelState.appliedCounts = {}

    WheelHook.isOpen = false
    WheelHook.currentWheel = 0
    WheelHook.selectedItem = 0
    WheelHook.lastSelectedItem = 0
    WheelHook.currentUsableItem = 0
    WheelHook.currentUsableCoreItem = nil
end

function NewGuid()
    local struct = DataView.ArrayBuffer(8 * 4)
    struct:SetInt32(0, 0)
    struct:SetInt32(8, 0)
    struct:SetInt32(16, 0)
    struct:SetInt32(24, 0)
    return struct
end

local function GuidToString(guid)
    if not guid then
        return 'nil-guid'
    end

    return string.format(
        '[%s %s %s %s]',
        toHex(guid:GetInt32(0) or 0),
        toHex(guid:GetInt32(8) or 0),
        toHex(guid:GetInt32(16) or 0),
        toHex(guid:GetInt32(24) or 0)
    )
end

function NewSlotInfo()
    local struct = DataView.ArrayBuffer(8 * 8)
    local guid = NewGuid()

    local function syncGuid()
        struct:SetInt32(0, guid:GetInt32(0))
        struct:SetInt32(8, guid:GetInt32(8))
        struct:SetInt32(16, guid:GetInt32(16))
        struct:SetInt32(24, guid:GetInt32(24))
    end

    syncGuid()

    struct:SetInt32(32, 0)
    struct:SetInt32(40, 0)
    struct:SetInt32(48, 0)
    struct:SetInt32(56, 0)

    function struct:GetGuidStruct()
        return guid
    end

    function struct:GetGuidBuffer()
        return guid:Buffer()
    end

    function struct:SetGuid(newGuid)
        guid:SetInt32(0, newGuid:GetInt32(0) or 0)
        guid:SetInt32(8, newGuid:GetInt32(8) or 0)
        guid:SetInt32(16, newGuid:GetInt32(16) or 0)
        guid:SetInt32(24, newGuid:GetInt32(24) or 0)
        syncGuid()
    end

    function struct:GetSlotId()
        return struct:GetInt32(56)
    end

    function struct:SetSlotId(slotId)
        struct:SetInt32(56, tonumber(slotId) or 0)
    end

    return struct
end

function NewItemInfo()
    local struct = DataView.ArrayBuffer(8 * 13)
    for i = 0, 96, 8 do
        struct:SetInt32(i, 0)
    end
    return struct
end

function GetPlayerInventoryItemGUID(item, guidBuffer, slotId)
    local outGuid = NewGuid()
    local result = Citizen.InvokeNative(0x886DFD3E185C8A89, 1, guidBuffer, item, slotId, outGuid:Buffer(), Citizen.ResultAsInteger())

    dbg('GetPlayerInventoryItemGUID', 'item=', item, toHex(item), 'slotId=', slotId, toHex(slotId), 'result=', result, 'guid=', GuidToString(outGuid))

    return outGuid, result
end

function GetPlayerInventoryGUID()
    local emptyGuid = NewGuid()
    local invGuid, result = GetPlayerInventoryItemGUID(`CHARACTER`, emptyGuid:Buffer(), `SLOTID_NONE`)
    dbg('PlayerInventoryGUID result=', result, 'guid=', GuidToString(invGuid))
    return invGuid, result
end

function GetItemGroup(item)
    local info = NewItemInfo()

    if ItemdatabaseIsKeyValid and not ItemdatabaseIsKeyValid(item, 0) then
        dbg('ERROR ItemdatabaseIsKeyValid false for', item, toHex(item))
        return 0, info
    end

    local ok = Citizen.InvokeNative(0xFE90ABBCBFDC13B2, item, info:Buffer())
    if not ok then
        dbg('ERROR ItemdatabaseFilloutItemInfo failed for', item, toHex(item))
        return 0, info
    end

    local group = info:GetInt32(16) or 0
    return group, info
end

function GetDefaultItemSlotInfo(item, context)
    return Citizen.InvokeNative(0x6452B1D357D81742, item, context)
end

function FitsSlot(item, slotId)
    return Citizen.InvokeNative(0x780C5B9AE2819807, item, slotId)
end

function ResolveItemSlotInfo(item)
    local slotInfo = NewSlotInfo()

    local playerInvGuid = select(1, GetPlayerInventoryGUID())
    slotInfo:SetGuid(playerInvGuid)
    slotInfo:SetSlotId(`SLOTID_SATCHEL`)

    local group = GetItemGroup(item)
	
	if group == `CLOTHING` then
        if FitsSlot(item, `SLOTID_WARDROBE`) then
            local wardrobeGuid = select(1, GetPlayerInventoryItemGUID(`WARDROBE`, slotInfo:GetGuidBuffer(), `SLOTID_WARDROBE`))
            slotInfo:SetGuid(wardrobeGuid)
            slotInfo:SetSlotId(GetDefaultItemSlotInfo(item, `WARDROBE`))
        else
            slotInfo:SetSlotId(GetDefaultItemSlotInfo(item, `SLOTID_WARDROBE`))
        end
    elseif group == `WEAPON` then
        if FitsSlot(item, `SLOTID_WEAPON_0`) then
            slotInfo:SetSlotId(`SLOTID_WEAPON_0`)
        elseif FitsSlot(item, `SLOTID_WEAPON_1`) then
            slotInfo:SetSlotId(`SLOTID_WEAPON_1`)
        else
            slotInfo:SetSlotId(GetDefaultItemSlotInfo(item, `CHARACTER`))
        end
    elseif group == `HORSE` then
        slotInfo:SetSlotId(`SLOTID_ACTIVE_HORSE`)
    elseif group == `UPGRADE` then
        if FitsSlot(item, `SLOTID_UPGRADE`) then
            slotInfo:SetSlotId(`SLOTID_UPGRADE`)
        else
            slotInfo:SetSlotId(GetDefaultItemSlotInfo(item, `CHARACTER`))
        end
    else
		if FitsSlot(item, `SLOTID_WATCH`) then
			slotInfo:SetSlotId(`SLOTID_WATCH`)
        elseif FitsSlot(item, `SLOTID_SATCHEL`) then
            slotInfo:SetSlotId(`SLOTID_SATCHEL`)
        elseif FitsSlot(item, `SLOTID_WARDROBE`) then
            slotInfo:SetSlotId(`SLOTID_WARDROBE`)
        else
            slotInfo:SetSlotId(GetDefaultItemSlotInfo(item, `CHARACTER`))
        end
    end

    return slotInfo, group
end

function GetExistingItemGuid(item)
    local slotInfo, group = ResolveItemSlotInfo(item)
    local existingGuid, guidResult = GetPlayerInventoryItemGUID(item, slotInfo:GetGuidBuffer(), slotInfo:GetSlotId())
    return slotInfo, existingGuid, guidResult, group
end

function AddItemWithGUID(item, newItemGuid, slotInfo, quantity, addReason)
    local inventoryGuidValid = Citizen.InvokeNative(0xB881CA836CC4B6D4, slotInfo:GetGuidBuffer())
    if not inventoryGuidValid then
        return false
    end

    return Citizen.InvokeNative(0xCB5D11F9508A928D, 1, newItemGuid:Buffer(), slotInfo:GetGuidBuffer(), item, slotInfo:GetSlotId(), quantity, addReason)
end

local function AddPedWheelWeapon(nativeHash)
    if not HasPedGotWeapon(cache.ped, nativeHash, 0, false) then
        GiveWeaponToPed(cache.ped, nativeHash, 0, false, true)
    end
end

local function RemovePedWheelWeapon(nativeHash)
    if HasPedGotWeapon(cache.ped, nativeHash, 0, false) then
        RemoveWeaponFromPed(cache.ped, nativeHash, true, 0)
    end
end


function AddItemToInventory(item, quantity)
    local slotInfo = ResolveItemSlotInfo(item)
    local newItemGuid = NewGuid()

    -- Добавляем предмет в нативный инвентарь.
    -- Игра заполняет newItemGuid идентификатором добавленного предмета.
    local added = AddItemWithGUID(item, newItemGuid, slotInfo, quantity, `ADD_REASON_DEFAULT`)

    if added ~= true and added ~= 1 then
        dbg('Не удалось добавить предмет в колесо:', item)
        return added
    end

	--Если это часы их нужно экипировать
    local fitsWatch = FitsSlot(item, `SLOTID_WATCH`)

    if fitsWatch == true or fitsWatch == 1 then
        -- Отмечаем часы экипированными, как в оригинальных скриптах.
        -- Используем тот же ID нативного инвентаря, что при добавлении.
        local equipped = Citizen.InvokeNative(0x734311E2852760D0, 1, newItemGuid:Buffer(), true, Citizen.ResultAsInteger())

        dbg('Экипировка часов:', item, 'результат:', equipped)
    end

    return added
end


function RemoveItemWithGuid(existingGuid, quantity, removeReason)
    return Citizen.InvokeNative(0x3E4E811480B3AE79, 1, existingGuid:Buffer(), quantity or 1, removeReason or `REMOVE_REASON_DEFAULT`)
end

function RemoveItemByName(item, quantity)
    local _, itemGuid, guidResult = GetExistingItemGuid(item)
    if guidResult ~= 1 then return false end

    local valid = Citizen.InvokeNative(
        0xB881CA836CC4B6D4, itemGuid:Buffer()
    )
    if valid ~= true and valid ~= 1 then return false end

    -- Возвращаем именно boolean: в Lua число 0 считается истинным.
    local removed = RemoveItemWithGuid(itemGuid, quantity, `REMOVE_REASON_DEFAULT`)
    return removed == true or removed == 1
end

local function clearManagedWheelItems()
    for _, data in pairs(WheelItems or {}) do
        local nativeHash = safeHash(data.nativeName)
        
		if PedWheelWeapons[nativeHash] then
            RemovePedWheelWeapon(nativeHash)
        else
			local removed = 0	
			while true do
				local ok = RemoveItemByName(nativeHash, 1)
				if not ok then
					break
				end
	
				removed = removed + 1
				if removed >= 250 then
					dbg('clearManagedWheelItems max guard hit for', data.nativeName)
					break
				end
			end
			
			if removed > 0 then
				dbg('clearManagedWheelItems removed', removed, data.nativeName)
			end
		end
    end
end


-- Если активных часов больше нет, экипируем любые оставшиеся.
-- Новые предметы не добавляем: используем существующий GUID.
local function EquipRemainingWatch()
    local candidates = {}

    -- Сбрасываем старые связи часов с предметами RSG.
    -- Порядок PocketWatches определяет, какие оставшиеся часы выбрать.
    for _, watch in ipairs(InputWheelConfig.PocketWatches or {}) do
        local config = WheelItems[watch.item]

        if config then
            local nativeHash = safeHash(config.nativeName)
            WheelState.nativeHashToVorp[nativeHash] = nil

            -- Не позволяем открытому колесу использовать старый выбор.
            if WheelHook.currentUsableItem == nativeHash then
                WheelHook.currentUsableItem = 0
                WheelHook.currentUsableCoreItem = nil
                WheelHook.lastSelectedItem = -1
            end

            if (tonumber(WheelState.desiredCounts[watch.item]) or 0) > 0 then
                candidates[#candidates + 1] = {
                    name = watch.item,
                    hash = nativeHash,
                }
            end
        end
    end

    -- Экипируем существующие часы, которые остались у игрока.
    for _, watch in ipairs(candidates) do
        local fitsWatch = FitsSlot(watch.hash, `SLOTID_WATCH`)

        if fitsWatch == true or fitsWatch == 1 then
            local _, itemGuid, guidResult = GetExistingItemGuid(watch.hash)

            if guidResult == 1 then
                local equipped = Citizen.InvokeNative(0x734311E2852760D0, 1, itemGuid:Buffer(), true, Citizen.ResultAsInteger())

                if equipped == 1 then
                    -- Связываем значок с реально имеющимся предметом.
                    WheelState.nativeHashToVorp[watch.hash] = watch.name
                    return
                end
            end
        end
    end
end



local function ApplyWheelSnapshot(snapshot)
    snapshot = snapshot or {}
    WheelState.desiredCounts = snapshot

    for itemName, config in pairs(WheelItems or {}) do
        local desired = tonumber(snapshot[itemName]) or 0
        local applied = tonumber(WheelState.appliedCounts[itemName]) or 0
        local nativeHash = safeHash(config.nativeName)

        if PedWheelWeapons[nativeHash] then
            if desired > 0 then
                AddPedWheelWeapon(nativeHash)
                applied = 1
            else
                RemovePedWheelWeapon(nativeHash)
                applied = 0
            end
        else
            local diff = desired - applied
            local step = diff > 0 and 1 or -1

            for _ = 1, math.abs(diff) do
                local result

                if step == 1 then
                    result = AddItemToInventory(nativeHash, 1)
                else
                    result = RemoveItemByName(nativeHash, 1)
                end

                -- Не записываем неудачное изменение как выполненное.
                if result ~= true and result ~= 1 then
                    dbg('Ошибка синхронизации колеса:', itemName, desired, applied)
                    break
                end

                applied = applied + step
            end
        end

        WheelState.appliedCounts[itemName] = applied
    end

    -- После удаления старых часов экипируем оставшиеся.
    EquipRemainingWatch()
end

local function UpdateCurrentUsableWheelItem(itemHash)
    WheelHook.currentUsableItem = 0
    WheelHook.currentUsableCoreItem = nil

    if not itemHash or itemHash == 0 then
        return
    end

    local item = WheelState.nativeHashToVorp[itemHash]
    if not item then
        return
    end
	
--	if PedWheelWeapons[itemHash] then
--        WheelHook.currentUsableItem = itemHash
--        WheelHook.currentUsableCoreItem = item
--        return
--    end

    if ItemdatabaseIsKeyValid and not ItemdatabaseIsKeyValid(itemHash, 0) then
        return
    end

    local _, _, guidResult = GetExistingItemGuid(itemHash)
    if guidResult == 1 then
        WheelHook.currentUsableItem = itemHash
        WheelHook.currentUsableCoreItem = item
    end
end

local function HandleQuickSelectMessages()
    while EventsUiIsPending(`HUD_QUICK_SELECT`) do
        local msg = DataView.ArrayBuffer(8 * 4)
        msg:SetInt32(0, 0)
        msg:SetInt32(8, 0)
        msg:SetInt32(16, 0)
        msg:SetInt32(24, 0)

        local ok = Citizen.InvokeNative(0xE24E957294241444, `hud_quick_select`, msg:Buffer())
        if ok ~= 0 then
            local f0 = msg:GetInt32(0) or 0
            local f1 = msg:GetInt32(8) or 0
            local f2 = msg:GetInt32(16) or 0

            if f0 == `ITEM_FOCUSED` then
                if f1 == 1 and f2 == 813560150 then
                    WheelHook.currentWheel = 0
                elseif f1 == 2 and f2 == -414255251 then
                    WheelHook.currentWheel = 1
                elseif f1 == 3 and f2 == -1472057397 then
                    WheelHook.currentWheel = 2
                end
            end
        end
    end
end

local function prettifyItemName(vorpItemName)
    local cfg = WheelItems and WheelItems[vorpItemName]
    if cfg and cfg.notifyText and cfg.notifyText ~= '' then
        return tostring(cfg.notifyText)
    end

    local text = tostring(vorpItemName or 'ITEM USATO')
    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    text = text:gsub('_', ' ')
    text = text:upper()

    return text
end

local function showUsedItemNotification(itemName, amount)
    local notifyCfg = NotifyConfig or {}
    if notifyCfg.Enabled == false then
        return
    end

    local cfg = WheelItems and WheelItems[itemName]
    -- Отдельный предмет может отключить уведомление, сохранив своё действие.
    -- Если флаг не указан, действует общий переключатель Notify.Enabled выше.
    if cfg and cfg.showNotification == false then
        return
    end

    local title = notifyCfg.Title or 'Hai usato'
    local dict = notifyCfg.Dict or 'inventory_items'
    local color = notifyCfg.Color or 'COLOR_WHITE'
    local duration = tonumber(notifyCfg.Duration or 5000) or 5000

    local nativeNameForNotify = 'lock'
    if cfg and cfg.nativeName and cfg.nativeName ~= '' then
        nativeNameForNotify = tostring(cfg.nativeName)
    end

    local prettyName = prettifyItemName(itemName)

    TriggerEvent(
        notifyCfg.Event or 'awz_Notify:ShowAdvancedRightNotification',
        title .. ' ' .. '~o~' .. prettyName,
        dict,
        nativeNameForNotify,
        color,
        duration
    )
end

local function HandleWheelHook()
    if not WheelHook.enabled then
        return
    end

    local running = IsUiappRunning("hud_quick_select")

    if running then
        WheelHook.isOpen = true
        HandleQuickSelectMessages()

        local selected = Citizen.InvokeNative(0x9C409BBC492CB5B1, Citizen.ResultAsInteger())
        if selected ~= WheelHook.lastSelectedItem then
            WheelHook.lastSelectedItem = selected or 0
            WheelHook.selectedItem = selected or 0

			if WheelHook.currentWheel == 1 or WheelHook.currentWheel == 2 then
                UpdateCurrentUsableWheelItem(selected or 0)
            end
        end

        return
    end

    if WheelHook.isOpen then
        local wheelBeforeClose = WheelHook.currentWheel
        local usableNative = WheelHook.currentUsableItem
        local usableCoreItem = WheelHook.currentUsableCoreItem
        local now = GetGameTimer()

        WheelHook.isOpen = false
        WheelHook.currentWheel = 0
        WheelHook.selectedItem = 0
        WheelHook.lastSelectedItem = 0
        WheelHook.currentUsableItem = 0
        WheelHook.currentUsableCoreItem = nil

		if (wheelBeforeClose == 1 or wheelBeforeClose == 2) and usableNative and usableNative ~= 0 and usableCoreItem then
			if now >= (WheelHook.lastUseAt + WheelHook.useCooldownMs) then
				WheelHook.lastUseAt = now
		
				if PedWheelWeapons[usableNative] then
					SetCurrentPedWeapon(cache.ped, usableNative, true)
				else
					TriggerServerEvent('rsg-inventory:server:inputWheelUseItem', usableCoreItem)
				end
			end
		end
    end
end

-- Нативное зеркало создаём и обслуживаем только для вошедшего персонажа.
local wheelInitialized = false
InventorySession.OnStart(function(session)
    buildNativeIndex()
    clearManagedWheelItems()
    resetWheelMirrorState()
    wheelInitialized = true

    -- После выхода/смены персонажа отложенный запрос старой сессии ничего не отправит.
    SetTimeout((SyncConfig and SyncConfig.RequestOnClientStartDelayMs) or 3000, function()
        if InventorySession.IsCurrent(session) then
            TriggerServerEvent('rsg-inventory:server:requestSync', true)
        end
    end)
    while InventorySession.IsCurrent(session) do
        HandleWheelHook()
        Wait(0)
    end
end)

InventorySession.OnStop(function()
    if wheelInitialized and cache.ped and DoesEntityExist(cache.ped) then clearManagedWheelItems() end
    wheelInitialized = false
    resetWheelMirrorState()
end)

RegisterNetEvent('rsg-inventory:client:applySnapshot', function(snapshot)
    -- Поздний ответ не должен добавлять предметы в педа экрана выбора персонажа.
    if not InventorySession.IsActive() or not wheelInitialized then return end
    ApplyWheelSnapshot(snapshot)
end)

--RegisterNetEvent('rsg-inventory:client:forceResync', function()
--    TriggerServerEvent('rsg-inventory:server:requestSync')
--end)

--RegisterNetEvent('rsg-inventory:client:invokeVorpUseItem', function(payload)
--    if not payload or not payload.id or not payload.item then
--        dbg('invokeVorpUseItem invalid payload')
--        TriggerServerEvent('rsg-inventory:server:requestSync')
--        return
--    end
--
--    dbg('invokeVorpUseItem', payload.item, payload.id)
--    --TriggerServerEvent('vorp_inventory:useItem', payload)
--
--    CreateThread(function()
--        Wait((SyncConfig and SyncConfig.RequestAfterUseMs) or 900)
--        TriggerServerEvent('rsg-inventory:server:requestSync')
--    end)
--end)

RegisterNetEvent('rsg-inventory:client:showUsedNotification', function(itemName, amount)
    if not InventorySession.IsActive() then return end
    showUsedItemNotification(itemName, amount)
end)

RegisterCommand('awz_addnativeitem', function(_, args)
    if not InventorySession.IsActive() then return end
    local itemName = itemNameOrDefault(1, args, 'CONSUMABLE_PEACHES_CAN')
    local qty = qtyOrDefault(2, args, 1)
    local itemHash = safeHash(itemName)
    AddItemToInventory(itemHash, qty)
end, false)

RegisterCommand('awz_removenativeitem', function(_, args)
    if not InventorySession.IsActive() then return end
    local itemName = itemNameOrDefault(1, args, 'CONSUMABLE_PEACHES_CAN')
    local qty = qtyOrDefault(2, args, 1)
    local itemHash = safeHash(itemName)
    RemoveItemByName(itemHash, qty)
end, false)



--Ивент для использования часов и компасов.
RegisterNetEvent('rsg-inventory:client:inspectwatch', function(data)

    if data.type == 'Inspect' then
        local prop = CreateObject(joaat(data.prop), GetEntityCoords(cache.ped), false, true, false, false, true)
        TaskItemInteraction_2(cache.ped, joaat(data.promptLabel), prop, joaat("PrimaryItem"), joaat('POCKET_WATCH_INSPECT_UNHOLSTER'), 1, 0, -1.0)
        Wait(500)

        while IsPedRunningTaskItemInteraction(cache.ped) and not IsControlPressed(0, joaat('INPUT_CONTEXT_B')) do
            Wait(0)
        end
	elseif data.type == 'InspectZ' then
        local prop = CreateObject(joaat(data.prop), GetEntityCoords(cache.ped), false, true, false, false, true)
        TaskItemInteraction_2(cache.ped, joaat(data.promptLabel), prop, joaat("PrimaryItem"), joaat('POCKETWATCH@D6-5_H1-5_InspectZ_HOLD'), 1, 0, -1.0)
        Wait(500)

        while IsPedRunningTaskItemInteraction(cache.ped) and not IsDisabledControlJustReleased(0, joaat('INPUT_GAME_MENU_CANCEL')) do
            Wait(0)    
        end
    end    

    ClearPedTasks(cache.ped)
end)

