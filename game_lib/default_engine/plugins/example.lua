-- plugins/example.lua
-- Example plugin that adds a pulsing character to all "point" objects every 0.5s
-- and a handy "makeBouncy" helper.

local plugin = {}

function plugin.setup(screen)
  local last = 0
  screen.events:on("post_update", function(scr, dt)
    last = last + dt
    if last >= 0.5 then
      last = 0
      for _, id in ipairs(scr.drawOrder) do
        local o = scr.objects[id]
        if o and o.shape == "point" then
          o.char = (o.char == "o") and "O" or "o"
        end
      end
    end
  end)

  -- public helper
  function screen:makeBouncy(obj, amount)
    if type(obj) == "number" then obj = self.objects[obj] end
    if obj then obj.restitution = amount or 0.6 end
  end
end

return plugin
