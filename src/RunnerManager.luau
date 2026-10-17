-- Fail closed on collisions, duplicates, unsupported versions, edits, or child content.
local Manager = {}
Manager.NAME = "RegressionArena_TestRunner"
Manager.OWNER = "RegressionArena"
Manager.VERSION = "1.0.0"

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
        return "Runner " .. Manager.VERSION .. " is already current."
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
    return remove and "Owned runner removed. Undo is available." or "Runner " .. Manager.VERSION .. " ready. Undo is available."
end

return Manager
