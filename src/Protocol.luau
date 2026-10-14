-- Shared, engine-independent v0.2 wire contract. Never infer success from truthiness.
local Protocol = {}
Protocol.MARKER = "RegressionArenaV02"
Protocol.VERSION = 2
Protocol.MIN_TIMEOUT = 5
Protocol.MAX_TIMEOUT = 180
Protocol.MAX_REPORT_BYTES = 8192
Protocol.HISTORY_LIMIT = 10
Protocol.SCENARIOS = { "join", "spawn", "latejoin" }

local function integer(value, low, high)
    return type(value) == "number" and value == value and value >= low and value <= high and value % 1 == 0
end

local function text(value)
    return type(value) == "string" and #value > 0 and #value <= 512
end

function Protocol.validCase(value)
    return value == "join" or value == "spawn" or value == "latejoin"
end

function Protocol.validPlayers(value)
    return value == 1 or value == 2 or value == 4
end

function Protocol.validRequest(value)
    return type(value) == "table" and value.marker == Protocol.MARKER and value.version == Protocol.VERSION
        and type(value.runId) == "string" and #value.runId >= 1 and #value.runId <= 64
        and Protocol.validCase(value.scenario) and Protocol.validPlayers(value.players)
        and integer(value.timeout, Protocol.MIN_TIMEOUT, Protocol.MAX_TIMEOUT)
end

function Protocol.copyPlan(value)
    if type(value) ~= "table" or not Protocol.validPlayers(value.players) or type(value.cases) ~= "table" then
        return nil
    end
    local count, seen, cases = 0, {}, {}
    for key, case in pairs(value.cases) do
        if not integer(key, 1, 3) or type(case) ~= "table" or not Protocol.validCase(case.scenario)
            or seen[case.scenario] or not integer(case.timeout, Protocol.MIN_TIMEOUT, Protocol.MAX_TIMEOUT) then
            return nil
        end
        count += 1
        seen[case.scenario] = true
        cases[key] = { scenario = case.scenario, timeout = case.timeout }
    end
    if count == 0 or count > 3 then return nil end
    for index = 1, count do
        if cases[index] == nil then return nil end
    end
    return { players = value.players, cases = cases }
end

function Protocol.expected(request)
    if request.scenario == "spawn" then
        return string.format("Exactly %d players with parented characters and Humanoids", request.players)
    elseif request.scenario == "latejoin" then
        return string.format("Keep %d initial players and add exactly one new player", request.players)
    end
    return string.format("Exactly %d players joined", request.players)
end

function Protocol.failure(request, observed, elapsed, nextCheck)
    return {
        marker = Protocol.MARKER, version = Protocol.VERSION, runId = request.runId,
        scenario = request.scenario, players = request.players, timeout = request.timeout,
        passed = false, expected = Protocol.expected(request), observed = observed,
        elapsed = elapsed or 0, nextCheck = nextCheck,
        evidence = { initialCount = 0, finalCount = 0, readyCount = 0, addedCount = 0, retained = false },
    }
end

function Protocol.validateResult(value, request)
    if type(value) ~= "table" or not Protocol.validRequest(value) then return nil end
    for _, field in ipairs({ "runId", "scenario", "players", "timeout" }) do
        if value[field] ~= request[field] then return nil end
    end
    if type(value.passed) ~= "boolean" or not text(value.expected) or not text(value.observed)
        or not text(value.nextCheck) or type(value.elapsed) ~= "number" or value.elapsed ~= value.elapsed
        or value.elapsed < 0 or value.elapsed >= math.huge then return nil end
    local evidence = value.evidence
    if type(evidence) ~= "table" or type(evidence.retained) ~= "boolean" then return nil end
    for _, field in ipairs({ "initialCount", "finalCount", "readyCount", "addedCount" }) do
        if not integer(evidence[field], 0, 8) then return nil end
    end
    if evidence.readyCount > evidence.finalCount then return nil end
    if value.passed then
        if evidence.initialCount ~= request.players or value.elapsed > request.timeout then return nil end
        if request.scenario == "latejoin" then
            if evidence.finalCount ~= request.players + 1 or evidence.addedCount ~= 1 or not evidence.retained then
                return nil
            end
        elseif evidence.finalCount ~= request.players then
            return nil
        elseif request.scenario == "spawn" and evidence.readyCount ~= request.players then
            return nil
        end
    end
    return {
        marker = Protocol.MARKER, version = Protocol.VERSION, runId = request.runId,
        scenario = request.scenario, players = request.players, timeout = request.timeout, passed = value.passed,
        expected = value.expected, observed = value.observed, elapsed = value.elapsed, nextCheck = value.nextCheck,
        evidence = { initialCount = evidence.initialCount, finalCount = evidence.finalCount,
            readyCount = evidence.readyCount, addedCount = evidence.addedCount, retained = evidence.retained },
    }
end

return Protocol
