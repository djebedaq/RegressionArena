-- Read only explicitly configured paths. Never inspect Source or arbitrary services.
local Reader = {}
function Reader.read(contract,root,check)
    check=contract.copyCheck(check)
    if not check then return {kind="error",reason="Invalid or unsupported assertion definition."} end
    local node=root:GetService(check.path[1])
    for i=2,#check.path do
        local found=nil
        for _,child in ipairs(node:GetChildren()) do
            if child.Name==check.path[i] then
                if found then return {kind="error",reason="Ambiguous path: duplicate sibling names."} end
                found=child
            end
        end
        if not found then return {kind="missing"} end
        node=found
    end
    if check.source=="object" then return {kind="boolean",value=true} end
    local value
    local ok=pcall(function()
        if check.source=="attribute" then value=node:GetAttribute(check.key)
        elseif contract.PROPERTIES[check.key] then value=node[check.key]
        else error("Unsupported property") end
    end)
    if not ok then return {kind="error",reason="Field is not readable on this object class."} end
    if value==nil then return {kind="missing"} end
    return contract.observation({kind=type(value),value=value})
        or {kind="error",reason="Value must be a finite number, boolean or string of at most 128 bytes."}
end
return Reader
