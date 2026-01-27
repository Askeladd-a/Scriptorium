-- OBB-OBB intersection using Separating Axis Theorem (SAT)
-- a_verts, b_verts: array of 8 vertices (each is {x,y,z})
-- Returns true if the OBBs intersect, false otherwise
local obb = {}
function obb.intersect(a_verts, b_verts)
    local function get_axes(verts)
        local x = {verts[2][1]-verts[1][1], verts[2][2]-verts[1][2], verts[2][3]-verts[1][3]}
        local y = {verts[4][1]-verts[1][1], verts[4][2]-verts[1][2], verts[4][3]-verts[1][3]}
        local z = {verts[5][1]-verts[1][1], verts[5][2]-verts[1][2], verts[5][3]-verts[1][3]}
        return {x, y, z}
    end
    local function dot(a,b) return a[1]*b[1]+a[2]*b[2]+a[3]*b[3] end
    local function norm(v)
        local d = math.sqrt(dot(v,v))
        if d == 0 then return {0,0,0} end
        return {v[1]/d, v[2]/d, v[3]/d}
    end
    local function cross(a,b)
        return {
            a[2]*b[3]-a[3]*b[2],
            a[3]*b[1]-a[1]*b[3],
            a[1]*b[2]-a[2]*b[1]
        }
    end
    local function project(verts, axis)
        local min, max = dot(verts[1], axis), dot(verts[1], axis)
        for i=2,8 do
            local d = dot(verts[i], axis)
            if d < min then min = d end
            if d > max then max = d end
        end
        return min, max
    end
    local a_axes = get_axes(a_verts)
    local b_axes = get_axes(b_verts)
    local axes = {}
    for i=1,3 do axes[#axes+1] = norm(a_axes[i]) end
    for i=1,3 do axes[#axes+1] = norm(b_axes[i]) end
    for i=1,3 do for j=1,3 do axes[#axes+1] = norm(cross(a_axes[i], b_axes[j])) end end
    local min_overlap = math.huge
    local min_axis = nil
    for _,axis in ipairs(axes) do
        local minA, maxA = project(a_verts, axis)
        local minB, maxB = project(b_verts, axis)
        if maxA < minB or maxB < minA then
            return false -- Separating axis found
        end
        local overlap = math.min(maxA, maxB) - math.max(minA, minB)
        if overlap < min_overlap then
            min_overlap = overlap
            min_axis = axis
        end
    end
    return true, min_axis, min_overlap
end

-- Trova la coppia di punti più vicini tra due OBB (array di 8 vertici ciascuno)
-- Restituisce: puntoA, puntoB, distanza
function obb.closest_points(a_verts, b_verts)
    local function dist2(a, b)
        local dx,dy,dz = a[1]-b[1], a[2]-b[2], a[3]-b[3]
        return dx*dx+dy*dy+dz*dz
    end
    local minDist2 = math.huge
    local pa, pb = nil, nil
    for i=1,8 do
        for j=1,8 do
            local d2 = dist2(a_verts[i], b_verts[j])
            if d2 < minDist2 then
                minDist2 = d2
                pa, pb = a_verts[i], b_verts[j]
            end
        end
    end
    return pa, pb, math.sqrt(minDist2)
end

return obb