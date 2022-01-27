-- Made by IkeC
-- Based on "Server Players Data" by Lemos:
-- https://steamcommunity.com/sharedfiles/filedetails/?id=2695733462
require "ZKModShared"

print("ZKModServer: isServer=" .. tostring(isServer()))

if not isServer() then
    return
end

-- Parse player data and save it to a .csv file inside Lua/ServerPlayersData/ folder
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

end

-- executed on server every in-game-hour
local EveryHour = function(module, command, player, args)
    print("ZKModServer.EveryHour")

    local worldData = ZKGetWorldData()

    print("ZKModServer.EveryHour: worldData: " .. ZKDump(worldData))

    local strData = ZKGetCSVLine(worldData)

    local filePath = "/ZKMod/world_history.csv"

    local dataFile = getFileWriter(filePath, true, true)
    dataFile:write(strData)
    dataFile:close()

    print("ZKModServer.EveryHour: saved to " .. filePath)
end

-- executed on server every 10 in-game-minutes
local EveryTenMinutes = function(module, command, player, args)
    print("ZKModServer.EveryTenMinutes")

    local worldData = ZKGetWorldData()

    print("ZKModServer.EveryTenMinutes: worldData: " .. ZKDump(worldData))

    local strHeader = ZKGetCSVHeader(worldData)
    local strData = ZKGetCSVLine(worldData)

    local filePath = "/ZKMod/world.csv"
    local dataFile = getFileWriter(filePath, true, false)

    dataFile:write(strHeader)
    dataFile:write(strData)
    dataFile:close()

    print("ZKModServer.EveryTenMinutes: saved to " .. filePath)
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

    -- worldData.weather = world:getWeather() always "sunny"

    worldData.isGamePaused = isGamePaused()

    -- https://zomboid-javadoc.com/41.65/zombie/iso/weather/ClimateManager.html
    local climateManager = getClimateManager()

    -- https://zomboid-javadoc.com/41.65/zombie/iso/weather/ClimateManager.DayInfo.html
    local dayInfo = climateManager:getCurrentDay()

    -- https://zomboid-javadoc.com/41.65/zombie/erosion/season/ErosionSeason.html
    local season = dayInfo:getSeason()

    worldData.isRainingToday = "R=" .. tostring(gt:isRainingToday())
    worldData.dayWeatherRainDay = "R=" .. tostring(season:isRainDay())

    worldData.isThunderDay = "T=" .. tostring(gt:isThunderDay())
    worldData.dayWeatherThunderDay = "T=" .. tostring(season:isThunderDay())

    worldData.dayWeatherSunnyDay = "S=" .. tostring(season:isSunnyDay())
    worldData.thunderstorm = "TS=" .. tostring(gt:getThunderStorm())

    -- https://zomboid-javadoc.com/41.65/zombie/iso/weather/ClimateMoon.html
    local climateMoon = getClimateMoon()
    local currentMoonPhase = climateMoon:getCurrentMoonPhase()
    worldData.currentMoonPhase = currentMoonPhase

    -- https://zomboid-javadoc.com/41.65/zombie/erosion/ErosionMain.html
    -- local erosionMain = getErosion()
    -- local seasonMain = erosionMain:getSeasons() 

    return worldData
end

-- https://pzwiki.net/wiki/Modding:Lua_Events/OnRainStart
local function ZKOnRainStart()
    print("ZKModServer.ZKOnRainStart")
    ZKWriteEvent("global", "Es beginnt zu regnen.")
end

-- https://pzwiki.net/wiki/Modding:Lua_Events/OnRainStop
local function ZKOnRainStop()
    print("ZKModServer.ZKOnRainStop")
    ZKWriteEvent("global", "Der Regen hat aufgehört.")
end

-- https://pzwiki.net/wiki/Modding:Lua_Events/OnDawn
local function ZKOnDawn()
    print("ZKModServer.ZKOnDawn")
    ZKWriteEvent("global", "Die Sonne geht auf.")
end

-- https://pzwiki.net/wiki/Modding:Lua_Events/OnDusk
local function ZKOnDusk()
    print("ZKModServer.ZKOnDusk")
    ZKWriteEvent("global", "Die Sonne geht unter.")
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

-- https://pzwiki.net/wiki/Modding:Lua_Events/LevelPerk
-- IsoGameCharacter The character whose perk is being leveled up or down.
-- https://zomboid-javadoc.com/41.65/zombie/characters/skills/PerkFactory.Perk.html The perk being leveled up or down.
-- Integer Perk level.
-- Boolean Whether the perk is being leveled up.
local function ZKLevelPerk(character, perk, level, levelUp)
    print("ZKModServer.ZKLevelPerk")

    local username = character.isoPlayer:getUsername()
    local perkname = perk:getName()
    local message = username .. " leveled perk " .. perkname .. " to " .. tostring(level)

    print("ZKModServer.ZKLevelPerk: message=" .. message)
    ZKWriteEvent(username, message)
end

-- https://pzwiki.net/wiki/Modding:Lua_Events/OnChangeWeather
-- String A string representing the weather. Can be either: "normal", "cloud", "rain", or "sunny"
local function ZKOnChangeWeather(weather)
    print("ZKModServer.ZKOnChangeWeather")
    print("ZKModServer.ZKOnChangeWeather: weather=" .. weather)
end

-- https://pzwiki.net/wiki/Modding:Lua_Events
Events.OnClientCommand.Add(PlayerDataReceived)

Events.EveryHours.Add(EveryHour)
Events.EveryTenMinutes.Add(EveryTenMinutes)

Events.OnDawn.Add(ZKOnDawn)
Events.OnDusk.Add(ZKOnDusk)

Events.OnChangeWeather.Add(ZKOnChangeWeather)
Events.LevelPerk.Add(ZKLevelPerk)

Events.OnRainStart.Add(ZKOnRainStart)
Events.OnRainStop.Add(ZKOnRainStop)

