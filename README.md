# Description
ZKMod is a Project Zomboid Steam Workshop Mod to collect and save player and world statistics on the server.

Mod page on Steam: https://steamcommunity.com/sharedfiles/filedetails/?id=2733284288

Workshop ID: 2733284288 / Mod ID: ZKMod

# Configuration
You may configure or turn features off in *<servername>_SandboxVars.lua*. If you don't configure anything default values are used.
  
Example configuration:
```
SandboxVars = {
    [...]
    ZKMod = {
        ServerSaveWorldEvery = 1,
        ServerSaveWorldHistoryEvery = 2,
        ServerSaveOnlinePlayersEvery = 1,
        ServerSaveSafehousesEvery = 3,
        ServerSaveFactionsEvery = 3,
        ClientSendPlayerDataAliveEvery = 2,
        ClientSendPlayerDataDeath = 1,
        ClientSendEventLevelPerk = 1,
    },
}
```
All options and possible values: https://github.com/IkeC/ZKMod/blob/master/media/sandbox-options.txt


# Changelog

## ZKMod 1.2 (2022-02-08)
* Feature: safehouses.csv: safehouse info
* Feature: factions.csv: faction info
* Feature: player_(name).csv: added faction info, safehouse info, favorite weapon name and hits
* all features can be configured or turned off in sandbox settings

## ZKMod 1.1 (2022-02-02)
* Feature: world(_history).csv: added extended weather data
* Feature: player_(name).csv: added isFemale
* Feature: events_history.csv: Saving player perk level ups (multiline)
* Feature: players_online.csv: Players currently online (single line) 

## ZKMod 1.0.1 (2022-01-28)
* Fix: worldData.worldAgeDays incorrect
* new preview image

## ZKMod 1.0 (2022-01-27)
* collects player and game world statistics
* saves collected data to CSV files on the server
