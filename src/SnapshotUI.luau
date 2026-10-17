-- Snapshot authoring/persistence. Engine access and shared native ownership are injected.
local Product = {}
function Product.mount(E)
    local U,M,H,Store=E.ui,E.snapshot,E.http,E.settings
    local PREFIX="regression-arena-v1-"
    local function nowUTC() return os.date("!%Y-%m-%dT%H:%M:%SZ") end
    local function read(key,limit)
        local ok,raw=pcall(function() return E.plugin:GetSetting(PREFIX..key) end)
        return ok and Store.decode(raw,limit,function(v) return H:JSONDecode(v) end) or nil
    end
    local function save(key,value,limit)
        local raw=H:JSONEncode(value)
        return #raw<=limit and Store.save(raw,function(v) E.plugin:SetSetting(PREFIX..key,v) end,
            function() return E.plugin:GetSetting(PREFIX..key) end)
    end
    local page=U.pages.Snapshot
    U:label(page,"Regression Snapshot",26,true)
    U:label(page,"Assert stable server state after one player spawns. Each assertion is read once at the checkpoint; the test never waits until an expected value passes.",82)
    local actions=U:group(page)
    local planActions=U:group(page)
    local project=U:input(page,"Project key — unique to this place","local-demo")
    local name=U:input(page,"Plan name","Door safety")
    local timeout=U:input(page,"Session timeout seconds (5–180)","180")
    local settle=U:input(page,"Checkpoint delay after spawn (0–10 seconds)","1")
    local checks,selected={},nil
    local summary=U:label(page,"No assertions. Add one or load the bundled demo plan below.",76)
    local label=U:input(page,"Assertion label","Door exists")
    local pathInput=U:input(page,"Exact path — service/name/name","Workspace/RA_Demo/Door")
    U:button(page,"Use selected object's path",function()
        local items=E.selection:Get()
        if #items~=1 then U:status("Select exactly one object in Explorer.",true); return end
        local path,node={},items[1]
        while node and node~=game do
            if #node.Name>64 or string.find(node.Name,"[%c/]") then U:status("Use names without slashes or control characters, at most 64 bytes each.",true); return end
            table.insert(path,1,node.Name); node=node.Parent
        end
        if node~=game or not M.ROOTS[path[1]] or #path>8 then U:status("Choose at most eight path names under a supported service.",true); return end
        pathInput.Text=table.concat(path,"/")
    end)
    local sources,operators,kinds={"object","property","attribute"},{"exists","equals","range"},{"boolean","number","string"}
    local si,oi,ki=1,1,1
    local sourceButton,operatorButton,kindButton
    sourceButton=U:button(page,"Source: object (click to change)",function() si=si%3+1; sourceButton.Text="Source: "..sources[si].." (click to change)" end)
    local field=U:input(page,"Property / Attribute name (unused for object)","CanCollide")
    operatorButton=U:button(page,"Condition: exists (click to change)",function() oi=oi%3+1; operatorButton.Text="Condition: "..operators[oi].." (click to change)" end)
    kindButton=U:button(page,"Value type: boolean (click to change)",function() ki=ki%3+1; kindButton.Text="Value type: "..kinds[ki].." (click to change)" end)
    local expected=U:input(page,"Expected — true / false, number, or exact text","true")
    local minimum=U:input(page,"Range minimum (inclusive)","5")
    local maximum=U:input(page,"Range maximum (inclusive)","15")
    U:label(page,"Objects use exists. Properties/Attributes support equals, exists or range. Strings are case sensitive. A range compares against its bounds, never the baseline's exact numeric sample.",96)
    local function refresh()
        local lines={}
        for i,c in ipairs(checks) do table.insert(lines,string.format("%d. %s | %s | %s",i,c.label,c.source,M.expected(c))) end
        summary.Text=#lines>0 and table.concat(lines,"\n").."\nSelected for editing: "..tostring(selected or "none") or "No assertions. Add one or load the demo plan."
        summary.Size=UDim2.new(1,0,0,math.max(76,#checks*38+32))
    end
    local function editorCheck()
        local value=expected.Text
        if operators[oi]=="exists" or kinds[ki]=="boolean" then
            if value~="true" and value~="false" then return nil end
            value=value=="true"
        elseif kinds[ki]=="number" then value=tonumber(value) end
        return M.copyCheck({label=label.Text,path=string.split(pathInput.Text,"/"),source=sources[si],key=field.Text,
            operator=operators[oi],expected=value,min=tonumber(minimum.Text),max=tonumber(maximum.Text)})
    end
    local function invalid() U:status("Invalid assertion. Check path, supported property, typed value and finite bounds. Source is never readable. Maximum 16 assertions.",true) end
    U:button(page,"Add assertion",function()
        local c=editorCheck(); if not c or #checks>=M.MAX_CHECKS then invalid(); return end
        table.insert(checks,c); selected=#checks; refresh(); U:status("Assertion added. Save the plan to retain it locally.")
    end,true)
    U:button(page,"Select next assertion for editing",function()
        if #checks==0 then return end
        selected=(selected or 0)%#checks+1
        local c=checks[selected]; label.Text=c.label; pathInput.Text=table.concat(c.path,"/"); field.Text=c.key
        for i,v in ipairs(sources) do if v==c.source then si=i end end
        for i,v in ipairs(operators) do if v==c.operator then oi=i end end
        for i,v in ipairs(kinds) do if v==type(c.expected) then ki=i end end
        sourceButton.Text="Source: "..sources[si].." (click to change)"
        operatorButton.Text="Condition: "..operators[oi].." (click to change)"
        kindButton.Text="Value type: "..kinds[ki].." (click to change)"
        expected.Text=c.expected==nil and "true" or tostring(c.expected)
        minimum.Text=tostring(c.min or 5); maximum.Text=tostring(c.max or 15); refresh()
    end)
    U:button(page,"Update selected assertion",function()
        local c=editorCheck(); if not selected or not c then invalid(); return end
        checks[selected]=c; refresh(); U:status("Assertion updated. Comparison needs the same definitions as the baseline.")
    end)
    U:button(page,"Remove selected assertion",function() if selected then table.remove(checks,selected); selected=nil; refresh() end end)
    local function plan()
        return M.copyPlan({project=project.Text,name=name.Text,timeout=tonumber(timeout.Text),settle=tonumber(settle.Text),checks=checks})
    end
    local function load(p)
        project.Text=p.project; name.Text=p.name; timeout.Text=tostring(p.timeout); settle.Text=tostring(p.settle)
        checks=p.checks; selected=nil; refresh()
    end
    U:button(planActions,"Save local Snapshot plan",function()
        local p=plan(); local ok=p and save("snapshot-plan",p,M.MAX_REQUEST_BYTES)
        U:status(ok and "Snapshot plan saved and read back locally." or "Invalid plan or local storage failed. Current definitions kept.",not ok)
    end)
    U:button(planActions,"Load saved Snapshot plan",function()
        local p=M.copyPlan(read("snapshot-plan",M.MAX_REQUEST_BYTES))
        if not p then U:status("No valid saved Snapshot plan. Current definitions kept.",true); return end
        load(p); U:status("Saved plan loaded. Use the matching project key for this place.")
    end)
    U:button(planActions,"Load bundled demonstration plan",function()
        local path={"Workspace","RA_Demo","Door"}
        load({project="regression-arena-demo",name="Door safety",timeout=180,settle=1,checks={
            {label="Door exists",path=path,source="object",operator="exists",expected=true},
            {label="Door blocks players",path=path,source="property",key="CanCollide",operator="equals",expected=true},
            {label="Door unlocked",path=path,source="attribute",key="Unlocked",operator="equals",expected=true},
            {label="Reward stays in bounds",path=path,source="attribute",key="Reward",operator="range",min=5,max=15},
            {label="Door mode",path=path,source="attribute",key="Mode",operator="equals",expected="Open"},
        }})
        U:status("Demo definitions loaded. Open the bundled demo place; this action creates no game assets.")
    end)
    local baseline=M.baseline(read("snapshot-baseline",M.MAX_SAVED_BYTES))
    local fresh=nil
    local function rows(result,diff)
        if result.status~="complete" then return {{passed=false,text="FAIL — session infrastructure\nActual: "..result.observed.."\nNext: "..result.nextCheck}} end
        local out={}
        for i,item in ipairs(result.results) do
            local c=result.plan.checks[i]
            local text=(item.passed and "PASS" or "FAIL").." — "..c.label.."\n"..table.concat(c.path,"/")
                ..(c.source=="object" and "" or " • "..c.source.." "..c.key)
                .."\nExpected: "..M.expected(c).."\nActual: "..M.describe(item.actual).."\nReason: "..item.reason
            if diff and diff.results[i] then text..="\nBaseline observed: "..M.describe(diff.results[i].previous) end
            table.insert(out,{passed=item.passed,text=text})
        end
        return out
    end
    local function run(compare)
        local p=plan()
        if not p then U:status("Enter a project key, name, 1–16 assertions and valid time budgets.",true); return end
        if compare and (not baseline or not M.samePlan(baseline.plan,p)) then U:status("No matching successful baseline. Restore its plan/project key, or capture a new successful run.",true); return end
        if not E.ready() then return end
        local request={marker=M.MARKER,version=1,runId=H:GenerateGUID(false),players=1,timeout=p.timeout,plan=p}
        if #H:JSONEncode(request)>M.MAX_REQUEST_BYTES then U:status("Plan is too large. Shorten paths/labels or remove assertions.",true); return end
        local saved=compare and M.baseline(baseline) or nil
        fresh=nil; E.setBusy(true); U:results("RUNNING — no verified result yet",{},"No current report yet.")
        U:status("Starting one-player Snapshot. The checkpoint follows server-side spawning.")
        task.spawn(function()
            local started=os.clock()
            local ok,err=pcall(function()
                local result=E.session:run(request,M)
                if U.disposed then return end
                local safe=M.validateResult(result,request)
                    or M.failure(request,"Invalid Snapshot report; no verified result.",os.clock()-started,"Check Output and native cleanup before retrying.")
                local diff=saved and M.compare(saved,safe,request) or nil
                fresh={request=request,result=safe}
                local report={product="Regression Arena",pluginVersion="1.0.0",dateUTC=nowUTC(),report=safe,comparison=diff}
                local encoded=H:JSONEncode(report)
                local stored=#encoded<=M.MAX_SAVED_BYTES and save("snapshot-report",report,M.MAX_SAVED_BYTES)
                local passed=safe.passed and (not compare or (diff and diff.passed))
                U:results((passed and "PASS" or "FAIL")..(compare and " — baseline comparison" or " — current Snapshot"),rows(safe,diff),encoded)
                U:status((passed and "Assertions passed. " or "Test failed. ")..(stored and "Report saved locally." or "Report storage failed; export the visible JSON."),not passed or not stored)
            end)
            if U.disposed then return end
            E.setBusy(false)
            if not ok then
                fresh=nil; E.session:cancel(); warn("Regression Arena Snapshot failed:",err)
                U:results("FAIL — plugin runtime error",{{passed=false,text="No complete verified report. Check Studio Output and end any active native session."}},"No complete verified report.")
                U:status("Snapshot failed. Current baseline kept. Check Output and native cleanup.",true)
            end
        end)
    end
    U:button(actions,"Run Snapshot",function() run(false) end,true)
    U:button(actions,"Capture current successful Snapshot as baseline",function()
        local p=plan()
        if not fresh or not p or not M.samePlan(p,fresh.request.plan) then U:status("Run this plan successfully first. Saved previous reports cannot capture a baseline.",true); return end
        local candidate=M.capture(fresh.request,fresh.result,nowUTC())
        if not candidate then U:status("Failed or cancelled evidence cannot replace the baseline.",true); return end
        if not save("snapshot-baseline",candidate,M.MAX_SAVED_BYTES) then U:status("Baseline storage failed. In-memory baseline kept.",true); return end
        baseline=candidate; U:status("Successful baseline captured and read back locally for project: "..p.project)
    end)
    U:button(actions,"Rerun and compare with baseline",function() run(true) end,true)
    U:button(actions,"Cancel results (server still finishes)",function()
        if not E.isBusy() then U:status("There is no active run."); return end
        E.session:cancel(); U:status("Results cancelled. Server still finishes; use Studio End Session for immediate termination.",true)
    end,false,true)
    U:button(actions,"Show previous saved Snapshot report",function()
        local saved=read("snapshot-report",M.MAX_SAVED_BYTES)
        local result=type(saved)=="table" and type(saved.report)=="table" and M.validateResult(saved.report,saved.report) or nil
        if not result then U:status("No valid saved Snapshot report.",true); return end
        U:results("SAVED REPORT — previous run",rows(result),H:JSONEncode({product="Regression Arena",dateUTC=saved.dateUTC,report=result}))
    end)
    local setup=U.pages.Setup
    U:label(setup,"Setup & safety",26,true)
    U:label(setup,"Use a disposable local place copy. Game scripts still execute. Disable live data access, purchases and external integrations in that copy yourself; this plugin does not sandbox your game.",108)
    U:label(setup,"1. Install the runner in edit mode.\n2. Configure a Snapshot or Smoke plan.\n3. Run and inspect every failure.\n4. Capture a successful Snapshot baseline.\n5. Rerun after changes and export JSON.",120)
    U:button(setup,"Install / repair owned runner",function() E.changeRunner(false) end,true)
    U:button(setup,"Remove owned runner — Undo available",function() E.changeRunner(true) end)
    U:label(setup,"Runner: ServerScriptService.RegressionArena_TestRunner\nOwner: RegressionArena • Version: 1.0.0\nName collisions, unknown versions, edits and child content are preserved.",104)
    U:label(setup,"Update from 0.2: use the OLD matching plugin's Remove action first. Replace/restart the local plugin, then install 1.0. Unknown or edited code is never overwritten. Restart Studio if a local update hides the toolbar.",114)
    U:label(setup,"Only one initial player is supported. Latejoin adds a second client. Two initial players and four-client mode are excluded from this release. Smoke checks do not prove client UI/gameplay readiness.",108)
    U:label(setup,"Cancel discards results. It cannot terminate the whole native session. Use Studio End Session when required. Invalid native returns keep Run blocked until a Studio restart.",100)
    U:label(setup,"Snapshot roots: Workspace, ReplicatedStorage, ServerStorage, Lighting, SoundService. Paths must be unique, at most eight names. Each plan holds at most 16 assertions. Use stable values and a unique project key for each local place.",126)
    U:label(setup,"Supported properties: Name, ClassName, Value, Anchored, CanCollide, CanTouch, CanQuery, Transparency, Reflectance, Enabled, Brightness, ClockTime, Visible, Active, Text, Volume, PlaybackSpeed, Looped, WalkSpeed, JumpPower, Health, MaxHealth. Only explicit primitive values are read.",152)
    U:label(setup,"No Source reads except owned-runner integrity. No arbitrary code, player identities, network, accounts, telemetry, subscriptions or licensing. Local settings are bounded: one plan, one baseline, one Snapshot report and ten smoke reports.",124)
    U:label(setup,"Remove the runner before shipping your game. It remains inert outside explicitly marked Studio server tests. Snapshot covers only your configured assertions and does not guarantee detection of every bug.",104)
    U:status("Regression Arena 1.0.0. Open Setup and use a disposable place copy.")
    return {invalidate=function() fresh=nil end}
end
return Product
