-- src/content/binders.lua
-- Historical binder/medium database based on "The Medieval Manuscript" (Charles)
-- Includes binders for painting, inks, and gilding

local Binders = {}

-- ══════════════════════════════════════════════════════════════════
-- BINDER DATABASE
-- ══════════════════════════════════════════════════════════════════
Binders.data = {

    -- ══════════════════════════════════════════════════════════════
    -- PRIMARY PAINT BINDERS
    -- ══════════════════════════════════════════════════════════════
    
    GOMMA_ARABICA = {
        name = "Gum Arabic",
        name_en = "Gum Arabic",
        tier = 1,
        cost = 0,
        origin = "vegetable_gum",  -- Acacia resin
        function_desc = "Primary water-soluble binder for pigments and inks; gives control and transparency.",
        preparation = "Dissolve cleaned acacia tears in warm water, strain, and rest briefly before use.",
        uses = {"pigments", "inks", "shell_gold"},
        risks = nil,  -- No known risk discussed
        effects = {},
        description = "A standard medieval medium for paints and shell gold, valued for clean flow and stable film.",
    },
    
    MIELE = {
        name = "Honey",
        name_en = "Honey",
        tier = 2,
        cost = 15,
        origin = "organic",
        function_desc = "Humectant additive that keeps paint films flexible and delays cracking.",
        preparation = "Blend a small amount of clarified honey into gum or glair after filtering.",
        uses = {"pigments", "shell_gold"},
        risks = nil,
        effects = {
            flexible = true,  -- Keeps color flexible
            on_stain = "reduce",  -- Reduces stain impact
        },
        description = "Used sparingly to keep mixtures workable in dry conditions and soften brittle passages.",
    },
    
    GLAIR = {
        name = "Egg White / Glair",
        name_en = "Egg White / Glair",
        tier = 1,
        cost = 5,
        origin = "organic_egg",
        function_desc = "Protein binder from egg white, especially useful for gilding and glossy details.",
        preparation = "Whisk egg white, let foam settle, then decant the clear liquid phase.",
        uses = {"gold_leaf", "gesso", "pigments"},
        risks = "foam_bubbles",  -- Watch for foam and bubbles
        effects = {
            shine = true,  -- Glossy finish
            gold_adhesion = true,
        },
        description = "Produces a bright, tight surface but can trap bubbles if prepared too aggressively.",
    },
    
    TUORLO = {
        name = "Egg Yolk / Egg Tempera",
        name_en = "Egg Yolk / Egg Tempera",
        tier = 1,
        cost = 8,
        origin = "organic_egg",
        function_desc = "Egg-tempera binder for matte, durable color passages.",
        preparation = "Separate the yolk, pierce the membrane, and dilute lightly before adding pigment.",
        uses = {"pigments"},
        risks = nil,
        effects = {
            durability = 1,  -- More durable colors
            matte_finish = true,
        },
        description = "Creates strong adhesion and body, ideal for opaque passages that must resist wear.",
    },
    
    GOMMA_VEGETALE = {
        name = "Plant Gum",
        name_en = "Plant Gum",
        tier = 1,
        cost = 3,
        origin = "vegetable_gum",
        function_desc = "General plant gum binder for light paint and adhesive sizing.",
        preparation = "Soak and dissolve gum fragments, then strain to remove insoluble particles.",
        uses = {"gold_leaf"},
        risks = nil,
        effects = {},
        description = "A low-cost alternative to gum arabic, suitable for simple gilding and utility mixes.",
    },

    -- ══════════════════════════════════════════════════════════════
    -- ANIMAL GLUES
    -- ══════════════════════════════════════════════════════════════
    
    COLLA_PESCE = {
        name = "Fish Glue / Isinglass",
        name_en = "Fish Glue / Isinglass",
        tier = 2,
        cost = 20,
        origin = "animal",
        function_desc = "High-clarity animal glue for strong yet flexible gilding grounds.",
        preparation = "Rehydrate isinglass in cold water, then warm gently without boiling.",
        uses = {"gesso", "gold_leaf"},
        risks = nil,
        effects = {
            gold_adhesion = true,
            strong_bond = true,
        },
        description = "Preferred when a cleaner, less yellow glue film is needed on delicate supports.",
    },
    
    COLLA_CONIGLIO = {
        name = "Rabbit Skin Glue",
        name_en = "Rabbit Skin Glue",
        tier = 3,
        cost = 25,
        origin = "animal",
        function_desc = "Powerful collagen glue for gesso and heavy mineral loads.",
        preparation = "Soak granules overnight and heat in a bain-marie until fully dissolved.",
        uses = {"gesso", "gold_leaf", "heavy_pigments"},
        risks = nil,
        effects = {
            strong_bond = true,
        },
        description = "Offers high grab and rigidity, but concentration must be controlled to avoid brittleness.",
    },

    -- ══════════════════════════════════════════════════════════════
    -- GILDING GESSO
    -- ══════════════════════════════════════════════════════════════
    
    GESSO_DORATURA = {
        name = "Gilding Gesso / Raised Ground",
        name_en = "Gilding Gesso / Raised Ground",
        tier = 3,
        cost = 30,
        origin = "compound",  -- Plaster of Paris + adhesives
        function_desc = "Composite raised ground for embossed, burnishable gold leaf.",
        preparation = "Cook and grind plaster, glue, and additives into a smooth paste for thin layered application.",
        uses = {"gold_leaf_raised"},
        components = {"plaster_of_paris", "glair", "gum_arabic", "fish_glue", 
                      "rabbit_glue", "sugar", "garlic_juice", "pigment"},
        risks = "reactivation",  -- Requires reactivation with breath moisture
        effects = {
            raised_gold = true,  -- Raised gold
            reflection_boost = true,
        },
        description = "Forms the classic domed gilding relief that catches light and boosts metallic brilliance.",
    },

    -- ══════════════════════════════════════════════════════════════
    -- ADDITIVES AND AUXILIARIES
    -- ══════════════════════════════════════════════════════════════
    
    ZUCCHERO = {
        name = "Sugar",
        name_en = "Sugar",
        tier = 2,
        cost = 10,
        origin = "organic",
        function_desc = "Plasticizing additive that improves tack and handling in gesso mixes.",
        preparation = "Dissolve sugar in warm water before incorporating it into the binder phase.",
        uses = {"gesso"},
        risks = nil,
        effects = {
            adhesion_boost = true,
        },
        description = "In small doses it helps adhesion; excess can make layers sticky or moisture-sensitive.",
    },
    
    SUCCO_AGLIO = {
        name = "Garlic Juice",
        name_en = "Garlic Juice",
        tier = 2,
        cost = 5,
        origin = "organic",
        function_desc = "Traditional tack enhancer for gilding and difficult surfaces.",
        preparation = "Crush fresh garlic, press the juice, and add only tiny filtered drops to the mix.",
        uses = {"gesso"},
        risks = "odor",  -- Strong odor
        effects = {
            adhesion_boost = true,
        },
        description = "Historically cited for improving leaf grip, though odor and variability require caution.",
    },
    
    CERUME = {
        name = "Earwax",
        name_en = "Earwax",
        tier = 1,
        cost = 0,  -- Free!
        origin = "organic",
        function_desc = "Antifoam additive used to calm glair and reduce bubbling.",
        preparation = "Soften and disperse a minute amount into the binder while still warm.",
        uses = {"glair", "gesso"},
        risks = nil,
        effects = {
            antifoam = true,
        },
        description = "A workshop trick for smoother films when protein media trap persistent air.",
    },
    
    OLIO_GAROFANO = {
        name = "Clove Oil",
        name_en = "Clove Oil",
        tier = 3,
        cost = 15,
        origin = "organic_plant",
        function_desc = "Aromatic antifoam and preservative helper for protein-rich media.",
        preparation = "Add one or two drops to finished binder solution and mix thoroughly.",
        uses = {"glair", "gesso"},
        risks = nil,
        effects = {
            antifoam = true,
            fragrant = true,
        },
        description = "Reduces froth and slows spoilage in small batches without strongly shifting hue.",
    },

    -- ══════════════════════════════════════════════════════════════
    -- EXTRACTION AUXILIARIES (not final binders)
    -- ══════════════════════════════════════════════════════════════
    
    LISCIVIA = {
        name = "Lye",
        name_en = "Lye",
        tier = 3,
        cost = 12,
        origin = "chemical",  -- Ash + water
        function_desc = "Alkaline processing agent for extraction and special pigment preparation.",
        preparation = "Leach wood ash with water, let solids settle, and decant the clear alkaline liquor.",
        uses = {"pigment_extraction", "lapis_preparation"},
        risks = "skin_irritation",  -- Can cause skin cracking
        effects = {
            reactive = true,
            risk = 1,
        },
        description = "Useful in technical prep steps, but caustic handling is required to avoid skin damage.",
    },
    
    CERA = {
        name = "Wax",
        name_en = "Wax",
        tier = 2,
        cost = 10,
        origin = "organic",
        function_desc = "Wax additive for polishing, water resistance, and specialty extractions.",
        preparation = "Melt gently and emulsify or blend according to the target process.",
        uses = {"lapis_preparation"},
        risks = nil,
        effects = {},
        description = "Used as a process aid rather than a primary binder, especially in lapis workflows.",
    },

    -- ══════════════════════════════════════════════════════════════
    -- WRITING AUXILIARIES
    -- ══════════════════════════════════════════════════════════════
    
    SANDARACA = {
        name = "Gum Sandarac",
        name_en = "Gum Sandarac",
        tier = 2,
        cost = 8,
        origin = "vegetable_resin",
        function_desc = "Resin powder for parchment preparation and cleaner pen behavior.",
        preparation = "Pulverize sandarac and dust lightly over the writing area before inking.",
        uses = {"writing_preparation"},
        risks = nil,
        effects = {
            ink_absorption = true,
            clean_lines = true,
        },
        description = "Improves line control by reducing feathering on polished or oily surfaces.",
    },
    
    ACETO = {
        name = "Vinegar",
        name_en = "Vinegar",
        tier = 2,
        cost = 8,
        origin = "organic",
        function_desc = "Mild acid reagent for preservation and mineral conversions.",
        preparation = "Use clarified vinegar in controlled doses during maceration or washing steps.",
        uses = {"verdigris_production", "lead_white_production", "preservation"},
        risks = nil,
        effects = {
            preservative = true,
            verdigris_boost = true,
        },
        description = "Common in historical recipes for verdigris, lead-white production, and bath stabilization.",
    },

    -- ══════════════════════════════════════════════════════════════
    -- INKS (as complete formulas)
    -- ══════════════════════════════════════════════════════════════
    
    VITRIOLO = {
        name = "Vitriol / Copperas",
        name_en = "Vitriol / Copperas",
        tier = 2,
        cost = 10,
        origin = "mineral",  -- Solfato ferroso
        function_desc = "Iron sulfate source for iron-gall ink chemistry.",
        preparation = "Dissolve measured vitriol crystals and combine with filtered gall extract.",
        uses = {"iron_gall_ink"},
        risks = "corrosion",  -- High iron can corrode parchment
        effects = {
            permanence = true,
        },
        description = "Drives dark ink formation and permanence, but excess acidity increases corrosion risk.",
    },
    
    GALLA = {
        name = "Oak Gall / Gallnut",
        name_en = "Oak Gall / Gallnut",
        tier = 1,
        cost = 5,
        origin = "organic",  -- Oak galls
        function_desc = "Tannin-rich base material for iron-gall ink.",
        preparation = "Crush oak galls, soak to extract tannins, then filter before combining with vitriol.",
        uses = {"iron_gall_ink"},
        risks = nil,
        effects = {},
        description = "Core historical ink ingredient providing depth, permanence, and characteristic brown-black tone.",
    },
}

-- ══════════════════════════════════════════════════════════════════
-- FUNCTIONS
-- ══════════════════════════════════════════════════════════════════

--- Gets binder by name
function Binders.get(name)
    return Binders.data[name]
end

--- Gets binders by tier
function Binders.getByTier(tier)
    local result = {}
    for name, data in pairs(Binders.data) do
        if data.tier == tier then
            result[name] = data
        end
    end
    return result
end

--- Gets binders by specific use
function Binders.getByUse(use)
    local result = {}
    for name, data in pairs(Binders.data) do
        if data.uses then
            for _, u in ipairs(data.uses) do
                if u == use then
                    result[name] = data
                    break
                end
            end
        end
    end
    return result
end

--- Counts total binders
function Binders.count()
    local n = 0
    for _ in pairs(Binders.data) do
        n = n + 1
    end
    return n
end

--- Gets binders for gilding
function Binders.getForGilding()
    local result = {}
    for name, data in pairs(Binders.data) do
        if data.uses then
            for _, u in ipairs(data.uses) do
                if u == "gold_leaf" or u == "gesso" or u == "shell_gold" or u == "gold_leaf_raised" then
                    result[name] = data
                    break
                end
            end
        end
    end
    return result
end

return Binders
