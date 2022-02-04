-- Made by IkeC
-- CSV saving based on "Server Players Data" by Lemos: https://steamcommunity.com/sharedfiles/filedetails/?id=2695733462

require "ZKModShared"

print("ZKModServer: isServer=" .. tostring(isServer()))

if not isServer() then
    return
end

-- Parse player data and save it to a .csv file inside Lua/ZKMod/ folder
local function SavePlayerData(data, savedead)
    if data then

        print("ZKModServer: data.isAlive=" .. tostring(data.isAlive) .. " savedead=" .. tostring(savedead))

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

        print("ZKModServer: SavePlayerData: " .. data.username .. " data saved to file")

        if savedead and (not data.isAlive) then
            print("ZKModServer: SavePlayerData: " .. data.username .. " dead, saving death")
            filePath = "/ZKMod/deaths.csv"
            dataFile = getFileWriter(filePath, true, true)
            dataFile:write(strData)
            dataFile:close()
        end
    end
end

-- Parse player event data and save it to event_history.csv file inside Lua/ZKMod/ folder
local function SaveEventData(data)
    if data then
        -- overwrite client data with server date/time
        data.systemDate = ZKGetSystemDate()
        data.systemTime = ZKGetSystemTime()

        print("ZKModServer: SaveEventData=" .. ZKDump(data))
        local strData = ZKGetCSVLine(data)

        local filePath = "/ZKMod/event_history.csv"
        local dataFile = getFileWriter(filePath, true, true)

        dataFile:write(strData)
        dataFile:close()
    end
end

-- executed when a client(player) sends its information to the server
local PlayerDataReceived = function(module, command, player, args)
    if module ~= "ZKMod" then
        return;
    end

    if command == "SendPlayerDataAlive" then
        print("ZKModServer: " .. command .. " for " .. args.username .. " received")
        SavePlayerData(args, false)
    end

    if command == "SendPlayerDataDead" then
        print("ZKModServer: " .. command .. " for " .. args.username .. " received")
        SavePlayerData(args, true)
    end

    if command == "LevelPerk" then
        print("ZKModServer: " .. command .. " for " .. args.username .. " received")
        SaveEventData(args)
    end
end

-- executed on server every in-game-hour
local ZKEveryHour = function(module, command, player, args)
    -- print("ZKModServer.ZKEveryHour")

    local worldData = ZKGetWorldData()

    -- print("ZKModServer.ZKEveryHour: worldData: " .. ZKDump(worldData))

    local strData = ZKGetCSVLine(worldData)
    print("ZKModServer.ZKEveryHour: strData: " .. strData)

    local filePath = "/ZKMod/world_history.csv"

    local dataFile = getFileWriter(filePath, true, true)
    dataFile:write(strData)
    dataFile:close()

    print("ZKModServer.ZKEveryHour: saved to " .. filePath)
end

-- executed on server every 10 in-game-minutes
local ZKEveryTenMinutes = function(module, command, player, args)
    -- print("ZKModServer.ZKEveryTenMinutes")

    local worldData = ZKGetWorldData()

    -- print("ZKModServer.ZKEveryTenMinutes: worldData: " .. ZKDump(worldData))

    local strHeader = ZKGetCSVHeader(worldData)
    local strData = ZKGetCSVLine(worldData)

    local filePath = "/ZKMod/world.csv"
    local dataFile = getFileWriter(filePath, true, false)

    dataFile:write(strHeader)
    dataFile:write(strData)
    dataFile:close()

    print("ZKModServer.ZKEveryTenMinutes: saved to " .. filePath)

    
    local playerData = ZKGetOnlinePlayers()

    -- print("ZKModServer.ZKEveryHour: worldData: " .. ZKDump(worldData))

    filePath = "/ZKMod/players_online.csv"

    local dataFile = getFileWriter(filePath, true, false)
    dataFile:write(playerData)
    dataFile:close()

    print("ZKModServer.ZKEveryTenMinutes: saved to " .. filePath)
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
    print("ZKModServer.ZKWriteEvent: username=" .. username .. " message=" .. message)
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
Events.OnClientCommand.Add(PlayerDataReceived)

Events.EveryHours.Add(ZKEveryHour)
Events.EveryTenMinutes.Add(ZKEveryTenMinutes)


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


-- https://pzwiki.net/wiki/Modding:Lua_Events/OnRainStart
function ZKOnRainStart()
    print("ZKModServer.ZKOnRainStart")
    -- ZKWriteEvent("global", "Es beginnt zu regnen.")
end
Events.OnRainStart.Add(ZKOnRainStart)

-- https://pzwiki.net/wiki/Modding:Lua_Events/OnRainStop
function ZKOnRainStop()
    print("ZKModServer.ZKOnRainStop")
    -- ZKWriteEvent("global", "Der Regen hat aufgehört.")
end
Events.OnRainStop.Add(ZKOnRainStop)

-- https://pzwiki.net/wiki/Modding:Lua_Events/OnDawn
function ZKOnDawn()
    print("ZKModServer.ZKOnDawn")
    -- ZKWriteEvent("global", "Die Sonne geht auf.")
end
Events.OnDawn.Add(ZKOnDawn)

-- https://pzwiki.net/wiki/Modding:Lua_Events/OnDusk
function ZKOnDusk()
    print("ZKModServer.ZKOnDusk")
    -- ZKWriteEvent("global", "Die Sonne geht unter.")
end
Events.OnDusk.Add(ZKOnDusk)

-- https://pzwiki.net/wiki/Modding:Lua_Events/OnChangeWeather
-- String A string representing the weather. Can be either: "normal", "cloud", "rain", or "sunny"
function ZKOnChangeWeather(weather)
    print("ZKModServer.ZKOnChangeWeather")
    -- print("ZKModServer.ZKOnChangeWeather: weather=" .. weather)
end
Events.OnChangeWeather.Add(ZKOnChangeWeather)

function ZKOnWeatherPeriodStart(weatherPeriod)
    print("ZKModServer.ZKOnWeatherPeriodStart")
    --print(weatherPeriod)
end
Events.OnWeatherPeriodStart.Add(ZKOnWeatherPeriodStart)

-- works! (called twice?)
function ZKOnWeatherPeriodStop(weatherPeriod)
    print("ZKModServer.ZKOnWeatherPeriodStop")
    --print(weatherPeriod)
end
Events.OnWeatherPeriodStop.Add(ZKOnWeatherPeriodStop)

function ZKOnWeatherPeriodComplete(weatherPeriod)
    print("ZKModServer.ZKOnWeatherPeriodComplete")
    --print(weatherPeriod)
end
Events.OnWeatherPeriodComplete.Add(ZKOnWeatherPeriodComplete)

-- works!
function ZKOnWeatherPeriodStage(weatherPeriod)
    -- https://zomboid-javadoc.com/41.65/zombie/iso/weather/WeatherPeriod.html
    print("ZKModServer.ZKOnWeatherPeriodStage")
    print(weatherPeriod)
end
Events.OnWeatherPeriodStage.Add(ZKOnWeatherPeriodStage)

Events.OnRainStart.Add(ZKOnRainStart)
Events.OnRainStop.Add(ZKOnRainStop)

