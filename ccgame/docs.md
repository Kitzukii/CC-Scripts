# CC:T Render + Physics + UI Engine (Default Build)

A modular engine for **ComputerCraft: Tweaked** monitors with:
- Screen instances
- Objects (point, box, line)
- Physics (gravity, velocity, bounds, object-object collisions)
- On-screen UI (buttons, sliders, tap-drag)
- Z-index layering
- Plugin system

> This is the **default** build. A **mini** build can omit UI, collisions, and plugins.

---

## Installation
Pretty simple.
```pdf
wget run https://raw.githubusercontent.com/Kitzukii/CC-Scripts/main/ccgame/install.lua
```

```
/your_program.lua
/ccgame/
  core.lua
  physics.lua
  ui.lua
  docs.md
  /plugins/
    example.lua
```

## Quick Start
```lua
local engine = require("ccgame.core")

-- attach to a monitor by name or wrapped peripheral
local scr = engine.newScreen("top")  -- e.g. monitor on top
-- or: local scr = engine.newScreen(peripheral.wrap("monitor_0"))

-- Create some objects
local box = scr:addObject(5, 2, "#"):setShape("box", {w=4, h=2}):setPhysType("normal", {weight = 1}):setZ(1)
local ball = scr:addObject(10, 1, "o"):setPhysType("custom", {gravity_vector = {0, 0.2}, weight = 1})
ball:setVelocity(0.1, 0)

-- Make draggable
box:setDraggable(true)
ball:setDraggable(true)

-- UI
scr:addButton("Reset", 2, 10, 10, 3, function(s)
  box:setPos(5, 2):setVelocity(0, 0)
  ball:setPos(10, 1):setVelocity(0, 0)
end)

scr:addSlider("Gravity Y", 2, 7, 12, -1.0, 1.0, scr.gravity[2], function(s, slider, v)
  s.gravity[2] = v
end)

-- Run
scr:start()
```

## API

### `core.newScreen(monitor | name) -> screen`
Creates a screen instance bound to a CC:T monitor peripheral.

**Screen fields**
- `mon` – the monitor
- `width, height` – monitor size
- `gravity` – `{gx, gy}` default `{0, 0.2}`
- `tickRate` – seconds per tick (default `0.05`)
- `worldBounds` – `{x=1, y=1, w, h}`

**Object creation**
```lua
obj = screen:addObject(x, y, char)
  :setShape("point" | "box" | "line", sizeTable)
  :setPhysType("stationary" | "normal" | "custom", params)
  :setVelocity(vx, vy)
  :setPos(x, y)
  :setRot(radians?)     -- rotation stored but not used by rasterizer (future use)
  :setZ(z)              -- render order (higher z draws later)
  :setChar(c)
  :setColor(colors.red) -- if advanced monitor
  :setDraggable(true)
```
- Box size: `{w=number, h=number}`
- Line size: `{length=number}`
- `normal` params: `{weight = "auto" | number}`
- `custom` params: `{gravity_vector = {gx, gy}, weight = number}`

**Start / Stop**
```lua
screen:start({ plugins = true, plugins_dir = "ccgame/plugins" })
screen:stop()
```

**Plugins**
Any `.lua` in `plugins/` must return `{ setup = function(screen) ... end }`.
Use `screen.events:on(name, fn)` to hook:
- `object_added`, `object_removed`
- `pre_update`, `post_update`
- `pre_render`, `post_render`
- `touch` (side, x, y)
- `resized`

Example plugin: `plugins/example.lua` toggles point chars and adds `screen:makeBouncy(obj, amount)`.

## UI

### Buttons
```lua
local btn = screen:addButton("Click", 2, 12, 10, 3, function(s, b)
  print("Clicked:", b.label)
end)
```

### Sliders
```lua
screen:addSlider("Gravity Y", 2, 7, 12, -1.0, 1.0, screen.gravity[2], function(s, slider, v)
  s.gravity[2] = v
end)
```

### Dragging
Monitors only emit `monitor_touch`. True dragging is not available.
This engine implements **tap-drag**:
- Tap a **draggable** object to **pick up**.
- Tap elsewhere to **drop** it at that position.

## Notes / Limits
- Rotation is stored per-object for future rotated shapes; current rasterizer is axis-aligned.
- Physics is integer-grid oriented; velocities are scaled for 20 TPS (`vx=1` ≈ one cell/tick).
- Colors require an **advanced monitor** (`monitor.isColor()`).

## Mini Build
If you create a **mini** variant, you can:
- Keep only `core.lua:addObject`, rendering, and `:start()` loop.
- Remove object-object collisions from `physics.lua`.
- Remove `ui.lua` entirely and set `plugins=false` in `start()`.

## License
MIT-like. Use freely.
