-- Regression Arena v0.1 test runner.
-- Installed into ServerScriptService by the Studio plugin.
-- Runs ONLY when a Regression Arena StudioTestService session passes a valid marker.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
    return
end

local StudioTestService = game:GetService("StudioTestService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- The Roblox API occasionally returns nil immediately after entering test mode.
local arguments = nil
for _ = 1, 35 do
    arguments = StudioTestService:GetTestArgs()
    if arguments ~= nil then
        break
    end
    task.wait(0.1)
end

if type(arguments) ~= "string" then
    return -- Do not interfere with unrelated playtests.
end

local scenario, declaredPlayers = string.match(arguments, "^RA01:([%a]+):([1-8])$")
if not scenario then
    return
end

local expectedPlayers = tonumber(declaredPlayers)
local finalized = false
local startTime = os.clock()

local function endSession(passed, description)
    if finalized then
        return
    end
    finalized = true
    local result = {
        marker = "RegressionArenaV01",
        scenario = scenario,
        passed = passed == true,
        details = tostring(description),
        elapsed = math.floor((os.clock() - startTime) * 100) / 100,
    }
    StudioTestService:EndTest(HttpService:JSONEncode(result))
end

task.delay(40, function()
    endSession(false, "Timeout: scenario did not finish in 40 seconds.")
end)

local function waitUntil(predicate, seconds)
    local limit = os.clock() + seconds
    repeat
        if predicate() then
            return true
        end
        task.wait(0.15)
    until os.clock() >= limit
    return predicate()
end

-- Keep the test runner independent of the game's own remotes or dependencies.
task.spawn(function()
    local ok, err = pcall(function()
        local joined = waitUntil(function()
            return #Players:GetPlayers() >= expectedPlayers
        end, 18)
        if not joined then
            endSession(false, "Expected " .. expectedPlayers .. " players, got " .. #Players:GetPlayers())
            return
        end

        if scenario == "join" then
            endSession(true, "Joined " .. #Players:GetPlayers() .. " / " .. expectedPlayers .. " players.")
            return
        end

        if scenario == "spawn" then
            local ready = waitUntil(function()
                for _, player in Players:GetPlayers() do
                    local character = player.Character
                    if not character or not character:FindFirstChildOfClass("Humanoid") then
                        return false
                    end
                end
                return true
            end, 16)
            if ready then
                endSession(true, "All " .. expectedPlayers .. " players spawned with Humanoids.")
            else
                endSession(false, "One or more players did not spawn a character with a Humanoid.")
            end
            return
        end

        if scenario == "latejoin" then
            if expectedPlayers >= 8 then
                endSession(false, "Late join needs fewer than 8 initial players.")
                return
            end
            local existing = #Players:GetPlayers()
            StudioTestService:AddPlayers(1)
            local added = waitUntil(function()
                return #Players:GetPlayers() >= existing + 1
            end, 18)
            if added then
                endSession(true, "Late join succeeded: " .. existing .. " to " .. #Players:GetPlayers() .. " players.")
            else
                endSession(false, "Late join failed: expected " .. (existing + 1) .. " players.")
            end
            return
        end

        endSession(false, "Unknown scenario: " .. scenario)
    end)
    if not ok then
        endSession(false, "Runtime error: " .. tostring(err))
    end
end)
