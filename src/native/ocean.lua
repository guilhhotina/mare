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
