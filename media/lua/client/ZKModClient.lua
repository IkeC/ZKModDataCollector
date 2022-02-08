-- Made by IkeC
-- CSV saving based on "Server Players Data" by Lemos: https://steamcommunity.com/sharedfiles/filedetails/?id=2695733462

require "ZKModShared"

if isServer() then
    return
end

local function ZKGetCommonPlayerData()
    ZKPrint("ZKModClient.ZKGetCommonPlayerData")

    -- https://zomboid-javadoc.com/41.65/zombie/characters/IsoPlayer.html
    local player = getPlayer()

    if not player then
        ZKPrint("ZKModClient.ZKGetCommonPlayerData: No player data, exiting")
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

    ZKPrint("ZKModClient.SendPlayerData: isdead=" .. tostring(isdead))

    -- https://zomboid-javadoc.com/41.65/zombie/characters/IsoPlayer.html
    local player = getPlayer()
    if not player then
        ZKPrint("ZKModClient.SendPlayerData: No player data, exiting")
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

        -- https://zomboid-javadoc.com/41.65/zombie/characters/Faction.html
        local faction = Faction.getPlayerFaction(player)
        if faction then
            local tagColor = ""
            if faction:getTagColor() then
                tagColor = faction:getTagColor():toString()
            end
            playerData.factionName = faction:getName()
            playerData.factionTag = faction:getTag()
            playerData.factionTagColor = tagColor
            ZKPrint("faction: name=" .. faction:getName() .. " tag=" .. faction:getTag() .. " tagColor=" .. tagColor)
        else
            playerData.factionName = ""
            playerData.factionTag = ""
            playerData.factionTagColor = ""
            -- ZKPrint("faction empty")
        end

        -- https://zomboid-javadoc.com/41.65/zombie/iso/areas/SafeHouse.html
        local safehouse = SafeHouse.getSafeHouse(player:getSquare())
        if safehouse then
            playerData.safehouseTitle = ""
            playerData.safehouseX = safehouse:getX()
            playerData.safehouseX2 = safehouse:getX2()
            playerData.safehouseY = safehouse:getY()
            playerData.safehouseY2 = safehouse:getY2()
            ZKPrint("safehouse: title=" .. safehouse:getTitle() .. " X=" .. safehouse:getX() .. " Y=" .. safehouse:getY() ..  " X2=" .. safehouse:getX2() .. " Y2=" .. safehouse:getY2())
        else
            playerData.safehouseTitle = ""
            ZKPrint("safehouse empty")
        end 

        local command = "SendPlayerDataAlive"
        if isdead then
            command = "SendPlayerDataDead"
        end

        ZKPrint("ZKModClient.SendPlayerData: command=" .. command .. " username=" .. playerData.username)

        sendClientCommand(player, "ZKMod", command, playerData)
    end
end

local function ZKSendPlayerDataAlive()
    SendPlayerData(false)
end

local function ZKSendPlayerDataDeath()
    SendPlayerData(true)
end

local function ZKGetEventData(EventName)    
    local eventData = ZKGetCommonPlayerData()
    eventData.eventName = EventName
    eventData.eventData1 = ""
    eventData.eventData2 = ""
    eventData.eventData3 = ""
    eventData.eventData4 = ""
    eventData.eventData5 = ""
    
    return eventData
end

-- https://pzwiki.net/wiki/Modding:Lua_Events/LevelPerk
-- IsoGameCharacter The character whose perk is being leveled up or down.
-- https://zomboid-javadoc.com/41.65/zombie/characters/skills/PerkFactory.Perk.html The perk being leveled up or down.
-- Integer Perk level.
-- Boolean Whether the perk is being leveled up.
local function ZKLevelPerk(character, perk, level, levelUp)
    local eventData = ZKGetEventData("LevelPerk")
    if eventData then
        eventData.eventData1 = perk:getName()
        eventData.eventData2 = level
        eventData.eventData3 = levelUp
        local player = getPlayer()
        local command = "SendEvent"
        sendClientCommand(player, "ZKMod", command, eventData)
    end
end

local function ZKOnGameStart()
    ZKPrint("ZKModClient.ZKOnGameStart: SandboxVars.ZKMod.ClientSendPlayerDataAliveEvery=" .. SandboxVars.ZKMod.ClientSendPlayerDataAliveEvery)
    -- 0: Off, 1: EveryTenMinutes, 2: EveryHours, 3: EveryDays
    -- Default: 2

    if SandboxVars.ZKMod.ClientSendPlayerDataAliveEvery == 1 then
        Events.EveryTenMinutes.Add(ZKSendPlayerDataAlive)    
    elseif SandboxVars.ZKMod.ClientSendPlayerDataAliveEvery == 2 then
        Events.EveryHours.Add(ZKSendPlayerDataAlive)
    elseif SandboxVars.ZKMod.ClientSendPlayerDataAliveEvery == 3 then
        Events.EveryDays.Add(ZKSendPlayerDataAlive)
    end

    ZKPrint("ZKModClient.ZKOnGameStart: SandboxVars.ZKMod.ClientSendPlayerDataDeath=" .. SandboxVars.ZKMod.ClientSendPlayerDataDeath)
    -- 0: Off, 1: On
    -- Default: 1
    if SandboxVars.ZKMod.ClientSendPlayerDataDeath == 1 then
        Events.OnPlayerDeath.Add(ZKSendPlayerDataDeath)
    end

    ZKPrint("ZKModClient.ZKOnGameStart: SandboxVars.ZKMod.ClientSendEventLevelPerk=" .. SandboxVars.ZKMod.ClientSendEventLevelPerk)
    -- 0: Off, 1: On
    -- Default: 1
    if SandboxVars.ZKMod.ClientSendEventLevelPerk == 1 then
        Events.LevelPerk.Add(ZKLevelPerk)
    end
end
Events.OnGameStart.Add(ZKOnGameStart)

--https://pzwiki.net/wiki/Modding:Lua_Events/OnNewFire
--https://pzwiki.net/wiki/Modding:Lua_Events/OnZombieDead
--https://pzwiki.net/wiki/Modding:Lua_Events/OnCharacterMeet