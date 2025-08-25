-- physics.lua
-- Simple 2D physics for CC:T monitors with AABB collisions.
-- Integrates velocity, gravity, world-bounds & object-object collisions.

local physics = {}

local function aabb(o)
  local w, h = 1, 1
  if o.shape == "box" then
    w, h = (o.size.w or 1), (o.size.h or 1)
  elseif o.shape == "line" then
    w, h = (o.size.length or 1), 1
  end
  return {x=o.x, y=o.y, w=w, h=h}
end

local function intersect(A, B)
  return not (A.x + A.w <= B.x or B.x + B.w <= A.x or A.y + A.h <= B.y or B.y + B.h <= A.y)
end

local function resolve_static(A, B)
  -- minimal translation vector for A to separate from B
  local ax2, ay2 = A.x + A.w, A.y + A.h
  local bx2, by2 = B.x + B.w, B.y + B.h
  local dx1 = bx2 - A.x  -- push A right
  local dx2 = ax2 - B.x  -- push A left
  local dy1 = by2 - A.y  -- push A down
  local dy2 = ay2 - B.y  -- push A up
  local mvx, mvy, m = 0, 0, math.huge

  if dx1 >= 0 and dx1 < m then m, mvx, mvy = dx1,  dx1, 0 end
  if dx2 >= 0 and dx2 < m then m, mvx, mvy = dx2, -dx2, 0 end
  if dy1 >= 0 and dy1 < m then m, mvx, mvy = dy1, 0,  dy1 end
  if dy2 >= 0 and dy2 < m then m, mvx, mvy = dy2, 0, -dy2 end
  return mvx, mvy
end

local function apply_gravity(scr, o)
  if o.physType == "normal" then
    local g = (o.weight == "auto" and 1 or (type(o.weight)=="number" and o.weight or 1))
    o.vx = o.vx + scr.gravity[1] * g
    o.vy = o.vy + scr.gravity[2] * g
  elseif o.physType == "custom" then
    o.vx = o.vx + (o.gravity_vector[1] or 0)
    o.vy = o.vy + (o.gravity_vector[2] or 0)
  end
end

local function collide_bounds(scr, o)
  local W, H = scr.worldBounds.w, scr.worldBounds.h
  local aw, ah = 1, 1
  if o.shape == "box" then aw, ah = (o.size.w or 1), (o.size.h or 1)
  elseif o.shape == "line" then aw, ah = (o.size.length or 1), 1 end

  if not o.collides then
    o.x = math.max(1, math.min(W, o.x))
    o.y = math.max(1, math.min(H, o.y))
    return
  end

  if o.x < 1 then o.x = 1; if o.vx < 0 then o.vx = -o.vx * o.restitution end end
  if o.y < 1 then o.y = 1; if o.vy < 0 then o.vy = -o.vy * o.restitution end end
  if o.x + aw - 1 > W then o.x = W - aw + 1; if o.vx > 0 then o.vx = -o.vx * o.restitution end end
  if o.y + ah - 1 > H then o.y = H - ah + 1; if o.vy > 0 then o.vy = -o.vy * o.restitution end end
end

function physics.step(scr, dt)
  -- integrate + world bounds
  for _, id in ipairs(scr.drawOrder) do
    local o = scr.objects[id]
    if o then
      apply_gravity(scr, o)
      o.x = o.x + o.vx * dt * 20   -- scale to ticks (so 1 vx ~ 1 cell per tick if dt=0.05)
      o.y = o.y + o.vy * dt * 20
      collide_bounds(scr, o)
    end
  end

  -- object-object collisions (AABB)
  local ids = scr.drawOrder
  for i=1,#ids do
    local a = scr.objects[ids[i]]
    if a and a.collides then
      local A = aabb(a)
      for j=i+1,#ids do
        local b = scr.objects[ids[j]]
        if b and b.collides then
          local B = aabb(b)
          if intersect(A, B) then
            local mvx, mvy = resolve_static(A, B)
            -- push apart proportional to half each
            a.x = a.x - mvx/2; a.y = a.y - mvy/2
            b.x = b.x + mvx/2; b.y = b.y + mvy/2

            -- simple velocity response (swap / bounce along axis of greater penetration)
            if math.abs(mvx) > math.abs(mvy) then
              local avx, bvx = a.vx, b.vx
              a.vx = -bvx * a.restitution
              b.vx = -avx * b.restitution
            else
              local avy, bvy = a.vy, b.vy
              a.vy = -bvy * a.restitution
              b.vy = -avy * b.restitution
            end
          end
        end
      end
    end
  end
end

return physics
