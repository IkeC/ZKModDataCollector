-- Made by IkeC
-- CSV saving based on "Server Players Data" by Lemos: https://steamcommunity.com/sharedfiles/filedetails/?id=2695733462
function ZKGetGameTimeString(gt)
    local minutes = string.format("%02d", gt:getMinutes())
    local result = gt:getDay() + 1 .. "." .. gt:getMonth() + 1 .. "." .. gt:getYear() .. " " .. gt:getHour() .. ":" ..
                       minutes

    return result
end

function ZKGetCSVHeader(data)
    local strHeader = ""
    local separator = ""

    -- build the header
    for k, v in pairs(data) do
        if strHeader ~= "" then
            separator = ";"
        end

        strHeader = strHeader .. separator .. k
    end
    strHeader = strHeader .. "\n"

    return strHeader
end

function ZKGetCSVLine(data)
    local strData = ""
    local separator = ""
    local escapedValue = ""

    -- fill data on next line
    for k, v in pairs(data) do
        if strData ~= "" then
            separator = ";"
        end

        if type(v) == "string" then
            escapedValue = v:gsub("\"", "''")
            escapedValue = escapedValue:gsub(";", ",")
            strData = strData .. separator .. "\"" .. escapedValue .. "\""
        else

            strData = strData .. separator .. tostring(v)
        end
    end

    strData = strData .. "\n"

    return strData
end

function ZKDump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end
            s = s .. '[' .. k .. '] = ' .. ZKDump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

function ZKGetSystemDate()
    return tostring(os.date("%d.%m.%Y", os.time() + 2 * 60 * 60))
end

function ZKGetSystemTime()
    return tostring(os.date("%H:%M:%S", os.time() + 2 * 60 * 60))
end

function ZKPrint(msg)
    print(ZKGetSystemDate() .. " " .. ZKGetSystemTime() .. " [ZKMod Data Collector] " .. msg)
end

function ZKShallowCopy(original)
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = value
    end
    return copy
end
