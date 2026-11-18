local RSGCore = exports['rsg-core']:GetCoreObject()
-- Общие правила клиента и сервера: проверка количества, метаданные и совместимость стаков.
-- Клиент использует их для подсказки вместимости, сервер — для фактической выдачи предметов.
InventoryRules = {}

-- Единый формат серийного номера оружия: 2 цифры, 3 буквы, 1 цифра, 2 буквы, 3 цифры, 4 буквы.
-- Используется и при ручной выдаче (/giveitem), и при обычной выдаче через PlanAddItem,
-- чтобы формат номера менялся в одном месте.
function InventoryRules.GenerateWeaponSerial()
    return string.format(
        "%s%s%s%s%s%s",
        RSGCore.Shared.RandomInt(2),
        RSGCore.Shared.RandomStr(3),
        RSGCore.Shared.RandomInt(1),
        RSGCore.Shared.RandomStr(2),
        RSGCore.Shared.RandomInt(3),
        RSGCore.Shared.RandomStr(4)
    )
end

-- Принимает только положительное целое количество. nil заменяется указанным default.
-- Отсекает дроби, NaN и бесконечность до любых изменений инвентаря.
function InventoryRules.ValidAmount(value, default)
    if value == nil then value = default end
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value < 1 or value > 2147483647 or value % 1 ~= 0 then return nil end
    return value
end

-- Копирует вложенные метаданные, чтобы планирование операции не меняло исходный предмет.
-- seen сохраняет уже скопированные таблицы и защищает от циклических ссылок.
function InventoryRules.CopyItemData(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do copy[key] = InventoryRules.CopyItemData(item, seen) end
    return copy
end

function InventoryRules.GetDecayMinutes(definition)
    local minutes = definition and tonumber(definition.decay)
    return minutes and minutes > 0 and minutes < math.huge and minutes or nil
end

local function wholeQuality(value)
    return math.max(0, math.min(100, math.floor((tonumber(value) or 100) + 0.5)))
end

-- lastUpdate — граница последнего целого процента. Неполный шаг остаётся
-- в разнице с now, а при заморозке хранится в decayCarry (секунды при скорости 1).
function InventoryRules.ApplyDecay(info, minutes, now, rate)
    rate = rate or 1
    local quality = wholeQuality(info.quality)
    local lastUpdate = tonumber(info.lastUpdate) or now
    local previousRate = tonumber(info.decayRate) or rate
    local carry = tonumber(info.decayCarry) or 0
    local secondsPerPercent = minutes * 0.6
    if previousRate > 0 and quality > 0 then
        -- Целые микросекунды исключают накопление погрешности при частых проверках.
        local scale = 1000000
        local start = math.floor(lastUpdate * scale + 0.5)
        local elapsed = math.max(0, math.floor(now * scale + 0.5) - start)
        local interval = math.max(1, math.floor(secondsPerPercent / previousRate * scale + 0.5))
        local steps = math.min(quality, math.floor(elapsed / interval))
        quality = quality - steps
        if steps > 0 then lastUpdate = (start + steps * interval) / scale end
        carry = math.max(0, now - lastUpdate) * previousRate
    end
    if quality == 0 then carry = 0 end
    if rate ~= previousRate then
        lastUpdate = rate > 0 and (now - carry / rate) or now
    end
    carry = rate == 0 and carry or nil
    local changed = info.quality ~= quality or info.lastUpdate ~= lastUpdate
        or info.decayRate ~= rate or info.decayCarry ~= carry
    info.quality, info.lastUpdate, info.decayRate, info.decayCarry = quality, lastUpdate, rate, carry
    return changed
end

local function isDecayClock(key)
    return key == 'lastUpdate' or key == 'decayRate' or key == 'decayCarry'
end

-- Сравнивает все поля метаданных, включая вложенные таблицы.
-- У портящихся предметов служебные поля таймера не разделяют стаки; качество разделяет.
function InventoryRules.SameMetadata(a, b, ignoreDecayTime)
    a, b = type(a) == 'table' and a or {}, type(b) == 'table' and b or {}
    for key, value in pairs(a) do
        if not (ignoreDecayTime and isDecayClock(key)) then
            if type(value) == 'table' then
                if type(b[key]) ~= 'table' or not InventoryRules.SameMetadata(value, b[key], false) then return false end
            elseif value ~= b[key] then return false end
        end
    end
    for key in pairs(b) do
        if not (ignoreDecayTime and isDecayClock(key)) and a[key] == nil then return false end
    end
    return true
end

-- Берёт info из описания предмета и поверх него накладывает переданные поля.
-- Исходные таблицы не меняются; для decay добавляются начальное качество и время.
function InventoryRules.PrepareItemInfo(definition, info)
    local result = InventoryRules.CopyItemData(type(definition.info) == 'table' and definition.info or {})
    for key, value in pairs(type(info) == 'table' and info or {}) do
        result[key] = InventoryRules.CopyItemData(value)
    end
    if InventoryRules.GetDecayMinutes(definition) then
        result.quality = wholeQuality(result.quality)
        result.lastUpdate = tonumber(result.lastUpdate) or os.time()
    end
    return result
end

-- Одного имени недостаточно: уникальные предметы и разные метаданные не объединяются.
function InventoryRules.CanStackItem(existing, name, info, definition)
    return existing and definition and not definition.unique and not existing.unique
        and existing.name:lower() == name
        and InventoryRules.SameMetadata(existing.info, info, InventoryRules.GetDecayMinutes(definition) ~= nil)
end
