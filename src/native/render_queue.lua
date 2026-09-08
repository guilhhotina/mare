local Work = require('lua.native.work')
local unpack = _VERSION == 'Lua 5.1' and unpack or table.unpack
local Queue = {}
Queue.__index = Queue

function Queue.new(world)
    return setmetatable({world = world}, Queue)
end

function Queue:take()
    local plan = self.queued
    if plan then
        self.queued = nil
    elseif self.spare then
        plan, self.spare = self.spare, nil
    else
        plan = {count = 0, size = 0}
    end
    plan.count = 0
    self.recording = plan
end

function Queue:push(method, ...)
    local plan = self.recording
    local count, n = plan.count, select('#', ...)
    plan[count + 1], plan[count + 2] = method, n
    for i = 1, n do plan[count + 2 + i] = select(i, ...) end
    plan.count = count + 2 + n
end

function Queue:seal()
    local plan = self.recording
    for i = plan.count + 1, plan.size do plan[i] = nil end
    plan.size = plan.count
    self.queued, self.recording = plan, nil
end

function Queue:begin(...)
    self:take()
    self:push(self.world.begin, ...)
end

function Queue:finish()
    self:push(self.world.finish)
    self:seal()
end

function Queue:tone(phase)
    local world = self.world
    if self.thread or self.queued or world.pending or not world.current or math.floor(phase * 96) == world.tone_bin then return end
    self:take()
    self:push(world.publish, phase)
    self:seal()
end

function Queue:step()
    if not self.thread then
        local plan = self.queued
        if self.world.pending then return end
        if not plan then return end
        self.running, self.queued = plan, nil
        self.thread = coroutine.create(function()
            local index = 1
            while index <= plan.count do
                local method, n = plan[index], plan[index + 1]
                method(self.world, unpack(plan, index + 2, index + 1 + n))
                index = index + 2 + n
                Work.check()
            end
        end)
    end
    if Work.resume(self.thread, .006) then
        self.spare, self.running, self.thread = self.running, nil, nil
    end
end

return Queue
