local Bits = require('lua.native.bits')
local Binary = require('lua.native.binary')
local floor, min, max = math.floor, math.min, math.max
local Actors = {}
Actors.__index = Actors
local markers = {
    [0xfa01faff] = 1, [0xfb01fbff] = 2, [0xfc01fcff] = 3,
    [0x01fafaff] = 4, [0x01fbfbff] = 5, [0x01fcfcff] = 6,
    [0xfafa01ff] = 7, [0xfbfb01ff] = 8, [0xfcfc01ff] = 9
}
local skins = {
    {0xbc8465ff, 0xe4b38dff, 0xf7d2aaff}, {0xc7927cff, 0xefc4acff, 0xffe1c2ff},
    {0x9f684bff, 0xca9167ff, 0xe5b58aff}, {0x815038ff, 0xb17b53ff, 0xd29a6cff},
    {0x573c31ff, 0x82563fff, 0xab7958ff}, {0x372b29ff, 0x594033ff, 0x855c46ff},
    {0x9a795aff, 0xbea078ff, 0xdec39dff}, {0xa86855ff, 0xce957aff, 0xedb9a0ff}
}
local shirts = {
    {0x245958ff, 0x337c77ff, 0x74afa0ff}, {0x822e3fff, 0xc44853ff, 0xec7b7aff},
    {0x9b652fff, 0xd59a49ff, 0xf1c97cff}, {0x625875ff, 0x9789b0ff, 0xc1b4d4ff},
    {0x3f5876ff, 0x647fa7ff, 0x9ab1d0ff}, {0x4a644aff, 0x769363ff, 0xa8be84ff},
    {0xada080ff, 0xdfd3b1ff, 0xfff0cfff}, {0x38494eff, 0x5c6c6aff, 0x94a59cff}
}
local hairs = {
    {0x2d292bff, 0x493a33ff, 0x72604aff}, {0x533c32ff, 0x79513bff, 0xae7851ff},
    {0x977245ff, 0xc7a365ff, 0xead094ff}, {0x693f33ff, 0x9d5d3fff, 0xce8f57ff},
    {0x697779ff, 0x9ba7a1ff, 0xd3d7c6ff}, {0x25272bff, 0x383338ff, 0x5a5050ff},
    {0x46342fff, 0x6a4c3cff, 0xa27758ff}, {0x4b3d50ff, 0x755879ff, 0xaa88a4ff}
}

local function cache(limit, bytes)
    return {entries = {}, count = 0, bytes = 0, limit = limit, byte_limit = bytes}
end

local function touch(c, entry)
    if c.last == entry then return end
    if entry.previous then entry.previous.next = entry.next else c.first = entry.next end
    if entry.next then entry.next.previous = entry.previous end
    entry.previous, entry.next = c.last, nil
    c.last.next, c.last = entry, entry
end

local function remember(c, key, entry, bytes)
    assert(bytes <= c.byte_limit, 'Actor source exceeds cache budget')
    while c.count >= c.limit or c.bytes + bytes > c.byte_limit do
        local old = c.first
        c.entries[old.key], c.first = nil, old.next
        if c.first then c.first.previous = nil else c.last = nil end
        c.count, c.bytes = c.count - 1, c.bytes - old.bytes
    end
    entry.key, entry.bytes, entry.previous = key, bytes, c.last
    if c.last then c.last.next = entry else c.first = entry end
    c.last = entry
    c.entries[key], c.count, c.bytes = entry, c.count + 1, c.bytes + bytes
    return entry
end

local function tinted(color, red, green, blue)
    return floor(Bits.band(Bits.rshift(color, 24), 255) * red / 255 + .5) * 16777216
        + floor(Bits.band(Bits.rshift(color, 16), 255) * green / 255 + .5) * 65536
        + floor(Bits.band(Bits.rshift(color, 8), 255) * blue / 255 + .5) * 256 + Bits.band(color, 255)
end

function Actors.new(resources, depths)
    return setmetatable({resources = resources, depths = depths, sources = cache(512, 2 * 1024 * 1024), appearances = cache(64, 64 * 144), colors = {}, color_order = {}, color_count = 0, color_cursor = 1, tone = -1}, Actors)
end

local function source(self, key, meta)
    key = meta.offset or key
    local entry = self.sources.entries[key]
    if entry then touch(self.sources, entry); return entry end
    entry = {meta = meta, offset = meta.offset, length = meta.length, runs = meta.runs}
    self.resources:source(entry)
    return remember(self.sources, key, entry, #entry.runs * 8)
end

local function palette(self, appearance, scene)
    if appearance == nil then return nil end
    local entry = self.appearances.entries[appearance]
    if entry then touch(self.appearances, entry)
    else
        local skin, shirt, hair = skins[appearance % 8 + 1], shirts[floor(appearance / 8) % 8 + 1], hairs[floor(appearance / 64) % 8 + 1]
        entry = remember(self.appearances, appearance, {base = {skin[1], skin[2], skin[3], shirt[1], shirt[2], shirt[3], hair[1], hair[2], hair[3]}, colors = {}, tone = -1}, 144)
    end
    if entry.tone ~= self.tone then
        for i = 1, 9 do entry.colors[i] = tinted(entry.base[i], scene.tone_red, scene.tone_green, scene.tone_blue) end
        entry.tone = self.tone
    end
    return entry.colors
end

local function color(self, original, scene)
    local tint = self.colors[original]
    if tint then return tint end
    tint = tinted(original, scene.tone_red, scene.tone_green, scene.tone_blue)
    local cursor = self.color_cursor
    if self.color_count == 512 then self.colors[self.color_order[cursor]] = nil
    else self.color_count = self.color_count + 1 end
    self.color_order[cursor], self.colors[original] = original, tint
    self.color_cursor = cursor % 512 + 1
    return tint
end

local function draw_layer(self, scene, key, wx, wy, z, appearance)
    local meta = assert(self.resources.sprites[key], key)
    local zoom, factor = scene.zoom, scene.factor
    local sx = floor(scene.ox + (wx - wy - scene.cx + scene.cy) * 32 * zoom - meta.ox * zoom)
    local sy = floor(scene.oy + (wx + wy - scene.cx - scene.cy) * 16 * zoom - z * zoom - meta.oy * zoom)
    if sx >= 1280 or sy >= 720 or sx + meta.w * zoom <= 0 or sy + meta.h * zoom <= 0 then return end
    local step_x = sx % factor == 0 and factor or 1
    local step_y = sy % factor == 0 and factor or 1
    local runs, depth, std = source(self, key, meta).runs, scene.depth, self.resources.std
    local base, inverse, last_color = wx + wy + z * .0625, 1 / zoom, nil
    for i = 1, #runs, 4 do
        local original = runs[i + 3]
        local marker = appearance and markers[original]
        local tint = marker and appearance[marker] or color(self, original, scene)
        if tint ~= last_color then std.draw.color(tint); last_color = tint end
        local row = sy + runs[i + 1] * zoom
        local left, right = max(0, sx + runs[i] * zoom), min(1280, sx + (runs[i] + runs[i + 2]) * zoom)
        local value = base + (meta.oy - runs[i + 1]) * .0625
        local source_row = meta.depth and meta.depth[1] + runs[i + 1] * meta.w * 2
        for yy = max(0, row), min(720, row + zoom) - step_y, step_y do
            local offset, start = floor(yy / factor) * depth.w, nil
            for xx = left, right - step_x, step_x do
                if source_row then
                    value = base + Binary.i16(self.depths, source_row + floor((xx - sx) * inverse) * 2 + 1) * .00390625
                end
                if depth.pixels[offset + floor(xx / factor) + 1] <= value + .08 then
                    if not start then start = xx end
                elseif start then
                    std.draw.rect(0, start, yy, xx - start, step_y)
                    start = nil
                end
            end
            if start then std.draw.rect(0, start, yy, right - start, step_y) end
        end
    end
end

function Actors:draw(scene, key, wx, wy, z, appearance, accessory_key)
    local tone = scene.tone_red * 65536 + scene.tone_green * 256 + scene.tone_blue
    if self.tone ~= tone then
        for i = 1, self.color_count do self.colors[self.color_order[i]], self.color_order[i] = nil, nil end
        self.color_count, self.color_cursor, self.tone = 0, 1, tone
    end
    local colors = palette(self, appearance, scene)
    draw_layer(self, scene, key, wx, wy, z, colors)
    if accessory_key and self.resources.sprites[accessory_key] then draw_layer(self, scene, accessory_key, wx, wy, z, colors) end
end

return Actors
