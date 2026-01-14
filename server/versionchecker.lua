local RSGCore = exports['rsg-core']:GetCoreObject()

local resourceName = GetCurrentResourceName()
local githubRawBase = 'https://raw.githubusercontent.com/Rexshack-RedM/rsg-versioncheckers/main/'

-----------------------------------------------------------------------
-- version checker
-----------------------------------------------------------------------
local function printLog(type, message)
    local color = (type == 'success' and '^2') or (type == 'warning' and '^3') or '^1'
    print(('^5[%s]%s %s^7'):format(resourceName, color, message))
end

local function CheckVersion()
	local versionUrl = githubRawBase .. resourceName .. '/version.txt'
    PerformHttpRequest(versionUrl, function(statusCode, remoteVersion, headers)
        local currentVersion = GetResourceMetadata(resourceName, 'version')

        if not remoteVersion then
			printLog('error', 'Unable to read current resource version from fxmanifest.lua!')
            return
        end

        if remoteVersion == currentVersion then
			printLog('success', ('You are running the latest version --> %s'):format(currentVersion))
        else
			printLog('error', ('OUTDATED --> %s! Please update to version --> %s'):format(currentVersion, remoteVersion))
			printLog('error', 'Download from: https://github.com/Rexshack-RedM/'..resourceName..'')
        end
    end)
end

--------------------------------------------------------------------------------------------------
-- start version check
--------------------------------------------------------------------------------------------------
CheckVersion()
