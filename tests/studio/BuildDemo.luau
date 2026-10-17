-- Developer-only demo authoring command. Run once in a disposable local Baseplate.
-- Not embedded in the plugin or production runner. Creates only RA_Demo.
assert(game.PlaceId == 0 and game:GetService("RunService"):IsEdit(), "Use a local edit-mode Baseplate")
assert(not workspace:FindFirstChild("RA_Demo"), "Preserve the existing RA_Demo; use a fresh copy")
local model = Instance.new("Model")
model.Name = "RA_Demo"
model:SetAttribute("RegressionArenaDemoVersion", "1.0.0")
local function part(name, size, position, color)
    local p = Instance.new("Part")
    p.Name, p.Size, p.Position = name, size, position
    p.Anchored, p.CanCollide = true, true
    p.Color, p.Material = color, Enum.Material.SmoothPlastic
    p.Parent = model
    return p
end
local dark = Color3.fromRGB(30, 42, 61)
local door = part("Door", Vector3.new(8, 9, 1), Vector3.new(0, 4.5, -14), Color3.fromRGB(52, 161, 218))
door:SetAttribute("Unlocked", true)
door:SetAttribute("Reward", 10)
door:SetAttribute("Mode", "Open")
part("LeftFrame", Vector3.new(1, 10, 2), Vector3.new(-4.5, 5, -14), dark)
part("RightFrame", Vector3.new(1, 10, 2), Vector3.new(4.5, 5, -14), dark)
part("TopFrame", Vector3.new(10, 1, 2), Vector3.new(0, 10, -14), dark)
local board = part("ContractBoard", Vector3.new(16, 6, 1), Vector3.new(0, 14, -14), dark)
local gui = Instance.new("SurfaceGui")
gui.Name, gui.Face = "DemoInstructions", Enum.NormalId.Front
gui.SizingMode, gui.PixelsPerStud = Enum.SurfaceGuiSizingMode.PixelsPerStud, 45
gui.Parent = board
local text = Instance.new("TextLabel")
text.Name, text.Size, text.BackgroundTransparency = "Instructions", UDim2.fromScale(1, 1), 1
text.TextColor3, text.Font, text.TextSize, text.TextWrapped = Color3.new(1, 1, 1), Enum.Font.GothamBold, 30, true
text.Text = "REGRESSION ARENA\nSNAPSHOT DEMO\nDoor exists • CanCollide = true • Unlocked = true\nReward: 5–15 • Mode: Open\nCapture baseline, change an Attribute, rerun."
text.Parent = gui
model.Parent = workspace
print("RA10_DEMO_CREATED", model:GetFullName(), door.CanCollide, door:GetAttribute("Unlocked"), door:GetAttribute("Reward"), door:GetAttribute("Mode"))
