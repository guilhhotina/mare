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
