-- Made by IkeC
-- CSV saving based on "Server Players Data" by Lemos: https://steamcommunity.com/sharedfiles/filedetails/?id=2695733462

require "ZKModShared"

if not isServer() then
    return
end

ZKPrint("Mod version: v1.3.1")

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
        local dataFile = getFileWriter(filePath, true, false)
        dataFile:write(strHeader)
        dataFile:write(strData)
        dataFile:close()

        ZKPrint("SavePlayerData: saved to " .. filePath)

        if savedead and (not data.isAlive) then
            filePath = "/ZKMod/deaths.csv"
            ZKPrint("SavePlayerData: " .. data.username .. " dead, saving to " .. filePath)
            dataFile = getFileWriter(filePath, true, true)
            dataFile:write(strData)
            dataFile:close()
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
        local dataFile = getFileWriter(filePath, true, false)
        dataFile:write(strHeader)
        dataFile:write(strData)
        dataFile:close()

        ZKPrint("SavePlayerPerksData: saved to " .. filePath)
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
        local dataFile = getFileWriter(filePath, true, true)

        dataFile:write(strData)
        dataFile:close()
    end
end

-- executed when a client sends its information to the server
local ZKOnClientCommand = function(module, command, player, args)
    -- ZKPrint("ZKOnClientCommand: module=" .. module .. " command=" .. command .. " username=" .. args.username)

    if module ~= "ZKMod" then
        return;
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
    if command == "SendEvent" then
        SaveEventData(args)
    end
end

local ZKSaveWorldHistory = function()
    local worldData = ZKGetWorldData()

    local strData = ZKGetCSVLine(worldData)
    local filePath = "/ZKMod/world_history.csv"

    local dataFile = getFileWriter(filePath, true, true)
    dataFile:write(strData)
    dataFile:close()

    ZKPrint("ZKSaveWorldHistory: saved to " .. filePath)
end

local ZKSaveWorld = function()
    local worldData = ZKGetWorldData()

    local strHeader = ZKGetCSVHeader(worldData)
    local strData = ZKGetCSVLine(worldData)

    local filePath = "/ZKMod/world.csv"
    local dataFile = getFileWriter(filePath, true, false)

    dataFile:write(strHeader)
    dataFile:write(strData)
    dataFile:close()

    ZKPrint("ZKSaveWorld: saved to " .. filePath)
end

local ZKSaveOnlinePlayers = function()    
    local playerData = ZKGetOnlinePlayers()

    filePath = "/ZKMod/players_online.csv"

    local dataFile = getFileWriter(filePath, true, false)
    dataFile:write(playerData)
    dataFile:close()
    ZKPrint("ZKSaveOnlinePlayers: saved to " .. filePath)
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

    local dataFile = getFileWriter(filePath, true, true)
    dataFile:write(strData)
    dataFile:close()
end

-- https://pzwiki.net/wiki/Modding:Lua_Events
Events.OnClientCommand.Add(ZKOnClientCommand)

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

    if safehouses then
        for i = 0, safehouses:size() - 1 do
            
            local data = {}

            local safehouse = safehouses:get(i)

            -- data.id = safehouse:getId() -- "10744,9536 at 1644311215375"
            data.title = safehouse:getTitle()
            data.owner = safehouse:getOwner()
            data.x = safehouse:getX()
            data.x2 = safehouse:getX2()
            data.y = safehouse:getY()
            data.y2 = safehouse:getY2()
            data.w = safehouse:getW()
            data.h = safehouse:getH()
            data.lastVisited = safehouse:getLastVisited()
            
            local players = "Players(" .. safehouse:getOwner()
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

    filePath = "/ZKMod/safehouses.csv"
    
    local dataFile = getFileWriter(filePath, true, false)
    dataFile:write(strHeader)
    dataFile:write(strData)
    dataFile:close()

    ZKPrint("ZKSaveSafehouses: " .. safehouses:size() .. " safehouse(s) saved to " .. filePath)
end

local ZKSaveFactions = function()    
    
    -- https://zomboid-javadoc.com/41.65/zombie/characters/Faction.html
    local factions = Faction:getFactions()

    local strHeader = ""
    local strData = ""
    
    if factions then
        local data = {}
        for i = 0, factions:size() - 1 do
            local faction = factions:get(i)

            data.name = faction:getName()

            data.owner = faction:getOwner()
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

            local players = "Players(" .. faction:getOwner()            
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

    filePath = "/ZKMod/factions.csv"
    
    local dataFile = getFileWriter(filePath, true, false)
    dataFile:write(strHeader)
    dataFile:write(strData)
    dataFile:close()

    ZKPrint("ZKSaveFactions: " .. factions:size() .. " faction(s) saved to " .. filePath)
end

function ZKOnInitWorld()
    ZKPrint("OnInitWorld: SandboxVars.ZKMod.ServerSaveWorldEvery=" .. SandboxVars.ZKMod.ServerSaveWorldEvery)
    -- 0: Off, 1: EveryTenMinutes, 2: EveryHours, 3: EveryDays
    -- Default: 1

    if SandboxVars.ZKMod.ServerSaveWorldEvery == 1 then
        Events.EveryTenMinutes.Add(ZKSaveWorld)    
    elseif SandboxVars.ZKMod.ServerSaveWorldEvery == 2 then
        Events.EveryHours.Add(ZKSaveWorld)
    elseif SandboxVars.ZKMod.ServerSaveWorldEvery == 3 then
        Events.EveryDays.Add(ZKSaveWorld)
    end

    ZKPrint("OnInitWorld: SandboxVars.ZKMod.ServerSaveWorldHistoryEvery=" .. SandboxVars.ZKMod.ServerSaveWorldHistoryEvery)
    -- 0: Off, 1: EveryTenMinutes, 2: EveryHours, 3: EveryDays
    -- Default: 2

    if SandboxVars.ZKMod.ServerSaveWorldHistoryEvery == 1 then
        Events.EveryTenMinutes.Add(ZKSaveWorldHistory)    
    elseif SandboxVars.ZKMod.ServerSaveWorldHistoryEvery == 2 then
        Events.EveryHours.Add(ZKSaveWorldHistory)
    elseif SandboxVars.ZKMod.ServerSaveWorldHistoryEvery == 3 then
        Events.EveryDays.Add(ZKSaveWorldHistory)
    end

    ZKPrint("OnInitWorld: SandboxVars.ZKMod.ServerSaveOnlinePlayersEvery=" .. SandboxVars.ZKMod.ServerSaveOnlinePlayersEvery)
    -- 0: Off, 1: EveryTenMinutes, 2: EveryHours, 3: EveryDays
    -- Default: 1

    if SandboxVars.ZKMod.ServerSaveOnlinePlayersEvery == 1 then
        Events.EveryTenMinutes.Add(ZKSaveOnlinePlayers)    
    elseif SandboxVars.ZKMod.ServerSaveOnlinePlayersEvery == 2 then
        Events.EveryHours.Add(ZKSaveOnlinePlayers)
    elseif SandboxVars.ZKMod.ServerSaveOnlinePlayersEvery == 3 then
        Events.EveryDays.Add(ZKSaveOnlinePlayers)
    end
    if SandboxVars.ZKMod.ServerSaveOnlinePlayersEvery > 0 then
        Events.OnSave.Add(ZKSaveOnlinePlayers)
    end

    ZKPrint("OnInitWorld: SandboxVars.ZKMod.ServerSaveSafehousesEvery=" .. SandboxVars.ZKMod.ServerSaveSafehousesEvery)
    -- 0: Off, 1: EveryTenMinutes, 2: EveryHours, 3: EveryDays
    -- Default: 2

    if SandboxVars.ZKMod.ServerSaveSafehousesEvery == 1 then
        Events.EveryTenMinutes.Add(ZKSaveSafehouses)    
    elseif SandboxVars.ZKMod.ServerSaveSafehousesEvery == 2 then
        Events.EveryHours.Add(ZKSaveSafehouses)
    elseif SandboxVars.ZKMod.ServerSaveSafehousesEvery == 3 then
        Events.EveryDays.Add(ZKSaveSafehouses)
    end

    ZKPrint("OnInitWorld: SandboxVars.ZKMod.ServerSaveFactionsEvery=" .. SandboxVars.ZKMod.ServerSaveFactionsEvery)
    -- 0: Off, 1: EveryTenMinutes, 2: EveryHours, 3: EveryDays
    -- Default: 2

    if SandboxVars.ZKMod.ServerSaveFactionsEvery == 1 then
        Events.EveryTenMinutes.Add(ZKSaveFactions)    
    elseif SandboxVars.ZKMod.ServerSaveFactionsEvery == 2 then
        Events.EveryHours.Add(ZKSaveFactions)
    elseif SandboxVars.ZKMod.ServerSaveFactionsEvery == 3 then
        Events.EveryDays.Add(ZKSaveFactions)
    end

end
Events.OnInitWorld.Add(ZKOnInitWorld)

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