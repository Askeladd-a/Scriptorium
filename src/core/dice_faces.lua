
local Pigments = require("src.content.pigments")

local M = {}


M.DiceFaces = {
    [1] = {
        family = "BROWN",
        fallback = "OCRA_BRUNA",
        pigments = {
            "OCRA_BRUNA",
        },
    },
    [2] = {
        family = "GREEN",
        fallback = "VERDERAME",
        pigments = {
            "VERDERAME",
            "VERGAUT",
            "MALACHITE",
        },
    },
    [3] = {
        family = "BLACK",
        fallback = "NERO_CARBONIOSO",
        pigments = {
            "NERO_CARBONIOSO",
            "NERO_FERROGALLICO",
        },
    },
    [4] = {
        family = "RED",
        fallback = "OCRA_ROSSA",
        pigments = {
            "OCRA_ROSSA",
            "ROBBIA",
            "BRAZILWOOD",
            "MINIO",
            "VERMIGLIONE",
            "KERMES",
            "REALGAR",
        },
    },
    [5] = {
        family = "BLUE",
        fallback = "GUADO",
        pigments = {
            "GUADO",
            "AZZURRITE",
            "LAPISLAZZULI",
            "BLU_EGIZIO",
        },
    },
    [6] = {
        family = "GOLD",
        fallback = "OCRA_GIALLA",
        pigments = {
            "OCRA_GIALLA",
            "RESEDA",
            "CURCUMA",
            "CAMOMILLA",
            "ZAFFERANO",
            "GIALLORINO",
            "ORO_FOGLIA",
            "ORO_POLVERE",
            "ORPIMENTO",
            "ORO_MUSIVO",
        },
    },
}


---@param pigmentName string Nome esatto del pigmento (es. "OCRA_ROSSA")
---@return table {r, g, b} o nil se non trovato
function M.getDieColor(pigmentName)
    local pigment = Pigments.get(pigmentName)
    if pigment and pigment.color then
        return pigment.color
    end
    return {128, 128, 128}
end

---@param face number 1-6
---@return string Nome famiglia (BROWN, GREEN, BLACK, RED, BLUE, GOLD)
function M.getFamilyName(face)
    local faceData = M.DiceFaces[face]
    return faceData and faceData.family or "UNKNOWN"
end

---@param face number 1-6
---@param maxTier number Tier massimo sbloccato (1-7)
---@return table Filtered list of {name, tier, weight}
local function getAvailablePigments(face, maxTier)
    local faceData = M.DiceFaces[face]
    if not faceData then
        return {}
    end
    
    local available = {}
    for _, pigmentName in ipairs(faceData.pigments) do
        local pigment = Pigments.get(pigmentName)
        if pigment and pigment.tier <= maxTier then
            local weight = 1 / pigment.tier
            table.insert(available, {
                name = pigmentName,
                tier = pigment.tier,
                weight = weight,
            })
        end
    end
    
    return available
end

---@param face number 1-6
---@param maxTier number Tier massimo sbloccato (1-7)
---@param rng? function Optional RNG function (default: math.random)
---@return string Nome del pigmento selezionato
function M.pickPigmentForFace(face, maxTier, rng)
    rng = rng or math.random
    maxTier = maxTier or 7
    
    local faceData = M.DiceFaces[face]
    if not faceData then
        return "OCRA_GIALLA"
    end
    
    local available = getAvailablePigments(face, maxTier)
    
    if #available == 0 then
        return faceData.fallback
    end
    
    if #available == 1 then
        return available[1].name
    end
    
    local totalWeight = 0
    for _, p in ipairs(available) do
        totalWeight = totalWeight + p.weight
    end
    
    local roll = rng() * totalWeight
    local cumulative = 0
    
    for _, p in ipairs(available) do
        cumulative = cumulative + p.weight
        if roll <= cumulative then
            return p.name
        end
    end
    
    return available[#available].name
end

---@param numDice number Number of dice
---@param values table Array of values (1-6) for each die
---@param maxTier number Maximum unlocked tier
---@param seed? number Optional seed for deterministic RNG
---@return table Array of pigment names, one for each die
function M.pickPigmentsForRoll(numDice, values, maxTier, seed)
    local rng
    if seed then
        local state = seed
        rng = function()
            state = (state * 1103515245 + 12345) % 2147483648
            return state / 2147483648
        end
    else
        rng = math.random
    end
    
    local pigments = {}
    for i = 1, numDice do
        local face = values[i] or 1
        pigments[i] = M.pickPigmentForFace(face, maxTier, rng)
    end
    
    return pigments
end

---@param face number 1-6
---@return table Array of pigment names
function M.getAllPigmentsForFace(face)
    local faceData = M.DiceFaces[face]
    if not faceData then
        return {}
    end
    return faceData.pigments
end

---@param face number 1-6
---@param maxTier number Tier massimo sbloccato
function M.debugPrintFace(face, maxTier)
    local faceData = M.DiceFaces[face]
    if not faceData then
        log("Faccia invalida:", face)
        return
    end
    
    log(string.format("=== Faccia %d (%s) ===", face, faceData.family))
    log("Fallback:", faceData.fallback)
    log("Pigmenti disponibili (maxTier=" .. maxTier .. "):")
    
    local available = getAvailablePigments(face, maxTier)
    for _, p in ipairs(available) do
        local pigment = Pigments.get(p.name)
        local color = pigment and pigment.color or {0,0,0}
        log(string.format("  - %s (tier %d, peso %.2f) RGB(%d,%d,%d)",
            p.name, p.tier, p.weight, color[1], color[2], color[3]))
    end
end

return M
