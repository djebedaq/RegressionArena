-- Regression Arena 1.0 release candidate. Generated offline plugin, including its owned runner.
local StudioTestService = game:GetService("StudioTestService")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local ScriptEditorService = game:GetService("ScriptEditorService")
local Protocol = __PROTOCOL__
local Manager = __RUNNER_MANAGER__
local Session = __SESSION__
local Settings = __SETTINGS__
local Snapshot = __SNAPSHOT__
local Interface = __INTERFACE__
local SnapshotUI = __SNAPSHOT_UI__
local RUNNER_SOURCE = __EMBEDDED_RUNNER_SOURCE__
local HISTORY_KEY = "regression-arena-v1-smoke-history"
local PRESET_KEY = "regression-arena-v1-smoke-preset"
local disposed, busy, stopRequested = false, false, false
local history = {}

local function isEdit()
    local ok, value = pcall(function() return StudioTestService.EditModeActive end)
    return ok and value == true and not RunService:IsRunning()
end

local session = Session.new(Protocol, {
    now = os.clock, wait = task.wait, spawn = task.spawn,
    isEdit = isEdit,
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
local widget = plugin:CreateDockWidgetPluginGuiAsync("RegressionArenaPanel10",
    DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 420, 680, 300, 300))
widget.Title = "Regression Arena 1.0"
local UI = Interface.new(widget)
local root = Instance.new("ScrollingFrame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = palette.panel
root.BorderSizePixel = 0
root.ScrollBarThickness = 6
root.CanvasSize = UDim2.new()
root.AutomaticCanvasSize = Enum.AutomaticSize.Y
root.Parent = UI.pages.Smoke
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
    item.TextYAlignment = Enum.TextYAlignment.Top
    item.TextWrapped = true
    item.AutomaticSize = Enum.AutomaticSize.Y
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
    item.TextWrapped = true
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
label("One initial player; latejoin adds a second. Use a disposable place copy: your game's own scripts still run.", 62)
local status -- Filled before callbacks can be invoked.
local function notify(message, failed)
    if disposed then return end
    status.Text = message
    status.TextColor3 = failed and palette.red or palette.secondary
    UI:status(message, failed)
end
local function changeRunner(remove)
    local ok, message = pcall(function()
        if not session:ready() then error("Wait for the current native test to return to edit mode.") end
        return Manager.change(managerEnv, RUNNER_SOURCE, remove)
    end)
    notify((tostring(message):gsub("^.-:%d+:%s*", "")):sub(1, 512), not ok)
end
local playerOptions, playerIndex = { 1 }, 1
local playerButton
playerButton = button("Players: 1 (supported configuration)", function()
    notify("One initial player is supported. Latejoin adds a second client.", false)
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
    timeout.Text = "180"
    timeout.PlaceholderText = scenario .. " timeout seconds (5-180)"
    place(timeout, 26)
    label(scenario .. " timeout in seconds (5-180, includes joining)", 18)
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
    if not plan then notify("Select at least one case; use whole-number timeouts from 5 to 180.", true); return end
    local ok = saveSetting(PRESET_KEY, HttpService:JSONEncode(plan))
    notify(ok and "Preset saved on this computer." or "Could not save the local preset.", not ok)
end)
button("Load local preset", function()
    local plan = Protocol.copyPlan(decodeBounded(readSetting(PRESET_KEY), 2048))
    if not plan or plan.players ~= 1 then notify("No supported local preset. Current plan kept.", true); return end
    for index, count in ipairs(playerOptions) do if count == plan.players then playerIndex = index end end
    playerButton.Text = "Players: 1 (supported configuration)"
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
local invalidateSnapshot = function() end
local function setBusy(value)
    busy = value
    if value then invalidateSnapshot() end
    UI:setBusy(value)
    for _, item in ipairs(controls) do item.Active = not value; item.AutoButtonColor = not value end
    for _, entry in ipairs(cases) do entry.input.TextEditable = not value end
    runButton.Text = value and "Running test plan..." or "Run selected test plan"
end

local report
local function render(summary, previous)
    local lines = {}
    local rows = {}
    for _, result in ipairs(summary.tests) do
        table.insert(rows, { passed = result.passed, text = string.format("%s %s (%.2fs)\nExpected: %s\nActual: %s\nNext: %s",
            result.passed and "PASS" or "FAIL", result.scenario, result.elapsed, result.expected, result.observed, result.nextCheck) })
        table.insert(lines, string.format("%s %s (%.2fs)", result.passed and "PASS" or "FAIL", result.scenario, result.elapsed))
        table.insert(lines, "Expected: " .. result.expected)
        table.insert(lines, "Observed: " .. result.observed)
        table.insert(lines, "Next: " .. result.nextCheck)
    end
    local json = HttpService:JSONEncode(summary)
    report.Text = table.concat(lines, "\n") .. "\n\nREPORT JSON:\n" .. json
    UI:results(previous and "SAVED REPORT — previous smoke run"
        or string.format("%d/%d smoke cases passed", summary.passed, summary.total), rows, json)
    return json
end

runButton = button("Run selected test plan", function()
    local plan = readPlan()
    if not plan then notify("Select cases and enter whole-number timeouts from 5 to 180 seconds.", true); return end
    if not session:ready() then
        notify(session.pending and session.pending.ambiguous
            and "Native cleanup unconfirmed. End all test windows and restart Studio before retrying."
            or "Previous test pending or Studio not in edit mode. Use Stop, then retry.", true)
        return
    end
    local ok, runner = pcall(function() return Manager.find(managerEnv, RUNNER_SOURCE) end)
    if not ok or not runner or not runner.Enabled or runner.RunContext ~= Enum.RunContext.Legacy then
        notify("Install the current owned runner first. Resolve any Explorer name collision.", true); return
    end
    stopRequested = false
    setBusy(true)
    report.Text = "Current run has no verified results yet."
    UI:results("RUNNING — no current smoke evidence", {}, "No current verified report yet.")
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
            UI:results("FAIL — plugin suite error", {{ passed = false,
                text = "No complete verified suite report. Partial results discarded. Check Studio Output and end any active test." }}, "No complete verified report.")
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
stop.TextWrapped = true
stop.Text = "Cancel results (server finishes)"
place(stop, 30)
stop.MouseButton1Click:Connect(function()
    if disposed then return end
    if not busy then notify("There is no active run.", false); return end
    stopRequested = true
    session:cancel()
    notify("Results cancelled. Server ends at its deadline; use Studio Stop for immediate termination.", true)
end)

status = label("Install the runner in Setup, select cases and run. Results provides the report and JSON export.", 58)
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
    local summary = history[1] and Settings.summary(Protocol, decodeBounded(history[1], Protocol.MAX_REPORT_BYTES))
    if summary then render(summary, true) else notify("No saved report.", false) end
end)

history = Settings.history(Protocol, readSetting(HISTORY_KEY),
    function(value) return HttpService:JSONDecode(value) end,
    function(value) return HttpService:JSONEncode(value) end)
local snapshotController = SnapshotUI.mount({ ui = UI, plugin = plugin, snapshot = Snapshot, settings = Settings,
    http = HttpService, session = session, isEdit = isEdit, selection = game:GetService("Selection"),
    setBusy = setBusy, isBusy = function() return busy end,
    changeRunner = changeRunner,
    ready = function()
        if not session:ready() then
            notify(session.pending and session.pending.ambiguous
                and "Native cleanup unconfirmed. End all test windows and restart Studio before retrying."
                or "Previous native test is pending, or Studio is not in edit mode.", true)
            return false
        end
        local ok, runner = pcall(function() return Manager.find(managerEnv, RUNNER_SOURCE) end)
        if not ok or not runner or not runner.Enabled or runner.RunContext ~= Enum.RunContext.Legacy then
            notify("Install the current owned runner in Setup. Preserve name collisions; remove older runners with their matching old plugin first.", true)
            return false
        end
        return true
    end,
})
invalidateSnapshot = snapshotController.invalidate
openButton.Click:Connect(function() if not disposed then widget.Enabled = not widget.Enabled end end)
plugin.Unloading:Connect(function()
    disposed = true
    stopRequested = true
    session:dispose()
    UI.disposed = true
    pcall(function() widget:Destroy() end)
    pcall(function() toolbar:Destroy() end)
end)
