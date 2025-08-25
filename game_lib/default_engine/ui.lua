-- ui.lua
-- Simple UI toolkit: buttons, sliders, and "tap-drag" for draggable objects.
-- Registers to core events and runs an input loop to handle monitor_touch.

local ui = {}

local function center_text_x(x, w, label)
  return x + math.floor(w/2) - math.floor(#label/2)
end

-- State per screen
local function ensure_state(scr)
  if scr._ui then return scr._ui end
  scr._ui = {
    buttons = {},
    sliders = {},
    pressFlash = 0.1,
    activeButton = nil,
    draggingObj = nil,   -- picked object id for tap-drag
  }
  return scr._ui
end

-- Public UI API (attached to screen)
local function attach_api(scr)
  local S = ensure_state(scr)

  function scr:addButton(label, x, y, w, h, callback, opts)
    local btn = {
      id = #S.buttons + 1,
      label = label or "Button",
      x = x, y = y, w = w, h = h,
      callback = callback,
      pressedUntil = 0,
      opts = opts or {},
      visible = true,
      z = 1e9, -- very high to render on top (UI)
    }
    table.insert(S.buttons, btn)
    return btn
  end

  function scr:addSlider(label, x, y, w, minv, maxv, value, onChange)
    local s = {
      id = #S.sliders + 1,
      label = label or "",
      x=x, y=y, w=w,
      min=minv or 0, max=maxv or 1, value=value or 0,
      onChange = onChange,
      visible = true,
    }
    table.insert(S.sliders, s)
    return s
  end
end

-- Rendering
local function render_ui(scr)
  local S = ensure_state(scr)
  local mon = scr.mon

  -- Buttons
  for _,b in ipairs(S.buttons) do
    if b.visible then
      local label = b.label
      for dx=0,b.w-1 do
        for dy=0,b.h-1 do
          mon.setCursorPos(b.x+dx, b.y+dy)
          mon.write(" ")
        end
      end
      local tx = center_text_x(b.x, b.w, label)
      local ty = b.y + math.floor(b.h/2)
      mon.setCursorPos(tx, ty); mon.write(label)
    end
  end

  -- Sliders (simple horizontal)
  for _,s in ipairs(S.sliders) do
    if s.visible then
      -- rail
      for i=0,s.w-1 do
        mon.setCursorPos(s.x+i, s.y); mon.write("-")
      end
      if s.label ~= "" then
        mon.setCursorPos(s.x, s.y-1); mon.write(s.label)
      end
      -- knob
      local t = 0
      if s.max ~= s.min then t = (s.value - s.min) / (s.max - s.min) end
      t = math.max(0, math.min(1, t))
      local kx = s.x + math.floor(t * (s.w-1))
      mon.setCursorPos(kx, s.y); mon.write("O")
    end
  end
end

-- Hit testing
local function hit_button_at(scr, x, y)
  local S = ensure_state(scr)
  for _,b in ipairs(S.buttons) do
    if b.visible and x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h then
      return b
    end
  end
  return nil
end

local function hit_slider_at(scr, x, y)
  local S = ensure_state(scr)
  for _,s in ipairs(S.sliders) do
    if s.visible and y == s.y and x >= s.x and x < s.x + s.w then
      return s
    end
  end
  return nil
end

local function hit_draggable_object(scr, x, y)
  -- topmost first based on z order
  for i = #scr.drawOrder, 1, -1 do
    local o = scr.objects[scr.drawOrder[i]]
    if o and o.draggable then
      local w, h = 1,1
      if o.shape == "box" then w, h = o.size.w or 1, o.size.h or 1
      elseif o.shape == "line" then w, h = o.size.length or 1, 1 end
      if x >= o.x and x < o.x + w and y >= o.y and y < o.y + h then
        return o
      end
    end
  end
  return nil
end

-- Input loop
function ui._inputLoop(scr)
  local S = ensure_state(scr)
  while scr.running do
    local e, side, x, y = os.pullEvent()
    if e == "monitor_touch" then
      -- Buttons
      local b = hit_button_at(scr, x, y)
      if b then
        b.pressedUntil = os.clock() + (S.pressFlash or 0.1)
        if b.callback then
          local ok, err = pcall(b.callback, scr, b)
          if not ok then print("Button callback error: "..tostring(err)) end
        end
      end

      -- Slider
      local s = hit_slider_at(scr, x, y)
      if s then
        local t = (x - s.x) / math.max(1, (s.w-1))
        local v = s.min + (s.max - s.min) * t
        s.value = v
        if s.onChange then
          local ok, err = pcall(s.onChange, scr, s, v)
          if not ok then print("Slider onChange error: "..tostring(err)) end
        end
      end

      -- Tap-drag (pick up / drop)
      local obj = hit_draggable_object(scr, x, y)
      if obj then
        if S.draggingObj and S.draggingObj.id == obj.id then
          -- drop
          S.draggingObj = nil
        else
          S.draggingObj = obj
        end
      elseif S.draggingObj then
        -- move dragged object to new location
        S.draggingObj.x, S.draggingObj.y = x, y
        S.draggingObj.vx, S.draggingObj.vy = 0, 0
      end

      scr.events:emit("touch", scr, side, x, y)
    end
  end
end

-- Hook into render
function ui._attach(scr)
  ensure_state(scr)
  attach_api(scr)
  scr.events:on("post_render", function(s) render_ui(s) end)
end

return ui
