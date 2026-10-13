-- Regression Arena v0.1. Offline Roblox Studio test plugin.
-- Builds into dist/RegressionArena.plugin.luau (includes the server runner source).
local StudioTestService = game:GetService("StudioTestService")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local RUNNER_NAME = "RegressionArena_TestRunner"
local RUNNER_SOURCE = [==[
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

]==]
local HISTORY_KEY = "regression-arena-v01-history"

local palette = {
    panel = Color3.fromRGB(27, 32, 42),
    card = Color3.fromRGB(39, 47, 61),
    text = Color3.fromRGB(241, 245, 251),
    secondary = Color3.fromRGB(175, 190, 212),
    blue = Color3.fromRGB(74, 136, 230),
    green = Color3.fromRGB(92, 199, 155),
    red = Color3.fromRGB(245, 122, 122),
}

local toolbar = plugin:CreateToolbar("Regression Arena")
local openButton = toolbar:CreateButton("Regression Arena", "Open local multiplayer test runner", "")
openButton.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 360, 490, 300, 370)
local widget = plugin:CreateDockWidgetPluginGui("RegressionArenaPanel01", widgetInfo)
widget.Title = "Regression Arena - v0.1"

local root = Instance.new("Frame")
root.BackgroundColor3 = palette.panel
root.Size = UDim2.fromScale(1, 1)
root.BorderSizePixel = 0
root.Parent = widget

local column = Instance.new("UIListLayout")
column.FillDirection = Enum.FillDirection.Vertical
column.Padding = UDim.new(0, 8)
column.SortOrder = Enum.SortOrder.LayoutOrder
column.Parent = root

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 12)
pad.PaddingBottom = UDim.new(0, 12)
pad.PaddingLeft = UDim.new(0, 12)
pad.PaddingRight = UDim.new(0, 12)
pad.Parent = root

local function addText(text, height, fontSize)
    local item = Instance.new("TextLabel")
    item.BackgroundTransparency = 1
    item.TextColor3 = palette.text
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.TextYAlignment = Enum.TextYAlignment.Center
    item.Font = Enum.Font.Gotham
    item.TextSize = fontSize or 14
    item.Text = text
    item.Size = UDim2.new(1, 0, 0, height)
    item.TextWrapped = true
    item.Parent = root
    return item
end

local function addButton(text, color)
    local button = Instance.new("TextButton")
    button.Font = Enum.Font.GothamBold
    button.TextSize = 13
    button.Text = text
    button.TextColor3 = palette.text
    button.BackgroundColor3 = color or palette.card
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, 0, 0, 36)
    button.Parent = root
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    return button
end

local headline = addText("Multiplayer smoke tests", 28, 18)
headline.Font = Enum.Font.GothamBold
local subtitle = addText("Runs locally in Roblox Studio. No network or paid APIs.", 36, 12)
subtitle.TextColor3 = palette.secondary

local setup = addButton("1. Install / update test runner", palette.card)
local playerButton = addButton("Players: 2 (click to switch)")
local suiteButton = addButton("2. Run 3 test scenarios", palette.blue)
local status = addText("Install the runner, then start the test suite.", 44, 12)
status.TextColor3 = palette.secondary
local reportLabel = addText("Results", 22, 14)
reportLabel.Font = Enum.Font.GothamBold

local report = Instance.new("TextBox")
report.BackgroundColor3 = palette.card
report.TextColor3 = palette.text
report.PlaceholderColor3 = palette.secondary
report.PlaceholderText = "Results will appear here"
report.ClearTextOnFocus = false
report.MultiLine = true
report.TextEditable = false
report.TextWrapped = false
report.TextXAlignment = Enum.TextXAlignment.Left
report.TextYAlignment = Enum.TextYAlignment.Top
report.Font = Enum.Font.Code
report.TextSize = 12
report.Text = "No test runs yet."
report.Size = UDim2.new(1, 0, 0, 160)
report.Parent = root
local reportCorner = Instance.new("UICorner")
reportCorner.CornerRadius = UDim.new(0, 6)
reportCorner.Parent = report

local footer = addText("Copy output from Results. Runs stay on this computer.", 32, 11)
footer.TextColor3 = palette.secondary

local playerOptions = { 1, 2, 4 }
local playerIndex = 2
local isRunning = false
local scenarios = { "join", "spawn", "latejoin" }
local history = {}

local function safeReadHistory()
    local ok, value = pcall(function()
        return plugin:GetSetting(HISTORY_KEY)
    end)
    if ok and type(value) == "table" then
        return value
    end
    return {}
end

history = safeReadHistory()

local function persistHistory()
    pcall(function()
        plugin:SetSetting(HISTORY_KEY, history)
    end)
end

local function setBusy(busy)
    isRunning = busy
    suiteButton.Active = not busy
    setup.Active = not busy
    playerButton.Active = not busy
    suiteButton.Text = busy and "Running tests..." or "2. Run 3 test scenarios"
    suiteButton.BackgroundColor3 = busy and palette.card or palette.blue
end

local function getRunner()
    local existing = ServerScriptService:FindFirstChild(RUNNER_NAME)
    if existing and existing:IsA("Script") then
        return existing
    end
    return nil
end

setup.MouseButton1Click:Connect(function()
    if isRunning then
        return
    end
    local runner = getRunner()
    if not runner then
        runner = Instance.new("Script")
        runner.Name = RUNNER_NAME
        runner.Enabled = false
        runner.Parent = ServerScriptService
    end
    local ok, err = pcall(function()
        runner.Source = RUNNER_SOURCE
        runner.Enabled = true
    end)
    if ok then
        pcall(function() ChangeHistoryService:SetWaypoint("Regression Arena: install runner") end)
        status.TextColor3 = palette.green
        status.Text = "Runner ready in ServerScriptService."
    else
        status.TextColor3 = palette.red
        status.Text = "Install failed: " .. tostring(err)
    end
end)

playerButton.MouseButton1Click:Connect(function()
    if isRunning then
        return
    end
    playerIndex = (playerIndex % #playerOptions) + 1
    playerButton.Text = "Players: " .. playerOptions[playerIndex] .. " (click to switch)"
end)

local function runScenario(scenario, count)
    local payload = "RA01:" .. scenario .. ":" .. count
    local ok, raw = pcall(function()
        return StudioTestService:ExecuteMultiplayerTestAsync(count, payload)
    end)
    if not ok then
        return {scenario = scenario, passed = false, details = tostring(raw)}
    end
    if type(raw) ~= "string" then
        return {scenario = scenario, passed = false, details = "Unexpected test response"}
    end
    local parsed, value = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not parsed or type(value) ~= "table" or value.marker ~= "RegressionArenaV01" or value.scenario ~= scenario then
        return {scenario = scenario, passed = false, details = "Malformed test result"}
    end
    return {scenario = scenario, passed = value.passed == true, details = tostring(value.details), elapsed = value.elapsed}
end

suiteButton.MouseButton1Click:Connect(function()
    if isRunning then
        return
    end
    if not getRunner() then
        status.TextColor3 = palette.red
        status.Text = "Install the test runner first."
        return
    end
    setBusy(true)
    report.Text = ""
    local selectedPlayers = playerOptions[playerIndex]
    local results = {}
    local passed = 0
    -- Use a coroutine so controls redraw while Studio runs each test.
    task.spawn(function()
        for index, scenario in ipairs(scenarios) do
            status.TextColor3 = palette.secondary
            status.Text = "Running " .. index .. "/" .. #scenarios .. ": " .. scenario
            local result = runScenario(scenario, selectedPlayers)
            table.insert(results, result)
            if result.passed then
                passed += 1
            end
            local lines = {}
            for _, item in ipairs(results) do
                table.insert(lines, (item.passed and "PASS  " or "FAIL  ") .. item.scenario)
                table.insert(lines, "      " .. item.details)
            end
            report.Text = table.concat(lines, "\n")
        end
        local summary = { dateUTC = os.date("!%Y-%m-%dT%H:%M:%SZ"), players = selectedPlayers, passed = passed, total = #scenarios, tests = results }
        table.insert(history, 1, summary)
        while #history > 10 do
            table.remove(history)
        end
        persistHistory()
        status.Text = string.format("%d/%d passed. Last 10 runs saved locally.", passed, #scenarios)
        status.TextColor3 = passed == #scenarios and palette.green or palette.red
        report.Text = report.Text .. "\n\nREPORT JSON:\n" .. HttpService:JSONEncode(summary)
        setBusy(false)
    end)
end)

openButton.Click:Connect(function()
    widget.Enabled = not widget.Enabled
end)
