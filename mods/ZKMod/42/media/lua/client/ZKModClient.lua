-- Made by IkeC
-- CSV saving based on "Server Players Data" by Lemos: https://steamcommunity.com/sharedfiles/filedetails/?id=2695733462
require "ZKModShared"

if isServer() then
    return
end

ZKPrint("Mod version: v2.0.0 (Build 41+42)")

local clientEventsRegistered = false

local trackedPerks = {
    "Agility",
    "Aiming",
    "Axe",
    "Blacksmith",
    "Blunt",
    "Combat",
    "Cooking",
    "Crafting",
    "Doctor",
    "Electricity",
    "Farming",
    "Firearm",
    "Fishing",
    "Fitness",
    "Lightfoot",
    "LongBlade",
    "Maintenance",
    "Mechanics",
    "Melee",
    "Melting",
    "MetalWelding",
    "Nimble",
    "PlantScavenging",
    "Reloading",
    "SmallBlade",
    "SmallBlunt",
    "Sneak",
    "Spear",
    "Sprinting",
    "Strength",
    "Survivalist",
    "Tailoring",
    "Trapping",
    "Woodwork"
}

local function ZKGetCommonPlayerData()

    -- https://zomboid-javadoc.com/41.65/zombie/characters/IsoPlayer.html
    local player = getPlayer()

    if not player then
        ZKPrint("ZKGetCommonPlayerData: No player data, exiting")
        return
    end

    -- https://zomboid-javadoc.com/41.65/zombie/GameTime.html
    local gametime = getGameTime()

    local username = player:getUsername()
    local descriptor = player:getDescriptor()
    local forname = ""
    local surname = ""
    if descriptor then
        forname = descriptor:getForename() or ""
        surname = descriptor:getSurname() or ""
    end

    local playerData = {}

    playerData.systemDate = ZKGetSystemDate()
    playerData.systemTime = ZKGetSystemTime()
    playerData.gametime = ZKGetGameTimeString(gametime)
    local steamID = ""
    if player.getSteamID then
        steamID = player:getSteamID() or ""
    end
    if steamID == "" and username then
        local resolved = getSteamIDFromUsername(username)
        if resolved then
            steamID = resolved
        end
    end
    playerData.steamID = steamID

    playerData.username = username
    local charName = (forname .. " " .. surname):gsub("^%s+", "")
    charName = charName:gsub("%s+$", "")
    if charName == "" then
        charName = username or ""
    end
    playerData.charName = charName

    return playerData
end

local function SendPlayerData(isdead)

    -- ZKPrint("SendPlayerData: isdead=" .. tostring(isdead))

    -- https://zomboid-javadoc.com/41.65/zombie/characters/IsoPlayer.html
    local player = getPlayer()
    if not player then
        ZKPrint("SendPlayerData: No player data, exiting")
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
        if nutrition then
            playerData.weight = string.format("%.1f", nutrition:getWeight())
            playerData.characterHaveWeightTrouble = nutrition:characterHaveWeightTrouble()
        else
            playerData.weight = "0.0"
            playerData.characterHaveWeightTrouble = false
        end

        -- https://zomboid-javadoc.com/41.65/zombie/characters/SurvivorDesc.html
        local descriptor = player:getDescriptor()
        if descriptor and descriptor.getProfession then
            playerData.profession = descriptor:getProfession() or ""
        else
            playerData.profession = ""
        end

        -- https://zomboid-javadoc.com/41.65/zombie/characters/traits/TraitCollection.html
        local traitCollection = descriptor and descriptor.getTraits and descriptor:getTraits()
        if traitCollection and traitCollection.toString then
            playerData.traits = traitCollection:toString()
        else
            playerData.traits = ""
        end

        playerData.isFemale = player:isFemale()

        -- https://zomboid-javadoc.com/41.65/zombie/characters/Faction.html
        local faction = Faction.getPlayerFaction(player)
        if faction then

            if faction:getName() then
                playerData.factionName = faction:getName()
            else
                playerData.factionName = ""
            end
            if faction:getTag() then
                playerData.factionTag = faction:getTag()
            else
                playerData.factionTag = ""
            end

            playerData.factionTagColorR = ""
            playerData.factionTagColorG = ""
            playerData.factionTagColorB = ""

            if faction:getTagColor() then
                local color = faction:getTagColor():toColor()
                playerData.factionTagColorR = color:getRed()
                playerData.factionTagColorG = color:getGreen()
                playerData.factionTagColorB = color:getBlue()
            end
        else
            playerData.factionName = ""
            playerData.factionTag = ""
            playerData.factionTagColorR = ""
            playerData.factionTagColorG = ""
            playerData.factionTagColorB = ""
            -- ZKPrint("faction empty")
        end

        -- https://zomboid-javadoc.com/41.65/zombie/iso/areas/SafeHouse.html
        local safehouse = SafeHouse.hasSafehouse(player)
        -- local safehouse = SafeHouse.getSafeHouse(player:getSquare())

        if safehouse then
            if safehouse:getTitle() then
                playerData.safehouseTitle = safehouse:getTitle()
            else
                playerData.safehouseTitle = ""
            end
            if safehouse:getX() then
                playerData.safehouseX = safehouse:getX()
            else
                playerData.safehouseX = ""
            end
            if safehouse:getX2() then
                playerData.safehouseX2 = safehouse:getX2()
            else
                playerData.safehouseX2 = ""
            end
            if safehouse:getY() then
                playerData.safehouseY = safehouse:getY()
            else
                playerData.safehouseY = ""
            end
            if safehouse:getY2() then
                playerData.safehouseY2 = safehouse:getY2()
            else
                playerData.safehouseY2 = ""
            end
            -- ZKPrint("safehouse: title=" .. safehouse:getTitle() .. " X=" .. safehouse:getX() .. " Y=" .. safehouse:getY() ..  " X2=" .. safehouse:getX2() .. " Y2=" .. safehouse:getY2())
        else
            playerData.safehouseTitle = ""
            playerData.safehouseX = ""
            playerData.safehouseX2 = ""
            playerData.safehouseY = ""
            playerData.safehouseY2 = ""
            -- ZKPrint("safehouse empty")
        end

        local favoriteWeaponHit = 0;
        local favoriteWeapon = "";

        local modData = player:getModData()
        if modData then
            for iPData, vPData in pairs(modData) do
                -- ZKPrint("iPData type=[" .. type(iPData) .. "]")
                -- ZKPrint("iPData=[" .. ZKDump(iPData) .. "]")
                -- ZKPrint("vPData type=[" .. type(vPData) .. "]")
                -- ZKPrint("vPData=[" .. ZKDump(vPData) .. "]")
                for index in string.gmatch(iPData, "^Fav:(.+)") do
                    if vPData > favoriteWeaponHit then
                        favoriteWeapon = index;
                        favoriteWeaponHit = vPData;
                    end
                end
            end
        end

        playerData.favoriteWeapon = favoriteWeapon;
        playerData.favoriteWeaponHit = favoriteWeaponHit;

        local damage = player:getBodyDamage()

        if damage then
            playerData.hasInjury = damage:HasInjury()
            playerData.health = string.format("%.1f", damage:getHealth())
            playerData.wetness = string.format("%.1f", damage:getWetness())
            playerData.boredom = string.format("%.1f", damage:getBoredomLevel())
            playerData.infectionLevel = string.format("%.1f", damage:getInfectionLevel())
            playerData.fakeInfectionLevel = string.format("%.1f", damage:getFakeInfectionLevel())
        end

        local command = "SendPlayerDataAlive"
        if isdead then
            command = "SendPlayerDataDead"
        end

        ZKPrint("SendPlayerData: command=" .. command .. " username=" .. playerData.username)

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

local function ZKSendPlayerPerksData()

    -- https://zomboid-javadoc.com/41.65/zombie/characters/IsoPlayer.html
    local player = getPlayer()
    if not player then
        ZKPrint("SendPlayerPerksData: No player data, exiting")
        return
    end

    local playerData = ZKGetCommonPlayerData()

    if playerData then

        for _, perkName in ipairs(trackedPerks) do
            local perk = Perks[perkName]
            if perk then
                playerData[perkName] = player:getPerkLevel(perk)
            end
        end

        local command = "SendPlayerPerksData"
        ZKPrint("SendPlayerPerksData: command=" .. command .. " username=" .. playerData.username)

        sendClientCommand(player, "ZKMod", command, playerData)
    end
end

local function ZKSendPlayerInventoryData()

    -- https://zomboid-javadoc.com/41.65/zombie/characters/IsoPlayer.html
    local player = getPlayer()
    if not player then
        ZKPrint("SendPlayerInventoryData: No player data, exiting")
        return
    end

    local username = player:getUsername()
    local playerData = {}

    playerData.systemDate = ZKGetSystemDate()
    playerData.systemTime = ZKGetSystemTime()
    playerData.gametime = ZKGetGameTimeString(getGameTime())
    playerData.username = username

    local lines = {}
    local inventory = player:getInventory()
    if not inventory then
        ZKPrint("ZKSendPlayerInventoryData: inventory missing for " .. tostring(username))
        return
    end
    ZKSaveItemContainer(lines, playerData, "", inventory)

    local command = "SendPlayerInventoryData"
    ZKPrint("SendPlayerInventoryData: command=" .. command .. " username=" .. username)
    sendClientCommand(player, "ZKMod", command, lines)
end

-- SaveItem... functions kindly taken from "Character Save" Mod by Tchernobill 
-- https://steamcommunity.com/sharedfiles/filedetails/?id=2673317083
function ZKSaveItemContainer(lines, playerData, itemIndex, itemContainer)
    if not itemContainer then
        return
    end
    local invInventory = itemContainer:getItems();
    if not invInventory then
        return
    end
    local initialInvLastIt = invInventory:size() - 1;
    local countIndex = 1;

    for f = 0, initialInvLastIt do
        local item = invInventory:get(f);
        local itemId = item:getFullType()
        if itemId and itemId ~= "Base.KeyRing" then
            -- keyring is a pain and keys are world related anyway

            local line = ZKShallowCopy(playerData)
            
            local currentItemIndex = countIndex
            if itemIndex~="" then
                currentItemIndex = itemIndex.."|"..currentItemIndex
            end
            line.ItemIndex = currentItemIndex
            countIndex = countIndex + 1

            line.ItemCategory = item:getCategory()
            line.ItemId = itemId
            line.ItemDisplayName = item:getDisplayName()
            line.ItemExtraInfo = ""

            --ZKPrint("ZKSaveItemContainer: line=" .. ZKDump(line))

            table.insert(lines, line)

            if item:getCategory() == "Container" then
                ZKSaveItemContainer(lines, playerData, currentItemIndex, item:getInventory())
            elseif item:getCategory() == "Weapon" then
                ZKSaveItemWeaponPart(lines, playerData, currentItemIndex, item)
                ZKSaveItemWeaponMagazine(lines, playerData, currentItemIndex, item)
            end
        end
    end
end

function ZKSaveItemWeaponPart(lines, playerData, itemIndex, weaponItem)
    if not weaponItem then
        return
    end
    local weaponParts = weaponItem:getAllWeaponParts();
    if not weaponParts then
        return
    end
    for f = 0, weaponParts:size() - 1 do
        local item = weaponParts:get(f);
        if item then
            local itemId = item:getFullType()

            local line = ZKShallowCopy(playerData)

            local currentItemIndex = tostring(f + 1)
            if itemIndex~="" then
                currentItemIndex = itemIndex.."|"..currentItemIndex
            end
            line.ItemIndex = currentItemIndex
            
            line.ItemCategory = "WeaponPart"
            line.ItemId = itemId
            line.ItemDisplayName = ""
            line.ItemExtraInfo = ""

            --ZKPrint("ZKSaveItemWeaponPart: line=" .. ZKDump(line))

            table.insert(lines, line)
        end
    end
end

function ZKSaveItemWeaponMagazine(lines, playerData, itemIndex, weaponItem)
    if not weaponItem then
        return
    end
    local magazineType = weaponItem:getMagazineType();
    if weaponItem:isContainsClip() and magazineType then
        local nbAmmo = weaponItem:getCurrentAmmoCount()
        if weaponItem:isRoundChambered() then
            nbAmmo = nbAmmo + 1
        end

        local line = ZKShallowCopy(playerData)

        local currentItemIndex = 1
        if itemIndex~="" then
            currentItemIndex = itemIndex.."|"..currentItemIndex
        end
        line.ItemIndex = currentItemIndex
        
        line.ItemCategory = "HandWeaponClip"
        line.ItemId = magazineType
        line.ItemDisplayName = weaponItem:getDisplayName()
        line.ItemExtraInfo = "ammo=" .. nbAmmo

        --ZKPrint("ZKSaveItemWeaponMagazine: line=" .. ZKDump(line))

        table.insert(lines, line)
    end
end

-- https://pzwiki.net/wiki/Modding:Lua_Events/LevelPerk
-- IsoGameCharacter The character whose perk is being leveled up or down.
-- https://zomboid-javadoc.com/41.65/zombie/characters/skills/PerkFactory.Perk.html The perk being leveled up or down.
-- Integer Perk level.
-- Boolean Whether the perk is being leveled up.
local function ZKLevelPerk(character, perk, level, levelUp)
    local eventData = ZKGetEventData("LevelPerk")
    if eventData then
        eventData.eventData1 = perk and perk:getName() or ""
        eventData.eventData2 = level or 0
        eventData.eventData3 = levelUp and true or false
        local player = character
        if not player or not player.getUsername then
            player = getPlayer()
        end
        if player then
            local command = "SendEvent"
            sendClientCommand(player, "ZKMod", command, eventData)
        end
    end

    ZKSendPlayerPerksData()
end

local function ZKSendPlayerInventoryDataStart()
    ZKPrint("ZKSendPlayerInventoryDataStart")
    ZKSendPlayerInventoryData()
    Events.EveryTenMinutes.Remove(ZKSendPlayerInventoryDataStart)
end

local function ZKRegisterClientEvents()
    if clientEventsRegistered then
        return
    end

    if not SandboxVars or not SandboxVars.ZKMod then
        ZKPrint("ZKRegisterClientEvents: SandboxVars.ZKMod not ready, waiting for another lifecycle event")
        return
    end

    clientEventsRegistered = true
    local zkSandbox = SandboxVars.ZKMod

    ZKPrint("ZKRegisterClientEvents: SandboxVars.ZKMod.ClientSendPlayerDataAliveEvery=" ..
                tostring(zkSandbox.ClientSendPlayerDataAliveEvery))
    -- 0: Off, 1: EveryTenMinutes, 2: EveryHours, 3: EveryDays
    -- Default: 2

    if zkSandbox.ClientSendPlayerDataAliveEvery == 1 then
        Events.EveryTenMinutes.Add(ZKSendPlayerDataAlive)
    elseif zkSandbox.ClientSendPlayerDataAliveEvery == 2 then
        Events.EveryHours.Add(ZKSendPlayerDataAlive)
    elseif zkSandbox.ClientSendPlayerDataAliveEvery == 3 then
        Events.EveryDays.Add(ZKSendPlayerDataAlive)
    end

    ZKPrint("ZKRegisterClientEvents: SandboxVars.ZKMod.ClientSendPlayerDataDeath=" .. tostring(zkSandbox.ClientSendPlayerDataDeath))
    -- 0: Off, 1: On
    -- Default: 1
    if zkSandbox.ClientSendPlayerDataDeath == 1 then
        Events.OnPlayerDeath.Add(ZKSendPlayerDataDeath)
    end

    ZKPrint("ZKRegisterClientEvents: SandboxVars.ZKMod.ClientSendEventLevelPerk=" .. tostring(zkSandbox.ClientSendEventLevelPerk))
    -- 0: Off, 1: On
    -- Default: 1
    if zkSandbox.ClientSendEventLevelPerk == 1 then
        Events.LevelPerk.Add(ZKLevelPerk)
    end

    ZKPrint("ZKRegisterClientEvents: SandboxVars.ZKMod.ClientSendPlayerPerksDataEvery=" ..
                tostring(zkSandbox.ClientSendPlayerPerksDataEvery))
    -- 0: Off, 1: EveryTenMinutes, 2: EveryHours, 3: EveryDays
    -- Default: 3
    if zkSandbox.ClientSendPlayerPerksDataEvery == 1 then
        Events.EveryTenMinutes.Add(ZKSendPlayerPerksData)
    elseif zkSandbox.ClientSendPlayerPerksDataEvery == 2 then
        Events.EveryHours.Add(ZKSendPlayerPerksData)
    elseif zkSandbox.ClientSendPlayerPerksDataEvery == 3 then
        Events.EveryDays.Add(ZKSendPlayerPerksData)
    end

    ZKPrint("ZKRegisterClientEvents: SandboxVars.ZKMod.ClientSendPlayerInventoryDataEvery=" ..
                tostring(zkSandbox.ClientSendPlayerInventoryDataEvery))
    -- 0: Off, 1: EveryTenMinutes, 2: EveryHours, 3: EveryDays
    -- Default: 3
    if zkSandbox.ClientSendPlayerInventoryDataEvery == 1 then
        Events.EveryTenMinutes.Add(ZKSendPlayerInventoryData)
    elseif zkSandbox.ClientSendPlayerInventoryDataEvery == 2 then
        Events.EveryHours.Add(ZKSendPlayerInventoryData)
    elseif zkSandbox.ClientSendPlayerInventoryDataEvery == 3 then
        Events.EveryDays.Add(ZKSendPlayerInventoryData)
    end

    -- also do once on join
    if (zkSandbox.ClientSendPlayerInventoryDataEvery or 0) > 1 then
        ZKPrint("ZKRegisterClientEvents: adding ZKSendPlayerInventoryDataStart")
        Events.EveryTenMinutes.Add(ZKSendPlayerInventoryDataStart)
    end
end

local function ZKOnGameStart()
    ZKRegisterClientEvents()
end

local function ZKOnCreatePlayerEvent()
    ZKRegisterClientEvents()
end

Events.OnGameStart.Add(ZKOnGameStart)
Events.OnCreatePlayer.Add(function(playerIndex, player)
    ZKOnCreatePlayerEvent()
end)

-- https://pzwiki.net/wiki/Modding:Lua_Events/OnNewFire
-- https://pzwiki.net/wiki/Modding:Lua_Events/OnZombieDead
-- https://pzwiki.net/wiki/Modding:Lua_Events/OnCharacterMeet
