-- Regression Arena v0.2. Offline Studio smoke tests. Generated distribution includes the runner.
local StudioTestService = game:GetService("StudioTestService")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local ScriptEditorService = game:GetService("ScriptEditorService")
local Protocol = (function()
-- Shared, engine-independent v0.2 wire contract. Never infer success from truthiness.
local Protocol = {}
Protocol.MARKER = "RegressionArenaV02"
Protocol.VERSION = 2
Protocol.MIN_TIMEOUT = 5
Protocol.MAX_TIMEOUT = 60
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

end)()
local Manager = (function()
-- Fail closed on collisions, duplicates, unsupported versions, edits, or child content.
local Manager = {}
Manager.NAME = "RegressionArena_TestRunner"
Manager.OWNER = "RegressionArena"
Manager.VERSION = "0.2.0"

function Manager.find(env, source)
    local found = nil
    for _, child in ipairs(env.container:GetChildren()) do
        if child.Name == Manager.NAME then
            if found then error("Duplicate runner names: inspect Explorer before continuing.") end
            found = child
        end
    end
    if found and (not found:IsA("Script") or found:GetAttribute("RAOwner") ~= Manager.OWNER
        or found:GetAttribute("RAVersion") ~= Manager.VERSION or found.Source ~= source
        or env.editorSource(found) ~= source or #found:GetChildren() ~= 0) then
        error("Runner name collision or modified/unsupported runner. Nothing changed; inspect Explorer and preserve your content.")
    end
    return found
end

function Manager.change(env, source, remove)
    if not env.isEdit() then error("Return to Studio edit mode before changing the runner.") end
    local runner = Manager.find(env, source)
    if remove and not runner then return "No owned runner installed." end
    if not remove and runner and runner.Enabled and runner.RunContext == env.legacyContext then
        return "Runner 0.2.0 is already current."
    end
    local candidate = nil
    if not remove and not runner then
        candidate = env.newScript()
        local ok, err = pcall(function()
            candidate.Name = Manager.NAME
            candidate.Enabled = false
            candidate.RunContext = env.legacyContext
            candidate.Source = source
            candidate:SetAttribute("RAOwner", Manager.OWNER)
            candidate:SetAttribute("RAVersion", Manager.VERSION)
        end)
        if not ok then candidate:Destroy(); error(err) end
    end
    local begun, recording = pcall(env.beginRecording)
    if not begun or not recording then
        if candidate then candidate:Destroy() end
        error("Could not begin undo recording; runner unchanged.")
    end
    local oldEnabled = runner and runner.Enabled
    local oldContext = runner and runner.RunContext
    local ok, err = pcall(function()
        if remove then
            runner.Parent = nil
        elseif candidate then
            candidate.Enabled = true
            candidate.Parent = env.container
        else
            runner.RunContext = env.legacyContext
            runner.Enabled = true
        end
        env.finishRecording(recording, true)
    end)
    if not ok then
        local restored, restoreError = pcall(function()
            if candidate then candidate:Destroy() end
            if runner then
                runner.Parent = env.container
                runner.RunContext = oldContext
                runner.Enabled = oldEnabled
            end
        end)
        pcall(env.finishRecording, recording, false)
        error(tostring(err) .. (restored and "" or "; rollback failed: " .. tostring(restoreError)))
    end
    return remove and "Owned runner removed. Undo is available." or "Runner 0.2.0 ready. Undo is available."
end

return Manager

end)()
local Session = (function()
-- Own exactly one native Execute call. A timed-out coroutine is not assumed to be cancelled.
local Session = {}
Session.__index = Session
Session.STARTUP_ALLOWANCE = 30
Session.CLEANUP_ALLOWANCE = 5

function Session.new(protocol, env)
    return setmetatable({ protocol = protocol, env = env, pending = nil, disposed = false }, Session)
end

function Session:ready()
    if self.disposed then return false end
    if self.pending and self.pending.done and self.env.isEdit() then self.pending = nil end
    return self.pending == nil and self.env.isEdit()
end

function Session:cancel()
    local operation = self.pending
    if not operation then return end
    operation.cancelled = true
    local ok, err = pcall(function()
        if self.env.canLeave() then self.env.leave() end
    end)
    if not ok then self:logError(err) end
end

function Session:logError(message)
    if self.env.logError then pcall(self.env.logError, tostring(message):sub(1, 512)) end
end

function Session:dispose()
    self.disposed = true
    self:cancel()
end

function Session:run(request)
    local protocol, env = self.protocol, self.env
    local started = env.now()
    local function fail(message)
        return protocol.failure(request, message, env.now() - started,
            "Check Studio Output. Use Studio Stop if still testing, then retry after edit mode returns."), true
    end
    if not self:ready() then return fail("Previous native test is still pending, or Studio is not in edit mode") end
    local operation = { done = false, cancelled = false }
    self.pending = operation
    env.spawn(function()
        operation.ok, operation.raw = pcall(function() return env.execute(request.players, env.encode(request)) end)
        operation.done = true
    end)
    local deadline = started + request.timeout + Session.STARTUP_ALLOWANCE
    while not operation.done and not operation.cancelled and env.now() < deadline do env.wait(0.1) end
    -- A completion observed after the plugin deadline cannot bypass the watchdog.
    local timedOut = not operation.cancelled and env.now() >= deadline
    if timedOut then self:cancel() end
    if operation.done and not operation.cancelled then
        -- Execute can return just before Studio exposes edit mode. Allow that transition to settle.
        local settleDeadline = env.now() + Session.CLEANUP_ALLOWANCE
        while not env.isEdit() and env.now() < settleDeadline do env.wait(0.1) end
    end
    if operation.cancelled or not env.isEdit() then
        self:cancel()
        local cleanupDeadline = env.now() + Session.CLEANUP_ALLOWANCE
        while (not operation.done or not env.isEdit()) and env.now() < cleanupDeadline do env.wait(0.1) end
    end
    local recovered = operation.done and env.isEdit()
    if recovered then self.pending = nil end
    if timedOut then return fail("Plugin watchdog timeout; no verified scenario result") end
    if operation.cancelled then return fail("Test cancelled or session cleanup was required; result discarded") end
    if not recovered then return fail("Native test did not return safely to edit mode") end
    if not operation.ok then
        self:logError(operation.raw)
        return fail("ExecuteMultiplayerTestAsync failed; no verified result")
    end
    if type(operation.raw) ~= "string" or #operation.raw > protocol.MAX_REPORT_BYTES then
        return fail("Unexpected or oversized EndTest result")
    end
    local decoded, value = pcall(env.decode, operation.raw)
    local validated = decoded and protocol.validateResult(value, request) or nil
    if not validated then return fail("Malformed, stale, or unproven EndTest result") end
    return validated, false
end

return Session

end)()
local Settings = (function()
-- Bounded, whitelisted local history. JSON and plugin APIs are injected by the UI.
local Settings = {}

function Settings.save(value, write, read)
    local written = pcall(write, value)
    if not written then return false end
    local ok, stored = pcall(read)
    if not ok or type(stored) ~= type(value) then return false end
    if type(value) == "string" then return stored == value end
    if type(value) ~= "table" or #stored ~= #value then return false end
    for index = 1, #value do
        if stored[index] ~= value[index] then return false end
    end
    return true
end

function Settings.decode(raw, limit, decode)
    if type(raw) ~= "string" or #raw > limit then return nil end
    local ok, value = pcall(decode, raw)
    return ok and value or nil
end

function Settings.summary(protocol, value)
    if type(value) ~= "table" or value.version ~= 2 or not protocol.validPlayers(value.players)
        or type(value.tests) ~= "table" then return nil end
    local count = 0
    for key in pairs(value.tests) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > 3 then return nil end
        count += 1
    end
    if count < 1 or count > 3 then return nil end
    local safe = { version = 2, players = value.players, tests = {}, total = count, passed = 0 }
    local seen = {}
    for index = 1, count do
        local item = value.tests[index]
        local result = protocol.validRequest(item) and protocol.validateResult(item, item) or nil
        if not result or result.players ~= value.players or seen[result.scenario] then return nil end
        seen[result.scenario] = true
        table.insert(safe.tests, result)
        if result.passed then safe.passed += 1 end
    end
    if type(value.dateUTC) == "string" and string.match(value.dateUTC, "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$") then
        safe.dateUTC = value.dateUTC
    end
    return safe
end

function Settings.history(protocol, stored, decode, encode)
    local history = {}
    if type(stored) ~= "table" then return history end
    for index = 1, math.min(#stored, protocol.HISTORY_LIMIT) do
        local value = Settings.decode(stored[index], protocol.MAX_REPORT_BYTES, decode)
        local safe = Settings.summary(protocol, value)
        if safe then
            local ok, encoded = pcall(encode, safe)
            if ok and type(encoded) == "string" and #encoded <= protocol.MAX_REPORT_BYTES then
                table.insert(history, encoded)
            end
        end
    end
    return history
end

function Settings.push(protocol, history, summary, encode)
    local safe = Settings.summary(protocol, summary)
    if not safe then return false end
    local ok, encoded = pcall(encode, safe)
    if not ok or type(encoded) ~= "string" or #encoded > protocol.MAX_REPORT_BYTES then return false end
    table.insert(history, 1, encoded)
    while #history > protocol.HISTORY_LIMIT do table.remove(history) end
    return true
end

return Settings

end)()
local RUNNER_SOURCE = [==[
-- Regression Arena runner 0.2.0. Only an explicitly marked Studio server test may act.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() or not RunService:IsServer() then return end

local StudioTestService = game:GetService("StudioTestService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Protocol = (function()
-- Shared, engine-independent v0.2 wire contract. Never infer success from truthiness.
local Protocol = {}
Protocol.MARKER = "RegressionArenaV02"
Protocol.VERSION = 2
Protocol.MIN_TIMEOUT = 5
Protocol.MAX_TIMEOUT = 60
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

end)()
local Core = (function()
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

end)()

-- No speculative polling in ordinary playtests. A missing marker means no action.
local argsOK, raw = pcall(function() return StudioTestService:GetTestArgs() end)
if not argsOK or type(raw) ~= "string" or #raw > 2048 then return end
local decoded, request = pcall(function() return HttpService:JSONDecode(raw) end)
if not decoded or not Protocol.validRequest(request) then return end

local started = os.clock()
local finalized = false
local function snapshot()
    local players = Players:GetPlayers()
    local identities, ready = {}, 0
    for _, player in ipairs(players) do
        identities[player] = true -- In-memory identity only; never put in the result.
        local character = player.Character
        if character and character.Parent and character:FindFirstChildOfClass("Humanoid") then ready += 1 end
    end
    return { count = #players, ready = ready, identities = identities }
end
local function finish(value)
    if finalized then return end
    finalized = true
    local ok, err = pcall(function()
        StudioTestService:EndTest(HttpService:JSONEncode(value))
    end)
    if not ok then
        warn("Regression Arena: EndTest failed; plugin watchdog must stop this test.", err)
        -- Never resend a PASS after an ambiguous EndTest failure.
        pcall(function()
            if StudioTestService:CanLeaveTest() then StudioTestService:LeaveTest() end
        end)
    end
end

task.delay(request.timeout, function()
    if finalized then return end
    local value = Protocol.failure(request, "Server scenario deadline exceeded", os.clock() - started,
        request.scenario == "spawn" and "Check Players.CharacterAutoLoads, custom character loaders, and server Output."
            or "Check initial joining, AddPlayers for latejoin, and server Output for blocked API calls.")
    local measured, view = pcall(snapshot)
    if measured then
        value.observed = string.format("Server deadline exceeded: %d players; %d characters with Humanoids", view.count, view.ready)
        value.evidence.finalCount = view.count
        value.evidence.readyCount = view.ready
    end
    finish(value)
end)

local ok, value = pcall(function()
    return Core.run(Protocol, request, {
        now = os.clock,
        wait = task.wait,
        addPlayer = function() StudioTestService:AddPlayers(1) end,
        snapshot = snapshot,
    })
end)
if not ok then
    warn("Regression Arena: scenario API/runtime error.", value)
    value = Protocol.failure(request, "Server scenario API/runtime error", os.clock() - started,
        "Read server Output; check StudioTestService:AddPlayers support for latejoin.")
end
finish(value)

]==]
local HISTORY_KEY = "regression-arena-v02-history"
local PRESET_KEY = "regression-arena-v02-preset"
local disposed, busy, stopRequested = false, false, false
local history = {}

local function isEdit()
    local ok, value = pcall(function() return StudioTestService.EditModeActive end)
    return ok and value == true and not RunService:IsRunning()
end

local session = Session.new(Protocol, {
    now = os.clock, wait = task.wait, spawn = task.spawn,
    isEdit = isEdit,
    canLeave = function() return StudioTestService:CanLeaveTest() end,
    leave = function() StudioTestService:LeaveTest() end,
    logError = function(message) warn("Regression Arena: Studio session API error.", message) end,
    execute = function(players, payload) return StudioTestService:ExecuteMultiplayerTestAsync(players, payload) end,
    encode = function(value) return HttpService:JSONEncode(value) end,
    decode = function(value) return HttpService:JSONDecode(value) end,
})
local managerEnv = {
    container = ServerScriptService, isEdit = isEdit,
    editorSource = function(runner) return ScriptEditorService:GetEditorSource(runner) end,
    legacyContext = Enum.RunContext.Legacy,
    newScript = function() return Instance.new("Script") end,
    beginRecording = function() return ChangeHistoryService:TryBeginRecording("RegressionArenaRunner", "Regression Arena runner") end,
    finishRecording = function(recording, commit)
        ChangeHistoryService:FinishRecording(recording, commit and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
    end,
}

local palette = {
    panel = Color3.fromRGB(27, 32, 42), card = Color3.fromRGB(39, 47, 61),
    text = Color3.fromRGB(241, 245, 251), secondary = Color3.fromRGB(175, 190, 212),
    blue = Color3.fromRGB(74, 136, 230), green = Color3.fromRGB(92, 199, 155), red = Color3.fromRGB(245, 122, 122),
}
local toolbar = plugin:CreateToolbar("Regression Arena")
local openButton = toolbar:CreateButton("Regression Arena", "Open local multiplayer test plan", "")
openButton.ClickableWhenViewportHidden = true
local widget = plugin:CreateDockWidgetPluginGuiAsync("RegressionArenaPanel02",
    DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 380, 650, 300, 300))
widget.Title = "Regression Arena - v0.2"
local root = Instance.new("ScrollingFrame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = palette.panel
root.BorderSizePixel = 0
root.ScrollBarThickness = 6
root.CanvasSize = UDim2.new()
root.AutomaticCanvasSize = Enum.AutomaticSize.Y
root.Parent = widget
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = root
local pad = Instance.new("UIPadding")
pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 16)
pad.Parent = root
local order = 0
local function place(item, height)
    order += 1
    item.LayoutOrder = order
    item.Size = UDim2.new(1, 0, 0, height)
    item.Parent = root
    return item
end
local function label(value, height)
    local item = Instance.new("TextLabel")
    item.BackgroundTransparency = 1
    item.TextColor3 = palette.text
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.TextWrapped = true
    item.Font = Enum.Font.Gotham
    item.TextSize = 12
    item.Text = value
    return place(item, height)
end
local controls = {}
local function button(value, callback)
    local item = Instance.new("TextButton")
    item.BackgroundColor3 = palette.card
    item.BorderSizePixel = 0
    item.TextColor3 = palette.text
    item.TextSize = 13
    item.Font = Enum.Font.GothamBold
    item.Text = value
    place(item, 30)
    table.insert(controls, item)
    item.MouseButton1Click:Connect(function()
        if not disposed and not busy then callback() end
    end)
    return item
end

label("Multiplayer Test Plan", 24).TextSize = 18
label("Local tests only. Use a disposable place copy: your game's own scripts still run.", 36)
local status -- Filled before callbacks can be invoked.
local function notify(message, failed)
    if disposed then return end
    status.Text = message
    status.TextColor3 = failed and palette.red or palette.secondary
end
local function changeRunner(remove)
    local ok, message = pcall(function()
        if not session:ready() then error("Wait for the current native test to return to edit mode.") end
        return Manager.change(managerEnv, RUNNER_SOURCE, remove)
    end)
    notify(tostring(message):sub(1, 512), not ok)
end
button("Install / update owned test runner", function() changeRunner(false) end)
button("Remove owned test runner", function() changeRunner(true) end)
local playerOptions, playerIndex = { 1, 2, 4 }, 2
local playerButton
playerButton = button("Players: 2 (click to switch)", function()
    playerIndex = playerIndex % #playerOptions + 1
    playerButton.Text = "Players: " .. playerOptions[playerIndex] .. " (click to switch)"
end)

local cases = {}
for _, scenario in ipairs(Protocol.SCENARIOS) do
    local entry = { scenario = scenario, selected = true }
    local toggle
    toggle = button("[x] " .. scenario, function()
        entry.selected = not entry.selected
        toggle.Text = (entry.selected and "[x] " or "[ ] ") .. scenario
    end)
    local timeout = Instance.new("TextBox")
    timeout.BackgroundColor3 = palette.card
    timeout.TextColor3 = palette.text
    timeout.ClearTextOnFocus = false
    timeout.Font = Enum.Font.Code
    timeout.TextSize = 12
    timeout.Text = "20"
    timeout.PlaceholderText = scenario .. " timeout seconds (5-60)"
    place(timeout, 26)
    label(scenario .. " timeout in seconds (5-60, includes joining)", 18)
    entry.toggle, entry.input = toggle, timeout
    table.insert(cases, entry)
end

local function readPlan()
    local plan = { players = playerOptions[playerIndex], cases = {} }
    for _, entry in ipairs(cases) do
        if entry.selected then
            table.insert(plan.cases, { scenario = entry.scenario, timeout = tonumber(entry.input.Text) })
        end
    end
    return Protocol.copyPlan(plan)
end
local function readSetting(key)
    local ok, value = pcall(function() return plugin:GetSetting(key) end)
    if not ok then notify("Local settings unavailable; testing still works.", true) end
    return ok and value or nil
end
local function saveSetting(key, value)
    return Settings.save(value, function(stored) plugin:SetSetting(key, stored) end,
        function() return plugin:GetSetting(key) end)
end
local function decodeBounded(raw, limit)
    return Settings.decode(raw, limit, function(value) return HttpService:JSONDecode(value) end)
end

button("Save local preset", function()
    local plan = readPlan()
    if not plan then notify("Select at least one case; use whole-number timeouts from 5 to 60.", true); return end
    local ok = saveSetting(PRESET_KEY, HttpService:JSONEncode(plan))
    notify(ok and "Preset saved on this computer." or "Could not save the local preset.", not ok)
end)
button("Load local preset", function()
    local plan = Protocol.copyPlan(decodeBounded(readSetting(PRESET_KEY), 2048))
    if not plan then notify("No valid local preset. Current plan kept.", true); return end
    for index, count in ipairs(playerOptions) do if count == plan.players then playerIndex = index end end
    playerButton.Text = "Players: " .. plan.players .. " (click to switch)"
    for _, entry in ipairs(cases) do
        entry.selected = false
        for _, case in ipairs(plan.cases) do
            if case.scenario == entry.scenario then entry.selected = true; entry.input.Text = tostring(case.timeout) end
        end
        entry.toggle.Text = (entry.selected and "[x] " or "[ ] ") .. entry.scenario
    end
    notify("Local preset loaded.", false)
end)

local runButton
local function setBusy(value)
    busy = value
    for _, item in ipairs(controls) do item.Active = not value; item.AutoButtonColor = not value end
    for _, entry in ipairs(cases) do entry.input.TextEditable = not value end
    runButton.Text = value and "Running test plan..." or "Run selected test plan"
end

local report
local function render(summary)
    local lines = {}
    for _, result in ipairs(summary.tests) do
        table.insert(lines, string.format("%s %s (%.2fs)", result.passed and "PASS" or "FAIL", result.scenario, result.elapsed))
        table.insert(lines, "Expected: " .. result.expected)
        table.insert(lines, "Observed: " .. result.observed)
        table.insert(lines, "Next: " .. result.nextCheck)
    end
    local json = HttpService:JSONEncode(summary)
    report.Text = table.concat(lines, "\n") .. "\n\nREPORT JSON:\n" .. json
    return json
end

runButton = button("Run selected test plan", function()
    local plan = readPlan()
    if not plan then notify("Select cases and enter whole-number timeouts from 5 to 60 seconds.", true); return end
    if not session:ready() then notify("Previous test pending or Studio not in edit mode. Use Stop, then retry.", true); return end
    local ok, runner = pcall(function() return Manager.find(managerEnv, RUNNER_SOURCE) end)
    if not ok or not runner or not runner.Enabled or runner.RunContext ~= Enum.RunContext.Legacy then
        notify("Install the current owned runner first. Resolve any Explorer name collision.", true); return
    end
    stopRequested = false
    setBusy(true)
    report.Text = "Current run has no verified results yet."
    task.spawn(function()
        local summary = { version = 2, dateUTC = os.date("!%Y-%m-%dT%H:%M:%SZ"), players = plan.players,
            passed = 0, total = #plan.cases, tests = {} }
        local successful, errorMessage = pcall(function()
            local abort = false
            for _, case in ipairs(plan.cases) do
                if disposed then return end
                local request = { marker = Protocol.MARKER, version = Protocol.VERSION,
                    runId = HttpService:GenerateGUID(false), scenario = case.scenario, players = plan.players, timeout = case.timeout }
                local result, fatal
                if abort or stopRequested then
                    result = Protocol.failure(request, "Not run after cancellation or session failure", 0,
                        "Resolve the previous failure and run the selected plan again.")
                else
                    notify("Running " .. case.scenario .. " (" .. case.timeout .. "s + launch allowance)", false)
                    result, fatal = session:run(request)
                end
                abort = abort or fatal == true
                table.insert(summary.tests, result)
                if result.passed then summary.passed += 1 end
                if not disposed then render(summary) end
            end
        end)
        if disposed then return end
        if not successful then
            session:cancel()
            warn("Regression Arena: suite error.", errorMessage)
            report.Text = "FAIL: plugin suite error; partial results discarded. Check Studio Output and Stop any active test."
            notify("Suite failed. Check Output; retry after Studio returns to edit mode.", true)
        else
            local finalized, saved = pcall(function()
                render(summary)
                local appended = Settings.push(Protocol, history, summary, function(value) return HttpService:JSONEncode(value) end)
                return appended and saveSetting(HISTORY_KEY, history)
            end)
            if not finalized then warn("Regression Arena: report/history error.", saved) end
            notify(string.format("%d/%d passed. %s", summary.passed, summary.total,
                finalized and saved and "Last 10 reports saved locally." or "Report/history could not be saved; check Output."),
                summary.passed ~= summary.total or not finalized or not saved)
        end
        setBusy(false)
    end)
end)
local stop = Instance.new("TextButton")
stop.BackgroundColor3 = palette.card
stop.TextColor3 = palette.text
stop.TextSize = 13
stop.Font = Enum.Font.GothamBold
stop.Text = "Cancel / retry session cleanup"
place(stop, 30)
stop.MouseButton1Click:Connect(function()
    if disposed then return end
    stopRequested = true
    session:cancel()
    notify("Cancellation requested. If Studio stays active, use its Stop button.", true)
end)

status = label("Install the runner, select cases, then run. Studio validation is still required.", 50)
report = Instance.new("TextBox")
report.BackgroundColor3 = palette.card
report.TextColor3 = palette.text
report.Font = Enum.Font.Code
report.TextSize = 12
report.TextXAlignment, report.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
report.ClearTextOnFocus, report.MultiLine, report.TextEditable, report.TextWrapped = false, true, false, false
report.Text = "No test runs yet."
place(report, 240)
label("Click Results, Ctrl+A, Ctrl+C to copy text and JSON. Saved reports are never current-run evidence.", 36)
button("Show last saved report", function()
    report.Text = history[1] and ("SAVED REPORT (previous run)\n" .. history[1]) or "No saved report."
end)

history = Settings.history(Protocol, readSetting(HISTORY_KEY),
    function(value) return HttpService:JSONDecode(value) end,
    function(value) return HttpService:JSONEncode(value) end)
openButton.Click:Connect(function() if not disposed then widget.Enabled = not widget.Enabled end end)
plugin.Unloading:Connect(function()
    disposed = true
    stopRequested = true
    session:dispose()
end)
