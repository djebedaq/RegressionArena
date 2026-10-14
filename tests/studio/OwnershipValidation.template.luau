-- Developer-only Studio plugin integration test. Render with scripts_studio_validation.py.
-- Run only in the disposable unpublished Baseplate. Uses real engine services, no mocks.
assert(game.PlaceId == 0 and game.GameId == 0, "Use the unpublished validation Baseplate")
local STS = game:GetService("StudioTestService")
local RS = game:GetService("RunService")
assert(STS.EditModeActive and not RS:IsRunning(), "Wait for edit mode")
local Manager = __RUNNER_MANAGER__
local SSS = game:GetService("ServerScriptService")
local baseline = SSS:FindFirstChild("RegressionArena_TestRunner")
assert(baseline and baseline:GetAttribute("RAOwner") == "RegressionArena", "Install the baseline runner first")
local source = baseline.Source
local negativeFixture = SSS:FindFirstChild("RA_Validation_NoAutoSpawn")
if negativeFixture then negativeFixture.Parent = nil end
assert(not SSS:FindFirstChild("RA_Validation_Ownership"), "Preserve any previous fixture first")
local container = Instance.new("Folder")
container.Name = "RA_Validation_Ownership"
container.Parent = SSS
local editor = game:GetService("ScriptEditorService")
local history = game:GetService("ChangeHistoryService")
local env = {
    container = container,
    isEdit = function() return STS.EditModeActive and not RS:IsRunning() end,
    editorSource = function(runner) return editor:GetEditorSource(runner) end,
    legacyContext = Enum.RunContext.Legacy,
    newScript = function() return Instance.new("Script") end,
    beginRecording = function() return history:TryBeginRecording("RAValidation", "RA validation fixture") end,
    finishRecording = function(id, commit)
        history:FinishRecording(id, commit and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
    end,
}
local passed = 0
local function check(name, callback)
    callback()
    passed += 1
    print("RA_VALIDATION ST11 PASS", name)
end
local function refuses()
    assert(not pcall(function() Manager.change(env, source, false) end), "Install must refuse")
    assert(not pcall(function() Manager.change(env, source, true) end), "Remove must refuse")
end
local ok, reason = pcall(function()
    local runner, sentinel
    check("install and repeated install", function()
        Manager.change(env, source, false)
        runner = Manager.find(env, source)
        Manager.change(env, source, false)
        assert(Manager.find(env, source) == runner and #container:GetChildren() == 1)
        assert(runner.Enabled and runner.RunContext == Enum.RunContext.Legacy)
    end)
    check("disabled/context repair", function()
        runner.Enabled = false
        runner.RunContext = Enum.RunContext.Server
        Manager.change(env, source, false)
        assert(runner.Enabled and runner.RunContext == Enum.RunContext.Legacy)
    end)
    check("unknown version preserved", function()
        runner:SetAttribute("RAVersion", "unknown-fixture")
        refuses()
        assert(runner.Parent == container and runner:GetAttribute("RAVersion") == "unknown-fixture")
        runner:SetAttribute("RAVersion", "0.2.0")
    end)
    check("modified Source preserved", function()
        local edited = source .. "\n-- RA validation edit"
        runner.Source = edited
        refuses()
        assert(runner.Source == edited and runner.Parent == container)
        runner.Source = source
    end)
    check("runner child content preserved", function()
        local child = Instance.new("Folder")
        child.Name = "RA_Validation_Child"
        child.Parent = runner
        local script = Instance.new("Script")
        script.Source = "-- Keep fixture child"
        script.Parent = child
        refuses()
        assert(child.Parent == runner and script.Source == "-- Keep fixture child")
        child.Parent = nil
    end)
    check("duplicate exact runner names preserved", function()
        local duplicate = runner:Clone()
        duplicate.Parent = container
        refuses()
        assert(duplicate.Parent == container and runner.Parent == container)
        duplicate.Parent = nil
    end)
    check("unowned matching Script preserved", function()
        runner.Parent = nil
        sentinel = Instance.new("Script")
        sentinel.Name = "RegressionArena_TestRunner"
        sentinel.Source = "-- Customer fixture; never overwrite"
        sentinel.Parent = container
        refuses()
        assert(sentinel.Source == "-- Customer fixture; never overwrite" and sentinel.Parent == container)
        assert(sentinel:GetAttribute("RAOwner") == nil)
        sentinel.Name = "CustomerSentinel"
        runner.Parent = container
    end)
    check("wrong class preserved", function()
        runner.Parent = nil
        local wrong = Instance.new("Folder")
        wrong.Name = "RegressionArena_TestRunner"
        wrong.Parent = container
        refuses()
        assert(wrong.Parent == container)
        wrong.Parent = nil
        runner.Parent = container
    end)
    check("remove and repeated remove preserve sentinel", function()
        Manager.change(env, source, true)
        Manager.change(env, source, true)
        assert(runner.Parent == nil and #container:GetChildren() == 1)
        assert(sentinel.Parent == container and sentinel.Source == "-- Customer fixture; never overwrite")
    end)
end)
-- Detach only the named validation container; never operate on the real baseline runner.
container.Parent = nil
assert(baseline.Parent == SSS and baseline.Source == source, "Baseline changed unexpectedly")
print("RA_VALIDATION ST11 checks", passed, "of", 9, "baseline intact", true)
if not ok then error("RA validation failed: " .. tostring(reason)) end
