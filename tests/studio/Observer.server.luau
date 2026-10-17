-- Developer-only fixture for the disposable, unpublished Baseplate. Never publish.
-- Without a Fault attribute this only observes an ordinary unmarked Studio session.
-- Fault="malformed" deliberately ends a marked RA session with invalid evidence.
-- Fault="stale" replays PreviousResult, an actual old result JSON string.
-- Fault="niltransport" exercises the plugin's ambiguous native cleanup lock.
-- Fault="invalidtransport" returns a table instead of the product JSON string.
local RS = game:GetService("RunService")
if not RS:IsStudio() or not RS:IsServer() then return end
local STS = game:GetService("StudioTestService")
local Players = game:GetService("Players")
local fault = script:GetAttribute("Fault")
task.wait(fault and 0 or 5)
local ok, raw = pcall(function() return STS:GetTestArgs() end)
print("RA_VALIDATION ST08 observer", "running", RS:IsRunning(), "argsNil", ok and raw == nil,
    "players", #Players:GetPlayers())
if not fault or not ok or type(raw) ~= "string" then return end
local decoded, request = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
if not decoded or type(request) ~= "table" or request.marker ~= "RegressionArenaV02" then return end
if fault == "niltransport" or fault == "invalidtransport" then
    -- Stop only the owned runner clone inside this marked disposable server.
    -- Otherwise its later real join result can replace the injected nil value.
    local runner = script.Parent:FindFirstChild("RegressionArena_TestRunner")
    assert(runner and runner:IsA("Script") and runner:GetAttribute("RAOwner") == "RegressionArena"
        and runner:GetAttribute("RAVersion") == (script:GetAttribute("ExpectedRunnerVersion") or "0.2.0"), "Expected the owned test-server runner clone")
    runner.Enabled = false
    print("RA002_FAULT owned server runner clone disabled")
    local delay = script:GetAttribute("DelaySeconds")
    if type(delay) == "number" and delay >= 0 and delay <= 120 then
        print("RA10_FAULT delayed transport seconds", delay)
        task.wait(delay)
    end
    if fault == "niltransport" then
        print("RA002_FAULT deliberately nil EndTest transport")
        STS:EndTest(nil)
    else
        print("RA002_FAULT deliberately table EndTest transport")
        STS:EndTest({ passed = true })
    end
elseif fault == "malformed" then
    print("RA_VALIDATION ST13 deliberately malformed EndTest fixture")
    STS:EndTest('{"passed":true}')
elseif fault == "stale" then
    local previous = script:GetAttribute("PreviousResult")
    assert(type(previous) == "string" and #previous <= 8192, "Supply an actual bounded old result")
    print("RA_VALIDATION ST13 deliberately stale EndTest replay fixture")
    STS:EndTest(previous)
end
