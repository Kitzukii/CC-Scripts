local baseURL = 
    "https://raw.githubusercontent.com/Kitzukii/CC-Scripts/main/ccgame/engine/"
local files = {
    "core.lua",
    "physics.lua",
    "ui.lua"
}

local pluginDir = "plugins"
local plugins = {
    -- "example.lua"
    -- Just here to help me remember how to add a default plugin.
}

local httpGet = http.get
local fsExists = fs.exists
local fsMakeDir = fs.makeDir
local fsOpen = fs.open

term.setTextColor(colors.green)

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

print("Installing CCGame.")

ensureDir("ccgame")
ensureDir(fs.combine("ccgame", pluginDir))

-- Download core files
for _, fname in ipairs(files) do
    local dest = fs.combine("ccgame", fname)
    downloadFile(fname, dest)
end

-- Download plugins
for _, pf in ipairs(plugins) do
    local dest = fs.combine("ccgame", pluginDir, pf)
    downloadFile(fs.combine(pluginDir, pf), dest)
end

term.setTextColor(colors.white)
print("Installation completed successfully!")
print("To use it:")
print("  local engine = require('ccgame.core')")
print("  local scr = engine.newScreen('monitor_name')")