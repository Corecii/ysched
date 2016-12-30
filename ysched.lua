-- optimization

local os_clock = os.clock
local no_args = {}

-- import hack

local oldrequire = require
require = function(argname)
    if not getfenv().wait or not argname:match("ysched") then
        return oldrequire(argname)
    end
end

-- finds function to schedule

local target
if arg[1] then
    target = assert(loadfile(arg[1]))
elseif debug then
    target = debug.getinfo(3, "f").func -- cheeky hack to support require
else
    error "[SCHEDULER] Error: No arguments or being required without debug library."
end

-- queue code 

local queue = {}

function queue:push(task, back)
    if back then
        self[#self + 1] = task
        return
    end
    table.insert(self, 1, task)
end

function queue:pop()
    return table.remove(self, 1)
end

-- scheduler apis 

function spawn(_function)
    queue:push {
        ["coroutine"] = coroutine.create(_function),
        ["condition"] = false,
        ["args"] = no_args,
    }
end

function yield(condition, _function, ...) -- ... = args for _function 
    local args       = {...}
    local truth      = condition
    local running    = coroutine.running()
    local _coroutine = _function and coroutine.create(function(...) _function(...) coroutine.resume(running) end) or coroutine.running()

    queue:push {
        ["coroutine"] = _coroutine,
        ["condition"] = truth,
        ["args"]      = args,
    }

    return coroutine.yield()
end

function wait(time)
    local _coroutine = coroutine.running()

    queue:push {
        ["coroutine"] = _coroutine,
        ["args"] = no_args,
        ["resumeAt"] = os_clock() + time,
    }

    return coroutine.yield()
end

--starts scheduling code

local function startscheduler()
    local now, step
    repeat
        now = os_clock()
        step = queue:pop()
        assert(step, "No step means that something went horribly, horribly wrong")
        if (not step.condition and not step.resumeAt) or (step.resumeAt and now >= step.resumeAt) or (step.condition and step.condition()) then
            coroutine.resume(step.coroutine, unpack(step.args))
        else
            queue:push(step, true)
        end
    until #queue    == 0
    debug.traceback = nil -- remove stacktrace from error in vanilla lua 
    error "[SCHEDULER] Execution complete." -- prevent script from running again when required. (side effect of require hack)
end

-- init

spawn(target) -- put specified function on scheduler 
startscheduler() -- starts scheduling
