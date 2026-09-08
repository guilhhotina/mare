local web=type(mare_load)=='function'
local Platform
if web then
Platform=(function()
local camera={}
return {
    text = mare_text,
    text_width = mare_text_width,
    sprite = mare_sprite,
    skin = mare_skin,
    sound = mare_sound,
    load = mare_load,
    backup = mare_backup,
    save = mare_save,
    cache_begin = function(csv,cx,cy,zoom,ox,oy,...)
        camera.cx,camera.cy,camera.zoom,camera.ox,camera.oy=cx,cy,zoom,ox,oy
        return mare_cache_begin(csv,cx,cy,zoom,ox,oy,...)
    end,
    camera = function() return camera end,
    cache_end = mare_cache_end,
    scene = mare_scene,
    depth = mare_depth,
    actor = mare_actor,
    shadow = mare_shadow,
    ground_light = mare_ground_light,
    bridge = mare_bridge,
    world = mare_world,
    effects = mare_effects,
    thumb = mare_thumb,
    minimap = mare_minimap,
    burst = mare_burst,
    options = mare_options,
    get_options = mare_get_options,
    register = mare_register,
    take_key = mare_take_key,
    ui_begin = mare_ui_begin,
    ui_end = mare_ui_end
}

end)()
else
package.preload["lua.native.actors"]=function(...)
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

end
package.preload["lua.native.assets"]=function(...)
local Assets = {progress = 0}
local base, manifest
local paths = {}

function Assets.configure(url, files)
    base, manifest = url, files
    Assets.remote = true
end

local function temporary(extension)
    local path = os.tmpname()
    local file = assert(io.open(path, 'wb'))
    assert(file:close())
    local renamed = path .. extension
    assert(os.rename(path, renamed))
    return renamed
end

function Assets.path(name)
    if base then return assert(paths[name], 'native asset is not ready: ' .. name) end
    return 'assets/' .. name
end

function Assets.texture(serial)
    if base then return temporary('.tga') end
    return 'cache/texture-' .. serial .. '.tga'
end

function Assets.prepare(std, ready)
    if not base then ready(); return end
    local index = 0
    local function next_asset()
        index = index + 1
        if index > #manifest then ready(); return end
        local asset = manifest[index]
        std.http.get(base .. asset[1]):success(function(response)
            local body = response.http.body
            assert(type(body) == 'string' and #body == asset[2], 'native asset size mismatch: ' .. asset[1])
            local path = temporary(asset[1]:match('%.[^.]+$'))
            paths[asset[1]] = path
            local file = assert(io.open(path, 'wb'))
            assert(file:write(body))
            assert(file:close())
            Assets.progress = index / #manifest
            next_asset()
        end):failed(function(response)
            error('native asset request failed: ' .. asset[1] .. ' HTTP ' .. tostring(response.http.status))
        end):error(function(response)
            error('native asset request failed: ' .. asset[1] .. ': ' .. tostring(response.http.error))
        end):run()
    end
    next_asset()
end

function Assets.close()
    for name, path in pairs(paths) do
        assert(os.remove(path))
        paths[name] = nil
    end
end

return Assets

end
package.preload["lua.native.binary"]=function(...)
local byte, char, floor = string.byte, string.char, math.floor
local Binary = {}

function Binary.u32(data, offset)
    local a, b, c, d = byte(data, offset, offset + 3)
    return a + b * 256 + c * 65536 + d * 16777216
end

function Binary.i16(data, offset)
    local a, b = byte(data, offset, offset + 1)
    return a + (b < 128 and b or b - 256) * 256
end

function Binary.run(data, offset)
    local a, b, c, d, e, f, r, g, blue, alpha = byte(data, offset, offset + 9)
    return a * 256 + b, c * 256 + d, e * 256 + f, r * 16777216 + g * 65536 + blue * 256 + alpha
end

function Binary.mask(data, offset)
    local relative = Binary.u32(data, offset)
    if relative >= 2147483648 then relative = relative - 4294967296 end
    return relative, Binary.u32(data, offset + 4)
end

function Binary.pack_mask(relative, mask)
    return char(relative % 256, floor(relative / 256) % 256, floor(relative / 65536) % 256, floor(relative / 16777216) % 256,
        mask % 256, floor(mask / 256) % 256, floor(mask / 65536) % 256, floor(mask / 16777216) % 256)
end

function Binary.tga_header(width, height)
    return char(0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, width % 256, floor(width / 256), height % 256, floor(height / 256), 32, 40)
end

return Binary

end
package.preload["lua.native.bits"]=function(...)
if _VERSION == 'Lua 5.4' then
    return assert(load([[
        return {
            band = function(a, b) return (a & b) & 0xffffffff end,
            bor = function(a, b) return (a | b) & 0xffffffff end,
            bxor = function(a, b) return (a ~ b) & 0xffffffff end,
            lshift = function(a, b) return (a << b) & 0xffffffff end,
            rshift = function(a, b) return (a & 0xffffffff) >> b end
        }
    ]], 'native bits', 't'))()
end
assert(_VERSION == 'Lua 5.1', 'native renderer requires LuaJIT or Lua 5.4')
local bit = require('bit')
local function unsigned(value)
    if value < 0 then return value + 4294967296 end
    return value
end
return {
    band = function(a, b) return unsigned(bit.band(a, b)) end,
    bor = function(a, b) return unsigned(bit.bor(a, b)) end,
    bxor = function(a, b) return unsigned(bit.bxor(a, b)) end,
    lshift = function(a, b) return unsigned(bit.lshift(a, b)) end,
    rshift = function(a, b) return unsigned(bit.rshift(a, b)) end
}

end
package.preload["lua.native.depth"]=function(...)
local Binary = require('lua.native.binary')
local Work = require('lua.native.work')
local floor, min, max = math.floor, math.min, math.max
local byte = string.byte
local Depth = {}
Depth.__index = Depth

function Depth.new(w, h)
    local pixels = {}
    for i = 1, w * h do
        pixels[i] = -math.huge
        if i % 2048 == 0 then Work.check() end
    end
    return setmetatable({w = w, h = h, pixels = pixels}, Depth)
end

function Depth:clear()
    for i = 1, self.w * self.h do
        self.pixels[i] = -math.huge
        if i % 2048 == 0 then Work.check() end
    end
end

function Depth:stamp(meta, x, y, scale, base, data)
    if not meta.depth then return end
    local x0, y0 = floor(x + .5), floor(y + .5)
    if scale == 1 then
        local left, right = max(0, -x0), min(meta.w, self.w - x0) - 1
        local pixels = self.pixels
        for yy = max(0, -y0), min(meta.h, self.h - y0) - 1 do
            local at = meta.depth[1] + (yy * meta.w + left) * 2 + 1
            local target = (y0 + yy) * self.w + x0 + left + 1
            for position = at, at + (right - left) * 2, 2 do
                local low, high = byte(data, position, position + 1)
                local value = low + (high < 128 and high or high - 256) * 256
                if value ~= -32768 then pixels[target] = base + value / 256 end
                target = target + 1
            end
            Work.check()
        end
        return
    end
    local w, h = floor(meta.w * scale + .5), floor(meta.h * scale + .5)
    local inverse, pixels = 1 / scale, self.pixels
    for yy = max(0, -y0), min(h, self.h - y0) - 1 do
        local source_row = min(meta.h - 1, floor((yy + .5) * inverse)) * meta.w
        local row = (y0 + yy) * self.w + x0
        for xx = max(0, -x0), min(w, self.w - x0) - 1 do
            local source = source_row + min(meta.w - 1, floor((xx + .5) * inverse))
            local value = Binary.i16(data, meta.depth[1] + source * 2 + 1)
            if value ~= -32768 then pixels[row + xx + 1] = base + value / 256 end
        end
        Work.check()
    end
end

return Depth

end
package.preload["lua.native.ocean"]=function(...)
local Bits = require('lua.native.bits')
local Surface = require('lua.native.surface')
local Work = require('lua.native.work')
local floor, min, max = math.floor, math.min, math.max
local Ocean = {}
Ocean.__index = Ocean
local palette = {{118,192,174},{84,175,171},{53,151,166},{39,132,155},{35,117,144},{35,117,144}}
local colors = {}
for band = 0, 4 do
    local c, b = palette[band + 1], palette[band + 2]
    for step = 0, 4 do
        local blend = step / 4
        local r = floor(c[1] + (b[1] - c[1]) * blend + .5)
        local g = floor(c[2] + (b[2] - c[2]) * blend + .5)
        local blue = floor(c[3] + (b[3] - c[3]) * blend + .5)
        colors[band * 5 + step + 1] = r * 16777216 + g * 65536 + blue * 256 + 255
    end
end
local caustics = {}
for y = 0, 63 do
    for x = 0, 63 do caustics[y * 64 + x + 1] = math.sin(x * .61 + y * .37) + math.cos(x * .43 - y * .51) > 1.68 and 7 or 0 end
end

function Ocean.new()
    return setmetatable({height_key = '', shore_key = '', sea_key = '', heights = {}, waves = {}}, Ocean)
end

function Ocean:distance(x, y)
    x, y = x * 4 + 15.5, y * 4 + 15.5
    if x < 0 or y < 0 or x >= 127 or y >= 127 then return 12 end
    local ix, iy = floor(x), floor(y)
    local u, v, a = x - ix, y - iy, self.field
    local k = iy * 128 + ix + 1
    return ((a[k] * (1 - u) + a[k + 1] * u) * (1 - v) + (a[k + 128] * (1 - u) + a[k + 129] * u) * v) * .25
end

function Ocean:terrain(csv)
    if csv == self.height_key then return false end
    self.height_key = csv
    local heights, n = self.heights, 0
    for value in csv:gmatch('[^,]+') do n = n + 1; heights[n] = tonumber(value) end
    local shore = {}
    for y = 0, 23 do
        for x = 0, 23 do
            local k = y * 25 + x + 1
            shore[#shore + 1] = max(heights[k], heights[k + 1], heights[k + 25], heights[k + 26]) > 0 and '1' or '0'
        end
    end
    local signature = table.concat(shore)
    if signature == self.shore_key then return false end
    self.shore_key = signature
    local a = self.field or {}
    self.field = a
    for y = 0, 127 do
        local wy = floor(y / 4) - 4
        local row = y * 128
        for cell = 0, 31 do
            local wx = cell - 4
            local value = wx >= 0 and wx < 24 and wy >= 0 and wy < 24
                and shore[wy * 24 + wx + 1] == '1' and 0 or 100
            local k = row + cell * 4 + 1
            a[k], a[k + 1], a[k + 2], a[k + 3] = value, value, value, value
        end
        Work.check()
    end
    for y = 0, 127 do
        for x = 0, 127 do
            local q = y * 128 + x + 1
            local v = a[q]
            if x > 0 then v = min(v, a[q - 1] + 1) end
            if y > 0 then v = min(v, a[q - 128] + 1) end
            if x > 0 and y > 0 then v = min(v, a[q - 129] + 1.4142) end
            if x < 127 and y > 0 then v = min(v, a[q - 127] + 1.4142) end
            a[q] = v
        end
        Work.check()
    end
    for y = 127, 0, -1 do
        for x = 127, 0, -1 do
            local q = y * 128 + x + 1
            local v = a[q]
            if x < 127 then v = min(v, a[q + 1] + 1) end
            if y < 127 then v = min(v, a[q + 128] + 1) end
            if x < 127 and y < 127 then v = min(v, a[q + 129] + 1.4142) end
            if x > 0 and y < 127 then v = min(v, a[q + 127] + 1.4142) end
            a[q] = v
        end
        Work.check()
    end
    local image = self.ocean or Surface.new(512, 512)
    self.ocean = image
    local pixels = image.pixels
    for y = 0, 511 do
        local row = y * 512
        if y < 2 or y > 509 then
            for x = 1, 512 do pixels[row + x] = 0x237590ff end
        else
            pixels[row + 1], pixels[row + 2] = 0x237590ff, 0x237590ff
            pixels[row + 511], pixels[row + 512] = 0x237590ff, 0x237590ff
            local sy = y * .25 - .375
            local iy = floor(sy)
            local v = sy - iy
            local iv, field_row = 1 - v, iy * 128
            local hash_y, caustic_row, streak_y = y * 668265263, (y % 64) * 64, y * 3
            for cell = 0, 126 do
                local q = field_row + cell + 1
                local a0, a1, a2, a3 = a[q], a[q + 1], a[q + 128], a[q + 129]
                local first = cell * 4 + 2
                local k = row + first + 1
                if a0 >= 9 and a1 >= 9 and a2 >= 9 and a3 >= 9 then
                    pixels[k], pixels[k + 1], pixels[k + 2], pixels[k + 3] = 0x237590ff, 0x237590ff, 0x237590ff, 0x237590ff
                else
                    for offset = 0, 3 do
                        local u = (offset + .5) * .25
                        local iu = 1 - u
                        local d = ((a0 * iu + a1 * u) * iv + (a2 * iu + a3 * u) * v) * .25
                        local color = 0x237590ff
                        if d < 2.2 then
                            local x = first + offset
                            local f = d * 2.35
                            local band = min(4, floor(f))
                            local step = min(4, floor((f - band) * 4 + .5))
                            local hash = Bits.band((x * 374761393 + hash_y), 0xffffffff)
                            hash = Bits.bxor(hash, (Bits.rshift(hash, 13)))
                            local grain = hash % 3 - 1
                            local caustic = d < 1.4 and caustics[caustic_row + x % 64 + 1] or 0
                            color = colors[band * 5 + step + 1] + (grain + caustic) * 0x01010100
                            if d > .09 and d < .17 and (x + streak_y) % 17 < 11 then color = 0xb3dbbfff end
                        end
                        pixels[k + offset] = color
                    end
                end
            end
        end
        Work.check()
    end
    return true
end

function Ocean:prepare(csv, cx, cy, zoom, ox, oy)
    local changed = self:terrain(csv)
    local key = cx .. ',' .. cy .. ',' .. zoom .. ',' .. ox .. ',' .. oy
    if not changed and key == self.sea_key then return false end
    self.sea_key = key
    local image = self.sea or Surface.new(640, 360)
    self.sea = image
    local e = (ox + (-cx + cy) * 32 * zoom) / 2
    local f = (oy + (-8 - cx - cy) * 16 * zoom) / 2
    local inverse = 1 / zoom
    local columns = self.columns or {}
    self.columns = columns
    for x = 0, 639 do columns[x + 1] = (x + .5 - e) * inverse * .5 end
    local pixels, ocean = image.pixels, self.ocean.pixels
    for y = 0, 359 do
        local yy = (y + .5 - f) * inverse
        local row = y * 640
        for x = 0, 639 do
            local xx = columns[x + 1]
            local sx, sy = yy + xx, yy - xx
            pixels[row + x + 1] = sx >= 0 and sx < 512 and sy >= 0 and sy < 512
                and ocean[floor(sy) * 512 + floor(sx) + 1] or 0x237590ff
        end
        Work.check()
    end
    local waves = {}
    for j = 0, 239 do
        local wx, wy = ((j * 73 + 13) % 310) / 10 - 3, ((j * 137 + 39) % 310) / 10 - 3
        local d = self:distance(wx, wy)
        if d >= .25 then
            local sx = ox + (wx - wy - cx + cy) * 32 * zoom
            local sy = oy + (wx + wy - cx - cy) * 16 * zoom
            if sx > 0 and sx < 1280 and sy > 90 and sy < 720 then waves[#waves + 1] = {sx, sy, 8 + (j % 5) * 4, j, d} end
            if #waves == 44 then break end
        end
    end
    self.waves = waves
    return true
end

return Ocean

end
package.preload["lua.native.platform"]=function(...)
local Assets = require('lua.native.assets')
local Resources = require('lua.native.resources')
local UI = require('lua.native.ui')
local World = require('lua.native.world')
local Storage = require('lua.native.storage')
local RenderQueue = require('lua.native.render_queue')
local Bits = require('lua.native.bits')
local Platform = {}
local resources, ui, world, storage, proxy, render_queue
local initialized = false
local queue, pressed, read_index, write_index = {}, {}, 0, 0
local input_keys = {up = true, down = true, left = true, right = true, a = true, menu = true}
local sounds = {'sound-0.wav', 'sound-1.wav', 'sound-2.wav'}

function Platform.cache_begin(...) render_queue:begin(...) end
function Platform.cache_end() render_queue:finish() end
function Platform.scene(...) render_queue:push(world.scene, ...) end
function Platform.depth(...) render_queue:push(world.stamp, ...) end
function Platform.actor(...) world:actor(...) end
function Platform.shadow(...) render_queue:push(world.shadow, ...) end
function Platform.ground_light(...) render_queue:push(world.ground_light, ...) end
function Platform.bridge(...) render_queue:push(world.bridge, ...) end
function Platform.world(phase, ...) render_queue:tone(phase); world:draw(phase, ...) end
function Platform.camera() return world.current end
function Platform.effects(...) world:effects(...) end
function Platform.burst(...) world:burst(...) end
function Platform.text(...) return ui:text(...) end
function Platform.text_width(...) return ui:width(...) end
function Platform.skin(...) ui:skin(...) end
function Platform.thumb(...) ui:thumb(...) end

function Platform.sprite(key, x, y, scale, alpha, lit)
    if render_queue.recording then render_queue:push(world.sprite, key, x, y, scale, alpha, lit)
    else ui:sprite(key, x, y, scale, alpha) end
end

function Platform.minimap(x, y, size) world:minimap(x, y, size, ui.offset) end
function Platform.ui_begin(elapsed, motion)
    ui.offset = motion and elapsed < 140 and math.floor((1 - elapsed / 140) * 4) * 2 or 0
end
function Platform.ui_end() ui.offset = 0 end
function Platform.sound(kind) native_audio_sfx_play(0, Assets.path(sounds[kind + 1])) end
function Platform.load(slot) return storage.values['mare.island.' .. slot] end
function Platform.backup(slot) return storage.values['mare.island.' .. slot .. '.backup'] end
function Platform.save(slot, value, previous) return storage:save(slot, value, previous) end
function Platform.options(...) storage:options(...) end
function Platform.get_options() return storage.values['mare.options'] end
function Platform.register(inspect) Platform.inspect = inspect end

function Platform.take_key()
    if read_index == write_index then return false end
    local key = queue[read_index % 32 + 1]
    read_index = read_index + 1
    return key
end

function Platform.attach(app)
    local init, loop, draw = app.callbacks.init, app.callbacks.loop, app.callbacks.draw
    app.config = {require = Assets.remote and 'storage http' or 'storage', fps_max = 30}
    app.callbacks.init = function(self, std)
        Assets.prepare(std, function()
        resources = Resources.new(std)
        ui = UI.new(resources)
        world, storage = World.new(resources, ui), Storage.new(std)
        render_queue = RenderQueue.new(world)
        local native_rect, native_line = std.draw.rect, std.draw.line
        local color = 0xffffffff
        proxy = setmetatable({draw = {
            color = function(value) color = value; std.draw.color(value) end,
            rect = function(mode, x, y, w, h)
                if Bits.band(color, 255) < 255 and mode == 0 then ui:rect(x, y, w, h, color)
                else native_rect(mode, x, y + ui.offset, w, h) end
            end,
            line = function(x1, y1, x2, y2) native_line(x1, y1 + ui.offset, x2, y2 + ui.offset) end
        }}, {__index = std})
        std.bus.listen('rkey', function(key, value)
            if not input_keys[key] then return end
            local down = value ~= 0 and value ~= false and value ~= nil
            if down and not pressed[key] then
                if write_index - read_index >= 32 then read_index = read_index + 1 end
                queue[write_index % 32 + 1] = key
                write_index = write_index + 1
            end
            pressed[key] = down
        end)
        storage:load(function()
            init(self, proxy)
            initialized = true
        end)
        end)
    end
    app.callbacks.loop = function(self, std)
        if resources then resources:poll(std.delta) end
        if initialized then loop(self, proxy); render_queue:step() end
    end
    app.callbacks.draw = function(self, std)
        if initialized then
            draw(self, proxy)
        elseif Assets.remote then
            std.draw.color(0x182536ff)
            std.draw.rect(0, 0, 0, 1280, 720)
            std.draw.color(0xf5e7c6ff)
            std.text.font_size(32)
            std.text.print(48, 48, 'Maré')
            std.draw.rect(0, 48, 108, math.floor(1184 * Assets.progress), 8)
        end
    end
    app.callbacks.exit = function()
        if initialized then
            local value = Platform.inspect('checkpoint')
            if value ~= '' then assert(Platform.save(Platform.inspect('slot'), value, Platform.inspect('previous-save')), 'could not save island on exit') end
        end
        if resources then resources:close() end
        Assets.close()
        initialized = false
    end
    return app
end

return Platform

end
package.preload["lua.native.raycast"]=function(...)
local floor, min, max = math.floor, math.min, math.max
local epsilon = 1e-8

return function(heights, decks, x, y, z, dx, dy)
    local enter, leave = 0, z
    if dx ~= 0 then
        local a, b = -x / dx, (24 - x) / dx
        if a > b then a, b = b, a end
        enter, leave = max(enter, a), min(leave, b)
    elseif x < 0 or x >= 24 then return end
    if dy ~= 0 then
        local a, b = -y / dy, (24 - y) / dy
        if a > b then a, b = b, a end
        enter, leave = max(enter, a), min(leave, b)
    elseif y < 0 or y >= 24 then return end
    if enter > leave then return end
    local px, py = x + dx * enter, y + dy * enter
    local xx, yy = floor(px), floor(py)
    if dx < 0 and px == xx then xx = xx - 1 end
    if dy < 0 and py == yy then yy = yy - 1 end
    xx, yy = max(0, min(23, xx)), max(0, min(23, yy))
    local step_x, step_y = dx < 0 and -1 or 1, dy < 0 and -1 or 1
    local next_x = dx == 0 and math.huge or (xx + (dx > 0 and 1 or 0) - x) / dx
    local next_y = dy == 0 and math.huge or (yy + (dy > 0 and 1 or 0) - y) / dy
    local stride_x = dx == 0 and math.huge or step_x / dx
    local stride_y = dy == 0 and math.huge or step_y / dy
    while xx >= 0 and xx < 24 and yy >= 0 and yy < 24 do
        local finish = min(leave, next_x, next_y)
        local k = yy * 25 + xx + 1
        local a, b, c, d = heights[k] * 16, heights[k + 1] * 16, heights[k + 26] * 16, heights[k + 25] * 16
        local deck = decks[yy * 24 + xx + 1]
        local hit = deck and z - deck or math.huge
        if hit < enter - epsilon or hit > finish + epsilon then hit = math.huge end
        if z - finish <= max(a, b, c, d) + epsilon then
            local u, v = x - xx, y - yy
            local gx, gy = b - a, c - b
            local denominator = 1 + gx * dx + gy * dy
            if denominator > 0 then
                local t = (z - a - gx * u - gy * v) / denominator
                if t >= enter - epsilon and t <= finish + epsilon and u - v + (dx - dy) * t >= -epsilon then hit = min(hit, t) end
            end
            gx, gy = c - d, d - a
            denominator = 1 + gx * dx + gy * dy
            if denominator > 0 then
                local t = (z - a - gx * u - gy * v) / denominator
                if t >= enter - epsilon and t <= finish + epsilon and u - v + (dx - dy) * t <= epsilon then hit = min(hit, t) end
            end
        end
        if hit < math.huge then
            hit = max(enter, hit)
            return x + dx * hit, y + dy * hit, z - hit
        end
        if finish >= leave then return end
        enter = finish
        if next_x <= finish then xx, next_x = xx + step_x, next_x + stride_x end
        if next_y <= finish then yy, next_y = yy + step_y, next_y + stride_y end
    end
end

end
package.preload["lua.native.render_queue"]=function(...)
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

end
package.preload["lua.native.resources"]=function(...)
local Assets = require('lua.native.assets')
local Binary = require('lua.native.binary')
local Surface = require('lua.native.surface')
local Work = require('lua.native.work')
local Resources = {}
Resources.__index = Resources

function Resources.new(std)
    return setmetatable({
        std = std,
        sprites = dofile(Assets.path('sprites.lua')),
        fonts = dofile(Assets.path('fonts.lua')),
        file = assert(io.open(Assets.path('pixels.bin'), 'rb')),
        textures = {}, pending = {}, writing = {}, serial = 0, frame = 0, bytes = 0, count = 0,
        limit = 32 * 1024 * 1024
    }, Resources)
end

function Resources:source(meta)
    if not meta.runs then
        assert(self.file:seek('set', meta.offset))
        local data = assert(self.file:read(meta.length))
        local runs, at = {}, 1
        for pos = 1, #data, 10 do
            local x, y, w, color = Binary.run(data, pos)
            runs[at], runs[at + 1], runs[at + 2], runs[at + 3] = x, y, w, color
            at = at + 4
            if pos % 2560 == 1 then Work.check() end
        end
        meta.runs = runs
    end
    return meta
end

function Resources:bitmap(meta)
    self:source(meta)
    if not meta.pixels then
        local bitmap = Surface.new(meta.w, meta.h)
        bitmap:blit(meta, 0, 0, 1)
        meta.pixels = bitmap.pixels
    end
    return meta
end

function Resources:find(key)
    local entry = self.textures[key]
    if entry then entry.used = self.frame end
    return entry
end

function Resources:remove(entry)
    self.std.image.unload(entry.id)
    assert(os.remove(entry.path))
    self.textures[entry.key] = nil
    self.bytes = self.bytes - entry.bytes
    self.count = self.count - 1
end

function Resources:trim(needed)
    while self.bytes + needed > self.limit or self.count >= 240 do
        local oldest
        for _, entry in pairs(self.textures) do
            if entry.ready and not entry.pinned and entry.used < self.frame and (not oldest or entry.used < oldest.used) then oldest = entry end
        end
        if not oldest then error('native texture working set exceeds cache budget') end
        self:remove(oldest)
    end
end

function Resources:add(key, surface, scale, red, green, blue, light, intensity, pinned)
    scale = scale or 1
    local bytes = surface.w * surface.h * scale * scale * 4
    self:trim(bytes)
    self.serial = self.serial + 1
    local path = Assets.texture(self.serial)
    self.bytes, self.count = self.bytes + bytes, self.count + 1
    self.writing[path] = true
    surface:write(path, scale, red, green, blue, light, intensity)
    self.writing[path] = nil
    local entry = {
        key = key, path = path, id = self.std.image.load(Assets.remote and 'file://' .. path or path), bytes = bytes,
        w = surface.w * scale, h = surface.h * scale,
        used = self.frame, pinned = pinned, ready = false
    }
    self.textures[key] = entry
    self.pending[#self.pending + 1] = entry
    return entry
end

function Resources:poll(dt)
    self.frame = self.frame + 1
    for i = #self.pending, 1, -1 do
        local entry = self.pending[i]
        local w, h = self.std.image.mensure(entry.id)
        if w == entry.w and h == entry.h then
            entry.ready = true
            table.remove(self.pending, i)
        else
            entry.waiting = entry.waiting and entry.waiting + dt or 0
            if entry.waiting > 5000 then error('native image did not load: ' .. entry.path) end
        end
    end
end

function Resources:draw(entry, x, y)
    entry.used = self.frame
    self.std.image.draw(entry.id, math.floor(x + .5), math.floor(y + .5))
end

function Resources:close()
    for _, entry in pairs(self.textures) do
        self.std.image.unload(entry.id)
        assert(os.remove(entry.path))
    end
    for path in pairs(self.writing) do assert(os.remove(path)) end
    assert(self.file:close())
end

return Resources

end
package.preload["lua.native.shadow_cache"]=function(...)
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

end
package.preload["lua.native.shadows"]=function(...)
local Assets = require('lua.native.assets')
local Bits = require('lua.native.bits')
local Binary = require('lua.native.binary')
local Surface = require('lua.native.surface')
local raycast = require('lua.native.raycast')
local ShadowCache = require('lua.native.shadow_cache')
local Work = require('lua.native.work')
local floor, min, max = math.floor, math.min, math.max
local Shadows = {}
Shadows.__index = Shadows

function Shadows.new(resources, heights)
    local file = assert(io.open(Assets.path('shadow-shapes.bin'), 'rb'))
    local points = assert(file:read('*a'))
    assert(file:close())
    return setmetatable({resources = resources, heights = heights, points = points, cache = ShadowCache.new(points), projections = {}, field = {}, tiles = {}, cells = {}, shadow_cells = {}}, Shadows)
end

function Shadows:ground(x, y)
    local xx, yy = min(23, max(0, floor(x))), min(23, max(0, floor(y)))
    local u, v, heights = max(0, min(1, x - xx)), max(0, min(1, y - yy)), self.heights
    local k = yy * 25 + xx + 1
    local a, b, c, d = heights[k], heights[k + 1], heights[k + 26], heights[k + 25]
    return (u >= v and a + u * (b - a) + v * (c - b) or a + u * (c - d) + v * (d - a)) * 16
end

function Shadows:prepare(csv, scene, phase, detail)
    local daylight = phase > .18 and phase < .79
    local bin = daylight and floor(phase * 48) or -2
    local key = csv .. '|' .. scene .. '|' .. bin .. '|' .. detail
    if self.key == key then return end
    self.key, self.sun = key, daylight
    self.res = detail == 1 and 64 or 32
    local res, field = self.res, self.field
    local n = 24 * res
    local stride = math.floor(n / 32)
    self.n = n
    for i = 1, math.floor(n * n / 32) do field[i] = 0 end
    self.tiles, self.cells, self.shadow_cells, self.deck_shadow_cells = {}, {}, {}, {}
    self.decks, self.deck_field = {}, self.deck_field or {}
    local objects = {}
    for row in scene:gmatch('[^;]+') do
        local name, x, y, z, powered = row:match('([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)')
        local object = {name, tonumber(x), tonumber(y), tonumber(z), powered == '1'}
        objects[#objects + 1] = object
        local bridge = name:match('^b([56])_')
        if bridge then
            local size = bridge == '5' and 1 or 2
            for v = 0, size - 1 do
                for u = 0, size - 1 do self.decks[(object[3] + v) * 24 + object[2] + u + 1] = object[4] end
            end
        end
        if name == 'lamp' and object[5] then
            local lx, ly = object[2] + .71, object[3] + .185
            local lamp = {lx, ly, object[4] + 23}
            for yy = max(0, floor(ly - 1)), min(23, floor(ly + 1)) do
                for xx = max(0, floor(lx - 1)), min(23, floor(lx + 1)) do
                    local k = yy * 24 + xx + 1
                    local near = self.cells[k]
                    if not near then near = {}; self.cells[k] = near end
                    near[#near + 1] = lamp
                end
            end
        end
    end
    if next(self.decks) then
        for i = 1, math.floor(n * n / 32) do self.deck_field[i] = 0 end
    end
    if not daylight then return end
    local t = ((bin + .5) / 48 - .18) / .61
    local angle = -math.pi * .92 + t * math.pi * 1.1
    local altitude = .33 + math.sin(t * math.pi) * 1.8
    local dx, dy = math.cos(angle) / (16 * altitude), math.sin(angle) / (16 * altitude)
    local function surface(px, py, pz)
        local x, y = min(23, max(0, floor(px))), min(23, max(0, floor(py)))
        local deck = self.decks[y * 24 + x + 1]
        if deck and math.abs(pz - deck) < .000001 then return 1152 + y * 24 + x end
        return (y * 24 + x) * 2 + (px - x >= py - y and 0 or 1)
    end
    local object_field, object_deck_field
    local function mark(px, py, receiver)
        local field = receiver >= 1152 and object_deck_field or object_field
        local cells = receiver >= 1152 and self.deck_shadow_cells or self.shadow_cells
        local xx, yy = floor(px * res + .5), floor(py * res + .5)
        if xx < 0 then xx = 0 elseif xx >= n then xx = n - 1 end
        if yy < 0 then yy = 0 elseif yy >= n then yy = n - 1 end
        local end_x, end_y = xx + 2, yy + 2
        if end_x >= n then end_x = n - 1 end
        if end_y >= n then end_y = n - 1 end
        local bit = xx % 32
        local coverage = (Bits.lshift(1, (end_x - xx + 1))) - 1
        local mask = Bits.band((Bits.lshift(coverage, bit)), 0xffffffff)
        local spill = bit > 29 and Bits.rshift(coverage, (32 - bit)) or 0
        local k = yy * stride + math.floor(xx / 32) + 1
        for row = 0, end_y - yy do
            field[k] = Bits.bor((field[k] or 0), mask)
            if spill ~= 0 then field[k + 1] = Bits.bor((field[k + 1] or 0), spill) end
            k = k + stride
        end
        local cell_x, cell_y = math.floor(xx / res), math.floor(yy / res)
        local cross_x, cross_y = math.floor(end_x / res) ~= cell_x, math.floor(end_y / res) ~= cell_y
        local cell = cell_y * 24 + cell_x + 1
        cells[cell] = true
        if cross_x then cells[cell + 1] = true end
        if cross_y then
            cells[cell + 24] = true
            if cross_x then cells[cell + 25] = true end
        end
    end
    local function cast(x, y, z)
        local px, py, pz = raycast(self.heights, self.decks, x + dx * .00001, y + dy * .00001, z - .00001, dx, dy)
        if not px then return end
        local receiver = surface(px, py, pz)
        mark(px, py, receiver)
        return px, py, receiver
    end
    local minimum_span = 1 / res
    local function connect(x, y, low, high, ax, ay, a, bx, by, b)
        if ax and bx and a == b then
            local steps = math.ceil(max(math.abs(bx - ax), math.abs(by - ay)) * res)
            if steps > 1 then
                local sx, sy = (bx - ax) / steps, (by - ay) / steps
                for i = 1, steps - 1 do mark(ax + sx * i, ay + sy * i, a) end
            end
        elseif (ax or bx) and high - low > minimum_span then
            local middle = (low + high) * .5
            local mx, my, receiver = cast(x, y, middle)
            connect(x, y, low, middle, ax, ay, a, mx, my, receiver)
            connect(x, y, middle, high, mx, my, receiver, bx, by, b)
        end
    end
    local terrain_only = next(self.decks) == nil
    for _, object in ipairs(objects) do
        local meta = self.resources.sprites[object[1]]
        if meta.cast then
            local cache_key, origin, cached = self.cache:lookup(meta.cast, object, res, bin, self.heights, self.decks, dx, dy)
            if not cached then
            object_field, object_deck_field = {}, {}
            local previous_column, previous_z, previous_x, previous_y, previous_surface
            for i = meta.cast[1], meta.cast[1] + meta.cast[2] - 1 do
                local point = Binary.u32(self.points, i * 4 + 1)
                local column, low, span = Bits.band(point, 0xfffff), Bits.band((Bits.rshift(point, 20)), 255), Bits.rshift(point, 28)
                local x, y = object[2] + ((Bits.band(point, 1023)) - 64) / 64, object[3] + ((Bits.band((Bits.rshift(point, 10)), 1023)) - 64) / 64
                local ax, ay, a, bx, by, b, sx, sy
                if terrain_only and span > 1 then
                    ax, ay, a = cast(x, y, object[4] + low)
                    bx, by, b = cast(x, y, object[4] + low + span)
                    if ax and bx and a == b then sx, sy = (bx - ax) / span, (by - ay) / span end
                end
                for offset = 0, span do
                    local z = object[4] + low + offset
                    local px, py, receiver
                    if offset == 0 and ax then px, py, receiver = ax, ay, a
                    elseif offset == span and bx then px, py, receiver = bx, by, b
                    elseif sx then
                        px, py, receiver = ax + sx * offset, ay + sy * offset, a
                        mark(px, py, receiver)
                    else px, py, receiver = cast(x, y, z) end
                    if column == previous_column and z == previous_z + 1 then
                        connect(x, y, previous_z, z, previous_x, previous_y, previous_surface, px, py, receiver)
                    end
                    previous_column, previous_z, previous_x, previous_y, previous_surface = column, z, px, py, receiver
                end
                    if i % 32 == 0 then Work.check() end
            end
            cached = self.cache:store(cache_key, origin, object_field, object_deck_field)
            end
            self.cache:apply(cached, origin, self.field, self.deck_field, self.shadow_cells, self.deck_shadow_cells, res)
        end
    end
end

function Shadows:projection(corners)
    local cached = self.projections[corners]
    if cached then return cached end
    local heights = {Bits.band(corners, 1) ~= 0 and 16 or 0, Bits.band(corners, 2) ~= 0 and 16 or 0, Bits.band(corners, 4) ~= 0 and 16 or 0, Bits.band(corners, 8) ~= 0 and 16 or 0}
    local uv, points, output = {{0,0},{1,0},{1,1},{0,1}}, {}, {}
    for i = 1, 4 do
        local u, v = uv[i][1], uv[i][2]
        points[i] = {32 + (u - v) * 32, 17 + (u + v) * 16 - heights[i], u, v}
    end
    for _, ids in ipairs({{1,2,3},{1,3,4}}) do
        local a, b, c = points[ids[1]], points[ids[2]], points[ids[3]]
        local det = (b[1] - a[1]) * (c[2] - a[2]) - (c[1] - a[1]) * (b[2] - a[2])
        if det ~= 0 then
            local inverse = 1 / det
            for y = 0, 64 do
                for x = 0, 64 do
                    local v = ((x - a[1]) * (c[2] - a[2]) - (y - a[2]) * (c[1] - a[1])) * inverse
                    local w = ((y - a[2]) * (b[1] - a[1]) - (x - a[1]) * (b[2] - a[2])) * inverse
                    if v >= -.001 and w >= -.001 and v + w <= 1.001 then
                        output[y * 65 + x + 1] = {
                            min(.99999, max(0, a[3] + v * (b[3] - a[3]) + w * (c[3] - a[3]))),
                            min(.99999, max(0, a[4] + v * (b[4] - a[4]) + w * (c[4] - a[4])))
                        }
                    end
                end
            end
        end
    end
    self.projections[corners] = output
    return output
end

function Shadows:paint(target, wx, wy, sx, sy, zoom, corners, mask, coarse, light, depth, receiver)
    local cell = wy * 24 + wx + 1
    local near = self.cells[cell]
    if light and not near then return end
    local shadow_cells = receiver and self.deck_shadow_cells or self.shadow_cells
    if not light and (not self.sun or (not shadow_cells[cell] and mask == '')) then return end
    local key = cell .. ':' .. corners .. ':' .. tostring(light) .. ':' .. mask .. ':' .. tostring(receiver)
    local tile = self.tiles[key]
    if tile == nil then
        tile = Surface.new(65, 65)
        local projection, hits = self:projection(corners), 0
        local field = receiver and self.deck_field or self.field
        for i = 1, 65 * 65 do
            local uv = projection[i]
            if uv then
                local u, v, alpha = uv[1], uv[2], 0
                local color
                if light then
                    local x, y = wx + u, wy + v
                    local z = receiver or self:ground(x, y)
                    for _, emitter in ipairs(near) do
                        local du, dv, dz = x - emitter[1], y - emitter[2], emitter[3] - z
                        if dz > 0 then
                            local radius = min(.9, max(.2, dz / 30))
                            local d = (du * du + dv * dv) / (radius * radius)
                            if d < 1 then
                                local px, py, pz = raycast(self.heights, self.decks, emitter[1], emitter[2], emitter[3], du / dz, dv / dz)
                                if px and math.abs(px - x) < .001 and math.abs(py - y) < .001 and math.abs(pz - z) < .001 then
                                    alpha = max(alpha, d < .12 and 72 or d < .4 and 46 or d < .7 and 26 or 12)
                                end
                            end
                        end
                    end
                    color = Bits.bor(0xffce7700, alpha)
                else
                    local k = (wy * self.res + floor(v * self.res)) * self.n + wx * self.res + floor(u * self.res)
                    local hit = Bits.band(field[math.floor(k / 32) + 1], (Bits.lshift(1, (k % 32)))) ~= 0
                    local terrain = mask:byte(floor(v * coarse) * coarse + floor(u * coarse) + 1) == 49
                    alpha = (hit or terrain) and 80 or 0
                    color = Bits.bor(0x19273e00, alpha)
                end
                if alpha > 0 then tile.pixels[i] = color; hits = hits + 1 end
            end
            if i % 65 == 0 then Work.check() end
        end
        if hits == 0 then tile = false end
        self.tiles[key] = tile
    end
    if tile then
        local x, y = floor(sx - 32 * zoom + .5), floor(sy - 17 * zoom + .5)
        if depth then target:blit_plane(tile, x, y, zoom, depth, wx + wy + receiver / 16 - 17 / 16)
        else target:blit(tile, x, y, zoom) end
    end
end

return Shadows

end
package.preload["lua.native.storage"]=function(...)
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

end
package.preload["lua.native.surface"]=function(...)
local Bits = require('lua.native.bits')
local Binary = require('lua.native.binary')
local Work = require('lua.native.work')
local floor, min, max = math.floor, math.min, math.max
local char = string.char
local Surface = {}
Surface.__index = Surface

local function over(src, dst)
    local a = Bits.band(src, 255)
    if a == 255 or dst == 0 then return src end
    if a == 0 then return dst end
    local b = (Bits.band(dst, 255)) * (255 - a) / 255
    local alpha = a + b
    local r = floor(((Bits.band((Bits.rshift(src, 24)), 255)) * a + (Bits.band((Bits.rshift(dst, 24)), 255)) * b) / alpha + .5)
    local g = floor(((Bits.band((Bits.rshift(src, 16)), 255)) * a + (Bits.band((Bits.rshift(dst, 16)), 255)) * b) / alpha + .5)
    local blue = floor(((Bits.band((Bits.rshift(src, 8)), 255)) * a + (Bits.band((Bits.rshift(dst, 8)), 255)) * b) / alpha + .5)
    return r * 16777216 + g * 65536 + blue * 256 + floor(alpha + .5)
end

function Surface.new(w, h)
    local pixels = {}
    for i = 1, w * h do
        pixels[i] = 0
        if i % 2048 == 0 then Work.check() end
    end
    return setmetatable({w = w, h = h, pixels = pixels}, Surface)
end

function Surface.solid(w, h, color)
    return setmetatable({w = w, h = h, fill = color}, Surface)
end

function Surface:clear()
    for i = 1, self.w * self.h do
        self.pixels[i] = 0
        if i % 2048 == 0 then Work.check() end
    end
end

function Surface:rect(x, y, w, h, color, erase)
    local x0, y0 = max(0, floor(x + .5)), max(0, floor(y + .5))
    local x1, y1 = min(self.w, floor(x + w + .5)), min(self.h, floor(y + h + .5))
    local pixels, width = self.pixels, self.w
    local alpha = Bits.band(color, 255)
    if alpha == 0 then return end
    if alpha == 255 then
        if erase then color = 0 end
        for yy = y0, y1 - 1 do
            local k = yy * width
            for xx = x0 + 1, x1 do pixels[k + xx] = color end
        end
    elseif erase then
        local factor = (255 - alpha) / 255
        for yy = y0, y1 - 1 do
            local k = yy * width
            for xx = x0 + 1, x1 do
                local dst = pixels[k + xx]
                local a = floor((Bits.band(dst, 255)) * factor + .5)
                pixels[k + xx] = a == 0 and 0 or Bits.bor((Bits.band(dst, 0xffffff00)), a)
            end
        end
    else
        for yy = y0, y1 - 1 do
            local k = yy * width
            for xx = x0 + 1, x1 do pixels[k + xx] = over(color, pixels[k + xx]) end
        end
    end
end

function Surface:blit(source, x, y, scale, alpha, erase)
    scale, alpha = scale or 1, alpha or 1
    if source.runs and scale == 1 then
        local runs, pixels, width, height = source.runs, self.pixels, self.w, self.h
        local last_y, rows, row
        for i = 1, #runs, 4 do
            local color = runs[i + 3]
            if alpha ~= 1 then color = Bits.bor((Bits.band(color, 0xffffff00)), floor((Bits.band(color, 255)) * alpha + .5)) end
            local opacity = Bits.band(color, 255)
            if opacity ~= 0 then
                local sy = runs[i + 1]
                if sy ~= last_y then
                    local ry = y + sy
                    local y0 = max(0, floor(ry + .5))
                    rows, row = min(height, floor(ry + 1 + .5)) - y0, y0 * width
                    last_y = sy
                end
                if rows > 0 then
                    local rx = x + runs[i]
                    local first = row + max(0, floor(rx + .5)) + 1
                    local last = row + min(width, floor(rx + runs[i + 2] + .5))
                    for _ = 1, rows do
                        if opacity == 255 then
                            if erase then color = 0 end
                            for k = first, last do pixels[k] = color end
                        elseif erase then
                            local factor = (255 - opacity) / 255
                            for k = first, last do
                                local dst = pixels[k]
                                local a = floor((Bits.band(dst, 255)) * factor + .5)
                                pixels[k] = a == 0 and 0 or Bits.bor((Bits.band(dst, 0xffffff00)), a)
                            end
                        else
                            for k = first, last do pixels[k] = over(color, pixels[k]) end
                        end
                        first, last = first + width, last + width
                    end
                end
            end
            if i % 256 == 1 then Work.check() end
        end
        return
    end
    if source.runs and scale % 1 == 0 then
        local runs = source.runs
        for i = 1, #runs, 4 do
            local color = runs[i + 3]
            if alpha ~= 1 then color = Bits.bor((Bits.band(color, 0xffffff00)), floor((Bits.band(color, 255)) * alpha + .5)) end
            self:rect(x + runs[i] * scale, y + runs[i + 1] * scale, runs[i + 2] * scale, scale, color, erase)
            if i % 256 == 1 then Work.check() end
        end
        return
    end
    local pixels = source.pixels
    if not pixels then
        local bitmap = Surface.new(source.w, source.h)
        bitmap:blit(source, 0, 0, 1)
        source.pixels = bitmap.pixels
        pixels = source.pixels
    end
    local x0, y0 = floor(x + .5), floor(y + .5)
    local w, h = floor(source.w * scale + .5), floor(source.h * scale + .5)
    local target, width = self.pixels, self.w
    local inverse = 1 / scale
    for yy = max(0, -y0), min(h, self.h - y0) - 1 do
        local sy = min(source.h - 1, floor((yy + .5) * inverse)) * source.w
        local row = (y0 + yy) * width + x0
        for xx = max(0, -x0), min(w, self.w - x0) - 1 do
            local color = pixels[sy + min(source.w - 1, floor((xx + .5) * inverse)) + 1]
            if color ~= 0 then
                if alpha ~= 1 then color = Bits.bor((Bits.band(color, 0xffffff00)), floor((Bits.band(color, 255)) * alpha + .5)) end
                if Bits.band(color, 255) ~= 0 then
                    local k = row + xx + 1
                    if erase then
                        local dst = target[k]
                        local a = floor((Bits.band(dst, 255)) * (255 - (Bits.band(color, 255))) / 255 + .5)
                        target[k] = a == 0 and 0 or Bits.bor((Bits.band(dst, 0xffffff00)), a)
                    else
                        target[k] = over(color, target[k])
                    end
                end
            end
        end
        Work.check()
    end
end

function Surface:blit_plane(source, x, y, scale, depth, base)
    local x0, y0 = floor(x + .5), floor(y + .5)
    local w, h = floor(source.w * scale + .5), floor(source.h * scale + .5)
    local inverse, target, pixels = 1 / scale, self.pixels, source.pixels
    for yy = max(0, -y0), min(h, self.h - y0) - 1 do
        local sy = min(source.h - 1, floor((yy + .5) * inverse))
        local row, value = (y0 + yy) * self.w + x0, base + sy / 16 + .08
        for xx = max(0, -x0), min(w, self.w - x0) - 1 do
            local index = row + xx + 1
            if depth.pixels[index] <= value then
                local color = pixels[sy * source.w + min(source.w - 1, floor((xx + .5) * inverse)) + 1]
                if color ~= 0 then target[index] = over(color, target[index]) end
            end
        end
        Work.check()
    end
end

function Surface:copy(source, sx, sy, w, h, dx, dy)
    for y = 0, h - 1 do
        local source_row = (sy + y) * source.w
        for x = 0, w - 1 do
            self:rect(dx + x, dy + y, 1, 1, source.pixels[source_row + sx + x + 1])
        end
        Work.check()
    end
end

function Surface:write(path, scale, red, green, blue, light, intensity)
    scale = scale or 1
    red, green, blue = red or 255, green or 255, blue or 255
    intensity = intensity or 0
    local file = assert(io.open(path, 'wb'))
    assert(file:write(Binary.tga_header(self.w * scale, self.h * scale)))
    local palette, shaded, row = {}, {}, {}
    if self.fill then
        local color, row, left = self.fill, {}, self.w * scale
        local pixel = char(Bits.band((Bits.rshift(color, 8)), 255), Bits.band((Bits.rshift(color, 16)), 255), Bits.band((Bits.rshift(color, 24)), 255), Bits.band(color, 255))
        while left > 0 do
            local n = min(128, left)
            row[#row + 1] = char(127 + n) .. pixel
            left = left - n
        end
        assert(file:write(table.concat(row):rep(self.h * scale)))
        assert(file:close())
        return
    end
    local function encode(color)
        local value = palette[color]
        if not value then
            value = char(Bits.band((Bits.rshift(color, 8)), 255), Bits.band((Bits.rshift(color, 16)), 255), Bits.band((Bits.rshift(color, 24)), 255), Bits.band(color, 255))
            palette[color] = value
        end
        return value
    end
    local function tint(color)
        if color == 0 then return 0 end
        local value = shaded[color]
        if not value then
            value = floor(Bits.band(Bits.rshift(color, 24), 255) * red / 255 + .5) * 16777216
                + floor(Bits.band(Bits.rshift(color, 16), 255) * green / 255 + .5) * 65536
                + floor(Bits.band(Bits.rshift(color, 8), 255) * blue / 255 + .5) * 256 + Bits.band(color, 255)
            shaded[color] = value
        end
        return value
    end
    for y = 0, self.h - 1 do
        local count, last, length = 0, -1, 0
        local function flush()
            while length > 0 do
                local n = min(128, length)
                count = count + 1
                row[count] = char(127 + n) .. encode(last)
                length = length - n
            end
        end
        for x = 1, self.w do
            local k = y * self.w + x
            local color = tint(self.pixels[k])
            if light and intensity > 0 then
                local emitted = light.pixels[k]
                if emitted ~= 0 then
                    emitted = Bits.bor((Bits.band(emitted, 0xffffff00)), floor((Bits.band(emitted, 255)) * intensity + .5))
                    color = over(emitted, color)
                end
            end
            if color ~= last then flush(); last = color end
            length = length + scale
        end
        flush()
        local bytes = table.concat(row, '', 1, count)
        for _ = 1, scale do assert(file:write(bytes)) end
        Work.check()
    end
    assert(file:close())
end

Surface.over = over
return Surface

end
package.preload["lua.native.ui"]=function(...)
local Bits = require('lua.native.bits')
local Surface = require('lua.native.surface')
local floor, min, max = math.floor, math.min, math.max
local UI = {}
UI.__index = UI
local character = '[%z\1-\127\194-\244][\128-\191]*'

function UI.new(resources)
    return setmetatable({resources = resources, offset = 0, specs = {body = {}, display = {}}, widths = {}}, UI)
end

function UI:font(size, face)
    face = face == 'display' and 'display' or 'body'
    local spec = self.specs[face][size]
    if not spec then
        local n = face == 'display' and max(8, floor(size / 16 + .5) * 8) or max(11, floor(size / 2 + .5))
        local key = face .. n
        spec = {key = key, glyphs = assert(self.resources.fonts[key]), widths = {}, count = 0}
        self.specs[face][size] = spec
    end
    return spec
end

function UI:width(value, size, face)
    local str = tostring(value)
    local font = self:font(size, face)
    local w = font.widths[str]
    if w then return w end
    w = 0
    for ch in str:gmatch(character) do
        local glyph = font.glyphs[ch] or font.glyphs['?']
        w = w + glyph.advance * 2
    end
    if font.count == 512 then font.widths = {}; font.count = 0 end
    font.widths[str], font.count = w, font.count + 1
    return w
end

function UI:text(x, y, value, size, color, max_width, face)
    local str = tostring(value)
    if str == '' then return 0 end
    local font = self:font(size, face)
    local key = 'text:' .. font.key .. ':' .. color .. ':' .. max_width .. ':' .. str
    local entry = self.resources:find(key)
    if not entry then
        local chars = {}
        for ch in str:gmatch(character) do chars[#chars + 1] = ch end
        if max_width > 0 and self:width(str, size, face) > max_width then
            local w = self:width(str, size, face)
            local ellipsis = self:width('…', size, face)
            while #chars > 0 and w + ellipsis > max_width do
                local glyph = font.glyphs[chars[#chars]] or font.glyphs['?']
                w = w - glyph.advance * 2
                chars[#chars] = nil
            end
            chars[#chars + 1] = '…'
            str = table.concat(chars)
        end
        local w, top, bottom = self:width(str, size, face) / 2, 100, 0
        for _, ch in ipairs(chars) do
            local glyph = font.glyphs[ch] or font.glyphs['?']
            if glyph.w > 0 then top = min(top, glyph.oy); bottom = max(bottom, glyph.oy + glyph.h) end
        end
        if bottom == 0 then return w * 2 end
        local image, cursor = Surface.new(max(1, w + 4), bottom - top), 1
        for _, ch in ipairs(chars) do
            local glyph = self.resources:source(font.glyphs[ch] or font.glyphs['?'])
            local runs = glyph.runs
            for i = 1, #runs, 4 do image:rect(cursor + glyph.ox + runs[i], glyph.oy - top + runs[i + 1], runs[i + 2], 1, Bits.bor(color, 255)) end
            cursor = cursor + glyph.advance
        end
        entry = self.resources:add(key, image, 2)
        entry.text_width, entry.top = w * 2, top * 2
    end
    self.resources:draw(entry, floor(x / 2 + .5) * 2, floor(y / 2 + .5) * 2 + entry.top + self.offset)
    return entry.text_width
end

function UI:rect(x, y, w, h, color)
    if Bits.band(color, 255) == 0 then return end
    local key = 'rect:' .. w .. ':' .. h .. ':' .. color
    local entry = self.resources:find(key)
    if not entry then entry = self.resources:add(key, Surface.solid(w, h, color)) end
    self.resources:draw(entry, x, y + self.offset)
end

function UI:skin(kind, x, y, w, h, focus)
    local key = 'skin:' .. kind .. ':' .. w .. ':' .. h
    local entry = self.resources:find(key)
    if not entry then
        local sw, sh, b = math.ceil(w / 2), math.ceil(h / 2), 6
        local image = Surface.new(sw, sh)
        local source = self.resources:bitmap(assert(self.resources.sprites['ui_' .. kind].skin))
        for yy = b, sh - b - 1, 20 do
            for xx = b, sw - b - 1, 20 do image:copy(source, 6, 6, min(20, sw - b - xx), min(20, sh - b - yy), xx, yy) end
        end
        for xx = b, sw - b - 1, 20 do
            local tw = min(20, sw - b - xx)
            image:copy(source, 6, 0, tw, b, xx, 0)
            image:copy(source, 6, 26, tw, b, xx, sh - b)
        end
        for yy = b, sh - b - 1, 20 do
            local th = min(20, sh - b - yy)
            image:copy(source, 0, 6, b, th, 0, yy)
            image:copy(source, 26, 6, b, th, sw - b, yy)
        end
        image:copy(source, 0, 0, b, b, 0, 0)
        image:copy(source, 26, 0, b, b, sw - b, 0)
        image:copy(source, 0, 26, b, b, 0, sh - b)
        image:copy(source, 26, 26, b, b, sw - b, sh - b)
        entry = self.resources:add(key, image, 2)
    end
    self.resources:draw(entry, x, y + self.offset)
    if focus then
        self.resources.std.draw.color(0xd6b574ff)
        self.resources.std.draw.rect(0, x + 4, y + 16 + self.offset, 4, h - 32)
    end
end

function UI:sprite(key, x, y, scale, alpha)
    local meta = assert(self.resources.sprites[key], key)
    local w, h = floor(meta.w * scale + .5), floor(meta.h * scale + .5)
    local cache_key = 'sprite:' .. key .. ':' .. w .. ':' .. h .. ':' .. alpha
    local entry = self.resources:find(cache_key)
    if not entry then
        local image = Surface.new(w, h)
        image:blit(self.resources:source(meta), 0, 0, scale, alpha)
        entry = self.resources:add(cache_key, image)
    end
    self.resources:draw(entry, floor(x - meta.ox * scale + .5), floor(y - meta.oy * scale + .5) + self.offset)
end

function UI:thumb(key, x, y, w, h)
    local meta = assert(self.resources.sprites[key], key)
    local scale = min(3, w / meta.w, h / meta.h)
    if scale >= 1 then scale = floor(scale) end
    self:sprite(key, x + (meta.ox - meta.w / 2) * scale, y + (meta.oy - meta.h / 2) * scale, scale, 1)
end

return UI

end
package.preload["lua.native.work"]=function(...)
local Work = {}
local deadline

function Work.check()
    if deadline and os.clock() >= deadline then coroutine.yield() end
end

function Work.resume(thread, seconds)
    deadline = os.clock() + seconds
    local ok, failure = coroutine.resume(thread)
    deadline = nil
    if not ok then error(debug.traceback(thread, failure), 0) end
    return coroutine.status(thread) == 'dead'
end

return Work

end
package.preload["lua.native.world"]=function(...)
local Assets = require('lua.native.assets')
local Bits = require('lua.native.bits')
local Surface = require('lua.native.surface')
local Ocean = require('lua.native.ocean')
local Shadows = require('lua.native.shadows')
local Depth = require('lua.native.depth')
local Actors = require('lua.native.actors')
local floor, min, max = math.floor, math.min, math.max
local World = {}
World.__index = World
local stops = {{0,86,109,161},{.14,91,112,164},{.21,191,159,170},{.28,255,244,218},{.5,255,255,244},{.64,255,241,207},{.72,255,210,161},{.79,153,132,174},{.87,88,111,163},{1,86,109,161}}

local function tone(phase)
    for i = 2, #stops do
        local a, b = stops[i - 1], stops[i]
        if phase <= b[1] then
            local t = (phase - a[1]) / (b[1] - a[1])
            return floor(a[2] + (b[2] - a[2]) * t + .5), floor(a[3] + (b[3] - a[3]) * t + .5), floor(a[4] + (b[4] - a[4]) * t + .5)
        end
    end
end

local function tinted(color, r, g, b)
    return floor(Bits.band(Bits.rshift(color, 24), 255) * r / 255 + .5) * 16777216
        + floor(Bits.band(Bits.rshift(color, 16), 255) * g / 255 + .5) * 65536
        + floor(Bits.band(Bits.rshift(color, 8), 255) * b / 255 + .5) * 256
end

function World.new(resources, ui)
    local ocean = Ocean.new()
    local file = assert(io.open(Assets.path('depths.bin'), 'rb'))
    local depths = assert(file:read('*a'))
    assert(file:close())
    return setmetatable({resources = resources, ui = ui, ocean = ocean, shadows = Shadows.new(resources, ocean.heights), actors = Actors.new(resources, depths), depths = depths, generation = 0, clock = 0, bursts = {}}, World)
end

function World:begin(csv, cx, cy, zoom, ox, oy)
    self.csv, self.zoom = csv, zoom
    self.ocean:prepare(csv, cx, cy, zoom, ox, oy)
    local factor = zoom >= 2 and 2 or 1
    if self.factor ~= factor then
        self.factor = factor
        self.land, self.lights = Surface.new(math.floor(1280 / factor), math.floor(720 / factor)), Surface.new(math.floor(1280 / factor), math.floor(720 / factor))
    else
        self.land:clear()
        self.lights:clear()
    end
    self.cx, self.cy, self.ox, self.oy = cx, cy, ox, oy
    if self.depth == (self.current and self.current.depth) or not self.depth or self.depth.w ~= math.floor(1280 / factor) then
        self.depth = self.spare_depth
        if not self.depth or self.depth.w ~= math.floor(1280 / factor) then self.depth = Depth.new(math.floor(1280 / factor), math.floor(720 / factor))
        else self.depth:clear() end
        self.spare_depth = nil
    else self.depth:clear() end
end

function World:scene(scene, phase, detail)
    self.phase = phase
    self.shadows:prepare(self.csv, scene, phase, detail)
end

function World:sprite(key, x, y, scale, alpha, lit)
    local meta = self.resources:source(assert(self.resources.sprites[key], key))
    local factor = self.factor
    local xx, yy = floor(x - meta.ox * scale + .5) / factor, floor(y - meta.oy * scale + .5) / factor
    local s = scale / factor
    self.land:blit(meta, xx, yy, s, alpha)
    self.lights:blit(meta, xx, yy, s, alpha, true)
    if meta.light and lit ~= false then
        if key == 'lamp' then
            local px = (x + (.71 - .185) * 32 * scale) / factor
            local py = (y + ((.71 + .185) * 16 - 23) * scale) / factor
            self.lights:rect(px - 4 * s, py - 3 * s, 8 * s, 6 * s, 0xffca6f24)
            self.lights:rect(px - 3 * s, py - 2 * s, 6 * s, 4 * s, 0xffe39b38)
        end
        for i = 1, #meta.light, 4 do
            self.lights:rect(xx + meta.light[i] * s, yy + meta.light[i + 1] * s, meta.light[i + 2] * s, s, meta.light[i + 3] ~= 0 and 0xffedb1ff or 0xffd384ff)
        end
    end
end

function World:stamp(key, x, y, scale, wx, wy, z)
    local meta = assert(self.resources.sprites[key], key)
    self.depth:stamp(meta, (x - meta.ox * scale) / self.factor, (y - meta.oy * scale) / self.factor, scale / self.factor, wx + wy + z / 16, self.depths)
end

function World:actor(key, wx, wy, z, appearance, accessory_key)
    if self.current then self.actors:draw(self.current, key, wx, wy, z, appearance, accessory_key) end
end

function World:shadow(mask, sx, sy, zoom, corners, res, wx, wy)
    self.shadows:paint(self.land, wx, wy, sx / self.factor, sy / self.factor, zoom / self.factor, corners, mask, res, false)
end

function World:ground_light(wx, wy, sx, sy, zoom, corners)
    self.shadows:paint(self.lights, wx, wy, sx / self.factor, sy / self.factor, zoom / self.factor, corners, '', 8, true)
end

function World:bridge(wx, wy, sx, sy, zoom, z)
    local factor = self.factor
    self.shadows:paint(self.land, wx, wy, sx / factor, sy / factor, zoom / factor, 0, '', 8, false, self.depth, z)
    self.shadows:paint(self.lights, wx, wy, sx / factor, sy / factor, zoom / factor, 0, '', 8, true, self.depth, z)
end

function World:publish(phase)
    self.generation = self.generation + 1
    local r, g, b = tone(phase)
    local night = max(0, min(1, phase > .73 and (phase - .73) / .13 or phase < .25 and (.25 - phase) / .1 or 0))
    if self.pending then
        self.pending.sea.pinned, self.pending.land.pinned = false, false
    end
    self.pending = {
        generation = self.generation, depth = self.depth, factor = self.factor,
        cx = self.cx, cy = self.cy, ox = self.ox, oy = self.oy, zoom = self.zoom,
        tone_red = r, tone_green = g, tone_blue = b,
        sea = self.resources:add('sea:' .. self.generation, self.ocean.sea, 2, r, g, b, nil, nil, true),
        land = self.resources:add('land:' .. self.generation, self.land, self.factor, r, g, b, self.lights, night * .94, true),
        waves = self.ocean.waves,
        gold = tinted(0xe2bd8bff, r, g, b), shore = tinted(0x95cfbfff, r, g, b), blue = tinted(0x4d95abff, r, g, b)
    }
    self.tone_bin = floor(phase * 96)
end

function World:finish()
    self:publish(self.phase)
end

function World:draw(phase, time, motion)
    self.clock = time
    local pending = self.pending
    if pending and pending.sea.ready and pending.land.ready then
        if self.current then
            if self.current.depth ~= pending.depth then self.spare_depth = self.current.depth end
            self.resources:remove(self.current.sea)
            self.resources:remove(self.current.land)
        end
        self.current, self.pending = pending, nil
    end
    local current = self.current
    local std = self.resources.std
    if not current then
        std.draw.color(0x182536ff)
        std.draw.rect(0, 0, 0, 1280, 720)
        return
    end
    self.resources:draw(current.sea, 0, 0)
    if motion then
        for i = 1, #current.waves do
            local wave = current.waves[i]
            local t = (floor(time / 220) + wave[4]) % 12
            local color = phase > .65 and phase < .79 and i % 3 == 1 and current.gold or wave[5] < 1.5 and current.shore or current.blue
            std.draw.color(Bits.bor(color, floor((t < 6 and t or 12 - t) * 25.5 + .5)))
            local x, y = floor((wave[1] + t * 2) / 2 + .5) * 2, floor(wave[2] / 2 + .5) * 2
            std.draw.rect(0, x, y, wave[3], 2)
            if t > 3 and t < 8 then std.draw.rect(0, x + 4, y + 4, max(2, wave[3] - 8), 2) end
        end
    end
    self.resources:draw(current.land, 0, 0)
end

function World:burst(x, y, good)
    if #self.bursts == 4 then table.remove(self.bursts, 1) end
    self.bursts[#self.bursts + 1] = {x, y, self.clock, good}
end

local directions = {}
for j = 0, 7 do directions[j + 1] = {math.cos(j * math.pi / 4), math.sin(j * math.pi / 4)} end

function World:effects(time, motion)
    if not motion then
        for i = #self.bursts, 1, -1 do self.bursts[i] = nil end
        return
    end
    for i = #self.bursts, 1, -1 do
        local burst = self.bursts[i]
        local t = (time - burst[3]) / 720
        if t >= 1 then
            table.remove(self.bursts, i)
        else
            local alpha = min(255, floor((1 - t) * 16 + .5) * 16)
            for j = 0, 7 do
                local direction = directions[j + 1]
                local x = floor((burst[1] + direction[1] * t * 46) / 2 + .5) * 2
                local y = floor((burst[2] - 18 - direction[2] * t * 24 - t * 25) / 2 + .5) * 2
                local color = burst[4] and (j % 2 == 1 and 0xfff0bd00 or 0xa8d09800) or 0xe98c7800
                self.ui:rect(x, y, j % 3 == 0 and 6 or 4, 4, Bits.bor(color, alpha))
            end
        end
    end
end

function World:minimap(x, y, size, offset)
    local unit = max(2, floor(size / 48))
    local ox, heights, std = x + size / 2, self.ocean.heights, self.resources.std
    for j = 0, 23 do
        for i = 0, 23 do
            local k = j * 25 + i + 1
            local h = max(heights[k], heights[k + 1], heights[k + 25], heights[k + 26])
            if h > 0 then
                std.draw.color(h == 1 and 0xe5c992ff or h == 2 and 0x96b67aff or h == 3 and 0x6f945fff or 0xc6bb95ff)
                std.draw.rect(0, ox + (i - j) * unit, y + (i + j) * unit / 2 - h * 2 + offset, unit * 2, unit)
            end
        end
    end
end

return World

end
local Assets=require('lua.native.assets')
Assets.configure("https://guilhhotina.github.io/mare/native/9006d4482b404676/",{{"depths.bin",4511092},{"fonts.lua",206779},{"pixels.bin",8702050},{"shadow-shapes.bin",1603248},{"sound-0.wav",2470},{"sound-1.wav",5776},{"sound-2.wav",5776},{"sprites.lua",2930378}})
Platform=require('lua.native.platform')

end
local app=(function()
local Catalog=(function()
return {{"Trilha de terra","Vias",1,1,8,0,0,0,"terra","Trilha de","terra"},{"Passeio","Vias",1,1,16,0,0,0,"pedestres","Passeio",""},{"Rua","Vias",1,1,25,0,0,0,"rua","Rua",""},{"Avenida","Vias",2,2,70,1,0,0,"avenida","Avenida",""},{"Ponte de madeira","Vias",1,1,60,0,0,0,"bridge","Ponte de","madeira"},{"Ponte rodoviaria","Vias",2,2,150,1,0,0,"bridge","Ponte","rodoviaria"},{"Escadaria","Vias",1,1,30,0,0,0,"steps","Escadaria",""},{"Ponto de onibus","Vias",1,1,110,1,0,0,"bus","Ponto de","onibus"},{"Terminal de balsas","Vias",3,2,650,6,0,0,"ferry","Terminal de","balsas"},{"Porto de cargas","Vias",4,3,1200,10,0,0,"port","Porto de","cargas"},{"Casinha","Moradia",1,1,90,0,4,0,"house","Casinha",""},{"Casa com jardim","Moradia",2,1,160,1,8,0,"garden","Casa com","jardim"},{"Vila de sobrados","Moradia",3,1,330,2,18,0,"row","Vila de","sobrados"},{"Predinho","Moradia",1,1,240,1,14,0,"apart","Predinho",""},{"Edificio","Moradia",2,1,480,3,32,0,"apart","Edificio",""},{"Torre residencial","Moradia",2,2,1000,6,72,0,"tower","Torre","residencial"},{"Mercadinho","Comercio",1,1,160,2,0,12,"shop","Mercadinho",""},{"Padaria e cafe","Comercio",1,1,180,2,0,14,"cafe","Padaria e","cafe"},{"Pet shop","Comercio",1,1,170,2,0,12,"pet","Pet shop",""},{"Restaurante","Comercio",2,1,300,3,0,25,"rest","Restaurante",""},{"Feira ao ar livre","Comercio",4,1,360,2,0,28,"market","Feira ao ar","livre"},{"Hotel da ilha","Comercio",2,3,900,7,0,65,"hotel","Hotel da ilha",""},{"Jardim comercial","Comercio",3,2,650,5,0,48,"mall","Jardim","comercial"},{"Oficina","Comercio",3,2,600,5,0,60,"factory","Oficina",""},{"Gerador","Servicos",2,1,220,7,0,0,"diesel","Gerador",""},{"Turbina eolica","Servicos",2,2,700,3,0,0,"wind","Turbina","eolica"},{"Usina solar","Servicos",3,2,950,2,0,0,"solar","Usina solar",""},{"Agua e saneamento","Servicos",3,2,650,5,0,0,"water","Agua e","saneamento"},{"Reciclagem","Servicos",3,2,580,5,0,0,"waste","Reciclagem",""},{"Clinica","Servicos",2,1,420,4,0,0,"clinic","Clinica",""},{"Escola","Servicos",3,2,500,4,0,0,"school","Escola",""},{"Bombeiros","Servicos",2,2,430,4,0,0,"fire","Bombeiros",""},{"Posto policial","Servicos",2,2,400,3,0,0,"police","Posto policial",""},{"Administracao","Servicos",2,2,500,3,0,0,"admin","","Administracao"},{"Praca e playground","Natureza",2,2,100,1,0,0,"park","Praca e","playground"},{"Mirante","Natureza",2,1,140,1,0,4,"lookout","Mirante",""},{"Quiosque de praia","Natureza",1,1,120,1,0,8,"kiosk","Quiosque de","praia"},{"Cerca e portao","Natureza",1,1,15,0,0,0,"fence","Cerca e","portao"},{"Abrigo de animais","Natureza",2,2,320,3,0,16,"shelter","Abrigo de","animais"},{"Centro veterinario","Natureza",3,2,650,5,0,32,"vet","Centro","veterinario"}}
end)()
local LocaleData=(function()
return {["pt"]={["messages"]={["Mare"]="Mar\195\169",["Um pedacinho de mundo, do seu jeito."]="Um pedacinho de mundo, do seu jeito.",["Vias"]="Vias",["Moradia"]="Moradia",["Comercio"]="Com\195\169rcio",["Servicos"]="Servi\195\167os",["Natureza"]="Natureza",["Construir"]="Construir",["Terreno"]="Terreno",["Remover"]="Remover",["Desfazer"]="Desfazer",["Zonas"]="Zonas",["Elevar"]="Elevar",["Baixar"]="Baixar",["Nivelar"]="Nivelar",["Distorcer"]="Distorcer",["Pinte um nivel acima. As construcoes sobem junto."]="Pinte um n\195\173vel acima. As constru\195\167\195\181es sobem junto.",["Pinte um nivel abaixo. As vias se acomodam."]="Pinte um n\195\173vel abaixo. As vias se acomodam.",["Copie uma altura e pinte o terreno com as setas."]="Copie uma altura e pinte o terreno com as setas.",["Segure a costa e puxe. As fundacoes acompanham."]="Segure a costa e puxe. As funda\195\167\195\181es acompanham.",["Escolha uma peca e coloque direto na ilha."]="Escolha uma pe\195\167a e coloque direto na ilha.",["Molde morros, praias e enseadas."]="Molde morros, praias e enseadas.",["Libere espaco e receba 75% do custo de volta."]="Libere espa\195\167o e receba 75% do custo de volta.",["Desfaca uma construcao, remocao ou gesto inteiro."]="Desfa\195\167a uma constru\195\167\195\163o, remo\195\167\195\163o ou gesto inteiro.",["Autorize bairros; moradores chegam e constroem."]="Autorize bairros; moradores chegam e constroem.",["Apagar zona"]="Apagar zona",["Casas: acesso, energia e lojas sustentam novos moradores."]="Casas: acesso, energia e lojas sustentam novos moradores.",["Lojas: atendem moradores e permitem mais casas."]="Lojas: atendem moradores e permitem mais casas.",["Clinicas: lotes 2x1 para moradores sem cobertura."]="Cl\195\173nicas: lotes 2\195\1511 para moradores sem cobertura.",["Retira autorizacao e cancela obras; nao demole edificios."]="Retira a zona e cancela obras; n\195\163o demole edif\195\173cios.",["pequeno"]="pequeno",["medio"]="m\195\169dio",["grande"]="grande",["Explore a ilha"]="Explore a ilha",["Elevar terreno"]="Elevar terreno",["Baixar terreno"]="Baixar terreno",["Nivelar terreno"]="Nivelar terreno",["Distorcer a costa"]="Distorcer a costa",["Remover construcao"]="Remover constru\195\167\195\163o",["Zonear bairro"]="Zonear bairro",["Continuar"]="Continuar",["Nova ilha"]="Nova ilha",["Como jogar"]="Como jogar",["Ajustes"]="Ajustes",["Continuar jogando"]="Continuar jogando",["Salvar a ilha"]="Salvar a ilha",["Diario da ilha"]="Di\195\161rio da ilha",["Contemplar a ilha"]="Contemplar a ilha",["Salvar e ir ao inicio"]="Salvar e ir ao in\195\173cio",["Trocar via"]="Trocar via",["Concluir"]="Concluir",["Girar peca"]="Girar pe\195\167a",["Trocar peca"]="Trocar pe\195\167a",["Trocar uso"]="Trocar uso",["Pincel"]="Pincel",["Trocar ferramenta"]="Trocar ferramenta",["Sons curtos ao navegar e construir."]="Sons curtos ao navegar e construir.",["Reduz ondas, passaros e animacoes."]="Reduz ondas, p\195\161ssaros e anima\195\167\195\181es.",["Ajusta vegetacao e custo das sombras."]="Ajusta vegeta\195\167\195\163o e custo das sombras.",["Pixels inteiros nas duas distancias."]="Pixels inteiros nas duas dist\195\162ncias.",["Escolha um momento do dia."]="Escolha um momento do dia.",["Escolha Portugues, English ou Deutsch. A troca e imediata."]="Portugu\195\170s, English ou Deutsch. A troca \195\169 imediata.",["Salva as preferencias neste dispositivo."]="Salva as prefer\195\170ncias neste dispositivo.",["Portugu\195\170s"]="Portugu\195\170s",["English"]="English",["Deutsch"]="Deutsch",["Ilha salva. Pode voltar quando quiser."]="Ilha salva. Pode voltar quando quiser.",["Nao foi possivel salvar neste dispositivo."]="N\195\163o foi poss\195\173vel salvar neste dispositivo.",["MARE"]="MAR\195\137",["Seu mundo, no seu ritmo."]="Seu mundo, no seu ritmo.",["SETAS escolher   OK entrar"]="SETAS escolher   OK entrar",["MAR ABERTO"]="MAR ABERTO",["DIA %d"]="DIA %d",["Modo livre"]="Modo livre",["Jornada"]="Jornada",["Livre"]="Livre",["moedas"]="moedas",["moradores"]="moradores",["%d / %d"]="%d / %d",["energia"]="energia",["%d%%"]="%d%%",["felicidade"]="felicidade",["Nivelar: altura do mar"]="Nivelar: altura do mar",["Nivelar: altura %d"]="Nivelar: altura %d",["SETAS explorar    OK criar    VOLTAR pausa"]="SETAS explorar    OK criar    VOLTAR pausa",["OK construir  /  Custo: %d  /  VOLTAR opcoes"]="OK construir  /  Custo: %d  /  VOLTAR op\195\167\195\181es",["%s  /  VOLTAR opcoes"]="%s  /  VOLTAR op\195\167\195\181es",["SETAS tracar    OK terminar    VOLTAR cancelar"]="SETAS tra\195\167ar    OK terminar    VOLTAR cancelar",["OK comecar via    VOLTAR opcoes"]="OK come\195\167ar via    VOLTAR op\195\167\195\181es",["SETAS pintar    OK confirmar zona    VOLTAR cancelar"]="SETAS pintar    OK confirmar zona    VOLTAR cancelar",["OK comecar zona    VOLTAR escolher uso"]="OK come\195\167ar zona    VOLTAR escolher uso",["Sem acesso: construcao inativa    OK criar    VOLTAR pausa"]="Sem acesso: constru\195\167\195\163o inativa    OK criar    VOLTAR pausa",["Com acesso    OK criar    VOLTAR pausa"]="Com acesso    OK criar    VOLTAR pausa",["%s  /  %d%%"]="%s  /  %d%%",["Autorize o lote inteiro: clinicas precisam de 2x1"]="Autorize o lote inteiro: cl\195\173nicas precisam de 2\195\1511",["Aguardando uma das quatro equipes de obra"]="Aguardando uma das quatro equipes de obra",["Zona autorizada: aguardando ocupacao"]="Zona autorizada: aguardando ocupa\195\167\195\163o",["SETAS puxar    OK soltar    VOLTAR cancelar"]="SETAS puxar    OK soltar    VOLTAR cancelar",["SETAS pintar    OK concluir    VOLTAR cancelar"]="SETAS pintar    OK concluir    VOLTAR cancelar",["OK remover e recuperar 75%    VOLTAR explorar"]="OK remover e recuperar 75%    VOLTAR explorar",["OK segurar    Pincel %s    VOLTAR opcoes"]="OK segurar    Pincel: %s    VOLTAR op\195\167\195\181es",["OK copiar altura    Pincel %s    VOLTAR opcoes"]="OK copiar altura    Pincel: %s    VOLTAR op\195\167\195\181es",["OK comecar    Pincel %s    VOLTAR opcoes"]="OK come\195\167ar    Pincel: %s    VOLTAR op\195\167\195\181es",["%+d / dia"]="%+d / dia",["Sem acesso: ligue uma via ao lado para ativar."]="Sem acesso: ligue uma via ao lado para ativar.",["Conquista pronta!"]="Conquista pronta!",["VOLTAR > Diario para receber"]="VOLTAR > Di\195\161rio para receber",["%d%%  /  Diario na pausa"]="%d%%  /  Di\195\161rio na pausa",["Desfazer disponivel: %d acoes. O gesto inteiro volta."]="A\195\167\195\181es para desfazer: %d. O gesto inteiro volta.",["Nada para desfazer ainda."]="Nada para desfazer ainda.",["O que vamos criar?"]="O que vamos criar?",["SETAS escolher    OK usar    VOLTAR explorar"]="SETAS escolher    OK usar    VOLTAR explorar",["Moldar a ilha"]="Moldar a ilha",["SETAS escolher    OK usar    VOLTAR ferramentas"]="SETAS escolher    OK usar    VOLTAR ferramentas",["Crescer em bairros"]="Crescer em bairros",["Cada tracado pode ser desfeito de uma vez."]="Cada tra\195\167ado pode ser desfeito de uma vez.",["OK gira 90 graus e volta para a ilha."]="OK gira 90 graus e volta para a ilha.",["Escolha outra peca. A ilha fica como esta."]="Escolha outra pe\195\167a. A ilha fica como est\195\161.",["Volte a explorar a ilha."]="Volte a explorar a ilha.",["Pincel: %s"]="Pincel: %s",["OK muda o tamanho. A terra leva as construcoes junto."]="OK muda o tamanho. A terra leva as constru\195\167\195\181es junto.",["Troque entre elevar, baixar, nivelar e distorcer."]="Troque entre elevar, baixar, nivelar e distorcer.",["Escolha o que vai fazer parte da sua ilha."]="Escolha o que vai fazer parte da sua ilha.",["%d  /  %dx%d"]="%d  /  %d\195\151%d",["SELECIONADO"]="SELECIONADO",["%d x %d terrenos"]="\195\129rea: %d \195\151 %d",["Custo: %d moedas"]="Custo em moedas: %d",["%d moedas / dia"]="Moedas por dia: %d",["ESQUERDA / DIREITA categorias    OK ver construcoes    VOLTAR"]="ESQ. / DIR. categorias    OK ver constru\195\167\195\181es    VOLTAR",["SETAS escolher    CIMA categorias    OK colocar    VOLTAR"]="SETAS escolher    CIMA categorias    OK colocar    VOLTAR",["Um respiro"]="Um respiro",["Sua ilha fica guardada enquanto voce faz uma pausa."]="Sua ilha fica guardada enquanto voc\195\170 faz uma pausa.",["ILHA %d"]="ILHA %d",["Dia %d  /  Moradores: %d"]="Dia %d  /  Moradores: %d",["SETAS escolher    OK confirmar    VOLTAR continuar"]="SETAS escolher    OK confirmar    VOLTAR continuar",["Deixe a ilha confortavel para voce."]="Deixe a ilha confort\195\161vel para voc\195\170.",["Som: ligado"]="Som: ligado",["Som: desligado"]="Som: desligado",["Movimento: ligado"]="Movimento: ligado",["Movimento: reduzido"]="Movimento: reduzido",["Detalhes: completos"]="Detalhes: completos",["Detalhes: economicos"]="Detalhes: econ\195\180micos",["Zoom: %dx"]="Zoom: %d\195\151",["Luz: %s"]="Luz: %s",["Idioma: %s"]="Idioma: %s",["Ciclo natural"]="Ciclo natural",["Manha"]="Manh\195\163",["Golden hour"]="P\195\180r do sol",["Noite"]="Noite",["Manha, por do sol e luzes da noite."]="Manh\195\163, p\195\180r do sol e luzes da noite.",["SETAS escolher    OK alterar    VOLTAR concluir"]="SETAS escolher    OK alterar    VOLTAR concluir",["Sua ilha, seu ritmo"]="Sua ilha, seu ritmo",["Setas movem o cursor pelas diagonais da ilha."]="Setas movem o cursor pelas diagonais da ilha.",["OK abre as ferramentas durante a exploracao."]="OK abre as ferramentas durante a explora\195\167\195\163o.",["Voltar cancela gestos ou abre opcoes da peca."]="Voltar cancela gestos ou abre op\195\167\195\181es da pe\195\167a.",["Ao explorar, Voltar abre a pausa e o diario."]="Ao explorar, Voltar abre a pausa e o di\195\161rio.",["Moldar a terra"]="Moldar a terra",["Elevar e Baixar: OK, setas para pintar, OK."]="Elevar e Baixar: OK, setas para pintar, OK.",["Nivelar: OK copia a altura; setas pintam nela."]="Nivelar: OK copia a altura; setas pintam nela.",["Distorcer: OK segura; setas puxam; OK solta."]="Distorcer: OK segura; setas puxam; OK solta.",["Casas sobem e descem; vias ganham rampas."]="Casas sobem e descem; vias ganham rampas.",["Fazer a ilha crescer"]="Fazer a ilha crescer",["Casas, lojas e servicos precisam de via ao lado."]="Casas, lojas e servi\195\167os precisam de via ao lado.",["Geradores e usinas tambem precisam de acesso."]="Geradores e usinas tamb\195\169m precisam de acesso.",["Sem via, a construcao fica inativa."]="Sem via, a constru\195\167\195\163o fica inativa.",["Com acesso, energia e servicos atendem a ilha."]="Com acesso, energia e servi\195\167os atendem a ilha.",["Experimentar"]="Experimentar",["Um dia passa a cada 12 segundos de partida."]="Um dia passa a cada 12 segundos de partida.",["Troque o piso de vias pagando a diferenca."]="Troque o piso de vias pagando a diferen\195\167a.",["Remover devolve 75%; Desfazer recupera tudo."]="Remover devolve 75%; Desfazer recupera tudo.",["No modo livre, construa sem limite de moedas."]="No modo livre, construa sem limite de moedas.",["Pontes e praias"]="Pontes e praias",["Pontes ocupam agua ou margens na altura 1."]="Pontes ocupam \195\161gua ou margens na altura 1.",["Portos e quiosques precisam ficar junto da agua."]="Portos e quiosques precisam ficar junto da \195\161gua.",["Rampas retas aceitam trilhas, passeios e ruas."]="Rampas retas aceitam trilhas, passeios e ruas.",["Com via: abrigo tem 2 animais; centro vet., 4."]="Com via: abrigo tem 2 animais; centro vet., 4.",["GUIA DE BOLSO  /  %d DE %d"]="GUIA DE BOLSO  /  %d DE %d",["ESQUERDA / DIREITA  paginas     OK ou VOLTAR  fechar"]="ESQUERDA / DIREITA p\195\161ginas    OK ou VOLTAR fechar",["MODO LIVRE  /  Sem limites para experimentar"]="MODO LIVRE  /  Sem limites para experimentar",["JORNADA  /  Cada conquista abre novas possibilidades"]="JORNADA  /  Cada conquista abre novas possibilidades",["A ilha e toda sua."]="A ilha \195\169 toda sua.",["Todas as conquistas foram completadas."]="Todas as conquistas foram completadas.",["Continue criando, sem um fim obrigatorio."]="Continue criando, sem um fim obrigat\195\179rio.",["Recompensa: %d moedas"]="Recompensa em moedas: %d",["Receber conquista"]="Receber conquista",["Continuar explorando"]="Continuar explorando",["Conquistas: %d / 5"]="Conquistas: %d / 5",["Animais: %d    Pracas: %d    Lojas: %d"]="Animais: %d    Pra\195\167as: %d    Lojas: %d",["A CIDADE EM NUMEROS"]="A CIDADE EM N\195\154MEROS",["Receita por dia"]="Receita por dia",["Manutencao"]="Manuten\195\167\195\163o",["Saldo por dia"]="Saldo por dia",["Agua / pessoas"]="\195\129gua / pessoas",["Saude / pessoas"]="Sa\195\186de / pessoas",["Educacao / pessoas"]="Educa\195\167\195\163o / pessoas",["OK receber ou explorar    VOLTAR pausa"]="OK receber ou explorar    VOLTAR pausa",["Escolha a paisagem e o ritmo da partida."]="Escolha a paisagem e o ritmo da partida.",["Jornada: construir e prosperar"]="Jornada: construir e prosperar",["Modo livre: criar sem custos"]="Modo livre: criar sem custos",["Paisagem: semente %d"]="Paisagem: semente %d",["Arquivo: ilha %d"]="Arquivo: ilha %d",["Criar esta ilha"]="Criar esta ilha",["Sua paisagem"]="Sua paisagem",["40 construcoes"]="40 constru\195\167\195\181es",["5 conquistas"]="5 conquistas",["Espaco para 3 ilhas"]="Espa\195\167o para 3 ilhas",["OK escolher    VOLTAR inicio    Confirme a criacao no final"]="OK escolher    VOLTAR in\195\173cio    Confirme a cria\195\167\195\163o no final",["Substituir esta ilha?"]="Substituir esta ilha?",["O arquivo %d ja tem uma ilha salva."]="O arquivo %d j\195\161 tem uma ilha salva.",["Seu novo mundo vai ocupar este arquivo."]="Seu novo mundo vai ocupar este arquivo.",["Os outros dois arquivos ficam guardados."]="Os outros dois arquivos ficam guardados.",["Escolher outro arquivo"]="Escolher outro arquivo",["Substituir e criar a nova ilha"]="Substituir e criar nova ilha",["SETAS  escolher     OK  confirmar     VOLTAR  cancelar"]="SETAS escolher    OK confirmar    VOLTAR cancelar",["Suas ilhas"]="Suas ilhas",["Tres pequenos mundos, guardados neste dispositivo."]="Tr\195\170s pequenos mundos, guardados neste dispositivo.",["Ilha %d"]="Ilha %d",["Dia %d  /  Moradores: %d  /  %s"]="Dia %d  /  Moradores: %d  /  %s",["Arquivo invalido. Escolha outra ilha."]="Arquivo inv\195\161lido. Escolha outra ilha.",["Este arquivo esta vazio"]="Este arquivo est\195\161 vazio",["SETAS  escolher     OK  continuar     VOLTAR  inicio"]="SETAS escolher    OK continuar    VOLTAR in\195\173cio",["Bem-vindo a sua ilha! OK abre as ferramentas."]="Bem-vindo \195\160 sua ilha! OK abre as ferramentas.",["Nenhuma alteracao neste gesto."]="Nenhuma altera\195\167\195\163o neste gesto.",["Gesto parcial: %s"]="Gesto parcial: %s",["Gesto cancelado."]="Gesto cancelado.",["Via pronta."]="Via pronta.",["%s: pronta. Ligue uma via ao lado para ativar."]="Constru\195\167\195\163o pronta: %s. Ligue uma via ao lado para ativar.",["Zona confirmada. Acompanhe as obras."]="Zona confirmada. Acompanhe as obras.",["Zona removida. Construcoes prontas foram mantidas."]="Zona removida. Constru\195\167\195\181es prontas foram mantidas.",["Costa redesenhada."]="Costa redesenhada.",["Relevo e construcoes ajustados."]="Relevo e constru\195\167\195\181es ajustados.",["Conquista recebida! Sua ilha esta crescendo."]="Conquista recebida! Sua ilha est\195\161 crescendo.",["Este arquivo nao tem uma ilha valida."]="Este arquivo n\195\163o tem uma ilha v\195\161lida.",["%s: obra concluida!"]="%s: obra conclu\195\173da!",["Obra cancelada. Saldo nao gasto devolvido."]="Obra cancelada. Saldo n\195\163o gasto devolvido.",["OK mudar a luz   VOLTAR continuar"]="OK mudar a luz   VOLTAR continuar",["Caminhos que acompanham o relevo"]="Caminhos que acompanham o relevo",["Passeios e rampas para pedestres"]="Passeios e rampas para pedestres",["Conecta moradias e servicos"]="Conecta moradias e servi\195\167os",["Uma via larga para sua cidade"]="Uma via larga para sua cidade",["Atravesse canais e margens baixas"]="Atravesse canais e margens baixas",["Conecte duas margens com uma via"]="Conecte duas margens com uma via",["Ligue diferentes alturas da ilha"]="Ligue diferentes alturas da ilha",["+2 de felicidade com acesso"]="+2 de felicidade com acesso",["Balsas: receita e felicidade"]="Balsas: receita e felicidade",["Porto: 85 de receita por dia"]="Porto: 85 de receita por dia",["35 de energia para a ilha"]="35 de energia para a ilha",["60 de energia limpa"]="60 de energia limpa",["90 de energia limpa"]="90 de energia limpa",["Agua para 150 moradores"]="\195\129gua para 150 moradores",["Reciclagem para 150 moradores"]="Reciclagem para 150 moradores",["Saude para 100 moradores"]="Sa\195\186de para 100 moradores",["Educacao para 100 moradores"]="Educa\195\167\195\163o para 100 moradores",["Seguranca para 100 moradores"]="Seguran\195\167a para 100 moradores",["20 de receita por dia"]="20 de receita por dia",["+4 de felicidade na ilha"]="+4 de felicidade na ilha",["Delimite jardins e recintos"]="Delimite jardins e recintos",["2 animais ao conectar uma via ao lado"]="2 animais ao conectar uma via ao lado",["4 animais e saude para 100 moradores; requer via ao lado"]="4 animais e sa\195\186de para 100 moradores; requer via ao lado",["%d moradores com acesso viario"]="%d moradores com acesso vi\195\161rio",["%d de receita base por dia com acesso viario"]="%d de receita base por dia com acesso vi\195\161rio",["Cuidados e vida para sua ilha"]="Cuidados e vida para sua ilha",["Fora dos limites da ilha"]="Fora dos limites da ilha",["Faltam moedas. Espere a renda ou use o modo livre."]="Faltam moedas. Espere a renda ou use o modo livre.",["Esta via ja tem esse piso"]="Esta via j\195\161 tem esse piso",["Este espaco ja esta ocupado"]="Este espa\195\167o j\195\161 est\195\161 ocupado",["Eleve e nivele o terreno primeiro"]="Eleve e nivele o terreno primeiro",["Esta construcao precisa de terreno plano"]="Esta constru\195\167\195\163o precisa de terreno plano",["Use Nivelar para criar uma rampa reta"]="Use Nivelar para criar uma rampa reta",["Pontes atravessam agua ou margens baixas"]="Pontes atravessam \195\161gua ou margens baixas",["Escolha um terreno plano junto da agua"]="Escolha um terreno plano junto da \195\161gua",["Pronto para construir"]="Pronto para construir",["%s: pronto!"]="%s: pronto!",["Nada para remover aqui"]="Nada para remover aqui",["Removido. Reembolso de 75%."]="Removido. Reembolso de 75%.",["Relevo e fundacoes ajustados"]="Relevo e funda\195\167\195\181es ajustados",["Fundo de apoio: +300 moedas para recuperar a ilha."]="Fundo de apoio: +300 moedas para recuperar a ilha.",["Um lugar para chamar de seu"]="Um lugar para chamar de seu",["Chegue a 20 moradores"]="Chegue a 20 moradores",["A ilha funciona"]="A ilha funciona",["40 moradores, energia suficiente"]="40 moradores, energia suficiente",["A vida la fora"]="A vida l\195\161 fora",["3 pracas ou mirantes e 2 comercios"]="3 pra\195\167as ou mirantes e 2 com\195\169rcios",["Amigos de todas as especies"]="Amigos de todas as esp\195\169cies",["Tenha 6 animais e uma clinica"]="Tenha 6 animais e uma cl\195\173nica",["Uma pequena grande ilha"]="Uma pequena grande ilha",["100 moradores e 80% de felicidade"]="100 moradores e 80% de felicidade",["Lote reservado"]="Lote reservado",["Sem trabalhador: conecte uma moradia"]="Sem trabalhador: conecte uma moradia",["Sem rota: reconecte o caminho"]="Sem rota: reconecte o caminho",["Terreno invalido: nivele o lote"]="Terreno inv\195\161lido: nivele o lote",["Sem demanda para este uso"]="Sem demanda para este uso",["Faltam moedas para reservar a obra"]="Faltam moedas para reservar a obra",["Lote sem acesso viario"]="Lote sem acesso vi\195\161rio",["Trabalhador a caminho"]="Trabalhador a caminho",["Construcao em andamento"]="Constru\195\167\195\163o em andamento",["Aguarde a pessoa atravessar o lote"]="Aguarde a pessoa atravessar o lote",["Aguarde uma obra terminar"]="Aguarde uma obra terminar",["Autorize todo o lote desta construcao"]="Autorize todo o lote desta constru\195\167\195\163o",["Obra nao encontrada"]="Obra n\195\163o encontrada",["Obra cancelada; saldo nao gasto devolvido"]="Obra cancelada; saldo n\195\163o gasto devolvido",["Uso de zona invalido"]="Uso de zona inv\195\161lido",["Apagar autorizacao sem demolir construcoes"]="Apagar autoriza\195\167\195\163o sem demolir constru\195\167\195\181es",["Eleve a terra antes de zonear"]="Eleve a terra antes de zonear",["Clinica: autorize um lote de 2 por 1 com acesso"]="Cl\195\173nica: autorize um lote de 2 por 1 com acesso",["Autorizar crescimento com acesso viario"]="Autorizar crescimento com acesso vi\195\161rio",["Esta celula ja tem esse uso"]="Esta c\195\169lula j\195\161 tem esse uso",["Lote reservado para uma obra"]="Lote reservado para uma obra",["Aguarde a pessoa atravessar antes de construir"]="Aguarde a pessoa atravessar antes de construir",["Ha uma pessoa atravessando esta ponte; aguarde antes de remover"]="H\195\161 uma pessoa atravessando esta ponte; aguarde antes de remover",["Ha uma pessoa nesta travessia; mantenha o terreno seguro ate ela passar"]="H\195\161 uma pessoa nesta travessia; mantenha o terreno seguro at\195\169 ela passar",["O ajuste afeta uma pessoa ou seu acesso, inclusive alem do pincel. Aguarde o local ficar livre."]="O ajuste afeta uma pessoa ou seu acesso, inclusive al\195\169m do pincel. Aguarde o local ficar livre.",["A ilha progrediu; esta transacao nao pode substituir a simulacao"]="A ilha progrediu; esta transa\195\167\195\163o n\195\163o pode substituir a simula\195\167\195\163o",["Nada para desfazer"]="Nada para desfazer",["Uma zona posterior ocupa esta transacao"]="Uma zona posterior ocupa esta transa\195\167\195\163o",["Obras progrediram; desfazer terreno antigo apagaria progresso"]="Obras progrediram; desfazer terreno antigo apagaria progresso",["Faltam moedas para desfazer este reembolso"]="Faltam moedas para desfazer este reembolso",["Ultima acao desfeita"]="\195\154ltima a\195\167\195\163o desfeita",["Aguarde o transito liberar este espaco"]="Aguarde o tr\195\162nsito liberar este espa\195\167o",["Aguarde o veiculo sair desta via"]="Aguarde o ve\195\173culo sair desta via",["Aguarde a travessia antes de mudar esta costa ou via"]="Aguarde a travessia antes de mudar esta costa ou via",["Aguarde o transito liberar o terreno antes de desfazer"]="Aguarde o tr\195\162nsito liberar o terreno antes de desfazer"},["catalog"]={{"Trilha de terra","Vias",1,1,8,0,0,0,"terra","Trilha de","terra"},{"Passeio","Vias",1,1,16,0,0,0,"pedestres","Passeio",""},{"Rua","Vias",1,1,25,0,0,0,"rua","Rua",""},{"Avenida","Vias",2,2,70,1,0,0,"avenida","Avenida",""},{"Ponte de madeira","Vias",1,1,60,0,0,0,"bridge","Ponte de","madeira"},{"Ponte rodovi\195\161ria","Vias",2,2,150,1,0,0,"bridge","Ponte","rodovi\195\161ria"},{"Escadaria","Vias",1,1,30,0,0,0,"steps","Escadaria",""},{"Ponto de \195\180nibus","Vias",1,1,110,1,0,0,"bus","Ponto de","\195\180nibus"},{"Terminal de balsas","Vias",3,2,650,6,0,0,"ferry","Terminal de","balsas"},{"Porto de cargas","Vias",4,3,1200,10,0,0,"port","Porto de","cargas"},{"Casinha","Moradia",1,1,90,0,4,0,"house","Casinha",""},{"Casa com jardim","Moradia",2,1,160,1,8,0,"garden","Casa com","jardim"},{"Vila de sobrados","Moradia",3,1,330,2,18,0,"row","Vila de","sobrados"},{"Predinho","Moradia",1,1,240,1,14,0,"apart","Predinho",""},{"Edif\195\173cio","Moradia",2,1,480,3,32,0,"apart","Edif\195\173cio",""},{"Torre residencial","Moradia",2,2,1000,6,72,0,"tower","Torre","residencial"},{"Mercadinho","Comercio",1,1,160,2,0,12,"shop","Mercadinho",""},{"Padaria e caf\195\169","Comercio",1,1,180,2,0,14,"cafe","Padaria e","caf\195\169"},{"Pet shop","Comercio",1,1,170,2,0,12,"pet","Pet shop",""},{"Restaurante","Comercio",2,1,300,3,0,25,"rest","Restaurante",""},{"Feira ao ar livre","Comercio",4,1,360,2,0,28,"market","Feira ao ar","livre"},{"Hotel da ilha","Comercio",2,3,900,7,0,65,"hotel","Hotel da ilha",""},{"Jardim comercial","Comercio",3,2,650,5,0,48,"mall","Jardim","comercial"},{"Oficina","Comercio",3,2,600,5,0,60,"factory","Oficina",""},{"Gerador","Servicos",2,1,220,7,0,0,"diesel","Gerador",""},{"Turbina e\195\179lica","Servicos",2,2,700,3,0,0,"wind","Turbina","e\195\179lica"},{"Usina solar","Servicos",3,2,950,2,0,0,"solar","Usina solar",""},{"\195\129gua e saneamento","Servicos",3,2,650,5,0,0,"water","\195\129gua e","saneamento"},{"Reciclagem","Servicos",3,2,580,5,0,0,"waste","Reciclagem",""},{"Cl\195\173nica","Servicos",2,1,420,4,0,0,"clinic","Cl\195\173nica",""},{"Escola","Servicos",3,2,500,4,0,0,"school","Escola",""},{"Bombeiros","Servicos",2,2,430,4,0,0,"fire","Bombeiros",""},{"Posto policial","Servicos",2,2,400,3,0,0,"police","Posto policial",""},{"Prefeitura","Servicos",2,2,500,3,0,0,"admin","Prefeitura",""},{"Pra\195\167a e playground","Natureza",2,2,100,1,0,0,"park","Pra\195\167a e","playground"},{"Mirante","Natureza",2,1,140,1,0,4,"lookout","Mirante",""},{"Quiosque de praia","Natureza",1,1,120,1,0,8,"kiosk","Quiosque de","praia"},{"Cerca e port\195\163o","Natureza",1,1,15,0,0,0,"fence","Cerca e","port\195\163o"},{"Abrigo de animais","Natureza",2,2,320,3,0,16,"shelter","Abrigo de","animais"},{"Centro veterin\195\161rio","Natureza",3,2,650,5,0,32,"vet","Centro","veterin\195\161rio"}}},["en"]={["messages"]={["Mare"]="Mar\195\169",["Um pedacinho de mundo, do seu jeito."]="A little world, made your way.",["Vias"]="Roads",["Moradia"]="Housing",["Comercio"]="Shops",["Servicos"]="Services",["Natureza"]="Nature",["Construir"]="Build",["Terreno"]="Terrain",["Remover"]="Remove",["Desfazer"]="Undo",["Zonas"]="Zones",["Elevar"]="Raise",["Baixar"]="Lower",["Nivelar"]="Level",["Distorcer"]="Pull coast",["Pinte um nivel acima. As construcoes sobem junto."]="Paint one level higher. Buildings rise with the land.",["Pinte um nivel abaixo. As vias se acomodam."]="Paint one level lower. Roads adjust to the land.",["Copie uma altura e pinte o terreno com as setas."]="Copy a height, then paint the land with the arrows.",["Segure a costa e puxe. As fundacoes acompanham."]="Grab and pull the coast. Foundations move with it.",["Escolha uma peca e coloque direto na ilha."]="Choose a building and place it on the island.",["Molde morros, praias e enseadas."]="Shape hills, beaches and bays.",["Libere espaco e receba 75% do custo de volta."]="Clear space and get 75% of the cost back.",["Desfaca uma construcao, remocao ou gesto inteiro."]="Undo a build, removal or entire gesture.",["Autorize bairros; moradores chegam e constroem."]="Zone neighborhoods; residents arrive and build.",["Apagar zona"]="Clear zone",["Casas: acesso, energia e lojas sustentam novos moradores."]="Homes need road access, power and shops to attract residents.",["Lojas: atendem moradores e permitem mais casas."]="Shops serve residents and make room for more homes.",["Clinicas: lotes 2x1 para moradores sem cobertura."]="Clinics: 2\195\1511 plots for residents without care.",["Retira autorizacao e cancela obras; nao demole edificios."]="Clears zoning and cancels projects; keeps finished buildings.",["pequeno"]="small",["medio"]="medium",["grande"]="large",["Explore a ilha"]="Explore the island",["Elevar terreno"]="Raise terrain",["Baixar terreno"]="Lower terrain",["Nivelar terreno"]="Level terrain",["Distorcer a costa"]="Pull the coast",["Remover construcao"]="Remove a building",["Zonear bairro"]="Zone a neighborhood",["Continuar"]="Continue",["Nova ilha"]="New island",["Como jogar"]="How to play",["Ajustes"]="Settings",["Continuar jogando"]="Keep playing",["Salvar a ilha"]="Save island",["Diario da ilha"]="Island journal",["Contemplar a ilha"]="Enjoy the view",["Salvar e ir ao inicio"]="Save and return to title",["Trocar via"]="Change road",["Concluir"]="Done",["Girar peca"]="Rotate",["Trocar peca"]="Change building",["Trocar uso"]="Change zone",["Pincel"]="Brush",["Trocar ferramenta"]="Change tool",["Sons curtos ao navegar e construir."]="Soft sounds for menus and building.",["Reduz ondas, passaros e animacoes."]="Reduces waves, birds and animations.",["Ajusta vegetacao e custo das sombras."]="Adjusts plants and shadow detail.",["Pixels inteiros nas duas distancias."]="Crisp pixels at both distances.",["Escolha um momento do dia."]="Choose a time of day.",["Escolha Portugues, English ou Deutsch. A troca e imediata."]="Portugu\195\170s, English or Deutsch. Changes apply now.",["Salva as preferencias neste dispositivo."]="Saves preferences on this device.",["Portugu\195\170s"]="Portugu\195\170s",["English"]="English",["Deutsch"]="Deutsch",["Ilha salva. Pode voltar quando quiser."]="Island saved. Come back whenever you like.",["Nao foi possivel salvar neste dispositivo."]="Could not save on this device.",["MARE"]="MAR\195\137",["Seu mundo, no seu ritmo."]="Your world, your pace.",["SETAS escolher   OK entrar"]="ARROWS choose   OK open",["MAR ABERTO"]="OPEN SEA",["DIA %d"]="DAY %d",["Modo livre"]="Free play",["Jornada"]="Journey",["Livre"]="Free",["moedas"]="coins",["moradores"]="residents",["%d / %d"]="%d / %d",["energia"]="power",["%d%%"]="%d%%",["felicidade"]="happiness",["Nivelar: altura do mar"]="Level: sea level",["Nivelar: altura %d"]="Level: height %d",["SETAS explorar    OK criar    VOLTAR pausa"]="ARROWS explore    OK create    BACK pause",["OK construir  /  Custo: %d  /  VOLTAR opcoes"]="OK build  /  Cost: %d  /  BACK options",["%s  /  VOLTAR opcoes"]="%s  /  BACK options",["SETAS tracar    OK terminar    VOLTAR cancelar"]="ARROWS draw    OK finish    BACK cancel",["OK comecar via    VOLTAR opcoes"]="OK start road    BACK options",["SETAS pintar    OK confirmar zona    VOLTAR cancelar"]="ARROWS paint    OK confirm zone    BACK cancel",["OK comecar zona    VOLTAR escolher uso"]="OK start zone    BACK choose use",["Sem acesso: construcao inativa    OK criar    VOLTAR pausa"]="No road: building inactive    OK create    BACK pause",["Com acesso    OK criar    VOLTAR pausa"]="Road connected    OK create    BACK pause",["%s  /  %d%%"]="%s  /  %d%%",["Autorize o lote inteiro: clinicas precisam de 2x1"]="Zone the whole plot: clinics need 2\195\1511",["Aguardando uma das quatro equipes de obra"]="Waiting for one of the four building crews",["Zona autorizada: aguardando ocupacao"]="Zone ready: waiting for residents",["SETAS puxar    OK soltar    VOLTAR cancelar"]="ARROWS pull    OK release    BACK cancel",["SETAS pintar    OK concluir    VOLTAR cancelar"]="ARROWS paint    OK finish    BACK cancel",["OK remover e recuperar 75%    VOLTAR explorar"]="OK remove and refund 75%    BACK explore",["OK segurar    Pincel %s    VOLTAR opcoes"]="OK grab    Brush: %s    BACK options",["OK copiar altura    Pincel %s    VOLTAR opcoes"]="OK copy height    Brush: %s    BACK options",["OK comecar    Pincel %s    VOLTAR opcoes"]="OK start    Brush: %s    BACK options",["%+d / dia"]="%+d / day",["Sem acesso: ligue uma via ao lado para ativar."]="No road access: add a road alongside to activate.",["Conquista pronta!"]="Milestone ready!",["VOLTAR > Diario para receber"]="BACK > Journal to claim",["%d%%  /  Diario na pausa"]="%d%%  /  Journal in pause",["Desfazer disponivel: %d acoes. O gesto inteiro volta."]="Undo steps: %d. Each restores the whole gesture.",["Nada para desfazer ainda."]="Nothing to undo yet.",["O que vamos criar?"]="What shall we create?",["SETAS escolher    OK usar    VOLTAR explorar"]="ARROWS choose    OK use    BACK explore",["Moldar a ilha"]="Shape the island",["SETAS escolher    OK usar    VOLTAR ferramentas"]="ARROWS choose    OK use    BACK tools",["Crescer em bairros"]="Grow neighborhoods",["Cada tracado pode ser desfeito de uma vez."]="Each road stroke can be undone in one step.",["OK gira 90 graus e volta para a ilha."]="OK rotates 90 degrees and returns to the island.",["Escolha outra peca. A ilha fica como esta."]="Choose another building. Your island stays as it is.",["Volte a explorar a ilha."]="Go back to exploring the island.",["Pincel: %s"]="Brush: %s",["OK muda o tamanho. A terra leva as construcoes junto."]="OK changes brush size. Buildings move with the land.",["Troque entre elevar, baixar, nivelar e distorcer."]="Switch between raising, lowering, leveling and pulling.",["Escolha o que vai fazer parte da sua ilha."]="Choose what belongs on your island.",["%d  /  %dx%d"]="%d  /  %d\195\151%d",["SELECIONADO"]="SELECTED",["%d x %d terrenos"]="Footprint: %d \195\151 %d",["Custo: %d moedas"]="Coin cost: %d",["%d moedas / dia"]="Coins per day: %d",["ESQUERDA / DIREITA categorias    OK ver construcoes    VOLTAR"]="LEFT / RIGHT categories    OK see buildings    BACK",["SETAS escolher    CIMA categorias    OK colocar    VOLTAR"]="ARROWS choose    UP categories    OK place    BACK",["Um respiro"]="Take a breath",["Sua ilha fica guardada enquanto voce faz uma pausa."]="Your island waits safely while you take a break.",["ILHA %d"]="ISLAND %d",["Dia %d  /  Moradores: %d"]="Day %d  /  Residents: %d",["SETAS escolher    OK confirmar    VOLTAR continuar"]="ARROWS choose    OK confirm    BACK resume",["Deixe a ilha confortavel para voce."]="Make the island feel right for you.",["Som: ligado"]="Sound: on",["Som: desligado"]="Sound: off",["Movimento: ligado"]="Motion: on",["Movimento: reduzido"]="Motion: reduced",["Detalhes: completos"]="Details: full",["Detalhes: economicos"]="Details: low",["Zoom: %dx"]="Zoom: %d\195\151",["Luz: %s"]="Light: %s",["Idioma: %s"]="Language: %s",["Ciclo natural"]="Day cycle",["Manha"]="Morning",["Golden hour"]="Golden hour",["Noite"]="Night",["Manha, por do sol e luzes da noite."]="Morning, sunset and glowing nights.",["SETAS escolher    OK alterar    VOLTAR concluir"]="ARROWS choose    OK change    BACK done",["Sua ilha, seu ritmo"]="Your island, your pace",["Setas movem o cursor pelas diagonais da ilha."]="Arrows move the cursor along the island diagonals.",["OK abre as ferramentas durante a exploracao."]="OK opens tools while you explore.",["Voltar cancela gestos ou abre opcoes da peca."]="Back cancels a gesture or opens building options.",["Ao explorar, Voltar abre a pausa e o diario."]="While exploring, Back opens pause and the journal.",["Moldar a terra"]="Shape the land",["Elevar e Baixar: OK, setas para pintar, OK."]="Raise and Lower: OK, arrows to paint, then OK.",["Nivelar: OK copia a altura; setas pintam nela."]="Level: OK copies a height; arrows paint at that height.",["Distorcer: OK segura; setas puxam; OK solta."]="Pull coast: OK grabs; arrows pull; OK releases.",["Casas sobem e descem; vias ganham rampas."]="Homes rise and fall; roads gain ramps.",["Fazer a ilha crescer"]="Help the island grow",["Casas, lojas e servicos precisam de via ao lado."]="Homes, shops and services need a road alongside.",["Geradores e usinas tambem precisam de acesso."]="Generators and power plants need road access too.",["Sem via, a construcao fica inativa."]="Without a road, a building stays inactive.",["Com acesso, energia e servicos atendem a ilha."]="With road access, power and services reach the island.",["Experimentar"]="Try things out",["Um dia passa a cada 12 segundos de partida."]="One day passes every 12 seconds of play.",["Troque o piso de vias pagando a diferenca."]="Change road surfaces by paying the difference.",["Remover devolve 75%; Desfazer recupera tudo."]="Remove refunds 75%; Undo restores everything.",["No modo livre, construa sem limite de moedas."]="In free play, build without a coin limit.",["Pontes e praias"]="Bridges and beaches",["Pontes ocupam agua ou margens na altura 1."]="Bridges span water or shores at height 1.",["Portos e quiosques precisam ficar junto da agua."]="Harbors and kiosks need to be beside the water.",["Rampas retas aceitam trilhas, passeios e ruas."]="Straight ramps support trails, walkways and streets.",["Com via: abrigo tem 2 animais; centro vet., 4."]="With a road: shelters house 2 animals; vet centers, 4.",["GUIA DE BOLSO  /  %d DE %d"]="POCKET GUIDE  /  %d OF %d",["ESQUERDA / DIREITA  paginas     OK ou VOLTAR  fechar"]="LEFT / RIGHT pages    OK or BACK close",["MODO LIVRE  /  Sem limites para experimentar"]="FREE PLAY  /  Endless room to experiment",["JORNADA  /  Cada conquista abre novas possibilidades"]="JOURNEY  /  Each milestone opens new possibilities",["A ilha e toda sua."]="The island is all yours.",["Todas as conquistas foram completadas."]="You have reached every milestone.",["Continue criando, sem um fim obrigatorio."]="Keep creating; there is no finish line.",["Recompensa: %d moedas"]="Coin reward: %d",["Receber conquista"]="Claim milestone",["Continuar explorando"]="Keep exploring",["Conquistas: %d / 5"]="Milestones: %d / 5",["Animais: %d    Pracas: %d    Lojas: %d"]="Animals: %d    Plazas: %d    Shops: %d",["A CIDADE EM NUMEROS"]="THE ISLAND IN NUMBERS",["Receita por dia"]="Daily income",["Manutencao"]="Upkeep",["Saldo por dia"]="Daily balance",["Agua / pessoas"]="Water / residents",["Saude / pessoas"]="Health / residents",["Educacao / pessoas"]="School / residents",["OK receber ou explorar    VOLTAR pausa"]="OK claim or explore    BACK pause",["Escolha a paisagem e o ritmo da partida."]="Choose the landscape and pace of your game.",["Jornada: construir e prosperar"]="Journey: build and thrive",["Modo livre: criar sem custos"]="Free play: build without costs",["Paisagem: semente %d"]="Landscape: seed %d",["Arquivo: ilha %d"]="Save slot: island %d",["Criar esta ilha"]="Create this island",["Sua paisagem"]="Your landscape",["40 construcoes"]="40 buildings",["5 conquistas"]="5 milestones",["Espaco para 3 ilhas"]="Room for 3 islands",["OK escolher    VOLTAR inicio    Confirme a criacao no final"]="OK choose    BACK title    Confirm creation at the end",["Substituir esta ilha?"]="Replace this island?",["O arquivo %d ja tem uma ilha salva."]="Slot %d already holds a saved island.",["Seu novo mundo vai ocupar este arquivo."]="Your new world will take this save slot.",["Os outros dois arquivos ficam guardados."]="The other two save slots stay untouched.",["Escolher outro arquivo"]="Choose another slot",["Substituir e criar a nova ilha"]="Replace and create new island",["SETAS  escolher     OK  confirmar     VOLTAR  cancelar"]="ARROWS choose    OK confirm    BACK cancel",["Suas ilhas"]="Your islands",["Tres pequenos mundos, guardados neste dispositivo."]="Three little worlds, saved on this device.",["Ilha %d"]="Island %d",["Dia %d  /  Moradores: %d  /  %s"]="Day %d  /  Residents: %d  /  %s",["Arquivo invalido. Escolha outra ilha."]="Invalid save. Choose another island.",["Este arquivo esta vazio"]="This slot is empty",["SETAS  escolher     OK  continuar     VOLTAR  inicio"]="ARROWS choose    OK continue    BACK title",["Bem-vindo a sua ilha! OK abre as ferramentas."]="Welcome to your island! OK opens the tools.",["Nenhuma alteracao neste gesto."]="This gesture made no changes.",["Gesto parcial: %s"]="Gesture partly applied: %s",["Gesto cancelado."]="Gesture canceled.",["Via pronta."]="Road ready.",["%s: pronta. Ligue uma via ao lado para ativar."]="%s is ready. Add a road alongside to activate it.",["Zona confirmada. Acompanhe as obras."]="Zone confirmed. Watch construction begin.",["Zona removida. Construcoes prontas foram mantidas."]="Zone removed. Completed buildings were kept.",["Costa redesenhada."]="Coast reshaped.",["Relevo e construcoes ajustados."]="Terrain and buildings adjusted.",["Conquista recebida! Sua ilha esta crescendo."]="Milestone claimed! Your island is growing.",["Este arquivo nao tem uma ilha valida."]="There is no valid island in this slot.",["%s: obra concluida!"]="%s: construction complete!",["Obra cancelada. Saldo nao gasto devolvido."]="Construction canceled. Unspent funds returned.",["OK mudar a luz   VOLTAR continuar"]="OK change light   BACK resume",["Caminhos que acompanham o relevo"]="Paths that follow the terrain",["Passeios e rampas para pedestres"]="Footpaths and ramps for pedestrians",["Conecta moradias e servicos"]="Connects homes and services",["Uma via larga para sua cidade"]="A wide road for your town",["Atravesse canais e margens baixas"]="Cross channels and low banks",["Conecte duas margens com uma via"]="Connect two banks with a road",["Ligue diferentes alturas da ilha"]="Connect different heights on the island",["+2 de felicidade com acesso"]="+2 happiness with access",["Balsas: receita e felicidade"]="Ferries: income and happiness",["Porto: 85 de receita por dia"]="Port: 85 income per day",["35 de energia para a ilha"]="35 power for the island",["60 de energia limpa"]="60 clean power",["90 de energia limpa"]="90 clean power",["Agua para 150 moradores"]="Water for 150 residents",["Reciclagem para 150 moradores"]="Recycling for 150 residents",["Saude para 100 moradores"]="Healthcare for 100 residents",["Educacao para 100 moradores"]="Education for 100 residents",["Seguranca para 100 moradores"]="Safety for 100 residents",["20 de receita por dia"]="20 income per day",["+4 de felicidade na ilha"]="+4 happiness on the island",["Delimite jardins e recintos"]="Mark out gardens and enclosures",["2 animais ao conectar uma via ao lado"]="2 animals with a road connected beside it",["4 animais e saude para 100 moradores; requer via ao lado"]="4 animals and healthcare for 100 residents; needs a road beside it",["%d moradores com acesso viario"]="%d residents with road access",["%d de receita base por dia com acesso viario"]="%d base income per day with road access",["Cuidados e vida para sua ilha"]="Care and life for your island",["Fora dos limites da ilha"]="Outside the island boundaries",["Faltam moedas. Espere a renda ou use o modo livre."]="Not enough coins. Wait for income or use free mode.",["Esta via ja tem esse piso"]="This road already has this surface",["Este espaco ja esta ocupado"]="This space is already occupied",["Eleve e nivele o terreno primeiro"]="Raise and level the terrain first",["Esta construcao precisa de terreno plano"]="This building needs flat terrain",["Use Nivelar para criar uma rampa reta"]="Use Level to make a straight ramp",["Pontes atravessam agua ou margens baixas"]="Bridges cross water or low banks",["Escolha um terreno plano junto da agua"]="Choose flat terrain beside the water",["Pronto para construir"]="Ready to build",["%s: pronto!"]="%s: ready!",["Nada para remover aqui"]="Nothing to remove here",["Removido. Reembolso de 75%."]="Removed. 75% refunded.",["Relevo e fundacoes ajustados"]="Terrain and foundations adjusted",["Fundo de apoio: +300 moedas para recuperar a ilha."]="Support fund: +300 coins to help the island recover.",["Um lugar para chamar de seu"]="A place of your own",["Chegue a 20 moradores"]="Reach 20 residents",["A ilha funciona"]="The island works",["40 moradores, energia suficiente"]="40 residents, enough power",["A vida la fora"]="Life outdoors",["3 pracas ou mirantes e 2 comercios"]="3 parks or lookouts and 2 shops",["Amigos de todas as especies"]="Friends of every species",["Tenha 6 animais e uma clinica"]="Have 6 animals and a clinic",["Uma pequena grande ilha"]="A small but mighty island",["100 moradores e 80% de felicidade"]="100 residents and 80% happiness",["Lote reservado"]="Lot reserved",["Sem trabalhador: conecte uma moradia"]="No worker: connect a home",["Sem rota: reconecte o caminho"]="No route: reconnect the path",["Terreno invalido: nivele o lote"]="Invalid terrain: level the lot",["Sem demanda para este uso"]="No demand for this use",["Faltam moedas para reservar a obra"]="Not enough coins to reserve construction",["Lote sem acesso viario"]="Lot has no road access",["Trabalhador a caminho"]="Worker on the way",["Construcao em andamento"]="Construction in progress",["Aguarde a pessoa atravessar o lote"]="Wait for the person to cross the lot",["Aguarde uma obra terminar"]="Wait for a construction project to finish",["Autorize todo o lote desta construcao"]="Authorize the entire lot for this building",["Obra nao encontrada"]="Construction project not found",["Obra cancelada; saldo nao gasto devolvido"]="Construction canceled; unspent balance returned",["Uso de zona invalido"]="Invalid zone use",["Apagar autorizacao sem demolir construcoes"]="Remove authorization without demolishing buildings",["Eleve a terra antes de zonear"]="Raise the land before zoning",["Clinica: autorize um lote de 2 por 1 com acesso"]="Clinic: authorize a 2 by 1 lot with access",["Autorizar crescimento com acesso viario"]="Allow growth with road access",["Esta celula ja tem esse uso"]="This cell already has this use",["Lote reservado para uma obra"]="Lot reserved for construction",["Aguarde a pessoa atravessar antes de construir"]="Wait for the person to cross before building",["Ha uma pessoa atravessando esta ponte; aguarde antes de remover"]="Someone is crossing this bridge; wait before removing it",["Ha uma pessoa nesta travessia; mantenha o terreno seguro ate ela passar"]="Someone is crossing here; keep the terrain safe until they pass",["O ajuste afeta uma pessoa ou seu acesso, inclusive alem do pincel. Aguarde o local ficar livre."]="This edit affects a person or their access, possibly beyond the brush. Wait for the area to clear.",["A ilha progrediu; esta transacao nao pode substituir a simulacao"]="The island has progressed; this action cannot replace the simulation",["Nada para desfazer"]="Nothing to undo",["Uma zona posterior ocupa esta transacao"]="A newer zone overlaps this action",["Obras progrediram; desfazer terreno antigo apagaria progresso"]="Construction has progressed; restoring old terrain would erase progress",["Faltam moedas para desfazer este reembolso"]="Not enough coins to undo this refund",["Ultima acao desfeita"]="Last action undone",["Aguarde o transito liberar este espaco"]="Wait for traffic to clear this space",["Aguarde o veiculo sair desta via"]="Wait for the vehicle to leave this road",["Aguarde a travessia antes de mudar esta costa ou via"]="Wait for the crossing to finish before changing this coast or road",["Aguarde o transito liberar o terreno antes de desfazer"]="Wait for traffic to clear the terrain before undoing"},["catalog"]={{"Dirt trail","Vias",1,1,8,0,0,0,"terra","Dirt trail",""},{"Footpath","Vias",1,1,16,0,0,0,"pedestres","Footpath",""},{"Street","Vias",1,1,25,0,0,0,"rua","Street",""},{"Avenue","Vias",2,2,70,1,0,0,"avenida","Avenue",""},{"Wooden bridge","Vias",1,1,60,0,0,0,"bridge","Wooden","bridge"},{"Road bridge","Vias",2,2,150,1,0,0,"bridge","Road bridge",""},{"Stairway","Vias",1,1,30,0,0,0,"steps","Stairway",""},{"Bus stop","Vias",1,1,110,1,0,0,"bus","Bus stop",""},{"Ferry terminal","Vias",3,2,650,6,0,0,"ferry","Ferry","terminal"},{"Cargo port","Vias",4,3,1200,10,0,0,"port","Cargo port",""},{"Cottage","Moradia",1,1,90,0,4,0,"house","Cottage",""},{"Garden home","Moradia",2,1,160,1,8,0,"garden","Garden home",""},{"Row houses","Moradia",3,1,330,2,18,0,"row","Row houses",""},{"Small apartments","Moradia",1,1,240,1,14,0,"apart","Small","apartments"},{"Apartment block","Moradia",2,1,480,3,32,0,"apart","Apartment","block"},{"Residential tower","Moradia",2,2,1000,6,72,0,"tower","Residential","tower"},{"Corner shop","Comercio",1,1,160,2,0,12,"shop","Corner shop",""},{"Bakery and caf\195\169","Comercio",1,1,180,2,0,14,"cafe","Bakery and","caf\195\169"},{"Pet shop","Comercio",1,1,170,2,0,12,"pet","Pet shop",""},{"Restaurant","Comercio",2,1,300,3,0,25,"rest","Restaurant",""},{"Open-air market","Comercio",4,1,360,2,0,28,"market","Open-air","market"},{"Island hotel","Comercio",2,3,900,7,0,65,"hotel","Island hotel",""},{"Garden shops","Comercio",3,2,650,5,0,48,"mall","Garden shops",""},{"Workshop","Comercio",3,2,600,5,0,60,"factory","Workshop",""},{"Generator","Servicos",2,1,220,7,0,0,"diesel","Generator",""},{"Wind turbine","Servicos",2,2,700,3,0,0,"wind","Wind turbine",""},{"Solar farm","Servicos",3,2,950,2,0,0,"solar","Solar farm",""},{"Water and sewage","Servicos",3,2,650,5,0,0,"water","Water and","sewage"},{"Recycling","Servicos",3,2,580,5,0,0,"waste","Recycling",""},{"Clinic","Servicos",2,1,420,4,0,0,"clinic","Clinic",""},{"School","Servicos",3,2,500,4,0,0,"school","School",""},{"Fire station","Servicos",2,2,430,4,0,0,"fire","Fire station",""},{"Police station","Servicos",2,2,400,3,0,0,"police","Police","station"},{"Town hall","Servicos",2,2,500,3,0,0,"admin","Town hall",""},{"Park and play area","Natureza",2,2,100,1,0,0,"park","Park and play","area"},{"Lookout","Natureza",2,1,140,1,0,4,"lookout","Lookout",""},{"Beach kiosk","Natureza",1,1,120,1,0,8,"kiosk","Beach kiosk",""},{"Fence and gate","Natureza",1,1,15,0,0,0,"fence","Fence and","gate"},{"Animal shelter","Natureza",2,2,320,3,0,16,"shelter","Animal","shelter"},{"Vet clinic","Natureza",3,2,650,5,0,32,"vet","Vet clinic",""}}},["de"]={["messages"]={["Mare"]="Mar\195\169",["Um pedacinho de mundo, do seu jeito."]="Ein St\195\188ck Welt, ganz nach deinem Geschmack.",["Vias"]="Wege",["Moradia"]="Wohnen",["Comercio"]="Handel",["Servicos"]="Dienste",["Natureza"]="Natur",["Construir"]="Bauen",["Terreno"]="Gel\195\164nde",["Remover"]="Entfernen",["Desfazer"]="R\195\188ckg\195\164ngig",["Zonas"]="Bauzonen",["Elevar"]="Anheben",["Baixar"]="Senken",["Nivelar"]="Einebnen",["Distorcer"]="Verformen",["Pinte um nivel acima. As construcoes sobem junto."]="Male eine Stufe h\195\182her. Die Geb\195\164ude steigen mit.",["Pinte um nivel abaixo. As vias se acomodam."]="Male eine Stufe tiefer. Die Wege passen sich an.",["Copie uma altura e pinte o terreno com as setas."]="Kopiere eine H\195\182he und male das Gel\195\164nde mit den Pfeilen.",["Segure a costa e puxe. As fundacoes acompanham."]="Greife und ziehe die K\195\188ste. Die Fundamente folgen.",["Escolha uma peca e coloque direto na ilha."]="W\195\164hle ein Bauwerk und setze es auf die Insel.",["Molde morros, praias e enseadas."]="Forme H\195\188gel, Str\195\164nde und Buchten.",["Libere espaco e receba 75% do custo de volta."]="Schaffe Platz und erhalte 75% der Kosten zur\195\188ck.",["Desfaca uma construcao, remocao ou gesto inteiro."]="Mache einen Bau, Abriss oder eine ganze Geste r\195\188ckg\195\164ngig.",["Autorize bairros; moradores chegam e constroem."]="Weise Bauzonen aus. Menschen ziehen ein und bauen.",["Apagar zona"]="Zone l\195\182schen",["Casas: acesso, energia e lojas sustentam novos moradores."]="H\195\164user brauchen Wege, Strom und L\195\164den f\195\188r neue Bewohner.",["Lojas: atendem moradores e permitem mais casas."]="L\195\164den versorgen die Menschen und erm\195\182glichen mehr H\195\164user.",["Clinicas: lotes 2x1 para moradores sem cobertura."]="Kliniken: 2\195\1511 Felder f\195\188r Menschen ohne Versorgung.",["Retira autorizacao e cancela obras; nao demole edificios."]="L\195\182scht Zonen und stoppt Bauarbeiten; fertige Geb\195\164ude bleiben.",["pequeno"]="klein",["medio"]="mittel",["grande"]="gro\195\159",["Explore a ilha"]="Insel erkunden",["Elevar terreno"]="Gel\195\164nde anheben",["Baixar terreno"]="Gel\195\164nde senken",["Nivelar terreno"]="Gel\195\164nde einebnen",["Distorcer a costa"]="K\195\188ste verformen",["Remover construcao"]="Bauwerk entfernen",["Zonear bairro"]="Bauzone ausweisen",["Continuar"]="Fortsetzen",["Nova ilha"]="Neue Insel",["Como jogar"]="Spielanleitung",["Ajustes"]="Einstellungen",["Continuar jogando"]="Weiterspielen",["Salvar a ilha"]="Insel speichern",["Diario da ilha"]="Inseltagebuch",["Contemplar a ilha"]="Insel betrachten",["Salvar e ir ao inicio"]="Speichern und zum Titel",["Trocar via"]="Weg wechseln",["Concluir"]="Fertig",["Girar peca"]="Drehen",["Trocar peca"]="Bauwerk wechseln",["Trocar uso"]="Nutzung \195\164ndern",["Pincel"]="Pinsel",["Trocar ferramenta"]="Werkzeug wechseln",["Sons curtos ao navegar e construir."]="Kurze T\195\182ne beim W\195\164hlen und Bauen.",["Reduz ondas, passaros e animacoes."]="Weniger Wellen, V\195\182gel und Animationen.",["Ajusta vegetacao e custo das sombras."]="Passt Pflanzen und Schattendetails an.",["Pixels inteiros nas duas distancias."]="Klare Pixel in beiden Ansichten.",["Escolha um momento do dia."]="W\195\164hle eine Tageszeit.",["Escolha Portugues, English ou Deutsch. A troca e imediata."]="Portugu\195\170s, English oder Deutsch. Sofort wirksam.",["Salva as preferencias neste dispositivo."]="Speichert Optionen auf diesem Ger\195\164t.",["Portugu\195\170s"]="Portugu\195\170s",["English"]="English",["Deutsch"]="Deutsch",["Ilha salva. Pode voltar quando quiser."]="Insel gespeichert. Komm jederzeit wieder.",["Nao foi possivel salvar neste dispositivo."]="Speichern auf diesem Ger\195\164t nicht m\195\182glich.",["MARE"]="MAR\195\137",["Seu mundo, no seu ritmo."]="Deine Welt, dein Tempo.",["SETAS escolher   OK entrar"]="PFEILE w\195\164hlen   OK \195\182ffnen",["MAR ABERTO"]="OFFENES MEER",["DIA %d"]="TAG %d",["Modo livre"]="Freispiel",["Jornada"]="Reise",["Livre"]="Frei",["moedas"]="M\195\188nzen",["moradores"]="Einwohner",["%d / %d"]="%d / %d",["energia"]="Strom",["%d%%"]="%d %%",["felicidade"]="Zufriedenheit",["Nivelar: altura do mar"]="Einebnen: Meeresh\195\182he",["Nivelar: altura %d"]="Einebnen: H\195\182he %d",["SETAS explorar    OK criar    VOLTAR pausa"]="PFEILE erkunden    OK bauen    ZUR\195\156CK Pause",["OK construir  /  Custo: %d  /  VOLTAR opcoes"]="OK bauen  /  Kosten: %d  /  ZUR\195\156CK Optionen",["%s  /  VOLTAR opcoes"]="%s  /  ZUR\195\156CK Optionen",["SETAS tracar    OK terminar    VOLTAR cancelar"]="PFEILE zeichnen    OK fertig    ZUR\195\156CK abbrechen",["OK comecar via    VOLTAR opcoes"]="OK Weg beginnen    ZUR\195\156CK Optionen",["SETAS pintar    OK confirmar zona    VOLTAR cancelar"]="PFEILE malen    OK Zone best\195\164tigen    ZUR\195\156CK abbrechen",["OK comecar zona    VOLTAR escolher uso"]="OK Zone beginnen    ZUR\195\156CK Nutzung w\195\164hlen",["Sem acesso: construcao inativa    OK criar    VOLTAR pausa"]="Ohne Weg: Bau inaktiv    OK bauen    ZUR\195\156CK Pause",["Com acesso    OK criar    VOLTAR pausa"]="Weganschluss vorhanden    OK bauen    ZUR\195\156CK Pause",["%s  /  %d%%"]="%s  /  %d %%",["Autorize o lote inteiro: clinicas precisam de 2x1"]="Weise das ganze Grundst\195\188ck aus: Kliniken brauchen 2\195\1511",["Aguardando uma das quatro equipes de obra"]="Wartet auf eines der vier Bauteams",["Zona autorizada: aguardando ocupacao"]="Zone bereit: wartet auf Einzug",["SETAS puxar    OK soltar    VOLTAR cancelar"]="PFEILE ziehen    OK loslassen    ZUR\195\156CK abbrechen",["SETAS pintar    OK concluir    VOLTAR cancelar"]="PFEILE malen    OK fertig    ZUR\195\156CK abbrechen",["OK remover e recuperar 75%    VOLTAR explorar"]="OK entfernen, 75% zur\195\188ck    ZUR\195\156CK erkunden",["OK segurar    Pincel %s    VOLTAR opcoes"]="OK greifen    Pinsel: %s    ZUR\195\156CK Optionen",["OK copiar altura    Pincel %s    VOLTAR opcoes"]="OK H\195\182he kopieren    Pinsel: %s    ZUR\195\156CK Optionen",["OK comecar    Pincel %s    VOLTAR opcoes"]="OK beginnen    Pinsel: %s    ZUR\195\156CK Optionen",["%+d / dia"]="%+d / Tag",["Sem acesso: ligue uma via ao lado para ativar."]="Ohne Anschluss: Lege zum Aktivieren einen Weg daneben.",["Conquista pronta!"]="Meilenstein erreicht!",["VOLTAR > Diario para receber"]="ZUR\195\156CK > Tagebuch: abholen",["%d%%  /  Diario na pausa"]="%d %%  /  Tagebuch in Pause",["Desfazer disponivel: %d acoes. O gesto inteiro volta."]="R\195\188ckg\195\164ngig: %d. Gilt immer f\195\188r die ganze Geste.",["Nada para desfazer ainda."]="Noch nichts r\195\188ckg\195\164ngig zu machen.",["O que vamos criar?"]="Was wollen wir bauen?",["SETAS escolher    OK usar    VOLTAR explorar"]="PFEILE w\195\164hlen    OK benutzen    ZUR\195\156CK erkunden",["Moldar a ilha"]="Insel formen",["SETAS escolher    OK usar    VOLTAR ferramentas"]="PFEILE w\195\164hlen    OK benutzen    ZUR\195\156CK Werkzeuge",["Crescer em bairros"]="Viertel wachsen lassen",["Cada tracado pode ser desfeito de uma vez."]="Jeder gezeichnete Weg l\195\164sst sich als Ganzes zur\195\188cknehmen.",["OK gira 90 graus e volta para a ilha."]="OK dreht um 90 Grad und kehrt zur Insel zur\195\188ck.",["Escolha outra peca. A ilha fica como esta."]="W\195\164hle ein anderes Bauwerk. Die Insel bleibt unver\195\164ndert.",["Volte a explorar a ilha."]="Erkunde die Insel weiter.",["Pincel: %s"]="Pinsel: %s",["OK muda o tamanho. A terra leva as construcoes junto."]="OK \195\164ndert die Pinselgr\195\182\195\159e. Geb\195\164ude folgen dem Gel\195\164nde.",["Troque entre elevar, baixar, nivelar e distorcer."]="Wechsle zwischen Anheben, Senken, Einebnen und Verformen.",["Escolha o que vai fazer parte da sua ilha."]="W\195\164hle, was zu deiner Insel geh\195\182rt.",["%d  /  %dx%d"]="%d  /  %d\195\151%d",["SELECIONADO"]="AUSWAHL",["%d x %d terrenos"]="Grundfl\195\164che: %d \195\151 %d",["Custo: %d moedas"]="M\195\188nzkosten: %d",["%d moedas / dia"]="M\195\188nzen pro Tag: %d",["ESQUERDA / DIREITA categorias    OK ver construcoes    VOLTAR"]="LINKS / RECHTS Kategorien    OK Bauwerke    ZUR\195\156CK",["SETAS escolher    CIMA categorias    OK colocar    VOLTAR"]="PFEILE w\195\164hlen    OBEN Kategorien    OK platzieren    ZUR\195\156CK",["Um respiro"]="Kurz durchatmen",["Sua ilha fica guardada enquanto voce faz uma pausa."]="Deine Insel wartet, w\195\164hrend du eine Pause machst.",["ILHA %d"]="INSEL %d",["Dia %d  /  Moradores: %d"]="Tag %d  /  Einwohner: %d",["SETAS escolher    OK confirmar    VOLTAR continuar"]="PFEILE w\195\164hlen    OK best\195\164tigen    ZUR\195\156CK weiter",["Deixe a ilha confortavel para voce."]="Richte die Insel so ein, wie es dir gef\195\164llt.",["Som: ligado"]="Ton: an",["Som: desligado"]="Ton: aus",["Movimento: ligado"]="Bewegung: an",["Movimento: reduzido"]="Bewegung: reduziert",["Detalhes: completos"]="Details: voll",["Detalhes: economicos"]="Details: sparsam",["Zoom: %dx"]="Zoom: %d\195\151",["Luz: %s"]="Licht: %s",["Idioma: %s"]="Sprache: %s",["Ciclo natural"]="Tageszyklus",["Manha"]="Morgen",["Golden hour"]="Abendgold",["Noite"]="Nacht",["Manha, por do sol e luzes da noite."]="Morgen, Abendrot und Nachtlichter.",["SETAS escolher    OK alterar    VOLTAR concluir"]="PFEILE w\195\164hlen    OK \195\164ndern    ZUR\195\156CK fertig",["Sua ilha, seu ritmo"]="Deine Insel, dein Tempo",["Setas movem o cursor pelas diagonais da ilha."]="Pfeile bewegen den Cursor entlang der Inseldiagonalen.",["OK abre as ferramentas durante a exploracao."]="Beim Erkunden \195\182ffnet OK die Werkzeuge.",["Voltar cancela gestos ou abre opcoes da peca."]="Zur\195\188ck bricht Gesten ab oder \195\182ffnet Bauoptionen.",["Ao explorar, Voltar abre a pausa e o diario."]="Beim Erkunden \195\182ffnet Zur\195\188ck Pause und Tagebuch.",["Moldar a terra"]="Gel\195\164nde formen",["Elevar e Baixar: OK, setas para pintar, OK."]="Anheben und Senken: OK, mit Pfeilen malen, dann OK.",["Nivelar: OK copia a altura; setas pintam nela."]="Einebnen: OK kopiert die H\195\182he; Pfeile malen auf dieser H\195\182he.",["Distorcer: OK segura; setas puxam; OK solta."]="Verformen: OK greift; Pfeile ziehen; OK l\195\164sst los.",["Casas sobem e descem; vias ganham rampas."]="H\195\164user steigen und sinken; Wege erhalten Rampen.",["Fazer a ilha crescer"]="Die Insel wachsen lassen",["Casas, lojas e servicos precisam de via ao lado."]="H\195\164user, L\195\164den und Dienste brauchen einen Weg daneben.",["Geradores e usinas tambem precisam de acesso."]="Auch Generatoren und Kraftwerke brauchen einen Weg.",["Sem via, a construcao fica inativa."]="Ohne Weg bleibt ein Geb\195\164ude inaktiv.",["Com acesso, energia e servicos atendem a ilha."]="Mit Weganschluss versorgen Strom und Dienste die Insel.",["Experimentar"]="Ausprobieren",["Um dia passa a cada 12 segundos de partida."]="Ein Tag dauert 12 Sekunden Spielzeit.",["Troque o piso de vias pagando a diferenca."]="Wechsle den Wegbelag und zahle nur den Aufpreis.",["Remover devolve 75%; Desfazer recupera tudo."]="Entfernen gibt 75% zur\195\188ck; R\195\188ckg\195\164ngig stellt alles wieder her.",["No modo livre, construa sem limite de moedas."]="Im freien Spiel baust du ohne M\195\188nzlimit.",["Pontes e praias"]="Br\195\188cken und Str\195\164nde",["Pontes ocupam agua ou margens na altura 1."]="Br\195\188cken \195\188berspannen Wasser oder Ufer auf H\195\182he 1.",["Portos e quiosques precisam ficar junto da agua."]="H\195\164fen und Kioske m\195\188ssen direkt am Wasser stehen.",["Rampas retas aceitam trilhas, passeios e ruas."]="Gerade Rampen tragen Pfade, Gehwege und Stra\195\159en.",["Com via: abrigo tem 2 animais; centro vet., 4."]="Mit Weg: Tierheim f\195\188r 2 Tiere; Tierarztzentrum f\195\188r 4.",["GUIA DE BOLSO  /  %d DE %d"]="KURZANLEITUNG  /  %d VON %d",["ESQUERDA / DIREITA  paginas     OK ou VOLTAR  fechar"]="LINKS / RECHTS Seiten    OK oder ZUR\195\156CK schlie\195\159en",["MODO LIVRE  /  Sem limites para experimentar"]="FREIES SPIEL  /  Grenzenlos ausprobieren",["JORNADA  /  Cada conquista abre novas possibilidades"]="REISE  /  Jeder Meilenstein er\195\182ffnet neue M\195\182glichkeiten",["A ilha e toda sua."]="Die Insel geh\195\182rt dir.",["Todas as conquistas foram completadas."]="Alle Meilensteine sind erreicht.",["Continue criando, sem um fim obrigatorio."]="Baue weiter. Ein Ende ist nicht n\195\182tig.",["Recompensa: %d moedas"]="M\195\188nzbonus: %d",["Receber conquista"]="Belohnung abholen",["Continuar explorando"]="Weiter erkunden",["Conquistas: %d / 5"]="Meilensteine: %d / 5",["Animais: %d    Pracas: %d    Lojas: %d"]="Tiere: %d    Pl\195\164tze: %d    L\195\164den: %d",["A CIDADE EM NUMEROS"]="DIE INSEL IN ZAHLEN",["Receita por dia"]="Tageseinnahmen",["Manutencao"]="Unterhalt",["Saldo por dia"]="Tagesbilanz",["Agua / pessoas"]="Wasser / Einwohner",["Saude / pessoas"]="Medizin / Einwohner",["Educacao / pessoas"]="Bildung / Einwohner",["OK receber ou explorar    VOLTAR pausa"]="OK abholen oder erkunden    ZUR\195\156CK Pause",["Escolha a paisagem e o ritmo da partida."]="W\195\164hle Landschaft und Spieltempo.",["Jornada: construir e prosperar"]="Reise: bauen und wachsen",["Modo livre: criar sem custos"]="Freies Spiel: ohne Kosten bauen",["Paisagem: semente %d"]="Landschaft: Startwert %d",["Arquivo: ilha %d"]="Speicherplatz: Insel %d",["Criar esta ilha"]="Diese Insel erschaffen",["Sua paisagem"]="Deine Landschaft",["40 construcoes"]="40 Bauwerke",["5 conquistas"]="5 Meilensteine",["Espaco para 3 ilhas"]="Platz f\195\188r 3 Inseln",["OK escolher    VOLTAR inicio    Confirme a criacao no final"]="OK w\195\164hlen    ZUR\195\156CK Titel    Zum Schluss Erstellung best\195\164tigen",["Substituir esta ilha?"]="Diese Insel ersetzen?",["O arquivo %d ja tem uma ilha salva."]="Auf Speicherplatz %d liegt bereits eine Insel.",["Seu novo mundo vai ocupar este arquivo."]="Deine neue Welt wird diesen Speicherplatz belegen.",["Os outros dois arquivos ficam guardados."]="Die beiden anderen Speicherpl\195\164tze bleiben erhalten.",["Escolher outro arquivo"]="Anderen Platz w\195\164hlen",["Substituir e criar a nova ilha"]="Ersetzen und neue Insel bauen",["SETAS  escolher     OK  confirmar     VOLTAR  cancelar"]="PFEILE w\195\164hlen    OK best\195\164tigen    ZUR\195\156CK abbrechen",["Suas ilhas"]="Deine Inseln",["Tres pequenos mundos, guardados neste dispositivo."]="Drei kleine Welten, auf diesem Ger\195\164t gespeichert.",["Ilha %d"]="Insel %d",["Dia %d  /  Moradores: %d  /  %s"]="Tag %d  /  Einwohner: %d  /  %s",["Arquivo invalido. Escolha outra ilha."]="Ung\195\188ltiger Spielstand. W\195\164hle eine andere Insel.",["Este arquivo esta vazio"]="Dieser Speicherplatz ist leer",["SETAS  escolher     OK  continuar     VOLTAR  inicio"]="PFEILE w\195\164hlen    OK fortsetzen    ZUR\195\156CK Titel",["Bem-vindo a sua ilha! OK abre as ferramentas."]="Willkommen auf deiner Insel! OK \195\182ffnet die Werkzeuge.",["Nenhuma alteracao neste gesto."]="Diese Geste hat nichts ver\195\164ndert.",["Gesto parcial: %s"]="Geste teilweise ausgef\195\188hrt: %s",["Gesto cancelado."]="Geste abgebrochen.",["Via pronta."]="Weg fertig.",["%s: pronta. Ligue uma via ao lado para ativar."]="%s ist fertig. Lege zum Aktivieren einen Weg daneben.",["Zona confirmada. Acompanhe as obras."]="Zone best\195\164tigt. Verfolge die Bauarbeiten.",["Zona removida. Construcoes prontas foram mantidas."]="Zone entfernt. Fertige Geb\195\164ude bleiben erhalten.",["Costa redesenhada."]="K\195\188ste neu geformt.",["Relevo e construcoes ajustados."]="Gel\195\164nde und Geb\195\164ude angepasst.",["Conquista recebida! Sua ilha esta crescendo."]="Belohnung abgeholt! Deine Insel w\195\164chst.",["Este arquivo nao tem uma ilha valida."]="Dieser Speicherplatz enth\195\164lt keine g\195\188ltige Insel.",["%s: obra concluida!"]="%s: Bau abgeschlossen!",["Obra cancelada. Saldo nao gasto devolvido."]="Bau abgebrochen. Restbudget zur\195\188ckgezahlt.",["OK mudar a luz   VOLTAR continuar"]="OK Licht \195\164ndern   ZUR\195\156CK weiter",["Caminhos que acompanham o relevo"]="Wege, die dem Gel\195\164nde folgen",["Passeios e rampas para pedestres"]="Wege und Rampen f\195\188r Fu\195\159g\195\164nger",["Conecta moradias e servicos"]="Verbindet Wohnh\195\164user und Versorgung",["Uma via larga para sua cidade"]="Eine breite Stra\195\159e f\195\188r deine Stadt",["Atravesse canais e margens baixas"]="\195\156berquere Kan\195\164le und flache Ufer",["Conecte duas margens com uma via"]="Verbinde zwei Ufer mit einer Stra\195\159e",["Ligue diferentes alturas da ilha"]="Verbinde verschiedene H\195\182hen der Insel",["+2 de felicidade com acesso"]="+2 Zufriedenheit mit Anschluss",["Balsas: receita e felicidade"]="F\195\164hren: Einnahmen und Zufriedenheit",["Porto: 85 de receita por dia"]="Hafen: 85 Einnahmen pro Tag",["35 de energia para a ilha"]="35 Energie f\195\188r die Insel",["60 de energia limpa"]="60 saubere Energie",["90 de energia limpa"]="90 saubere Energie",["Agua para 150 moradores"]="Wasser f\195\188r 150 Bewohner",["Reciclagem para 150 moradores"]="Recycling f\195\188r 150 Bewohner",["Saude para 100 moradores"]="Gesundheitsversorgung f\195\188r 100 Bewohner",["Educacao para 100 moradores"]="Bildung f\195\188r 100 Bewohner",["Seguranca para 100 moradores"]="Sicherheit f\195\188r 100 Bewohner",["20 de receita por dia"]="20 Einnahmen pro Tag",["+4 de felicidade na ilha"]="+4 Zufriedenheit auf der Insel",["Delimite jardins e recintos"]="Begrenze G\195\164rten und Gehege",["2 animais ao conectar uma via ao lado"]="2 Tiere mit einer Stra\195\159e direkt daneben",["4 animais e saude para 100 moradores; requer via ao lado"]="4 Tiere; medizinische Versorgung f\195\188r 100 Bewohner; Stra\195\159e daneben n\195\182tig",["%d moradores com acesso viario"]="%d Bewohner mit Stra\195\159enanschluss",["%d de receita base por dia com acesso viario"]="%d Grundeinnahmen pro Tag mit Stra\195\159enanschluss",["Cuidados e vida para sua ilha"]="F\195\188rsorge und Leben f\195\188r deine Insel",["Fora dos limites da ilha"]="Au\195\159erhalb der Inselgrenzen",["Faltam moedas. Espere a renda ou use o modo livre."]="Zu wenig M\195\188nzen. Warte auf Einnahmen oder nutze den freien Modus.",["Esta via ja tem esse piso"]="Diese Stra\195\159e hat schon diesen Belag",["Este espaco ja esta ocupado"]="Dieser Platz ist bereits belegt",["Eleve e nivele o terreno primeiro"]="Hebe und ebne zuerst das Gel\195\164nde",["Esta construcao precisa de terreno plano"]="Dieses Geb\195\164ude braucht ebenes Gel\195\164nde",["Use Nivelar para criar uma rampa reta"]="Ebne das Gel\195\164nde f\195\188r eine gerade Rampe",["Pontes atravessam agua ou margens baixas"]="Br\195\188cken f\195\188hren \195\188ber Wasser oder flache Ufer",["Escolha um terreno plano junto da agua"]="W\195\164hle ebenes Gel\195\164nde am Wasser",["Pronto para construir"]="Bereit zum Bauen",["%s: pronto!"]="%s: fertig!",["Nada para remover aqui"]="Hier gibt es nichts zu entfernen",["Removido. Reembolso de 75%."]="Entfernt. 75% erstattet.",["Relevo e fundacoes ajustados"]="Gel\195\164nde und Fundamente angepasst",["Fundo de apoio: +300 moedas para recuperar a ilha."]="Hilfsfonds: +300 M\195\188nzen, damit sich die Insel erholt.",["Um lugar para chamar de seu"]="Ein Ort f\195\188r dich",["Chegue a 20 moradores"]="Erreiche 20 Bewohner",["A ilha funciona"]="Die Insel l\195\164uft",["40 moradores, energia suficiente"]="40 Bewohner, genug Energie",["A vida la fora"]="Drau\195\159en leben",["3 pracas ou mirantes e 2 comercios"]="3 Parks oder Aussichtspunkte und 2 L\195\164den",["Amigos de todas as especies"]="Freunde aller Arten",["Tenha 6 animais e uma clinica"]="Habe 6 Tiere und eine Klinik",["Uma pequena grande ilha"]="Kleine Insel, ganz gro\195\159",["100 moradores e 80% de felicidade"]="100 Bewohner und 80% Zufriedenheit",["Lote reservado"]="Grundst\195\188ck reserviert",["Sem trabalhador: conecte uma moradia"]="Kein Arbeiter: ein Wohnhaus anschlie\195\159en",["Sem rota: reconecte o caminho"]="Keine Route: Weg wieder verbinden",["Terreno invalido: nivele o lote"]="Ung\195\188ltiges Gel\195\164nde: Grundst\195\188ck ebnen",["Sem demanda para este uso"]="Kein Bedarf f\195\188r diese Nutzung",["Faltam moedas para reservar a obra"]="Zu wenig M\195\188nzen f\195\188r die Baureservierung",["Lote sem acesso viario"]="Grundst\195\188ck ohne Stra\195\159enanschluss",["Trabalhador a caminho"]="Arbeiter unterwegs",["Construcao em andamento"]="Bauarbeiten laufen",["Aguarde a pessoa atravessar o lote"]="Warte, bis die Person das Grundst\195\188ck \195\188berquert hat",["Aguarde uma obra terminar"]="Warte, bis ein Bauprojekt fertig ist",["Autorize todo o lote desta construcao"]="Gib das ganze Baugrundst\195\188ck frei",["Obra nao encontrada"]="Bauprojekt nicht gefunden",["Obra cancelada; saldo nao gasto devolvido"]="Bau abgebrochen; ungenutzte M\195\188nzen zur\195\188ckgezahlt",["Uso de zona invalido"]="Ung\195\188ltige Zonennutzung",["Apagar autorizacao sem demolir construcoes"]="Freigabe l\195\182schen, ohne Geb\195\164ude abzurei\195\159en",["Eleve a terra antes de zonear"]="Hebe das Land vor dem Zonieren an",["Clinica: autorize um lote de 2 por 1 com acesso"]="Klinik: 2 mal 1 Felder mit Anschluss freigeben",["Autorizar crescimento com acesso viario"]="Wachstum mit Stra\195\159enanschluss erlauben",["Esta celula ja tem esse uso"]="Dieses Feld hat bereits diese Nutzung",["Lote reservado para uma obra"]="Grundst\195\188ck f\195\188r Bauarbeiten reserviert",["Aguarde a pessoa atravessar antes de construir"]="Warte mit dem Bauen, bis die Person den Weg frei macht",["Ha uma pessoa atravessando esta ponte; aguarde antes de remover"]="Jemand \195\188berquert die Br\195\188cke; warte mit dem Entfernen",["Ha uma pessoa nesta travessia; mantenha o terreno seguro ate ela passar"]="Jemand \195\188berquert diese Stelle; halte das Gel\195\164nde sicher, bis der Weg frei ist",["O ajuste afeta uma pessoa ou seu acesso, inclusive alem do pincel. Aguarde o local ficar livre."]="Die \195\132nderung betrifft eine Person oder ihren Zugang, auch au\195\159erhalb des Pinsels. Warte, bis der Bereich frei ist.",["A ilha progrediu; esta transacao nao pode substituir a simulacao"]="Die Insel ist weitergewachsen; diese Aktion w\195\188rde den Fortschritt ersetzen",["Nada para desfazer"]="Nichts zum R\195\188ckg\195\164ngigmachen",["Uma zona posterior ocupa esta transacao"]="Eine sp\195\164tere Zone \195\188berlagert diese Aktion",["Obras progrediram; desfazer terreno antigo apagaria progresso"]="Der Bau ist fortgeschritten; altes Gel\195\164nde w\195\188rde Fortschritt l\195\182schen",["Faltam moedas para desfazer este reembolso"]="Zu wenig M\195\188nzen, um diese Erstattung r\195\188ckg\195\164ngig zu machen",["Ultima acao desfeita"]="Letzte Aktion r\195\188ckg\195\164ngig gemacht",["Aguarde o transito liberar este espaco"]="Warte, bis der Verkehr diesen Platz freigibt",["Aguarde o veiculo sair desta via"]="Warte, bis das Fahrzeug diese Stra\195\159e verl\195\164sst",["Aguarde a travessia antes de mudar esta costa ou via"]="Warte, bis der Weg frei ist, bevor du K\195\188ste oder Stra\195\159e \195\164nderst",["Aguarde o transito liberar o terreno antes de desfazer"]="Warte vor dem R\195\188ckg\195\164ngigmachen, bis der Verkehr das Gel\195\164nde freigibt"},["catalog"]={{"Trampelpfad","Vias",1,1,8,0,0,0,"terra","Trampelpfad",""},{"Fu\195\159weg","Vias",1,1,16,0,0,0,"pedestres","Fu\195\159weg",""},{"Stra\195\159e","Vias",1,1,25,0,0,0,"rua","Stra\195\159e",""},{"Breite Stra\195\159e","Vias",2,2,70,1,0,0,"avenida","Breite","Stra\195\159e"},{"Holzbr\195\188cke","Vias",1,1,60,0,0,0,"bridge","Holzbr\195\188cke",""},{"Autobr\195\188cke","Vias",2,2,150,1,0,0,"bridge","Autobr\195\188cke",""},{"Treppe","Vias",1,1,30,0,0,0,"steps","Treppe",""},{"Busstopp","Vias",1,1,110,1,0,0,"bus","Busstopp",""},{"F\195\164hrterminal","Vias",3,2,650,6,0,0,"ferry","F\195\164hrterminal",""},{"Frachthafen","Vias",4,3,1200,10,0,0,"port","Frachthafen",""},{"Kleines Haus","Moradia",1,1,90,0,4,0,"house","Kleines Haus",""},{"Haus mit Garten","Moradia",2,1,160,1,8,0,"garden","Haus mit","Garten"},{"Reihenh\195\164user","Moradia",3,1,330,2,18,0,"row","Reihenh\195\164user",""},{"Kleines Wohnhaus","Moradia",1,1,240,1,14,0,"apart","Kleines","Wohnhaus"},{"Wohnblock","Moradia",2,1,480,3,32,0,"apart","Wohnblock",""},{"Wohnturm","Moradia",2,2,1000,6,72,0,"tower","Wohnturm",""},{"Minimarkt","Comercio",1,1,160,2,0,12,"shop","Minimarkt",""},{"B\195\164ckerei und Caf\195\169","Comercio",1,1,180,2,0,14,"cafe","B\195\164ckerei und","Caf\195\169"},{"Tierbedarf","Comercio",1,1,170,2,0,12,"pet","Tierbedarf",""},{"Restaurant","Comercio",2,1,300,3,0,25,"rest","Restaurant",""},{"Markt im Freien","Comercio",4,1,360,2,0,28,"market","Markt im","Freien"},{"Inselhotel","Comercio",2,3,900,7,0,65,"hotel","Inselhotel",""},{"L\195\164den im Gr\195\188nen","Comercio",3,2,650,5,0,48,"mall","L\195\164den im","Gr\195\188nen"},{"Werkstatt","Comercio",3,2,600,5,0,60,"factory","Werkstatt",""},{"Generator","Servicos",2,1,220,7,0,0,"diesel","Generator",""},{"Windrad","Servicos",2,2,700,3,0,0,"wind","Windrad",""},{"Solarpark","Servicos",3,2,950,2,0,0,"solar","Solarpark",""},{"Wasser und Abwasser","Servicos",3,2,650,5,0,0,"water","Wasser und","Abwasser"},{"Recycling","Servicos",3,2,580,5,0,0,"waste","Recycling",""},{"Klinik","Servicos",2,1,420,4,0,0,"clinic","Klinik",""},{"Schule","Servicos",3,2,500,4,0,0,"school","Schule",""},{"Feuerwache","Servicos",2,2,430,4,0,0,"fire","Feuerwache",""},{"Polizeiwache","Servicos",2,2,400,3,0,0,"police","Polizeiwache",""},{"Rathaus","Servicos",2,2,500,3,0,0,"admin","Rathaus",""},{"Park und Spielplatz","Natureza",2,2,100,1,0,0,"park","Park und","Spielplatz"},{"Aussicht","Natureza",2,1,140,1,0,4,"lookout","Aussicht",""},{"Strandkiosk","Natureza",1,1,120,1,0,8,"kiosk","Strandkiosk",""},{"Zaun und Tor","Natureza",1,1,15,0,0,0,"fence","Zaun und Tor",""},{"Tierheim","Natureza",2,2,320,3,0,16,"shelter","Tierheim",""},{"Tierklinik","Natureza",3,2,650,5,0,32,"vet","Tierklinik",""}}}}
end)()
local I18n=(function()
local I = {}
local locale, active = 'pt', LocaleData.pt
local capitals = {['\195\161']='\195\129',['\195\160']='\195\128',['\195\162']='\195\130',['\195\163']='\195\131',['\195\164']='\195\132',['\195\169']='\195\137',['\195\170']='\195\138',['\195\173']='\195\141',['\195\179']='\195\147',['\195\180']='\195\148',['\195\181']='\195\149',['\195\182']='\195\150',['\195\186']='\195\154',['\195\188']='\195\156',['\195\167']='\195\135',['\195\159']='SS'}

function I.select(code)
    active = assert(LocaleData[code], 'unknown locale: ' .. code)
    locale = code
end

function I.locale()
    return locale
end

function I.t(key)
    return (assert(active.messages[key], 'missing translation: ' .. locale .. ': ' .. key))
end

function I.f(key, ...)
    return string.format(I.t(key), ...)
end

function I.catalog(id)
    return (assert(active.catalog[id], 'unknown building: ' .. id))
end

function I.upper(value)
    return (string.upper(value):gsub('[\194-\244][\128-\191]*', capitals))
end

return I

end)()
local Casters={}
local Activities=(function()
return {{["id"]="walk",["frames"]=8,["frame_ms"]=110,["kind"]="baseline",["buildings"]={},["anchor"]="door",["loop"]=true},{["id"]="wait",["frames"]=4,["frame_ms"]=360,["kind"]="baseline",["buildings"]={},["anchor"]="door",["loop"]=true},{["id"]="enter",["frames"]=6,["frame_ms"]=130,["kind"]="baseline",["buildings"]={},["anchor"]="door",["loop"]=false},{["id"]="exit",["frames"]=6,["frame_ms"]=130,["kind"]="baseline",["buildings"]={},["anchor"]="door",["loop"]=false},{["id"]="survey",["frames"]=8,["frame_ms"]=190,["kind"]="construction",["buildings"]={5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40},["anchor"]="work_edge",["loop"]=false},{["id"]="mark",["frames"]=6,["frame_ms"]=170,["kind"]="construction",["buildings"]={5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40},["anchor"]="work_edge",["loop"]=false},{["id"]="carry_timber",["frames"]=8,["frame_ms"]=150,["kind"]="construction",["buildings"]={5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40},["anchor"]="work_surface",["loop"]=false},{["id"]="stack_bricks",["frames"]=8,["frame_ms"]=170,["kind"]="construction",["buildings"]={5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40},["anchor"]="work_edge",["loop"]=false},{["id"]="mix_mortar",["frames"]=8,["frame_ms"]=140,["kind"]="construction",["buildings"]={5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40},["anchor"]="work_edge",["loop"]=true},{["id"]="lay_bricks",["frames"]=8,["frame_ms"]=180,["kind"]="construction",["buildings"]={5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40},["anchor"]="work_edge",["loop"]=false},{["id"]="hammer",["frames"]=8,["frame_ms"]=110,["kind"]="construction",["buildings"]={5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40},["anchor"]="work_surface",["loop"]=true},{["id"]="saw",["frames"]=8,["frame_ms"]=120,["kind"]="construction",["buildings"]={5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40},["anchor"]="work_surface",["loop"]=true},{["id"]="paint",["frames"]=8,["frame_ms"]=150,["kind"]="construction",["buildings"]={5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40},["anchor"]="work_surface",["loop"]=true},{["id"]="inspect_work",["frames"]=8,["frame_ms"]=210,["kind"]="construction",["buildings"]={5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40},["anchor"]="work_surface",["loop"]=false},{["id"]="unlock_door",["frames"]=6,["frame_ms"]=160,["kind"]="resident",["buildings"]={9,10,11,12,13,14,15,16,17,18,19,20,22,23,24,25,28,29,30,31,32,33,34,37,39,40},["anchor"]="door",["loop"]=false},{["id"]="knock_door",["frames"]=8,["frame_ms"]=130,["kind"]="resident",["buildings"]={11,12,13,14,15,16,17,18,19,20,22,23,24,30,31,32,33,34,37,39,40},["anchor"]="door",["loop"]=false},{["id"]="greet_neighbor",["frames"]=8,["frame_ms"]=160,["kind"]="resident",["buildings"]={8,9,11,12,13,14,15,16,17,18,19,20,21,22,23,24,30,31,32,33,34,35,36,37,39,40},["anchor"]="front",["loop"]=false},{["id"]="read_book",["frames"]=8,["frame_ms"]=260,["kind"]="resident",["buildings"]={8,35},["anchor"]="bench",["loop"]=true},{["id"]="drink_mug",["frames"]=8,["frame_ms"]=190,["kind"]="resident",["buildings"]={18,20,22,37},["anchor"]="front",["loop"]=true},{["id"]="water_planter",["frames"]=8,["frame_ms"]=160,["kind"]="resident",["buildings"]={11,12,13,17,18,20,22,23,31,35,37,39,40},["anchor"]="garden",["loop"]=true},{["id"]="sweep_steps",["frames"]=8,["frame_ms"]=140,["kind"]="resident",["buildings"]={11,12,13,14,15,16,17,18,19,20,22,23,30,31,34,37,39,40},["anchor"]="door",["loop"]=true},{["id"]="carry_groceries",["frames"]=8,["frame_ms"]=170,["kind"]="resident",["buildings"]={11,12,13,14,15,16,17,21,23},["anchor"]="front",["loop"]=false},{["id"]="browse_stall",["frames"]=8,["frame_ms"]=230,["kind"]="resident",["buildings"]={21},["anchor"]="counter",["loop"]=true},{["id"]="choose_produce",["frames"]=8,["frame_ms"]=170,["kind"]="resident",["buildings"]={21},["anchor"]="counter",["loop"]=false},{["id"]="pay_vendor",["frames"]=8,["frame_ms"]=160,["kind"]="resident",["buildings"]={21},["anchor"]="counter",["loop"]=false},{["id"]="serve_coffee",["frames"]=8,["frame_ms"]=170,["kind"]="resident",["buildings"]={18,20,22,37},["anchor"]="front",["loop"]=false},{["id"]="bake_bread",["frames"]=8,["frame_ms"]=180,["kind"]="resident",["buildings"]={18},["anchor"]="front",["loop"]=true},{["id"]="cook_stir",["frames"]=8,["frame_ms"]=140,["kind"]="resident",["buildings"]={20,37},["anchor"]="front",["loop"]=true},{["id"]="arrange_flowers",["frames"]=8,["frame_ms"]=200,["kind"]="resident",["buildings"]={12,21,23,35},["anchor"]="garden",["loop"]=true},{["id"]="repair_bike",["frames"]=8,["frame_ms"]=160,["kind"]="resident",["buildings"]={24},["anchor"]="yard",["loop"]=true},{["id"]="load_crate",["frames"]=8,["frame_ms"]=170,["kind"]="resident",["buildings"]={10,24,29},["anchor"]="yard",["loop"]=false},{["id"]="check_delivery",["frames"]=8,["frame_ms"]=210,["kind"]="resident",["buildings"]={9,10,17,18,19,20,22,23,24,30,31,34,40},["anchor"]="front",["loop"]=false},{["id"]="read_notice",["frames"]=8,["frame_ms"]=260,["kind"]="resident",["buildings"]={8,17,18,19,20},["anchor"]="front",["loop"]=false},{["id"]="check_meter",["frames"]=8,["frame_ms"]=190,["kind"]="resident",["buildings"]={25,26,27,28},["anchor"]="yard",["loop"]=true},{["id"]="sort_recycling",["frames"]=8,["frame_ms"]=160,["kind"]="resident",["buildings"]={29},["anchor"]="yard",["loop"]=true},{["id"]="water_sample",["frames"]=8,["frame_ms"]=200,["kind"]="resident",["buildings"]={9,10,37},["anchor"]="shore",["loop"]=false},{["id"]="examine_chart",["frames"]=8,["frame_ms"]=240,["kind"]="resident",["buildings"]={9,10,28,30,33,34,40},["anchor"]="front",["loop"]=true},{["id"]="study_book",["frames"]=8,["frame_ms"]=250,["kind"]="resident",["buildings"]={31},["anchor"]="front",["loop"]=true},{["id"]="teach_board",["frames"]=8,["frame_ms"]=190,["kind"]="resident",["buildings"]={31},["anchor"]="yard",["loop"]=true},{["id"]="radio_call",["frames"]=8,["frame_ms"]=180,["kind"]="resident",["buildings"]={9,10,32,33},["anchor"]="front",["loop"]=false},{["id"]="polish_equipment",["frames"]=8,["frame_ms"]=150,["kind"]="resident",["buildings"]={24,30,32,40},["anchor"]="front",["loop"]=true},{["id"]="file_papers",["frames"]=8,["frame_ms"]=190,["kind"]="resident",["buildings"]={30,31,33,34,40},["anchor"]="front",["loop"]=false},{["id"]="sit_bench",["frames"]=8,["frame_ms"]=290,["kind"]="resident",["buildings"]={8,35},["anchor"]="bench",["loop"]=true},{["id"]="eat_snack",["frames"]=8,["frame_ms"]=200,["kind"]="resident",["buildings"]={8,35},["anchor"]="bench",["loop"]=true},{["id"]="feed_birds",["frames"]=8,["frame_ms"]=170,["kind"]="resident",["buildings"]={35},["anchor"]="yard",["loop"]=true},{["id"]="smell_flower",["frames"]=8,["frame_ms"]=220,["kind"]="resident",["buildings"]={11,12,13,21,22,23,35,37},["anchor"]="garden",["loop"]=true},{["id"]="take_photo",["frames"]=8,["frame_ms"]=190,["kind"]="resident",["buildings"]={36},["anchor"]="lookout",["loop"]=false},{["id"]="look_out",["frames"]=8,["frame_ms"]=320,["kind"]="resident",["buildings"]={36},["anchor"]="lookout",["loop"]=true},{["id"]="stretch",["frames"]=8,["frame_ms"]=210,["kind"]="resident",["buildings"]={12,31,35},["anchor"]="yard",["loop"]=true},{["id"]="exercise",["frames"]=8,["frame_ms"]=140,["kind"]="resident",["buildings"]={31,35},["anchor"]="yard",["loop"]=true},{["id"]="play_ball",["frames"]=8,["frame_ms"]=120,["kind"]="resident",["buildings"]={31,35},["anchor"]="yard",["loop"]=true},{["id"]="hopscotch",["frames"]=8,["frame_ms"]=160,["kind"]="resident",["buildings"]={31,35},["anchor"]="yard",["loop"]=true},{["id"]="pet_animal",["frames"]=8,["frame_ms"]=180,["kind"]="resident",["buildings"]={39,40},["anchor"]="yard",["loop"]=true},{["id"]="feed_animal",["frames"]=8,["frame_ms"]=190,["kind"]="resident",["buildings"]={39,40},["anchor"]="yard",["loop"]=true}}

end)()
local Appearance=(function()
local Appearance = {}
local floor = math.floor
local function next_value(state, range)
    state = state * 48271 % 2147483647
    return state, state % range
end

function Appearance.make(seed, id, role)
    local state = (floor(seed) % 2147483646 + floor(id) % 2147483646 * 104729) % 2147483646 + 1
    local skin, shirt, hair, clothing, detail
    state, skin = next_value(state, 8)
    state, shirt = next_value(state, 8)
    state, hair = next_value(state, 8)
    state, clothing = next_value(state, 1000)
    state, detail = next_value(state, 1000)
    local outfit
    if role == 'worker' then outfit = 1
    elseif clothing < 440 then outfit = 0
    elseif clothing < 640 then outfit = 4
    elseif clothing < 760 then outfit = 5
    elseif clothing < 880 then outfit = 6
    elseif clothing < 960 then outfit = 7
    elseif clothing < 990 then outfit = 2
    else outfit = 3 end
    local accessory = 0
    if detail >= 997 then accessory = 1
    elseif detail >= 991 then accessory = 7
    elseif detail >= 976 then accessory = 6
    elseif detail >= 955 then accessory = 5
    elseif detail >= 925 then accessory = 4
    elseif detail >= 870 then accessory = 3
    elseif detail >= 720 then accessory = 2 end
    if outfit == 1 or outfit == 2 or outfit == 3 then
        if accessory ~= 2 and not (outfit == 1 and accessory == 1) then accessory = 0 end
    end
    return skin + shirt * 8 + hair * 64 + outfit * 512 + accessory * 4096
end

return Appearance

end)()
local InteractionAnchors=(function()
local I={}
local floor,abs=math.floor,math.abs
local N=24
local models={}
local function point(u,v,z) return {u,v,z or 0} end
local function route(side,slot,...)
    return {side=side,slot=slot,points={...}}
end
local function south(u,m,z,...)
    return route(1,floor(u),point(u,m,z),...)
end
local function location(id,name,position,facing,contact,interior,routes,water)
    local anchors=models[id].anchors
    local entries=anchors[name]
    if not entries then entries={};anchors[name]=entries end
    entries[#entries+1]={position=position,facing=facing,contact=contact,interior=interior,routes=routes,water=water}
end
local sizes={{1,1},{1,1},{1,1},{2,2},{1,1},{2,2},{1,1},{1,1},{3,2},{4,3},{1,1},{2,1},{3,1},{1,1},{2,1},{2,2},{1,1},{1,1},{1,1},{2,1},{4,1},{2,3},{3,2},{3,2},{2,1},{2,2},{3,2},{3,2},{3,2},{2,1},{3,2},{2,2},{2,2},{2,2},{2,2},{2,1},{1,1},{1,1},{2,2},{3,2}}
for id=1,#sizes do models[id]={n=sizes[id][1],m=sizes[id][2],anchors={}} end
local function entrance(id,u,facade,stand,ground,threshold,depth,routes)
    local position=point(u,stand,ground)
    location(id,'door',position,3,point(u,facade,threshold),point(u,facade-depth,1),routes)
    location(id,'front',position,1,position,nil,routes)
end
local function planter(id,u,v,z,stand_u,stand_v,routes,facing)
    location(id,'garden',point(stand_u,stand_v,z),facing or 0,point(u,v,9),nil,routes)
end
local function corner_planter(id)
    local model=models[id];local u,v=model.n-.13,model.m-.12
    planter(id,u,v,0,u-.21875,v,{south(u-.21875,model.m,0)},0)
end

location(8,'front',point(.64,.91,1),0,point(.86,.76,23),nil,{south(.5,1,1,point(.5,.91,1))})
location(8,'bench',point(.45,.31,3),1,point(.45,.31,7),nil,{south(.45,1,1,point(.45,.61,1),point(.45,.4,1))})

local ferry_entry={south(.75,2,1,point(.75,1.4,1),point(.36,1.4,1)),route(2,1,point(0,1.4,1),point(.36,1.4,1))}
entrance(9,.36,1.12,1.4,1,1,.28,ferry_entry)
models[9].anchors.door[1].position=point(.36,1.27625,1)
location(9,'bench',point(2.22,.295,3),1,point(2.22,.295,7),nil,{route(0,0,point(3,.89,1),point(2.22,.89,1),point(2.22,.39,1))})
location(9,'shore',point(.75,1.88,1),1,point(.75,1.97,1),nil,{route(2,1,point(0,1.4,1),point(.75,1.4,1)),south(1.15,2,1,point(1.15,1.9,1),point(.75,1.9,1))},{side=1,slot=0})
location(9,'shore',point(.12,1.44,1),2,point(.02,1.44,1),nil,{south(.75,2,1,point(.75,1.44,1))},{side=2,slot=1})
location(9,'shore',point(2.86,.95,1),0,point(2.98,.95,1),nil,{route(2,1,point(0,1.24,1),point(1.77,1.24,1),point(1.77,.95,1)),south(.75,2,1,point(.75,1.24,1),point(1.77,1.24,1),point(1.77,.95,1))},{side=0,slot=0})

entrance(10,.36,2.81,2.96,1,1,.26,{south(.36,3,1)})
location(10,'yard',point(1.51875,1.61,1),2,point(1.3,1.61,8),nil,{south(2.55,3,1,point(2.55,1.96,1),point(1.51875,1.96,1))})
location(10,'shore',point(3.72,2.26,1),0,point(3.97,2.26,1),nil,{south(2.55,3,1,point(2.55,2.26,1))},{side=0,slot=2})
location(10,'shore',point(2.5,2.87,1),1,point(2.5,2.97,1),nil,{route(0,2,point(4,2.3,1),point(2.5,2.3,1))},{side=1,slot=2})
location(10,'shore',point(.1,2.04,1),2,point(.03,2.04,1),nil,{south(1.6,3,1,point(1.6,2.04,1))},{side=2,slot=2})

for _,id in ipairs({11,12}) do
    entrance(id,.3,.8,.94,1,2,.28,{south(.3,1,1)})
end
corner_planter(11)
planter(12,1.4,.75125,0,1.4,.97,{south(1.4,1,0),route(0,0,point(2,.61,0),point(2,1,0),point(1.4,1,0))},3)
location(12,'yard',point(1.72,.6,.4),0,point(1.8,.6,.4),nil,{route(0,0,point(2,.61,0),point(1.85,.61,.4))})
for k=0,2 do
    entrance(13,k+.26,.75,.93,1,2,.27,{south(k+.27,1,1,point(k+.27,.93,1))})
    planter(13,k+.69,.88,0,k+.47125,.88,{south(k+.47125,1,0)},0)
end
for _,id in ipairs({14,15}) do
    entrance(id,.3,.8,.94,0,1,.28,{south(.3,1,0)})
    corner_planter(id)
end
entrance(16,.3,1.6,1.79,0,1,.3,{south(.3,2,0)})
corner_planter(16)

for _,id in ipairs({17,18,19,20}) do
    entrance(id,.3,.78,.94,0,1,.27,{south(.3,1,0)})
    models[id].anchors.front={}
    location(id,'front',point(.33,.935,0),2,point(.135,.875,7),nil,{south(.33,1,0)})
    corner_planter(id)
end
models[20].anchors.front={}
location(20,'front',point(.6,.935,0),2,point(.6,.935,0),nil,{south(.6,1,0)})
for k=0,3 do
    location(21,'counter',point(k+.49,.85625,0),3,point(k+.49,.7,12),nil,{south(k+.49,1,0)})
    location(21,'front',point(k+.49,.94,0),1,point(k+.49,.94,0),nil,{south(k+.49,1,0)})
end
corner_planter(21)

local hotel_entry={route(2,1,point(0,1.76,0)),route(0,1,point(2,1.76,0),point(1.72,1.76,0))}
entrance(22,.3,1.6,1.76,0,1,.3,hotel_entry)
planter(22,.45,2.8,0,.66875,2.8,{south(.66875,3,0)},2)
location(22,'yard',point(1.44,2.1,0),0,point(1.65,2.1,0),nil,{route(0,2,point(2,2.3,0),point(1.44,2.3,0))})
for _,id in ipairs({23,24,33,34,40}) do
    entrance(id,.3,1.25,1.44,0,1,.3,{south(.3,2,0)})
    corner_planter(id)
    location(id,'yard',point(1.55,1.69,0),0,point(1.76875,1.69,0),nil,{south(1.55,2,0)})
end
entrance(25,.3,.78,.94,0,1,.27,{south(.3,1,0)})
location(25,'yard',point(1.26,.94,0),3,point(1.26,.78,6),nil,{south(1.26,1,0)})
corner_planter(25)
location(26,'yard',point(1.36875,1,0),2,point(1.15,1,4),nil,{route(0,1,point(2,1.4,0),point(1.36875,1.4,0)),south(1.4,2,0,point(1.4,1,0))})
location(27,'yard',point(2.82,1.4,0),2,point(2.7,1.4,10),nil,{route(0,1,point(3,1.4,0)),south(2.82,2,0)})

entrance(28,.3,1.25,1.3,0,1,.27,{route(2,1,point(0,1.3,0),point(.18,1.3,0))})
models[28].anchors.front={}
location(28,'front',point(1.37,1.65,0),3,point(1.37,1.25,7),nil,{south(1.37,2,0)})
location(28,'yard',point(1.33875,1.62,0),2,point(1.12,1.62,8),nil,{south(1.33875,2,0)})
corner_planter(28)
entrance(29,.3,1.25,1.35,0,1,.27,{route(2,1,point(0,1.35,0)),south(.975,2,0,point(.975,1.35,0))})
location(29,'yard',point(.975,1.65,0),2,point(.85,1.65,8),nil,{south(.975,2,0)})
corner_planter(29)
entrance(30,.3,.78,.94,0,1,.27,{south(.3,1,0)})
corner_planter(30)
entrance(31,.3,1.25,1.4,0,1,.28,{south(.3,2,0,point(.3,1.85,1),point(.3,1.45,1))})
models[31].anchors.front={}
location(31,'front',point(.62,1.63,1),1,point(.62,1.63,1),nil,{south(.62,2,0,point(.62,1.85,1))})
location(31,'yard',point(1.5,1.66,1),0,point(1.71875,1.66,1),nil,{south(1.5,2,0,point(1.5,1.85,1))})
corner_planter(31)
entrance(32,.3,1.25,1.275,0,1,.28,{})
models[32].anchors.front={}
location(32,'front',point(.925,1.61,0),2,point(.8,1.61,11),nil,{south(.925,2,0)})

location(35,'front',point(.96,1.83,1),1,point(.96,1.83,1),nil,{south(.96,2,1)})
location(35,'yard',point(1.16,1.12,1),0,point(1.37875,1.12,1),nil,{south(.96,2,1,point(.96,1.72,1),point(.97,1.29,1))})
location(35,'bench',point(1.475,1.56,3),1,point(1.475,1.56,7),nil,{south(1.475,2,0,point(1.475,1.7,1)),south(.96,2,1,point(.96,1.75,1),point(1.475,1.7,1))})
planter(35,1.83,1.88,0,1.61125,1.88,{south(1.61125,2,0)},0)
location(36,'front',point(.5,.7,10),1,point(.5,.7,10),nil,{south(.5,1,0,point(.5,.9,10))})
location(36,'lookout',point(.52,.36,10),3,point(.52,.15,22),nil,{south(.52,1,0,point(.52,.9,10),point(.52,.6,10))})

entrance(37,.36,.75,.93,0,1,.25,{south(.36,1,0)})
planter(37,.1,.86,0,.31875,.86,{south(.31875,1,0)},2)
location(37,'shore',point(.92,.45,0),0,point(.985,.45,0),nil,{route(3,0,point(.5,0,0),point(.5,.08,0),point(.92,.08,0))},{side=0,slot=0})
location(37,'shore',point(.085,.5,0),2,point(.015,.5,0),nil,{route(3,0,point(.5,0,0),point(.5,.08,0),point(.085,.08,0)),route(0,0,point(1,.4,0),point(.92,.4,0),point(.92,.08,0),point(.085,.08,0))},{side=2,slot=0})
location(37,'shore',point(.63,.09,0),3,point(.63,.015,0),nil,{route(0,0,point(1,.4,0),point(.92,.4,0),point(.92,.09,0)),route(2,0,point(0,.45,0),point(.08,.45,0),point(.08,.09,0))},{side=3,slot=0})
location(37,'shore',point(.55,.92,0),1,point(.55,.985,0),nil,{}, {side=1,slot=0})
location(38,'front',point(.5,.74,0),3,point(.5,.48,6),nil,{south(.5,1,0)})
location(38,'yard',point(.5,.74,0),1,point(.5,.74,0),nil,{south(.5,1,0)})
entrance(39,.28,.9,1.08,0,1,.28,{south(.28,2,0)})
location(39,'yard',point(1.28125,1.22,1),0,point(1.5,1.22,8),nil,{south(1.25,2,0,point(1.25,1.72,1),point(1.25,1.22,1))})
corner_planter(39)

local function rotate(u,v,n,m,r)
    if r==1 then return m-v,u end
    if r==2 then return n-u,m-v end
    if r==3 then return v,n-u end
    return u,v
end
local function boundary_cell(model,rotation,x,y,side,slot)
    local u,v
    if side==0 then u,v=model.n+.5,slot+.5
    elseif side==1 then u,v=slot+.5,model.m+.5
    elseif side==2 then u,v=-.5,slot+.5
    else u,v=slot+.5,-.5 end
    u,v=rotate(u,v,model.n,model.m,rotation)
    u,v=floor(x+u),floor(y+v)
    if u<0 or v<0 or u>=N or v>=N then return nil end
    return v*N+u+1
end
local function world_point(p,model,rotation,x,y,z)
    local u,v=rotate(p[1],p[2],model.n,model.m,rotation)
    return {x=x+u-.5,y=y+v-.5,z=z+p[3]}
end
local function road_access(w,k,z)
    if not k or not w.road[k] or (w.reserved and w.reserved[k]) then return false end
    local navigation=w.navigation
    if navigation and navigation.revision==w.revision and navigation.lots==w.lot_revision then
        return navigation.walk[k] and abs(navigation.height[k]-z)<=8
    end
    if w.base[k]<=0 or (w.mask[k]~=0 and w.mask[k]~=3 and w.mask[k]~=6 and w.mask[k]~=9 and w.mask[k]~=12) then return false end
    local u,v=(k-1)%N,floor((k-1)/N);local vertex=v*(N+1)+u+1
    local height=(w.h[vertex]+w.h[vertex+1]+w.h[vertex+N+1]+w.h[vertex+N+2])*4
    return abs(height-z)<=8
end
local function water_access(w,model,rotation,x,y,water,z)
    if not water then return true end
    local k=boundary_cell(model,rotation,x,y,water.side,water.slot)
    return k~=nil and w.base[k]==0 and w.occ[k]==0 and z==16
end
local function resolve_location(w,model,rotation,x,y,z,entry,access)
    local standing=world_point(entry.position,model,rotation,x,y,z)
    local contact=world_point(entry.contact,model,rotation,x,y,z)
    local interior=entry.interior and world_point(entry.interior,model,rotation,x,y,z) or standing
    local result={x=standing.x,y=standing.y,z=standing.z,facing=(entry.facing+rotation)%4,contact_x=contact.x,contact_y=contact.y,contact_z=contact.z,interior_x=interior.x,interior_y=interior.y,interior_z=interior.z,has_interior=entry.interior~=nil,reachable=access~=nil,approach={},approach_cell=access and access.cell or 0}
    if entry.water then result.water_z=0 end
    if access then
        local points=access.route.points;local approach=result.approach
        for i=1,#points do approach[#approach+1]=world_point(points[i],model,rotation,x,y,z) end
        local last=approach[#approach]
        if not last or last.x~=standing.x or last.y~=standing.y or last.z~=standing.z then approach[#approach+1]=standing end
    end
    return result
end
local function site_job(w,id,rotation,x,y)
    if not w.jobs then return nil end
    for i=1,#w.jobs do
        local job=w.jobs[i]
        if job.building_id==id and job.rotation==rotation and job.x==x and job.y==y then return job end
    end
    return nil
end
local function append_site(points,u,v,z,x,y,base)
    local last=points[#points];local xx,yy,zz=x+u-.5,y+v-.5,base+z
    if not last or last.x~=xx or last.y~=yy or last.z~=zz then points[#points+1]={x=xx,y=yy,z=zz} end
end
local function site_anchor(w,id,rotation,x,y,name,approach_cell)
    local job=site_job(w,id,rotation,x,y)
    local model=models[id];local nx,ny=model.n,model.m
    if rotation%2==1 then nx,ny=ny,nx end
    if not job then
        if name~='work_edge' or x<0 or y<0 or x+nx>N or y+ny>N then return nil end
        local height=w.base[y*N+x+1]
        if not height or height<1 then return nil end
        for v=0,ny-1 do
            for u=0,nx-1 do
                local k=(y+v)*N+x+u+1
                if w.occ[k]~=0 or (w.reserved and w.reserved[k]) or w.base[k]~=height or w.mask[k]~=0 then return nil end
            end
        end
    elseif name=='work_surface' and job.stage=='reserved' then return nil end
    local base=w.base[y*N+x+1]*16
    local tile_x,tile_y,side=x,y,1
    local matched=false
    if approach_cell and approach_cell>=1 and approach_cell<=N*N then
        local ax,ay=(approach_cell-1)%N,floor((approach_cell-1)/N)
        if ax==x-1 and ay>=y and ay<y+ny then tile_y,side,matched=ay,2,true
        elseif ax==x+nx and ay>=y and ay<y+ny then tile_x,tile_y,side,matched=x+nx-1,ay,0,true
        elseif ay==y-1 and ax>=x and ax<x+nx then tile_x,side,matched=ax,3,true
        elseif ay==y+ny and ax>=x and ax<x+nx then tile_x,tile_y,side,matched=ax,y+ny-1,1,true end
    end
    local reachable=matched and road_access(w,approach_cell,base)
    local stage=job and job.stage or 'reserved'
    local points={}
    local u,v,ground,cu,cv,cz,facing
    if name=='work_surface' then
        cu,cv,cz=stage=='frame' and .72 or .69,stage=='frame' and .335 or .555,stage=='frame' and 4 or 3
        u,v,ground,facing=cu+.21875,cv,0,2
        if reachable then
            if side==0 then
                append_site(points,1,.5,0,tile_x,tile_y,base)
                append_site(points,.96,.5,0,tile_x,tile_y,base)
            elseif side==1 then
                append_site(points,.5,1,0,tile_x,tile_y,base)
                append_site(points,.5,.96,0,tile_x,tile_y,base)
                append_site(points,.96,.96,0,tile_x,tile_y,base)
            elseif side==3 then
                append_site(points,.5,0,0,tile_x,tile_y,base)
                append_site(points,.5,.06,0,tile_x,tile_y,base)
                append_site(points,.96,.06,0,tile_x,tile_y,base)
            else
                append_site(points,0,.5,0,tile_x,tile_y,base)
                append_site(points,.06,.5,0,tile_x,tile_y,base)
                local edge=stage=='frame' and .06 or .96
                append_site(points,.06,edge,0,tile_x,tile_y,base)
                append_site(points,.96,edge,0,tile_x,tile_y,base)
            end
            append_site(points,.96,v,0,tile_x,tile_y,base)
        end
    else
        local edge=stage=='reserved' and .86 or .835
        ground,cz=stage=='reserved' and 0 or 2.1,stage=='reserved' and 2 or 4
        local inner=edge-.21875
        if side==0 then u,v,cu,cv,facing=inner,.68,edge,.68,0
        elseif side==1 then u,v,cu,cv,facing=.25,inner,.25,edge,1
        elseif side==2 then u,v,cu,cv,facing=1-inner,.68,1-edge,.68,2
        else u,v,cu,cv,facing=.25,1-inner,.25,1-edge,3 end
        if reachable then
            if side==0 then append_site(points,1,.68,0,tile_x,tile_y,base)
            elseif side==1 then append_site(points,.25,1,0,tile_x,tile_y,base)
            elseif side==2 then append_site(points,0,.68,0,tile_x,tile_y,base)
            else append_site(points,.25,0,0,tile_x,tile_y,base) end
            append_site(points,cu,cv,stage=='reserved' and 0 or 4,tile_x,tile_y,base)
        end
    end
    if reachable then append_site(points,u,v,ground,tile_x,tile_y,base) end
    return {x=tile_x+u-.5,y=tile_y+v-.5,z=base+ground,facing=facing,contact_x=tile_x+cu-.5,contact_y=tile_y+cv-.5,contact_z=base+cz,interior_x=tile_x+u-.5,interior_y=tile_y+v-.5,interior_z=base+ground,has_interior=false,reachable=reachable,approach=points,approach_cell=matched and approach_cell or 0,site_stage=stage,site_cell=tile_y*N+tile_x+1,preview=not job}
end
function I.resolve(w,building_id,rotation,x,y,anchor,approach_cell)
    local model=models[building_id]
    if not model then return nil end
    rotation=rotation%4
    if anchor=='work_edge' or anchor=='work_surface' then return site_anchor(w,building_id,rotation,x,y,anchor,approach_cell) end
    local entries=model.anchors[anchor]
    if not entries or #entries==0 then return nil end
    local z=w.base[y*N+x+1]*16
    local selected=entries[1]
    local access
    if road_access(w,approach_cell,z) then
        for i=1,#entries do
            local entry=entries[i]
            if water_access(w,model,rotation,x,y,entry.water,z) then
                for j=1,#entry.routes do
                    local candidate=entry.routes[j]
                    if boundary_cell(model,rotation,x,y,candidate.side,candidate.slot)==approach_cell then
                        selected=entry;access={route=candidate,cell=approach_cell};break
                    end
                end
            end
            if access then break end
        end
    end
    return resolve_location(w,model,rotation,x,y,z,selected,access)
end
return I

end)()
local ActorRender=(function()
local ActorRender = {}
ActorRender.__index = ActorRender
local floor, min = math.floor, math.min
local outfits = {'casual', 'worker', 'maid', 'bunny', 'dress', 'suit', 'coat', 'overalls'}

local function frames(prefix, action)
    local directions = {}
    for facing = 0, 3 do
        local sequence = {}
        directions[facing] = sequence
        local stem = prefix .. facing .. '_' .. action.id .. '_'
        for frame = 0, action.frames - 1 do sequence[frame] = stem .. frame end
    end
    return directions
end

function ActorRender.new(activities, platform)
    local actions = {}
    for i = 1, #activities do
        local activity = activities[i]
        assert(not actions[activity.id], 'Duplicate actor action')
        assert(activity.frames >= 1 and activity.frames % 1 == 0 and activity.frame_ms > 0, 'Invalid actor sequence')
        local action = {frames = activity.frames, frame_ms = activity.frame_ms, loop = activity.loop, bodies = {}, accessories = {}}
        for outfit = 0, 7 do action.bodies[outfit] = frames('actor_' .. outfits[outfit + 1] .. '_', activity) end
        for accessory = 1, 7 do action.accessories[accessory] = frames('actor_accessory_' .. accessory .. '_', activity) end
        actions[activity.id] = action
    end
    return setmetatable({actions = actions, platform = platform, order = {}}, ActorRender)
end

local function order_actor(order, p, count, x, y, z, key, appearance, accessory)
    p.draw_x, p.draw_y, p.draw_z, p.draw_key = x, y, z, key
    p.draw_palette, p.draw_accessory_key = appearance, accessory
    p.draw_depth = x + y + z * .0625
    local at = count + 1
    while at > 1 do
        local previous = order[at - 1]
        if previous.draw_depth <= p.draw_depth then break end
        order[at], at = previous, at - 1
    end
    order[at] = p
    return count + 1
end

function ActorRender:draw(w, motion)
    local order, count = self.order, 0
    for i = 1, #w.people do
        local p = w.people[i]
        if p.visible then
            local action = self.actions[p.action]
            if not action then error('Unknown actor action: ' .. tostring(p.action)) end
            if p.draw_appearance ~= p.appearance or p.draw_outfit == nil then
                local appearance = assert(p.appearance, 'Person appearance missing')
                p.draw_outfit, p.draw_accessory = floor(appearance / 512) % 8, floor(appearance / 4096) % 8
                p.draw_appearance = appearance
            end
            local frame = motion and floor(p.action_time / action.frame_ms) or 0
            frame = action.loop and frame % action.frames or min(frame, action.frames - 1)
            local key = action.bodies[p.draw_outfit][p.facing][frame]
            local accessory = p.draw_accessory ~= 0 and action.accessories[p.draw_accessory][p.facing][frame] or nil
            count = order_actor(order, p, count, p.x + .5, p.y + .5, p.z, key, p.appearance, accessory)
        end
    end
    local alpha = (w.traffic_state.step + w.life_step) * .02
    for i = 1, #w.traffic do
        local p = w.traffic[i]
        if p.visible then
            local x = p.previous_x + (p.x - p.previous_x) * alpha
            local y = p.previous_y + (p.y - p.previous_y) * alpha
            local z = p.previous_z + (p.z - p.previous_z) * alpha
            count = order_actor(order, p, count, x + .5, y + .5, z, motion and p.sprite or p.still_sprite, nil, nil)
        end
    end
    for i = count + 1, #order do order[i] = nil end
    for i = 1, count do
        local p = order[i]
        self.platform.actor(p.draw_key, p.draw_x, p.draw_y, p.draw_z, p.draw_palette, p.draw_accessory_key)
    end
end

return ActorRender

end)()
local Paths=(function()
local P={}
local floor,abs=math.floor,math.abs
local N=24
local function xy(k) return (k-1)%N,floor((k-1)/N) end
function P.refresh(w)
    local n=w.navigation
    if n and n.revision==w.revision and n.lots==w.lot_revision then return n end
    n=n or {height={},walk={},bridge={},queue={},seen={},parent={},targets={},stamp=0}
    for k=1,576 do
        local a=w.occ[k];local id=a>0 and w.bid[a] or 0
        local bridge=id==5 or id==6
        local mask=w.mask[k]
        n.bridge[k]=bridge
        n.walk[k]=(not w.reserved[k]) and (bridge or ((id==0 or id<=7) and w.base[k]>0 and (mask==0 or mask==3 or mask==6 or mask==9 or mask==12)))
        local x,y=xy(k);local v=y*25+x+1
        n.height[k]=bridge and 16 or (w.h[v]+w.h[v+1]+w.h[v+25]+w.h[v+26])*4
        if bridge then
            if k==a then
                local d=Catalog[id];local nx,ny=d[3],d[4]
                if w.rot[a]%2==1 then nx,ny=ny,nx end
                local deck=1
                for yy=0,ny-1 do for xx=0,nx-1 do deck=math.max(deck,w.top[a+yy*N+xx]) end end
                n.height[k]=deck*16
            else n.height[k]=n.height[a] end
        end
    end
    n.revision=w.revision;n.lots=w.lot_revision;n.interactions={};w.navigation=n
    return n
end
function P.edge(w,a,b)
    local n=P.refresh(w)
    if not n.walk[a] or not n.walk[b] then return false end
    local ax,ay=xy(a);local bx,by=xy(b)
    if abs(ax-bx)+abs(ay-by)~=1 then return false end
    if n.bridge[a] or n.bridge[b] then
        if n.bridge[a] and n.bridge[b] then return n.height[a]==n.height[b] end
        local dry=n.bridge[a] and b or a;local deck=n.bridge[a] and n.height[a] or n.height[b]
        local x,y=xy(dry);local v=y*25+x+1
        if ax<bx then
            if dry==a then v=v+1 end
            return w.h[v]*16==deck and w.h[v+25]*16==deck
        elseif ax>bx then
            if dry==b then v=v+1 end
            return w.h[v]*16==deck and w.h[v+25]*16==deck
        elseif ay<by then
            if dry==a then v=v+25 end
            return w.h[v]*16==deck and w.h[v+1]*16==deck
        else
            if dry==b then v=v+25 end
            return w.h[v]*16==deck and w.h[v+1]*16==deck
        end
    end
    return abs(n.height[a]-n.height[b])<=16
end
function P.doors(w,id,x,y,r,W,out)
    local n=P.refresh(w);local nx,ny=W.footprint(id,r);local count=0
    for v=-1,ny do
        for u=-1,nx do
            if (u>=0 and u<nx and (v==-1 or v==ny)) or (v>=0 and v<ny and (u==-1 or u==nx)) then
                local xx,yy=x+u,y+v
                if xx>=0 and yy>=0 and xx<N and yy<N then
                    local k=yy*N+xx+1
                    if w.road[k] and n.walk[k] and abs(n.height[k]-w.base[y*N+x+1]*16)<=8 then count=count+1;out[count]=k end
                end
            end
        end
    end
    for i=count+1,#out do out[i]=nil end
    return count
end
local function interaction(w,id,x,y,r,W,Anchors,anchor)
    local n=P.refresh(w);local key=((y*N+x)*64+id)*4+r
    local site=n.interactions[key]
    if not site then site={};n.interactions[key]=site end
    local stage
    if anchor=='work_edge' or anchor=='work_surface' then
        stage='reserved'
        for i=1,#w.jobs do
            local j=w.jobs[i]
            if j.building_id==id and j.rotation==r and j.x==x and j.y==y then stage=j.stage;break end
        end
    end
    local entry=site[anchor]
    if not entry or entry.stage~=stage then
        entry={cells={},anchors={},stage=stage};site[anchor]=entry
        P.doors(w,id,x,y,r,W,entry.cells)
        local count=0
        for i=1,#entry.cells do
            local cell=entry.cells[i];local point=Anchors.resolve(w,id,r,x,y,anchor,cell)
            if point and point.reachable then count=count+1;entry.cells[count]=cell;entry.anchors[cell]=point end
        end
        for i=count+1,#entry.cells do entry.cells[i]=nil end
    end
    return entry
end
function P.approaches(w,id,x,y,r,W,Anchors,anchor,out)
    local entry=interaction(w,id,x,y,r,W,Anchors,anchor)
    for i=1,#entry.cells do out[i]=entry.cells[i] end
    for i=#entry.cells+1,#out do out[i]=nil end
    return #entry.cells
end
function P.anchor(w,id,x,y,r,W,Anchors,anchor,cell)
    return interaction(w,id,x,y,r,W,Anchors,anchor).anchors[cell]
end
function P.route(w,start,targets)
    local n=P.refresh(w)
    n.stamp=n.stamp+1;local stamp=n.stamp;local queue,parent,seen=n.queue,n.parent,n.seen
    local first,last=1,0
    local targets_seen=n.targets
    for i=1,#targets do targets_seen[targets[i]]=stamp end
    if type(start)=='table' then
        for i=1,#start do local k=start[i]
            if n.walk[k] and seen[k]~=stamp then last=last+1;queue[last]=k;seen[k]=stamp;parent[k]=0 end
        end
    elseif n.walk[start] then last=1;queue[1]=start;seen[start]=stamp;parent[start]=0 end
    while first<=last do
        local k=queue[first];first=first+1
        if targets_seen[k]==stamp then
            local path={};local p=k
            while parent[p]~=0 do path[#path+1]=p;p=parent[p] end
            for a=1,floor(#path/2) do local b=#path-a+1;path[a],path[b]=path[b],path[a] end
            return path,k,p
        end
        local x,y=xy(k)
        for d=1,4 do
            local b=d==1 and k+1 or d==2 and k+N or d==3 and k-1 or k-N
            local inside=d==1 and x<N-1 or d==2 and y<N-1 or d==3 and x>0 or d==4 and y>0
            if inside and seen[b]~=stamp and P.edge(w,k,b) then seen[b]=stamp;parent[b]=k;last=last+1;queue[last]=b end
        end
    end
    return nil
end
return P

end)()
local Life=(function()
local L={}
local floor,min,max,abs,sqrt=math.floor,math.min,math.max,math.abs,math.sqrt
local buildings={11,17,30}
local status_codes={reserved=1,worker=2,route=3,terrain=4,demand=5,resources=6,access=7,walking=8,working=9}
local statuses={'reserved','worker','route','terrain','demand','resources','access','walking','working'}
local legacy_states={'walk','wait','work','arrive','leave'}
local states={'walk','wait','work','approach','enter','interior','exit','activity','depart'}
local anchor_names={'door','front','yard','counter','bench','lookout','shore','garden','work_edge','work_surface'}
local construction={'survey','mark','mix_mortar','stack_bricks','lay_bricks','carry_timber','saw','hammer','paint','inspect_work'}
local stages={'reserved','foundation','frame'}
local function index(t,value) for i=1,#t do if t[i]==value then return i end end end
local function copy(t) local r={};for k,v in pairs(t) do r[k]=v end;return r end
function L.install(W,Catalog,P,Activities,Appearance,InteractionAnchors)
    local actions,visits,work_actions={},{},{}
    for i=1,#Activities do
        local a=Activities[i];actions[a.id]=a
        if a.kind=='resident' then
            for j=1,#a.buildings do
                local id=a.buildings[j];visits[id]=visits[id] or {};visits[id][#visits[id]+1]=a
            end
        end
    end
    local first,last=0,0
    for i=1,#construction do
        local a=assert(actions[construction[i]],'Missing construction activity')
        if i<=5 then first=first+a.frames*a.frame_ms else last=last+a.frames*a.frame_ms end
    end
    local stop=0
    for i=1,#construction do
        local a=actions[construction[i]]
        stop=stop+a.frames*a.frame_ms*(i<=5 and 4000/first or 8000/last)
        work_actions[i]={activity=a,stop=i==5 and 4000 or i==#construction and 12000 or stop}
    end
    local function work_action(j)
        for i=1,#work_actions do
            if (j.work_ms or 0)<work_actions[i].stop then return work_actions[i].activity,work_actions[i].stop,i==1 and 0 or work_actions[i-1].stop end
        end
        return work_actions[#work_actions].activity,12000,work_actions[#work_actions-1].stop
    end
    local function action(p,id)
        if p.action~=id then p.action=id;p.action_time=0 end
    end
    local function duration(id)
        local a=actions[id];return a.frames*a.frame_ms*(a.loop and 2 or 1)
    end
    W.zone_buildings=buildings
    W.job_status={reserved='Lote reservado',worker='Sem trabalhador: conecte uma moradia',route='Sem rota: reconecte o caminho',terrain='Terreno invalido: nivele o lote',demand='Sem demanda para este uso',resources='Faltam moedas para reservar a obra',access='Lote sem acesso viario',walking='Trabalhador a caminho',working='Construcao em andamento',occupied='Aguarde a pessoa atravessar o lote',capacity='Aguarde uma obra terminar',footprint='Autorize todo o lote desta construcao'}
    local function init(w)
        w.zones={};w.reserved={};w.zone_status={};w.jobs={};w.people={};w.events={}
        for k=1,576 do w.zones[k]=0 end
        w.life_time=0;w.life_accumulator=0;w.life_step=0;w.life_epoch=0;w.next_job_id=1;w.next_person_id=1;w.lot_revision=0;w.trip_clock=0;w.schedule_cursor=1;w.completed_lots=0
        w.life_doors={};w.life_homes={};w.life_targets={};w.life_owners={};w.life_candidate={};w.life_places={};w.life_place_revision=-1
        return w
    end
    local old_new=W.new
    W.new=function(seed,free) return init(old_new(seed,free)) end
    local function reindex(w)
        for k=1,576 do w.reserved[k]=nil end
        for i=1,#w.jobs do
            local j=w.jobs[i];local nx,ny=W.footprint(j.building_id,j.rotation)
            for v=0,ny-1 do for u=0,nx-1 do w.reserved[W.cell(j.x+u,j.y+v)]=j.id end end
        end
        w.lot_revision=w.lot_revision+1
    end
    local function event(w,kind,j)
        if #w.events==8 then table.remove(w.events,1) end
        w.events[#w.events+1]={kind=kind,building_id=j.building_id,x=j.x,y=j.y}
    end
    function W.take_event(w) if #w.events>0 then return table.remove(w.events,1) end end
    local function person(w,id) for i=1,#w.people do if w.people[i].id==id then return w.people[i],i end end end
    local function job(w,id) for i=1,#w.jobs do if w.jobs[i].id==id then return w.jobs[i],i end end end
    local function return_home(p)
        p.job_id=0;p.phase=2;p.path=nil;p.path_index=1;p.pause=0;p.destination=0;p.destination_id=0;p.activity='none';p.home_route_failed=nil
        if p.interaction then
            p.state=p.local_cursor>p.interaction.stand and 'exit' or 'depart';p.visible=true
            action(p,p.state=='exit' and 'exit' or 'walk')
        else p.state='wait';action(p,'wait') end
    end
    local function cancel(w,id,erase)
        local j,i=job(w,id)
        if not j then return false,I18n.t('Obra nao encontrada') end
        local nx,ny=W.footprint(j.building_id,j.rotation);local kind=index(buildings,j.building_id)
        if erase then for v=0,ny-1 do for u=0,nx-1 do local k=W.cell(j.x+u,j.y+v);if w.zones[k]==kind then w.zones[k]=0 end end end end
        w.cash=w.cash+j.escrow;j.escrow=0
        local p=person(w,j.worker_id);if p then return_home(p) end
        table.remove(w.jobs,i);reindex(w);w.life_epoch=w.life_epoch+1;w.dirty=true;event(w,'canceled',j)
        return true,I18n.t('Obra cancelada; saldo nao gasto devolvido')
    end
    function W.cancel_job(w,id) return cancel(w,id,true) end
    local function authorized(w,j)
        local nx,ny=W.footprint(j.building_id,j.rotation);local kind=index(buildings,j.building_id)
        for v=0,ny-1 do for u=0,nx-1 do if w.zones[W.cell(j.x+u,j.y+v)]~=kind then return false end end end
        return true
    end
    local function reconcile(w)
        for i=#w.jobs,1,-1 do if not authorized(w,w.jobs[i]) then cancel(w,w.jobs[i].id,false) end end
    end
    function W.zone_valid(w,kind,x,y)
        if type(kind)~='number' or kind~=floor(kind) or kind<0 or kind>3 then return false,I18n.t('Uso de zona invalido') end
        if type(x)~='number' or type(y)~='number' or x~=floor(x) or y~=floor(y) or x<0 or y<0 or x>=24 or y>=24 then return false,I18n.t('Fora dos limites da ilha') end
        if kind==0 then return true,I18n.t('Apagar autorizacao sem demolir construcoes') end
        local k=W.cell(x,y)
        if w.occ[k]>0 then return false,I18n.t('Este espaco ja esta ocupado') end
        if w.base[k]<1 then return false,I18n.t('Eleve a terra antes de zonear') end
        return true,I18n.t(kind==3 and 'Clinica: autorize um lote de 2 por 1 com acesso' or 'Autorizar crescimento com acesso viario')
    end
    function W.zone(w,kind,x,y)
        local ok,msg=W.zone_valid(w,kind,x,y);if not ok then return false,msg end
        local k=W.cell(x,y);if w.zones[k]==kind then return false,I18n.t('Esta celula ja tem esse uso') end
        w.zones[k]=kind;w.dirty=true
        return true,msg
    end
    local function crossing(w,id,x,y,r)
        local nx,ny=W.footprint(id,r)
        for i=1,#w.people do local p=w.people[i]
            local px,py=floor(p.x+.5),floor(p.y+.5)
            if px>=x and px<x+nx and py>=y and py<y+ny then return true end
            if p.interaction then
                for t=1,#p.interaction.points do
                    local q=p.interaction.points[t];local qx,qy=floor(q.x+.5),floor(q.y+.5)
                    if qx>=x and qx<x+nx and qy>=y and qy<y+ny then return true end
                end
            end
            local ax,ay=(p.cell-1)%24,floor((p.cell-1)/24)
            if ax>=x and ax<x+nx and ay>=y and ay<y+ny then return true end
            if p.next_cell~=0 then
                local bx,by=(p.next_cell-1)%24,floor((p.next_cell-1)/24)
                if bx>=x and bx<x+nx and by>=y and by<y+ny then return true end
            end
        end
        return false
    end
    local old_valid=W.valid
    W.valid=function(w,id,x,y,r,ignore_cost)
        local ok,msg=old_valid(w,id,x,y,r,ignore_cost);if not ok then return ok,msg end
        local nx,ny=W.footprint(id,r)
        for v=0,ny-1 do for u=0,nx-1 do if w.reserved[W.cell(x+u,y+v)] then return false,I18n.t('Lote reservado para uma obra') end end end
        if id>7 and crossing(w,id,x,y,r) then return false,I18n.t('Aguarde a pessoa atravessar antes de construir') end
        return ok,msg
    end
    local old_remove=W.remove
    W.remove=function(w,x,y)
        local k=w.occ[W.cell(x,y)]
        if k>0 and (w.bid[k]==5 or w.bid[k]==6) and crossing(w,w.bid[k],(k-1)%24,floor((k-1)/24),w.rot[k]) then return false,I18n.t('Ha uma pessoa atravessando esta ponte; aguarde antes de remover') end
        return old_remove(w,x,y)
    end
    local old_terraform=W.terraform
    local function moved_ground(w,heights,q)
        local x,y=q.x+.5,q.y+.5;local ax,ay=max(0,min(23,floor(x))),max(0,min(23,floor(y)))
        local u,v=max(0,min(1,x-ax)),max(0,min(1,y-ay));local k=ay*25+ax+1
        local delta=(w.h[k]-heights[k])*(1-u)*(1-v)+(w.h[k+1]-heights[k+1])*u*(1-v)+(w.h[k+25]-heights[k+25])*(1-u)*v+(w.h[k+26]-heights[k+26])*u*v
        return abs(delta)>1e-8
    end
    local function supported(w,heights)
        local nav=P.refresh(w)
        for i=1,#w.people do
            local p=w.people[i]
            if not nav.walk[p.cell] or (p.next_cell~=0 and not P.edge(w,p.cell,p.next_cell)) then return false end
            if p.interaction then
                if moved_ground(w,heights,p) then return false end
                for t=1,#p.interaction.points do if moved_ground(w,heights,p.interaction.points[t]) then return false end end
            else
                local z=nav.height[p.cell]
                if p.next_cell~=0 then z=z+(nav.height[p.next_cell]-z)*p.edge_progress end
                if abs(z-p.z)>1e-8 then return false end
            end
        end
        return true
    end
    W.terraform=function(w,tool,x,y,radius,reference,dx,dy,stroke)
        local heights
        if #w.people>0 then heights=copy(w.h) end
        local revision=w.revision
        local ok,msg=old_terraform(w,tool,x,y,radius,reference,dx,dy,stroke)
        if not ok or #w.people==0 then return ok,msg end
        if not supported(w,heights) then
            for k=1,625 do w.h[k]=heights[k] end
            W.rebuild(w)
            for i=1,#w.people do local p=w.people[i];if p.path_revision==revision then p.path_revision=w.revision end end
            return false,I18n.t('O ajuste afeta uma pessoa ou seu acesso, inclusive alem do pincel. Aguarde o local ficar livre.')
        end
        return ok,msg
    end
    local old_snapshot=W.snapshot
    W.snapshot=function(w)
        local s=old_snapshot(w);s.zones=copy(w.zones);s.life_epoch=w.life_epoch;s.navigation_revision=w.revision;s.navigation_lots=w.lot_revision;return s
    end
    local old_record=W.record
    W.record=function(w,s)
        local same=true;local zoned=false
        for k=1,625 do if w.h[k]~=s.h[k] then same=false;break end end
        for k=1,576 do if w.bid[k]~=s.bid[k] or w.rot[k]~=s.rot[k] then same=false end;if w.zones[k]~=s.zones[k] then zoned=true end end
        if same and zoned then s.zone_only=true;s.zone_after=copy(w.zones) end
        old_record(w,s)
    end
    local old_restore=W.restore
    W.restore=function(w,s)
        if w.life_epoch~=s.life_epoch then return false,I18n.t('A ilha progrediu; esta transacao nao pode substituir a simulacao') end
        for i=1,#w.people do
            local interaction=w.people[i].interaction
            if interaction and (w.bid[interaction.target]~=s.bid[interaction.target] or w.rot[interaction.target]~=s.rot[interaction.target]) then
                return false,I18n.t('Ha uma pessoa nesta travessia; mantenha o terreno seguro ate ela passar')
            end
        end
        if #w.people>0 then
            for k=1,576 do
                if s.bid[k]>7 and (s.bid[k]~=w.bid[k] or s.rot[k]~=w.rot[k]) and crossing(w,s.bid[k],(k-1)%24,floor((k-1)/24),s.rot[k]) then
                    return false,I18n.t('Ha uma pessoa nesta travessia; mantenha o terreno seguro ate ela passar')
                end
            end
        end
        local previous=#w.people>0 and old_snapshot(w)
        local revision=w.revision
        old_restore(w,s)
        if previous and not supported(w,previous.h) then
            old_restore(w,previous)
            for i=1,#w.people do local p=w.people[i];if p.path_revision==revision then p.path_revision=w.revision end end
            return false,I18n.t('Ha uma pessoa nesta travessia; mantenha o terreno seguro ate ela passar')
        end
        for k=1,576 do w.zones[k]=s.zones[k] end
        for i=1,#w.people do local p=w.people[i]
            if p.path_revision==s.navigation_revision and p.path_lots==s.navigation_lots then p.path_revision=w.revision end
        end
        return true
    end
    W.undo=function(w)
        local n=#w.undo;if n==0 then return false,I18n.t('Nada para desfazer') end
        local s=w.undo[n]
        if s.zone_only then
            for k=1,576 do
                if s.zone_after[k]~=s.zones[k] and w.zones[k]~=s.zone_after[k] then return false,I18n.t('Uma zona posterior ocupa esta transacao') end
            end
            for k=1,576 do if s.zone_after[k]~=s.zones[k] then w.zones[k]=s.zones[k] end end
            reconcile(w);w.dirty=true
        else
            if w.life_epoch~=s.life_epoch then return false,I18n.t('Obras progrediram; desfazer terreno antigo apagaria progresso') end
            local cash=w.cash+(s.refund or 0)
            if cash<0 then return false,I18n.t('Faltam moedas para desfazer este reembolso') end
            local ok,msg=W.restore(w,s);if not ok then return false,msg end;w.cash=cash
        end
        w.undo[n]=nil;return true,I18n.t('Ultima acao desfeita')
    end
    local function terrain(w,j)
        local nx,ny=W.footprint(j.building_id,j.rotation);local base=w.base[W.cell(j.x,j.y)]
        for v=0,ny-1 do for u=0,nx-1 do local k=W.cell(j.x+u,j.y+v)
            if w.occ[k]>0 or base<1 or w.base[k]~=base or w.mask[k]~=0 then return false end
        end end
        return true
    end
    local function demand(w,j)
        local homes,shops,health=0,0,w.health
        for i=1,#w.jobs do local q=w.jobs[i]
            if q.id~=j.id and q.funded then
                if q.building_id==11 then homes=homes+4 elseif q.building_id==17 then shops=shops+1 else health=health+100 end
            end
        end
        if j.building_id==11 then return w.power>=w.need+max(1,floor((homes+4)/4))+shops*2 and w.population+homes<max(16,(w.shops+shops)*16) end
        if j.building_id==17 then return w.population>=8*(w.shops+shops+1) and w.power>=w.need+2+shops*2+homes/4 end
        return w.population>health and w.power>=w.need+3+shops*2+homes/4
    end
    local function condition(w,j)
        if not terrain(w,j) then return 'terrain' end
        local a=work_action(j)
        if P.approaches(w,j.building_id,j.x,j.y,j.rotation,W,InteractionAnchors,a.anchor,w.life_targets)==0 then return 'access' end
        if not j.funded then
            if crossing(w,j.building_id,j.x,j.y,j.rotation) then return 'occupied' end
            if not demand(w,j) then return 'demand' end
            if not w.free and w.cash<j.cost then return 'resources' end
            j.funded=true;j.escrow=w.free and 0 or j.cost;w.cash=w.cash-j.escrow;w.life_epoch=w.life_epoch+1
        end
        return nil
    end
    local function complete(w,p,j)
        local _,i=job(w,j.id);local k=W.cell(j.x,j.y)
        w.bid[k]=j.building_id;w.rot[k]=j.rotation
        table.remove(w.jobs,i);reindex(w);W.rebuild(w);w.completed_lots=w.completed_lots+1;w.life_epoch=w.life_epoch+1
        event(w,'completed',j);return_home(p)
    end
    local function home_doors(w,home,out)
        local id=w.bid[home]
        if id<11 or id>16 or not w.linked[home] then for i=#out,1,-1 do out[i]=nil end;return 0 end
        return P.approaches(w,id,(home-1)%24,floor((home-1)/24),w.rot[home],W,InteractionAnchors,'door',out)
    end
    local function separation(a,b)
        local dx,dy,dz=b.x-a.x,b.y-a.y,(b.z-a.z)/16
        return sqrt(dx*dx+dy*dy+dz*dz)
    end
    local function bind(w,p,target,id,rotation,anchor)
        local point=P.anchor(w,id,(target-1)%24,floor((target-1)/24),rotation,W,InteractionAnchors,anchor,p.cell)
        if not point then return false end
        local points={{x=(p.cell-1)%24,y=floor((p.cell-1)/24),z=P.refresh(w).height[p.cell]}}
        for i=1,#point.approach do
            local q=point.approach[i];points[#points+1]={x=q.x,y=q.y,z=q.z}
        end
        local stand=#points
        if anchor=='door' then
            points[#points+1]={x=point.contact_x,y=point.contact_y,z=point.contact_z}
            points[#points+1]={x=point.interior_x,y=point.interior_y,z=point.interior_z}
        end
        for i=1,#points-1 do points[i].distance=separation(points[i],points[i+1]) end
        p.interaction={target=target,building_id=id,rotation=rotation,anchor=anchor,stand=stand,facing=point.facing,site_stage=point.site_stage,points=points,contact_x=point.contact_x,contact_y=point.contact_y,contact_z=point.contact_z}
        p.local_cursor=1;p.local_revision=w.revision;p.local_lots=w.lot_revision;p.local_valid=true
        return true
    end
    local function spawn(w,role,home,start,path,destination,j,activity)
        local p={id=w.next_person_id,role=role,x=(start-1)%24,y=floor((start-1)/24),z=P.refresh(w).height[start],facing=0,state='exit',animation_time=0,action='exit',action_time=0,appearance=Appearance.make(w.seed,w.next_person_id,role),visible=false,home=home,job_id=j and j.id or 0,phase=1,cell=start,next_cell=0,edge_progress=0,path=path,path_index=1,path_revision=w.revision,path_lots=w.lot_revision,pause=0,destination=destination,destination_id=destination>0 and w.bid[destination] or 0,activity=activity and activity.id or 'none',local_cursor=0}
        if not bind(w,p,home,w.bid[home],w.rot[home],'door') then return nil end
        local points=p.interaction.points;local interior=points[#points]
        p.local_cursor=#points;p.x=interior.x;p.y=interior.y;p.z=interior.z;p.facing=(p.interaction.facing+2)%4
        w.next_person_id=w.next_person_id+1;w.people[#w.people+1]=p
        if j then j.worker_id=p.id;j.status='walking' end
        return p
    end
    local function find_origin(w,role)
        local homes=w.life_homes;local count=0
        for k=1,576 do
            if w.bid[k]>=11 and w.bid[k]<=16 and w.linked[k] then
                local busy=false
                for i=1,#w.people do if w.people[i].home==k and w.people[i].role==role then busy=true;break end end
                if not busy and home_doors(w,k,w.life_doors)>0 then
                    for i=1,#w.life_doors do
                        count=count+1;local h=homes[count] or {};h.home=k;h.door=w.life_doors[i];homes[count]=h
                    end
                end
            end
        end
        for i=count+1,#homes do homes[i]=nil end
        return homes
    end
    local function assign(w,j,budget)
        if #w.people>=32 then j.status='worker';return budget end
        local homes=find_origin(w,'worker')
        if #homes==0 then j.status='worker';return budget end
        if budget==0 then j.status='route';return budget end
        local a=work_action(j)
        P.approaches(w,j.building_id,j.x,j.y,j.rotation,W,InteractionAnchors,a.anchor,w.life_targets)
        local targets=w.life_targets
        local starts=w.life_doors;for i=1,#homes do starts[i]=homes[i].door end;for i=#homes+1,#starts do starts[i]=nil end
        local path,door,target=P.route(w,targets,starts);budget=budget-1
        if not path then j.status='route';return budget end
        local reversed={};for i=#path-1,1,-1 do reversed[#reversed+1]=path[i] end
        if door~=target then reversed[#reversed+1]=target end
        local home=homes[1].home;for i=1,#homes do if homes[i].door==door then home=homes[i].home;break end end
        spawn(w,'worker',home,door,reversed,0,j)
        return budget
    end
    local function reserve(w)
        for k=1,576 do w.zone_status[k]=nil end
        for step=1,576 do
            local k=(w.schedule_cursor+step-2)%576+1;local kind=w.zones[k]
            if kind>0 and w.occ[k]==0 and not w.reserved[k] then
                local x,y=(k-1)%24,floor((k-1)/24);local id=buildings[kind];local r=0;local fit=false
                for rotation=0,1 do
                    local nx,ny=W.footprint(id,rotation);fit=x+nx<=24 and y+ny<=24
                    if fit then for v=0,ny-1 do for u=0,nx-1 do local c=W.cell(x+u,y+v);if w.zones[c]~=kind or w.occ[c]>0 or w.reserved[c] then fit=false end end end end
                    if fit then r=rotation;break end
                end
                if fit and #w.jobs<4 then
                    local candidate=w.life_candidate
                    candidate.id=w.next_job_id;candidate.x=x;candidate.y=y;candidate.building_id=id;candidate.rotation=r;candidate.cost=Catalog[id][5];candidate.funded=false
                    local blocked=condition(w,candidate)
                    if blocked then w.zone_status[k]=blocked
                    else
                        local j={id=candidate.id,x=x,y=y,building_id=id,rotation=r,stage='reserved',progress=0,work_ms=0,status='reserved',worker_id=0,escrow=candidate.escrow,spent=0,cost=candidate.cost,funded=true}
                        w.next_job_id=w.next_job_id+1;w.jobs[#w.jobs+1]=j;w.life_epoch=w.life_epoch+1;reindex(w);w.dirty=true
                    end
                else w.zone_status[k]=fit and 'capacity' or 'footprint' end
            end
        end
        w.schedule_cursor=w.schedule_cursor%576+1
    end
    local function destinations(w,p,out)
        if p.phase==2 then return home_doors(w,p.home,out) end
        if p.role=='worker' then
            local j=job(w,p.job_id)
            if not j then return_home(p);return 0 end
            local a=work_action(j)
            return P.approaches(w,j.building_id,j.x,j.y,j.rotation,W,InteractionAnchors,a.anchor,out)
        end
        local k=p.destination;local id=w.bid[k];local a=actions[p.activity]
        if id~=p.destination_id or not a or not index(a.buildings,id) then return_home(p);return 0 end
        return P.approaches(w,id,(k-1)%24,floor((k-1)/24),w.rot[k],W,InteractionAnchors,a.anchor,out)
    end
    local function reroute(w,p,budget)
        if p.interaction or p.pause>0 or p.next_cell~=0 then return budget end
        if p.path and p.path_revision==w.revision and p.path_lots==w.lot_revision then return budget end
        p.path=nil;p.state='wait';p.wait_reason='route';action(p,'wait')
        if budget==0 then return budget end
        local targets=w.life_targets;local count=destinations(w,p,targets)
        local alternative=p.phase==2 and (count==0 or p.home_route_failed)
        if alternative then
            count=0
            for k=1,576 do
                if home_doors(w,k,w.life_doors)>0 then
                    for d=1,#w.life_doors do count=count+1;targets[count]=w.life_doors[d];w.life_owners[count]=k end
                end
            end
            for i=count+1,#targets do targets[i]=nil end
            if count==0 then p.wait_reason='home';return budget end
        elseif count==0 then return budget end
        local door
        p.path,door=P.route(w,p.cell,targets);budget=budget-1;p.path_index=1;p.path_revision=w.revision;p.path_lots=w.lot_revision
        if p.path then
            p.state='walk';p.wait_reason=nil;p.home_route_failed=nil;action(p,'walk')
            if alternative then for i=1,count do if targets[i]==door then p.home=w.life_owners[i];break end end end
        elseif p.phase==2 then p.home_route_failed=true end
        return budget
    end
    local function trips(w,budget)
        if w.trip_clock<8000 or budget==0 or #w.people>=32 then return budget end
        local residents=0;for i=1,#w.people do if w.people[i].role=='resident' then residents=residents+1 end end
        if residents>=4 then return budget end
        local places=w.life_places
        if w.life_place_revision~=w.revision then
            local count=0
            for k=1,576 do if visits[w.bid[k]] and w.linked[k] then count=count+1;places[count]=k end end
            for i=count+1,#places do places[i]=nil end
            w.life_place_revision=w.revision
        end
        if #places==0 then return budget end
        local homes=find_origin(w,'resident');if #homes==0 then return budget end
        local home=homes[(w.next_person_id-1)%#homes+1]
        for offset=1,#places do
            local k=places[(w.next_person_id+offset-2)%#places+1];local id=w.bid[k];local choices=visits[id]
            local first=floor((w.next_person_id-1)/#places)%#choices
            for c=1,#choices do
                local a=choices[(first+c-1)%#choices+1]
                if P.approaches(w,id,(k-1)%24,floor((k-1)/24),w.rot[k],W,InteractionAnchors,a.anchor,w.life_targets)>0 then
                    local path=P.route(w,home.door,w.life_targets);budget=budget-1
                    if path then
                        spawn(w,'resident',home.home,home.door,path,k,nil,a);w.trip_clock=0;return budget
                    end
                    break
                end
            end
            if budget==0 then return budget end
        end
        return budget
    end
    local function schedule(w)
        reconcile(w);reserve(w);local budget=2
        for i=1,#w.people do local p=w.people[i];if p.job_id==0 then budget=reroute(w,p,budget) end end
        for offset=1,#w.jobs do
            local i=(w.schedule_cursor+offset-2)%#w.jobs+1
            local j=w.jobs[i];local blocked=condition(w,j)
            if blocked then
                j.status=blocked;local p=person(w,j.worker_id)
                if p then action(p,'wait');if not p.interaction then p.state='wait';p.path=nil end end
            elseif j.worker_id==0 then budget=assign(w,j,budget)
            else
                local p=person(w,j.worker_id)
                if p then
                    if j.work_ms==12000 then j.status='walking'
                    else
                        budget=reroute(w,p,budget)
                        j.status=p.state=='work' and 'working' or (p.interaction or p.path) and 'walking' or 'route'
                    end
                end
            end
        end
        trips(w,budget)
    end
    local function arrive(w,p)
        p.path=nil;p.path_index=1
        local target,id,rotation,anchor,assigned
        if p.phase==2 then
            target=p.home;id=w.bid[target];rotation=w.rot[target];anchor='door'
            if id<11 or id>16 then p.state='wait';p.home_route_failed=true;action(p,'wait');return end
        elseif p.role=='resident' then
            target=p.destination;id=w.bid[target];rotation=w.rot[target]
            local a=actions[p.activity]
            if id~=p.destination_id or not a or not index(a.buildings,id) then return_home(p);return end
            anchor=a.anchor
        else
            local j=job(w,p.job_id)
            if not j then return_home(p);return end
            target=W.cell(j.x,j.y);id=j.building_id;rotation=j.rotation;anchor=work_action(j).anchor
            assigned=j
        end
        if bind(w,p,target,id,rotation,anchor) then
            p.state='approach';p.visible=true;action(p,'walk');if assigned then assigned.status='walking' end
        else p.state='wait';p.path=nil;action(p,'wait') end
    end
    local function move(w,p,dt)
        local nav=P.refresh(w)
        if p.path_revision~=w.revision or p.path_lots~=w.lot_revision then p.path=nil end
        local distance=dt*.0025
        while distance>0 do
            if p.next_cell==0 then
                if not p.path then p.state='wait';action(p,'wait');return end
                local next=p.path[p.path_index]
                if not next then arrive(w,p);return end
                if not P.edge(w,p.cell,next) then p.path=nil;p.state='wait';action(p,'wait');return end
                p.next_cell=next;p.edge_progress=0;p.path_index=p.path_index+1
            end
            if not P.edge(w,p.cell,p.next_cell) then p.path=nil;p.state='wait';action(p,'wait');return end
            local amount=min(distance,1-p.edge_progress);p.edge_progress=p.edge_progress+amount;distance=distance-amount
            local ax,ay=(p.cell-1)%24,floor((p.cell-1)/24);local bx,by=(p.next_cell-1)%24,floor((p.next_cell-1)/24)
            p.x=ax+(bx-ax)*p.edge_progress;p.y=ay+(by-ay)*p.edge_progress
            p.z=nav.height[p.cell]+(nav.height[p.next_cell]-nav.height[p.cell])*p.edge_progress
            p.facing=bx>ax and 0 or by>ay and 1 or bx<ax and 2 or 3;p.state='walk';p.visible=true;action(p,'walk')
            if p.edge_progress>=1 then p.cell=p.next_cell;p.next_cell=0;p.edge_progress=0 end
        end
    end
    local function local_position(p)
        local points=p.interaction.points
        if p.local_shift then
            local from=p.local_shift;local to=points[p.interaction.stand];local t=from.progress
            return from.x+(to.x-from.x)*t,from.y+(to.y-from.y)*t,from.z+(to.z-from.z)*t
        end
        local i=floor(p.local_cursor);local t=p.local_cursor-i;local a=points[i]
        if t==0 then return a.x,a.y,a.z end
        local b=points[i+1]
        return a.x+(b.x-a.x)*t,a.y+(b.y-a.y)*t,a.z+(b.z-a.z)*t
    end
    local function local_move(w,p,dt,target)
        local points=p.interaction.points;local direction=p.local_cursor<target and 1 or -1;local distance=dt*.0025
        if p.local_shift then
            local from=p.local_shift;local length=from.distance
            local amount=min(distance,(1-from.progress)*length);from.progress=length<1e-10 and 1 or min(1,from.progress+amount/length);distance=distance-amount
            if 1-from.progress<1e-10 then p.local_shift=nil end
            p.facing=p.interaction.facing
        end
        while not p.local_shift and distance>0 and p.local_cursor~=target do
            local i=direction==1 and floor(p.local_cursor) or math.ceil(p.local_cursor)-1
            local a,b=points[i],points[i+1];local dx,dy=b.x-a.x,b.y-a.y
            local length=a.distance;local limit=direction==1 and i+1 or i
            if length<1e-10 then p.local_cursor=limit
            else
                local amount=min(distance,abs(limit-p.local_cursor)*length)
                p.local_cursor=p.local_cursor+direction*amount/length;distance=distance-amount
                if abs(p.local_cursor-limit)<1e-10 then p.local_cursor=limit end
                if abs(dx)+abs(dy)>1e-10 then
                    dx=dx*direction;dy=dy*direction
                    p.facing=abs(dx)>=abs(dy) and (dx>0 and 0 or 2) or (dy>0 and 1 or 3)
                end
            end
        end
        p.x,p.y,p.z=local_position(p);p.visible=true
        return not p.local_shift and p.local_cursor==target
    end
    local function valid_interaction(w,p)
        if p.local_revision==w.revision and p.local_lots==w.lot_revision then return p.local_valid end
        p.local_revision=w.revision;p.local_lots=w.lot_revision
        local s=p.interaction
        local point=P.anchor(w,s.building_id,(s.target-1)%24,floor((s.target-1)/24),s.rotation,W,InteractionAnchors,s.anchor,p.cell)
        local stand=s.points[s.stand]
        p.local_valid=point~=nil and abs(point.x-stand.x)<1e-8 and abs(point.y-stand.y)<1e-8 and abs(point.z-stand.z)<1e-8 and point.facing==s.facing
        return p.local_valid
    end
    local function inspect(w,p)
        if p.checked_revision==w.revision and p.checked_lots==w.lot_revision then return end
        p.checked_revision=w.revision;p.checked_lots=w.lot_revision
        if p.phase==1 and p.role=='resident' and w.bid[p.destination]~=p.destination_id then return_home(p) end
        local s=p.interaction
        if not s or p.state=='exit' or p.state=='depart' then return end
        if p.job_id>0 then
            local j=job(w,p.job_id)
            if not j then return_home(p);return end
            local blocked=condition(w,j)
            if blocked then j.status=blocked;action(p,'wait')
            elseif not valid_interaction(w,p) then p.state='depart';p.path=nil;j.status='route';action(p,'walk')
            else j.status=p.state=='work' and 'working' or 'walking' end
        elseif w.bid[s.target]~=s.building_id or w.rot[s.target]~=s.rotation or not valid_interaction(w,p) then
            return_home(p);p.home_route_failed=s.target==p.home or nil
        end
    end
    local function work(w,p,j,dt)
        if j.status~='working' and j.status~='walking' then action(p,'wait');return end
        local a,stop,start=work_action(j);local s=p.interaction
        if not s or p.local_cursor~=s.stand or s.target~=W.cell(j.x,j.y) or s.anchor~=a.anchor or s.site_stage~=j.stage then
            p.state='depart';p.path=nil;j.status='walking';action(p,'walk');return
        end
        action(p,a.id);p.facing=s.facing
        local previous=j.stage
        j.work_ms=min(stop,j.work_ms+dt);j.progress=j.work_ms/12000;j.stage=j.work_ms<4000 and 'foundation' or 'frame';j.status='working'
        p.action_time=(j.work_ms-start)/(stop-start)*duration(a.id)
        if j.stage~=previous then w.dirty=true end
        local spent=w.free and 0 or floor(j.cost*j.progress);j.escrow=j.escrow-(spent-j.spent);j.spent=spent;w.life_epoch=w.life_epoch+1
        if j.work_ms==12000 then
            p.state='depart';p.path=nil;j.status='walking';action(p,'walk')
        elseif j.stage~=previous then
            j.status='walking'
            local next_action=work_action(j)
            if next_action.anchor==s.anchor and bind(w,p,s.target,s.building_id,s.rotation,s.anchor) then
                p.local_cursor=p.interaction.stand;p.local_shift={x=p.x,y=p.y,z=p.z,progress=0};p.state='approach';action(p,'walk')
                p.local_shift.distance=separation(p.local_shift,p.interaction.points[p.interaction.stand])
            else p.state='depart';p.path=nil;action(p,'walk') end
        end
    end
    local function advance(w,dt)
        for i=#w.people,1,-1 do
            local p=w.people[i];p.animation_time=(p.animation_time+dt)%120000;p.action_time=(p.action_time+dt)%120000
            inspect(w,p)
            local s=p.interaction;local j=p.job_id>0 and job(w,p.job_id) or nil
            if s then
                local blocked=j and j.status~='walking' and j.status~='working' and j.status~='route'
                if p.state=='exit' then
                    action(p,'exit')
                    if local_move(w,p,dt,s.stand) then p.state='depart';action(p,'walk') end
                elseif p.state=='depart' then
                    action(p,'walk')
                    if local_move(w,p,dt,1) then
                        p.interaction=nil;p.local_cursor=0;p.local_valid=nil;p.state='walk'
                        if not p.path and p.phase==1 and j and j.work_ms<12000 then p.path={};p.path_index=1;p.path_revision=w.revision;p.path_lots=w.lot_revision end
                    end
                elseif not blocked then
                    if p.state=='approach' then
                        action(p,'walk')
                        if local_move(w,p,dt,s.stand) then
                            p.facing=s.facing;p.action_time=0
                            if j then p.state='work';j.status='working';action(p,work_action(j).id)
                            else
                                p.state='activity';if p.phase==1 then p.phase=4 end
                                action(p,p.phase==2 and 'unlock_door' or p.activity)
                            end
                        end
                    elseif p.state=='work' then
                        if j then work(w,p,j,dt) else return_home(p) end
                    elseif p.state=='activity' then
                        p.facing=s.facing
                        if p.action_time>=duration(p.action) then
                            if s.anchor=='door' then p.state='enter';action(p,'enter')
                            else return_home(p) end
                        end
                    elseif p.state=='enter' then
                        action(p,'enter')
                        if local_move(w,p,dt,#s.points) then
                            p.state='interior';p.visible=false;p.pause=p.phase==2 and 500 or 1800
                            if p.phase==2 then p.phase=3 end
                            action(p,'wait')
                        end
                    elseif p.state=='interior' then
                        p.pause=max(0,p.pause-dt)
                        if p.pause==0 then
                            if p.phase==3 then table.remove(w.people,i)
                            else return_home(p) end
                        end
                    end
                end
            elseif j and j.work_ms==12000 then
                if j.status=='walking' or j.status=='working' or j.status=='route' then
                    local blocked=condition(w,j)
                    if blocked then j.status=blocked;p.state='wait';action(p,'wait') else complete(w,p,j) end
                end
            elseif not j or j.status=='walking' or j.status=='working' or j.status=='route' then move(w,p,dt)
            else action(p,'wait') end
        end
    end
    function W.update(w,dt)
        if type(dt)~='number' or dt~=dt or dt<=0 or dt==math.huge then return end
        reconcile(w)
        w.life_step=w.life_step+dt
        while w.life_step>=10 do
            local step=10;w.life_step=w.life_step-step
            w.life_time=w.life_time+step;w.trip_clock=min(8000,w.trip_clock+step);w.life_accumulator=w.life_accumulator+step
            if w.life_accumulator>=500 then w.life_accumulator=w.life_accumulator-500;schedule(w) end
            advance(w,step)
            W.traffic_step(w,step)
        end
    end
    local old_encode,old_decode=W.encode,W.decode
    function W.encode(w)
        local out={(old_encode(w):gsub('^MARE2','MARE5'))}
        for k=1,576 do out[#out+1]=w.zones[k] end
        local function put(...) for i=1,select('#',...) do local value=select(i,...);out[#out+1]=string.format('%.17g',value) end end
        put(w.life_time,w.life_accumulator,w.life_step,w.next_job_id,w.next_person_id,w.trip_clock,w.schedule_cursor,w.completed_lots,w.ticks,#w.jobs)
        for i=1,#w.jobs do local j=w.jobs[i];put(j.id,j.x,j.y,j.building_id,j.rotation,index(stages,j.stage),j.work_ms,status_codes[j.status],j.worker_id,j.escrow,j.spent,j.cost,j.funded and 1 or 0) end
        put(#w.people)
        for i=1,#w.people do
            local p=w.people[i]
            put(p.id,p.role=='worker' and 1 or 2,p.x,p.y,p.z,p.facing,index(states,p.state),p.animation_time,p.home,p.job_id,p.phase,p.cell,p.next_cell,p.edge_progress,p.pause,p.destination)
            out[#out+1]=p.action;put(p.action_time,p.appearance,p.visible and 1 or 0,p.destination_id);out[#out+1]=p.activity
            put(p.local_cursor,p.interaction and 1 or 0)
            local s=p.interaction
            if s then
                put(s.target,s.building_id,s.rotation,index(anchor_names,s.anchor),s.stand,s.facing,index(stages,s.site_stage) or 0,s.contact_x,s.contact_y,s.contact_z,#s.points)
                for t=1,#s.points do local q=s.points[t];put(q.x,q.y,q.z) end
                put(p.local_shift and 1 or 0)
                if p.local_shift then local q=p.local_shift;put(q.x,q.y,q.z,q.progress) end
            end
        end
        return table.concat(out,',')
    end
    function W.decode(text)
        if type(text)~='string' or #text>100000 or text:find(',,',1,true) or text:sub(-1)==',' then return nil end
        if text:sub(1,6)=='MARE2,' then local w=old_decode(text);if w then init(w) end;return w end
        local old=text:sub(1,6)=='MARE3,'
        if not old and text:sub(1,6)~='MARE5,' then return nil end
        local raw={};for token in text:gmatch('[^,]+') do raw[#raw+1]=token end
        local base_count=6+625+576*2
        if #raw<base_count+576+11 then return nil end
        local legacy={'MARE2'};for i=2,base_count do legacy[i]=raw[i] end
        local w=old_decode(table.concat(legacy,','));if not w then return nil end;init(w)
        local cursor=base_count+1;local failed=false
        local function get(lo,hi,integer)
            local v=tonumber(raw[cursor]);cursor=cursor+1
            if not v or v~=v or v<lo or v>hi or (integer and v~=floor(v)) then failed=true;return lo end
            return v
        end
        local function get_action(optional)
            local id=raw[cursor];cursor=cursor+1
            if not actions[id] and not (optional and id=='none') then failed=true;return optional and 'none' or 'wait' end
            return id
        end
        for k=1,576 do w.zones[k]=get(0,3,true) end
        w.life_time=get(0,1e15);w.life_accumulator=get(0,500);w.life_step=get(0,10);w.next_job_id=get(1,100000000,true);w.next_person_id=get(1,100000000,true);w.trip_clock=get(0,8000);w.schedule_cursor=get(1,576,true);w.completed_lots=get(0,100000000,true);w.ticks=get(0,100000000,true)
        if w.life_accumulator==500 or w.life_step==10 then return nil end
        local count=get(0,4,true);local ids={};local occupied={}
        for i=1,count do
            local j={id=get(1,w.next_job_id-1,true),x=get(0,23,true),y=get(0,23,true),building_id=get(11,30,true),rotation=get(0,1,true),stage=stages[get(1,3,true)],work_ms=get(0,12000),status=statuses[get(1,9,true)],worker_id=get(0,w.next_person_id-1,true),escrow=get(0,100000000,true),spent=get(0,100000000,true),cost=get(0,100000000,true),funded=get(0,1,true)==1}
            if old and j.work_ms==12000 then return nil end
            j.progress=j.work_ms/12000
            if not index(buildings,j.building_id) or ids[j.id] or j.cost~=Catalog[j.building_id][5] then return nil end
            ids[j.id]=j
            if j.spent~=(w.free and 0 or floor(j.cost*j.progress)) or j.escrow+j.spent~=(j.funded and not w.free and j.cost or 0) or (not j.funded and (j.work_ms>0 or j.worker_id>0)) then return nil end
            if j.work_ms>0 and (j.worker_id==0 or j.stage~=(j.work_ms<4000 and 'foundation' or 'frame')) then return nil end
            if j.work_ms==0 and j.stage~='reserved' then return nil end
            local nx,ny=W.footprint(j.building_id,j.rotation);if j.x+nx>24 or j.y+ny>24 then return nil end
            for v=0,ny-1 do for u=0,nx-1 do local k=W.cell(j.x+u,j.y+v);if occupied[k] or w.occ[k]>0 then return nil end;occupied[k]=true end end
            w.jobs[i]=j
        end
        count=get(0,32,true);local people={}
        for i=1,count do
            local p={id=get(1,w.next_person_id-1,true),role=get(1,2,true)==1 and 'worker' or 'resident',x=get(old and 0 or -1,old and 23 or 24),y=get(old and 0 or -1,old and 23 or 24),z=get(0,old and 80 or 160),facing=get(0,3,true),state=(old and legacy_states or states)[get(1,old and 5 or #states,true)],animation_time=get(0,120000),home=get(1,576,true),job_id=get(0,w.next_job_id-1,true),phase=get(1,4,true),cell=get(1,576,true),next_cell=get(0,576,true),edge_progress=get(0,1),pause=get(0,1800),destination=get(0,576,true),path_index=1}
            if not old then
                p.action=get_action(false);p.action_time=get(0,120000);p.appearance=get(0,32767,true);p.visible=get(0,1,true)==1;p.destination_id=get(0,#Catalog,true);p.activity=get_action(true);p.local_cursor=get(0,32)
                if get(0,1,true)==1 then
                    local s={target=get(1,576,true),building_id=get(8,#Catalog,true),rotation=get(0,3,true),anchor=anchor_names[get(1,#anchor_names,true)],stand=get(2,30,true),facing=get(0,3,true),site_stage=stages[get(0,3,true)],contact_x=get(-1,24),contact_y=get(-1,24),contact_z=get(0,160),points={}}
                    local length=get(2,32,true)
                    for t=1,length do s.points[t]={x=get(-1,24),y=get(-1,24),z=get(0,160)} end
                    for t=1,length-1 do s.points[t].distance=separation(s.points[t],s.points[t+1]) end
                    p.interaction=s
                    if get(0,1,true)==1 then p.local_shift={x=get(-1,24),y=get(-1,24),z=get(0,160),progress=get(0,1)} end
                end
            end
            if p.animation_time==120000 or p.edge_progress==1 then return nil end
            if people[p.id] or (p.role=='resident' and p.job_id~=0) then return nil end;people[p.id]=p
            local ax,ay=(p.cell-1)%24,floor((p.cell-1)/24);local bx,by=ax,ay
            if p.next_cell>0 then bx,by=(p.next_cell-1)%24,floor((p.next_cell-1)/24);if math.abs(ax-bx)+math.abs(ay-by)~=1 then return nil end
            elseif p.edge_progress~=0 then return nil end
            if old or not p.interaction then
                if abs(p.x-(ax+(bx-ax)*p.edge_progress))>1e-8 or abs(p.y-(ay+(by-ay)*p.edge_progress))>1e-8 then return nil end
            else
                local s=p.interaction;local points=s.points;local start=points[1]
                if p.next_cell~=0 or p.local_cursor<1 or p.local_cursor>#points or abs(start.x-ax)>1e-8 or abs(start.y-ay)>1e-8 then return nil end
                if #points~=(s.anchor=='door' and s.stand+2 or s.stand) then return nil end
                if (s.anchor=='work_edge' or s.anchor=='work_surface')~=(s.site_stage~=nil) then return nil end
                if p.local_shift then
                    local q=p.local_shift;local to=points[s.stand]
                    if not s.site_stage or p.local_cursor~=s.stand or (p.state~='approach' and p.state~='depart') or q.progress==1 or abs(q.x-to.x)>.5 or abs(q.y-to.y)>.5 or abs(q.z-to.z)>16 then return nil end
                    q.distance=separation(q,to)
                end
                local tx,ty=(s.target-1)%24,floor((s.target-1)/24);local nx,ny=W.footprint(s.building_id,s.rotation)
                if tx+nx>24 or ty+ny>24 then return nil end
                for t=1,#points do
                    local q=points[t]
                    if q.x<tx-2 or q.x>tx+nx+1 or q.y<ty-2 or q.y>ty+ny+1 then return nil end
                end
                local x,y,z=local_position(p)
                if abs(p.x-x)>1e-8 or abs(p.y-y)>1e-8 or abs(p.z-z)>1e-8 then return nil end
            end
            if p.job_id>0 then local j=ids[p.job_id];if not j or j.worker_id~=p.id or p.phase~=1 or p.role~='worker' then return nil end end
            if p.state=='work' and (p.job_id==0 or p.next_cell~=0) then return nil end
            if old then
                if p.phase==3 and (p.state~='leave' or p.pause==0) then return nil end
                if p.phase==4 and (p.role~='resident' or p.state~='arrive' or p.pause==0) then return nil end
            else
                local s=p.interaction
                if not s then
                    if p.local_cursor~=0 or not p.visible or p.pause~=0 or (p.state~='walk' and p.state~='wait') or p.phase>2 then return nil end
                else
                    if p.state=='walk' or p.state=='wait' then return nil end
                    if (p.state=='work' or p.state=='activity') and p.local_cursor~=s.stand then return nil end
                    if (p.state=='enter' or p.state=='exit') and (s.anchor~='door' or p.local_cursor<s.stand) then return nil end
                    if (p.state=='approach' or p.state=='depart') and p.local_cursor>s.stand then return nil end
                    if p.state=='interior' then
                        if s.anchor~='door' or p.local_cursor~=#s.points or p.visible or p.pause==0 or (p.phase~=3 and p.phase~=4) then return nil end
                    elseif p.pause~=0 or (not p.visible and not (p.state=='exit' and p.phase==1 and s.target==p.home and p.local_cursor==#s.points)) then return nil end
                    if p.phase==3 and (p.state~='interior' or s.target~=p.home) then return nil end
                    if p.phase==4 and (p.role~='resident' or s.target~=p.destination or (p.state~='activity' and p.state~='enter' and p.state~='interior')) then return nil end
                    if p.state=='activity' then
                        local a=actions[p.action]
                        if a.kind~='resident' or a.anchor~=s.anchor or not index(a.buildings,s.building_id) then return nil end
                    end
                    if p.state=='work' then
                        local j=ids[p.job_id]
                        if not j or s.target~=W.cell(j.x,j.y) or s.building_id~=j.building_id or s.rotation~=j.rotation or (s.anchor~='work_edge' and s.anchor~='work_surface') then return nil end
                    end
                end
                if p.role=='resident' and (p.phase==1 or p.phase==4) then
                    local a=actions[p.activity]
                    if not a or a.kind~='resident' or not index(a.buildings,p.destination_id) then return nil end
                end
            end
            if p.role=='worker' and p.phase==1 and p.job_id==0 then return nil end
            if p.role=='resident' and (p.phase==1 or p.phase==4) and p.destination==0 then return nil end
            w.people[i]=p
        end
        for i=1,#w.jobs do local j=w.jobs[i];if j.worker_id>0 and (not people[j.worker_id] or people[j.worker_id].job_id~=j.id) then return nil end end
        if failed or cursor~=#raw+1 then return nil end
        reindex(w)
        local nav=P.refresh(w)
        for i=1,#w.people do local p=w.people[i]
            if not nav.walk[p.cell] or (p.next_cell~=0 and not P.edge(w,p.cell,p.next_cell)) then return nil end
            if old then
                p.appearance=Appearance.make(w.seed,p.id,p.role);p.visible=true;p.action=p.state=='walk' and 'walk' or 'wait';p.action_time=0;p.local_cursor=0;p.destination_id=p.destination>0 and w.bid[p.destination] or 0;p.activity='none';p.pause=0
                if p.phase==3 then p.phase=2 elseif p.phase==4 then p.phase=1 end
                p.state=p.state=='walk' and 'walk' or 'wait'
                if p.role=='resident' and p.phase==1 then
                    local choices=visits[p.destination_id]
                    if choices and #choices>0 then p.activity=choices[(p.id-1)%#choices+1].id else return_home(p) end
                end
                if p.job_id>0 then local j=ids[p.job_id];if j.status=='working' then j.status='walking' end end
            end
        end
        return w
    end
end
return L

end)()
local TrafficPaths=(function()
local T={}
local floor,abs,max,min=math.floor,math.abs,math.max,math.min
local dx={1,1,0,-1,-1,-1,0,1}
local dy={0,1,1,1,0,-1,-1,-1}
local radius={car=.28,boat=.6,fish=.14,dolphin=.48,whale=1.05}
local aquatic={'boat','fish','dolphin','whale'}
T.dx=dx;T.dy=dy;T.radius=radius
local function xy(k) return (k-1)%24,floor((k-1)/24) end
local function trim(t,n) for i=n+1,#t do t[i]=nil end end
function T.water(w,x,y,r)
    for yy=max(0,floor(y+.5-r)),min(23,floor(y+.5+r)) do
        for xx=max(0,floor(x+.5-r)),min(23,floor(x+.5+r)) do
            local k=yy*24+xx+1
            local ax=max(abs(xx-x)-.5,0);local ay=max(abs(yy-y)-.5,0)
            if ax*ax+ay*ay<r*r and (w.top[k]~=0 or w.occ[k]~=0 or w.reserved[k]) then return false end
        end
    end
    return true
end
local function source(w,n)
    if n.revision==w.revision and n.lots==w.lot_revision then return false end
    n.revision=w.revision;n.lots=w.lot_revision
    local changed=false
    for k=1,625 do if n.h[k]~=w.h[k] then n.h[k]=w.h[k];changed=true end end
    for k=1,576 do
        local occupied=w.reserved[k] and 1 or 0
        if n.bid[k]~=w.bid[k] or n.rot[k]~=w.rot[k] or n.reserved[k]~=occupied then changed=true end
        n.bid[k]=w.bid[k];n.rot[k]=w.rot[k];n.reserved[k]=occupied
    end
    return changed
end
local function perimeter(w,k,id,W,visit)
    local x,y=xy(k);local nx,ny=W.footprint(id,w.rot[k])
    for v=-1,ny do for u=-1,nx do
        if (u>=0 and u<nx and (v==-1 or v==ny)) or (v>=0 and v<ny and (u==-1 or u==nx)) then
            local xx,yy=x+u,y+v
            if xx>=0 and yy>=0 and xx<24 and yy<24 then visit(xx,yy,u<0 and -1 or u==nx and 1 or 0,v<0 and -1 or v==ny and 1 or 0) end
        end
    end end
end
function T.refresh(w,W,P)
    local n=w.traffic_navigation
    if not n then
        n={h={},bid={},rot={},reserved={},pass={car={},boat={},fish={},dolphin={},whale={}},height={},degree={},places={},homes={},destinations={},ports={},boundary={boat={},fish={},dolphin={},whale={}},waters={boat={},fish={},dolphin={},whale={}},edges={},queue={},seen={},parent={},targets={},stamp=0,routes={},route_cursor=1,generation=0,builds=0,searches=0,expanded=0}
        for i=1,576 do n.edges[i]={} end
        w.traffic_navigation=n
    end
    if not source(w,n) then return n end
    n.generation=n.generation+1;n.builds=n.builds+1
    trim(n.routes,0);n.route_cursor=1
    local walk=P.refresh(w)
    for k=1,576 do
        local a=w.occ[k];local id=a>0 and w.bid[a] or 0
        n.pass.car[k]=(id==3 or id==4 or id==6) and walk.walk[k] or false
        n.height[k]=walk.height[k]
        local x,y=xy(k)
        for i=1,4 do local kind=aquatic[i];n.pass[kind][k]=T.water(w,x,y,radius[kind]) end
    end
    for k=1,576 do
        local x,y=xy(k);local degree=0
        for d=1,8 do
            local xx,yy=x+dx[d],y+dy[d];local b=yy*24+xx+1
            local allowed=d%2==1 and xx>=0 and yy>=0 and xx<24 and yy<24 and n.pass.car[k] and n.pass.car[b] and P.edge(w,k,b) or false
            n.edges[k][d]=allowed
            if allowed then degree=degree+1 end
        end
        n.degree[k]=degree
    end
    local homes,destinations,ports=0,0,0
    for k=1,576 do
        local id=w.bid[k];local p=n.places[k]
        if id>=8 then
            p=p or {car={},boat={}};n.places[k]=p;p.id=id
            local cars,boats=0,0
            perimeter(w,k,id,W,function(x,y,sx,sy)
                local b=y*24+x+1
                if n.pass.car[b] and abs(n.height[b]-w.base[k]*16)<=8 then cars=cars+1;p.car[cars]=b end
                if (id==9 or id==10) and w.linked[k] and (id==10 or w.population>0) then
                    for step=0,2 do
                        local xx,yy=x+sx*step,y+sy*step
                        if xx<0 or yy<0 or xx>=24 or yy>=24 then break end
                        local a=yy*24+xx+1
                        if w.base[a]~=0 or w.occ[a]~=0 then break end
                        if n.pass.boat[a] then
                            local found=false;for i=1,boats do if p.boat[i]==a then found=true;break end end
                            if not found then boats=boats+1;p.boat[boats]=a end
                            break
                        end
                    end
                end
            end)
            trim(p.car,cars);trim(p.boat,boats)
            if cars>0 then
                if id>=11 and id<=16 and w.linked[k] then homes=homes+1;n.homes[homes]=k
                elseif (id>=17 and id<=34) or id==8 or id==9 or id==10 or id==35 or id==36 or id==39 or id==40 then destinations=destinations+1;n.destinations[destinations]=k end
            end
            if boats>0 then ports=ports+1;n.ports[ports]=k end
        elseif p then p.id=0;trim(p.car,0);trim(p.boat,0) end
    end
    trim(n.homes,homes);trim(n.destinations,destinations);trim(n.ports,ports)
    for i=1,4 do
        local kind=aquatic[i];local boundary,water=0,0
        for k=1,576 do if n.pass[kind][k] then
            water=water+1;n.waters[kind][water]=k
            local x,y=xy(k)
            if x==0 or y==0 or x==23 or y==23 then boundary=boundary+1;n.boundary[kind][boundary]=k end
        end end
        trim(n.waters[kind],water);trim(n.boundary[kind],boundary)
    end
    return n
end
function T.edge(n,kind,a,b)
    if not n.pass[kind][a] or not n.pass[kind][b] then return false end
    local ax,ay=xy(a);local bx,by=xy(b);local x,y=bx-ax,by-ay
    if abs(x)>1 or abs(y)>1 or x==0 and y==0 then return false end
    if kind=='car' then
        local d=x==1 and 1 or y==1 and 3 or x==-1 and 5 or 7
        return abs(x)+abs(y)==1 and n.edges[a][d]
    end
    return x==0 or y==0 or n.pass[kind][ay*24+bx+1] and n.pass[kind][by*24+ax+1]
end
function T.route(n,kind,starts,targets,source_key,target_key,budget)
    if budget==0 then return nil,nil,nil,0 end
    for i=1,#n.routes do local c=n.routes[i]
        if c.kind==kind and c.source==source_key and c.target==target_key then return c.path,c.start,c.finish,budget-1 end
    end
    n.searches=n.searches+1;n.stamp=n.stamp+1;local stamp=n.stamp
    local first,last=1,0;local seen,parent,queue=n.seen,n.parent,n.queue
    if type(starts)=='number' then
        if n.pass[kind][starts] then last=1;queue[1]=starts;seen[starts]=stamp;parent[starts]=0 end
    else
        for i=1,#starts do local k=starts[i]
            if n.pass[kind][k] and seen[k]~=stamp then last=last+1;queue[last]=k;seen[k]=stamp;parent[k]=0 end
        end
    end
    for i=1,#targets do n.targets[targets[i]]=stamp end
    local path,start,finish
    while first<=last do
        local k=queue[first];first=first+1;n.expanded=n.expanded+1
        if n.targets[k]==stamp then
            path={};finish=k;start=k
            while parent[start]~=0 do path[#path+1]=start;start=parent[start] end
            for a=1,floor(#path/2) do local b=#path-a+1;path[a],path[b]=path[b],path[a] end
            break
        end
        local x,y=xy(k)
        for d=1,8,kind=='car' and 2 or 1 do
            local xx,yy=x+dx[d],y+dy[d];local b=yy*24+xx+1
            if xx>=0 and yy>=0 and xx<24 and yy<24 and seen[b]~=stamp and T.edge(n,kind,k,b) then
                seen[b]=stamp;parent[b]=k;last=last+1;queue[last]=b
            end
        end
    end
    local c=n.routes[n.route_cursor] or {};n.routes[n.route_cursor]=c
    c.kind=kind;c.source=source_key;c.target=target_key;c.path=path;c.start=start;c.finish=finish
    n.route_cursor=n.route_cursor%32+1
    return path,start,finish,budget-1
end
function T.height(w,n,x,y,cell)
    local a=w.occ[cell]
    if a>0 and w.bid[a]==6 then return n.height[cell] end
    local xx,yy=max(0,min(23.999999,x+.5)),max(0,min(23.999999,y+.5))
    local ix,iy=floor(xx),floor(yy);local u,v=xx-ix,yy-iy;local k=iy*25+ix+1
    return (w.h[k]*(1-u)*(1-v)+w.h[k+1]*u*(1-v)+w.h[k+25]*(1-u)*v+w.h[k+26]*u*v)*16
end
return T

end)()
local Traffic=(function()
local T={}
local floor,min,max,abs=math.floor,math.min,math.max,math.abs
local kinds={'car','boat','fish','dolphin','whale'}
local caps={car=8,boat=4,fish=6,dolphin=1,whale=1}
local frames={car=2,boat=4,fish=4,dolphin=8,whale=8}
local speed={car=.0014,boat=.00065,fish=.00038,dolphin=.0008,whale=.00048}
local sprites={}
for i=1,#kinds do local kind=kinds[i];sprites[kind]={}
    for d=0,7 do local row={};sprites[kind][d]=row
        for f=0,frames[kind]-1 do row[f]=(i<=2 and 'vehicle_' or 'fauna_')..kind..'_'..d..'_'..f end
    end
end
T.kinds=kinds;T.caps=caps
local function xy(k) return (k-1)%24,floor((k-1)/24) end
local function random(s,n) s.rng=(s.rng*48271)%2147483647;return s.rng%n end
local function count(w,kind) local n=0;for i=1,#w.traffic do if w.traffic[i].kind==kind then n=n+1 end end;return n end
local function facing(x,y)
    if abs(y)<abs(x)*.41421356237 then return x>0 and 0 or 4 end
    if abs(x)<abs(y)*.41421356237 then return y>0 and 2 or 6 end
    return x>0 and (y>0 and 1 or 7) or (y>0 and 3 or 5)
end
function T.remember_position(e)
    e.previous_x,e.previous_y,e.previous_z=e.x,e.y,e.z
end
function T.render(e)
    local frame
    if e.kind=='dolphin' or e.kind=='whale' then frame=min(7,floor(e.age*8/e.duration))
    else frame=floor(e.animation_time/(e.kind=='car' and 130 or 180))%frames[e.kind] end
    e.sprite=sprites[e.kind][e.facing][frame];e.visible=true
    e.still_sprite=(e.kind=='dolphin' or e.kind=='whale') and e.sprite or sprites[e.kind][e.facing][0]
end
function T.init(w)
    local s={rng=w.seed%2147483646+1,time=0,step=0,plan_clock=0,next_id=1,cursor=1,spawn_cursor=1,car_due=3000,boat_due=7000,fish_due=2000}
    s.dolphin_due=45000+random(s,45001);s.whale_due=180000+random(s,180001)
    w.traffic={};w.traffic_state=s;w.traffic_navigation=nil;w.traffic_targets={}
    return w
end
function T.install(W,Catalog,P,Nav)
    W.traffic_caps=caps
    local function navigation(w) return Nav.refresh(w,W,P) end
    W.traffic_navigation=navigation
    local function clear(w,kind,x,y,heading,except)
        for i=1,#w.traffic do local q=w.traffic[i]
            if q~=except and (kind=='car')==(q.kind=='car') then
                local gap
                if kind=='car' then
                    local diff=abs(heading-q.facing)
                    gap=diff==0 and .76 or diff==4 and .36 or .59
                else gap=Nav.radius[kind]+Nav.radius[q.kind]+.12 end
                local dx,dy=x-q.x,y-q.y
                if dx*dx+dy*dy<gap*gap then return false end
            end
        end
        return true
    end
    local function positioned(w,n,e,progress)
        local ax,ay=xy(e.cell);local bx,by=xy(e.next_cell);local dx,dy=bx-ax,by-ay
        local x,y,fx,fy=ax+dx*progress,ay+dy*progress,dx,dy
        if e.kind=='car' then
            local ix,iy=Nav.dx[e.incoming+1],Nav.dy[e.incoming+1]
            if e.incoming~=e.heading and progress<.4 then
                local t=progress/.4;local u=1-t
                local sx,sy=ax-iy*.21,ay+ix*.21
                local ex,ey=ax+dx*.4-dy*.21,ay+dy*.4+dx*.21
                local cx,cy=sx+ix*.3,sy+iy*.3
                x=u*u*sx+2*u*t*cx+t*t*ex;y=u*u*sy+2*u*t*cy+t*t*ey
                fx=u*(cx-sx)+t*(ex-cx);fy=u*(cy-sy)+t*(ey-cy)
            else x=x-dy*.21;y=y+dx*.21 end
        end
        return x,y,facing(fx,fy)
    end
    local function spawn(w,n,kind,home,destination,path,start,duration)
        local next=path[1];if not next then return nil end
        local x,y=xy(start);local bx,by=xy(next);local heading=facing(bx-x,by-y)
        if kind=='car' then x=x-Nav.dy[heading+1]*.21;y=y+Nav.dx[heading+1]*.21 end
        if not clear(w,kind,x,y,heading) then return nil end
        local s=w.traffic_state
        local e={id=s.next_id,kind=kind,home=home,destination=destination,phase=1,cell=start,next_cell=0,progress=0,path=path,path_index=1,path_generation=n.generation,heading=heading,incoming=heading,facing=heading,x=x,y=y,z=kind=='car' and Nav.height(w,n,x,y,start) or 0,state=kind=='boat' and 'dock' or 'travel',wait=kind=='boat' and 1800 or 0,waited_cell=0,age=0,duration=duration or 0,animation_time=0,exit_progress=0,retry=0,blocked=0,goal=path[#path]}
        s.next_id=s.next_id+1;w.traffic[#w.traffic+1]=e;T.remember_position(e);T.render(e)
        return e
    end
    function T.position(w,e)
        if e.next_cell~=0 then return positioned(w,navigation(w),e,e.progress) end
        local x,y=xy(e.cell)
        if e.kind=='car' then return x-Nav.dy[e.heading+1]*.21,y+Nav.dx[e.heading+1]*.21 end
        if e.state=='exit' then
            local dx,dy=x==0 and -1 or x==23 and 1 or 0,y==0 and -1 or y==23 and 1 or 0
            if dx~=0 then dy=0 end
            return x+dx*e.exit_progress,y+dy*e.exit_progress
        end
        return x,y
    end
    local function target(w,n,e)
        if e.kind=='car' then
            local k=e.phase==1 and e.destination or e.home;local p=n.places[k]
            local valid=p and #p.car>0 and (e.phase==1 and not (p.id>=11 and p.id<=16) or e.phase==2 and p.id>=11 and p.id<=16)
            if valid then return p.car,k+1000 end
            e.phase=2
            p=n.places[e.home]
            if p and p.id>=11 and p.id<=16 and #p.car>0 then return p.car,e.home+1000 end
            if #n.homes>0 then e.home=n.homes[(e.id-1)%#n.homes+1];return n.places[e.home].car,e.home+1000 end
        elseif e.kind=='boat' then
            local k=e.phase==1 and e.destination or e.home
            local p=n.places[k]
            if p and #p.boat>0 then return p.boat,k+2000 end
            if e.phase==1 and e.destination==0 then return n.boundary.boat,3000 end
            e.phase=2
            if #n.ports>0 then e.home=n.ports[(e.id-1)%#n.ports+1];return n.places[e.home].boat,e.home+2000 end
            e.destination=0;e.phase=1;return n.boundary.boat,3000
        else
            local waters=n.waters[e.kind];if #waters==0 then return nil end
            local s=w.traffic_state;local x,y=xy(e.cell);local k
            for attempt=1,8 do
                local candidate=waters[random(s,#waters)+1];local xx,yy=xy(candidate);local distance=abs(x-xx)+abs(y-yy)
                if distance>=2 and distance<=(e.kind=='fish' and 7 or 18) then k=candidate;break end
            end
            if k then w.traffic_targets[1]=k;return w.traffic_targets,k+4000 end
        end
        return nil
    end
    local function plan(w,n,e,budget)
        if e.next_cell~=0 or e.state=='exit' or e.wait>0 then return budget end
        if e.path and e.path_generation==n.generation then return budget end
        if e.retry>w.traffic_state.time and e.path_generation==n.generation then return budget end
        local targets,key=target(w,n,e)
        e.retry=w.traffic_state.time+2000;e.path_generation=n.generation
        if not targets or #targets==0 then return budget end
        local path,_,finish
        path,_,finish,budget=Nav.route(n,e.kind,e.cell,targets,e.cell,key,budget)
        if path then e.path=path;e.path_index=1;e.goal=finish;e.state='travel';e.blocked=0 end
        return budget
    end
    local function spawn_car(w,n,budget)
        local s=w.traffic_state;s.car_due=s.time+1200
        if count(w,'car')>=min(8,max(1,floor(w.population/8))) or w.population==0 or #n.homes==0 or #n.destinations==0 then return budget end
        local home=n.homes[random(s,#n.homes)+1];local busy=0
        for i=1,#w.traffic do if w.traffic[i].kind=='car' and w.traffic[i].home==home then busy=busy+1 end end
        if busy>=max(1,min(8,floor(Catalog[w.bid[home]][7]/8))) then return budget end
        local destination=n.destinations[random(s,#n.destinations)+1]
        local path,start,finish
        path,start,finish,budget=Nav.route(n,'car',n.places[home].car,n.places[destination].car,home+1000,destination+1000,budget)
        if path and #path>0 and spawn(w,n,'car',home,destination,path,start) then s.car_due=s.time+3000 end
        return budget
    end
    local function spawn_boat(w,n,budget)
        local s=w.traffic_state;s.boat_due=s.time+4000
        if count(w,'boat')>=4 or #n.ports==0 then return budget end
        local home=n.ports[random(s,#n.ports)+1];local destination=0
        if #n.ports>1 then
            local index=random(s,#n.ports)+1;destination=n.ports[index]
            if destination==home then destination=n.ports[index%#n.ports+1] end
        end
        for i=1,#w.traffic do local e=w.traffic[i]
            if e.kind=='boat' and (e.home==home or e.destination==home or destination>0 and (e.home==destination or e.destination==destination)) then return budget end
        end
        local targets=destination==0 and n.boundary.boat or n.places[destination].boat
        if #targets==0 then return budget end
        local path,start,finish
        path,start,finish,budget=Nav.route(n,'boat',n.places[home].boat,targets,home+2000,destination==0 and 3000 or destination+2000,budget)
        if path and #path>0 and spawn(w,n,'boat',home,destination,path,start) then s.boat_due=s.time+11000+random(s,6001) end
        return budget
    end
    local function spawn_fauna(w,n,kind,budget)
        local s=w.traffic_state;local due=kind..'_due';s[due]=s.time+(kind=='fish' and 2500 or 5000)
        if count(w,kind)>=caps[kind] then return budget end
        local waters=n.waters[kind];if #waters<8 then return budget end
        local start=waters[random(s,#waters)+1];local x,y=xy(start);local destination
        for attempt=1,12 do
            local k=waters[random(s,#waters)+1];local xx,yy=xy(k);local distance=abs(xx-x)+abs(yy-y)
            if distance>=(kind=='fish' and 2 or kind=='dolphin' and 6 or 8) and distance<=(kind=='fish' and 7 or 18) then destination=k;break end
        end
        if not destination or not clear(w,kind,x,y,0) then return budget end
        w.traffic_targets[1]=destination
        local path,origin,finish
        path,origin,finish,budget=Nav.route(n,kind,start,w.traffic_targets,start,destination+4000,budget)
        if path and #path>0 then
            local duration=kind=='fish' and 16000+random(s,8001) or kind=='dolphin' and 10000 or 18000
            if spawn(w,n,kind,0,0,path,start,duration) then
                s[due]=s.time+(kind=='fish' and 2500 or kind=='dolphin' and 45000+random(s,45001) or 180000+random(s,180001))
            end
        end
        return budget
    end
    local function schedule(w,n)
        local s=w.traffic_state;local budget=2;local total=#w.traffic
        for offset=1,total do
            local i=(s.cursor+offset-2)%total+1;local e=w.traffic[i]
            if not e.path or e.path_generation~=n.generation then
                local before=budget;budget=plan(w,n,e,budget)
                if budget<before then s.cursor=i%max(1,total)+1;break end
            end
        end
        for offset=1,5 do
            if budget==0 then break end
            local i=(s.spawn_cursor+offset-2)%5+1;local kind=kinds[i]
            if s.time>=s[kind..'_due'] then
                if kind=='car' then budget=spawn_car(w,n,budget)
                elseif kind=='boat' then budget=spawn_boat(w,n,budget)
                else budget=spawn_fauna(w,n,kind,budget) end
            end
        end
        s.spawn_cursor=s.spawn_cursor%5+1
    end
    local function intersection(w,n,e,next,heading)
        if n.degree[next]<3 and n.degree[e.cell]<3 and heading==e.heading then return true end
        for i=1,#w.traffic do local q=w.traffic[i]
            if q~=e and q.kind=='car' then
                if n.degree[next]>=3 and (q.next_cell==next or q.cell==next and (q.next_cell==0 or q.progress<.65)) then return false end
                if q.cell==e.cell and q.next_cell~=0 and q.progress<.65 then return false end
            end
        end
        return true
    end
    local function arrived(e)
        e.path=nil;e.path_index=1;e.next_cell=0;e.progress=0;e.retry=0
        if e.kind=='car' then e.state='dock';e.wait=e.phase==1 and 1800 or 600
        elseif e.kind=='boat' then
            if e.destination==0 and e.phase==1 then e.state='exit';e.exit_progress=0
            else e.state='dock';e.wait=2200 end
        else e.state='wait' end
    end
    local function exit(w,e,dt)
        local x,y=xy(e.cell);local dx,dy=x==0 and -1 or x==23 and 1 or 0,y==0 and -1 or y==23 and 1 or 0
        if dx~=0 then dy=0 end
        e.exit_progress=e.exit_progress+speed.boat*dt;e.x=x+dx*e.exit_progress;e.y=y+dy*e.exit_progress;e.facing=facing(dx,dy)
        e.animation_time=(e.animation_time+dt)%120000
        return e.exit_progress>=1.8
    end
    local function move(w,n,e,dt)
        if e.path_generation~=n.generation then e.path=nil;e.retry=0 end
        if e.next_cell==0 then
            if not e.path then e.state='wait';return end
            local next=e.path[e.path_index]
            if not next then arrived(e);return end
            if not Nav.edge(n,e.kind,e.cell,next) then e.path=nil;e.state='wait';e.retry=0;return end
            local ax,ay=xy(e.cell);local bx,by=xy(next);local heading=facing(bx-ax,by-ay)
            if e.kind=='car' then
                if e.waited_cell~=e.cell and (n.degree[e.cell]>=3 or heading~=e.heading) then
                    e.wait=250;e.waited_cell=e.cell;e.state='wait';return
                end
                if not intersection(w,n,e,next,heading) then e.state='wait';return end
            end
            e.incoming=e.heading;e.heading=heading
            e.next_cell=next;e.progress=0;e.path_index=e.path_index+1
        end
        if not Nav.edge(n,e.kind,e.cell,e.next_cell) then e.path=nil;e.state='wait';return end
        local ax,ay=xy(e.cell);local bx,by=xy(e.next_cell)
        local length=ax~=bx and ay~=by and 1.4142135623730951 or 1
        local progress=min(1,e.progress+dt*speed[e.kind]/length)
        local x,y,d=positioned(w,n,e,progress)
        if not clear(w,e.kind,x,y,d,e) then e.blocked=e.blocked+dt;e.state='wait';return end
        e.x=x;e.y=y;e.facing=d;e.progress=progress;e.state='travel';e.blocked=0
        e.z=e.kind=='car' and Nav.height(w,n,x,y,progress<.5 and e.cell or e.next_cell) or 0
        e.animation_time=(e.animation_time+dt)%120000
        if progress==1 then e.cell=e.next_cell;e.next_cell=0;e.progress=0;e.waited_cell=0 end
    end
    function W.traffic_step(w,dt)
        local s=w.traffic_state;s.step=s.step+dt
        if s.step<50 then return end
        s.step=s.step-50;s.time=s.time+50;s.plan_clock=s.plan_clock+50
        local n=navigation(w)
        if s.plan_clock>=500 then s.plan_clock=s.plan_clock-500;schedule(w,n) end
        for i=#w.traffic,1,-1 do
            local e=w.traffic[i];local remove=false;e.age=e.age+50
            T.remember_position(e)
            if e.kind~='car' and e.kind~='boat' and e.age>=e.duration then remove=true
            elseif e.state=='exit' then remove=exit(w,e,50)
            elseif e.wait>0 then
                e.wait=max(0,e.wait-50)
                if e.wait==0 and e.state=='dock' then
                    if e.kind=='boat' and e.path then e.state='travel'
                    elseif e.phase==2 then remove=true
                    else e.phase=2;e.path=nil;e.retry=0;e.state='wait' end
                end
            else move(w,n,e,50) end
            if remove then table.remove(w.traffic,i) else T.render(e) end
        end
    end
    local old_new=W.new
    W.new=function(seed,free) return T.init(old_new(seed,free)) end
    local function overlap(w,x,y,nx,ny)
        for i=1,#w.traffic do local e=w.traffic[i];local r=Nav.radius[e.kind]
            if e.x+r+.5>x and e.y+r+.5>y and e.x-r+.5<x+nx and e.y-r+.5<y+ny then return true end
            if e.next_cell~=0 then local xx,yy=xy(e.next_cell)
                if xx+r+.5>x and yy+r+.5>y and xx-r+.5<x+nx and yy-r+.5<y+ny then return true end
            end
        end
        return false
    end
    local old_valid=W.valid
    W.valid=function(w,id,x,y,r,ignore_cost)
        local ok,msg=old_valid(w,id,x,y,r,ignore_cost);if not ok then return ok,msg end
        local nx,ny=W.footprint(id,r)
        if w.traffic and #w.traffic>0 and overlap(w,x,y,nx,ny) then return false,I18n.t('Aguarde o transito liberar este espaco') end
        return ok,msg
    end
    local old_remove=W.remove
    W.remove=function(w,x,y)
        local k=w.occ[W.cell(x,y)]
        if k>0 and (w.bid[k]==3 or w.bid[k]==4 or w.bid[k]==6) then
            local nx,ny=W.footprint(w.bid[k],w.rot[k]);local xx,yy=xy(k)
            if overlap(w,xx,yy,nx,ny) then return false,I18n.t('Aguarde o veiculo sair desta via') end
        end
        return old_remove(w,x,y)
    end
    local function safe(w)
        local n=P.refresh(w)
        for i=1,#w.traffic do local e=w.traffic[i]
            if e.kind=='car' then
                local a=w.occ[e.cell];local id=a>0 and w.bid[a] or 0
                if not (id==3 or id==4 or id==6) or not n.walk[e.cell] then return false end
                if e.next_cell~=0 then
                    a=w.occ[e.next_cell];id=a>0 and w.bid[a] or 0
                    if not (id==3 or id==4 or id==6) or not P.edge(w,e.cell,e.next_cell) then return false end
                end
                local cell=e.next_cell~=0 and e.progress>=.5 and e.next_cell or e.cell
                if abs(e.z-Nav.height(w,n,e.x,e.y,cell))>1e-8 then return false end
            else
                if not Nav.water(w,e.x,e.y,Nav.radius[e.kind]) then return false end
                if e.next_cell~=0 then local x,y=xy(e.next_cell);if not Nav.water(w,x,y,Nav.radius[e.kind]) then return false end end
            end
        end
        return true
    end
    local old_terraform=W.terraform
    W.terraform=function(w,tool,x,y,radius,reference,dx,dy,stroke)
        if #w.traffic==0 then return old_terraform(w,tool,x,y,radius,reference,dx,dy,stroke) end
        local heights=w.traffic_heights or {};w.traffic_heights=heights
        for k=1,625 do heights[k]=w.h[k] end
        local ok,msg=old_terraform(w,tool,x,y,radius,reference,dx,dy,stroke)
        if not ok or safe(w) then return ok,msg end
        for k=1,625 do w.h[k]=heights[k] end
        W.rebuild(w);return false,I18n.t('Aguarde a travessia antes de mudar esta costa ou via')
    end
    local old_restore=W.restore
    W.restore=function(w,s)
        if #w.traffic==0 then return old_restore(w,s) end
        local previous=W.snapshot(w);local valid={}
        for i=1,#w.people do local p=w.people[i];valid[i]=p.path_revision==w.revision and p.path_lots==w.lot_revision end
        local ok,msg=old_restore(w,s)
        if not ok or safe(w) then return ok,msg end
        old_restore(w,previous)
        for i=1,#w.people do local p=w.people[i];p.path_revision=valid[i] and w.revision or -1;p.path_lots=valid[i] and w.lot_revision or -1 end
        return false,I18n.t('Aguarde o transito liberar o terreno antes de desfazer')
    end
end
return T

end)()
local TrafficStore=(function()
local S={}
local floor,abs=math.floor,math.abs
local states={'travel','wait','dock','exit'}
local function code(values,value) for i=1,#values do if values[i]==value then return i end end;return 0 end
function S.install(W,Traffic,Nav,P)
    local old_encode,old_decode=W.encode,W.decode
    function W.encode(w)
        local out={};local n=W.traffic_navigation(w);local s=w.traffic_state
        local function put(...) for i=1,select('#',...) do out[#out+1]=string.format('%.17g',select(i,...)) end end
        local function path(p,index,previous)
            if not p then out[#out+1]='n';return end
            local encoded={'p'}
            for i=index,#p do
                local k=p[i];local ax,ay=(previous-1)%24,floor((previous-1)/24);local bx,by=(k-1)%24,floor((k-1)/24);local direction='?'
                for d=1,8 do if Nav.dx[d]==bx-ax and Nav.dy[d]==by-ay then direction=string.char(47+d);break end end
                encoded[#encoded+1]=direction;previous=k
            end
            out[#out+1]=table.concat(encoded)
        end
        put(w.life_epoch,#w.people)
        for i=1,#w.people do local p=w.people[i]
            put(p.path_revision==w.revision and p.path_lots==w.lot_revision and 1 or 0,p.wait_reason=='route' and 1 or p.wait_reason=='home' and 2 or 0,p.home_route_failed and 1 or 0)
            path(p.path,p.path_index,p.next_cell~=0 and p.next_cell or p.cell)
        end
        put(s.rng,s.time,s.step,s.plan_clock,s.next_id,s.cursor,s.spawn_cursor,s.car_due,s.boat_due,s.fish_due,s.dolphin_due,s.whale_due,#w.traffic)
        for i=1,#w.traffic do local e=w.traffic[i]
            put(e.id,code(Traffic.kinds,e.kind),e.home,e.destination,e.phase,e.cell,e.next_cell,e.progress,e.heading,e.incoming,e.facing,e.x,e.y,e.z,code(states,e.state),e.wait,e.waited_cell,e.age,e.duration,e.animation_time,e.exit_progress,e.retry,e.blocked,e.goal,e.path_generation==n.generation and 1 or 0)
            path(e.path,e.path_index,e.next_cell~=0 and e.next_cell or e.cell)
        end
        return (old_encode(w):gsub('^MARE5','MARE6'))..'|TRAFFIC1,'..table.concat(out,',')
    end
    function W.decode(text)
        if type(text)~='string' or #text>100000 then return nil end
        if text:sub(1,6)=='MARE2,' or text:sub(1,6)=='MARE3,' or text:sub(1,6)=='MARE5,' then
            local w=old_decode(text);return w and Traffic.init(w) or nil
        end
        local version=text:sub(1,6)
        if version~='MARE4,' and version~='MARE6,' or text:find(',,',1,true) or text:sub(-1)==',' then return nil end
        local split=text:find('|TRAFFIC1,',1,true);if not split then return nil end
        local body=text:sub(split+10);if body:find('|',1,true) then return nil end
        local w=old_decode((version=='MARE4,' and 'MARE3' or 'MARE5')..text:sub(6,split-1));if not w then return nil end
        Traffic.init(w)
        local raw={};for token in body:gmatch('[^,]+') do raw[#raw+1]=token end
        local cursor,failed=1,false
        local function get(lo,hi,integer)
            local value=tonumber(raw[cursor]);cursor=cursor+1
            if not value or value~=value or value<lo or value>hi or integer and value~=floor(value) then failed=true;return lo end
            return value
        end
        local function path(previous)
            local token=raw[cursor];cursor=cursor+1
            if token=='n' then return nil end
            if not token or token:sub(1,1)~='p' or #token>577 then failed=true;return nil end
            local p={}
            for i=2,#token do
                local direction=token:byte(i)-47
                if direction<1 or direction>8 then failed=true;return nil end
                local x,y=(previous-1)%24+Nav.dx[direction],floor((previous-1)/24)+Nav.dy[direction]
                if x<0 or y<0 or x>=24 or y>=24 then failed=true;return nil end
                previous=y*24+x+1;p[#p+1]=previous
            end
            return p
        end
        w.life_epoch=get(0,1e15,true)
        if get(0,32,true)~=#w.people then return nil end
        for i=1,#w.people do local p=w.people[i]
            local valid=get(0,1,true);local reason=get(0,2,true)
            p.wait_reason=reason==1 and 'route' or reason==2 and 'home' or nil;p.home_route_failed=get(0,1,true)==1 or nil
            p.path=path(p.next_cell~=0 and p.next_cell or p.cell);p.path_index=1;p.path_revision=valid==1 and w.revision or -1;p.path_lots=valid==1 and w.lot_revision or -1
            local previous=p.next_cell~=0 and p.next_cell or p.cell
            if p.path then for j=1,#p.path do
                local k=p.path[j];local ax,ay=(previous-1)%24,floor((previous-1)/24);local bx,by=(k-1)%24,floor((k-1)/24)
                if abs(ax-bx)+abs(ay-by)~=1 or valid==1 and not P.edge(w,previous,k) then return nil end
                previous=k
            end end
        end
        local s=w.traffic_state
        s.rng=get(1,2147483646,true);s.time=get(0,1e15,true);s.step=get(0,49,true);s.plan_clock=get(0,499,true);s.next_id=get(1,100000000,true);s.cursor=get(1,20,true);s.spawn_cursor=get(1,5,true)
        s.car_due=get(0,1e15,true);s.boat_due=get(0,1e15,true);s.fish_due=get(0,1e15,true);s.dolphin_due=get(0,1e15,true);s.whale_due=get(0,1e15,true)
        if s.time%50~=0 or s.step%10~=0 or s.plan_clock%50~=0 then return nil end
        local count=get(0,20,true);local ids,counts={},{};local n=W.traffic_navigation(w)
        for i=1,count do
            local id=get(1,s.next_id-1,true);local kind=Traffic.kinds[get(1,5,true)]
            if ids[id] then return nil end;ids[id]=true
            counts[kind]=(counts[kind] or 0)+1;if counts[kind]>Traffic.caps[kind] then return nil end
            local e={id=id,kind=kind,home=get(0,576,true),destination=get(0,576,true),phase=get(1,2,true),cell=get(1,576,true),next_cell=get(0,576,true),progress=get(0,1),heading=get(0,7,true),incoming=get(0,7,true),facing=get(0,7,true),x=get(-2,25),y=get(-2,25),z=get(0,80),state=states[get(1,4,true)],wait=get(0,2200,true),waited_cell=get(0,576,true),age=get(0,1e15,true),duration=get(0,24000,true),animation_time=get(0,120000,true),exit_progress=get(0,1.8),retry=get(0,1e15,true),blocked=get(0,1e15,true),goal=get(1,576,true),path_index=1}
            e.path_generation=get(0,1,true)==1 and n.generation or -1;e.path=path(e.next_cell~=0 and e.next_cell or e.cell)
            if e.progress==1 or e.animation_time==120000 or e.exit_progress==1.8 then return nil end
            if kind=='car' or kind=='boat' then
                if e.home==0 or e.duration~=0 or kind=='car' and (e.destination==0 or e.heading%2~=0 or e.incoming%2~=0) then return nil end
            elseif e.home~=0 or e.destination~=0 or e.duration==0 or e.age>=e.duration or e.phase~=1 or e.wait>0 or e.state=='dock' or e.state=='exit' then return nil end
            if kind~='car' and e.z~=0 then return nil end
            if e.next_cell~=0 then
                if not Nav.edge(n,kind,e.cell,e.next_cell) then return nil end
                local ax,ay=(e.cell-1)%24,floor((e.cell-1)/24);local bx,by=(e.next_cell-1)%24,floor((e.next_cell-1)/24)
                if Nav.dx[e.heading+1]~=bx-ax or Nav.dy[e.heading+1]~=by-ay then return nil end
            elseif e.progress~=0 then return nil end
            local x,y=(e.cell-1)%24,floor((e.cell-1)/24)
            if e.state=='exit' then
                if kind~='boat' or e.next_cell~=0 or e.phase~=1 or e.destination~=0 or e.wait~=0 or e.path or (x~=0 and y~=0 and x~=23 and y~=23) then return nil end
            elseif e.exit_progress~=0 then return nil end
            if e.state=='dock' and (e.next_cell~=0 or e.wait==0) then return nil end
            local px,py=Traffic.position(w,e)
            if abs(e.x-px)>1e-8 or abs(e.y-py)>1e-8 then return nil end
            if kind=='car' then if not n.pass.car[e.cell] then return nil end
            elseif not Nav.water(w,e.x,e.y,Nav.radius[kind]) then return nil end
            local previous=e.next_cell~=0 and e.next_cell or e.cell
            if e.path then for j=1,#e.path do
                local k=e.path[j];local ax,ay=(previous-1)%24,floor((previous-1)/24);local bx,by=(k-1)%24,floor((k-1)/24)
                if abs(ax-bx)>1 or abs(ay-by)>1 or ax==bx and ay==by or kind=='car' and abs(ax-bx)+abs(ay-by)~=1 or e.path_generation==n.generation and not Nav.edge(n,kind,previous,k) then return nil end
                previous=k
            end end
            Traffic.remember_position(e);Traffic.render(e);w.traffic[i]=e
        end
        if failed or cursor~=#raw+1 then return nil end
        return w
    end
end
return S

end)()
local World=(function()

local W = {}
local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local N, V = 24, 25
W.N=N
local function cell(x,y) return y*N+x+1 end
local function vertex(x,y) return y*V+x+1 end
local function inside(x,y) return x>=0 and y>=0 and x<N and y<N end
local function footprint(id,r)
    local d=Catalog[id]
    if r%2==1 then return d[4],d[3] end
    return d[3],d[4]
end
W.cell=cell; W.footprint=footprint
function W.access(w,id,x,y,r)
    if id<=7 or id==35 or id==36 or id==38 then return true end
    local nx,ny=footprint(id,r);local u=0
    while u<nx do
        if (y>0 and w.road[cell(x+u,y-1)]) or (y+ny<N and w.road[cell(x+u,y+ny)]) then return true end
        u=u+1
    end
    local v=0
    while v<ny do
        if (x>0 and w.road[cell(x-1,y+v)]) or (x+nx<N and w.road[cell(x+nx,y+v)]) then return true end
        v=v+1
    end
    return false
end
local building_info={[1]='Caminhos que acompanham o relevo',[2]='Passeios e rampas para pedestres',[3]='Conecta moradias e servicos',[4]='Uma via larga para sua cidade',[5]='Atravesse canais e margens baixas',[6]='Conecte duas margens com uma via',[7]='Ligue diferentes alturas da ilha',[8]='+2 de felicidade com acesso',[9]='Balsas: receita e felicidade',[10]='Porto: 85 de receita por dia',[25]='35 de energia para a ilha',[26]='60 de energia limpa',[27]='90 de energia limpa',[28]='Agua para 150 moradores',[29]='Reciclagem para 150 moradores',[30]='Saude para 100 moradores',[31]='Educacao para 100 moradores',[32]='Seguranca para 100 moradores',[33]='Seguranca para 100 moradores',[34]='20 de receita por dia',[35]='+4 de felicidade na ilha',[36]='+4 de felicidade na ilha',[38]='Delimite jardins e recintos'}
building_info[39]='2 animais ao conectar uma via ao lado'
building_info[40]='4 animais e saude para 100 moradores; requer via ao lado'
function W.describe(id)
    local d=Catalog[id]
    if building_info[id] then return I18n.t(building_info[id]) end
    if d[7]>0 then return I18n.f('%d moradores com acesso viario',d[7]) end
    if d[8]>0 then return I18n.f('%d de receita base por dia com acesso viario',d[8]) end

    return I18n.t('Cuidados e vida para sua ilha')
end
function W.rebuild(w)
    local i=1
    while i<=N*N do
        local x=(i-1)%N; local y=floor((i-1)/N);local k=vertex(x,y)
        local a,b,c,d=w.h[k],w.h[k+1],w.h[k+V+1],w.h[k+V]
        local lo=min(a,b,c,d);local hi=max(a,b,c,d)
        w.base[i]=lo;w.mask[i]=(a>lo and 1 or 0)+(b>lo and 2 or 0)+(c>lo and 4 or 0)+(d>lo and 8 or 0)
        w.top[i]=hi;w.occ[i]=0;w.road[i]=false
        i=i+1
    end
    i=1
    while i<=N*N do
        local id=w.bid[i]
        if id>0 then
            local nx,ny=footprint(id,w.rot[i]);local x=(i-1)%N;local y=floor((i-1)/N);local v=0
            while v<ny do local u=0
                while u<nx do local j=cell(x+u,y+v);w.occ[j]=i;w.road[j]=id<=7;u=u+1 end
                v=v+1
            end
        end
        i=i+1
    end

    local pop,power,need,income,upkeep,parks,animals,roads,shops,count=0,0,0,0,0,0,0,0,0,0
    local water,health,school,waste,safety,transit,pollution=0,0,0,0,0,0,0
    i=1
    while i<=N*N do
        local id=w.bid[i]
        if id>0 then
            local d=Catalog[id];local nx,ny=footprint(id,w.rot[i]);local x=(i-1)%N;local y=floor((i-1)/N)
            local linked=id<=7 or id==35 or id==36 or id==38;local u=0
            while u<nx and not linked do
                linked=(y>0 and w.road[cell(x+u,y-1)]) or (y+ny<N and w.road[cell(x+u,y+ny)]);u=u+1
            end
            local v=0
            while v<ny and not linked do
                linked=(x>0 and w.road[cell(x-1,y+v)]) or (x+nx<N and w.road[cell(x+nx,y+v)]);v=v+1
            end
            w.linked[i]=linked
            count=count+1;upkeep=upkeep+d[6]
            if id<=7 then roads=roads+nx*ny end
            if linked then
                pop=pop+d[7];income=income+d[8]
                if d[7]>0 then need=need+max(1,floor(d[7]/4)) end
                if id>=28 and id<=34 then need=need+3 elseif id==39 or id==40 then need=need+2 elseif id>=8 and id<=10 then need=need+1 end
                if id>=17 and id<=24 then shops=shops+1;need=need+2 end
                if id==8 then transit=transit+2 elseif id==9 then transit=transit+5;income=income+35
                elseif id==10 then income=income+85 elseif id==34 then income=income+20 end
                if id==24 then pollution=pollution+2 elseif id==25 then pollution=pollution+1 end
                if id==25 then power=power+35 elseif id==26 then power=power+60 elseif id==27 then power=power+90 end
                if id==28 then water=water+150 elseif id==29 then waste=waste+150 elseif id==30 or id==40 then health=health+100 elseif id==31 then school=school+100 elseif id==32 or id==33 then safety=safety+100 end
            end
            if id==35 or id==36 then parks=parks+1 end
            if linked then if id==39 then animals=animals+2 elseif id==40 then animals=animals+4 end end
        end
        i=i+1
    end
    local happiness=60+min(20,parks*4)+(shops>0 and 5 or 0)+min(10,transit)-max(0,pollution-(waste>0 and 4 or 0))
    if need>power then happiness=happiness-25 end
    if pop>40 and water<pop then happiness=happiness-8 end
    if pop>60 and health<pop then happiness=happiness-8 end
    if pop>80 and waste<pop then happiness=happiness-6 end
    if pop>80 and school<pop then happiness=happiness-6 end
    if pop>120 and safety<pop then happiness=happiness-6 end
    happiness=min(100,max(10,happiness))
    w.population=pop;w.power=power;w.need=need;w.happy=happiness;w.animals=animals;w.parks=parks;w.roads=roads;w.shops=shops;w.count=count
    w.upkeep=upkeep;w.revenue=floor(pop*happiness/100)+floor(income*(need<=power and 1 or 1/2))+25
    w.balance=w.revenue-upkeep;w.water=water;w.health=health;w.school=school;w.waste=waste;w.safety=safety

    w.drawlist=w.drawlist or {};local commands=w.drawlist;local n=0;i=1
    while i<=N*N do
        local x=(i-1)%N;local y=floor((i-1)/N);local id=w.bid[i]
        if w.top[i]>0 then n=n+1;commands[n]=(x+y)*4096+i end

        if w.top[i]==0 then n=n+1;commands[n]=(x+y)*4096+1024+i end
        if id>0 then local nx,ny=footprint(id,w.rot[i]);n=n+1;commands[n]=(x+y+nx+ny-2)*4096+2048+i
        elseif w.occ[i]==0 and w.deco[i]>0 and w.base[i]>0 and w.mask[i]==0 then n=n+1;commands[n]=(x+y)*4096+2048+i end
        i=i+1
    end
    i=n+1;while commands[i] do commands[i]=nil;i=i+1 end
    table.sort(commands)
    w.dirty=true;w.revision=w.revision+1
end
function W.new(seed,free)
    local w={h={},base={},mask={},top={},occ={},road={},bid={},rot={},linked={},deco={},reserved={},people={},cash=3200,day=1,seed=seed,free=free,revision=0,undo={},reward=0,ticks=0}
    local y=0
    while y<V do local x=0
        while x<V do
            local a=(x-11)*(x-11)/96+(y-12)*(y-12)/86
            local jitter=math.sin(x*.63+seed*.017)*math.cos(y*.49-seed*.013)*.13
            local h=0
            if a+jitter<1 then h=1 end
            if a+jitter<62/100 then h=2 end
            if (x-10)*(x-10)+(y-7)*(y-7)<15 then h=3 end
            if (x-10)*(x-10)+(y-7)*(y-7)<4 then h=4 end
            local b=(x-20)*(x-20)+(y-4)*(y-4)
            if b<10 then h=max(h,1) end
            if x>=7 and x<=17 and y>=10 and y<=16 then h=2 end
            w.h[vertex(x,y)]=h;x=x+1
        end
        y=y+1
    end
    local pass=0
    while pass<4 do
        local yy=0
        while yy<V do local xx=0
            while xx<V do
                local k=vertex(xx,yy);local vy=max(0,yy-1)
                while vy<=min(N,yy+1) do local vx=max(0,xx-1)
                    while vx<=min(N,xx+1) do w.h[k]=min(w.h[k],w.h[vertex(vx,vy)]+1);vx=vx+1 end
                    vy=vy+1
                end
                xx=xx+1
            end
            yy=yy+1
        end
        pass=pass+1
    end
    local i=1
    while i<=N*N do w.bid[i]=0;w.rot[i]=0;w.deco[i]=((i*137+(i%24)*53+seed*11)%29<3) and 1+(i%3) or 0;i=i+1 end
    W.rebuild(w)

    local x=7
    while x<=16 do
        local j=cell(x,12)
        if w.base[j]>=1 and w.mask[j]==0 then w.bid[j]=3 end
        x=x+1
    end
    W.rebuild(w)
    local starter={{11,7,11},{12,9,13},{17,11,11},{25,14,13},{35,12,13}};i=1
    while i<=#starter do
        local id=starter[i][1];local yy=13;local placed=false
        local sx,sy=starter[i][2],starter[i][3]
        if W.valid(w,id,sx,sy,0,true) then w.bid[cell(sx,sy)]=id;W.rebuild(w);placed=true end
        while yy>=10 and not placed do local xx=7
            while xx<17 and not placed do
                local ok=W.valid(w,id,xx,yy,0,true)
                if ok then w.bid[cell(xx,yy)]=id;W.rebuild(w);placed=true end
                xx=xx+1
            end
            yy=yy-1
        end
        i=i+1
    end
    return w
end
function W.valid(w,id,x,y,r,ignore_cost)
    local nx,ny=footprint(id,r)
    if x<0 or y<0 or x+nx>N or y+ny>N then return false,I18n.t('Fora dos limites da ilha') end
    if not ignore_cost and not w.free and w.cash<W.price(w,id,x,y) then return false,I18n.t('Faltam moedas. Espere a renda ou use o modo livre.') end
    local base=w.base[cell(x,y)];local bridge=id==5 or id==6;local v=0;local coast=false
    while v<ny do local u=0
        while u<nx do
            local k=cell(x+u,y+v);local mask=w.mask[k]
            if w.occ[k]>0 then
                if id<=3 and w.bid[k]>=1 and w.bid[k]<=3 then
                    if w.bid[k]==id then return false,I18n.t('Esta via ja tem esse piso') end
                else return false,I18n.t('Este espaco ja esta ocupado') end
            end
            if not bridge then
                if base<1 or w.base[k]~=base then return false,I18n.t('Eleve e nivele o terreno primeiro') end
                if mask~=0 then
                    if id>3 and id~=7 then return false,I18n.t('Esta construcao precisa de terreno plano') end
                    if mask~=3 and mask~=6 and mask~=9 and mask~=12 then return false,I18n.t('Use Nivelar para criar uma rampa reta') end
                end
            elseif w.top[k]>1 then return false,I18n.t('Pontes atravessam agua ou margens baixas') end
            if (x+u>0 and w.base[k-1]==0) or (x+u<N-1 and w.base[k+1]==0) or (y+v>0 and w.base[k-N]==0) or (y+v<N-1 and w.base[k+N]==0) then coast=true end
            u=u+1
        end
        v=v+1
    end
    if (id==9 or id==10 or id==37) and not coast then return false,I18n.t('Escolha um terreno plano junto da agua') end
    return true,I18n.t('Pronto para construir')
end
function W.price(w,id,x,y)
    local price=Catalog[id][5]
    if id<=3 and inside(x,y) then
        local old=w.bid[cell(x,y)]
        if old>=1 and old<=3 then price=max(0,price-Catalog[old][5]) end
    end
    return price
end
function W.snapshot(w)
    local s={h={},bid={},rot={},cash=w.cash};local i=1
    while i<=V*V do s.h[i]=w.h[i];i=i+1 end
    i=1;while i<=N*N do s.bid[i]=w.bid[i];s.rot[i]=w.rot[i];i=i+1 end
    return s
end
function W.restore(w,s)
    local i=1;while i<=V*V do w.h[i]=s.h[i];i=i+1 end
    i=1;while i<=N*N do w.bid[i]=s.bid[i];w.rot[i]=s.rot[i];i=i+1 end
    w.cash=s.cash;W.rebuild(w)
end
function W.record(w,s)
    local n=#w.undo
    if n==12 then table.remove(w.undo,1) end
    w.undo[#w.undo+1]=s
end
function W.undo(w)
    local n=#w.undo
    if n==0 then return false end
    local current_cash=w.cash;local snapshot=w.undo[n]
    W.restore(w,snapshot);w.cash=max(0,current_cash+(snapshot.refund or 0));w.undo[n]=nil;return true
end
function W.build(w,id,x,y,r)
    local ok,msg=W.valid(w,id,x,y,r)
    if not ok then return false,msg end
    local price=W.price(w,id,x,y);local snapshot=W.snapshot(w);snapshot.refund=w.free and 0 or price;W.record(w,snapshot);local k=cell(x,y);w.bid[k]=id;w.rot[k]=r
    if not w.free then w.cash=w.cash-price end
    W.rebuild(w);return true,I18n.f('%s: pronto!',I18n.catalog(id)[1])
end
function W.paint(w,id,x,y)
    local k=cell(x,y)
    if w.bid[k]==id then return true end
    local ok,msg=W.valid(w,id,x,y,0)
    if not ok then return false,msg end
    local price=W.price(w,id,x,y);w.bid[k]=id;w.rot[k]=0
    if not w.free then w.cash=w.cash-price end
    W.rebuild(w);return true
end
function W.remove(w,x,y)
    local k=w.occ[cell(x,y)]
    if k==0 then return false,I18n.t('Nada para remover aqui') end
    local id=w.bid[k];local snapshot=W.snapshot(w);snapshot.refund=w.free and 0 or -floor(Catalog[id][5]*3/4);W.record(w,snapshot);w.bid[k]=0;w.rot[k]=0
    if not w.free then w.cash=w.cash+floor(Catalog[id][5]*3/4) end
    W.rebuild(w);return true,I18n.t('Removido. Reembolso de 75%.')
end



local edge_a,edge_b={},{}
do
    local y=0
    while y<V do local x=0
        while x<V do
            local k=vertex(x,y)
            if x<N then edge_a[#edge_a+1]=k;edge_b[#edge_b+1]=k+1 end
            if y<N then
                edge_a[#edge_a+1]=k;edge_b[#edge_b+1]=k+V
                if x<N then edge_a[#edge_a+1]=k;edge_b[#edge_b+1]=k+V+1 end
                if x>0 then edge_a[#edge_a+1]=k;edge_b[#edge_b+1]=k+V-1 end
            end
            x=x+1
        end;y=y+1
    end
end
local function envelope(g,values,rising)
    local step=rising and -1 or 1;local h=rising and 5 or 0;local last=rising and 1 or 4
    while rising and h>=last or not rising and h<=last do
        local i=1;local next_h=h+step
        while i<=#edge_a do
            local a,b=g.parent[edge_a[i]],g.parent[edge_b[i]]
            if a~=b then
                local ah,bh=values[a],values[b]
                if ah==h and (rising and bh<next_h or not rising and bh>next_h) then values[b]=next_h end
                if bh==h and (rising and ah<next_h or not rising and ah>next_h) then values[a]=next_h end
            end;i=i+1
        end;h=h+step
    end
end
local function terrain_groups(w,reference)
    local g={parent={},pref={},minimum={},goal={},low={},high={},touched={}}
    local p=g.parent;local i=1;while i<=V*V do p[i]=i;i=i+1 end
    local function root(k) while p[k]~=k do p[k]=p[p[k]];k=p[k] end;return k end
    local function join(a,b) a=root(a);b=root(b);if a~=b then p[max(a,b)]=min(a,b) end end
    i=1
    while i<=N*N do
        local id=reference.bid[i]
        if id>0 then
            local x,y=(i-1)%N,floor((i-1)/N);local k=vertex(x,y)
            if id<=3 or id==7 then
                local along_x=(x>0 and w.road[i-1]) or (x<N-1 and w.road[i+1])
                local along_y=(y>0 and w.road[i-N]) or (y<N-1 and w.road[i+N])
                if along_x and not along_y then join(k,k+V);join(k+1,k+V+1)
                elseif along_y and not along_x then join(k,k+1);join(k+V,k+V+1)
                elseif not along_x and not along_y then

                    local a,b,c,d=reference.h[k],reference.h[k+1],reference.h[k+V+1],reference.h[k+V]
                    if a==d and b==c and a~=b then join(k,k+V);join(k+1,k+V+1)
                    elseif a==b and c==d and a~=c then join(k,k+1);join(k+V,k+V+1)
                    else join(k,k+1);join(k,k+V);join(k,k+V+1) end
                else join(k,k+1);join(k,k+V);join(k,k+V+1) end
            else
                local nx,ny=footprint(id,reference.rot[i]);local yy=0
                while yy<=ny do local xx=0
                    while xx<=nx do join(k,vertex(x+xx,y+yy));xx=xx+1 end;yy=yy+1
                end
            end
        end;i=i+1
    end
    i=1;while i<=V*V do p[i]=root(i);local k=p[i];g.pref[k]=max(g.pref[k] or 0,reference.h[i]);g.minimum[k]=0;i=i+1 end
    i=1
    while i<=N*N do
        local id=reference.bid[i]
        if id>0 and id~=5 and id~=6 then
            local x,y=(i-1)%N,floor((i-1)/N);local nx,ny=footprint(id,reference.rot[i]);local yy=0
            while yy<=ny do local xx=0
                while xx<=nx do g.minimum[p[vertex(x+xx,y+yy)]]=1;xx=xx+1 end;yy=yy+1
            end
        end;i=i+1
    end


    i=1;while i<=V*V do if p[i]==i then g.pref[i]=max(g.minimum[i],g.pref[i]) end;i=i+1 end
    envelope(g,g.pref,true);return g
end
function W.terraform(w,tool,x,y,radius,reference,dx,dy,stroke)
    local g=stroke and stroke.graph or terrain_groups(w,reference)
    if stroke and not g then g=terrain_groups(w,reference) end
    if stroke then stroke.graph=g;stroke.visited=stroke.visited or {};stroke.pending_visits=stroke.pending_visits or {} end
    local visits=stroke and stroke.visited;local target=stroke and stroke.target or reference.h[vertex(x,y)]
    local i=1
    while i<=V*V do
        local k=g.parent[i]
        if k==i then g.goal[k]=g.pref[k];g.low[k]=g.minimum[k];g.high[k]=5;g.touched[k]=false end
        i=i+1
    end
    if visits then
        local yy=max(0,y-radius-1)
        while yy<=min(N,y+radius+1) do local xx=max(0,x-radius-1)
            while xx<=min(N,x+radius+1) do
                local k=vertex(xx,yy)
                if not visits[k] and (xx-x)*(xx-x)+(yy-y)*(yy-y)<=(radius+1)*(radius+1) then
                    visits[k]=true;stroke.pending_visits[#stroke.pending_visits+1]=k
                end
                xx=xx+1
            end;yy=yy+1
        end
    end
    i=1
    while i<=V*V do
        local xx,yy2=(i-1)%V,floor((i-1)/V)
        local hit=visits and visits[i] or (not visits and (xx-x)^2+(yy2-y)^2<=(radius+1)^2)
        if hit then
            local k=g.parent[i];local h=reference.h[i]
            if tool=='raise' then h=max(g.pref[k],min(5,h+1))
            elseif tool=='lower' then h=max(0,h-1)
            elseif tool=='level' then h=target
            else h=reference.h[vertex(max(0,min(N,xx-(dx or 0))),max(0,min(N,yy2-(dy or 0))))] end
            h=max(g.minimum[k],h)
            if not g.touched[k] then g.goal[k]=h
            elseif tool=='lower' then g.goal[k]=min(g.goal[k],h)
            else g.goal[k]=max(g.goal[k],h) end
            g.touched[k]=true
        end;i=i+1
    end
    if tool=='raise' then envelope(g,g.goal,true)
    elseif tool=='lower' then envelope(g,g.goal,false)
    elseif tool=='level' then
        i=1;while i<=V*V do if g.parent[i]==i and g.touched[i] then g.low[i]=g.goal[i];g.high[i]=g.goal[i] end;i=i+1 end
        envelope(g,g.low,true);envelope(g,g.high,false)
        i=1;while i<=V*V do if g.parent[i]==i then g.goal[i]=max(g.low[i],min(g.high[i],g.pref[i])) end;i=i+1 end
    else
        i=1;while i<=V*V do if g.parent[i]==i then g.low[i]=g.goal[i];g.high[i]=g.goal[i] end;i=i+1 end
        envelope(g,g.low,false);envelope(g,g.high,true)
        i=1;while i<=V*V do if g.parent[i]==i then g.goal[i]=max(g.minimum[i],floor((g.low[i]+g.high[i]+1)/2)) end;i=i+1 end
        envelope(g,g.goal,true)
    end
    i=1;while i<=V*V do w.h[i]=g.goal[g.parent[i]];i=i+1 end
    W.rebuild(w);return true,I18n.t('Relevo e fundacoes ajustados')
end
function W.elevation(w,id,x,y,r)
    local h=w.base[cell(x,y)]
    if id==5 or id==6 then
        local nx,ny=footprint(id,r);nx=min(nx,N-x);ny=min(ny,N-y);local v=0;h=1
        while v<ny do local u=0;while u<nx do h=max(h,w.top[cell(x+u,y+v)]);u=u+1 end;v=v+1 end
    end
    return h
end
local goals={
    {'Um lugar para chamar de seu','Chegue a 20 moradores',500},
    {'A ilha funciona','40 moradores, energia suficiente',750},
    {'A vida la fora','3 pracas ou mirantes e 2 comercios',1000},
    {'Amigos de todas as especies','Tenha 6 animais e uma clinica',1250},
    {'Uma pequena grande ilha','100 moradores e 80% de felicidade',2000}
}
W.goals=goals
function W.progress(w)
    local g=w.reward+1
    if g==1 then return min(1,w.population/20) end
    if g==2 then return min(1,w.population/40,w.power/max(1,w.need)) end
    if g==3 then return min(1,w.parks/3,w.shops/2) end
    if g==4 then return min(1,w.animals/6,w.health>0 and 1 or 0) end
    if g==5 then return min(1,w.population/100,w.happy/80) end
    return 1
end
function W.goal_ready(w)
    local g=w.reward+1
    if g==1 then return w.population>=20 end
    if g==2 then return w.population>=40 and w.power>=w.need end
    if g==3 then return w.parks>=3 and w.shops>=2 end
    if g==4 then return w.animals>=6 and w.health>0 end
    if g==5 then return w.population>=100 and w.happy>=80 end
    return false
end
function W.tick(w)
    w.day=w.day+1;w.cash=max(0,w.cash+w.balance);w.ticks=w.ticks+1
    if not w.free and w.cash==0 and w.balance<0 then w.cash=300;return I18n.t('Fundo de apoio: +300 moedas para recuperar a ilha.') end
end
function W.claim(w)
    if not W.goal_ready(w) then return false end
    w.reward=w.reward+1;w.cash=w.cash+goals[w.reward][3];return true
end
function W.encode(w)
    local out={'MARE2',w.seed,w.free and 1 or 0,w.cash,w.day,w.reward};local i=1
    while i<=V*V do out[#out+1]=w.h[i];i=i+1 end
    i=1;while i<=N*N do out[#out+1]=w.bid[i];out[#out+1]=w.rot[i];i=i+1 end
    return table.concat(out,',')
end
function W.decode(text)
    if type(text)~='string' or #text>20000 then return nil end
    local values={};for token in string.gmatch(text,'[^,]+') do values[#values+1]=token end
    if #values~=6+V*V+N*N*2 or values[1]~='MARE2' then return nil end
    local i=2
    while i<=#values do
        local n=tonumber(values[i]);if not n or n~=floor(n) or n<0 or n>100000000 then return nil end
        values[i]=n;i=i+1
    end
    if values[3]>1 or values[6]>5 or values[5]<1 then return nil end
    local w={h={},base={},mask={},top={},occ={},road={},bid={},rot={},linked={},deco={},reserved={},people={},seed=values[2],free=values[3]==1,cash=values[4],day=values[5],reward=values[6],undo={},revision=0,ticks=0}
    i=1;while i<=V*V do if values[6+i]>5 then return nil end;w.h[i]=values[6+i];i=i+1 end
    local used={};i=1
    while i<=N*N do
        local p=7+V*V+(i-1)*2;local id,r=values[p],values[p+1]
        if id>40 or r>3 then return nil end
        if id>0 then
            local x=(i-1)%N;local y=floor((i-1)/N);local nx,ny=footprint(id,r)
            if x+nx>N or y+ny>N then return nil end
            local v=0;while v<ny do local u=0
                while u<nx do local j=cell(x+u,y+v);if used[j] then return nil end;used[j]=true;u=u+1 end;v=v+1
            end
        end
        w.bid[i]=id;w.rot[i]=r;w.deco[i]=((i*137+(i%24)*53+w.seed*11)%29<3) and 1+(i%3) or 0;i=i+1
    end
    local y=0
    while y<N do local x=0
        while x<N do local k=vertex(x,y)
            if max(w.h[k],w.h[k+1],w.h[k+V],w.h[k+V+1])-min(w.h[k],w.h[k+1],w.h[k+V],w.h[k+V+1])>1 then return nil end
            x=x+1
        end;y=y+1
    end
    W.rebuild(w);return w
end
Life.install(W,Catalog,Paths,Activities,Appearance,InteractionAnchors)
Traffic.install(W,Catalog,Paths,TrafficPaths)
TrafficStore.install(W,Traffic,TrafficPaths,Paths)
local terraform=W.terraform
W.terraform=function(w,tool,x,y,radius,reference,dx,dy,stroke)
    local ok,msg=terraform(w,tool,x,y,radius,reference,dx,dy,stroke)
    if stroke then
        for i=#stroke.pending_visits,1,-1 do
            if not ok then stroke.visited[stroke.pending_visits[i]]=nil end
            stroke.pending_visits[i]=nil
        end
    end
    return ok,msg
end
return W

end)()
local Lighting=(function()



local L={revision=-1,bin=-1}
local floor,min,max=math.floor,math.min,math.max
local R,N=8,192
local phases={'Ciclo natural','Manha','Golden hour','Noite'}
L.names=phases
local function ground(w,x,y)
    local xx=min(23,max(0,floor(x)));local yy=min(23,max(0,floor(y)))
    local u=x-xx;local v=y-yy;local k=yy*25+xx+1
    local a,b,c,d=w.h[k],w.h[k+1],w.h[k+26],w.h[k+25]
    if u>=v then return (a+u*(b-a)+v*(c-b))*16 end
    return (a+u*(c-d)+v*(d-a))*16
end
L.ground=ground
function L.phase(mode,time)
    if mode==2 then return .31 elseif mode==3 then return .72 elseif mode==4 then return .91 end
    return (time/360000+.31)%1
end
function L.prepare(w,detail)
    R=detail==1 and 8 or 4;N=24*R;L.R=R;L.N=N
    local h=L.height or {};local g=L.groundmap or {};L.height=h;L.groundmap=g
    local previous=L.vertices or {};L.vertices=previous
    local changed=L.changed or {};L.changed=changed;local all=L.detail~=detail;local i=1
    while i<=576 do changed[i]=all;i=i+1 end
    i=1
    while i<=625 do
        if previous[i]~=w.h[i] then
            previous[i]=w.h[i];local vx=(i-1)%25;local vy=floor((i-1)/25)
            local y=max(0,vy-1)
            while y<=min(23,vy) do local x=max(0,vx-1)
                while x<=min(23,vx) do changed[y*24+x+1]=true;x=x+1 end
                y=y+1
            end
        end;i=i+1
    end

    i=1
    while i<=576 do
        if changed[i] then
            local xx=(i-1)%24;local yy=floor((i-1)/24);local y=0
            while y<R do local x=0
                while x<R do local k=(yy*R+y)*N+xx*R+x+1;g[k]=ground(w,xx+(x+.5)/R,yy+(y+.5)/R);x=x+1 end
                y=y+1
            end
        end;i=i+1
    end
    i=1;while i<=N*N do h[i]=g[i];i=i+1 end
    L.revision=w.revision;L.detail=detail;L.world=w;L.bin=-1
end
function L.update(w,phase,detail)
    if L.world~=w or L.revision~=w.revision or L.detail~=detail then L.prepare(w,detail) end
    local daylight=phase>.18 and phase<.79
    local bin=daylight and floor(phase*48) or -2
    if bin==L.bin then return false end
    L.bin=bin;L.rebuilds=(L.rebuilds or 0)+1
    local masks=L.masks or {};L.masks=masks
    if not daylight then local i=1;while i<=576 do masks[i]='';i=i+1 end;return true end
    local sun=((bin+.5)/48-.18)/.61
    local angle=-math.pi*.92+sun*math.pi*1.1
    local dx,dy=math.cos(angle),math.sin(angle)
    local altitude=.33+math.sin(sun*math.pi)*1.8
    local major=max(math.abs(dx),math.abs(dy));dx=dx/major;dy=dy/major
    local drop=16/R*altitude/major
    local horizon=L.horizon or {};L.horizon=horizon
    local shaded=L.shaded or {};L.shaded=shaded

    local horizontal=math.abs(dx)>=math.abs(dy)
    local step=(horizontal and dx or dy)<0 and -1 or 1
    local start=step<0 and N-1 or 0
    local offset=horizontal and dy or dx;local lo=floor(-offset);local fraction=-offset-lo
    local outer=0
    while outer<N do local axis=start+outer*step;local inner=0
        while inner<N do
            local x=horizontal and axis or inner;local y=horizontal and inner or axis;local k=y*N+x+1
            local upstream=axis-step;local v0=inner+lo;local v1=v0+1;local sunheight=-100
            if upstream>=0 and upstream<N and v0>=0 and v1<N then
                local a=horizontal and v0*N+upstream+1 or upstream*N+v0+1
                local b=horizontal and v1*N+upstream+1 or upstream*N+v1+1
                sunheight=horizon[a]*(1-fraction)+horizon[b]*fraction-drop
            end
            horizon[k]=max(L.height[k],sunheight)
            shaded[k]=sunheight>L.groundmap[k]+2 and 1 or 0
            inner=inner+1
        end;outer=outer+1
    end

    local parts=L.parts or {};L.parts=parts
    local i=1
    while i<=576 do
        local xx=((i-1)%24)*R;local yy=floor((i-1)/24)*R;local n=0;local hits=0;local y=0
        while y<R do local x=0
            while x<R do n=n+1;local v=shaded[(yy+y)*N+xx+x+1];parts[n]=v==1 and '1' or '0';hits=hits+v;x=x+1 end
            y=y+1
        end
        masks[i]=hits>0 and table.concat(parts,'',1,n) or '';i=i+1
    end
    return true
end
return L

end)()
local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local app_meta={title=I18n.t('Mare'),author='Ilhas Studio',description=I18n.t('Um pedacinho de mundo, do seu jeito.'),version='0.4.0',id='studio.ilhas.mare'}
local S={screen='title',selection=1,category=1,item=1,tool='inspect',cx=11,cy=13,camx=11,camy=11,zoom=2,brush=1,rotation=0,time=0,skytime=0,light=1,elapsed=0,saveclock=0,toast='',toast_time=0,keys={},held={},sound=true,motion=true,contrast=false,slot=1,seed=2706,gesture=nil,detail=1}
local C={ink=0xF5E7C6FF,panel=0x182536FF,paper=0xF5E7C6FF,muted=0xA8B4BAFF,gold=0xD6B574FF,teal=0x99BCADFF,line=0x344354FF,red=0xE6A18CFF,dark=0x131F2DFF}
local categories={'Vias','Moradia','Comercio','Servicos','Natureza'}
local ranges={{1,10},{11,16},{17,24},{25,34},{35,40}}
local tool_names={'Construir','Terreno','Remover','Desfazer','Zonas'}
local tool_ids={'build','terrain','remove','undo','zones'}
local terrain_names={'Elevar','Baixar','Nivelar','Distorcer'}
local terrain_ids={'raise','lower','level','pull'}
local terrain_notes={'Pinte um nivel acima. As construcoes sobem junto.','Pinte um nivel abaixo. As vias se acomodam.','Copie uma altura e pinte o terreno com as setas.','Segure a costa e puxe. As fundacoes acompanham.'}
local tool_notes={'Escolha uma peca e coloque direto na ilha.','Molde morros, praias e enseadas.','Libere espaco e receba 75% do custo de volta.','Desfaca uma construcao, remocao ou gesto inteiro.'}
tool_notes[5]='Autorize bairros; moradores chegam e constroem.'
local zone_names={'Moradia','Comercio','Servicos','Apagar zona'}
local zone_notes={'Casas: acesso, energia e lojas sustentam novos moradores.','Lojas: atendem moradores e permitem mais casas.','Clinicas: lotes 2x1 para moradores sem cobertura.','Retira autorizacao e cancela obras; nao demole edificios.'}
local zone_colors={0x99BCADFF,0xD6B574FF,0xA4BEDCFF,0xE6A18CFF}
local site_keys={reserved='site_reserved',foundation='site_foundation',frame='site_frame'}
S.zone_kind=1
S.playing=false
local brush_names={'pequeno','medio','grande'}
local captions={inspect='Explore a ilha',raise='Elevar terreno',lower='Baixar terreno',level='Nivelar terreno',pull='Distorcer a costa',remove='Remover construcao',build='Construir',zone='Zonear bairro'}
local title_items={'Continuar','Nova ilha','Como jogar','Ajustes'}
local pause_items={'Continuar jogando','Salvar a ilha','Diario da ilha','Ajustes','Como jogar','Contemplar a ilha','Salvar e ir ao inicio'}
local context_road_names={'Trocar via','Concluir'}
local context_build_names={'Girar peca','Trocar peca','Concluir'}
local context_zone_names={'Trocar uso','Concluir'}
local context_terrain_names={'Pincel','Trocar ferramenta','Concluir'}
local settings_notes={'Sons curtos ao navegar e construir.','Reduz ondas, passaros e animacoes.','Ajusta vegetacao e custo das sombras.','Pixels inteiros nas duas distancias.','Escolha um momento do dia.','Escolha Portugues, English ou Deutsch. A troca e imediata.','Salva as preferencias neste dispositivo.'}
local language_codes={'pt','en','de'}
local language_names={pt='Portugu\195\170s',en='English',de='Deutsch'}
local menu_lengths={title=4,new=5,confirm=2,load=3,pause=7,settings=7}
local function text(std,x,y,str,size,col,width,face)
    return Platform.text(x,y,tostring(str),size or 30,col or C.paper,width or max(40,1212-x),face or 'body')
end
local function title(std,x,y,str,size,col,width)
    return text(std,x,y,I18n.upper(str),size or 40,col or C.paper,width,'display')
end
local paragraph_lines,toast_lines,pause_toast_lines={},{},{}
local function wrap_lines(out,str,size,width)
    local row='';local count=0
    for word in str:gmatch('%S+') do
        local nextrow=row=='' and word or row..' '..word
        if row~='' and Platform.text_width(nextrow,size,'body')>width then
            count=count+1;out[count]=row;row=word
        else row=nextrow end
    end
    if row~='' then count=count+1;out[count]=row end
    for i=count+1,#out do out[i]=nil end
    return count
end
local function paragraph(std,x,y,str,size,col,width)
    local count=wrap_lines(paragraph_lines,str,size,width)
    for i=1,count do text(std,x,y+(i-1)*(size+6),paragraph_lines[i],size,col,width) end
    return y+max(1,count)*(size+6)
end
local function box(std,x,y,w,h,col)
    if w>=40 and h>=32 then
        local kind=col==C.panel and 'panel' or col==C.dark and 'inset' or col==C.gold and 'focus' or col==C.line and 'button'
        if kind then Platform.skin(kind,x,y,w,h,col==C.gold,S.time,S.motion);return end
    end
    std.draw.color(col);std.draw.rect(0,x,y,w,h)
end
local function icon(name,x,y,scale) Platform.sprite('icon_'..name,x,y,scale or 2,1) end
local function line(std,x1,y1,x2,y2,col)
    std.draw.color(col);std.draw.line(x1,y1,x2,y2)
end
local function pill(std,x,y,label,focus,width)
    if focus and S.tab_focus and S.screen=='catalog' then Platform.skin('focus',x,y,width or 100,44,false,S.time,false) end
    text(std,x+12,y+6,label,28,focus and C.gold or C.muted,(width or 100)-20)
    if focus then std.draw.color(C.gold);std.draw.rect(0,x+12,y+39,(width or 100)-24,2) end
end
local function select_locale(locale)
    I18n.select(locale);S.toast='';S.toast_time=0;S.toast_height=0
    for i=1,#toast_lines do toast_lines[i]=nil end
    app_meta.description=I18n.t('Um pedacinho de mundo, do seu jeito.')
end
local function notify(msg,good)
    S.toast=msg;S.toast_time=3400;S.toast_good=good
    S.toast_height=24+wrap_lines(toast_lines,msg,26,738)*32
    wrap_lines(pause_toast_lines,msg,26,380)
    if S.sound then Platform.sound(good==false and 2 or 1) end
end
local function open(screen,selection)
    if screen=='new' and not S.preview then S.preview=World.new(S.seed,S.new_free or false) end
    S.screen=screen;S.selection=selection or 1;S.entered=S.time
    if screen=='load' then
        S.saved=S.saved or {};local i=1
        while i<=3 do
            local data=Platform.load(i);S.saved[i]=World.decode(data) or World.decode(Platform.backup(i)) or false;i=i+1
        end
    end
    if S.sound then Platform.sound(0) end
end
local function previous_save()
    local value=Platform.load(S.slot)
    return World.decode(value) and value or ''
end
local function save_game(silent)
    if S.gesture then return end
    local ok=Platform.save(S.slot,World.encode(S.world),previous_save())
    if not silent or not ok then notify(I18n.t(ok and 'Ilha salva. Pode voltar quando quiser.' or 'Nao foi possivel salvar neste dispositivo.'),ok) end
    S.has_save=ok or S.has_save;S.saveclock=0
    return ok
end
local function pos(x,y,z)
    local zoom=S.zoom
    return floor(S.ox+(x-y-S.camx+S.camy)*32*zoom),floor(S.oy+((x+y-S.camx-S.camy)*16-z)*zoom)
end
local function display_pos(x,y,z)
    return floor(S.view_x+(x-y)*32*S.view_zoom),floor(S.view_y+((x+y)*16-z)*S.view_zoom)
end
local function home_camera()
    local shift=S.world.base[World.cell(S.cx,S.cy)]/2
    S.camx=S.cx-shift;S.camy=S.cy-shift;S.world.dirty=true
end
local function road_sprite(w,i,id)
    local mask=w.mask[i]
    if mask~=0 then
        local dir=mask==3 and 'N' or mask==6 and 'E' or mask==12 and 'S' or 'W'
        return 'ramp'..id..'_'..dir
    end
    local x=(i-1)%24;local y=floor((i-1)/24);local bits=0
    local nx,ny=World.footprint(id,w.rot[i]);local u=0
    while u<nx do
        if y>0 and w.occ[World.cell(x+u,y-1)]>0 and bits%2==0 then bits=bits+1 end
        if y+ny<24 and w.occ[World.cell(x+u,y+ny)]>0 and floor(bits/4)%2==0 then bits=bits+4 end
        u=u+1
    end
    local v=0
    while v<ny do
        if x+nx<24 and w.occ[World.cell(x+nx,y+v)]>0 and floor(bits/2)%2==0 then bits=bits+2 end
        if x>0 and w.occ[World.cell(x-1,y+v)]>0 and floor(bits/8)%2==0 then bits=bits+8 end
        v=v+1
    end
    if bits==0 then bits=10 end
    return 'road'..id..'_'..bits
end
local function world_sprite(key,sx,sy,scale,alpha,lit,x,y,z)
    Platform.sprite(key,sx,sy,scale,alpha,lit)
    Platform.depth(key,sx,sy,scale,x,y,z)
end
local actors=ActorRender.new(Activities,Platform)
local function render_actors(w)
    actors:draw(w,S.motion)
end
local function render_world(std)
    local w=(S.screen=='new' or S.screen=='confirm') and S.preview or S.world
    if S.rendered_world~=w then w.dirty=true;S.rendered_world=w end
    S.phase=S.screen=='title' and .68 or Lighting.phase(S.light,S.skytime)
    if Lighting.update(w,S.phase,S.detail) then w.dirty=true end
    if w.dirty then
        Platform.cache_begin(table.concat(w.h,','),S.camx,S.camy,S.zoom,S.ox,S.oy,w.revision);S.visible=0
        local scene=S.scene or {};S.scene=scene;local sn=0;local si=1
        local sites=S.sites or {};S.sites=sites
        for i=1,576 do sites[i]=nil end
        for i=1,#w.jobs do
            local job=w.jobs[i];local nx,ny=World.footprint(job.building_id,job.rotation)
            for v=0,ny-1 do for u=0,nx-1 do sites[World.cell(job.x+u,job.y+v)]=site_keys[job.stage] end end
        end
        while si<=576 do
            local id=w.bid[si];local x=(si-1)%24;local y=floor((si-1)/24);local key
            if id>4 then key='b'..id..'_'..w.rot[si]
            elseif id==0 and w.occ[si]==0 and not sites[si] and w.deco[si]>0 and w.base[si]>0 and w.mask[si]==0 and S.detail==1 then
                key=(w.base[si]==1 and 'palm' or 'tree')..(w.deco[si]-1)
            end
            if key then sn=sn+1;scene[sn]=key..','..x..','..y..','..(World.elevation(w,id,x,y,w.rot[si])*16)..',0' end
            if id==3 and (x+y)%4==0 and w.mask[si]==0 then
                sn=sn+1;scene[sn]='lamp,'..x..','..y..','..(w.base[si]*16)..','..(w.linked[si] and w.power>=w.need and '1' or '0')
            end
            if sites[si] then sn=sn+1;scene[sn]=sites[si]..','..x..','..y..','..(w.base[si]*16)..',0' end
            si=si+1
        end
        Platform.scene(table.concat(scene,';',1,sn),S.phase,S.detail)
        local marks=S.zone_marks or {};S.zone_marks=marks;local mark_count=0
        for i=1,576 do
            if w.zones[i]>0 and w.occ[i]==0 then
                local x,y=(i-1)%24,floor((i-1)/24)
                mark_count=mark_count+1
                local mark=marks[mark_count] or {};marks[mark_count]=mark
                local z=w.base[i]*16;local mask=w.mask[i]
                mark[10],mark[11]=x,y
                mark[12],mark[13]=z+(mask%2==1 and 16 or 0),z+(floor(mask/2)%2==1 and 16 or 0)
                mark[14],mark[15]=z+(floor(mask/4)%2==1 and 16 or 0),z+(floor(mask/8)%2==1 and 16 or 0)
                mark[9]=w.zones[i]
            end
        end
        S.project_marks=true
        for i=mark_count+1,#marks do marks[i]=nil end
        S.flies=S.flies or {};local flies=S.flies;local fly_count=0
        local commands=S.render_commands or {};S.render_commands=commands
        local count=#w.drawlist
        for i=1,count do commands[i]=w.drawlist[i] end
        for i=1,576 do if sites[i] then count=count+1;commands[count]=(((i-1)%24)+floor((i-1)/24))*4096+3072+i end end
        for i=count+1,#commands do commands[i]=nil end
        table.sort(commands)
        local n=1
        while n<=#commands do
            local command=commands[n]%4096;local kind=floor(command/1024);local i=command%1024
            local x=(i-1)%24;local y=floor((i-1)/24);local id=w.bid[i]
            local base=kind==2 and id>0 and World.elevation(w,id,x,y,w.rot[i]) or w.base[i];local sx,sy=pos(x,y,base*16)
            if sx>-280 and sx<1560 and sy>-180 and sy<960 then
                if kind==0 then
                    local coast=w.base[i]==0 or (w.base[i]==1 and ((x>0 and w.base[i-1]==0) or (y>0 and w.base[i-24]==0) or (x<23 and w.base[i+1]==0) or (y<23 and w.base[i+24]==0)))
                    local key=(coast and 'sand' or 'grass')..w.mask[i]..'_'..((x*7+y*11+w.seed)%6)
                    world_sprite(key,sx,sy,S.zoom,1,true,x,y,base*16);S.visible=S.visible+1
                    if not (w.occ[i]>0 and w.bid[w.occ[i]]<=4) then Platform.shadow(Lighting.masks[i],sx,sy,S.zoom,w.mask[i],Lighting.R,x,y) end
                    Platform.ground_light(x,y,sx,sy,S.zoom,w.mask[i])
                elseif kind==1 then
                    Platform.shadow(Lighting.masks[i],sx,sy,S.zoom,0,Lighting.R,x,y)
                    Platform.ground_light(x,y,sx,sy,S.zoom,0)
                elseif kind==3 then
                    world_sprite(sites[i],sx,sy,S.zoom,1,false,x,y,base*16)
                elseif id>0 then
                    local key=id<=4 and road_sprite(w,i,id) or 'b'..id..'_'..w.rot[i]
                    if id==7 then local m=w.mask[i];key=m==0 and 'road2_10' or 'b7_'..(m==12 and 0 or m==9 and 1 or m==3 and 2 or 3) end
                    local powered=w.linked[i] and w.power>=w.need
                    world_sprite(key,sx,sy,S.zoom,1,powered,x,y,base*16)
                    if id<=4 then
                        local nx,ny=World.footprint(id,w.rot[i]);local v=0
                        while v<ny do local u=0
                            while u<nx do
                                local k=World.cell(x+u,y+v);local px,py=pos(x+u,y+v,w.base[k]*16)
                                Platform.shadow(Lighting.masks[k],px,py,S.zoom,w.mask[k],Lighting.R,x+u,y+v)
                                Platform.ground_light(x+u,y+v,px,py,S.zoom,w.mask[k]);u=u+1
                            end;v=v+1
                        end
                    elseif id==5 or id==6 then
                        local nx,ny=World.footprint(id,w.rot[i])
                        for v=0,ny-1 do for u=0,nx-1 do
                            local px,py=pos(x+u,y+v,base*16)
                            Platform.bridge(x+u,y+v,px,py,S.zoom,base*16)
                        end end
                    end
                    if id==3 and (x+y)%4==0 and w.mask[i]==0 then world_sprite('lamp',sx,sy,S.zoom,1,powered,x,y,base*16) end
                elseif S.detail==1 and not sites[i] then
                    world_sprite((w.base[i]==1 and 'palm' or 'tree')..(w.deco[i]-1),sx,sy,S.zoom,1,true,x,y,base*16)
                    if fly_count<6 and w.base[i]>1 then fly_count=fly_count+1;flies[fly_count*3-2]=x;flies[fly_count*3-1]=y;flies[fly_count*3]=base*16 end
                end
            end
            n=n+1
        end
        S.fly_count=fly_count;Platform.cache_end();w.dirty=false
    end
    Platform.world(S.phase,S.time,S.motion)
    local view=Platform.camera()
    S.view=view
    if not view then return end
    local vx=view.ox+(-view.cx+view.cy)*32*view.zoom
    local vy=view.oy+(-view.cx-view.cy)*16*view.zoom
    local changed=S.view_x~=vx or S.view_y~=vy or S.view_zoom~=view.zoom
    S.view_x,S.view_y,S.view_zoom=vx,vy,view.zoom
    if changed or S.project_marks then
        for i=1,#S.zone_marks do
            local m=S.zone_marks[i];local x,y=m[10],m[11]
            m[1],m[2]=display_pos(x,y,m[12]);m[3],m[4]=display_pos(x+1,y,m[13])
            m[5],m[6]=display_pos(x+1,y+1,m[14]);m[7],m[8]=display_pos(x,y+1,m[15])
        end
        S.project_marks=false
    end
    if S.screen=='play' and (S.tool=='zone' or S.tool=='inspect') then
        local marks=S.zone_marks
        for i=1,#marks do
            local m=marks[i];local color=zone_colors[m[9]]
            line(std,m[1],m[2],m[3],m[4],color);line(std,m[3],m[4],m[5],m[6],color)
            line(std,m[5],m[6],m[7],m[8],color);line(std,m[7],m[8],m[1],m[2],color)
            local sx,sy=(m[1]+m[5])*.5,(m[2]+m[6])*.5
            for dot=1,m[9] do box(std,sx+(dot-1)*5-3,sy-1,3,3,color) end
        end
    end
    render_actors(w)
    Platform.effects(S.time,S.motion)
    if S.motion and S.phase>.2 and S.phase<.8 then

        local k=0
        while k<3 do
            local x=(S.time/85+k*417)%1370-45;local y=155+k*115+math.sin(S.time/1800+k)*13
            line(std,x-7,y+2,x-2,y,C.paper);line(std,x-2,y,x+3,y+2,C.paper);k=k+1
        end
    elseif S.motion and S.detail==1 then
        local k=1
        while k<=(S.fly_count or 0) do
            if math.sin(S.time/900+k*1.7)>.15 then
                local x,y=display_pos(S.flies[k*3-2],S.flies[k*3-1],S.flies[k*3])
                x=x+floor(math.sin(S.time/2100+k)*18)*2
                y=y-14+floor(math.cos(S.time/1800+k)*8)*2
                box(std,x,y,4,4,C.gold)
            end;k=k+1
        end
    end
end
local function ornament(std,x,y,w)
    line(std,x,y,x+w,y,C.line)
    line(std,x,y,x+min(w,80),y,C.gold)
    box(std,x-3,y-3,6,6,C.gold)
end
local function frame(std,label,sub)
    box(std,0,0,1280,720,0x101923EC)
    title(std,76,48,label,40)
    if sub then text(std,78,104,sub,28,C.muted,1120) end
    ornament(std,78,150,1122)
end
local function footer(std,hint)
    line(std,78,630,1200,630,C.line)
    text(std,78,650,hint,26,C.muted,1122)
end
local function menu_button(std,x,y,w,label,sub,focus,glyph)
    local h=sub and 94 or 62
    if focus then
        Platform.skin('focus',x,y,w,h,false,S.time,false)
        box(std,x+4,y+18,4,h-36,C.gold)
    else
        line(std,x+20,y+h-2,x+w-20,y+h-2,C.line)
    end
    if glyph then icon(glyph,x+22,y+12,1) end
    local tx=x+(glyph and 68 or 26)
    text(std,tx,y+(sub and 12 or 15),label,32,focus and C.paper or C.muted,w-(glyph and 96 or 58))
    if sub then text(std,x+26,y+52,sub,26,C.muted,w-58) end
end
local function title_draw(std)
    box(std,0,0,532,720,0x101923EF)
    title(std,78,78,I18n.t('MARE'),96,C.paper,432)
    ornament(std,82,180,354)
    text(std,82,208,I18n.t('Seu mundo, no seu ritmo.'),30,C.muted,400)
    local n=1
    while n<=4 do
        menu_button(std,66,302+(n-1)*72,398,I18n.t(title_items[n]),nil,S.selection==n)
        n=n+1
    end
    text(std,84,644,I18n.t('SETAS escolher   OK entrar'),26,C.muted,400)
    title(std,962,54,I18n.t('MAR ABERTO'),16,C.paper,246)
end
local function header(std)
    local w=S.world

    box(std,48,32,1184,82,C.panel)
    title(std,74,46,I18n.f('DIA %d',w.day),20,C.muted,144)
    text(std,74,73,I18n.t(w.free and 'Modo livre' or 'Jornada'),26,C.paper,140)
    icon('coin',246,54,1);text(std,286,45,w.free and I18n.t('Livre') or w.cash,34,C.gold,190)
    text(std,286,82,I18n.t('moedas'),22,C.muted)
    icon('people',472,54,1);text(std,512,45,w.population,34,C.paper,174)
    text(std,512,82,I18n.t('moradores'),22,C.muted)
    icon('power',708,54,1);text(std,746,45,I18n.f('%d / %d',w.power,w.need),34,w.power>=w.need and C.teal or C.red,188)
    text(std,746,82,I18n.t('energia'),22,C.muted)
    icon('happy',978,54,1);text(std,1018,45,I18n.f('%d%%',w.happy),34,C.paper,166)
    text(std,1018,82,I18n.t('felicidade'),22,C.muted)
end
local function terrain_tool()
    return S.tool=='raise' or S.tool=='lower' or S.tool=='level' or S.tool=='pull'
end
local function ground_pos(x,y,project)
    x=max(0,min(24,x));y=max(0,min(24,y))
    local xx=min(23,floor(x));local yy=min(23,floor(y));local u=x-xx;local v=y-yy
    local k=yy*25+xx+1;local h=S.world.h;local a,b,c,d=h[k],h[k+1],h[k+26],h[k+25]
    local z=u>=v and a+u*(b-a)+v*(c-b) or a+u*(c-d)+v*(d-a)
    return (project or display_pos)(x,y,z*16)
end

local brush_ring={};local ring_i=0
while ring_i<=48 do local angle=ring_i*math.pi/24;brush_ring[ring_i*2+1]=math.cos(angle);brush_ring[ring_i*2+2]=math.sin(angle);ring_i=ring_i+1 end
local function brush_draw(std)
    local pulling=S.gesture and S.tool=='pull'
    local cx=pulling and S.gx or S.cx;local cy=pulling and S.gy or S.cy
    local radius=S.brush+1;local lastx,lasty;local n=0
    while n<=48 do

        local xx=cx+brush_ring[n*2+1]*radius
        local yy=cy+brush_ring[n*2+2]*radius
        local x,y=ground_pos(xx,yy)
        if lastx then line(std,lastx,lasty+2,x,y+2,C.dark);line(std,lastx,lasty,x,y,C.gold) end
        lastx=x;lasty=y;n=n+1
    end
    local x,y=ground_pos(cx,cy)
    line(std,x-6,y,x+6,y,C.paper);line(std,x,y-4,x,y+4,C.paper)
    if pulling then
        local tx,ty=ground_pos(S.cx,S.cy);line(std,x,y,tx,ty,C.gold)
        box(std,tx-4,ty-3,8,6,C.paper)
    end
end
local function selection_draw(std)
    if not S.view then return end
    if terrain_tool() then brush_draw(std);return end
    local w=S.world;local i=World.cell(S.cx,S.cy);local nx,ny=1,1
    if S.tool=='build' then nx,ny=World.footprint(S.build_id,S.rotation) end
    local good=true
    if S.tool=='build' then good=(S.paint and w.bid[i]==S.build_id) or World.valid(w,S.build_id,S.cx,S.cy,S.rotation)
    elseif S.tool=='zone' then good=World.zone_valid(w,S.zone_kind%4,S.cx,S.cy)
    elseif S.tool=='remove' then good=w.occ[i]>0 end
    local col=good and (S.tool=='zone' and zone_colors[S.zone_kind] or C.gold) or C.red
    local x0=S.cx;local y0=S.cy
    local v=0
    while v<ny do local u=0
        while u<nx do
            local xx=x0+u;local yy=y0+v
            if xx>=0 and yy>=0 and xx<24 and yy<24 then
                local k=World.cell(xx,yy);local h=w.base[k]*16;local mask=w.mask[k]
                local a,b=display_pos(xx,yy,h+(mask%2>=1 and 16 or 0));local c,d=display_pos(xx+1,yy,h+(floor(mask/2)%2==1 and 16 or 0))
                local e,f=display_pos(xx+1,yy+1,h+(floor(mask/4)%2==1 and 16 or 0));local g,j=display_pos(xx,yy+1,h+(floor(mask/8)%2==1 and 16 or 0))
                line(std,a,b,c,d,col);line(std,c,d,e,f,col);line(std,e,f,g,j,col);line(std,g,j,a,b,col)
                line(std,a,b+1,c,d+1,col);line(std,c,d+1,e,f+1,col)
            end
            u=u+1
        end;v=v+1
    end
    local sx,sy=display_pos(S.cx,S.cy,(S.tool=='build' and World.elevation(w,S.build_id,S.cx,S.cy,S.rotation) or w.base[i])*16)
    if S.tool=='build' then
        local id=S.build_id;local key=id<=4 and road_sprite(w,i,id) or 'b'..id..'_'..S.rotation
        Platform.sprite(key,sx,sy,S.view_zoom,good and 65/100 or 35/100)
    end
    box(std,sx-5,sy-9,10,6,col)
end
local function play_draw(std)
    selection_draw(std);header(std)
    local w=S.world;local i=World.cell(S.cx,S.cy);local id=w.occ[i]>0 and w.bid[w.occ[i]] or 0
    box(std,48,580,1184,100,C.panel)
    local label=S.tool=='zone' and I18n.t(zone_names[S.zone_kind]) or S.tool=='build' and I18n.catalog(S.build_id)[1] or S.tool=='inspect' and id>0 and I18n.catalog(id)[1] or I18n.t(captions[S.tool])
    if S.tool=='level' and S.stroke then label=S.stroke.target==0 and I18n.t('Nivelar: altura do mar') or I18n.f('Nivelar: altura %d',S.stroke.target) end
    text(std,76,594,label,32,C.paper,890)
    local msg=I18n.t('SETAS explorar    OK criar    VOLTAR pausa')
    local color=C.muted;local access_warning=false
    if S.tool=='build' then
        local good,reason=World.valid(w,S.build_id,S.cx,S.cy,S.rotation)
        msg=good and I18n.f('OK construir  /  Custo: %d  /  VOLTAR opcoes',World.price(w,S.build_id,S.cx,S.cy)) or I18n.f('%s  /  VOLTAR opcoes',reason)
        color=good and C.muted or C.red
        access_warning=good and not World.access(w,S.build_id,S.cx,S.cy,S.rotation)
        if S.paint then
            msg=I18n.t(S.gesture and 'SETAS tracar    OK terminar    VOLTAR cancelar' or 'OK comecar via    VOLTAR opcoes')
            color=S.gesture and C.gold or C.muted
        end
    elseif S.tool=='zone' then
        local valid,reason=World.zone_valid(w,S.zone_kind%4,S.cx,S.cy)
        msg=S.gesture and I18n.t('SETAS pintar    OK confirmar zona    VOLTAR cancelar') or valid and I18n.t('OK comecar zona    VOLTAR escolher uso') or reason
        color=valid and C.muted or C.red
    elseif S.tool=='inspect' and id>0 then
        access_warning=not w.linked[w.occ[i]]
        msg=I18n.t(access_warning and 'Sem acesso: construcao inativa    OK criar    VOLTAR pausa' or 'Com acesso    OK criar    VOLTAR pausa')
        color=access_warning and C.gold or C.muted
    elseif S.tool=='inspect' and w.reserved[i] then
        for j=1,#w.jobs do
            local job=w.jobs[j]
            if job.id==w.reserved[i] then
                msg=I18n.f('%s  /  %d%%',I18n.t(World.job_status[job.status]),floor(job.progress*100));break
            end
        end
    elseif S.tool=='inspect' and w.zones[i]>0 then
        local status=w.zone_status[i]
        msg=I18n.t(status=='footprint' and 'Autorize o lote inteiro: clinicas precisam de 2x1' or status=='capacity' and 'Aguardando uma das quatro equipes de obra' or status and World.job_status[status] or 'Zona autorizada: aguardando ocupacao')
    elseif S.gesture then
        msg=I18n.t(S.tool=='pull' and 'SETAS puxar    OK soltar    VOLTAR cancelar' or 'SETAS pintar    OK concluir    VOLTAR cancelar');color=C.gold
    elseif S.tool~='inspect' then
        msg=S.tool=='remove' and I18n.t('OK remover e recuperar 75%    VOLTAR explorar') or I18n.f(S.tool=='pull' and 'OK segurar    Pincel %s    VOLTAR opcoes' or S.tool=='level' and 'OK copiar altura    Pincel %s    VOLTAR opcoes' or 'OK comecar    Pincel %s    VOLTAR opcoes',I18n.t(brush_names[S.brush]))
    end
    text(std,76,635,msg,26,color,1110)
    text(std,1006,600,I18n.f('%+d / dia',w.balance),26,w.balance>=0 and C.teal or C.red,190)
    if access_warning then
        box(std,48,522,1184,50,C.panel)
        text(std,76,534,I18n.t('Sem acesso: ligue uma via ao lado para ativar.'),26,C.gold,1110)
    end
    if S.tool=='inspect' and w.reward<5 then
        local ready=World.goal_ready(w)
        box(std,48,134,396,80,C.panel)
        text(std,70,147,I18n.t(ready and 'Conquista pronta!' or World.goals[w.reward+1][1]),24,C.gold,352)
        text(std,70,180,ready and I18n.t('VOLTAR > Diario para receber') or I18n.f('%d%%  /  Diario na pausa',floor(World.progress(w)*100)),22,C.muted,336)
        box(std,70,204,332,2,C.line);box(std,70,204,max(2,floor(332*World.progress(w))),2,C.gold)
    end
end

local function dock(std,heading,names,icons,note,back,first_label)
    header(std);box(std,48,icons and 410 or 470,1184,icons and 270 or 210,C.panel)
    title(std,80,icons and 432 or 488,heading,32,C.paper,1080)
    text(std,80,icons and 480 or 530,note,26,C.muted,1090)
    local width=floor(1104/#names);local n=1
    while n<=#names do
        local x=80+(n-1)*width;local focus=S.selection==n
        if focus then box(std,x,icons and 526 or 572,width-14,icons and 84 or 48,C.gold) end
        if icons then icon(icons[n],x+14,540,1) end
        text(std,x+14,icons and 568 or 576,n==1 and first_label or I18n.t(names[n]),28,focus and C.paper or C.muted,width-40)
        n=n+1
    end
    footer(std,I18n.t(back))
end
local function toolbar_draw(std)
    local note=I18n.t(tool_notes[S.selection])
    if S.selection==4 then note=#S.world.undo>0 and I18n.f('Desfazer disponivel: %d acoes. O gesto inteiro volta.',#S.world.undo) or I18n.t('Nada para desfazer ainda.') end
    dock(std,I18n.t('O que vamos criar?'),tool_names,tool_ids,note,'SETAS escolher    OK usar    VOLTAR explorar')
end
local function terrain_draw(std)
    dock(std,I18n.t('Moldar a ilha'),terrain_names,terrain_ids,I18n.t(terrain_notes[S.selection]),'SETAS escolher    OK usar    VOLTAR ferramentas')
end
local function zones_draw(std)
    dock(std,I18n.t('Crescer em bairros'),zone_names,nil,I18n.t(zone_notes[S.selection]),'SETAS escolher    OK usar    VOLTAR ferramentas')
end
local function context_draw(std)
    selection_draw(std)
    local names,heading,note,first_label
    if S.tool=='build' then
        heading=I18n.catalog(S.build_id)[1]
        if S.paint then names=context_road_names;note='Cada tracado pode ser desfeito de uma vez.'
        else names=context_build_names;note=S.selection==1 and 'OK gira 90 graus e volta para a ilha.' or S.selection==2 and 'Escolha outra peca. A ilha fica como esta.' or 'Volte a explorar a ilha.' end
    elseif S.tool=='zone' then
        heading=I18n.t(zone_names[S.zone_kind]);names=context_zone_names;note=zone_notes[S.zone_kind]
    else
        heading=I18n.t(captions[S.tool]);names=context_terrain_names;first_label=I18n.f('Pincel: %s',I18n.t(brush_names[S.brush]))
        note=S.selection==1 and 'OK muda o tamanho. A terra leva as construcoes junto.' or S.selection==2 and 'Troque entre elevar, baixar, nivelar e distorcer.' or 'Volte a explorar a ilha.'
    end
    dock(std,heading,names,nil,I18n.t(note),'SETAS escolher    OK usar    VOLTAR explorar',first_label)
end
local function catalog_draw(std)
    frame(std,I18n.t('Construir'),I18n.t('Escolha o que vai fazer parte da sua ilha.'))
    local cat=1
    while cat<=5 do pill(std,78+(cat-1)*224,170,I18n.t(categories[cat]),S.category==cat,210);cat=cat+1 end
    local range=ranges[S.category];local count=range[2]-range[1]+1;local page=floor((S.item-1)/6);local n=page*6+1
    while n<=min(count,page*6+6) do
        local id=range[1]+n-1;local d=I18n.catalog(id);local index=n-page*6-1;local x=78+(index%3)*238;local y=234+floor(index/3)*182;local focus=S.item==n and not S.tab_focus
        box(std,x,y,222,166,focus and C.gold or C.line)
        local key=id<=4 and 'road'..id..'_10' or 'b'..id..'_0'
        Platform.thumb(key,x+111,y+42,186,76)
        text(std,x+16,y+82,d[10],26,focus and C.paper or C.muted,194)
        text(std,x+16,y+108,d[11],26,focus and C.paper or C.muted,194)
        text(std,x+16,y+131,I18n.f('%d  /  %dx%d',d[5],d[3],d[4]),22,C.gold,190)
        n=n+1
    end
    local id=range[1]+S.item-1;local d=Catalog[id]
    line(std,812,234,812,590,C.line)
    title(std,842,242,I18n.t('SELECIONADO'),18,C.gold,350)
    Platform.thumb(id<=4 and 'road'..id..'_10' or 'b'..id..'_0',1018,376,348,186)
    text(std,842,488,I18n.f('%d x %d terrenos',d[3],d[4]),28,C.paper,352)
    text(std,842,528,I18n.f('Custo: %d moedas',d[5]),28,C.gold,352)
    text(std,842,564,I18n.f('%d moedas / dia',d[6]),26,C.muted,352)
    text(std,80,600,World.describe(id),24,C.teal,960)
    text(std,1100,600,I18n.f('%d / %d',page+1,math.ceil(count/6)),24,C.muted,100)
    footer(std,I18n.t(S.tab_focus and 'ESQUERDA / DIREITA categorias    OK ver construcoes    VOLTAR' or 'SETAS escolher    CIMA categorias    OK colocar    VOLTAR'))
end
local function pause_draw(std)
    frame(std,I18n.t('Um respiro'),I18n.t('Sua ilha fica guardada enquanto voce faz uma pausa.'))
    local n=1;while n<=7 do
        menu_button(std,78,168+(n-1)*64,572,I18n.t(pause_items[n]),nil,S.selection==n);n=n+1
    end
    Platform.minimap(722,234,420)
    if S.toast_time>0 and S.toast_good then
        for i=1,#pause_toast_lines do text(std,766,474+(i-1)*32,pause_toast_lines[i],26,C.paper,380) end
    else
        title(std,766,474,I18n.f('ILHA %d',S.slot),24,C.gold,380)
        text(std,766,520,I18n.f('Dia %d  /  Moradores: %d',S.world.day,S.world.population),28,C.paper,380)
        text(std,766,564,I18n.t(S.world.free and 'Modo livre' or 'Jornada'),26,C.muted,380)
    end
    footer(std,I18n.t('SETAS escolher    OK confirmar    VOLTAR continuar'))
end
local function settings_draw(std)
    frame(std,I18n.t('Ajustes'),I18n.t('Deixe a ilha confortavel para voce.'))
    local n=1;while n<=7 do
        local label
        if n==1 then label=I18n.t(S.sound and 'Som: ligado' or 'Som: desligado')
        elseif n==2 then label=I18n.t(S.motion and 'Movimento: ligado' or 'Movimento: reduzido')
        elseif n==3 then label=I18n.t(S.detail==1 and 'Detalhes: completos' or 'Detalhes: economicos')
        elseif n==4 then label=I18n.f('Zoom: %dx',S.preferred_zoom or 2)
        elseif n==5 then label=I18n.f('Luz: %s',I18n.t(Lighting.names[S.light]))
        elseif n==6 then label=I18n.f('Idioma: %s',I18n.t(language_names[I18n.locale()]))
        else label=I18n.t('Concluir') end
        menu_button(std,78,170+(n-1)*64,680,label,nil,S.selection==n);n=n+1
    end
    icon(S.phase>.8 and 'moon' or 'sun',934,250,3)
    paragraph(std,808,380,I18n.t(settings_notes[S.selection]),28,C.paper,380)
    paragraph(std,808,532,I18n.t('Manha, por do sol e luzes da noite.'),28,C.muted,380)
    footer(std,I18n.t('SETAS escolher    OK alterar    VOLTAR concluir'))
end
local help_pages={
    {'Sua ilha, seu ritmo','Setas movem o cursor pelas diagonais da ilha.','OK abre as ferramentas durante a exploracao.','Voltar cancela gestos ou abre opcoes da peca.','Ao explorar, Voltar abre a pausa e o diario.'},
    {'Moldar a terra','Elevar e Baixar: OK, setas para pintar, OK.','Nivelar: OK copia a altura; setas pintam nela.','Distorcer: OK segura; setas puxam; OK solta.','Casas sobem e descem; vias ganham rampas.'},
    {'Fazer a ilha crescer','Casas, lojas e servicos precisam de via ao lado.','Geradores e usinas tambem precisam de acesso.','Sem via, a construcao fica inativa.','Com acesso, energia e servicos atendem a ilha.'},
    {'Experimentar','Um dia passa a cada 12 segundos de partida.','Troque o piso de vias pagando a diferenca.','Remover devolve 75%; Desfazer recupera tudo.','No modo livre, construa sem limite de moedas.'},
    {'Pontes e praias','Pontes ocupam agua ou margens na altura 1.','Portos e quiosques precisam ficar junto da agua.','Rampas retas aceitam trilhas, passeios e ruas.','Com via: abrigo tem 2 animais; centro vet., 4.'}
}

local function help_draw(std)
    local p=help_pages[S.selection];frame(std,I18n.t(p[1]),I18n.f('GUIA DE BOLSO  /  %d DE %d',S.selection,#help_pages))
    local n=2;while n<=5 do
        pill(std,84,186+(n-2)*94,tostring(n-1),true,46)
        paragraph(std,155,190+(n-2)*94,I18n.t(p[n]),32,C.paper,1030);n=n+1
    end
    footer(std,I18n.t('ESQUERDA / DIREITA  paginas     OK ou VOLTAR  fechar'))
end
local function goals_draw(std)
    local w=S.world;frame(std,I18n.t('Diario da ilha'),I18n.t(w.free and 'MODO LIVRE  /  Sem limites para experimentar' or 'JORNADA  /  Cada conquista abre novas possibilidades'))
    local g=min(5,w.reward+1);local goal=World.goals[g]
    box(std,82,180,654,180,C.line)
    text(std,104,200,I18n.t(w.reward>=5 and 'A ilha e toda sua.' or goal[1]),32,C.gold,610)
    paragraph(std,104,248,I18n.t(w.reward>=5 and 'Todas as conquistas foram completadas.' or goal[2]),26,C.paper,610)
    text(std,104,322,w.reward>=5 and I18n.t('Continue criando, sem um fim obrigatorio.') or I18n.f('Recompensa: %d moedas',goal[3]),23,C.muted,610)
    menu_button(std,82,387,654,I18n.t(World.goal_ready(w) and 'Receber conquista' or 'Continuar explorando'),nil,true)
    text(std,82,484,I18n.f('Conquistas: %d / 5',w.reward),26,C.muted,654)
    text(std,82,528,I18n.f('Animais: %d    Pracas: %d    Lojas: %d',w.animals,w.parks,w.shops),25,C.muted,654)
    text(std,795,190,I18n.t('A CIDADE EM NUMEROS'),21,C.gold)
    local rows={{'Receita por dia',w.revenue},{'Manutencao',w.upkeep},{'Saldo por dia',w.balance},{'Agua / pessoas',I18n.f('%d / %d',w.water,w.population)},{'Saude / pessoas',I18n.f('%d / %d',w.health,w.population)},{'Educacao / pessoas',I18n.f('%d / %d',w.school,w.population)}}
    local n=1;while n<=#rows do
        text(std,795,239+(n-1)*57,I18n.t(rows[n][1]),20,C.muted,265);text(std,1070,236+(n-1)*57,rows[n][2],24);n=n+1
    end
    footer(std,I18n.t('OK receber ou explorar    VOLTAR pausa'))
end
local function new_draw(std)
    frame(std,I18n.t('Nova ilha'),I18n.t('Escolha a paisagem e o ritmo da partida.'))
    local n=1;while n<=5 do
        local label=n==1 and I18n.t('Jornada: construir e prosperar') or n==2 and I18n.t('Modo livre: criar sem custos') or n==3 and I18n.f('Paisagem: semente %d',S.seed) or n==4 and I18n.f('Arquivo: ilha %d',S.slot) or I18n.t('Criar esta ilha')
        menu_button(std,84,179+(n-1)*83,776,label,nil,S.selection==n)
        if n==1 and not S.new_free or n==2 and S.new_free then icon('check',792,194+(n-1)*83,1) end
        n=n+1
    end
    line(std,878,180,878,595,C.line)
    Platform.minimap(896,225,284)
    text(std,910,434,I18n.t('Sua paisagem'),22,C.gold)
    text(std,910,482,I18n.t('40 construcoes'),23,C.muted)
    text(std,910,524,I18n.t('5 conquistas'),23,C.muted)
    text(std,910,565,I18n.t('Espaco para 3 ilhas'),21,C.muted)
    footer(std,I18n.t('OK escolher    VOLTAR inicio    Confirme a criacao no final'))
end
local function confirm_draw(std)
    frame(std,I18n.t('Substituir esta ilha?'),I18n.f('O arquivo %d ja tem uma ilha salva.',S.slot))
    text(std,86,204,I18n.t('Seu novo mundo vai ocupar este arquivo.'),30)
    text(std,86,266,I18n.t('Os outros dois arquivos ficam guardados.'),26,C.muted)
    menu_button(std,84,380,538,I18n.t('Escolher outro arquivo'),nil,S.selection==1)
    menu_button(std,84,474,538,I18n.t('Substituir e criar a nova ilha'),nil,S.selection==2)
    footer(std,I18n.t('SETAS  escolher     OK  confirmar     VOLTAR  cancelar'))
end
local function load_draw(std)
    frame(std,I18n.t('Suas ilhas'),I18n.t('Tres pequenos mundos, guardados neste dispositivo.'))
    local n=1;while n<=3 do
        local data=Platform.load(n);local w=S.saved[n]
        menu_button(std,84,191+(n-1)*127,1108,I18n.f('Ilha %d',n),w and I18n.f('Dia %d  /  Moradores: %d  /  %s',w.day,w.population,I18n.t(w.free and 'Modo livre' or 'Jornada')) or I18n.t(#data>0 and 'Arquivo invalido. Escolha outra ilha.' or 'Este arquivo esta vazio'),S.selection==n);n=n+1
    end
    footer(std,I18n.t('SETAS  escolher     OK  continuar     VOLTAR  inicio'))
end
local function start_game()
    S.playing=true
    S.world=S.preview or World.new(S.seed,S.new_free or false);S.world.free=S.new_free or false;S.preview=nil;S.cx=11;S.cy=13;S.zoom=S.preferred_zoom or 2;S.ox=640;S.oy=375;home_camera();S.tool='inspect';S.gesture=nil;S.stroke=nil;S.elapsed=0;S.skytime=0
    open('play');if save_game(true) then notify(I18n.t('Bem-vindo a sua ilha! OK abre as ferramentas.'),true) end
end
local function follow_cursor()
    local sx,sy=ground_pos(S.cx,S.cy,pos);local margin=terrain_tool() and (S.brush+1)*46*S.zoom or 112
    if sx<48+margin or sx>1232-margin or sy<150+margin/2 or sy>550-margin/2 then home_camera() end
end
local function move_cursor(dx,dy)
    if S.toast_good==false then S.toast_time=0 end
    local nx=max(0,min(23,S.cx+dx));local ny=max(0,min(23,S.cy+dy))
    if nx==S.cx and ny==S.cy then return end
    if S.gesture then
        if S.tool=='build' and S.paint then
            S.cx=nx;S.cy=ny;local ok,msg=World.paint(S.world,S.build_id,nx,ny);if not ok then S.stroke.failure=msg;notify(msg,false) end
        elseif S.tool=='zone' then
            S.cx=nx;S.cy=ny
            local valid,msg=World.zone_valid(S.world,S.zone_kind%4,nx,ny)
            if valid then World.zone(S.world,S.zone_kind%4,nx,ny) else notify(msg,false) end
        elseif S.tool=='pull' then
            nx=max(S.gx-S.brush-1,min(S.gx+S.brush+1,nx));ny=max(S.gy-S.brush-1,min(S.gy+S.brush+1,ny))
            S.cx=nx;S.cy=ny
            local ok,msg=World.terraform(S.world,'pull',S.gx,S.gy,S.brush,S.gesture,nx-S.gx,ny-S.gy)
            if not ok then notify(msg,false) end
        else
            S.cx=nx;S.cy=ny
            local ok,msg=World.terraform(S.world,S.tool,nx,ny,S.brush,S.gesture,0,0,S.stroke)
            if not ok then S.stroke.failure=msg;notify(msg,false) end
        end
        follow_cursor();return
    end
    S.cx=nx;S.cy=ny;follow_cursor()
end
local function changed(snapshot)
    local w=S.world;local i=1
    while i<=625 do if snapshot.h[i]~=w.h[i] then return true end;i=i+1 end
    i=1;while i<=576 do if snapshot.bid[i]~=w.bid[i] or snapshot.rot[i]~=w.rot[i] or snapshot.zones[i]~=w.zones[i] then return true end;i=i+1 end
    return false
end
local function finish_edit(snapshot,label,failure)
    if not changed(snapshot) then notify(failure or I18n.t('Nenhuma alteracao neste gesto.'),not failure);return end
    snapshot.refund=snapshot.cash-S.world.cash;World.record(S.world,snapshot);notify(failure and I18n.f('Gesto parcial: %s',failure) or label,not failure);follow_cursor()
    local x,y=pos(S.cx,S.cy,S.world.base[World.cell(S.cx,S.cy)]*16);Platform.burst(x,y,true)
end
local function explore()
    S.tool='inspect';open('play')
end
local function catalog_open()
    S.tab_focus=false;open('catalog')
end
local function act(key)
    local screen=S.screen;local delta=key=='down' and 1 or key=='up' and -1 or 0
    if screen~='play' and screen~='view' and (delta~=0 or key=='left' or key=='right') and S.sound and S.time-(S.focus_sound or -100)>70 then
        S.focus_sound=S.time;Platform.sound(0)
    end
    if screen=='view' then
        if key=='a' then S.light=S.light%4+1;Platform.options(S.sound,S.motion,S.detail,S.preferred_zoom or 2,S.light,I18n.locale())
        elseif key=='menu' then S.zoom=S.view_zoom;home_camera();open('pause',6) end
        return
    end
    if screen=='play' then
        if key=='left' then move_cursor(-1,0) elseif key=='right' then move_cursor(1,0) elseif key=='up' then move_cursor(0,-1) elseif key=='down' then move_cursor(0,1)
        elseif key=='menu' then
            if S.gesture then World.restore(S.world,S.gesture);S.cx=S.gx;S.cy=S.gy;S.gesture=nil;S.stroke=nil;follow_cursor();notify(I18n.t('Gesto cancelado.'),true)
            elseif S.tool=='inspect' then open('pause')
            elseif S.tool=='remove' then explore()
            else open('context') end
        elseif key=='a' then
            if S.tool~='inspect' then S.toast_time=0 end
            if S.tool=='inspect' then open('tools',S.tool_focus or 1)
            elseif S.tool=='build' then
                if S.paint then
                    if S.gesture then finish_edit(S.gesture,I18n.t('Via pronta.'),S.stroke.failure);S.gesture=nil;S.stroke=nil
                    else S.gesture=World.snapshot(S.world);S.stroke={};S.gx=S.cx;S.gy=S.cy;local ok,msg=World.paint(S.world,S.build_id,S.cx,S.cy);if not ok then S.gesture=nil;S.stroke=nil;notify(msg,false) end end
                else
                    local ok,msg=World.build(S.world,S.build_id,S.cx,S.cy,S.rotation)
                    if ok and not S.world.linked[World.cell(S.cx,S.cy)] then msg=I18n.f('%s: pronta. Ligue uma via ao lado para ativar.',I18n.catalog(S.build_id)[1]) end
                    notify(msg,ok)
                    if ok then local x,y=pos(S.cx,S.cy,S.world.base[World.cell(S.cx,S.cy)]*16);Platform.burst(x,y,true) end
                end
            elseif S.tool=='zone' then
                if S.gesture then finish_edit(S.gesture,I18n.t(S.zone_kind==4 and 'Zona removida. Construcoes prontas foram mantidas.' or 'Zona confirmada. Acompanhe as obras.'));S.gesture=nil
                else
                    local valid,msg=World.zone_valid(S.world,S.zone_kind%4,S.cx,S.cy)
                    if valid then S.gesture=World.snapshot(S.world);S.gx=S.cx;S.gy=S.cy;World.zone(S.world,S.zone_kind%4,S.cx,S.cy)
                    else notify(msg,false) end
                end
            elseif S.tool=='remove' then local ok,msg=World.remove(S.world,S.cx,S.cy);notify(msg,ok);if ok then local x,y=pos(S.cx,S.cy,S.world.base[World.cell(S.cx,S.cy)]*16);Platform.burst(x,y,false) end
            elseif S.tool=='pull' then
                if S.gesture then finish_edit(S.gesture,I18n.t('Costa redesenhada.'));S.gesture=nil
                else S.gesture=World.snapshot(S.world);S.gx=S.cx;S.gy=S.cy end
            else
                if S.gesture then finish_edit(S.gesture,I18n.t('Relevo e construcoes ajustados.'),S.stroke.failure);S.gesture=nil;S.stroke=nil
                else
                    S.gesture=World.snapshot(S.world);S.gx=S.cx;S.gy=S.cy
                    S.stroke={target=S.gesture.h[S.cy*25+S.cx+1]}
                    if S.tool~='level' then
                        local ok,msg=World.terraform(S.world,S.tool,S.cx,S.cy,S.brush,S.gesture,0,0,S.stroke)
                        if not ok then S.stroke.failure=msg;notify(msg,false) end
                        follow_cursor()
                    end
                end
            end
        end
        return
    end
    if screen=='tools' or screen=='terrain' or screen=='context' or screen=='zones' then
        local count=screen=='context' and ((S.tool=='build' and S.paint) or S.tool=='zone') and 2 or screen=='context' and 3 or screen=='tools' and 5 or 4
        if key=='menu' then
            if screen=='terrain' then open('tools',2) elseif screen=='zones' then open('tools',5) else explore() end
        elseif key=='left' or key=='up' then S.selection=max(1,S.selection-1)
        elseif key=='right' or key=='down' then S.selection=min(count,S.selection+1)
        elseif key=='a' then
            local n=S.selection
            if screen=='tools' then
                S.tool_focus=n
                if n==1 then catalog_open()
                elseif n==2 then open('terrain',S.terrain_focus or 1)
                elseif n==3 then S.tool='remove';open('play')
                elseif n==4 then local ok,msg=World.undo(S.world);explore();notify(msg,ok)
                else open('zones',S.zone_kind) end
            elseif screen=='terrain' then S.terrain_focus=n;S.tool=terrain_ids[n];follow_cursor();open('play')
            elseif screen=='zones' then S.zone_kind=n;S.tool='zone';open('play')
            elseif n==count then explore()
            elseif S.tool=='zone' then open('zones',S.zone_kind)
            elseif S.tool=='build' then
                if n==1 and not S.paint then S.rotation=(S.rotation+1)%4;open('play') else catalog_open() end
            elseif n==1 then S.brush=S.brush%3+1;follow_cursor();open('play')
            else open('terrain',S.terrain_focus or 1) end
        end
        return
    end
    if screen=='catalog' then
        local count=ranges[S.category][2]-ranges[S.category][1]+1
        if key=='menu' then open('tools',1)
        elseif S.tab_focus then
            if key=='left' then S.category=(S.category+3)%5+1;S.item=1
            elseif key=='right' then S.category=S.category%5+1;S.item=1
            elseif key=='down' or key=='a' then S.tab_focus=false end
        elseif key=='right' then S.item=min(count,S.item+1)
        elseif key=='left' then S.item=max(1,S.item-1)
        elseif key=='down' then S.item=min(count,S.item+3)
        elseif key=='up' then if S.item<=3 then S.tab_focus=true else S.item=S.item-3 end
        elseif key=='a' then S.build_id=ranges[S.category][1]+S.item-1;S.rotation=0;S.tool='build';S.paint=S.build_id<=3;open('play') end
        return
    end
    if screen=='help' then
        if key=='left' then S.selection=max(1,S.selection-1) elseif key=='right' then S.selection=min(#help_pages,S.selection+1)
        elseif key=='a' or key=='menu' then open(S.return_to or 'title',S.return_selection) end;return
    end
    if screen=='goals' then
        if key=='a' then if World.claim(S.world) then notify(I18n.t('Conquista recebida! Sua ilha esta crescendo.'),true) else explore() end
        elseif key=='menu' then open('pause',3) end;return
    end
    local count=menu_lengths[screen] or 1
    if delta~=0 then S.selection=(S.selection-1+delta+count)%count+1;return end
    if screen=='pause' and (key=='left' or key=='right') then return end
    if key=='menu' then
        if screen=='title' then return
        elseif screen=='new' or screen=='load' then open('title')
        elseif screen=='confirm' then open('new',4)
        elseif screen=='settings' then open(S.return_to or 'title',S.return_selection)
        elseif screen=='pause' then S.tool='inspect';open('play') end
        return
    end
    if key~='a' then return end
    local n=S.selection
    if screen=='title' then
        if n==1 then open('load') elseif n==2 then open('new') elseif n==3 then S.return_to='title';S.return_selection=3;open('help') else S.return_to='title';S.return_selection=4;open('settings') end
    elseif screen=='load' then
        local w=S.saved[n]
        if w then S.playing=true;S.world=w;S.slot=n;S.cx=11;S.cy=13;S.ox=640;S.oy=375;S.zoom=S.preferred_zoom or 2;S.tool='inspect';S.elapsed=0;home_camera();open('play') else notify(I18n.t('Este arquivo nao tem uma ilha valida.'),false) end
    elseif screen=='new' then
        if n==1 then S.new_free=false elseif n==2 then S.new_free=true elseif n==3 then S.seed=(S.seed+137)%9999;S.preview=World.new(S.seed,S.new_free or false) elseif n==4 then S.slot=S.slot%3+1
        else if #Platform.load(S.slot)>0 then open('confirm') else start_game() end end
    elseif screen=='confirm' then if n==1 then open('new',4) else start_game() end
    elseif screen=='pause' then
        if n==1 then S.tool='inspect';open('play') elseif n==2 then save_game(false) elseif n==3 then open('goals')
        elseif n==4 then S.return_to='pause';S.return_selection=4;open('settings') elseif n==5 then S.return_to='pause';S.return_selection=5;open('help')
        elseif n==6 then S.view_zoom=S.zoom;S.zoom=1;S.camx=11;S.camy=11;S.world.dirty=true;open('view')
        elseif n==7 and save_game(true) then S.playing=false;S.ox=880;S.oy=350;S.camx=11;S.camy=11;S.zoom=1;S.world.dirty=true;open('title') end
    elseif screen=='settings' then
        if n==1 then S.sound=not S.sound elseif n==2 then S.motion=not S.motion elseif n==3 then S.detail=3-S.detail;S.world.dirty=true
        elseif n==4 then
            S.preferred_zoom=3-(S.preferred_zoom or 2)
            if S.return_to=='pause' then S.zoom=S.preferred_zoom;S.world.dirty=true end
        elseif n==5 then S.light=S.light%4+1
        elseif n==6 then local locale=I18n.locale();local index=locale=='pt' and 1 or locale=='en' and 2 or 3;select_locale(language_codes[index%3+1])
        else open(S.return_to or 'title',S.return_selection) end
        Platform.options(S.sound,S.motion,S.detail,S.preferred_zoom or 2,S.light,I18n.locale())
    end
    if S.sound then Platform.sound(0) end
end
local function init(self,std)
    S.world=World.new(2706,true);S.ox=872;S.oy=354;S.zoom=1
    S.selection=(#Platform.load(1)>0 or #Platform.load(2)>0 or #Platform.load(3)>0) and 1 or 2

    local demo={14,12,18,19,35};local n=1
    while n<=#demo do local placed=false;local y=8
        while y<17 and not placed do local x=6
            while x<18 and not placed do
                if World.valid(S.world,demo[n],x,y,0,true) then S.world.bid[World.cell(x,y)]=demo[n];World.rebuild(S.world);placed=true end
                x=x+1
            end;y=y+1
        end;n=n+1
    end
    std.text.font_name('Mare, Arial, sans-serif')
    local options=Platform.get_options();local locale='pt'
    if options then
        S.sound=not string.find(options,'silent',1,true);S.motion=not string.find(options,'still',1,true)
        local detail,zoom,light,stored_locale=string.match(options,'^[^,]+,[^,]+,(%d),(%d),(%d),([^,]+)$')
        if not detail then detail,zoom,light=string.match(options,',[^,]+,(%d),(%d),?(%d?)') end
        S.detail=tonumber(detail)==2 and 2 or 1;S.preferred_zoom=tonumber(zoom)==1 and 1 or 2;S.light=max(1,min(4,tonumber(light) or 1))
        if stored_locale=='en' or stored_locale=='de' then locale=stored_locale end
    end
    select_locale(locale)
    if options and string.match(options,'^[^,]+,[^,]+,[^,]+,[^,]+,[^,]+$') then
        Platform.options(S.sound,S.motion,S.detail,S.preferred_zoom or 2,S.light,'pt')
    end
    if Platform.register then Platform.register(function(command,arg)
        if command=='state' then return S.screen..','..S.cx..','..S.cy..','..S.world.cash..','..S.world.population..','..S.selection..','..S.world.revision end
        if command=='tool' then return S.tool..','..S.brush..','..S.rotation..','..(S.gesture and 'gesture' or 'ready')..','..(S.paint and 'trace' or 'single')..','..S.category..','..S.item..','..(S.tab_focus and 'tabs' or 'cards') end
        if command=='level' then return S.stroke and S.stroke.target~=nil and tostring(S.stroke.target) or '' end
        if command=='save' then return World.encode(S.world) end
        if command=='checkpoint' then return S.playing and not S.gesture and World.encode(S.world) or '' end
        if command=='previous-save' then return previous_save() end
        if command=='slot' then return S.slot end
        if command=='metrics' then return (S.visible or 0)..','..#S.world.undo..','..S.world.count..','..S.world.balance end
        if command=='lighting' then return S.light..','..S.phase..','..(Lighting.rebuilds or 0)..','..Lighting.R end
        if command=='key' then act(arg);return S.screen end
    end) end

    render_world(std)
end
local input_keys={'up','down','left','right','a','menu'}
local function loop(self,std)
    local dt=min(std.delta or 16,100);S.time=S.time+dt
    S.toast_time=max(0,S.toast_time-dt)
    local queued=Platform.take_key and Platform.take_key();local drained=0
    while queued do act(queued);drained=drained+1;queued=Platform.take_key() end
    local keys=input_keys;local i=1
    while i<=6 do
        local k=keys[i];local down=std.key.press[k] or false
        if down and not S.keys[k] then S.held[k]=0;if not Platform.take_key then act(k) end
        elseif down and i<=4 then
            S.held[k]=(S.held[k] or 0)+dt
            if S.held[k]>=340 then S.held[k]=240;act(k) end
        end
        S.keys[k]=down;i=i+1
    end
    if S.screen=='play' and not S.gesture then
        World.update(S.world,dt)
        local event=World.take_event(S.world)
        while event do
            local x,y=pos(event.x,event.y,S.world.base[World.cell(event.x,event.y)]*16)
            Platform.burst(x,y,event.kind=='completed')
            notify(event.kind=='completed' and I18n.f('%s: obra concluida!',I18n.catalog(event.building_id)[1]) or I18n.t('Obra cancelada. Saldo nao gasto devolvido.'),true)
            event=World.take_event(S.world)
        end
        S.skytime=S.skytime+dt
        S.elapsed=S.elapsed+dt;S.saveclock=S.saveclock+dt
        if S.elapsed>=12000 then S.elapsed=S.elapsed-12000;local msg=World.tick(S.world);if msg then notify(msg,true) end end
        if S.saveclock>=30000 then save_game(true) end
    end
end
local function draw(self,std)
    render_world(std)
    Platform.ui_begin(S.time-(S.entered or 0),S.motion)
    if S.screen=='zones' then zones_draw(std) end
    if S.screen=='title' then title_draw(std) elseif S.screen=='play' then play_draw(std) elseif S.screen=='tools' then toolbar_draw(std)
    elseif S.screen=='catalog' then catalog_draw(std) elseif S.screen=='terrain' then terrain_draw(std) elseif S.screen=='context' then context_draw(std)
    elseif S.screen=='pause' then pause_draw(std) elseif S.screen=='settings' then settings_draw(std) elseif S.screen=='help' then help_draw(std)
    elseif S.screen=='goals' then goals_draw(std) elseif S.screen=='new' then new_draw(std) elseif S.screen=='confirm' then confirm_draw(std) elseif S.screen=='load' then load_draw(std)
    elseif S.screen=='view' then box(std,350,624,580,56,C.panel);text(std,378,640,I18n.t('OK mudar a luz   VOLTAR continuar'),28,C.paper,530) end
    if S.toast_time>0 and (S.screen=='play' or S.toast_good==false) then
        box(std,448,128,784,S.toast_height,C.dark);box(std,448,128,5,S.toast_height,S.toast_good==false and C.red or C.gold)
        for i=1,#toast_lines do text(std,472,138+(i-1)*32,toast_lines[i],26,S.toast_good==false and C.red or C.paper,738) end
    end
    Platform.ui_end()
end
return {meta=app_meta,callbacks={init=init,loop=loop,draw=draw}}

end)()
if web then return app end
return Platform.attach(app)
