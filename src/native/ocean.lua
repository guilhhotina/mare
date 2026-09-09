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
    local previous = self.field
    local a = self.spare_field or {}
    self.field, self.spare_field = a, previous
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
    local image = self.ocean
    if not image then
        image = Surface.new(512, 512)
        image:rect(0, 0, 512, 512, 0x237590ff)
        self.ocean = image
    end
    local pixels, changed = image.pixels, {}
    self.changed_blocks = changed
    for iy = 0, 126 do
        local field_row = iy * 128
        for cell = 0, 126 do
            local q = field_row + cell + 1
            local a0, a1, a2, a3 = a[q], a[q + 1], a[q + 128], a[q + 129]
            local shallow = a0 < 9 or a1 < 9 or a2 < 9 or a3 < 9
            local before = previous and (previous[q] < 9 or previous[q + 1] < 9 or previous[q + 128] < 9 or previous[q + 129] < 9)
            if (shallow or before) and (not previous or a0 ~= previous[q] or a1 ~= previous[q + 1] or a2 ~= previous[q + 128] or a3 ~= previous[q + 129]) then
                local first = cell * 4 + 2
                changed[#changed + 1] = (iy * 4 + 2) * 512 + first
                for dy = 0, 3 do
                    local y = iy * 4 + 2 + dy
                    local v = (dy + .5) * .25
                    local iv, k = 1 - v, y * 512 + first + 1
                    if not shallow then
                        pixels[k], pixels[k + 1], pixels[k + 2], pixels[k + 3] = 0x237590ff, 0x237590ff, 0x237590ff, 0x237590ff
                    else
                        local hash_y, caustic_row, streak_y = y * 668265263, (y % 64) * 64, y * 3
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
        end
        Work.check()
    end
    return true
end

function Ocean:prepare(csv, cx, cy, zoom, ox, oy)
    local changed = self:terrain(csv)
    local key = cx .. ',' .. cy .. ',' .. zoom .. ',' .. ox .. ',' .. oy
    if not changed and key == self.sea_key then return false end
    local moved = key ~= self.sea_key
    self.sea_key = key
    local image = self.sea or Surface.new(640, 360)
    self.sea = image
    local e = (ox + (-cx + cy) * 32 * zoom) / 2
    local f = (oy + (-8 - cx - cy) * 16 * zoom) / 2
    local inverse = 1 / zoom
    local columns = self.columns or {}
    self.columns = columns
    if moved then for x = 0, 639 do columns[x + 1] = (x + .5 - e) * inverse * .5 end end
    local left, right = {}, {}
    if not moved then
        for i = 1, #self.changed_blocks do
            local block = self.changed_blocks[i]
            local x, y = block % 512, floor(block / 512)
            local x0 = max(0, floor(e + (x - y - 4) * zoom - .5))
            local x1 = min(640, math.ceil(e + (x - y + 4) * zoom + .5))
            local y0 = max(0, floor(f + (x + y) * zoom * .5 - .5))
            local y1 = min(360, math.ceil(f + (x + y + 8) * zoom * .5 + .5))
            if x1 > x0 then
                for row = y0, y1 - 1 do
                    left[row] = min(left[row] or 640, x0)
                    right[row] = max(right[row] or 0, x1)
                end
            end
        end
    end
    local pixels, ocean, changed_tiles = image.pixels, self.ocean.pixels, {}
    self.sea_changed = changed_tiles
    for y = 0, 359 do
        if moved or left[y] then
            local yy = (y + .5 - f) * inverse
            local row, tile_row = y * 640, floor(y / 128) * 5
            for x = moved and 0 or left[y], (moved and 640 or right[y]) - 1 do
                local xx = columns[x + 1]
                local sx, sy = yy + xx, yy - xx
                local color = sx >= 0 and sx < 512 and sy >= 0 and sy < 512
                    and ocean[floor(sy) * 512 + floor(sx) + 1] or 0x237590ff
                if pixels[row + x + 1] ~= color then
                    pixels[row + x + 1] = color
                    changed_tiles[tile_row + floor(x / 128) + 1] = true
                end
            end
            Work.check()
        end
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
