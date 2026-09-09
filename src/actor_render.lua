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

function ActorRender.new(activities, platform, traffic_sprite)
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
    return setmetatable({actions = actions, platform = platform, traffic_sprite = traffic_sprite, order = {}}, ActorRender)
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
    local elapsed = w.traffic_state.step + w.life_step
    local alpha = elapsed * .02
    for i = 1, #w.traffic do
        local p = w.traffic[i]
        if p.visible then
            local x = p.previous_x + (p.x - p.previous_x) * alpha
            local y = p.previous_y + (p.y - p.previous_y) * alpha
            local z = p.previous_z + (p.z - p.previous_z) * alpha
            count = order_actor(order, p, count, x + .5, y + .5, z, motion and self.traffic_sprite(p, elapsed) or p.still_sprite, nil, nil)
        end
    end
    for i = count + 1, #order do order[i] = nil end
    for i = 1, count do
        local p = order[i]
        self.platform.actor(p.draw_key, p.draw_x, p.draw_y, p.draw_z, p.draw_palette, p.draw_accessory_key)
    end
end

return ActorRender
