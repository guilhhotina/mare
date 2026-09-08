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
