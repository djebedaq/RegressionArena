-- Regression Arena runner 0.2.0. Only an explicitly marked Studio server test may act.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() or not RunService:IsServer() then return end

local StudioTestService = game:GetService("StudioTestService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Protocol = __PROTOCOL__
local Core = __RUNNER_CORE__

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
