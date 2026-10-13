-- Python substitutes the actual generated runner below. Services here are mocks.
local S = require("./Support")
local function run(options)
    options = options or {}
    local request = S.request(options.scenario)
    local state = { ends = 0, leaves = 0, delays = {}, services = {}, warnings = 0 }
    local service = {}
    function service:GetTestArgs()
        if options.argsError then error("GetTestArgs denied") end
        if options.noArgs then return nil end
        return "payload"
    end
    function service:EndTest(value)
        state.ends += 1
        if options.endError then error("EndTest denied") end
        state.result = value
    end
    function service:CanLeaveTest() return true end
    function service:LeaveTest() state.leaves += 1 end
    function service:AddPlayers() error("AddPlayers denied") end
    local players = {}
    function players:GetPlayers()
        local character = { Parent = true }
        function character:FindFirstChildOfClass() return true end
        return options.noCharacters and { {}, {} } or { { Character = character }, { Character = character } }
    end
    local http = {}
    function http:JSONDecode()
        if options.decodeError then error("Bad JSON") end
        if options.badMarker then return {marker="other"} end
        return request
    end
    function http:JSONEncode(value) return value end -- No transport semantics claimed by this mock.
    local runService = {}
    function runService:IsStudio() return options.studio ~= false end
    function runService:IsServer() return options.server ~= false end
    local time = 0
    local os = { clock = function() return time end }
    local task = {
        delay = function(_,callback) table.insert(state.delays,callback) end,
        wait = function(seconds)
            time += seconds
            if options.fireDeadline and time >= request.timeout then
                for _, callback in ipairs(state.delays) do callback() end
            end
        end,
    }
    local warn = function() state.warnings += 1 end
    local game = {}
    function game:GetService(name)
        table.insert(state.services,name)
        return ({ RunService=runService, StudioTestService=service, Players=players, HttpService=http })[name]
    end
    local function installedRunner()
__RUNNER_UNDER_TEST__
    end
    installedRunner()
    return state
end

S.test("published runtime returns before accessing test services",function()
    local state=run({studio=false})
    assert(#state.services==1 and state.ends==0 and #state.delays==0)
end)
S.test("client context returns before accessing test services",function()
    local state=run({server=false})
    assert(#state.services==1 and state.ends==0)
end)
S.test("ordinary playtest with no args remains inert",function()
    local state=run({noArgs=true})
    assert(state.ends==0 and #state.delays==0 and state.leaves==0)
end)
S.test("argument API failure and malformed JSON remain inert",function()
    assert(run({argsError=true}).ends==0)
    assert(run({decodeError=true}).ends==0)
    assert(run({badMarker=true}).ends==0)
end)
S.test("valid marked join reports proven success once",function()
    local state=run()
    assert(state.ends==1 and state.result.passed and state.result.evidence.finalCount==2)
    for _,callback in ipairs(state.delays) do callback() end
    assert(state.ends==1)
end)
S.test("EndTest failure requests cleanup without retrying PASS",function()
    local state=run({endError=true})
    assert(state.ends==1 and state.leaves==1 and state.warnings==1)
    for _,callback in ipairs(state.delays) do callback() end
    assert(state.ends==1)
end)
S.test("server AddPlayers exception becomes diagnostic failure",function()
    local state=run({scenario="latejoin"})
    assert(state.ends==1 and state.result.passed==false and state.warnings==1)
    assert(string.find(state.result.nextCheck,"AddPlayers",1,true))
end)
S.test("server watchdog preserves spawn counts and actionable diagnosis",function()
    local state=run({scenario="spawn",noCharacters=true,fireDeadline=true})
    assert(state.ends==1 and not state.result.passed and state.result.evidence.readyCount==0)
    assert(state.result.evidence.finalCount==2 and string.find(state.result.nextCheck,"CharacterAutoLoads",1,true))
end)
S.finish()
