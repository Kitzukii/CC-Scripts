local lib = require("ccgame")
local scr = lib.newScreen("monitor_0")

-- Object
local obj = scr:addObject(5, 1, "O")
obj:setPhysType("normal", {weight = 1})

-- Button
scr:addButton("Reset", 2, 10, 10, 3, function()
    obj:setPos(5, 1)
    obj:setVelocity(0, 0)
end)

scr:start()