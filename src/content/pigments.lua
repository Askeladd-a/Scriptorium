
local PigmentCatalog = {}

PigmentCatalog.TOXICITY = {
    SAFE = 0,
    MILD = 1,
    MODERATE = 2,
    HIGH = 3,
}

PigmentCatalog.TIERS = {
    [1] = {"OCRA_ROSSA", "OCRA_GIALLA", "OCRA_BRUNA", "NERO_CARBONIOSO", 
           "NERO_FERROGALLICO", "CRETA", "GESSO", "GUSCIO_UOVO"},
    [2] = {"GUADO", "VERDERAME", "RESEDA", "CURCUMA", "CAMOMILLA", "ZAFFERANO"},
    [3] = {"ROBBIA", "BRAZILWOOD", "FOLIUM", "VERGAUT", "AZZURRITE"},
    [4] = {"MINIO", "GIALLORINO", "VERMIGLIONE", "ORCHIL"},
    [5] = {"LAPISLAZZULI", "ORO_FOGLIA", "ORO_POLVERE", "KERMES", "MALACHITE"},
    [6] = {"ORPIMENTO", "ORO_MUSIVO", "BLU_EGIZIO", "REALGAR"},
    [7] = {"PORPORA_TIRO", "BIANCO_PIOMBO"},
}

PigmentCatalog.data = {

    
    OCRA_ROSSA = {
        name = "Red Ochre",
        name_en = "Red Ochre",
        color = {180, 60, 40},
        tier = 1,
        toxicity = 0,
        cost = 0,
        origin = "mineral",
        preparation = "Wash and levigate hematite-rich earth, discard coarse sand, and dry the fine fraction.",
        folio_use = {
            text = nil,
            dropcaps = true,
            borders = false,
            corners = false,
            miniature = nil,
        },
        effects = {},
        description = "Reliable non-toxic earth red used from rubrication accents to broad underpainting.",
    },
    
    ROBBIA = {
        name = "Madder Lake",
        name_en = "Madder Lake",
        color = {160, 50, 60},
        tier = 3,
        toxicity = 0,
        cost = 20,
        origin = "organic_plant",
        preparation = "Extract color from madder roots, precipitate with alum, then dry and grind the lake pigment.",
        folio_use = {
            text = nil,
            dropcaps = nil,
            borders = false,
            corners = false,
            miniature = nil,
        },
        effects = {
            safe_red = true,
        },
        description = "Transparent organic red with elegant depth, favored when a safer crimson is needed.",
    },
    
    MINIO = {
        name = "Red Lead / Minium",
        name_en = "Red Lead / Minium",
        color = {230, 90, 50},
        tier = 4,
        toxicity = 3,
        cost = 25,
        origin = "artificial",
        preparation = "Use finely ground red lead and mull it carefully with binder to avoid dust exposure.",
        folio_use = {
            text = true,
            dropcaps = true,
            borders = false,
            corners = false,
            miniature = true,
        },
        effects = {
            bonus_dropcaps = 1,
            origin_miniature = true,
        },
        description = "Brilliant orange-red rubrication color with strong impact, but lead-based and hazardous.",
    },
    
    VERMIGLIONE = {
        name = "Vermilion / Cinnabar",
        name_en = "Vermilion / Cinnabar",
        color = {200, 40, 40},
        tier = 4,
        toxicity = 3,
        cost = 45,
        origin = "mineral_artificial",
        preparation = "Grind cinnabar or synthetic vermilion gently and avoid contamination from alkali residues.",
        folio_use = {
            text = true,
            dropcaps = nil,
            borders = false,
            corners = false,
            miniature = true,
        },
        effects = {
            vibrant = true,
            degradation_risk = true,
        },
        description = "Intense scarlet prized for focal details, ceremonial garments, and high-contrast accents.",
    },
    
    REALGAR = {
        name = "Realgar",
        name_en = "Realgar",
        color = {220, 100, 40},
        tier = 6,
        toxicity = 3,
        cost = 60,
        origin = "mineral",
        preparation = "Select bright orange crystals, grind under controlled conditions, and store away from light.",
        folio_use = {
            text = false,
            dropcaps = nil,
            borders = false,
            corners = false,
            miniature = nil,
        },
        effects = {
            risk_reward = true,
            rare = true,
        },
        description = "Rare arsenic orange with dramatic chroma, used sparingly because of instability and danger.",
    },
    
    KERMES = {
        name = "Kermes / Carmine",
        name_en = "Kermes / Carmine",
        color = {180, 30, 50},
        tier = 5,
        toxicity = 0,
        cost = 70,
        origin = "organic_insect",
        preparation = "Steep dried kermes insects, precipitate the dye onto a substrate, then dry into a usable lake.",
        folio_use = {
            text = nil,
            dropcaps = nil,
            borders = false,
            corners = false,
            miniature = nil,
        },
        effects = {
            precious_red = true,
        },
        description = "Luxurious insect crimson associated with prestige manuscripts and costly commissions.",
    },
    
    BRAZILWOOD = {
        name = "Brazilwood / Sappanwood",
        name_en = "Brazilwood / Sappanwood",
        color = {150, 40, 50},
        tier = 3,
        toxicity = 0,
        cost = 18,
        origin = "organic_plant",
        preparation = "Boil chipped wood to extract dye, concentrate the liquor, and precipitate a workable lake.",
        folio_use = {
            text = nil,
            dropcaps = nil,
            borders = false,
            corners = false,
            miniature = nil,
        },
        effects = {},
        description = "Warm red lake with good tinting value, often used for decorative passages.",
    },

    
    OCRA_GIALLA = {
        name = "Yellow Ochre",
        name_en = "Yellow Ochre",
        color = {200, 160, 60},
        tier = 1,
        toxicity = 0,
        cost = 0,
        origin = "mineral",
        preparation = "Levigate yellow earth repeatedly to separate clean iron-rich particles from clay and grit.",
        folio_use = {
            text = nil,
            dropcaps = true,
            borders = false,
            corners = false,
            miniature = nil,
        },
        effects = {},
        description = "Durable earth yellow, dependable for initials, flesh mixtures, and warm highlights.",
    },
    
    ORPIMENTO = {
        name = "Orpiment / Auripigmentum",
        name_en = "Orpiment / Auripigmentum",
        color = {240, 200, 50},
        tier = 6,
        toxicity = 3,
        cost = 55,
        origin = "mineral",
        preparation = "Grind arsenic sulfide with strict dust precautions and isolate tools used for toxic PigmentCatalog.",
        folio_use = {
            text = nil,
            dropcaps = true,
            borders = false,
            corners = false,
            miniature = true,
        },
        effects = {
            gold_substitute = true,
            risk_reward = true,
        },
        description = "Luminous arsenic yellow that can rival gold in brilliance but carries serious toxicity.",
    },
    
    GIALLORINO = {
        name = "Lead-Tin Yellow",
        name_en = "Lead-Tin Yellow",
        color = {240, 210, 80},
        tier = 4,
        toxicity = 3,
        cost = 35,
        origin = "artificial",
        preparation = "Prepare from calcined lead-tin oxide powder and mull to a smooth opaque paint.",
        folio_use = {
            text = false,
            dropcaps = nil,
            borders = true,
            corners = true,
            miniature = nil,
        },
        effects = {
            border_bonus = 1,
        },
        description = "Opaque historical yellow excellent for foliage, ornaments, and layered highlights.",
    },
    
    ORO_MUSIVO = {
        name = "Mosaic Gold / Purpurino",
        name_en = "Mosaic Gold / Purpurino",
        color = {255, 190, 60},
        tier = 6,
        toxicity = 3,
        cost = 65,
        origin = "artificial",
        preparation = "Synthesize and wash the powder repeatedly, then bind it as a metallic yellow highlight.",
        folio_use = {
            text = false,
            dropcaps = nil,
            borders = nil,
            corners = nil,
            miniature = true,
        },
        effects = {
            gold_compatible = true,
            hair_highlight = true,
        },
        description = "Artificial metallic yellow used to simulate gold effects in miniature details.",
    },
    
    RESEDA = {
        name = "Weld",
        name_en = "Weld",
        color = {200, 190, 80},
        tier = 2,
        toxicity = 0,
        cost = 5,
        origin = "organic_plant",
        preparation = "Simmer weld stems and flowers, then fix the extracted dye on alumina for better body.",
        folio_use = {
            text = nil,
            dropcaps = nil,
            borders = nil,
            corners = nil,
            miniature = nil,
        },
        effects = {
            fugitive = true,
        },
        description = "Clear plant yellow, bright but fugitive unless protected from strong light.",
    },
    
    CURCUMA = {
        name = "Turmeric",
        name_en = "Turmeric",
        color = {220, 180, 50},
        tier = 2,
        toxicity = 0,
        cost = 8,
        origin = "organic_plant",
        preparation = "Extract color from dried turmeric rhizome and prepare in small fresh batches.",
        folio_use = {
            text = nil,
            dropcaps = nil,
            borders = nil,
            corners = nil,
            miniature = nil,
        },
        effects = {
            fugitive = true,
        },
        description = "Accessible organic yellow with vivid tone and limited permanence.",
    },
    
    ZAFFERANO = {
        name = "Saffron",
        name_en = "Saffron",
        color = {255, 180, 40},
        tier = 2,
        toxicity = 0,
        cost = 40,
        origin = "organic_plant",
        preparation = "Infuse saffron threads in warm water or glair to obtain a luminous transparent yellow.",
        folio_use = {
            text = nil,
            dropcaps = nil,
            borders = nil,
            corners = nil,
            miniature = nil,
        },
        effects = {
            precious = true,
            fugitive = true,
        },
        description = "Prestige yellow glaze valued for warmth, transparency, and symbolic richness.",
    },
    
    CAMOMILLA = {
        name = "Chamomile",
        name_en = "Chamomile",
        color = {210, 190, 90},
        tier = 2,
        toxicity = 0,
        cost = 3,
        origin = "organic_plant",
        preparation = "Steep chamomile flower heads for a soft yellow extract, often reinforced with a mordant.",
        folio_use = {
            text = nil,
            dropcaps = nil,
            borders = nil,
            corners = nil,
            miniature = nil,
        },
        effects = {
            fugitive = true,
        },
        description = "Gentle botanical yellow suited to subtle highlights and delicate mixtures.",
    },

    
    VERDERAME = {
        name = "Verdigris",
        name_en = "Verdigris",
        color = {80, 160, 120},
        tier = 2,
        toxicity = 1,
        cost = 10,
        origin = "artificial",
        preparation = "Grow copper acetate crystals with vinegar vapors, then wash and grind before use.",
        folio_use = {
            text = nil,
            dropcaps = true,
            borders = nil,
            corners = nil,
            miniature = true,
        },
        effects = {
            corrosive = true,
            on_1 = "extra_stain",
        },
        description = "Powerful copper green with striking saturation, but chemically reactive over time.",
    },
    
    VERGAUT = {
        name = "Vergaut",
        name_en = "Vergaut",
        color = {120, 150, 80},
        tier = 3,
        toxicity = 3,
        cost = 30,
        origin = "mixture",
        preparation = "Blend a blue base with a yellow lake to obtain the characteristic mixed manuscript green.",
        folio_use = {
            text = false,
            dropcaps = true,
            borders = nil,
            corners = nil,
            miniature = nil,
        },
        effects = {
            mixed = true,
        },
        description = "Classic mixed green balancing blue depth with yellow brightness.",
    },
    
    MALACHITE = {
        name = "Malachite",
        name_en = "Malachite",
        color = {60, 140, 90},
        tier = 5,
        toxicity = 1,
        cost = 50,
        origin = "mineral",
        preparation = "Crush and grade malachite by particle size to control hue from pale to deep green.",
        folio_use = {
            text = false,
            dropcaps = nil,
            borders = nil,
            corners = nil,
            miniature = true,
        },
        effects = {
            stable_green = true,
        },
        description = "Granular mineral green giving textured natural passages in foliage and drapery.",
    },

    
    GUADO = {
        name = "Woad / Indigo",
        name_en = "Woad / Indigo",
        color = {60, 80, 140},
        tier = 2,
        toxicity = 0,
        cost = 8,
        origin = "organic_plant",
        preparation = "Ferment and oxidize woad extract, then dry cakes and regrind for painting use.",
        folio_use = {
            text = nil,
            dropcaps = true,
            borders = nil,
            corners = nil,
            miniature = nil,
        },
        effects = {},
        description = "Historic vat blue, softer than ultramarine but practical and widely obtainable.",
    },
    
    LAPISLAZZULI = {
        name = "Ultramarine / Lapis Lazuli",
        name_en = "Ultramarine / Lapis Lazuli",
        color = {40, 60, 170},
        tier = 5,
        toxicity = 0,
        cost = 100,
        origin = "mineral",
        preparation = "Separate lazurite from gangue by repeated grinding and wax-lye kneading cycles.",
        folio_use = {
            text = false,
            dropcaps = true,
            borders = nil,
            corners = nil,
            miniature = true,
        },
        effects = {
            golden_bonus = true,
            virgin_mary = true,
        },
        description = "Premium ultramarine source, exceptionally vivid and reserved for high-status work.",
    },
    
    AZZURRITE = {
        name = "Azurite",
        name_en = "Azurite",
        color = {50, 100, 180},
        tier = 3,
        toxicity = 2,
        cost = 35,
        origin = "mineral",
        preparation = "Levigate azurite and classify grains; coarser fractions produce deeper darker blues.",
        folio_use = {
            text = false,
            dropcaps = nil,
            borders = nil,
            corners = nil,
            miniature = nil,
        },
        effects = {
            lapis_alternative = true,
        },
        description = "Strong mineral blue and common ultramarine alternative in medieval workshops.",
    },
    
    BLU_EGIZIO = {
        name = "Egyptian Blue",
        name_en = "Egyptian Blue",
        color = {30, 90, 160},
        tier = 6,
        toxicity = 0,
        cost = 80,
        origin = "artificial_ancient",
        preparation = "Use pre-fritted synthetic blue, grind finely, and disperse in a compatible binder.",
        folio_use = {
            text = false,
            dropcaps = false,
            borders = false,
            corners = false,
            miniature = true,
        },
        effects = {
            ancient = true,
            rare = true,
        },
        description = "Ancient synthetic blue with a distinctive cool tone and rare manuscript attestations.",
    },

    
    PORPORA_TIRO = {
        name = "Tyrian Purple",
        name_en = "Tyrian Purple",
        color = {130, 40, 100},
        tier = 7,
        toxicity = 0,
        cost = 200,
        origin = "organic_animal",
        preparation = "Process murex-derived dye compounds and fix the color on a stable substrate.",
        folio_use = {
            text = nil,
            dropcaps = nil,
            borders = nil,
            corners = nil,
            miniature = nil,
        },
        effects = {
            imperial = true,
            legendary = true,
        },
        description = "Legendary imperial purple, symbol of rank and exceptional expense.",
    },
    
    ORCHIL = {
        name = "Orchil / Orcein",
        name_en = "Orchil / Orcein",
        color = {140, 60, 110},
        tier = 4,
        toxicity = 0,
        cost = 30,
        origin = "organic_lichen",
        preparation = "Ferment lichen material in alkaline solution, then age until violet tones fully develop.",
        folio_use = {
            text = false,
            dropcaps = nil,
            borders = nil,
            corners = nil,
            miniature = true,
        },
        effects = {
            parchment_dye = true,
        },
        description = "Lichen violet used for purple accents and occasional parchment tinting.",
    },
    
    FOLIUM = {
        name = "Turnsole / Folium",
        name_en = "Turnsole / Folium",
        color = {150, 70, 130},
        tier = 3,
        toxicity = 0,
        cost = 25,
        origin = "organic_plant",
        preparation = "Press turnsole fruit to collect sap and dry it onto cloth cakes for later rewetting.",
        folio_use = {
            text = false,
            dropcaps = true,
            borders = nil,
            corners = nil,
            miniature = nil,
        },
        effects = {
            penflourish = true,
        },
        description = "Plant violet-blue colorant known for pen flourishes and decorative line work.",
    },

    
    OCRA_BRUNA = {
        name = "Brown Ochre",
        name_en = "Brown Ochre",
        color = {140, 90, 50},
        tier = 1,
        toxicity = 0,
        cost = 0,
        origin = "mineral",
        preparation = "Wash and levigate brown earth, retaining the mid-weight fraction for stable color.",
        folio_use = {
            text = false,
            dropcaps = nil,
            borders = nil,
            corners = nil,
            miniature = true,
        },
        effects = {
            late_medieval = true,
        },
        description = "Stable earth brown for shadows, outlines, and naturalistic scenes.",
    },

    
    NERO_CARBONIOSO = {
        name = "Carbon Ink / Soot Ink",
        name_en = "Carbon Ink / Soot Ink",
        color = {30, 30, 35},
        tier = 1,
        toxicity = 0,
        cost = 0,
        origin = "organic",
        preparation = "Collect soot, wash impurities, and disperse the carbon with a gum-based binder.",
        folio_use = {
            text = true,
            dropcaps = nil,
            borders = false,
            corners = false,
            miniature = true,
        },
        effects = {
            erasable = true,
        },
        description = "Dense black with good covering power, easy to handle and comparatively safe.",
    },
    
    NERO_FERROGALLICO = {
        name = "Iron Gall Ink",
        name_en = "Iron Gall Ink",
        color = {25, 20, 30},
        tier = 1,
        toxicity = 1,
        cost = 5,
        origin = "chemical",
        preparation = "Macerate oak galls, add vitriol solution, then stabilize the ink with gum arabic.",
        folio_use = {
            text = true,
            dropcaps = nil,
            borders = false,
            corners = false,
            miniature = true,
        },
        effects = {
            permanent = true,
            corrosive = true,
        },
        description = "Standard writing black with excellent permanence, though potentially corrosive.",
    },

    
    CRETA = {
        name = "Chalk",
        name_en = "Chalk",
        color = {240, 235, 220},
        tier = 1,
        toxicity = 0,
        cost = 0,
        origin = "mineral",
        preparation = "Grind soft chalk and sieve to a fine even powder before mixing with binder.",
        folio_use = {
            text = false,
            dropcaps = nil,
            borders = nil,
            corners = nil,
            miniature = nil,
        },
        effects = {},
        description = "Matte white extender used for lightening, body, and preparatory passages.",
    },
    
    GESSO = {
        name = "Gypsum",
        name_en = "Gypsum",
        color = {245, 240, 230},
        tier = 1,
        toxicity = 0,
        cost = 0,
        origin = "mineral",
        preparation = "Calcine or grind gypsum, then levigate to produce a clean fine white mineral.",
        folio_use = {
            text = false,
            dropcaps = nil,
            borders = nil,
            corners = nil,
            miniature = nil,
        },
        effects = {
            ground = true,
        },
        description = "Utility white mineral for grounds, fillers, and gesso-related preparation work.",
    },
    
    GUSCIO_UOVO = {
        name = "Eggshell White",
        name_en = "Eggshell White",
        color = {250, 245, 235},
        tier = 1,
        toxicity = 0,
        cost = 0,
        origin = "organic",
        preparation = "Clean eggshells, remove membranes, then grind and wash to a smooth white powder.",
        folio_use = {
            text = false,
            dropcaps = nil,
            borders = nil,
            corners = nil,
            miniature = nil,
        },
        effects = {},
        description = "Fine calcium white from workshop waste, useful for subtle highlights.",
    },
    
    BIANCO_PIOMBO = {
        name = "Lead White / Cerussa",
        name_en = "Lead White / Cerussa",
        color = {250, 248, 245},
        tier = 7,
        toxicity = 3,
        cost = 40,
        origin = "artificial",
        preparation = "Produce basic lead carbonate by corrosion process, then wash and mill with care.",
        folio_use = {
            text = false,
            dropcaps = false,
            borders = false,
            corners = false,
            miniature = true,
        },
        effects = {
            highlight = true,
            flesh_base = true,
        },
        description = "Powerful opaque white for flesh and highlights, effective but highly toxic.",
    },

    
    ORO_FOGLIA = {
        name = "Gold Leaf",
        name_en = "Gold Leaf",
        color = {255, 200, 50},
        tier = 5,
        toxicity = 0,
        cost = 80,
        origin = "metal",
        preparation = "Apply bole or gesso mordant, lay leaf with a tip, then burnish after proper setting.",
        folio_use = {
            text = false,
            dropcaps = true,
            borders = true,
            corners = true,
            miniature = true,
        },
        effects = {
            burnishable = true,
            on_6 = "remove_2_stain",
        },
        description = "True metallic gold with unmatched reflectivity for initials, borders, and sacred halos.",
    },
    
    ORO_POLVERE = {
        name = "Shell Gold",
        name_en = "Shell Gold",
        color = {255, 190, 40},
        tier = 5,
        toxicity = 0,
        cost = 90,
        origin = "metal",
        preparation = "Grind gold leaf with honey or gum, wash out additives, and store as shell-gold paint.",
        folio_use = {
            text = false,
            dropcaps = true,
            borders = true,
            corners = true,
            miniature = true,
        },
        effects = {
            paint_like = true,
        },
        description = "Powdered gold paint for controlled brushwork where leaf application is impractical.",
    },
    
    ARGENTO_FOGLIA = {
        name = "Silver Leaf",
        name_en = "Silver Leaf",
        color = {200, 200, 210},
        tier = 5,
        toxicity = 0,
        cost = 50,
        origin = "metal",
        preparation = "Lay silver leaf on prepared mordant and seal it to slow oxidation and darkening.",
        folio_use = {
            text = false,
            dropcaps = true,
            borders = true,
            corners = true,
            miniature = true,
        },
        effects = {
            tarnish_risk = true,
        },
        description = "Bright metallic silver for armor and ornament, vulnerable to tarnish if left unsealed.",
    },
}


function PigmentCatalog.getByTier(tier)
    local result = {}
    local tier_names = PigmentCatalog.TIERS[tier] or {}
    for _, pigment_id in ipairs(tier_names) do
        local pigment = PigmentCatalog.data[pigment_id]
        if pigment then
            result[pigment_id] = pigment
        end
    end
    return result
end

function PigmentCatalog.getUnlockedUpTo(max_tier)
    local result = {}
    for tier = 1, max_tier do
        for pigment_id, pigment in pairs(PigmentCatalog.getByTier(tier)) do
            result[pigment_id] = pigment
        end
    end
    return result
end

function PigmentCatalog.get(pigment_id)
    return PigmentCatalog.data[pigment_id]
end

function PigmentCatalog.getByToxicity(level)
    local result = {}
    for pigment_id, pigment in pairs(PigmentCatalog.data) do
        if pigment.toxicity == level then
            result[pigment_id] = pigment
        end
    end
    return result
end

function PigmentCatalog.getSafe()
    return PigmentCatalog.getByToxicity(0)
end

function PigmentCatalog.getForFolioElement(element)
    local result = {}
    for pigment_id, pigment in pairs(PigmentCatalog.data) do
        if pigment.folio_use and pigment.folio_use[element] then
            result[pigment_id] = pigment
        end
    end
    return result
end

function PigmentCatalog.count()
    local total = 0
    for _ in pairs(PigmentCatalog.data) do
        total = total + 1
    end
    return total
end

return PigmentCatalog

