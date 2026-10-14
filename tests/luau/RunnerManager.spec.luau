local M=require("../../src/RunnerManager")
local S=require("./Support")
local function fixture(options)
    options=options or {}
    local all={}
    local container={}
    function container:GetChildren()
        local result={}
        for _,item in ipairs(all) do if item.Parent==container then table.insert(result,item) end end
        return result
    end
    local state={begins=0,commits=0,cancels=0}
    local function script(owned)
        local data={Name=M.NAME,Source="runner",Enabled=true,RunContext="Legacy",children={},attributes={}}
        local item=setmetatable({},{
            __index=function(_,key) return data[key] end,
            __newindex=function(_,key,value)
                if key=="Source" and options.sourceDenied then error("Source denied") end
                data[key]=value
            end,
        })
        function item:IsA(class) return class=="Script" and not data.wrongClass end
        function item:GetAttribute(key) return data.attributes[key] end
        function item:SetAttribute(key,value) data.attributes[key]=value end
        function item:GetChildren() return data.children end
        function item:Destroy() data.Parent=nil; data.destroyed=true end
        if owned then data.attributes={RAOwner=M.OWNER,RAVersion=M.VERSION} end
        table.insert(all,item)
        return item
    end
    local env={
        container=container,isEdit=function() return options.edit ~= false end,
        editorSource=function(item) return options.editorSource or item.Source end,
        legacyContext="Legacy",newScript=function() return script(false) end,
        beginRecording=function()
            state.begins+=1
            if options.beginDenied then return nil end
            return "recording"
        end,
        finishRecording=function(_,commit)
            if commit then
                state.commits+=1
                if options.commitDenied then error("commit failed") end
            else state.cancels+=1 end
        end,
    }
    return env,state,script,all
end
S.test("install is explicit, versioned and idempotent",function()
    local env,state=fixture()
    M.change(env,"runner",false)
    local runner=env.container:GetChildren()[1]
    assert(runner:GetAttribute("RAOwner")==M.OWNER and runner:GetAttribute("RAVersion")==M.VERSION)
    assert(runner.Source=="runner" and runner.Enabled)
    M.change(env,"runner",false)
    assert(#env.container:GetChildren()==1 and state.commits==1)
end)
S.test("same-version update repairs disabled server context",function()
    local env,_,script=fixture()
    local runner=script(true); runner.Parent=env.container; runner.Enabled=false; runner.RunContext="Client"
    M.change(env,"runner",false)
    assert(runner.Enabled and runner.RunContext=="Legacy")
end)
S.test("unowned matching script is never overwritten or removed",function()
    local env,state,script=fixture()
    local runner=script(false); runner.Parent=env.container; runner.Source="customer code"
    assert(not pcall(M.change,env,"runner",false))
    assert(not pcall(M.change,env,"runner",true))
    assert(runner.Source=="customer code" and runner.Parent==env.container and state.begins==0)
end)
S.test("wrong class, version, edited source or child content blocks mutation",function()
    for _,kind in ipairs({"class","version","source","child"}) do
        local env,state,script=fixture()
        local runner=script(true); runner.Parent=env.container
        if kind=="class" then runner.wrongClass=true
        elseif kind=="version" then runner:SetAttribute("RAVersion","9.0")
        elseif kind=="source" then runner.Source="edited"
        else runner.children={"customer content"} end
        assert(not pcall(M.change,env,"runner",true) and state.begins==0 and runner.Parent==env.container)
    end
end)
S.test("duplicates fail closed",function()
    local env,_,script=fixture()
    script(true).Parent=env.container; script(true).Parent=env.container
    assert(not pcall(M.change,env,"runner",false) and #env.container:GetChildren()==2)
end)
S.test("unsaved editor changes block update and removal",function()
    local env,state,script=fixture({editorSource="unsaved customer edits"})
    local runner=script(true); runner.Parent=env.container
    assert(not pcall(M.change,env,"runner",true) and not pcall(M.change,env,"runner",false))
    assert(runner.Parent==env.container and state.begins==0)
end)
S.test("remove touches only exact owned runner",function()
    local env,state,script=fixture()
    local ours=script(true); ours.Parent=env.container
    local other=script(false); other.Name="CustomerScript"; other.Parent=env.container
    M.change(env,"runner",true)
    assert(ours.Parent==nil and other.Parent==env.container and state.commits==1)
    M.change(env,"runner",true)
    assert(state.commits==1)
end)
S.test("Source write refusal leaves no partially installed asset",function()
    local env,state,_,all=fixture({sourceDenied=true})
    assert(not pcall(M.change,env,"runner",false))
    assert(#env.container:GetChildren()==0 and state.begins==0 and all[1].destroyed)
end)
S.test("undo recording refusal changes no game content",function()
    local env,_,_,all=fixture({beginDenied=true})
    assert(not pcall(M.change,env,"runner",false))
    assert(#env.container:GetChildren()==0 and all[1].destroyed)
end)
S.test("failed install commit rolls back candidate",function()
    local env,state=fixture({commitDenied=true})
    assert(not pcall(M.change,env,"runner",false))
    assert(#env.container:GetChildren()==0 and state.cancels==1)
end)
S.test("failed removal commit restores the same runner",function()
    local env,state,script=fixture({commitDenied=true})
    local ours=script(true); ours.Parent=env.container
    assert(not pcall(M.change,env,"runner",true))
    assert(ours.Parent==env.container and state.cancels==1)
end)
S.test("failed repair commit restores original enabled state and context",function()
    local env,state,script=fixture({commitDenied=true})
    local runner=script(true); runner.Parent=env.container; runner.Enabled=false; runner.RunContext="Client"
    assert(not pcall(M.change,env,"runner",false))
    assert(not runner.Enabled and runner.RunContext=="Client" and state.cancels==1)
end)
S.test("active playtest refuses install and removal",function()
    local env,state=fixture({edit=false})
    assert(not pcall(M.change,env,"runner",false) and not pcall(M.change,env,"runner",true))
    assert(state.begins==0)
end)
S.finish()
