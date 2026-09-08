local Bits = require('lua.native.bits')
local Storage = {}
Storage.__index = Storage
local keys = {'mare.options', 'mare.island.1', 'mare.island.2', 'mare.island.3', 'mare.island.1.backup', 'mare.island.2.backup', 'mare.island.3.backup'}
local chunk_size, max_length = 3000, 100000

local function checksum(value)
    local hash = 2166136261
    for i = 1, #value do
        hash = Bits.bxor(hash, value:byte(i))
        hash = (hash * 403 + (hash % 256) * 16777216) % 4294967296
    end
    return hash
end

local function manifest(value)
    if type(value) ~= 'string' then return end
    local bank, count, length, hash = value:match('^MARECHUNK1,([01]),(%d+),(%d+),(%d+)$')
    bank, count, length, hash = tonumber(bank), tonumber(count), tonumber(length), tonumber(hash)
    if not bank or not count or not length or not hash or length <= chunk_size or length > max_length or count ~= math.ceil(length / chunk_size) or hash > 0xffffffff then return end
    return bank, count, length, hash
end

local function part_key(key, bank, index)
    return key .. '.chunk.' .. bank .. '.' .. index
end

local function read_now(std, key)
    local received, value = false, nil
    std.storage.get(key):callback(function(actual) received, value = true, actual end):run()
    return received, value
end

local function write_part(std, key, value)
    std.storage.set(key, value):run()
    local received, actual = read_now(std, key)
    return received and actual == value
end

function Storage.new(std)
    return setmetatable({std = std, values = {}}, Storage)
end

function Storage:load(ready)
    local index = 0
    local function next_key()
        index = index + 1
        local key = keys[index]
        if not key then ready(); return end
        self.std.storage.get(key):callback(function(value)
            local bank, count, length, hash = manifest(value)
            if not bank then self.values[key] = value or ''; next_key(); return end
            local parts, part = {}, 0
            local function next_part()
                part = part + 1
                if part > count then
                    local complete = table.concat(parts)
                    self.values[key] = #complete == length and checksum(complete) == hash and complete or value
                    next_key()
                    return
                end
                self.std.storage.get(part_key(key, bank, part)):callback(function(chunk)
                    local expected = math.min(chunk_size, length - (part - 1) * chunk_size)
                    if type(chunk) ~= 'string' or #chunk ~= expected then
                        self.values[key] = value; next_key(); return
                    end
                    parts[part] = chunk
                    next_part()
                end):run()
            end
            next_part()
        end):run()
    end
    next_key()
end

function Storage:write(key, value)
    if type(value) ~= 'string' or #value > max_length then return false end
    local stored = value
    if #value > chunk_size then
        local received, current = read_now(self.std, key)
        if not received then return false end
        local active = manifest(current)
        local bank = active and 1 - active or 0
        local count = math.ceil(#value / chunk_size)
        for part = 1, count do
            if not write_part(self.std, part_key(key, bank, part), value:sub((part - 1) * chunk_size + 1, part * chunk_size)) then return false end
        end
        stored = string.format('MARECHUNK1,%d,%d,%d,%u', bank, count, #value, checksum(value))
    end
    if not write_part(self.std, key, stored) then return false end
    self.values[key] = value
    return true
end

function Storage:save(slot, value, previous)
    local key = 'mare.island.' .. slot
    if previous ~= '' and not self:write(key .. '.backup', previous) then return false end
    return self:write(key, value)
end

function Storage:options(sound, motion, detail, zoom, light, locale)
    local value = (sound and 'sound' or 'silent') .. ',' .. (motion and 'motion' or 'still') .. ',' .. detail .. ',' .. zoom .. ',' .. light .. ',' .. locale
    assert(self:write('mare.options', value), 'could not persist mare options')
end

return Storage
