-- Made by IkeC
-- Based on "Server Players Data" by Lemos:
-- https://steamcommunity.com/sharedfiles/filedetails/?id=2695733462
require "ZKModShared"

if isServer() then
    return
end


local function ZKGetCommonPlayerData()
    -- https://zomboid-javadoc.com/41.65/zombie/characters/IsoPlayer.html
    local player = getPlayer()

    if not player then
        print("ZKModClient: ZKGetCommonPlayerData: No player data, exiting")
        return
    end

    -- https://zomboid-javadoc.com/41.65/zombie/GameTime.html
    local gametime = getGameTime()

    local username = player:getUsername()
    local forname = player:getDescriptor():getForename()
    local surname = player:getDescriptor():getSurname()

    local playerData = {}

    playerData.systemDate = ZKGetSystemDate()
    playerData.systemTime = ZKGetSystemTime()
    playerData.gametime = ZKGetGameTimeString(gametime)
    playerData.steamID = getSteamIDFromUsername(username)

    playerData.username = username
    playerData.charName = forname .. " " .. surname
    return playerData
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

    local playerData = ZKGetCommonPlayerData()

    if playerData then
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

        print("ZKModClient: " .. playerData.username .. ": command=" .. command)

        sendClientCommand(player, "ZKMod", command, playerData)
    end
end

local function SendPlayerDataAlive()
    SendPlayerData(false)
end

local function SendPlayerDataDead()
    SendPlayerData(true)
end

Events.EveryHours.Add(SendPlayerDataAlive)
Events.OnPlayerDeath.Add(SendPlayerDataDead)


-- https://pzwiki.net/wiki/Modding:Lua_Events/LevelPerk
-- IsoGameCharacter The character whose perk is being leveled up or down.
-- https://zomboid-javadoc.com/41.65/zombie/characters/skills/PerkFactory.Perk.html The perk being leveled up or down.
-- Integer Perk level.
-- Boolean Whether the perk is being leveled up.
local function ZKLevelPerk(character, perk, level, levelUp)
    print("ZKModClient.ZKLevelPerk")

    -- https://zomboid-javadoc.com/41.65/zombie/characters/IsoPlayer.html
    local player = getPlayer()
    if not player then
        print("ZKModClient: SendPlayerData: No player data, exiting")
        return
    end
    
    local eventData = ZKGetCommonPlayerData()
    if eventData then
        eventData.eventName = "LevelPerk"
        eventData.eventData1 = perk:getName()
        eventData.eventData2 = level
        eventData.eventData3 = levelUp
        eventData.eventData4 = ""
        eventData.eventData5 = ""

        sendClientCommand(player, "ZKMod", "LevelPerk", eventData)
    end
end
Events.LevelPerk.Add(ZKLevelPerk)

--https://pzwiki.net/wiki/Modding:Lua_Events/OnNewFire
--https://pzwiki.net/wiki/Modding:Lua_Events/OnZombieDead
--https://pzwiki.net/wiki/Modding:Lua_Events/OnCharacterMeet