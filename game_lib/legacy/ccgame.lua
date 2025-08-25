local lib = {}

function lib.newScreen(monitor)
    if type(monitor) == "string" then
        monitor = peripheral.wrap(monitor)
    end
    if not monitor then error("Invalid monitor peripheral") end

    local screen = {
        mon = monitor,
        objects = {},
        buttons = {},
        gravity = {0, 1},
        tickRate = 0.05,
        worldBounds = {width = monitor.getSize()},
    }

    function screen:clear()
        self.mon.clear()
        self.mon.setCursorPos(1, 1)
    end

    -- ========================= OBJECT MANAGEMENT =========================
    function screen:addObject(x, y, char)
        local obj = {
            x = x or 1, y = y or 1,
            vx = 0, vy = 0,
            rotation = 0,
            char = char or "O",
            shape = "point",
            size = {w = 1, h = 1},
            physType = "stationary",
            weight = 1,
            gravity_vector = {0, 1},
            collides = true,
        }

        function obj:setPhysType(ptype, params)
            self.physType = ptype
            if ptype == "normal" then
                self.weight = (params and params.weight) or 1
            elseif ptype == "custom" then
                self.gravity_vector = params.gravity_vector or {0, 1}
                self.weight = params.weight or 1
            end
        end
        function obj:setVelocity(vx, vy) self.vx, self.vy = vx, vy end
        function obj:setPos(x, y) self.x, self.y = x, y end
        function obj:setRot(r) self.rotation = r end
        function obj:setShape(shape, size)
            self.shape = shape
            self.size = size or {w = 1, h = 1}
        end

        table.insert(self.objects, obj)
        return obj
    end

    -- ========================= BUTTON MANAGEMENT =========================
    function screen:addButton(label, x, y, w, h, callback)
        local btn = {
            label = label,
            x = x, y = y,
            w = w, h = h,
            callback = callback,
        }
        table.insert(self.buttons, btn)
        return btn
    end

    function screen:renderButtons()
        for _, btn in ipairs(self.buttons) do
            for dx = 0, btn.w - 1 do
                for dy = 0, btn.h - 1 do
                    local px, py = btn.x + dx, btn.y + dy
                    self.mon.setCursorPos(px, py)
                    self.mon.write(" ")
                end
            end
            -- Center text
            local tx = btn.x + math.floor(btn.w / 2) - math.floor(#btn.label / 2)
            local ty = btn.y + math.floor(btn.h / 2)
            self.mon.setCursorPos(tx, ty)
            self.mon.write(btn.label)
        end
    end

    function screen:handleInput()
        while true do
            local e, side, x, y = os.pullEvent("monitor_touch")
            for _, btn in ipairs(self.buttons) do
                if x >= btn.x and x < btn.x + btn.w and y >= btn.y and y < btn.y + btn.h then
                    if btn.callback then btn.callback() end
                end
            end
        end
    end

    -- ========================= PHYSICS & RENDERING =========================
    function screen:updatePhysics()
        for _, obj in ipairs(self.objects) do
            if obj.physType == "normal" then
                local g = (obj.weight == "auto" and 1 or obj.weight)
                obj.vy = obj.vy + self.gravity[2] * g
            elseif obj.physType == "custom" then
                obj.vx = obj.vx + obj.gravity_vector[1]
                obj.vy = obj.vy + obj.gravity_vector[2]
            end
            obj.x, obj.y = obj.x + obj.vx, obj.y + obj.vy

            local maxX, maxY = self.worldBounds.width, self.worldBounds.height
            if obj.collides then
                if obj.x < 1 then obj.x, obj.vx = 1, 0 end
                if obj.y < 1 then obj.y, obj.vy = 1, 0 end
                if obj.x > maxX then obj.x, obj.vx = maxX, 0 end
                if obj.y > maxY then obj.y, obj.vy = maxY, 0 end
            end
        end
    end

    function screen:renderObjects()
        for _, obj in ipairs(self.objects) do
            local x, y = math.floor(obj.x), math.floor(obj.y)
            if obj.shape == "point" then
                self.mon.setCursorPos(x, y)
                self.mon.write(obj.char)
            elseif obj.shape == "box" then
                for dx = 0, obj.size.w - 1 do
                    for dy = 0, obj.size.h - 1 do
                        self.mon.setCursorPos(x + dx, y + dy)
                        self.mon.write(obj.char)
                    end
                end
            elseif obj.shape == "line" then
                for i = 0, obj.size.length - 1 do
                    self.mon.setCursorPos(x + i, y)
                    self.mon.write(obj.char)
                end
            end
        end
    end

    function screen:render()
        self:clear()
        self:renderObjects()
        self:renderButtons()
    end

    function screen:start()
        parallel.waitForAny(
            function()
                while true do
                    self:updatePhysics()
                    self:render()
                    sleep(self.tickRate)
                end
            end,
            function() self:handleInput() end
        )
    end

    return screen
end

return lib
