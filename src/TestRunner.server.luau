-- Regression Arena runner 1.0.0. Only an explicitly marked Studio server test may act.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() or not RunService:IsServer() then return end

local StudioTestService = game:GetService("StudioTestService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Protocol = __PROTOCOL__
local Core = __RUNNER_CORE__
local Snapshot = __SNAPSHOT__
local Reader = __INSTANCE_READER__

-- Studio 0.742 can time out the initial argument handoff under local startup load.
-- Retry nil only, at most three reads. Unmarked tests still perform no test actions.
local argsOK, raw
for attempt = 1, 3 do
    argsOK, raw = pcall(function() return StudioTestService:GetTestArgs() end)
    if not argsOK or raw ~= nil then break end
    if attempt < 3 then task.wait(1) end
end
if not argsOK or type(raw) ~= "string" or #raw > Snapshot.MAX_REQUEST_BYTES then return end
local decoded, request = pcall(function() return HttpService:JSONDecode(raw) end)
if not decoded or type(request) ~= "table" then return end
local contract = request.marker == Snapshot.MARKER and Snapshot or Protocol
if not contract.validRequest(request) then return end

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
        warn("Regression Arena: EndTest failed. Use Studio Stop; LeaveTest is client-only.", err)
        -- No supported server fallback. Never resend a PASS after an ambiguous failure.
    end
end

task.delay(request.timeout, function()
    if finalized then return end
    local value = contract.failure(request, "Server scenario deadline exceeded", os.clock() - started,
        (contract == Snapshot or request.scenario == "spawn") and "Check Players.CharacterAutoLoads, custom character loaders, configured paths and server Output."
            or "Check initial joining, AddPlayers for latejoin, and server Output for blocked API calls.")
    local measured, view = pcall(snapshot)
    if measured and contract == Protocol then
        value.observed = string.format("Server deadline exceeded: %d players; %d characters with Humanoids", view.count, view.ready)
        value.evidence.finalCount = view.count
        value.evidence.readyCount = view.ready
    elseif measured then
        value.serverCount, value.readyCount = view.count, view.ready
        value.observed = string.format("Snapshot deadline exceeded: %d players; %d characters with Humanoids", view.count, view.ready)
    end
    finish(value)
end)

local ok, value = pcall(function()
    if contract == Snapshot then
        return Snapshot.run(request, {
            now = os.clock, wait = task.wait, snapshot = snapshot,
            read = function(check) return Reader.read(Snapshot, game, check) end,
        })
    end
    return Core.run(Protocol, request, {
        now = os.clock,
        wait = task.wait,
        addPlayer = function() StudioTestService:AddPlayers(1) end,
        snapshot = snapshot,
    })
end)
if not ok then
    warn("Regression Arena: scenario API/runtime error.", value)
    value = contract.failure(request, "Server scenario API/runtime error", os.clock() - started,
        "Read server Output; check StudioTestService:AddPlayers support for latejoin.")
end
finish(value)
