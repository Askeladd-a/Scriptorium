-- Legacy custom physics engine for dice.
-- Used for motion/collisions; tuned to reduce swapping and penetration.
-- simulation
--  simulates the behaviour of stars in a box
--  stars are set of points rigidly connected together
--  stars bounce when they hit a face of their box
--  stars bounce off each other as if they were spheres
require"vector"
local obb = require "obb"

box={ timeleft=0 }
-- global damping to reduce lingering oscillations (linear and angular)
box.linear_damping = 0.18
box.angular_damping = 0.18
-- sleeping thresholds to eliminate jitter when bodies come to rest
box.sleep_linear_threshold = 0.01
box.sleep_angular_threshold = 0.01
box.sleep_steps = 12
-- positional correction parameters and safety
box.pos_slop = 0.002     -- small penetration allowance to avoid jitter
box.pos_percent = 0.7   -- stronger positional correction to reduce interpenetration
box.max_steps = 12      -- più sub-steps per frame
box.dv_max = 50         -- clamp for delta-velocity applied by impulses
box.collision_iterations = 8
box.warm_start = true
box.bias_slop = 0.002
box.bias_factor = 0.35
-- buffered logging to reduce I/O churn; lines are flushed once per update
box.log_buffer = {}
function box:set(x,y,z,gravity,bounce,friction,dt) 
  self.x,self.y,self.z=x or self.x, y or self.y, z or self.z
  self.gravity=gravity or self.gravity
  self.bounce=bounce or self.bounce
  self.friction=friction or self.friction
  -- ensure a sensible default timestep if not provided
  self.dt=dt or self.dt or (1/60)
  return self
end

function box:update(dt)
  self.timeleft = self.timeleft + dt
  local maxSteps = self.max_steps or 5
  local steps = 0
  self.last_impulses = self.last_impulses or {}
  while (self.timeleft > self.dt) and (steps < maxSteps) do
    -- precompute gravity vector to avoid per-body allocations
    local gravity_vec = vector{0,0,-(self.gravity or 0) * self.dt}
    for i=1,#self do
      local s=self[i]
      -- apply gravity as acceleration (independent of mass)
      s.velocity = s.velocity + gravity_vec
      s:update(self.dt)
        -- pass global bounce/friction but allow per-star override inside star:wall
        s:box(-self.x,-self.y,0,self.x,self.y,self.z,self.bounce,self.friction)
        -- apply damping: prefer per-star damping if present, else fall back to global
        local ld = (s.linear_damping ~= nil) and s.linear_damping or self.linear_damping or 0
        local ad = (s.angular_damping ~= nil) and s.angular_damping or self.angular_damping or 0
        if ld and ld > 0 then
          local vf = 1 - math.min(0.99, ld * self.dt)
          s.velocity = s.velocity * vf
        end
        if ad and ad > 0 then
          local af = 1 - math.min(0.99, ad * self.dt)
          s.angular = s.angular * af
        end
      if math.abs(s.angular[3])<0.1 then s.angular[3]=0 end
      -- sleep threshold: stop micro-jitter once velocities stay below thresholds
      local lin = s.velocity:abs()
      local ang = s.angular:abs()
      local lin_th = s.sleep_linear_threshold or self.sleep_linear_threshold or 0
      local ang_th = s.sleep_angular_threshold or self.sleep_angular_threshold or 0
      local steps_th = s.sleep_steps or self.sleep_steps or 0
      if lin <= lin_th and ang <= ang_th then
        s._sleep_frames = (s._sleep_frames or 0) + 1
        if steps_th > 0 and s._sleep_frames >= steps_th then
          s.velocity = vector{0,0,0}
          s.angular = vector{0,0,0}
          s._sleep_frames = steps_th
        end
      else
        s._sleep_frames = 0
      end
    end
    -- broadphase: sweep-and-prune on X axis to reduce candidate pairs
    local n = #self
    if n > 1 then
      local intervals = {}
      for i=1,n do
        local body = self[i]
        -- ensure radius cached
        if not body.radius then
          local r = 0
          if #body == 8 then
            -- cubo: raggio = distanza dal centro a una faccia meno epsilon
            for k=1,#body do
              local v = body[k]
              r = math.max(r, math.abs(v[1]), math.abs(v[2]), math.abs(v[3]))
            end
            r = r - 0.05 * r -- epsilon: 5% in meno per garantire contatto visivo
          else
            -- altri solidi: raggio = distanza dal centro al vertice più lontano
            for k=1,#body do r = math.max(r, vector(body[k] or {0,0,0}):abs()) end
          end
          body.radius = r
        end
        local minx = body.position[1] - body.radius
        local maxx = body.position[1] + body.radius
        intervals[i] = {minx = minx, maxx = maxx, idx = i}
      end
      table.sort(intervals, function(a,b) return a.minx < b.minx end)

      local next_impulses = {}
      for iter=1,(self.collision_iterations or 1) do
        -- sweep
        for ii=1,n do
          local A = intervals[ii]
          local a = self[A.idx]
          for jj = ii+1, n do
            local B = intervals[jj]
            if B.minx > A.maxx then break end -- no overlap on x -> skip remaining
            local b = self[B.idx]
            -- quick AABB overlap on Y and Z to filter more
            local aymin, aymax = a.position[2] - a.radius, a.position[2] + a.radius
            local bymin, bymax = b.position[2] - b.radius, b.position[2] + b.radius
            if aymax < bymin or bymax < aymin then goto continue_pair end
            local azmin, azmax = a.position[3] - a.radius, a.position[3] + a.radius
            local bzmin, bzmax = b.position[3] - b.radius, b.position[3] + b.radius
            if azmax < bzmin or bzmax < azmin then goto continue_pair end

            -- OBB-OBB collision check (dadi ruotati)
            if #a == 8 and #b == 8 and obb.intersect then
              -- calcola i vertici in world space
              local a_verts, b_verts = {}, {}
              for k=1,8 do
                local va = a[k] + a.position
                local vb = b[k] + b.position
                a_verts[k] = {va[1], va[2], va[3]}
                b_verts[k] = {vb[1], vb[2], vb[3]}
              end
              local hit, normal, depth = obb.intersect(a_verts, b_verts)
              if hit and normal and depth and depth > 1e-6 then
                -- punto di contatto: centro-centro (più stabile)
                local contact = (a.position + b.position) * 0.5
                local ra = contact - a.position
                local rb = contact - b.position
                local invMassA = (a.mass ~= 0) and (1 / a.mass) or 0
                local invMassB = (b.mass ~= 0) and (1 / b.mass) or 0
                local denom = invMassA + invMassB
                if denom > 0 then
                  local key = A.idx < B.idx and (A.idx .. ":" .. B.idx) or (B.idx .. ":" .. A.idx)
                  if self.warm_start and self.last_impulses[key] then
                    local cached = self.last_impulses[key]
                    local warm = vector(cached.normal) * cached.j
                    a:push(-warm, ra)
                    b:push(warm, rb)
                  end
                  -- correzione di posizione (soft)
                  local percent = self.pos_percent or 0.4
                  local correction = {normal[1]*depth*percent/denom, normal[2]*depth*percent/denom, normal[3]*depth*percent/denom}
                  a.position = a.position - vector(correction) * invMassA
                  b.position = b.position + vector(correction) * invMassB
                  -- impulso di collisione nel punto di contatto (con rotazione)
                  local n = vector(normal)
                  local va = a.velocity + a.angular ^ ra
                  local vb = b.velocity + b.angular ^ rb
                  local relv = (vb - va)..n
                  local bias = 0
                  local bias_slop = self.bias_slop or 0
                  if depth > bias_slop then
                    bias = (depth - bias_slop) * (self.bias_factor or 0) / math.max(self.dt, 1e-6)
                  end
                  local e = math.min(self.bounce or 0.4, 0.9)
                  local j = (-(1+e) * relv + bias) / denom
                  -- limita la magnitudine dell'impulso per evitare esplosioni
                  local maxImpulse = 10
                  if j > maxImpulse then j = maxImpulse end
                  if j < -maxImpulse then j = -maxImpulse end
                  local impulse = n * j
                  a:push(-impulse, ra)
                  b:push(impulse, rb)
                  a._last_collision = {other=B.idx}
                  b._last_collision = {other=A.idx}
                  next_impulses[key] = { j = j, normal = {n[1], n[2], n[3]} }
                end
              end
            end
            ::continue_pair::
          end
        end
      end
      self.last_impulses = next_impulses
    end
    self.timeleft = self.timeleft - self.dt
    steps = steps + 1
  end
  if steps == maxSteps then
    -- drop remaining accumulated time to avoid spiral-of-death
    self.timeleft = 0
  end
  -- flush buffered logs if any
  if self.log_buffer and #self.log_buffer > 0 then
    local fh = io.open("physics_log.txt","a")
    if fh then
      for _,line in ipairs(self.log_buffer) do fh:write(line) end
      fh:close()
    end
    table.clear(self.log_buffer)
  end
end
star={position=vector{}, velocity=vector{}, angular=vector{}, mass=0, theta=0}
function star:set(pos,vel,ang,m,th)
  self.position=vector(pos) or self.position
  self.velocity=vector(vel) or self.velocity
  self.angular=vector(ang) or self.angular
  self.mass=m or self.mass
  -- cache inverse mass for fast access; mass==0 -> invMass = 0 (infinite mass/static)
  self.invMass = (self.mass ~= 0) and (1 / self.mass) or 0
  self.theta=th or self.theta
  -- compute radius cache
  local r = 0
  for k=1,#self do r = math.max(r, vector(self[k] or {0,0,0}):abs()) end
  self.radius = r
  return self
end

function star:effect(impulse, displacement)
  -- safe effect: avoid division by zero for mass/theta
  local dv = vector{0,0,0}
  local da = vector{0,0,0}
  if (self.mass or 0) ~= 0 then
    dv = vector(impulse) / self.mass
  end
  if (self.theta or 0) ~= 0 and displacement then
    da = (displacement ^ impulse) / self.theta
  end
  return dv, da
end

function star:push(impulse, displacement)
  local dv, da = self:effect(impulse, displacement)
  -- defensive clamp: avoid applying extreme delta-velocities that destabilize simulation
  local dv_mag = dv:abs()
  local dv_max = (self.dv_max or box.dv_max or 50)
  if dv_mag > dv_max then
    -- log anomaly to file for diagnosis (use high-resolution time if available)
    local t = (love and love.timer and love.timer.getTime()) or os.time()
    local fh = io.open("physics_log.txt","a")
    if fh then
      fh:write(string.format("[ANOMALY] time=%.3f star:push clamped dv=%.3f -> %.3f pos=(%.3f,%.3f,%.3f)\n", t, dv_mag, dv_max, self.position[1], self.position[2], self.position[3]))
      fh:close()
    else
      print("[ANOMALY] could not open physics_log.txt to write anomaly")
    end
    dv = dv * (dv_max / dv_mag)
  end
  self.velocity = self.velocity + dv
  self.angular = self.angular + da
end

function star:update(dt)
  self.position=self.position+self.velocity*dt
  local r=rotation():set(self.angular:abs()*dt, self.angular:norm())
  for i=1,#self do self[i]=r(self[i]) end
end


--bounce off a wall
function star:wall(index, normal, restitution, friction)
  --frictionless bounce
  local d = self[index]
  -- allow per-star override of restitution/friction
  local e = (self.restitution ~= nil) and self.restitution or restitution
  local f = (self.friction ~= nil) and self.friction or friction

  local s = normal..(self.angular^d + self.velocity)
  local cv,ca = self:effect(normal,d)

  local cs = ca^d + cv -- change in contact point speed with unit constraint
  local constraint = (1 + e) * s / (cs..normal)
  -- friction simulation in steps
  local steps = 11
  local impulse = -constraint * normal / steps
  local abs = impulse:abs()
  for i=1,steps do
    self:push(impulse,d)
    -- here comes the friction (use per-star or passed friction)
    local s = self.angular^d + self.velocity
    s = (s - (normal..s) * normal)
    self:push(s:norm() * f * (-abs), d)
  end
  -- mark last wall hit for debug
  self._last_wall = {index=index, normal=normal}
end

--bounce inside two parallel infinite walls
function star:parallel(normal, min, max, restitution, friction)
  local lowest, highest = nil,nil
  local lowesta, highesta = min,max
  for i=1,#self do
    local a=(self[i]+self.position)..normal
    if a<=lowesta then
      lowest=i 
      lowesta=a
    end
    if a>=highesta then 
      highest=i 
      highesta=a
    end
  end
  
  if lowest then
    self:wall(lowest,normal,restitution,friction)
    self.position=self.position+normal*(min-lowesta)
  end
  if highest then
    self:wall(highest,-normal,restitution,friction)
    self.position=self.position+normal*(max-highesta)
  end
  
end

--bounce inside a box
function star:box(x1,y1,z1,x2,y2,z2,restitution,friction)
  self:parallel(vector{0,0,1},z1,z2,restitution, friction)
  self:parallel(vector{1,0,0},x1,x2,restitution, friction)
  self:parallel(vector{0,1,0},y1,y2,restitution, friction)
end

-- Return the world table for external use (runner expects a table)
return box
