local Bits = require('lua.native.bits')
local Binary = require('lua.native.binary')
local Work = require('lua.native.work')
local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max
local Cache = {}
Cache.__index = Cache
local limit = 2 * 1024 * 1024

function Cache.new(points)
    return setmetatable({points = points, shapes = {}, entries = {}, queue = {}, first = 1, last = 0, bytes = 0}, Cache)
end

function Cache:shape(cast)
    local shape = self.shapes[cast]
    if shape then return shape end
    local x0, y0, x1, y1, z1 = math.huge, math.huge, -math.huge, -math.huge, 0
    for i = cast[1], cast[1] + cast[2] - 1 do
        local word = Binary.u32(self.points, i * 4 + 1)
        local x, y = ((Bits.band(word, 1023)) - 64) / 64, ((Bits.band((Bits.rshift(word, 10)), 1023)) - 64) / 64
        x0, y0, x1, y1 = min(x0, x), min(y0, y), max(x1, x), max(y1, y)
        z1 = max(z1, (Bits.band((Bits.rshift(word, 20)), 255)) + (Bits.rshift(word, 28)))
        if i % 128 == 0 then Work.check() end
    end
    shape = {x0, y0, x1, y1, z1}
    self.shapes[cast] = shape
    return shape
end

function Cache:lookup(cast, object, res, bin, heights, decks, dx, dy)
    local shape = self:shape(cast)
    local x, y, z = object[2], object[3], object[4]
    local ox, oy = floor(x), floor(y)
    local reach = z + shape[5] + .00001
    local x0 = floor(x + shape[1] + min(0, dx * reach)) - 1
    local y0 = floor(y + shape[2] + min(0, dy * reach)) - 1
    local x1 = ceil(x + shape[3] + max(0, dx * reach)) + 1
    local y1 = ceil(y + shape[4] + max(0, dy * reach)) + 1
    local parts = {cast[1], cast[2], res, bin, z, x - ox, y - oy, x0 - ox, y0 - oy, x1 - ox, y1 - oy, next(decks) and 1 or 0}
    for yy = y0, y1 do
        for xx = x0, x1 do
            parts[#parts + 1] = xx >= 0 and xx <= 24 and yy >= 0 and yy <= 24 and heights[yy * 25 + xx + 1] or 'x'
            parts[#parts + 1] = xx >= 0 and xx < 24 and yy >= 0 and yy < 24 and decks[yy * 24 + xx + 1] or '-'
        end
    end
    local key = table.concat(parts, ',')
    return key, oy * res * (math.floor(24 * res / 32)) + ox * (math.floor(res / 32)), self.entries[key]
end

local function pack(field, origin)
    local words = {}
    for k, mask in pairs(field) do words[#words + 1] = Binary.pack_mask(k - origin, mask) end
    return table.concat(words)
end

function Cache:store(key, origin, ground, deck)
    local entry = {ground = pack(ground, origin), deck = pack(deck, origin)}
    local bytes = #key + #entry.ground + #entry.deck
    entry.bytes = bytes
    if bytes > limit then return entry end
    while self.first <= self.last and (self.bytes + bytes > limit or self.last - self.first >= 63) do
        local old = self.queue[self.first]
        self.bytes = self.bytes - self.entries[old].bytes
        self.entries[old], self.queue[self.first] = nil, nil
        self.first = self.first + 1
    end
    if self.first > self.last then self.first, self.last = 1, 0 end
    self.last = self.last + 1
    self.queue[self.last], self.entries[key] = key, entry
    self.bytes = self.bytes + bytes
    return entry
end

local function apply(words, origin, field, cells, res)
    local stride = math.floor(24 * res / 32)
    local tile_stride = math.floor(res / 32)
    for offset = 1, #words, 8 do
        local relative, mask = Binary.mask(words, offset)
        local k = relative + origin
        field[k] = Bits.bor(field[k], mask)
        local position = k - 1
        cells[floor(position / (stride * res)) * 24 + floor((position % stride) / tile_stride) + 1] = true
        if offset % 2048 == 1 then Work.check() end
    end
end

function Cache:apply(entry, origin, field, deck_field, cells, deck_cells, res)
    apply(entry.ground, origin, field, cells, res)
    apply(entry.deck, origin, deck_field, deck_cells, res)
end

return Cache
