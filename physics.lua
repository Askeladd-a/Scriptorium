-- physics.lua
-- Consolidated from: stars.lua + materials.lua
-- Rigid body simulation and material presets

require"core"

--------------------------------------------------------------------------------
-- MATERIALS
--------------------------------------------------------------------------------
materials = {}

materials.presets = {
  wood = {
    mass = 1.2,
    restitution = 0.25,
    friction = 0.75,
    linear_damping = 0.06,
    angular_damping = 0.08,
    color = {0.55, 0.35, 0.18}, -- darker brown
  },
  metal = {
    mass = 1.5,
    restitution = 0.12,
    friction = 0.35,
    linear_damping = 0.02,
    angular_damping = 0.03,
    color = {0.66, 0.68, 0.70}, -- cool metal gray
  },
  rubber = {
    mass = 1.5,
    restitution = 0.15,
    friction = 1.0,
    linear_damping = 0.12,
    angular_damping = 0.12,
    color = {0.08, 0.08, 0.10}, -- near-black (rubber)
  },
  bone = {
    mass = 1.3,
    restitution = 0.22,
    friction = 0.72,
    linear_damping = 0.05,
    angular_damping = 0.06,
    color = {0.97, 0.94, 0.86}, -- warm bone
  }
}

-- Apply preset properties to a star-like object (mutates star)
function materials.apply(star, preset)
  if not star or not preset then return end
  if preset.mass       then star.mass = preset.mass; star.invMass = (preset.mass ~= 0) and (1 / preset.mass) or 0 end
  if preset.restitution then star.restitution = preset.restitution end
  if preset.friction    then star.friction = preset.friction end
  if preset.linear_damping then star.linear_damping = preset.linear_damping end
  if preset.angular_damping then star.angular_damping = preset.angular_damping end
  -- tag
  star.material = preset
  return star
end

function materials.get(name)
  return materials.presets[name]
end

--------------------------------------------------------------------------------
-- SIMULATION (stars in a box)
--------------------------------------------------------------------------------
-- simulates the behaviour of stars in a box
-- stars are set of points rigidly connected together
-- stars bounce when they hit a face of their box
-- stars bounce off each other as if they were spheres

box={ timeleft=0 }
-- global damping to reduce lingering oscillations (linear and angular)
box.linear_damping = 0.18
box.angular_damping = 0.18
-- positional correction parameters and safety
box.pos_slop = 0.05     -- INCREASED: ignores penetrations to prevent jitter on multi-tile contacts
box.pos_percent = 0.08  -- REDUCED: correction strength (0-1, lower = less aggressive)
box.max_steps = 5       -- max physics sub-steps per frame (spiral-of-death clamp)
box.dv_max = 50         -- clamp for delta-velocity applied by impulses
-- sleep detection (from manual: prevents jitter)
box.sleep_linear = 0.08   -- velocity threshold for sleeping (REDUCED: very permissive, sleeps easily)
box.sleep_angular = 0.12  -- angular velocity threshold (REDUCED: almost any rotation can sleep)
box.sleep_time = 0.2      -- time below threshold before sleeping (REDUCED: sleeps very quickly)
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
  while (self.timeleft > self.dt) and (steps < maxSteps) do
    -- precompute gravity vector to avoid per-body allocations
    local gravity_vec = vector{0,0,-(self.gravity or 0) * self.dt}
    for i=1,#self do
      local s=self[i]
      
      -- Skip physics for sleeping bodies (from manual)
      if not s.asleep then
        -- CRITICAL: Count vertices touching ground to determine stability
        local vertices_on_ground = 0
        local ground_z = 0.08  -- tighter tolerance for vertex-on-ground detection
        for k=1,#s do
          local vertex_world_z = s[k][3] + s.position[3]
          if vertex_world_z <= ground_z then
            vertices_on_ground = vertices_on_ground + 1
          end
        end
        
        -- Lock only if 4+ vertices touch ground (stable face resting) AND almost no movement
        local v_mag = s.velocity:abs()
        local w_mag = s.angular:abs()
        if vertices_on_ground >= 4 and v_mag < 0.2 and w_mag < 0.15 then
          -- Dice is stable and resting: LOCK completely
          s.velocity = vector{0,0,0}
          s.angular = vector{0,0,0}
          s.asleep = true
          s.sleep_timer = 999
        else
          -- Normal physics for airborne or moving bodies
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
        end
      else
        -- Force zero when asleep (prevent micro-drift)
        s.velocity = vector{0,0,0}
        s.angular = vector{0,0,0}
      end
      
      -- Sleep detection with timer (from manual: prevents jitter)
      local v_mag = s.velocity:abs()
      local w_mag = s.angular:abs()
      local sleep_thresh_v = self.sleep_linear or 0.05
      local sleep_thresh_w = self.sleep_angular or 0.15
      local sleep_time = self.sleep_time or 0.4
      local near_ground = s.position[3] < 1.2
      
      if v_mag < sleep_thresh_v and w_mag < sleep_thresh_w and near_ground then
        s.sleep_timer = (s.sleep_timer or 0) + self.dt
        if s.sleep_timer >= sleep_time and not s.asleep then
          s.asleep = true
          s.velocity = vector{0,0,0}
          s.angular = vector{0,0,0}
          s.wall_hits = 0
        end
      else
        s.sleep_timer = 0
        s.asleep = false
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
          for k=1,#body do r = math.max(r, vector(body[k] or {0,0,0}):abs()) end
          body.radius = r * 0.75  -- 75%: better coverage for cubic dice
        end
        local minx = body.position[1] - body.radius
        local maxx = body.position[1] + body.radius
        intervals[i] = {minx = minx, maxx = maxx, idx = i}
      end
      table.sort(intervals, function(a,b) return a.minx < b.minx end)

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

          -- precise sphere check
          local diff = b.position - a.position
          local dist = diff:abs()
          local minDist = a.radius + b.radius
          if dist > 0 and dist < minDist then
            -- CRITICAL: Skip collision if BOTH bodies are asleep (prevents jitter wake-up loop)
            if a.asleep and b.asleep then
              goto continue_pair  -- don't process this collision
            end
            
            -- perform standard instantaneous collision resolution
            local normal = diff * (1/dist)
            -- relative velocity along normal
            local rel = (b.velocity - a.velocity)..normal
            
            -- Wake sleeping bodies on collision (only if at least one awake)
            if a.asleep then a.asleep = false a.sleep_timer = 0 end
            if b.asleep then b.asleep = false b.sleep_timer = 0 end
            
            -- Only resolve if objects are approaching (prevents redundant impulses)
            if rel < -0.001 then
              local e = math.min(self.bounce or 0.4, 0.9)
              local invMassA = (a.mass ~= 0) and (1 / a.mass) or 0
              local invMassB = (b.mass ~= 0) and (1 / b.mass) or 0
              local denom = invMassA + invMassB
              if denom > 0 then
              -- If relative motion between the bodies over this step is large compared to size,
              -- attempt a swept-sphere CCD to compute time-of-impact and resolve at that instant.
              local dt = self.dt or 0.0166667
              local relDisp = (b.velocity - a.velocity) * dt
              local relPos0 = (b.position - a.position) - relDisp -- relative position at step start
              local a_q = relDisp..relDisp
              local b_q = 2 * (relPos0..relDisp)
              local c_q = (relPos0..relPos0) - (minDist * minDist)
              local didCCD = false
              local eps = 1e-8
              if a_q > eps then
                local disc = b_q*b_q - 4*a_q*c_q
                if disc >= 0 then
                  local sqrtD = math.sqrt(disc)
                  local ttoi = (-b_q - sqrtD) / (2 * a_q)
                  if ttoi >= 0 and ttoi <= 1 then
                    -- time of impact fraction found; move bodies to TOI, apply impulse, advance remainder
                    local prevA = a.position - a.velocity * dt
                    local prevB = b.position - b.velocity * dt
                    local posA_t = prevA + a.velocity * (ttoi * dt)
                    local posB_t = prevB + b.velocity * (ttoi * dt)
                    local contact = posB_t - posA_t
                    local dist_t = contact:abs()
                    if dist_t > eps then
                      local n = contact * (1 / dist_t)
                      -- relative normal velocity at TOI
                      local relv = (b.velocity - a.velocity)..n
                      local j = (-(1 + e) * relv) / denom
                      local impulse = n * j
                      -- rewind positions to TOI
                      a.position = posA_t
                      b.position = posB_t
                      -- apply impulses to velocities
                      a:push(-impulse)
                      b:push(impulse)
                      -- advance remainder of step with new velocities
                      local rem = (1 - ttoi) * dt
                      a.position = a.position + a.velocity * rem
                      b.position = b.position + b.velocity * rem
                      didCCD = true
                    end
                  end
                end
              end

              if not didCCD then
                -- fallback to instantaneous impulse at end of step
                local j = (-(1+e) * rel) / denom
                local impulse = normal * j
                a:push(-impulse)
                b:push(impulse)
                
                -- Tangential friction (simplified Coulomb friction)
                local rel_vel = b.velocity - a.velocity
                local tangent = rel_vel - normal * (rel_vel..normal)
                local tangent_mag = tangent:abs()
                if tangent_mag > 1e-6 then
                  local tangent_dir = tangent / tangent_mag
                  local mu = 0.3  -- friction coefficient for die-die collisions
                  local friction_impulse = tangent_dir * math.min(tangent_mag * denom, mu * math.abs(j))
                  a:push(friction_impulse)
                  b:push(-friction_impulse)
                end
                
                -- mark collision for debug
                a._last_collision = {other=B.idx}
                b._last_collision = {other=A.idx}
                
                -- positional correction to avoid sinking/interpenetration
                -- ALWAYS apply correction to prevent dice clipping through each other
                local slop = 0.01  -- smaller tolerance for tighter separation
                local percent = 0.4  -- stronger correction (was 0.08)
                local penetration = minDist - dist
                
                -- Always apply correction when penetrating
                if penetration > slop and denom > 0 then
                  local correction = normal * ((penetration - slop) * (percent / denom))
                  a.position = a.position - correction * invMassA
                  b.position = b.position + correction * invMassB
                end
              end
            end  -- close 'if denom > 0'
            end  -- close 'if rel < -0.001'
          end  -- close 'if dist > 0 and dist < minDist'
          ::continue_pair::
        end
      end
    end
    self.timeleft = self.timeleft - self.dt
    steps = steps + 1
  end
  if steps == maxSteps then
    -- drop remaining accumulated time to avoid spiral-of-death
    self.timeleft = 0
  end
  
  -- SOFT PUSHBACK: Separate ALL dice that are compenetrating (position-only, no velocity)
  -- This prevents visual clipping - works on all dice, not just asleep ones
  for i=1,#self do
    local a = self[i]
    for j=i+1,#self do
      local b = self[j]
      local diff = b.position - a.position
      local dist = diff:abs()
      local minDist = a.radius + b.radius
      if dist > 0.01 and dist < minDist then
        -- They're compenetrating; push them apart in full 3D
        local normal = diff * (1/dist)
        local penetration = minDist - dist
        -- Stronger pushback: 80% of penetration resolved immediately
        local pushback = normal * (penetration * 0.8)
        -- Split evenly (or by mass if needed)
        local invMassA = (a.mass ~= 0) and (1 / a.mass) or 0.5
        local invMassB = (b.mass ~= 0) and (1 / b.mass) or 0.5
        local total = invMassA + invMassB
        if total > 0 then
          a.position = a.position - pushback * (invMassA / total)
          b.position = b.position + pushback * (invMassB / total)
        end
      end
    end
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

--------------------------------------------------------------------------------
-- STAR (rigid body)
--------------------------------------------------------------------------------
star={position=vector{}, velocity=vector{}, angular=vector{}, mass=0, theta=0}
function star:set(pos,vel,ang,m,th)
  self.position=vector(pos) or self.position
  self.velocity=vector(vel) or self.velocity
  self.angular=vector(ang) or self.angular
  self.mass=m or self.mass
  -- cache inverse mass for fast access; mass==0 -> invMass = 0 (infinite mass/static)
  self.invMass = (self.mass ~= 0) and (1 / self.mass) or 0
  self.theta=th or self.theta
  -- compute radius cache for collision detection
  local r = 0
  for k=1,#self do r = math.max(r, vector(self[k] or {0,0,0}):abs()) end
  self.radius = r * 0.75  -- 75%: better coverage for cubic dice
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
  
  -- If asleep and contact velocity is VERY small, skip processing (prevents wake loop)
  -- Increased threshold from 0.01 to 0.05 for ultra-static contacts
  if self.asleep and math.abs(s) < 0.05 then
    return  -- Static contact - no wake, no impulse
  end
  
  -- Wake if contact velocity significant (>0.05)
  if self.asleep and math.abs(s) >= 0.05 then
    self.asleep = false
    self.sleep_timer = 0
  end
  
  local cv,ca = self:effect(normal,d)

  local cs = ca^d + cv -- change in contact point speed with unit constraint
  local constraint = (1 + e) * s / (cs..normal)
  
  -- Wall hit counter to prevent infinite bouncing
  self.wall_hits = (self.wall_hits or 0) + 1
  if self.wall_hits > 150 then
    -- Drastically dampen velocity to stop perpetual bouncing
    self.velocity = self.velocity * 0.2
    self.angular = self.angular * 0.3
    self.wall_hits = 0
  end
  
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
  
  -- CRITICAL FIX: only process if penetration is significant
  -- This prevents micro-corrections that cause jitter when multiple vertices touch
  local penetration_threshold = 0.001
  
  if lowest and (min - lowesta) > penetration_threshold then
    self:wall(lowest,normal,restitution,friction)
    if not self.asleep then
      -- Only correct position if awake (prevent jitter on sleeping bodies)
      self.position=self.position+normal*(min-lowesta)
    end
  end
  
  if highest and (highesta - max) > penetration_threshold then
    self:wall(highest,-normal,restitution,friction)
    if not self.asleep then
      -- Only correct position if awake (prevent jitter on sleeping bodies)
      self.position=self.position+normal*(max-highesta)
    end
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
