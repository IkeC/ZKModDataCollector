-- Made by IkeC
-- Based on "Server Players Data" by Lemos:
-- https://steamcommunity.com/sharedfiles/filedetails/?id=2695733462
require "ZKModShared"

if isServer() then
    return
end

-- Called on the player to parse its player data and send it to the server every ten (in-game) minutes
local function SendPlayerData(isdead)

    print("ZKModClient: SendPlayerData: isdead=" .. tostring(isdead))

    -- https://zomboid-javadoc.com/41.65/zombie/characters/IsoPlayer.html
    local player = getPlayer()

    if not player then
        print("ZKModClient: SendPlayerData: No player data, exiting")
        return        
    end

    -- https://zomboid-javadoc.com/41.65/zombie/GameTime.html
    local gametime = getGameTime()

    local username = player:getUsername()
    print("ZKModClient: " .. username .. ": collecting data")

    local forname = player:getDescriptor():getForename()
    local surname = player:getDescriptor():getSurname()

    local playerData = {}

    playerData.systemDate = ZKGetSystemDate()
    playerData.systemTime = ZKGetSystemTime()
    playerData.gametime = ZKGetGameTimeString(gametime)
    playerData.steamID = getSteamIDFromUsername(username)

    playerData.username = username
    playerData.charName = forname .. " " .. surname

    playerData.x = string.format("%.1f", player:getX())
    playerData.y = string.format("%.1f", player:getY())
    playerData.z = string.format("%.1f", player:getZ())

    playerData.isAlive = player:isAlive()
    playerData.zombieKills = player:getZombieKills()
    playerData.hoursSurvived = string.format("%.1f", player:getHoursSurvived())
    playerData.timeSurvived = player:getTimeSurvived()

    -- https://zomboid-javadoc.com/41.65/zombie/characters/BodyDamage/Nutrition.html
    local nutrition = player:getNutrition()
    playerData.weight = string.format("%.1f", nutrition:getWeight())
    playerData.characterHaveWeightTrouble = nutrition:characterHaveWeightTrouble()

    -- https://zomboid-javadoc.com/41.65/zombie/characters/SurvivorDesc.html
    local descriptor = player:getDescriptor()
    playerData.profession = descriptor:getProfession()

    -- https://zomboid-javadoc.com/41.65/zombie/characters/traits/TraitCollection.html
    local traits = player:getTraits()
    playerData.traits = traits:toString()

    playerData.isFemale = player:isFemale()

    local command = "SendPlayerDataAlive"
    if isdead then
        command = "SendPlayerDataDead"
    end

    print("ZKModClient: " .. username .. ": command=" .. command)

    sendClientCommand(player, "ZKMod", command, playerData)
end

local function SendPlayerDataAlive()
    SendPlayerData(false)
end

local function SendPlayerDataDead()
    SendPlayerData(true)
end

Events.EveryHours.Add(SendPlayerDataAlive)
Events.OnPlayerDeath.Add(SendPlayerDataDead)