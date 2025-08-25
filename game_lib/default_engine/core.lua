-- core.lua
-- CC:T Render + Physics + UI Engine (Default build)
-- Provides: screen instances, layered rendering, objects, plugin hooks, UI glue.
-- Requires: physics.lua, ui.lua (in same folder)
-- Author: ChatGPT for Kitzuki

local M = {}

-- Helpers
local function clamp(v, minv, maxv) if v < minv then return minv elseif v > maxv then return maxv else return v end end
local function get_dir(path)
  -- figure out the directory of this file when required with `require`
  -- shell.getRunningProgram() is not reliable from libraries; use debug info fallback
  local info = debug.getinfo(2, "S")
  local src = info and info.source or ""
  if src:sub(1,1) == "@" then src = src:sub(2) end
  local dir = fs.getDir(src)
  if dir == "" then dir = "." end
  return dir
end

-- Minimal event bus for plugins
local EventBus = {}
EventBus.__index = EventBus
function EventBus.new()
  return setmetatable({listeners = {}}, EventBus)
end
function EventBus:on(ev, fn)
  if not self.listeners[ev] then self.listeners[ev] = {} end
  table.insert(self.listeners[ev], fn)
end
function EventBus:emit(ev, ...)
  local lst = self.listeners[ev]
  if lst then for i = 1, #lst do
    local ok, err = pcall(lst[i], ...)
    if not ok then print("Plugin listener error on '"..ev.."': "..tostring(err)) end
  end end
end

-- Screen / World instance
function M.newScreen(monitor)
  if type(monitor) == "string" then monitor = peripheral.wrap(monitor) end
  if not monitor then error("Invalid monitor peripheral") end

  local mon = monitor
  local w, h = mon.getSize()
  local screen = {
    mon = mon,
    width = w, height = h,
    objects = {},        -- { id -> obj }
    drawOrder = {},      -- list of ids (sorted by z asc)
    nextId = 1,
    gravity = {0, 0.2},  -- default mild gravity tuned for 20 TPS
    tickRate = 0.05,     -- 20 ticks per second
    events = EventBus.new(),
    running = false,
    bgChar = " ",        -- clear fill
    worldBounds = {x=1, y=1, w=w, h=h},
    allowColor = mon.isColor and mon.isColor(),
    _dragging = nil,     -- ui drag token (managed by ui.lua)
  }

  -- ===================== Object API =====================
  local function indexAABB(obj)
    local w = obj.size.w or 1
    local h = obj.size.h or 1
    if obj.shape == "line" then
      w = obj.size.length or w
      h = 1
    elseif obj.shape == "point" then
      w, h = 1, 1
    end
    return {x = obj.x, y = obj.y, w = w, h = h}
  end

  function screen:addObject(x, y, char)
    local id = self.nextId
    self.nextId = id + 1
    local obj = {
      id = id,
      x = x or 1, y = y or 1,
      vx = 0, vy = 0,
      rotation = 0,
      char = char or "O",
      shape = "point",
      size = {w = 1, h = 1, length = 1},
      z = 0,
      physType = "stationary", -- "normal"|"stationary"|"custom"
      weight = 1,
      gravity_vector = {0, 1},
      collides = true,
      restitution = 0, -- 0=stick, 1=perfect bounce
      draggable = false,
      visible = true,
      color = nil, -- setTextColor (requires color monitor)
    }
    function obj:setPhysType(ptype, params)
      self.physType = ptype
      if ptype == "normal" then
        local wgt = params and params.weight or 1
        self.weight = wgt
      elseif ptype == "custom" then
        self.gravity_vector = (params and params.gravity_vector) or {0,1}
        self.weight = (params and params.weight) or 1
      end
      return self
    end
    function obj:setVelocity(vx, vy) self.vx, self.vy = vx or 0, vy or 0; return self end
    function obj:setPos(x, y) self.x, self.y = x or self.x, y or self.y; return self end
    function obj:setRot(r) self.rotation = r or 0; return self end
    function obj:setShape(shape, size)
      self.shape = shape or self.shape
      if size then self.size = size end
      return self
    end
    function obj:setZ(z) self.z = z or 0; return self end
    function obj:setChar(c) self.char = c or self.char; return self end
    function obj:setColor(c) self.color = c; return self end
    function obj:setDraggable(flag) self.draggable = not not flag; return self end
    function obj:getAABB() return indexAABB(self) end

    self.objects[id] = obj
    table.insert(self.drawOrder, id)
    self:_resort()
    self.events:emit("object_added", self, obj)
    return obj
  end

  function screen:removeObject(id)
    if type(id) == "table" then id = id.id end
    local obj = self.objects[id]
    if not obj then return end
    self.objects[id] = nil
    for i=#self.drawOrder,1,-1 do
      if self.drawOrder[i] == id then table.remove(self.drawOrder, i) break end
    end
    self.events:emit("object_removed", self, obj)
  end

  function screen:_resort()
    table.sort(self.drawOrder, function(a,b)
      local oa, ob = self.objects[a], self.objects[b]
      if not oa or not ob then return a < b end
      if oa.z == ob.z then return oa.id < ob.id end
      return oa.z < ob.z
    end)
  end

  -- ===================== Rendering =====================
  function screen:clear()
    self.mon.setBackgroundColor(colors.black)
    self.mon.setTextColor(colors.white)
    self.mon.clear()
    self.mon.setCursorPos(1,1)
  end

  local function drawChar(mon, x, y, ch, color, allowColor)
    if x < 1 or y < 1 then return end
    local W, H = mon.getSize()
    if x > W or y > H then return end
    if allowColor and color then mon.setTextColor(color) end
    mon.setCursorPos(x, y)
    mon.write(ch or " ")
  end

  function screen:_drawObject(obj)
    if not obj.visible then return end
    local x, y = math.floor(obj.x), math.floor(obj.y)
    local aabb = obj:getAABB()
    local maxX, maxY = self.width, self.height

    if obj.shape == "point" then
      drawChar(self.mon, x, y, obj.char, obj.color, self.allowColor)
    elseif obj.shape == "box" then
      local w, h = obj.size.w or 1, obj.size.h or 1
      for dx=0,w-1 do
        for dy=0,h-1 do
          local px, py = x + dx, y + dy
          if px >= 1 and py >= 1 and px <= maxX and py <= maxY then
            drawChar(self.mon, px, py, obj.char, obj.color, self.allowColor)
          end
        end
      end
    elseif obj.shape == "line" then
      local len = obj.size.length or 1
      for i=0,len-1 do
        drawChar(self.mon, x + i, y, obj.char, obj.color, self.allowColor)
      end
    end
  end

  function screen:render()
    self.events:emit("pre_render", self)
    self:clear()
    -- world
    for i=1,#self.drawOrder do
      local obj = self.objects[self.drawOrder[i]]
      if obj then self:_drawObject(obj) end
    end
    -- UI layer is rendered by ui.lua (registered to post_render)
    self.events:emit("post_render", self)
  end

  -- ===================== Main Loop =====================
  function screen:_resizeCheck()
    local w, h = self.mon.getSize()
    if w ~= self.width or h ~= self.height then
      self.width, self.height = w, h
      self.worldBounds.w, self.worldBounds.h = w, h
      self.events:emit("resized", self, w, h)
    end
  end

  function screen:step(dt, physics)
    self.events:emit("pre_update", self, dt)
    physics.step(self, dt)
    self.events:emit("post_update", self, dt)
    self:_resizeCheck()
  end

  function screen:start(opts)
    opts = opts or {}
    local physics = require(fs.combine(get_dir(), "physics"))
    local ui = require(fs.combine(get_dir(), "ui"))
    ui._attach(self) -- binds UI rendering & input to events

    if opts.plugins ~= false then
      local plugDir = opts.plugins_dir or fs.combine(get_dir(), "plugins")
      self:loadPlugins(plugDir)
    end

    self.running = true
    local tick = self.tickRate
    local function loopPhysicsRender()
      while self.running do
        self:step(tick, physics)
        self:render()
        sleep(tick)
      end
    end
    local function loopInput()
      ui._inputLoop(self) -- blocking, uses os.pullEvent
    end
    parallel.waitForAny(loopPhysicsRender, loopInput)
  end

  function screen:stop() self.running = false end

  -- ===================== Plugins =====================
  function screen:loadPlugins(dir)
    if not fs.exists(dir) or not fs.isDir(dir) then return end
    local files = fs.list(dir)
    for _, f in ipairs(files) do
      if f:match("%.lua$") then
        local path = fs.combine(dir, f)
        local ok, plugin = pcall(dofile, path)
        if ok and type(plugin) == "table" and type(plugin.setup) == "function" then
          local ok2, err = pcall(plugin.setup, self)
          if not ok2 then print("Plugin setup error in "..f..": "..tostring(err)) end
        end
      end
    end
  end

  return screen
end

return M
