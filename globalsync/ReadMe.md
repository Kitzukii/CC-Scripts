# GlobalSync API (CC:Tweaked)

A lightweight API for syncing global variables between multiple **CC:Tweaked** computers over **WIRED MODEMS**.

## Features
- **Persistent Variables** – Automatically saved in `/persistent_variables/globals.data`
- **Namespace Support** – Store values like `Game.Settings.Volume`
- **Bi-Directional Sync** – Server and clients can both update values
- **Event Driven** – Integrates into your main loop using `os.pullEvent()`
- **Automatic Sync on Startup** – Clients always request the latest values immediately

---

## Notes

All computers must use the same channel (CHANNEL_MAIN = 1 by default).
Works only with wired modems.
Multiple clients supported simultaneously.

---

## Installation
1. Save `globalsync.lua` in the same directory as your scripts.
2. Ensure all computers are connected via **wired modem**.
3. Require and initialize in your Lua program.

---

## Usage

### Server
```lua
local GlobalSync = require("globalsync")
GlobalSync.init(true) -- Start in server mode

-- Example variable
GlobalSync.set("Player.health", 100)

while true do
    local e, p1, p2, p3, p4, p5 = os.pullEvent()
    GlobalSync.handleEvent(e, p1, p2, p3, p4, p5)
end
```

### Client
```lua
local GlobalSync = require("globalsync")
GlobalSync.init(false) -- client mode

-- React to updates
GlobalSync.onUpdate(function(key, value)
    print("Updated:", key, "=", value)
end)

while true do
    local e, p1, p2, p3, p4, p5 = os.pullEvent()
    GlobalSync.handleEvent(e, p1, p2, p3, p4, p5)
end
```

## All functions

`GlobalSync.init(isServer)`
isServer = `true` for server, `false` for client.

---

`GlobalSync.set(key, value)`
Sets a variable and syncs it across the network.
Supports namespaces
```lua
GlobalSync.set("A.B", 80)
```
---
`GlobalSync.get(key)`
Retrieves a variable
```lua
GlobalSync.get("Player.health")
```
---
`GlobalSync.onUpdate(callback)`
Registers a function to run whenever a variable changes
```lua
GlobalSync.onUpdate(function(key, value)
    print(key .. " updated to " .. tostring(value))
end)
```
---
`GlobalSync.handleEvent(...)`
Handles incoming modem messages.
Call inside your event loop.

## Data Persistence

All variables are saved to /persistent_variables/globals.data on the server.
Data automatically loads when the server restarts.