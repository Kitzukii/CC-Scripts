## Using plugins
Just add it to ccgame/plugins, example on making your own here:

```lua
local plugin = {}

function plugin.setup(screen)
    -- example events:
    --   object_added, object_removed
    --   pre_update, post_update
    --   pre_render, post_render
    --   touch (side, x, y)
    --   resized
    screen.events:on("touch", function(side, x, y)
        -- code
    end)


    -- example on a function
    function screen:plugin()
        -- code
    end
end

-- basically returning:
-- {setup=function() end}
return plugin
```