-- optimization
local getfenv = getfenv
local string_match = string.match
local assert = assert
local loadfile = loadfile
local error = error

local debug = debug
local debug_getinfo = debug.getinfo

local table_insert = table.insert
local table_remove = table.remove

local coroutine_resume = coroutine.resume
local coroutine_yield = coroutine.yield

local no_args = {}

local os_clock = os.clock

-- import hack
local oldrequire = require
require = function(argname)
    if not getfenv().wait or not string_match(argnmae, "ysched") then
        return oldrequire(argname)
    end
end

-- finds function to schedule
local target
if arg[1] then
    target = assert(loadfile(arg[1]))
elseif debug then
    target = debug_getinfo(3, "f").func -- cheeky hack to support require
else
    error "[SCHEDULER] Error: No arguments or being required without debug library."
end

-- queue code 
local queue = {
    {
        coroutine = coroutine_create(_function)
    }
}

-- scheduler apis 
function spawn(_function)
    table_insert(queue, 1, {
        coroutine = coroutine_create(_function)
    })
end

function yield(condition, _function, ...)  -- ... = args for _function
    local running = coroutine_running()
    table_insert(queue, 1, {
        coroutine = _function and coroutine.create(function(...) _function(...) coroutine_resume(running) end) or running,
        condition = condition,
        ...
    })
    return coroutine_yield()
end

function wait(time)
    table_insert(queue, 1, {
        coroutine = coroutine_running(),
        resumeat = os_clock() + time
    })
    return coroutine_yield()
end

-- start scheduler
local now, step
repeat
    now = os_clock()
    step = table_remove(queue, 1)
    if (not step.condition and not step.resumeAt) or (step.resumeAt and now >= step.resumeAt) or (step.condition and step.condition()) then
        coroutine_resume(step.coroutine, unpack(step))
    else
        queue[#queue + 1] = step
    end
until #queue    == 0
debug.traceback = nil -- remove stacktrace from error in vanilla lua 
error "[SCHEDULER] Execution complete." -- prevent script from running again when required. (side effect of require hack)
