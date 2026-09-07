local Storage = {}
Storage.__index = Storage
local keys = {'mare.options', 'mare.island.1', 'mare.island.2', 'mare.island.3', 'mare.island.1.backup', 'mare.island.2.backup', 'mare.island.3.backup'}

function Storage.new(std)
    return setmetatable({std = std, values = {}}, Storage)
end

function Storage:load(ready)
    local remaining = #keys
    for _, key in ipairs(keys) do
        self.std.storage.get(key):callback(function(value)
            self.values[key] = value or ''
            remaining = remaining - 1
            if remaining == 0 then ready() end
        end):run()
    end
end

function Storage:write(key, value)
    local persisted = false
    self.std.storage.set(key, value):run()
    self.std.storage.get(key):callback(function(actual)
        persisted = actual == value
        if persisted then self.values[key] = value end
    end):run()
    return persisted
end

function Storage:save(slot, value)
    local key = 'mare.island.' .. slot
    local previous = self.values[key]
    if previous ~= '' and not self:write(key .. '.backup', previous) then return false end
    return self:write(key, value)
end

function Storage:options(sound, motion, detail, zoom, light)
    local value = (sound and 'sound' or 'silent') .. ',' .. (motion and 'motion' or 'still') .. ',' .. detail .. ',' .. zoom .. ',' .. light
    assert(self:write('mare.options', value), 'could not persist mare options')
end

return Storage
