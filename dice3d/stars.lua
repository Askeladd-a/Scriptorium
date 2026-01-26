-- simulation
--  simulates the behaviour of stars in a box
--  stars are set of points rigidly connected together
--  stars bounce when they hit a face of their box
--  stars bounce off each other as if they were spheres
require"vector"

box={ timeleft=0 }
-- global damping to reduce lingering oscillations (linear and angular)
box.linear_damping = 0.18
box.angular_damping = 0.18
-- positional correction parameters and safety
box.pos_slop = 0.01     -- small penetration ignored
box.pos_percent = 0.2   -- positional correction strength
box.max_steps = 5       -- max physics sub-steps per frame (spiral-of-death clamp)
box.dv_max = 50         -- clamp for delta-velocity applied by impulses
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
          body.radius = r
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
            -- perform standard instantaneous collision resolution
            local normal = diff * (1/dist)
            -- relative velocity along normal
            local rel = (b.velocity - a.velocity)..normal
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
                -- mark collision for debug
                a._last_collision = {other=B.idx}
                b._last_collision = {other=A.idx}
                -- positional correction to avoid sinking (slop + percent)
                local slop = self.pos_slop or 0.01
                local percent = self.pos_percent or 0.2
                local penetration = minDist - dist
                if penetration > slop and denom > 0 then
                  local correction = normal * ((penetration - slop) * (percent / denom))
                  a.position = a.position - correction * invMassA
                  b.position = b.position + correction * invMassB
                end
              end
            end
          end
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
star={position=vector{}, velocity=vector{}, angular=vector{}, mass=0, theta=0, orientation=rotation.precalculate{1,0,0,0}}
function star:set(pos,vel,ang,m,th)
  self.position=vector(pos) or self.position
  self.velocity=vector(vel) or self.velocity
  self.angular=vector(ang) or self.angular
  self.mass=m or self.mass
  -- cache inverse mass for fast access; mass==0 -> invMass = 0 (infinite mass/static)
  self.invMass = (self.mass ~= 0) and (1 / self.mass) or 0
  self.theta=th or self.theta
  if not self.orientation then
    self.orientation = rotation.precalculate{1,0,0,0}
  end
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
  if self.orientation then
    self.orientation = r ^ self.orientation
  end
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
