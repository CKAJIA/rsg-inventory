-- Жизненный цикл загруженного персонажа. До входа нет циклов ожидания входа:
-- задачи запускаются событиями ядра, а при выходе завершаются по номеру сессии.
InventorySession = {}
local active, generation = false, 0
local startHandlers, stopHandlers = {}, {}

-- Быстрая локальная проверка, без чтения state bag или всего PlayerData каждый кадр.
function InventorySession.IsActive()
    return active
end

-- Номер меняется и при входе, и при выходе: старый таймер не затронет нового персонажа.
function InventorySession.GetGeneration()
    return generation
end

-- Проверяет, что кадр/отложенный ответ относится к всё ещё вошедшему персонажу.
function InventorySession.IsCurrent(session)
    return active and generation == session
end

-- Подписывает модуль на вход. Каждый обработчик получает собственную задачу;
-- повторный OnPlayerLoaded не создаёт повторных циклов.
function InventorySession.OnStart(handler)
    startHandlers[#startHandlers + 1] = handler
    if active then
        local session = generation
        CreateThread(function()
            if InventorySession.IsCurrent(session) then handler(session) end
        end)
    end
end

-- Очистка выполняется при выходе до следующей сессии, без фонового опроса.
function InventorySession.OnStop(handler)
    stopHandlers[#stopHandlers + 1] = handler
end

-- Запускает подписанные задачи один раз для текущего входа.
local function startSession()
    if active then return end
    active, generation = true, generation + 1
    local session = generation
    for _, handler in ipairs(startHandlers) do
        local callback = handler
        CreateThread(function()
            if InventorySession.IsCurrent(session) then callback(session) end
        end)
    end
end

-- Сначала делает все старые задачи неактуальными, затем выполняет разовую очистку.
local function stopSession()
    if not active then return end
    active, generation = false, generation + 1
    for _, handler in ipairs(stopHandlers) do
        local ok, errorMessage = pcall(handler)
        if not ok then print(('[rsg-inventory] Ошибка очистки сессии: %s'):format(tostring(errorMessage))) end
    end
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', startSession)
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', stopSession)

-- При обычном подключении флаг ещё false. При рестарте ресурса в игре персонаж уже вошёл.
-- Читаем state bag один раз на старт, а не запускаем отдельный цикл проверки входа.
local function onResourceStart(resourceName)
    if resourceName == GetCurrentResourceName() and LocalPlayer.state.isLoggedIn == true then startSession() end
end
local function onResourceStop(resourceName)
    if resourceName == GetCurrentResourceName() then stopSession() end
end
-- Поддерживаем клиентские события Cfx и прежние обработчики ресурса; запуск идемпотентен.
AddEventHandler('onClientResourceStart', onResourceStart)
AddEventHandler('onResourceStart', onResourceStart)
AddEventHandler('onClientResourceStop', onResourceStop)
AddEventHandler('onResourceStop', onResourceStop)
