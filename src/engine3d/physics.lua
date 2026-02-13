
require"core"

materials = {}

materials.presets = {
  wood = {
    mass = 1.2,
    restitution = 0.25,
    friction = 0.75,
    linear_damping = 0.15,
    angular_damping = 0.20,
    color = {0.55, 0.35, 0.18},
  },
  rubber = {
    mass = 1.0,
    restitution = 0.35,
    friction = 0.85,
    linear_damping = 0.10,
    angular_damping = 0.15,
    color = {0.08, 0.08, 0.10},
  },
  plastic = {
    mass = 0.8,
    restitution = 0.30,
    friction = 0.70,
    linear_damping = 0.12,
    angular_damping = 0.18,
    color = {0.9, 0.2, 0.2},
  },
  metal = {
    mass = 2.0,
    restitution = 0.45,
    friction = 0.60,
    linear_damping = 0.08,
    angular_damping = 0.12,
    color = {0.66, 0.68, 0.70},
  },
  bone = {
    mass = 1.8,
    restitution = 0.30,
    friction = 0.80,
    linear_damping = 0.12,
    angular_damping = 0.18,
    color = {0.97, 0.94, 0.86},
  },
}

function materials.apply(body, preset)
  if not body or not preset then return end
  if preset.mass       then body.mass = preset.mass; body.invMass = (preset.mass ~= 0) and (1 / preset.mass) or 0 end
  if preset.restitution then body.restitution = preset.restitution end
  if preset.friction    then body.friction = preset.friction end
  if preset.linear_damping then body.linear_damping = preset.linear_damping end
  if preset.angular_damping then body.angular_damping = preset.angular_damping end
  body.material = preset
  return body
end

function materials.get(name)
  return materials.presets[name]
end


box={ timeleft=0 }
box.linear_damping = 0.18
box.angular_damping = 0.18
box.pos_slop = 0.05
box.pos_percent = 0.08
box.max_steps = 5
box.dv_max = 50
box.sleep_linear = 0.15
box.sleep_angular = 0.20
box.sleep_time = 0.08
box.log_buffer = {}
function box:set(x,y,z,gravity,bounce,friction,dt) 
  self.x,self.y,self.z=x or self.x, y or self.y, z or self.z
  self.gravity=gravity or self.gravity
  self.bounce=bounce or self.bounce
  self.friction=friction or self.friction
  self.dt=dt or self.dt or (1/60)
  return self
end

function box:update(dt)
  self.timeleft = self.timeleft + dt
  local maxSteps = self.max_steps or 5
  local steps = 0
  while (self.timeleft > self.dt) and (steps < maxSteps) do
    local gravity_vec = vector{0,0,-(self.gravity or 0) * self.dt}
    for i=1,#self do
      local s=self[i]
      
      if not s.asleep then
        local vertices_on_ground = 0
        local ground_z = 0.05
        local ground_vertices_z = {}
        for k=1,#s do
          local vertex_world_z = s[k][3] + s.position[3]
          if vertex_world_z <= ground_z then
            vertices_on_ground = vertices_on_ground + 1
            table.insert(ground_vertices_z, vertex_world_z)
          end
        end
        
        local is_flat = false
        if vertices_on_ground >= 4 and #ground_vertices_z >= 4 then
          local z_min = math.huge
          local z_max = -math.huge
          for _, z in ipairs(ground_vertices_z) do
            z_min = math.min(z_min, z)
            z_max = math.max(z_max, z)
          end
          is_flat = (z_max - z_min) < 0.03
        end
        
        local v_mag = s.velocity:abs()
        local w_mag = s.angular:abs()
        if is_flat and v_mag < 0.20 and w_mag < 0.15 then
          s.velocity = vector{0,0,0}
          s.angular = vector{0,0,0}
          s.asleep = true
          s.sleep_timer = 999
        else
          s.velocity = s.velocity + gravity_vec
          s:update(self.dt)
          s:box(-self.x,-self.y,0,self.x,self.y,self.z,self.bounce,self.friction)
          
          local border_height = self.border_height or 1.5
          local rim_margin = 0.3
          local rim_z_min = border_height * 0.3
          local rim_z_max = border_height + 0.5
          
          local pos = s.position
          local near_x_edge = math.abs(pos[1]) > (self.x - rim_margin)
          local near_y_edge = math.abs(pos[2]) > (self.y - rim_margin)
          local in_rim_zone = pos[3] > rim_z_min and pos[3] < rim_z_max
          
          if in_rim_zone and (near_x_edge or near_y_edge) then
            local push_strength = 2.0 * self.dt
            if near_x_edge then
              local dir = pos[1] > 0 and -1 or 1
              s.velocity[1] = s.velocity[1] + dir * push_strength
            end
            if near_y_edge then
              local dir = pos[2] > 0 and -1 or 1
              s.velocity[2] = s.velocity[2] + dir * push_strength
            end
            s.velocity[3] = s.velocity[3] - push_strength * 0.5
            s.asleep = false
            s.sleep_timer = 0
          end
          
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
        s.velocity = vector{0,0,0}
        s.angular = vector{0,0,0}
      end
      
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
    
    local n = #self
    if n > 1 then
      local intervals = {}
      for i=1,n do
        local body = self[i]
        if not body.radius then
          local r = 0
          for k=1,#body do r = math.max(r, vector(body[k] or {0,0,0}):abs()) end
          body.radius = r * 0.75
        end
        local minx = body.position[1] - body.radius
        local maxx = body.position[1] + body.radius
        intervals[i] = {minx = minx, maxx = maxx, idx = i}
      end
      table.sort(intervals, function(a,b) return a.minx < b.minx end)

      for ii=1,n do
        local A = intervals[ii]
        local a = self[A.idx]
        for jj = ii+1, n do
          local B = intervals[jj]
          if B.minx > A.maxx then break end
          local b = self[B.idx]
          local aymin, aymax = a.position[2] - a.radius, a.position[2] + a.radius
          local bymin, bymax = b.position[2] - b.radius, b.position[2] + b.radius
          if aymax < bymin or bymax < aymin then goto continue_pair end
          local azmin, azmax = a.position[3] - a.radius, a.position[3] + a.radius
          local bzmin, bzmax = b.position[3] - b.radius, b.position[3] + b.radius
          if azmax < bzmin or bzmax < azmin then goto continue_pair end

          local diff = b.position - a.position
          local dist = diff:abs()
          local minDist = a.radius + b.radius
          if dist > 0 and dist < minDist then
            if a.asleep and b.asleep then
              goto continue_pair
            end
            
            local normal = diff * (1/dist)
            local rel = (b.velocity - a.velocity)..normal
            
            if a.asleep then a.asleep = false a.sleep_timer = 0 end
            if b.asleep then b.asleep = false b.sleep_timer = 0 end
            
            if rel < -0.001 then
              local e = math.min(self.bounce or 0.4, 0.9)
              local invMassA = (a.mass ~= 0) and (1 / a.mass) or 0
              local invMassB = (b.mass ~= 0) and (1 / b.mass) or 0
              local denom = invMassA + invMassB
              if denom > 0 then
              local step_dt = self.dt or 0.0166667
              local relDisp = (b.velocity - a.velocity) * step_dt
              local relPos0 = (b.position - a.position) - relDisp
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
                    local prevA = a.position - a.velocity * step_dt
                    local prevB = b.position - b.velocity * step_dt
                    local posA_t = prevA + a.velocity * (ttoi * step_dt)
                    local posB_t = prevB + b.velocity * (ttoi * step_dt)
                    local contact = posB_t - posA_t
                    local dist_t = contact:abs()
                    if dist_t > eps then
                      local normal_toi = contact * (1 / dist_t)
                      local relv = (b.velocity - a.velocity)..normal_toi
                      local j = (-(1 + e) * relv) / denom
                      local impulse = normal_toi * j
                      a.position = posA_t
                      b.position = posB_t
                      a:push(-impulse)
                      b:push(impulse)
                      local rem = (1 - ttoi) * step_dt
                      a.position = a.position + a.velocity * rem
                      b.position = b.position + b.velocity * rem
                      didCCD = true
                    end
                  end
                end
              end

              if not didCCD then
                local j = (-(1+e) * rel) / denom
                local impulse = normal * j
                a:push(-impulse)
                b:push(impulse)
                
                local rel_vel = b.velocity - a.velocity
                local tangent = rel_vel - normal * (rel_vel..normal)
                local tangent_mag = tangent:abs()
                if tangent_mag > 1e-6 then
                  local tangent_dir = tangent / tangent_mag
                  local mu = 0.3
                  local friction_impulse = tangent_dir * math.min(tangent_mag * denom, mu * math.abs(j))
                  a:push(friction_impulse)
                  b:push(-friction_impulse)
                end
                
                a._last_collision = {other=B.idx}
                b._last_collision = {other=A.idx}
                
                local slop = 0.01
                local percent = 0.4
                local penetration = minDist - dist
                
                if penetration > slop and denom > 0 then
                  local correction = normal * ((penetration - slop) * (percent / denom))
                  a.position = a.position - correction * invMassA
                  b.position = b.position + correction * invMassB
                end
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
    self.timeleft = 0
  end
  
  for i=1,#self do
    local a = self[i]
    for j=i+1,#self do
      local b = self[j]
      local diff = b.position - a.position
      local dist = diff:abs()
      local minDist = a.radius + b.radius
      if dist > 0.01 and dist < minDist then
        local normal = diff * (1/dist)
        local penetration = minDist - dist
        local pushback = normal * (penetration * 0.8)
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
  
  if self.log_buffer and #self.log_buffer > 0 then
    local fh = io.open("physics_log.txt","a")
    if fh then
      for _,line in ipairs(self.log_buffer) do fh:write(line) end
      fh:close()
    end
    table.clear(self.log_buffer)
  end
end

---@diagnostic disable-next-line: lowercase-global
body={position=vector{}, velocity=vector{}, angular=vector{}, mass=0, theta=0}
function body:set(pos,vel,ang,m,th)
  self.position=vector(pos) or self.position
  self.velocity=vector(vel) or self.velocity
  self.angular=vector(ang) or self.angular
  self.mass=m or self.mass
  self.invMass = (self.mass ~= 0) and (1 / self.mass) or 0
  self.theta=th or self.theta
  local r = 0
  for k=1,#self do r = math.max(r, vector(self[k] or {0,0,0}):abs()) end
  self.radius = r * 0.75
  return self
end

function body:effect(impulse, displacement)
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

function body:push(impulse, displacement)
  local dv, da = self:effect(impulse, displacement)
  local dv_mag = dv:abs()
  local dv_max = (self.dv_max or box.dv_max or 50)
  if dv_mag > dv_max then
    local t = (love and love.timer and love.timer.getTime()) or os.time()
    local fh = io.open("physics_log.txt","a")
    if fh then
      fh:write(string.format("[ANOMALY] time=%.3f body:push clamped dv=%.3f -> %.3f pos=(%.3f,%.3f,%.3f)\n", t, dv_mag, dv_max, self.position[1], self.position[2], self.position[3]))
      fh:close()
    else
      log("[ANOMALY] could not open physics_log.txt to write anomaly")
    end
    dv = dv * (dv_max / dv_mag)
  end
  self.velocity = self.velocity + dv
  self.angular = self.angular + da
end

function body:update(dt)
  self.position=self.position+self.velocity*dt
  local r=rotation():set(self.angular:abs()*dt, self.angular:norm())
  for i=1,#self do self[i]=r(self[i]) end
end


function body:wall(index, normal, restitution, friction)
  local d = self[index]
  local e = (self.restitution ~= nil) and self.restitution or restitution
  local f = (self.friction ~= nil) and self.friction or friction

  local s = normal..(self.angular^d + self.velocity)
  
  if self.asleep and math.abs(s) < 0.05 then
    return
  end
  
  if self.asleep and math.abs(s) >= 0.05 then
    self.asleep = false
    self.sleep_timer = 0
  end
  
  local cv,ca = self:effect(normal,d)

  local cs = ca^d + cv
  local constraint = (1 + e) * s / (cs..normal)
  
  self.wall_hits = (self.wall_hits or 0) + 1
  if self.wall_hits > 150 then
    self.velocity = self.velocity * 0.2
    self.angular = self.angular * 0.3
    self.wall_hits = 0
  end
  
  local steps = 11
  local impulse = -constraint * normal / steps
  local abs = impulse:abs()
  for i=1,steps do
    self:push(impulse,d)
    local tangent_vel = self.angular^d + self.velocity
    tangent_vel = (tangent_vel - (normal..tangent_vel) * normal)
    self:push(tangent_vel:norm() * f * (-abs), d)
  end
  self._last_wall = {index=index, normal=normal}
end

function body:parallel(normal, min, max, restitution, friction)
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
  
  local penetration_threshold = 0.001
  
  if lowest and (min - lowesta) > penetration_threshold then
    self:wall(lowest,normal,restitution,friction)
    if not self.asleep then
      self.position=self.position+normal*(min-lowesta)
    end
  end
  
  if highest and (highesta - max) > penetration_threshold then
    self:wall(highest,-normal,restitution,friction)
    if not self.asleep then
      self.position=self.position+normal*(max-highesta)
    end
  end
  
end

function body:box(x1,y1,z1,x2,y2,z2,restitution,friction)
  self:parallel(vector{0,0,1},z1,z2,restitution, friction)
  self:parallel(vector{1,0,0},x1,x2,restitution, friction)
  self:parallel(vector{0,1,0},y1,y2,restitution, friction)
end

return box
