-- RA-002 developer-only observer; never publish or ship in the plugin.
-- No StudioTestService calls, player additions or session termination.
local RS = game:GetService("RunService")
if not RS:IsStudio() or not RS:IsServer() then return end
local Players = game:GetService("Players")
local started = os.clock()
local expected = script:GetAttribute("ExpectedClients")
local lastCount, lastReady = -1, -1
local function observe()
    local current, ready = Players:GetPlayers(), 0
    for _, player in ipairs(current) do
        local character = player.Character
        if character and character.Parent and character:FindFirstChildOfClass("Humanoid") then ready += 1 end
    end
    if #current ~= lastCount or ready ~= lastReady then
        print("RA002_NATIVE", "expected", expected, "players", #current, "ready", ready,
            "serverElapsed", math.round((os.clock() - started) * 100) / 100)
        lastCount, lastReady = #current, ready
    end
end
print("RA002_NATIVE observer started; no RA runner", not script.Parent:FindFirstChild("RegressionArena_TestRunner"))
for _ = 1, 180 do observe(); task.wait(2) end
print("RA002_NATIVE observation window ended; session left active")
