local P = require("../../src/Protocol")
local S = require("./Support")
local test = S.test
local function good(scenario)
    local request = S.request(scenario)
    local value = P.failure(request, "Observed counts", 1, "Check server Output")
    value.passed = true
    value.evidence = { initialCount = 2, finalCount = scenario == "latejoin" and 3 or 2,
        readyCount = 2, addedCount = scenario == "latejoin" and 1 or 0, retained = true }
    return value, request
end

test("plan copies only known fields and never aliases saved input", function()
    local input = { players = 4, cases = { { scenario = "spawn", timeout = 60 } }, ignored = "private" }
    local value = P.copyPlan(input)
    assert(value and value.ignored == nil)
    input.cases[1].timeout = 10
    assert(value.cases[1].timeout == 60)
end)
test("plan rejects empty, duplicate, sparse and named cases", function()
    for _, cases in ipairs({ {}, {{scenario="join",timeout=5},{scenario="join",timeout=5}},
        {[2]={scenario="join",timeout=5}}, {name={scenario="join",timeout=5}} }) do
        assert(P.copyPlan({players=2,cases=cases}) == nil)
    end
end)
test("plan rejects noninteger, out-of-range and nonfinite timeouts", function()
    for _, timeout in ipairs({4,181,5.5,math.huge,0/0,"20"}) do
        assert(P.copyPlan({players=2,cases={{scenario="spawn",timeout=timeout}}}) == nil)
    end
end)
test("slow local client startup can use the bounded 180-second budget", function()
    local plan = {players=4,cases={{scenario="latejoin",timeout=180}}}
    assert(P.copyPlan(plan).cases[1].timeout == 180)
end)
test("request refuses wrong marker, unknown scenario, invalid count and missing nonce", function()
    local request = S.request()
    for key, value in pairs({marker="RA01",scenario="unknown",players=3,runId=""}) do
        local bad = table.clone(request); bad[key] = value
        assert(not P.validRequest(bad))
    end
    assert(not P.validRequest(nil) and not P.validRequest("RA01:join:2"))
end)
test("all three success contracts accept matching measured evidence", function()
    for _, scenario in ipairs(P.SCENARIOS) do
        local value, request = good(scenario)
        assert(P.validateResult(value, request))
    end
end)
test("reject stale or mismatched result identity and plan", function()
    local value, request = good("join")
    for key, other in pairs({runId="old-run",scenario="spawn",players=4,timeout=20,version=1}) do
        local bad = table.clone(value); bad[key] = other
        assert(P.validateResult(bad, request) == nil)
    end
end)
test("never turn truthy fields into PASS", function()
    local value, request = good("join")
    for _, passed in ipairs({"true",1,{}, "PASS"}) do
        value.passed = passed
        assert(P.validateResult(value, request) == nil)
    end
end)
test("spawn success requires all expected players and characters", function()
    local value, request = good("spawn")
    value.evidence.readyCount = 0
    assert(P.validateResult(value, request) == nil)
    value.evidence.readyCount = 2; value.evidence.finalCount = 3
    assert(P.validateResult(value, request) == nil)
end)
test("latejoin success requires retention and exactly one new identity", function()
    for _, field in ipairs({"retained","addedCount","finalCount","initialCount"}) do
        local value, request = good("latejoin")
        value.evidence[field] = field == "retained" and false or 0
        assert(P.validateResult(value, request) == nil)
    end
end)
test("reject negative, NaN, infinite or late successful elapsed", function()
    local value, request = good("join")
    for _, elapsed in ipairs({-1,0/0,math.huge,6}) do
        value.elapsed = elapsed
        assert(P.validateResult(value, request) == nil)
    end
end)
test("failure retains actual elapsed time including launch or delayed cleanup", function()
    local request = S.request()
    local value = P.failure(request, "Plugin watchdog timeout", 40, "Use Studio Stop")
    assert(P.validateResult(value, request).passed == false)
    value.elapsed = 180
    assert(P.validateResult(value, request).elapsed == 180)
    value.elapsed = math.huge
    assert(P.validateResult(value, request) == nil)
end)
test("whitelist removes arbitrary payload fields from persistence", function()
    local value, request = good("join")
    value.gameSource = "secret"; value.evidence.playerName = "secret"
    local sanitized = P.validateResult(value, request)
    assert(sanitized.gameSource == nil and sanitized.evidence.playerName == nil)
end)
test("malformed result fields and oversized diagnostics are rejected", function()
    local value, request = good("join")
    value.observed = string.rep("x",513)
    assert(P.validateResult(value,request) == nil)
    value.observed = "fine"; value.evidence.finalCount = 0/0
    assert(P.validateResult(value,request) == nil)
end)
S.finish()
