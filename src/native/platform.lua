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
