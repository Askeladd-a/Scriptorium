-- src/content/mvp_decks.lua
-- Data-driven MVP decks for Scriptorium runs.

local Decks = {}

local COMMISSIONS = {
    { id = "rubriche_richieste", name = "Rubriche richieste", text = "Ogni Rosso vale +1 qualita", effects = { quality_per_color = { ROSSO = 1 } } },
    { id = "miniatura_preziosa", name = "Miniatura preziosa", text = "Ogni Oro vale +1 qualita extra", effects = { quality_per_color = { GIALLO = 1 } } },
    { id = "no_oro", name = "No dorature", text = "Oro vietato in questo folio", effects = { forbid_colors = { GIALLO = true } } },
    { id = "oro_azzardato", name = "Oro azzardato", text = "Oro vale +2 qualita ma +1 rischio", effects = { quality_per_color = { GIALLO = 2 }, risk_on_color = { GIALLO = 1 } } },
    { id = "inchiostro_nero", name = "Inchiostro nero", text = "Nero vale +1 qualita", effects = { quality_per_color = { NERO = 1 } } },
    { id = "rosso_pericoloso", name = "Rubricatore esperto", text = "Rosso vale +1 qualita e +1 rischio", effects = { quality_per_color = { ROSSO = 1 }, risk_on_color = { ROSSO = 1 } } },
    { id = "bordi_audaci", name = "Bordi audaci", text = "Bordi danno +1 qualita per dado", effects = { quality_per_section = { BORDERS = 1 } } },
    { id = "testo_pulito", name = "Testo pulito", text = "Testo da +1 qualita per dado", effects = { quality_per_section = { TEXT = 1 } } },
    { id = "miniatura_varia", name = "Miniatura varia", text = "Miniatura da +1 qualita per dado", effects = { quality_per_section = { MINIATURE = 1 } } },
    { id = "capilettera_ricchi", name = "Capilettera ricchi", text = "Dropcaps da +1 qualita per dado", effects = { quality_per_section = { DROPCAPS = 1 } } },
    { id = "ostinazione", name = "Cliente ostinato", text = "Ogni PUSH +1 rischio", effects = { push_risk_always = 1 } },
    { id = "copista_lieve", name = "Cliente benevolo", text = "Soglia wet sicura +1", effects = { safe_wet_threshold_bonus = 1 } },
}

local PARCHMENTS = {
    { id = "umidita", name = "Pergamena umida", text = "Primo STOP lascia 1 dado ancora wet", effects = { first_stop_wet_left = 1 } },
    { id = "grana_ruvida", name = "Grana ruvida", text = "Ogni valore 1 aumenta rischio", effects = { risk_on_value = { [1] = 1 } } },
    { id = "fibre_fragili", name = "Fibre fragili", text = "Ogni dado nei Bordi aumenta rischio", effects = { risk_on_section = { BORDERS = 1 } } },
    { id = "vellum_fine", name = "Vellum fine", text = "Soglia wet sicura +1", effects = { safe_wet_threshold_bonus = 1 } },
    { id = "pergamena_stabile", name = "Pergamena stabile", text = "Rischio da over-wet ridotto", effects = { safe_wet_threshold_bonus = 2 } },
    { id = "inchiostro_acido", name = "Inchiostro acido", text = "Ogni Rosso aumenta rischio", effects = { risk_on_color = { ROSSO = 1 } } },
    { id = "trattata_allume", name = "Trattata con allume", text = "Ogni Verde vale +1 qualita", effects = { quality_per_color = { VERDE = 1 } } },
    { id = "patina_scura", name = "Patina scura", text = "Ogni Nero vale +1 qualita", effects = { quality_per_color = { NERO = 1 } } },
    { id = "margini_larghi", name = "Margini larghi", text = "Bordi richiedono pari", effects = { force_borders_parity = "EVEN" } },
    { id = "margini_stretti", name = "Margini stretti", text = "Bordi richiedono dispari", effects = { force_borders_parity = "ODD" } },
    { id = "assorbente", name = "Pergamena assorbente", text = "Primo STOP riduce rischio di 1", effects = { stop_risk_reduction = 1 } },
    { id = "calligrafica", name = "Pergamena calligrafica", text = "Testo da +1 qualita per dado", effects = { quality_per_section = { TEXT = 1 } } },
}

local TOOLS = {
    { id = "coltellino", name = "Coltellino", text = "1/folio: riduci di 1 un dado in auto-place", uses_per_folio = 1, effects = { tool_coltellino = true } },
    { id = "sabbia", name = "Sabbia", text = "1/folio: STOP riduce rischio di 2", uses_per_folio = 1, effects = { tool_stop_risk_reduction = 2 } },
    { id = "pennino_fine", name = "Pennino fine", text = "Soglia wet sicura +1", uses_per_folio = 0, effects = { safe_wet_threshold_bonus = 1 } },
    { id = "raschietto", name = "Raschietto", text = "1/folio: ignora una macchia futura", uses_per_folio = 1, effects = { tool_bonus_guard = 1 } },
    { id = "calamaio_rosso", name = "Calamaio rosso", text = "Rosso vale +1 qualita", uses_per_folio = 0, effects = { quality_per_color = { ROSSO = 1 } } },
    { id = "regolo", name = "Regolo", text = "Ogni PUSH +0 rischio (stabile)", uses_per_folio = 0, effects = { push_risk_always = 0 } },
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
        tool_coltellino = false,
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
            if effects.tool_coltellino then
                out.tool_coltellino = true
            end
            if type(effects.tool_bonus_guard) == "number" then
                out.tool_bonus_guard = out.tool_bonus_guard + effects.tool_bonus_guard
            end
        end
    end

    return out
end

function Decks.draw_run_setup(seed)
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

function Decks.get_decks()
    return {
        commissions = COMMISSIONS,
        parchments = PARCHMENTS,
        tools = TOOLS,
    }
end

return Decks
