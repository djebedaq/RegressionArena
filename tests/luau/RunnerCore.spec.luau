local P = require("../../src/Protocol")
local Core = require("../../src/RunnerCore")
local S = require("./Support")
local function run(scenario, players, options)
    options = options or {}
    local time, added = 0, false
    local request = S.request(scenario, players, options.timeout or 5)
    local result = Core.run(P, request, {
        now = function() return time end,
        wait = function(seconds) time += seconds end,
        snapshot = function() return options.snapshot and options.snapshot(time,added) or S.snapshot(players == 1 and {"a"} or players == 4 and {"a","b","c","d"} or {"a","b"}) end,
        addPlayer = function()
            if options.addError then error("AddPlayers denied") end
            added = true
        end,
    })
    assert(P.validateResult(result,request), "Core emitted invalid result")
    return result
end
S.test("join and spawn pass for exactly 1, 2 and 4 players", function()
    for _, count in ipairs({1,2,4}) do
        assert(run("join",count).passed and run("spawn",count).passed)
    end
end)
S.test("zero or insufficient players time out with counts", function()
    local value = run("join",2,{snapshot=function() return S.snapshot({"a"}) end})
    assert(not value.passed and value.evidence.finalCount == 1 and value.elapsed >= 5)
end)
S.test("extra players cannot satisfy exact count", function()
    assert(not run("join",2,{snapshot=function() return S.snapshot({"a","b","c"}) end}).passed)
end)
S.test("CharacterAutoLoads false is a reproducible failing spawn", function()
    local value = run("spawn",2,{snapshot=function() return S.snapshot({"a","b"},0) end})
    assert(not value.passed and value.evidence.readyCount == 0)
    assert(string.find(value.nextCheck,"CharacterAutoLoads",1,true))
end)
S.test("partial spawn fails with useful readiness count", function()
    local value = run("spawn",2,{snapshot=function() return S.snapshot({"a","b"},1) end})
    assert(not value.passed and value.evidence.readyCount == 1)
end)
S.test("disconnected players cannot make empty spawn vacuously pass", function()
    local value = run("spawn",2,{snapshot=function(time) return time < 1 and S.snapshot({"a","b"},0) or S.snapshot({},0) end})
    assert(not value.passed)
end)
S.test("all phases share one bounded timeout", function()
    local value = run("spawn",2,{snapshot=function(time)
        return time < 4.5 and S.snapshot({},0) or S.snapshot({"a","b"},0)
    end})
    assert(not value.passed and value.elapsed >= 5 and value.elapsed < 5.2)
end)
S.test("condition first observed at deadline fails", function()
    local value = run("spawn",2,{snapshot=function(time) return S.snapshot({"a","b"},time >= 5 and 2 or 0) end})
    assert(not value.passed)
end)
S.test("latejoin adds exactly one after baseline for all player modes", function()
    for _, count in ipairs({1,2,4}) do
        local initial = count == 1 and {"a"} or count == 4 and {"a","b","c","d"} or {"a","b"}
        local value = run("latejoin",count,{snapshot=function(_,added)
            local ids=table.clone(initial); if added then table.insert(ids,"late") end
            return S.snapshot(ids)
        end})
        assert(value.passed and value.evidence.addedCount == 1 and value.elapsed >= 1)
    end
end)
S.test("latejoin fails when AddPlayers adds nobody", function()
    assert(not run("latejoin",2).passed)
end)
S.test("latejoin count cannot hide replacement of an initial player", function()
    local value = run("latejoin",2,{snapshot=function(_,added)
        return S.snapshot(added and {"a","replacement","late"} or {"a","b"})
    end})
    assert(not value.passed and not value.evidence.retained)
end)
S.test("AddPlayers API errors propagate to protected server boundary", function()
    assert(not pcall(function() run("latejoin",2,{addError=true}) end))
end)
S.finish()
