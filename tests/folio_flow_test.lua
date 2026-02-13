package.path = "./?.lua;./?/init.lua;" .. package.path

if type(_G.log) ~= "function" then
    _G.log = function()
    end
end

local Folio = require("src.gameplay.folio.model")

local function assert_true(value, message)
    if not value then
        error(message or "expected true")
    end
end

local function assert_false(value, message)
    if value then
        error(message or "expected false")
    end
end

local function assert_eq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected %s, got %s)", message or "assert_eq failed", tostring(expected), tostring(actual)))
    end
end

local function make_run_setup(overrides)
    local effects = {
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
        force_borders_parity = "EVEN",
        tool_knife = false,
        tool_bonus_guard = 0,
    }

    if overrides then
        for k, v in pairs(overrides) do
            effects[k] = v
        end
    end

    return {
        cards = {},
        effects = effects,
    }
end

local function first_valid_cell(folio, element, value, color)
    local options = folio:getValidPlacements(element, value, color)
    assert_true(#options > 0, "expected at least one valid placement")
    return options[1]
end

local function test_when_first_stop_is_humid_then_one_die_stays_wet_until_next_stop()
    local folio = Folio.new("BIFOLIO", 104, make_run_setup({
        first_stop_wet_left = 1,
    }))

    local first_cell = first_valid_cell(folio, "TEXT", 1, "MARRONE")
    local ok_first = folio:addWetDie("TEXT", first_cell.row, first_cell.col, 1, "MARRONE", "OCRA_BRUNA")
    assert_true(ok_first, "first addWetDie should succeed")

    local second_cell = first_valid_cell(folio, "TEXT", 2, "VERDE")
    local ok_second = folio:addWetDie("TEXT", second_cell.row, second_cell.col, 2, "VERDE", "VERDERAME")
    assert_true(ok_second, "second addWetDie should succeed")
    assert_eq(folio:getWetCount(), 2, "two dice should be wet before first stop")

    local first_stop = folio:commitWetBuffer()
    assert_eq(first_stop.still_wet, 1, "first stop should keep one die wet")
    assert_eq(first_stop.committed, 1, "first stop should commit one die")
    assert_eq(folio:getWetCount(), 1, "one die should remain wet after first stop")

    local second_stop = folio:commitWetBuffer()
    assert_eq(second_stop.still_wet, 0, "second stop should dry fully")
    assert_eq(second_stop.committed, 1, "second stop should commit the remaining die")
    assert_eq(folio:getWetCount(), 0, "wet buffer should be empty after second stop")
end

local function test_when_turn_resets_then_preparation_is_available_again_and_guard_blocks_once()
    local folio = Folio.new("BIFOLIO", 105, make_run_setup())

    local prep_ok = folio:applyPreparation("guard")
    assert_true(prep_ok, "first preparation use should succeed")
    assert_false(folio:canUsePreparation(), "preparation should be locked for the current turn")
    assert_eq(folio:getPreparationGuard(), 1, "guard stack should be one")

    local busted = folio:addStain(1)
    assert_false(busted, "guarded stain should not bust the folio")
    assert_eq(folio.stain_count, 0, "guard should absorb the first stain")
    assert_eq(folio:getPreparationGuard(), 0, "guard should be consumed")

    local second_prep_ok = folio:applyPreparation("risk")
    assert_false(second_prep_ok, "preparation cannot be reused before turn reset")

    folio:discardWetBuffer()
    assert_true(folio:canUsePreparation(), "turn reset should re-enable preparation")

    local prep_after_reset = folio:applyPreparation("risk")
    assert_true(prep_after_reset, "preparation should work again on the next turn")
end

local function test_when_pushing_then_stop_commits_wet_buffer()
    local folio = Folio.new("BIFOLIO", 101, make_run_setup())
    local cell = first_valid_cell(folio, "TEXT", 1, "MARRONE")
    local ok = folio:addWetDie("TEXT", cell.row, cell.col, 1, "MARRONE", "OCRA_BRUNA")
    assert_true(ok, "addWetDie should succeed")
    assert_eq(folio:getWetCount(), 1, "wet buffer should contain one die")

    folio:registerPush("all")
    local summary = folio:getWetSummary()
    assert_eq(summary.pushes, 1, "push counter should increment")

    local result = folio:commitWetBuffer()
    assert_eq(result.committed, 1, "stop should commit wet buffer")
    assert_eq(result.stains_added, 0, "no risk should produce no stains")
    assert_eq(folio:getWetCount(), 0, "wet buffer should be empty after stop")

    local state = folio:getCellState("TEXT", cell.row, cell.col)
    assert_true(state and state.placed ~= nil, "cell should contain committed die")
    assert_false(state.wet, "committed die should not be wet")
end

local function test_when_push_risk_is_two_then_stop_adds_one_stain()
    local folio = Folio.new("BIFOLIO", 102, make_run_setup({
        push_risk_always = 2,
    }))
    local cell = first_valid_cell(folio, "TEXT", 2, "VERDE")
    local ok = folio:addWetDie("TEXT", cell.row, cell.col, 2, "VERDE", "VERDERAME")
    assert_true(ok, "addWetDie should succeed")

    folio:registerPush("one")
    assert_eq(folio.last_push_mode, "one", "push mode should be tracked")
    assert_eq(folio:getTurnRisk(), 2, "push risk should apply")

    local result = folio:commitWetBuffer()
    assert_eq(result.stains_added, 1, "risk 2 should convert to one stain")
    assert_eq(folio.stain_count, 1, "stain counter should increase")
end

local function test_when_roll_busts_then_wet_is_lost_and_stain_is_added()
    local folio = Folio.new("BIFOLIO", 103, make_run_setup())
    local cell = first_valid_cell(folio, "TEXT", 3, "NERO")
    local ok = folio:addWetDie("TEXT", cell.row, cell.col, 3, "NERO", "NERO_CARBONIOSO")
    assert_true(ok, "addWetDie should succeed")
    assert_eq(folio:getWetCount(), 1, "wet buffer should contain one die")

    local legal = folio:hasAnyLegalPlacement({
        { value = 6, color = "GIALLO" },
    })
    assert_false(legal, "value 6 should not be legal in TEXT at run start")

    local removed = folio:discardWetBuffer()
    assert_eq(removed, 1, "discard should remove wet die")
    assert_eq(folio:getWetCount(), 0, "wet buffer should be empty after discard")

    local busted = folio:addStain(1)
    assert_false(busted, "single stain should not bust a fresh folio")
    assert_eq(folio.stain_count, 1, "stain should be applied")
end

local tests = {
    { name = "when_pushing_then_stop_commits_wet_buffer", fn = test_when_pushing_then_stop_commits_wet_buffer },
    { name = "when_push_risk_is_two_then_stop_adds_one_stain", fn = test_when_push_risk_is_two_then_stop_adds_one_stain },
    {
        name = "when_roll_busts_then_wet_is_lost_and_stain_is_added",
        fn = test_when_roll_busts_then_wet_is_lost_and_stain_is_added,
    },
    {
        name = "when_first_stop_is_humid_then_one_die_stays_wet_until_next_stop",
        fn = test_when_first_stop_is_humid_then_one_die_stays_wet_until_next_stop,
    },
    {
        name = "when_turn_resets_then_preparation_is_available_again_and_guard_blocks_once",
        fn = test_when_turn_resets_then_preparation_is_available_again_and_guard_blocks_once,
    },
}

local failed = 0
for _, test_case in ipairs(tests) do
    local ok, err = pcall(test_case.fn)
    if ok then
        print(string.format("ok - %s", test_case.name))
    else
        failed = failed + 1
        io.stderr:write(string.format("not ok - %s: %s\n", test_case.name, tostring(err)))
    end
end

if failed > 0 then
    error(string.format("%d test(s) failed", failed))
end

print(string.format("all tests passed (%d)", #tests))
