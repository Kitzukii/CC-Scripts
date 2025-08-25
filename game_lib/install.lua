local baseURL = 
    "https://raw.githubusercontent.com/Kitzukii/CC-Scripts/main/game_lib/default_engine/"
local files = {
    "core.lua",
    "physics.lua",
    "ui.lua",
    -- "docs.md"
    -- Don't really need the docs. Just check the Github.
}

local pluginDir = "plugins"
local plugins = {
    "example.lua"
}

local httpGet = http.get
local fsExists = fs.exists
local fsMakeDir = fs.makeDir
local fsOpen = fs.open

local function downloadFile(path, dest)
    print(("Downloading %s → %s"):format(path, dest))
    local res, err = httpGet(baseURL .. path)
    if not res then
        print("  Error downloading:", err)
        return false
    end
    local data = res.readAll()
    res.close()

    local f = fsOpen(dest, "w")
    f.write(data)
    f.close()
    return true
end

local function ensureDir(d)
    if not fsExists(d) then
        fsMakeDir(d)
    end
end

print("Installing default_engine...")

ensureDir("lib_engine")
ensureDir(fs.combine("lib_engine", pluginDir))

-- Download core files
for _, fname in ipairs(files) do
    local dest = fs.combine("lib_engine", fname)
    downloadFile(fname, dest)
end

-- Download plugins
for _, pf in ipairs(plugins) do
    local dest = fs.combine("lib_engine", pluginDir, pf)
    downloadFile(fs.combine(pluginDir, pf), dest)
end

print("Installation completed successfully!")
print("To use it:")
print("  local engine = require('lib_engine.core')")
print("  local scr = engine.newScreen('monitor_name')")