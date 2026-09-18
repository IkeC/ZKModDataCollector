-- Made by IkeC
-- CSV saving based on "Server Players Data" by Lemos: https://steamcommunity.com/sharedfiles/filedetails/?id=2695733462

require "ZKModShared"

if not isServer() then
    return
end

ZKPrintNoTime("Mod version: v2.4 (Build 42)")

local function ZKNormalizeFilePath(filePath)
    if not filePath or filePath == "" then
        return nil
    end

    local normalizedPath = tostring(filePath):gsub("\\", "/")
    normalizedPath = normalizedPath:gsub("^/+", "")

    if normalizedPath:sub(1, 6) ~= "ZKMod/" then
        normalizedPath = "ZKMod/" .. normalizedPath
    end

    return normalizedPath
end

local function ZKGetCSVOutputPath(filePath)
    return ZKNormalizeFilePath(filePath)
end

local function ZKGetCSVFallbackPath(filePath)
    local normalizedPath = ZKNormalizeFilePath(filePath)
    if normalizedPath and normalizedPath:lower():sub(-4) == ".csv" then
        return normalizedPath .. ".txt"
    end
    return normalizedPath
end

local function ZKWriteOutputBytes(output, content)
    local text = tostring(content)
    local index = 1
    while index <= #text do
        local codePoint = string.byte(text, index)
        if codePoint >= 55296 and codePoint <= 56319 and index < #text then
            local lowSurrogate = string.byte(text, index + 1)
            if lowSurrogate >= 56320 and lowSurrogate <= 57343 then
                codePoint = 65536 + (codePoint - 55296) * 1024 + lowSurrogate - 56320
                index = index + 1
            end
        end

        if codePoint < 128 then
            output:writeByte(codePoint)
        elseif codePoint < 2048 then
            output:writeByte(192 + math.floor(codePoint / 64))
            output:writeByte(128 + codePoint % 64)
        elseif codePoint < 65536 then
            output:writeByte(224 + math.floor(codePoint / 4096))
            output:writeByte(128 + math.floor(codePoint / 64) % 64)
            output:writeByte(128 + codePoint % 64)
        else
            output:writeByte(240 + math.floor(codePoint / 262144))
            output:writeByte(128 + math.floor(codePoint / 4096) % 64)
            output:writeByte(128 + math.floor(codePoint / 64) % 64)
            output:writeByte(128 + codePoint % 64)
        end

        index = index + 1
    end
end

local function ZKReadOutputBytes(filePath)
    if type(getFileInput) ~= "function" then
        return {}, nil
    end

    local openOk, input = pcall(getFileInput, filePath)
    if not openOk then
        return nil, input
    end
    if not input then
        return {}, nil
    end

    local availableOk, available = pcall(function()
        return input:available()
    end)
    if not availableOk then
        pcall(function()
            input:close()
        end)
        return nil, available
    end

    local contents = {}
    for index = 1, available do
        local readOk, byteValue = pcall(function()
            return input:readUnsignedByte()
        end)
        if not readOk then
            pcall(function()
                input:close()
            end)
            return nil, byteValue
        end
        contents[index] = byteValue
    end

    local closeOk, closeError = pcall(function()
        input:close()
    end)
    if not closeOk then
        return nil, closeError
    end

    return contents, nil
end

local function ZKGetFileOutputSafe(filePath, append)
    local outputPaths = {ZKGetCSVOutputPath(filePath), ZKGetCSVFallbackPath(filePath)}
    for _, outputPath in ipairs(outputPaths) do
        if outputPath then
            local outputOk, output = pcall(getFileOutput, outputPath)
            if outputOk and output then
                local existingContents = {}
                if append then
                    local readError
                    existingContents, readError = ZKReadOutputBytes(outputPath)
                    if readError then
                        pcall(function()
                            output:close()
                        end)
                        output = nil
                    end
                end

                if output then
                    return {
                        handle = output,
                        existingContents = existingContents,
                        path = outputPath
                    }
                end
            end
        end
    end
    return nil
end

local function ZKWriteAndCloseFileSafe(filePath, _, append, ...)
    local dataFile = ZKGetFileOutputSafe(filePath, append)
    if not dataFile then
        return false
    end

    local contents = {...}
    local writeOk, writeError = pcall(function()
        for index = 1, #dataFile.existingContents do
            dataFile.handle:writeByte(dataFile.existingContents[index])
        end
        for index = 1, #contents do
            ZKWriteOutputBytes(dataFile.handle, contents[index])
        end
    end)
    if not writeOk then
        ZKPrint("ZKWriteAndCloseFileSafe: write failed for normalized='" .. tostring(ZKNormalizeFilePath(filePath)) .. "' error=" .. tostring(writeError))
    end

    local closeOk, closeError = pcall(function()
        dataFile.handle:close()
    end)
    if not closeOk then
        ZKPrint("ZKWriteAndCloseFileSafe: close failed for normalized='" .. tostring(ZKNormalizeFilePath(filePath)) .. "' error=" .. tostring(closeError))
    end

    return writeOk and closeOk, dataFile.path
end

local function ZKWriteOpenFileSafe(dataFile, filePath, content)
    local ok, errorMessage = pcall(function()
        ZKWriteOutputBytes(dataFile.handle, content)
    end)
    if not ok then
        ZKPrint("ZKWriteOpenFileSafe: write failed for normalized='" .. tostring(ZKNormalizeFilePath(filePath)) .. "' error=" .. tostring(errorMessage))
    end
    return ok
end

local function ZKCloseFileSafe(dataFile, filePath)
    local ok, errorMessage = pcall(function()
        dataFile.handle:close()
    end)
    if not ok then
        ZKPrint("ZKCloseFileSafe: close failed for normalized='" .. tostring(ZKNormalizeFilePath(filePath)) .. "' error=" .. tostring(errorMessage))
    end
    return ok
end

-- Parse player data and save it to a .csv file inside Lua/ZKMod/ folder
local function SavePlayerData(data, savedead)
    if data then

        -- ZKPrint("SavePlayerData: data.isAlive=" .. tostring(data.isAlive) .. " savedead=" .. tostring(savedead))

        -- overwrite client data with server date/time
        data.systemDate = ZKGetSystemDate()
        data.systemTime = ZKGetSystemTime()

        local strHeader = ZKGetCSVHeader(data)
        local strData = ZKGetCSVLine(data)

        local filePath = "/ZKMod/player_" .. data.username .. ".csv"
        local saved, outputPath = ZKWriteAndCloseFileSafe(filePath, true, false, strHeader, strData)
        if saved then
            ZKPrint("SavePlayerData: saved to " .. outputPath)
        end

        if savedead and (not data.isAlive) then
            filePath = "/ZKMod/deaths.csv"
            local _, outputPath = ZKWriteAndCloseFileSafe(filePath, true, true, strData)
            ZKPrint("SavePlayerData: " .. data.username .. " dead, saving to " .. tostring(outputPath))
        end
    end
end

-- Parse player perks data and save it to a .csv file inside Lua/ZKMod/ folder
local function SavePlayerPerksData(data)
    if data then
        -- ZKPrint("SavePlayerData: data.isAlive=" .. tostring(data.isAlive) .. " savedead=" .. tostring(savedead))

        -- overwrite client data with server date/time
        data.systemDate = ZKGetSystemDate()
        data.systemTime = ZKGetSystemTime()

        local strHeader = ZKGetCSVHeader(data)
        local strData = ZKGetCSVLine(data)

        local filePath = "/ZKMod/playerperks_" .. data.username .. ".csv"
        local saved, outputPath = ZKWriteAndCloseFileSafe(filePath, true, false, strHeader, strData)
        if saved then
            ZKPrint("SavePlayerPerksData: saved to " .. outputPath)
        end
    end
end

local function SavePlayerInventoryData(lines)
    if lines then
        --ZKPrint("SavePlayerInventoryData")

        local filePath = ""
        local dataFile
        local lineCount = 0

        -- overwrite client data with server date/time
        local localDate = ZKGetSystemDate()
        local localTime = ZKGetSystemTime()

        --ZKPrint("SavePlayerInventoryData: lines=".. ZKDump(lines))
        --ZKPrint("SavePlayerInventoryData: type=".. type(lines))

        for key, line in pairs(lines) do
            --ZKPrint("SavePlayerInventoryData: line=".. ZKDump(line))

            if filePath == "" then
                filePath = "/ZKMod/playerinventory_" .. line.username .. ".csv"
                dataFile = ZKGetFileOutputSafe(filePath, true)
                if not dataFile then
                    return
                end
            end
            
            line.systemDate = localDate
            line.systemTime = localTime
            local strData = ZKGetCSVLine(line)
            if not ZKWriteOpenFileSafe(dataFile, filePath, strData) then
                ZKCloseFileSafe(dataFile, filePath)
                return
            end

            lineCount = lineCount + 1
        end
        if dataFile and ZKCloseFileSafe(dataFile, filePath) then
            ZKPrint("SavePlayerInventoryData: saved " .. lineCount .. " line(s) to " .. dataFile.path)
        end
    end
end

-- Parse player event data and save it to event_history.csv file inside Lua/ZKMod/ folder
local function SaveEventData(data)
    if data then
        -- overwrite client data with server date/time
        data.systemDate = ZKGetSystemDate()
        data.systemTime = ZKGetSystemTime()

        ZKPrint("SaveEventData: SaveEventData=" .. ZKDump(data))
        local strData = ZKGetCSVLine(data)

        local filePath = "/ZKMod/event_history.csv"
        ZKWriteAndCloseFileSafe(filePath, true, true, strData)
    end
end

local function ZKSaveLevelPerkEvent(character, perk, level, levelUp)
    if not character then
        return
    end

    local username = character:getUsername()
    local descriptor = character:getDescriptor()
    local forename = ""
    local surname = ""
    if descriptor then
        forename = descriptor:getForename() or ""
        surname = descriptor:getSurname() or ""
    end

    local eventData = {
        systemDate = ZKGetSystemDate(),
        systemTime = ZKGetSystemTime(),
        gametime = ZKGetGameTimeString(getGameTime()),
        steamID = username and tostring(getSteamIDFromUsername(username) or "") or "",
        username = username,
        charName = (forename .. " " .. surname):gsub("^%s+", ""):gsub("%s+$", ""),
        eventName = "LevelPerk",
        eventData1 = perk and perk:getName() or "",
        eventData2 = level or 0,
        eventData3 = levelUp and true or false,
        eventData4 = "",
        eventData5 = ""
    }

    if eventData.charName == "" then
        eventData.charName = username or ""
    end

    SaveEventData(eventData)
end

-- executed when a client sends its information to the server
local ZKOnClientCommand = function(module, command, player, args)
    -- ZKPrint("ZKOnClientCommand: module=" .. module .. " command=" .. command .. " username=" .. args.username)

    if module ~= "ZKMod" then
        return;
    end

    if args and args.steamID then
        args.steamID = tostring(args.steamID)
    end

    if command == "SendPlayerDataAlive" then
        SavePlayerData(args, false)
    end
    if command == "SendPlayerDataDead" then
        SavePlayerData(args, true)
    end
    if command == "SendPlayerPerksData" then
        SavePlayerPerksData(args)
    end
    if command == "SendPlayerInventoryData" then
        SavePlayerInventoryData(args)
    end
    if command == "SendEvent" then
        SaveEventData(args)
    end
end

local ZKSaveWorldHistory = function()
    local worldData = ZKGetWorldData()

    local strData = ZKGetCSVLine(worldData)
    local filePath = "/ZKMod/world_history.csv"

    local saved, outputPath = ZKWriteAndCloseFileSafe(filePath, true, true, strData)
    if saved then
        ZKPrint("ZKSaveWorldHistory: saved to " .. outputPath)
    end
end

local ZKSaveWorld = function()
    local worldData = ZKGetWorldData()

    local strHeader = ZKGetCSVHeader(worldData)
    local strData = ZKGetCSVLine(worldData)

    local filePath = "/ZKMod/world.csv"
    local saved, outputPath = ZKWriteAndCloseFileSafe(filePath, true, false, strHeader, strData)
    if saved then
        ZKPrint("ZKSaveWorld: saved to " .. outputPath)
    end
end

local ZKSaveOnlinePlayers = function()    
    local playerData = ZKGetOnlinePlayers()

    local filePath = "/ZKMod/players_online.csv"

    local saved, outputPath = ZKWriteAndCloseFileSafe(filePath, true, false, playerData)
    if saved then
        ZKPrint("ZKSaveOnlinePlayers: saved to " .. outputPath)
    end
end

-- get game world related data
function ZKGetWorldData()
    local worldData = {}

    -- https://zomboid-javadoc.com/41.65/zombie/GameTime.html
    local gt = getGameTime()
    local world = getWorld()

    worldData.serverDate = ZKGetSystemDate()
    worldData.serverTime = ZKGetSystemTime()
    worldData.gameTime = ZKGetGameTimeString(gt)
    worldData.worldAgeDays = math.floor(world:getWorldAgeDays())
    worldData.globalTemperature = string.format("%.1f", world:getGlobalTemperature())

    local onlinePlayers = getOnlinePlayers()
    local onlinePlayersCount = 0
    if onlinePlayers then
        onlinePlayersCount = onlinePlayers:size()
    end
    worldData.onlinePlayersCount = onlinePlayersCount

    worldData.isGamePaused = isGamePaused()
    worldData.night = string.format("%.1f", gt:getNight())

    local weatherData = ZKGetWeather()
    -- joining data: https://stackoverflow.com/a/1283399 
    for k,v in pairs(weatherData) do worldData[k] = v end

    return worldData
end

function ZKGetOnlinePlayers()
    local result = ""    
    local oPlayers = getOnlinePlayers()
    if oPlayers then
        local players = oPlayers:clone()
        for i = 0, players:size() - 1 do
            result = result .. players:get(i):getUsername()
            if i < players:size() - 1 then
                result = result .. ";"
            end
        end
    end
    return result
end

local function ZKWriteEvent(username, message)
    ZKPrint("ZKWriteEvent: username=" .. username .. " message=" .. message)
    local data = {}
    local gt = getGameTime()

    data.serverDate = ZKGetSystemDate()
    data.serverTime = ZKGetSystemTime()
    data.gameTime = ZKGetGameTimeString(gt)
    data.username = username
    data.message = message

    local strData = ZKGetCSVLine(data)
    local filePath = "/ZKMod/events.csv"

    ZKWriteAndCloseFileSafe(filePath, true, true, strData)
end

-- https://pzwiki.net/wiki/Modding:Lua_Events
Events.OnClientCommand.Add(ZKOnClientCommand)

-- https://pzwiki.net/wiki/Modding:Lua_Events/LevelPerk
-- Build 42 dispatches this event on the server.
local function ZKRegisterLevelPerkEvent()
    if not SandboxVars or not SandboxVars.ZKMod then
        return
    end

    if SandboxVars.ZKMod.ServerSendEventLevelPerk == 1 then
        Events.LevelPerk.Add(ZKSaveLevelPerkEvent)
    end
end

ZKRegisterLevelPerkEvent()

-- Based on weather function by Snake: http://pzmodding.blogspot.com/
function ZKGetWeather()
    local gt = GameTime:getInstance()
    local c = getClimateManager()

	local clouds = c:getCloudIntensity()
	local fog = c:getFogIntensity()
	local windpower = c:getWindPower()
	local windspeed = c:getWindspeedKph()
	local precipitationIntensity = c:getPrecipitationIntensity()

    local weatherData = {}
    weatherData.cloudIntensity = 0
    weatherData.fogIntensity = 0
    weatherData.precipitationIntensity = 0

    weatherData.windpower = 0
    weatherData.windspeed = 0

    weatherData.rain = false
    weatherData.snow = false

    weatherData.thunderstorm = false
    weatherData.tropicalstorm = false
    weatherData.blizzard = false
    
    -- wind
    if windpower > 0 then 
        weatherData.windpower = string.format("%.1f", windpower)
    end 
    if windspeed > 0 then
        weatherData.windspeed = string.format("%.1f", windspeed)        
    end

    if RainManager.isRaining() or (c:getPrecipitationIntensity() and c:getPrecipitationIntensity() > 0) then
        -- precipitation (snow, rain, storm...)
        weatherData.precipitationIntensity = string.format("%.1f", precipitationIntensity)

		if c:getPrecipitationIsSnow() then
            weatherData.snow = true
        else 
			if c:getWeatherPeriod():isRunning() then
				local wp = c:getWeatherPeriod()
				if wp:isThunderStorm() then
                    weatherData.thunderstorm = true
				elseif wp:isTropicalStorm() then
                    weatherData.tropicalstorm = true
				elseif wp:isBlizzard() then
                    weatherData.blizzard = true
				end
			end
            if weatherData.thunderstorm == false and weatherData.tropicalstorm == false and weatherData.blizzard == false then
             -- plain rain
             weatherData.rain = true
            end 
		end
	elseif (not RainManager.isRaining()) then
		-- cloudy without rain
        if clouds > 0 then
            weatherData.cloudIntensity = string.format("%.1f", clouds)
        end
        if fog > 0 then
            weatherData.fogIntensity = string.format("%.1f", fog)
        end

        if c:getPrecipitationIntensity() and c:getPrecipitationIntensity() > 0 and c:getPrecipitationIsSnow() then 
            --snow
            weatherData.snow = true
        end
	end

    return weatherData
end

local ZKSaveSafehouses = function()    
    
    -- https://zomboid-javadoc.com/41.65/zombie/iso/areas/SafeHouse.html
    local safehouses = SafeHouse:getSafehouseList() 
    local strHeader = ""
    local strData = ""
    local safehouseCount = 0

    if safehouses then
        safehouseCount = safehouses:size()
        for i = 0, safehouses:size() - 1 do
            
            local data = {}

            local safehouse = safehouses:get(i)

            -- data.id = safehouse:getId() -- "10744,9536 at 1644311215375"
            data.title = safehouse:getTitle() or ""
            data.owner = safehouse:getOwner() or ""
            data.x = safehouse:getX()
            data.x2 = safehouse:getX2()
            data.y = safehouse:getY()
            data.y2 = safehouse:getY2()
            data.w = safehouse:getW()
            data.h = safehouse:getH()
            data.lastVisited = safehouse:getLastVisited()
            
            local players = "Players(" .. data.owner
            local playersList = safehouse:getPlayers()

            -- ZKPrint("ZKSaveSafehouses: playersList:size()=" .. playersList:size())

            if playersList then
                for j = 0, playersList:size() - 1 do
                    local player = playersList:get(j)
                    -- ZKPrint("ZKSaveSafehouses: j=" .. j .. " player=" .. player)
                    if player ~= safehouse:getOwner() then                        
                        players = players .. ", " .. player
                    end
                end
            end
            players = players .. ")"
            data.players = players

            if i == 0 then
                strHeader = ZKGetCSVHeader(data)
            end
            strData = strData .. ZKGetCSVLine(data)
        end
    end

    local filePath = "/ZKMod/safehouses.csv"
    
    local saved, outputPath = ZKWriteAndCloseFileSafe(filePath, true, false, strHeader, strData)
    if saved then
        ZKPrint("ZKSaveSafehouses: " .. safehouseCount .. " safehouse(s) saved to " .. outputPath)
    end
end

local ZKSaveFactions = function()    
    
    -- https://zomboid-javadoc.com/41.65/zombie/characters/Faction.html
    local factions = Faction:getFactions()

    local strHeader = ""
    local strData = ""
    local factionCount = 0
    
    if factions then
        factionCount = factions:size()
        local data = {}
        for i = 0, factions:size() - 1 do
            local faction = factions:get(i)

            data.name = faction:getName() or ""

            data.owner = faction:getOwner() or ""
            data.tagName = ""
            if faction:getTag() then
                data.tagName = faction:getTag()
            end
            data.tagColorR = ""
            data.tagColorG = ""
            data.tagColorB = ""

            if faction:getTagColor() then
                local color = faction:getTagColor():toColor()
                data.tagColorR = color:getRed()
                data.tagColorG = color:getGreen()
                data.tagColorB = color:getBlue()
            end

            local players = "Players(" .. data.owner            
            local playersList = faction:getPlayers()

            -- ZKPrint("ZKSaveFactions: playersList:size()=" .. playersList:size())

            if playersList then
                for j = 0, playersList:size() - 1 do
                    local player = playersList:get(j)
                    -- ZKPrint("ZKSaveFactions: j=" .. j .. " player=" .. player)
                    if player ~= faction:getOwner() then
                        players = players .. ", " .. player
                    end
                end
            end
            players = players .. ")"
            data.players = players

            if i == 0 then
                strHeader = ZKGetCSVHeader(data)
            end
            strData = strData .. ZKGetCSVLine(data)
        end
    end

    local filePath = "/ZKMod/factions.csv"
    
    local saved, outputPath = ZKWriteAndCloseFileSafe(filePath, true, false, strHeader, strData)
    if saved then
        ZKPrint("ZKSaveFactions: " .. factionCount .. " faction(s) saved to " .. outputPath)
    end
end

local serverTimersRegistered = false

local function ZKInitServerTimers()
    if serverTimersRegistered then
        return
    end

    if not SandboxVars or not SandboxVars.ZKMod then
        ZKPrint("ZKInitServerTimers: SandboxVars.ZKMod not ready, waiting for next event tick")
        return
    end

    serverTimersRegistered = true
    local serverSandbox = SandboxVars.ZKMod

    ZKPrint("ZKInitServerTimers: SandboxVars.ZKMod.ServerSaveWorldEvery=" .. tostring(serverSandbox.ServerSaveWorldEvery))
    -- 0: Off, 1: EveryTenMinutes, 2: EveryHours, 3: EveryDays
    -- Default: 1

    if serverSandbox.ServerSaveWorldEvery == 1 then
        Events.EveryTenMinutes.Add(ZKSaveWorld)    
    elseif serverSandbox.ServerSaveWorldEvery == 2 then
        Events.EveryHours.Add(ZKSaveWorld)
    elseif serverSandbox.ServerSaveWorldEvery == 3 then
        Events.EveryDays.Add(ZKSaveWorld)
    end

    ZKPrint("ZKInitServerTimers: SandboxVars.ZKMod.ServerSaveWorldHistoryEvery=" .. tostring(serverSandbox.ServerSaveWorldHistoryEvery))
    -- 0: Off, 1: EveryTenMinutes, 2: EveryHours, 3: EveryDays
    -- Default: 2

    if serverSandbox.ServerSaveWorldHistoryEvery == 1 then
        Events.EveryTenMinutes.Add(ZKSaveWorldHistory)    
    elseif serverSandbox.ServerSaveWorldHistoryEvery == 2 then
        Events.EveryHours.Add(ZKSaveWorldHistory)
    elseif serverSandbox.ServerSaveWorldHistoryEvery == 3 then
        Events.EveryDays.Add(ZKSaveWorldHistory)
    end

    ZKPrint("ZKInitServerTimers: SandboxVars.ZKMod.ServerSaveOnlinePlayersEvery=" .. tostring(serverSandbox.ServerSaveOnlinePlayersEvery))
    -- 0: Off, 1: EveryTenMinutes, 2: EveryHours, 3: EveryDays
    -- Default: 1

    if serverSandbox.ServerSaveOnlinePlayersEvery == 1 then
        Events.EveryTenMinutes.Add(ZKSaveOnlinePlayers)    
    elseif serverSandbox.ServerSaveOnlinePlayersEvery == 2 then
        Events.EveryHours.Add(ZKSaveOnlinePlayers)
    elseif serverSandbox.ServerSaveOnlinePlayersEvery == 3 then
        Events.EveryDays.Add(ZKSaveOnlinePlayers)
    end
    if (serverSandbox.ServerSaveOnlinePlayersEvery or 0) > 0 then
        Events.OnSave.Add(ZKSaveOnlinePlayers)
    end

    ZKPrint("ZKInitServerTimers: SandboxVars.ZKMod.ServerSaveSafehousesEvery=" .. tostring(serverSandbox.ServerSaveSafehousesEvery))
    -- 0: Off, 1: EveryTenMinutes, 2: EveryHours, 3: EveryDays
    -- Default: 2

    if serverSandbox.ServerSaveSafehousesEvery == 1 then
        Events.EveryTenMinutes.Add(ZKSaveSafehouses)    
    elseif serverSandbox.ServerSaveSafehousesEvery == 2 then
        Events.EveryHours.Add(ZKSaveSafehouses)
    elseif serverSandbox.ServerSaveSafehousesEvery == 3 then
        Events.EveryDays.Add(ZKSaveSafehouses)
    end

    ZKPrint("ZKInitServerTimers: SandboxVars.ZKMod.ServerSaveFactionsEvery=" .. tostring(serverSandbox.ServerSaveFactionsEvery))
    -- 0: Off, 1: EveryTenMinutes, 2: EveryHours, 3: EveryDays
    -- Default: 2

    if serverSandbox.ServerSaveFactionsEvery == 1 then
        Events.EveryTenMinutes.Add(ZKSaveFactions)    
    elseif serverSandbox.ServerSaveFactionsEvery == 2 then
        Events.EveryHours.Add(ZKSaveFactions)
    elseif serverSandbox.ServerSaveFactionsEvery == 3 then
        Events.EveryDays.Add(ZKSaveFactions)
    end
end

Events.OnInitWorld.Add(ZKInitServerTimers)
if Events.OnServerStarted then
    Events.OnServerStarted.Add(ZKInitServerTimers)
end

-- https://pzwiki.net/wiki/Modding:Lua_Events/OnRainStart
-- function ZKOnRainStart()
--     ZKPrint("ZKOnRainStart")
-- end
-- Events.OnRainStart.Add(--ZKOnRainStart)

-- https://pzwiki.net/wiki/Modding:Lua_Events/OnRainStop
-- function ZKOnRainStop()
--     ZKPrint("ZKOnRainStop")
-- end
-- Events.OnRainStop.Add(ZKOnRainStop)

-- https://pzwiki.net/wiki/Modding:Lua_Events/OnDawn
-- function ZKOnDawn()
--     ZKPrint("ZKOnDawn")
-- end
-- Events.OnDawn.Add(ZKOnDawn)

-- https://pzwiki.net/wiki/Modding:Lua_Events/OnDusk
-- function ZKOnDusk()
--     ZKPrint("ZKOnDusk")
-- end
-- Events.OnDusk.Add(ZKOnDusk)

-- https://pzwiki.net/wiki/Modding:Lua_Events/OnChangeWeather
-- String A string representing the weather. Can be either: "normal", "cloud", "rain", or "sunny"
-- function ZKOnChangeWeather(weather)
--     ZKPrint("ZKOnChangeWeather")
-- end
-- Events.OnChangeWeather.Add(ZKOnChangeWeather)

-- function ZKOnWeatherPeriodStart(weatherPeriod)
--     ZKPrint("ZKOnWeatherPeriodStart")
-- end
-- Events.OnWeatherPeriodStart.Add(ZKOnWeatherPeriodStart)

-- works! (called twice?)
-- function ZKOnWeatherPeriodStop(weatherPeriod)
--     ZKPrint("ZKOnWeatherPeriodStop")
-- end
-- Events.OnWeatherPeriodStop.Add(ZKOnWeatherPeriodStop)

-- function ZKOnWeatherPeriodComplete(weatherPeriod)
--     ZKPrint("ZKOnWeatherPeriodComplete")
-- end
-- Events.OnWeatherPeriodComplete.Add(ZKOnWeatherPeriodComplete)

-- works on server
-- https://zomboid-javadoc.com/41.65/zombie/iso/weather/WeatherPeriod.html
-- function ZKOnWeatherPeriodStage(weatherPeriod)
--     ZKPrint("ZKOnWeatherPeriodStage")
-- end
-- Events.OnWeatherPeriodStage.Add(ZKOnWeatherPeriodStage)

-- Events.OnRainStart.Add(ZKOnRainStart)
-- Events.OnRainStop.Add(ZKOnRainStop)