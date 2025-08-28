local ws, err = http.websocket("ws://<server-ip>:8765")
if not ws then
    print("WebSocket error: " .. tostring(err))
    return
end

-- Device info
local info = {
    type = os.version(),
    label = os.getComputerLabel() or "",
    id = tostring(os.getComputerID())
}

-- Send registration
ws.send(textutils.serializeJSON(info))

-- Listen for commands
while true do
    local msg = ws.receive()
    if msg then
        local data = textutils.unserializeJSON(msg)
        if data and data.action == "execute" and data.code then
            local fn, err = load(data.code)
            if fn then
                pcall(fn)
            else
                print("Error loading code:", err)
            end
        end
    end
end
