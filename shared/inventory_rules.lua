-- Общие правила клиента и сервера: проверка количества, метаданные и совместимость стаков.
-- Клиент использует их для подсказки вместимости, сервер — для фактической выдачи предметов.
InventoryRules = {}

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

-- Сравнивает все поля метаданных, включая вложенные таблицы.
-- У портящихся предметов время последнего расчёта не разделяет стаки; качество разделяет.
-- Игнорируется только верхний lastUpdate, одноимённые поля вложенных таблиц сравниваются.
function InventoryRules.SameMetadata(a, b, ignoreDecayTime)
    a, b = type(a) == 'table' and a or {}, type(b) == 'table' and b or {}
    for key, value in pairs(a) do
        if not (ignoreDecayTime and key == 'lastUpdate') then
            if type(value) == 'table' then
                if type(b[key]) ~= 'table' or not InventoryRules.SameMetadata(value, b[key], false) then return false end
            elseif value ~= b[key] then return false end
        end
    end
    for key in pairs(b) do
        if not (ignoreDecayTime and key == 'lastUpdate') and a[key] == nil then return false end
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
    if definition.decay then
        result.quality = result.quality or 100
        result.lastUpdate = result.lastUpdate or os.time()
    end
    return result
end

-- Одного имени недостаточно: уникальные предметы и разные метаданные не объединяются.
function InventoryRules.CanStackItem(existing, name, info, definition)
    return existing and definition and not definition.unique and not existing.unique
        and existing.name:lower() == name
        and InventoryRules.SameMetadata(existing.info, info, definition.decay ~= nil and definition.decay ~= false)
end
