local Decks = {}

local COMMISSIONS = {
    { id = "required_rubrics", name = "Required Rubrics", text = "Each red die grants +1 quality", effects = { quality_per_color = { ROSSO = 1 } } },
    { id = "precious_miniature", name = "Precious Miniature", text = "Each gold die grants +1 extra quality", effects = { quality_per_color = { GIALLO = 1 } } },
    { id = "no_gold", name = "No Gold Leaf", text = "Gold is forbidden in this folio", effects = { forbid_colors = { GIALLO = true } } },
    { id = "risky_gold", name = "Risky Gold", text = "Gold grants +2 quality but +1 risk", effects = { quality_per_color = { GIALLO = 2 }, risk_on_color = { GIALLO = 1 } } },
    { id = "black_ink", name = "Black Ink", text = "Black grants +1 quality", effects = { quality_per_color = { NERO = 1 } } },
    { id = "expert_rubricator", name = "Expert Rubricator", text = "Red grants +1 quality and +1 risk", effects = { quality_per_color = { ROSSO = 1 }, risk_on_color = { ROSSO = 1 } } },
    { id = "bold_borders", name = "Bold Borders", text = "Borders grant +1 quality per die", effects = { quality_per_section = { BORDERS = 1 } } },
    { id = "clean_text", name = "Clean Text", text = "Text grants +1 quality per die", effects = { quality_per_section = { TEXT = 1 } } },
    { id = "varied_miniature", name = "Varied Miniature", text = "Miniature grants +1 quality per die", effects = { quality_per_section = { MINIATURE = 1 } } },
    { id = "rich_dropcaps", name = "Rich Dropcaps", text = "Dropcaps grant +1 quality per die", effects = { quality_per_section = { DROPCAPS = 1 } } },
    { id = "stubborn_patron", name = "Stubborn Patron", text = "Each PUSH adds +1 risk", effects = { push_risk_always = 1 } },
    { id = "kind_patron", name = "Kind Patron", text = "Safe wet threshold +1", effects = { safe_wet_threshold_bonus = 1 } },
}

local PARCHMENTS = {
    { id = "humidity", name = "Humid Parchment", text = "First STOP keeps 1 die wet", effects = { first_stop_wet_left = 1 } },
    { id = "rough_grain", name = "Rough Grain", text = "Each value 1 adds +1 risk", effects = { risk_on_value = { [1] = 1 } } },
    { id = "fragile_fibers", name = "Fragile Fibers", text = "Each die in Borders adds +1 risk", effects = { risk_on_section = { BORDERS = 1 } } },
    { id = "fine_vellum", name = "Fine Vellum", text = "Safe wet threshold +1", effects = { safe_wet_threshold_bonus = 1 } },
    { id = "stable_parchment", name = "Stable Parchment", text = "Over-wet risk reduced", effects = { safe_wet_threshold_bonus = 2 } },
    { id = "acidic_ink", name = "Acidic Ink", text = "Each red die adds +1 risk", effects = { risk_on_color = { ROSSO = 1 } } },
    { id = "alum_treated", name = "Alum Treated", text = "Each green die grants +1 quality", effects = { quality_per_color = { VERDE = 1 } } },
    { id = "dark_patina", name = "Dark Patina", text = "Each black die grants +1 quality", effects = { quality_per_color = { NERO = 1 } } },
    { id = "wide_margins", name = "Wide Margins", text = "Borders require even values", effects = { force_borders_parity = "EVEN" } },
    { id = "tight_margins", name = "Tight Margins", text = "Borders require odd values", effects = { force_borders_parity = "ODD" } },
    { id = "absorbent", name = "Absorbent Parchment", text = "First STOP reduces risk by 1", effects = { stop_risk_reduction = 1 } },
    { id = "calligraphic", name = "Calligraphic Parchment", text = "Text grants +1 quality per die", effects = { quality_per_section = { TEXT = 1 } } },
}

local TOOLS = {
    { id = "knife", name = "Knife", text = "1/folio: reduce one auto-placed die by 1", uses_per_folio = 1, effects = { tool_knife = true } },
    { id = "sand", name = "Sand", text = "1/folio: STOP reduces risk by 2", uses_per_folio = 1, effects = { tool_stop_risk_reduction = 2 } },
    { id = "fine_nib", name = "Fine Nib", text = "Safe wet threshold +1", uses_per_folio = 0, effects = { safe_wet_threshold_bonus = 1 } },
    { id = "scraper", name = "Scraper", text = "1/folio: ignore one future stain", uses_per_folio = 1, effects = { tool_bonus_guard = 1 } },
    { id = "red_inkwell", name = "Red Inkwell", text = "Red grants +1 quality", uses_per_folio = 0, effects = { quality_per_color = { ROSSO = 1 } } },
    { id = "ruler", name = "Ruler", text = "Each PUSH adds +0 risk (stable)", uses_per_folio = 0, effects = { push_risk_always = 0 } },
}

local function make_rng(seed)
    local state = math.floor(tonumber(seed) or os.time()) % 2147483647
    if state <= 0 then
        state = 1
    end
    return function(max_n)
        state = (state * 48271) % 2147483647
        if not max_n or max_n <= 1 then
            return 1
        end
        return (state % max_n) + 1
    end
end

local function pick_one(deck, rng)
    local idx = rng(#deck)
    return deck[idx]
end

local function merge_map(dst, src)
    if not src then
        return
    end
    for key, value in pairs(src) do
        if type(value) == "number" then
            dst[key] = (dst[key] or 0) + value
        elseif type(value) == "boolean" then
            dst[key] = value
        else
            dst[key] = value
        end
    end
end

local function merge_effects(cards)
    local out = {
        simple_sections = true,
        ignore_pattern_constraints = true,
        forbid_colors = {},
        quality_per_color = {},
        quality_per_section = {},
        risk_on_color = {},
        risk_on_value = {},
        risk_on_section = {},
        safe_wet_threshold_bonus = 0,
        push_risk_always = nil,
        first_stop_wet_left = 0,
        stop_risk_reduction = 0,
        tool_stop_risk_reduction = 0,
        force_borders_parity = nil,
        tool_knife = false,
        tool_bonus_guard = 0,
    }

    for _, card in ipairs(cards) do
        local effects = card and card.effects or nil
        if effects then
            merge_map(out.forbid_colors, effects.forbid_colors)
            merge_map(out.quality_per_color, effects.quality_per_color)
            merge_map(out.quality_per_section, effects.quality_per_section)
            merge_map(out.risk_on_color, effects.risk_on_color)
            merge_map(out.risk_on_value, effects.risk_on_value)
            merge_map(out.risk_on_section, effects.risk_on_section)

            if type(effects.safe_wet_threshold_bonus) == "number" then
                out.safe_wet_threshold_bonus = out.safe_wet_threshold_bonus + effects.safe_wet_threshold_bonus
            end
            if type(effects.first_stop_wet_left) == "number" then
                out.first_stop_wet_left = out.first_stop_wet_left + effects.first_stop_wet_left
            end
            if type(effects.stop_risk_reduction) == "number" then
                out.stop_risk_reduction = out.stop_risk_reduction + effects.stop_risk_reduction
            end
            if type(effects.tool_stop_risk_reduction) == "number" then
                out.tool_stop_risk_reduction = out.tool_stop_risk_reduction + effects.tool_stop_risk_reduction
            end
            if type(effects.push_risk_always) == "number" then
                out.push_risk_always = effects.push_risk_always
            end
            if type(effects.force_borders_parity) == "string" then
                out.force_borders_parity = effects.force_borders_parity
            end
            if effects.tool_knife then
                out.tool_knife = true
            end
            if type(effects.tool_bonus_guard) == "number" then
                out.tool_bonus_guard = out.tool_bonus_guard + effects.tool_bonus_guard
            end
        end
    end

    return out
end

function Decks.drawRunSetup(seed)
    local rng = make_rng(seed)
    local commission = pick_one(COMMISSIONS, rng)
    local parchment = pick_one(PARCHMENTS, rng)
    local tool = pick_one(TOOLS, rng)
    local cards = { commission = commission, parchment = parchment, tool = tool }
    local effects = merge_effects({ commission, parchment, tool })
    return {
        cards = cards,
        effects = effects,
    }
end

function Decks.getDecks()
    return {
        commissions = COMMISSIONS,
        parchments = PARCHMENTS,
        tools = TOOLS,
    }
end

return Decks
