local GlobalSync = {}
local modem = peripheral.find("modem")
if not modem then error("No modem found!") end

local CHANNEL_MAIN = 1
local replyChannel = math.random(1000, 65535)
local isServer = false
local globals = {}
local listeners = {}
local saveDir = "/persistent_variables"
local saveFile = saveDir .. "/globals.data"

-- Utility: Deep set/get for namespaces like "balast.current" or "balast.goal"
local function deepSet(tbl, path, value)
    local parts = {}
    for part in string.gmatch(path, "[^.]+") do table.insert(parts, part) end
    local t = tbl
    for i = 1, #parts-1 do
        t[parts[i]] = t[parts[i]] or {}
        t = t[parts[i]]
    end
    t[parts[#parts]] = value
end

local function deepGet(tbl, path)
    local t = tbl
    for part in string.gmatch(path, "[^.]+") do
        if type(t) ~= "table" then return nil end
        t = t[part]
    end
    return t
end

-- Persistence
local function loadGlobals()
    if fs.exists(saveFile) then
        local h = fs.open(saveFile, "r")
        local data = h.readAll()
        h.close()
        globals = textutils.unserialize(data) or {}
    end
end

local function saveGlobals()
    if not fs.exists(saveDir) then fs.makeDir(saveDir) end
    local h = fs.open(saveFile, "w")
    h.write(textutils.serialize(globals))
    h.close()
end

-- Initialization
function GlobalSync.init(server)
    isServer = server or false
    modem.open(CHANNEL_MAIN)
    modem.open(replyChannel)
    if isServer then loadGlobals() end
end

-- Set a value and sync
function GlobalSync.set(key, value)
    deepSet(globals, key, value)
    saveGlobals()
    if isServer then
        modem.transmit(CHANNEL_MAIN, replyChannel, textutils.serialize({
            type = "delta", key = key, value = value
        }))
    else
        modem.transmit(CHANNEL_MAIN, replyChannel, textutils.serialize({
            type = "set", key = key, value = value
        }))
    end
    os.queueEvent("globals_updated", key, value)
end

-- Get a value
function GlobalSync.get(key)
    return deepGet(globals, key)
end

-- Register update listener
function GlobalSync.onUpdate(func)
    table.insert(listeners, func)
end

-- Event-driven handler
function GlobalSync.handleEvent(event, side, senderChannel, replyChannel, msg)
    if event ~= "modem_message" then return end
    local packet = textutils.unserialize(msg)
    if packet then
        if isServer then
            if packet.type == "request" then
                modem.transmit(replyChannel, replyChannel, textutils.serialize({
                    type = "update", data = globals
                }))
            elseif packet.type == "set" then
                deepSet(globals, packet.key, packet.value)
                saveGlobals()
                modem.transmit(CHANNEL_MAIN, replyChannel, textutils.serialize({
                    type = "delta", key = packet.key, value = packet.value
                }))
            end
        else
            if packet.type == "update" then
                globals = packet.data
            elseif packet.type == "delta" then
                deepSet(globals, packet.key, packet.value)
            end
            for _, func in ipairs(listeners) do
                func(packet.key, deepGet(globals, packet.key))
            end
            os.queueEvent("globals_updated", packet.key, deepGet(globals, packet.key))
        end
    end
end

return GlobalSync