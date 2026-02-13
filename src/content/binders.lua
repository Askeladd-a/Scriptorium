
local BinderCatalog = {}

BinderCatalog.data = {

    
    GOMMA_ARABICA = {
        name = "Gum Arabic",
        name_en = "Gum Arabic",
        tier = 1,
        cost = 0,
        origin = "vegetable_gum",
        function_desc = "Primary water-soluble binder for pigments and inks; gives control and transparency.",
        preparation = "Dissolve cleaned acacia tears in warm water, strain, and rest briefly before use.",
        uses = {"pigments", "inks", "shell_gold"},
        risks = nil,
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
            flexible = true,
            on_stain = "reduce",
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
        risks = "foam_bubbles",
        effects = {
            shine = true,
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
            durability = 1,
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

    
    GESSO_DORATURA = {
        name = "Gilding Gesso / Raised Ground",
        name_en = "Gilding Gesso / Raised Ground",
        tier = 3,
        cost = 30,
        origin = "compound",
        function_desc = "Composite raised ground for embossed, burnishable gold leaf.",
        preparation = "Cook and grind plaster, glue, and additives into a smooth paste for thin layered application.",
        uses = {"gold_leaf_raised"},
        components = {"plaster_of_paris", "glair", "gum_arabic", "fish_glue", 
                      "rabbit_glue", "sugar", "garlic_juice", "pigment"},
        risks = "reactivation",
        effects = {
            raised_gold = true,
            reflection_boost = true,
        },
        description = "Forms the classic domed gilding relief that catches light and boosts metallic brilliance.",
    },

    
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
        risks = "odor",
        effects = {
            adhesion_boost = true,
        },
        description = "Historically cited for improving leaf grip, though odor and variability require caution.",
    },
    
    CERUME = {
        name = "Earwax",
        name_en = "Earwax",
        tier = 1,
        cost = 0,
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

    
    LISCIVIA = {
        name = "Lye",
        name_en = "Lye",
        tier = 3,
        cost = 12,
        origin = "chemical",
        function_desc = "Alkaline processing agent for extraction and special pigment preparation.",
        preparation = "Leach wood ash with water, let solids settle, and decant the clear alkaline liquor.",
        uses = {"pigment_extraction", "lapis_preparation"},
        risks = "skin_irritation",
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

    
    VITRIOLO = {
        name = "Vitriol / Copperas",
        name_en = "Vitriol / Copperas",
        tier = 2,
        cost = 10,
        origin = "mineral",
        function_desc = "Iron sulfate source for iron-gall ink chemistry.",
        preparation = "Dissolve measured vitriol crystals and combine with filtered gall extract.",
        uses = {"iron_gall_ink"},
        risks = "corrosion",
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
        origin = "organic",
        function_desc = "Tannin-rich base material for iron-gall ink.",
        preparation = "Crush oak galls, soak to extract tannins, then filter before combining with vitriol.",
        uses = {"iron_gall_ink"},
        risks = nil,
        effects = {},
        description = "Core historical ink ingredient providing depth, permanence, and characteristic brown-black tone.",
    },
}


function BinderCatalog.get(binder_id)
    return BinderCatalog.data[binder_id]
end

function BinderCatalog.getByTier(tier)
    local result = {}
    for binder_id, binder in pairs(BinderCatalog.data) do
        if binder.tier == tier then
            result[binder_id] = binder
        end
    end
    return result
end

function BinderCatalog.getByUse(usage_tag)
    local result = {}
    for binder_id, binder in pairs(BinderCatalog.data) do
        if binder.uses then
            for _, usage in ipairs(binder.uses) do
                if usage == usage_tag then
                    result[binder_id] = binder
                    break
                end
            end
        end
    end
    return result
end

function BinderCatalog.count()
    local total = 0
    for _ in pairs(BinderCatalog.data) do
        total = total + 1
    end
    return total
end

function BinderCatalog.getForGilding()
    local result = {}
    for binder_id, binder in pairs(BinderCatalog.data) do
        if binder.uses then
            for _, usage in ipairs(binder.uses) do
                if usage == "gold_leaf" or usage == "gesso" or usage == "shell_gold" or usage == "gold_leaf_raised" then
                    result[binder_id] = binder
                    break
                end
            end
        end
    end
    return result
end

return BinderCatalog
