local ip = "REPLACE"
-- josm :3
local function toJson(str)
    return textutils.serialiseJSON(str)
end
local function unJSON(str)
    return textutils.unserializeJSON(str)
end

-- ws loop, makes sure it stays connected even after the server goes down
while true do
    local ws, err = http.websocket("ws://"..ip..":8766")

    if not ws then
        print("WebSocket error: " .. tostring(err))
        sleep(3)
    else
        local info = {
            type = os.version(),
            label = os.getComputerLabel() or "",
            id = tostring(os.getComputerID())
        }

        pcall(function()
            ws.send(toJson(info))
            print("Connected.")
        end)

        while true do
            local ok, msg = pcall(function() return ws.receive() end)
            if not ok or not msg then
                print("Connection lost, reconnecting in 3 seconds.")
                pcall(function() ws.close() end)
                sleep(3)
                break -- break to outer loop to reconnect
            end
            print("got msg: "..msg)

            local okData, data = pcall(unJSON, msg)
            if okData and data and data.action == "execute" and data.code then
                local output = {}

                local function capturePrint(...)
                    local args = {...}
                    for i = 1, #args do
                        args[i] = tostring(args[i])
                    end
                    table.insert(output, table.concat(args, "\t"))
                end

                local fn, loadErr = load(data.code)
                if fn then
                    local execOk, execErr = pcall(function()
                        local oldPrint = print
                        print = capturePrint
                        pcall(fn)
                        print = oldPrint
                    end)
                    if not execOk and execErr then
                        table.insert(output, "Error: " .. tostring(execErr))
                    end
                else
                    table.insert(output, "Load error: " .. tostring(loadErr))
                end

                pcall(function()
                    ws.send(toJson({
                        action = "execute_result",
                        result = table.concat(output, "\n"),
                        request_id = data.request_id
                    }))
                end)
            end
        end
    end
end
