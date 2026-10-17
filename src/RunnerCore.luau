-- No engine globals: the same assertions are exercised by the CLI mock tests.
local Core = {}

function Core.run(protocol, request, env)
    assert(protocol.validRequest(request), "Invalid scenario request")
    local started = env.now()
    local deadline = started + request.timeout
    local snapshot = env.snapshot()
    local initialCount = 0
    local addedCount = 0
    local retained = false

    local function result(passed, observed, nextCheck)
        local value = protocol.failure(request, observed, env.now() - started, nextCheck)
        value.passed = passed
        value.evidence = { initialCount = initialCount, finalCount = snapshot.count,
            readyCount = snapshot.ready, addedCount = addedCount, retained = retained }
        return value
    end

    local function waitFor(predicate)
        while env.now() < deadline do
            snapshot = env.snapshot()
            if predicate(snapshot) then return true end
            env.wait(math.min(0.1, math.max(0, deadline - env.now())))
        end
        snapshot = env.snapshot()
        return false
    end

    if not waitFor(function(value) return value.count == request.players end) then
        return result(false, string.format("Join timed out: observed %d players", snapshot.count),
            "Check Studio server/client Output and whether game code removes players.")
    end
    initialCount = snapshot.count
    if request.scenario == "join" then
        return result(true, string.format("Observed exactly %d joined players", snapshot.count), "No next check required.")
    end
    if request.scenario == "spawn" then
        local ready = waitFor(function(value) return value.count == request.players and value.ready == request.players end)
        return result(ready, string.format("Observed %d players; %d characters with Humanoids", snapshot.count, snapshot.ready),
            ready and "No next check required." or "Check Players.CharacterAutoLoads, custom character loaders, and server Output.")
    end

    local initial = snapshot.identities
    env.wait(math.min(1, math.max(0, deadline - env.now())))
    if env.now() >= deadline then
        snapshot = env.snapshot()
        return result(false, "Timeout before requesting the late player", "Increase the latejoin timeout and check initial joining.")
    end
    env.addPlayer()
    local joined = waitFor(function(value)
        addedCount = 0
        retained = true
        for identity in pairs(initial) do
            if not value.identities[identity] then retained = false end
        end
        for identity in pairs(value.identities) do
            if not initial[identity] then addedCount += 1 end
        end
        return value.count == request.players + 1 and retained and addedCount == 1
    end)
    return result(joined, string.format("Players: %d to %d; new: %d; initial retained: %s",
        initialCount, snapshot.count, addedCount, tostring(retained)),
        joined and "No next check required." or "Check AddPlayers support, new client Output, and whether initial players disconnected.")
end

return Core
