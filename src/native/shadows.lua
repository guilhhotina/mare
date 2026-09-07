local Surface = require('lua.native.surface')
local floor, min, max = math.floor, math.min, math.max
local Shadows = {}
Shadows.__index = Shadows

function Shadows.new(resources, heights)
    local file = assert(io.open('assets/shadow-shapes.bin', 'rb'))
    local points = assert(file:read('a'))
    assert(file:close())
    return setmetatable({resources = resources, heights = heights, points = points, projections = {}, field = {}, tiles = {}, cells = {}, shadow_cells = {}}, Shadows)
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
    self.n = n
    for i = 1, n * n // 32 do field[i] = 0 end
    self.tiles, self.cells, self.shadow_cells = {}, {}, {}
    local objects = {}
    for row in scene:gmatch('[^;]+') do
        local name, x, y, z, powered = row:match('([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)')
        local object = {name, tonumber(x), tonumber(y), tonumber(z), powered == '1'}
        objects[#objects + 1] = object
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
    if not daylight then return end
    local t = ((bin + .5) / 48 - .18) / .61
    local angle = -math.pi * .92 + t * math.pi * 1.1
    local altitude = .33 + math.sin(t * math.pi) * 1.8
    local dx, dy = math.cos(angle) / (16 * altitude), math.sin(angle) / (16 * altitude)
    local cells = self.shadow_cells
    local function cast(x, y, z)
        local distance = max(0, z - self:ground(x, y))
        local px, py = x + dx * distance, y + dy * distance
        for _ = 1, 4 do
            distance = max(0, z - self:ground(px, py))
            px, py = x + dx * distance, y + dy * distance
        end
        local xx, yy = floor(px * res + .5), floor(py * res + .5)
        if xx < 0 or yy < 0 or xx >= n - 2 or yy >= n - 2 then return end
        local bit = xx % 32
        local mask = (7 << bit) & 0xffffffff
        local spill = bit > 29 and 7 >> (32 - bit) or 0
        for row = 0, 2 do
            local k = ((yy + row) * n + xx) // 32 + 1
            field[k] = field[k] | mask
            if spill ~= 0 then field[k + 1] = field[k + 1] | spill end
        end
        cells[(yy // res) * 24 + xx // res + 1] = true
        cells[((yy + 2) // res) * 24 + (xx + 2) // res + 1] = true
        cells[(yy // res) * 24 + (xx + 2) // res + 1] = true
        cells[((yy + 2) // res) * 24 + xx // res + 1] = true
    end
    for _, object in ipairs(objects) do
        local meta = self.resources.sprites[object[1]]
        if meta.cast then
            for i = meta.cast[1], meta.cast[1] + meta.cast[2] - 1 do
                local point = string.unpack('<I4', self.points, i * 4 + 1)
                cast(object[2] + ((point & 1023) - 64) / 64, object[3] + (((point >> 10) & 1023) - 64) / 64, object[4] + (point >> 20))
            end
        end
    end
end

function Shadows:projection(corners)
    local cached = self.projections[corners]
    if cached then return cached end
    local heights = {corners & 1 ~= 0 and 16 or 0, corners & 2 ~= 0 and 16 or 0, corners & 4 ~= 0 and 16 or 0, corners & 8 ~= 0 and 16 or 0}
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

function Shadows:paint(target, wx, wy, sx, sy, zoom, corners, mask, coarse, light)
    local cell = wy * 24 + wx + 1
    local near = self.cells[cell]
    if light and not near then return end
    if not light and (not self.sun or (not self.shadow_cells[cell] and mask == '')) then return end
    local key = cell .. ':' .. corners .. ':' .. tostring(light) .. ':' .. mask
    local tile = self.tiles[key]
    if tile == nil then
        tile = Surface.new(65, 65)
        local projection, hits = self:projection(corners), 0
        for i = 1, 65 * 65 do
            local uv = projection[i]
            if uv then
                local u, v, alpha = uv[1], uv[2], 0
                local color
                if light then
                    local x, y = wx + u, wy + v
                    local z = self:ground(x, y)
                    for _, emitter in ipairs(near) do
                        local du, dv = x - emitter[1], y - emitter[2]
                        local radius = min(.9, max(.2, (emitter[3] - z) / 30))
                        local d = (du * du + dv * dv) / (radius * radius)
                        if d < 1 then alpha = max(alpha, d < .12 and 72 or d < .4 and 46 or d < .7 and 26 or 12) end
                    end
                    color = 0xffce7700 | alpha
                else
                    local k = (wy * self.res + floor(v * self.res)) * self.n + wx * self.res + floor(u * self.res)
                    local hit = self.field[k // 32 + 1] & (1 << (k % 32)) ~= 0
                    local terrain = mask:byte(floor(v * coarse) * coarse + floor(u * coarse) + 1) == 49
                    alpha = (hit or terrain) and 80 or 0
                    color = 0x19273e00 | alpha
                end
                if alpha > 0 then tile.pixels[i] = color; hits = hits + 1 end
            end
        end
        if hits == 0 then tile = false end
        self.tiles[key] = tile
    end
    if tile then target:blit(tile, floor(sx - 32 * zoom + .5), floor(sy - 17 * zoom + .5), zoom) end
end

return Shadows
