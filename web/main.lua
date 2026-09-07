local b48aa = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
local r48aa = function(i, f)
return function()
local c = f()
b48aa[i] = function() return c end
return c
end
end
local math = ((function() local x, y = pcall(require, 'math'); return x and y end)()) or _G.math
local function m48aa()
local version = b48aa[1]('source_version')
local util_decorator = b48aa[2]('source_shared_functional_decorator')
local dom = b48aa[3]('source_engine_browser_dom')
local loadcore = b48aa[4]('source_shared_engine_loadcore')
local loadgame = b48aa[5]('source_shared_engine_loadgame')
local error_module = b48aa[6]('source_engine_core_error')
local engine_draw_fps = b48aa[7]('source_engine_api_draw_fps')
local engine_draw_poly = b48aa[8]('source_engine_api_draw_poly')
local engine_draw_text = b48aa[9]('source_engine_api_draw_text')
local engine_draw_ui = b48aa[10]('source_engine_api_draw_ui')
local engine_draw_img = b48aa[11]('source_engine_api_draw_image')
local engine_encoder = b48aa[12]('source_engine_api_data_encoder')
local engine_hash = b48aa[13]('source_engine_api_data_hash')
local engine_i18n = b48aa[14]('source_engine_api_data_i18n')
local engine_log = b48aa[15]('source_engine_api_debug_log')
local engine_http = b48aa[16]('source_engine_api_io_http')
local engine_media = b48aa[17]('source_engine_api_io_media')
local engine_storage = b48aa[18]('source_engine_api_io_storage')
local engine_raw_bus = b48aa[19]('source_engine_api_raw_bus')
local engine_raw_memory = b48aa[20]('source_engine_api_raw_memory')
local engine_raw_node = b48aa[21]('source_engine_api_raw_node')
local engine_env = b48aa[22]('source_engine_api_system_getenv')
local engine_color = b48aa[23]('source_engine_api_system_color')
local engine_game = b48aa[24]('source_engine_api_system_app')
local engine_key = b48aa[25]('source_engine_api_system_key')
local engine_math = b48aa[26]('source_engine_api_math_basic')
local engine_math_clib = b48aa[27]('source_engine_api_math_clib')
local engine_math_random = b48aa[28]('source_engine_api_math_random')
local callback_http = b48aa[29]('source_engine_protocol_http_callback')
local application_default = b48aa[30]('source_shared_var_object_root')
local std = b48aa[31]('source_shared_var_object_std')
local application = application_default
local engine = {
current = application_default,
root = application_default,
dom = {},
offset_x = 0,
offset_y = 0
}
local cfg_system = {
exit = native_system_exit,
reset = native_system_reset,
title = native_system_title,
get_fps = native_system_get_fps,
get_secret = native_system_get_secret,
get_language = native_system_get_language
}
local cfg_media = {
bootstrap=native_media_bootstrap,
position=native_media_position,
resize=native_media_resize,
resume=native_media_resume,
source=native_media_source,
pause=native_media_pause,
play=native_media_play,
stop=native_media_stop
}
local cfg_image = {
load = native_image_load,
draw = native_image_draw,
exists = native_image_exists,
mensure = native_image_mensure,
unload = native_image_unload,
unload_all = native_image_unload_all
}
local cfg_poly = {
repeats = {
native_cfg_poly_repeat_0 or false,
native_cfg_poly_repeat_1 or false,
native_cfg_poly_repeat_2 or false
},
triangle = native_draw_triangle,
poly2 = native_draw_poly2,
poly = native_draw_poly,
line = native_draw_line
}
local cfg_http = {
sock = native_http_sock,
install = native_http_install,
handler = native_http_handler,
has_ssl = native_http_has_ssl,
force = native_http_force_protocol
}
local cfg_log = {
fatal = native_log_fatal,
error = native_log_error,
warn = native_log_warn,
info = native_log_info,
debug = native_log_debug
}
local cfg_base64 = {
decode = native_base64_decode,
encode = native_base64_encode
}
local cfg_json = {
decode = native_json_decode,
encode = native_json_encode
}
local cfg_xml = {
decode = native_xml_decode,
encode = native_xml_encode
}
local cfg_text = {
is_tui = native_text_is_tui,
font_previous = native_text_font_previous
}
local cfg_storage = {
install = native_storage_install and function() native_storage_install() end,
get = native_storage_get,
set = native_storage_set
}
local cfg_env = {
get_env = native_system_get_env
}
local cfg_key = {
has_media = native_keyboard_has_media,
}
local function clear(tint)
local x, y = engine.offset_x, engine.offset_y
local width, height = engine.current.data.width, engine.current.data.height
native_draw_clear(tint, x, y, width, height)
end
function native_callback_loop(dt)
std.milis = std.milis + dt
std.delta = dt
std.bus.emit('loop')
end
function native_callback_draw()
native_draw_start()
std.bus.emit('draw')
native_draw_flush()
end
function native_callback_resize(width, height)
engine.root.data.width = width
engine.root.data.height = height
std.app.width = width
std.app.height = height
std.bus.emit('resize', width, height)
end
function native_callback_keyboard(key, value)
std.bus.emit('rkey', key, value)
end
function native_callback_http(id, key, data)
return callback_http.func(engine['http'][id], key, data, std)
end
function native_callback_init(width, height, game_lua)
application = loadgame.script(game_lua, application_default)
if application then
application.data.width = width
application.data.height = height
std.app.width = width
std.app.height = height
end
std.draw.color=native_draw_color
std.draw.clear=clear
std.draw.rect2=util_decorator.offset_xy2(engine, native_draw_rect2 or native_draw_rect)
std.draw.rect=util_decorator.offset_xy2(engine, native_draw_rect)
std.draw.line=util_decorator.offset_xyxy1(engine, native_draw_line)
std.text.print = util_decorator.offset_xy1(engine, native_text_print)
std.text.mensure=native_text_mensure
std.text.font_size=native_text_font_size
std.text.font_name=native_text_font_name
std.text.font_default=native_text_font_default
engine.handler = error_module.make_handler(engine, std, function()
(native_system_exit or native_system_fatal or function() end)()
end)
loadcore.setup(std, application, engine)
:package('@bus', engine_raw_bus)
:package('@node', engine_raw_node)
:package('@memory', engine_raw_memory)
:package('@game', engine_game, cfg_system)
:package('@math', engine_math)
:package('@key', engine_key, cfg_key)
:package('@draw.ui', engine_draw_ui)
:package('@draw.img', engine_draw_img, cfg_image)
:package('@draw.fps', engine_draw_fps)
:package('@draw.text', engine_draw_text, cfg_text)
:package('@draw.poly', engine_draw_poly, cfg_poly)
:package('@color', engine_color)
:package('@log', engine_log, cfg_log)
:package('@env', engine_env, cfg_env)        
:package('math', engine_math_clib)
:package('math.random', engine_math_random)
:package('http', engine_http, cfg_http)
:package('base64', engine_encoder, cfg_base64)
:package('json', engine_encoder, cfg_json)
:package('xml', engine_encoder, cfg_xml)
:package('i18n', engine_i18n, cfg_system)
:package('media.video', engine_media, cfg_media)
:package('media.music', engine_media, cfg_media)
:package('mock.video', engine_media)
:package('mock.music', engine_media)
:package('storage', engine_storage, cfg_storage)
:package('hash', engine_hash, cfg_system)
:run()
application.data.width, std.app.width = width, width
application.data.height, std.app.height = height, height
std.app.title(application.meta.title..' - '..application.meta.version)
engine.dom = dom.node_begin(application, std.app.width, std.app.height, engine.dom)
engine.root, engine.current = application, application
std.bus.emit_next('load')
std.bus.emit_next('init')
end
local P = {
meta={
title='gly-engine',
author='RodrigoDornelles',
description='native core',
version=version
}
}
return P
end
b48aa[1] = r48aa(1, function()
return '0.4.0'
end)
b48aa[2] = r48aa(2, function()
local function decorator_prefix3(zig, zag, zom, func)
return function (a, b, c, d, e, f)
return func(zig, zag, zom, a, b, c, d, e, f)
end
end
local function decorator_prefix2(zig, zag, func)
return function (a, b, c, d, e, f)
return func(zig, zag, a, b, c, d, e, f)
end
end
local function decorator_prefix1(zig, func)
return function (a, b, c, d, e, f)
return func(zig, a, b, c, d, e, f)
end
end
local function decorator_offset_xy2(object, func)
return function(a, b, c, d, e, f)
local x = object.offset_x + (b or 0)
local y = object.offset_y + (c or 0)
return func(a, x, y, d, e, f)
end
end
local function decorator_offset_xyxy1(object, func)
return function(a, b, c, d, e, f)
local x1 = object.offset_x + a
local y1 = object.offset_y + b
local x2 = object.offset_x + c
local y2 = object.offset_y + d
return func(x1, y1, x2, y2, e, f)
end
end
local function decorator_offset_xy1(object, func)
return function(a, b, c, d, e, f)
local x = object.offset_x + a
local y = object.offset_y + b
return func(x, y, c, d, e, f)
end
end
local function table_prefix1(prefix, fn_table)
local new_table = {}
for name, fn in pairs(fn_table) do
new_table[name] = decorator_prefix1(prefix, fn)
end
return new_table
end
local P = {
offset_xy1 = decorator_offset_xy1,
offset_xy2 = decorator_offset_xy2,
offset_xyxy1 = decorator_offset_xyxy1,
prefix3 = decorator_prefix3,
prefix2 = decorator_prefix2,
prefix1 = decorator_prefix1,
prefix1_t = table_prefix1
}
return P
end)
b48aa[3] = r48aa(3, function()
local ss = b48aa[32]('source_engine_browser_stylesheet')
local pause = b48aa[33]('source_engine_browser_pause')
local layout = b48aa[34]('source_engine_browser_layout')
local lifecycle = b48aa[35]('source_engine_browser_lifecycle')
local uid_counter = 0
local walk
local mark_dirty
walk = function(node, fn)
fn(node)
if node.childs then
for _, child in ipairs(node.childs) do
walk(child, fn)
end
end
end
mark_dirty = function(self, node)
self.dirty_queue[#self.dirty_queue + 1] = node
end
local function flush_dirty(self)
local queue = self.dirty_queue
if #queue == 0 then return end
for i = 1, #queue do
if queue[i] == self.root then
layout.dom_layout(self, self.root, 0, 0, self.width, self.height)
for j = #queue, 1, -1 do queue[j] = nil end
return
end
end
local processed = {}
for i = 1, #queue do
local node = queue[i]
local uid  = node.config.uid
if uid and not processed[uid] then
layout.dom_layout(self, node, node.config.offset_x, node.config.offset_y,
node.data.width, node.data.height)
walk(node, function(n)
if n.config.uid then
processed[n.config.uid] = true
end
end)
end
end
for i = #queue, 1, -1 do queue[i] = nil end
end
local function effective_z(node, cache)
local cached = cache[node]
if cached ~= nil then return cached end
local z = node.config._style_z
if z and z ~= 0 then
cache[node] = z
return z
end
local parent = node.config.parent
if parent then
z = effective_z(parent, cache)
else
z = 0
end
cache[node] = z
return z
end
local function sort_list(self)
local src      = self.node_list
local dispatch = self.dispatch_list
local n        = #src
local trivial = true
for i = 1, n do
local z = src[i].config._style_z
if z and z ~= 0 then trivial = false; break end
end
if trivial then
for i = 1, n do dispatch[i] = src[i] end
for i = n + 1, #dispatch do dispatch[i] = nil end
return
end
local cache = {}
local index = {}
for i = 1, n do index[src[i]] = i end
for i = 1, n do dispatch[i] = src[i] end
for i = n + 1, #dispatch do dispatch[i] = nil end
local root = self.root
table.sort(dispatch, function(a, b)
if a == root then return true  end
if b == root then return false end
local za, zb = effective_z(a, cache), effective_z(b, cache)
if za ~= zb then return za < zb end
return index[a] < index[b]
end)
end
local function compile(self)
local list  = self.render_list
local index = 0
local sw, sh = self.width, self.height
local source = self.dispatch_list
for i = 1, #source do
local node = source[i]
local cfg  = node.config
local paused_all = pause.is_paused(self, cfg.uid, '*')
local visible = cfg.visible ~= false
and not paused_all
and not cfg._scroll_clipped
and not cfg._span_hidden
and cfg.offset_x + node.data.width  > 0
and cfg.offset_x < sw
and cfg.offset_y + node.data.height > 0
and cfg.offset_y < sh
if visible then
index = index + 1
local entry = list[index]
if not entry then
entry = {}
list[index] = entry
end
entry.uid  = cfg.uid
entry.x    = cfg.offset_x
entry.y    = cfg.offset_y
entry.w    = node.data.width
entry.h    = node.data.height
entry.node = node
end
end
for i = index + 1, #list do
list[i] = nil
end
end
local function rebuild_list(self)
local new_list = { self.root }
for i = 2, #self.node_list do
if self.node_list[i].config.parent then
new_list[#new_list + 1] = self.node_list[i]
end
end
self.node_list = new_list
end
local function rebuild_tree_from_parents(self)
for i = 1, #self.node_list do
self.node_list[i].childs = {}
end
for i = 1, #self.node_list do
local node   = self.node_list[i]
local parent = node.config.parent
if parent then
parent.childs[#parent.childs + 1] = node
end
end
end
local function node_begin(node, width, height, self, std)
self = self or {}
self.width  = width
self.height = height
self.root   = node
self.std    = std or self.std
self.node_list = { node }
self.dispatch_list = { node }
self.render_list = self.render_list or {}
self.dirty_queue = self.dirty_queue or {}
self.index_uid   = {}
self.index_id    = {}
self.index_class = {}
self.scroll_registry = setmetatable(self.scroll_registry or {}, { __mode = 'k' })
self.pause_registry = self.pause_registry or {}
self.focus_list    = {}
self.focus_current = nil
self.current_node = nil
self.stylesheet_dict = self.stylesheet_dict or {}
self.stylesheet_func = self.stylesheet_func or {}
self.stylesheet_key  = self.stylesheet_key or {}
self.stylesheet_meta = self.stylesheet_meta or {}
self.flag_relist   = false
self.flag_reparent = false
self.flag_resort   = false
node.config.css  = {}
node.config.type = 'root'
node.config.uid  = 0
self.index_uid[0] = node
ss.init(mark_dirty)
return self
end
local function node_add(self, node, options)
local parent = options.parent
local dat    = node.data
local cfg    = node.config
if not parent.childs then
parent.childs = {}
end
if cfg.parent then
local old = cfg.parent
if old.childs then
for i = #old.childs, 1, -1 do
if old.childs[i] == node then
table.remove(old.childs, i)
break
end
end
end
parent.childs[#parent.childs + 1] = node
cfg.parent = parent
cfg.size   = options.size   or cfg.size   or 1
cfg.after  = options.after  or cfg.after  or 0
cfg.offset = options.offset or cfg.offset or 0
if options.id and not cfg.id then
cfg.id = options.id
self.index_id[options.id] = node
end
self.flag_reparent = true
mark_dirty(self, parent)
return
end
uid_counter = uid_counter + 1
cfg.uid = uid_counter
self.index_uid[uid_counter] = node
if options.id then
cfg.id = options.id
self.index_id[options.id] = node
end
if options.class then
cfg.class = type(options.class) == 'table' and options.class or { options.class }
for _, name in ipairs(cfg.class) do
if not self.index_class[name] then
self.index_class[name] = {}
end
local list = self.index_class[name]
list[#list + 1] = node
end
end
self.node_list[#self.node_list + 1] = node
dat.width, dat.height = layout.cells(parent)
parent.childs[#parent.childs + 1] = node
cfg.css    = {}
cfg.parent = parent
cfg.size   = options.size   or 1
cfg.after  = options.after  or 0
cfg.offset = options.offset or 0
lifecycle.spawn(self, node)
local has_handler = node.callbacks.focus   or node.callbacks.unfocus
or node.callbacks.click   or node.callbacks.hover
local focusable = options.focusable
if focusable == nil then
focusable = has_handler ~= nil
end
if focusable then
cfg.focusable = true
self.focus_list[#self.focus_list + 1] = node
end
self.flag_reparent = true
self.flag_resort   = true
mark_dirty(self, parent)
end
local function node_del(self, node_root)
local focused = self.focus_current
if focused then
local anc = focused
while anc do
if anc == node_root then
lifecycle.unfocus(self, focused)
self.focus_current = nil
break
end
anc = anc.config.parent
end
end
walk(node_root, function(node)
lifecycle.kill(self, node)
local uid = node.config.uid
if uid then
self.index_uid[uid] = nil
if node.config.id then
self.index_id[node.config.id] = nil
end
if node.config.class then
for _, cls in ipairs(node.config.class) do
local list = self.index_class[cls]
if list then
for i = #list, 1, -1 do
if list[i] == node then
table.remove(list, i)
break
end
end
end
end
end
self.pause_registry[uid] = nil
end
if node.config.focusable then
for i = #self.focus_list, 1, -1 do
if self.focus_list[i] == node then
table.remove(self.focus_list, i)
break
end
end
if self.focus_current == node then
self.focus_current = nil
end
end
self.scroll_registry[node] = nil
node.data          = {}
node.config.css    = {}
node.config.parent = nil
end)
self.flag_relist   = true
self.flag_reparent = true
mark_dirty(self, self.root)
end
local function resize(self, width, height)
self.width  = width
self.height = height
mark_dirty(self, self.root)
end
local function bus(self, key, handler_func)
if self.flag_relist then
rebuild_list(self)
self.flag_relist = false
self.flag_resort = true
end
if self.flag_reparent then
rebuild_tree_from_parents(self)
self.flag_reparent = false
self.flag_resort = true
end
if self.flag_resort then
sort_list(self)
self.flag_resort = false
end
flush_dirty(self)
compile(self)
local list = self.dispatch_list
local root = self.root
local i = 1
while i <= #list do
local node = list[i]
local skip = node ~= root and (pause.is_paused(self, node.config.uid, key) or node.config._scroll_clipped or node.config._span_hidden)
if not skip then
self.current_node = node
handler_func(node)
self.current_node = nil
end
i = i + 1
end
end
local P = {
node_begin  = node_begin,
node_add    = node_add,
node_del    = node_del,
resize      = resize,
flush_dirty = flush_dirty,
mark_dirty  = mark_dirty,
compile     = compile,
bus         = bus,
walk        = walk,
cells      = layout.cells,
parse_span = layout.parse_span,
slide_step = layout.slide_step,
dom_layout = layout.dom_layout,
}
return P
end)
b48aa[4] = r48aa(4, function()
local zeebo_pipeline = b48aa[36]('source_shared_functional_pipeline')
local requires = b48aa[37]('source_shared_string_dsl_requires')
local function step_install_libsys(self, lib_name, library, custom, is_system)
if not is_system then return end
local ok, msg = pcall(function()
library.install(self.std, self.engine, custom, lib_name)
end)
if ok then
self.libsys[lib_name] = true
else
self.error('sys', lib_name, msg)
end
end
local function step_check_libsys(self, lib_name, library, custom, is_system)
if not is_system then return end
if not self.libsys[lib_name] then
self.error('sys', lib_name, 'is missing!')
end
end
local function step_install_libusr(self, lib_name, library, custom, is_system)
if is_system then return end
if self.libusr[lib_name] then return end
if not requires.should_import(self.spec, lib_name) then return end
self.libusr[lib_name] = pcall(function()
library.install(self.std, self.engine, custom, lib_name)
end)
end
local function step_check_libsys_all(self)
local missing = requires.missing(self.spec, self.libusr)
if #missing > 0 then
self.error('usr', '*', 'missing libs: '..table.concat(missing, ' '))
end
end
local function package(self, lib_name, library, custom)
self.pipeline[#self.pipeline + 1] = function()
local is_system = lib_name:sub(1, 1) == '@'
local name = is_system and lib_name:sub(2) or lib_name
self:step(name, library, custom, is_system)
end
return self
end
local function setup(std, application, engine)
if not application then
error('game not found!')
end
local spec = requires.encode((application.config or application).require or '')
local self = {
std = std,
spec = spec,
errmsg = '',
engine = engine,
package = package,
libusr = {},
libsys = {},
pipeline = {},
pipe = zeebo_pipeline.pipe
}
self.error = function (prefix, lib_name, message) 
self.errmsg = self.errmsg..'['..prefix..':'..lib_name..'] '..message..'\n'
end
self.run = function()
self.step = step_install_libsys
zeebo_pipeline.reset(self)
zeebo_pipeline.run(self)
self.step = step_check_libsys
zeebo_pipeline.reset(self)
zeebo_pipeline.run(self)
self.step = step_install_libusr
zeebo_pipeline.reset(self)
zeebo_pipeline.run(self)
step_check_libsys_all(self)
if #self.errmsg > 0 then
error(self.errmsg, 0)
end
end
return self
end
local P = {
setup = setup
}
return P
end)
b48aa[5] = r48aa(5, function()
local eval_file = b48aa[38]('source_shared_string_eval_file')
local eval_code = b48aa[39]('source_shared_string_eval_code')
local has_io_open = io and io.open
local function normalize(app, base)
if not app then return nil end
if not app.callbacks then
local old_app = app
app = {meta={},config={},callbacks={}, data={}, envs={}}
for key, value in pairs(old_app) do
local is_function = type(value) == 'function'
if base.meta and base.meta[key] and not is_function then
app.meta[key] = value
elseif base.config and base.config[key] and not is_function then
app.config[key] = value
elseif is_function then
app.callbacks[key] = value
elseif app[key] then
app[key] = value
else
app.data[key] = value
end
end
end
local function defaults(a, b, key)
if type(a[key]) ~= "table" then a[key] = {} end
for k, v in pairs(b[key]) do
if a[key][k] == nil then
a[key][k] = b[key][k]
end
end
end
for field in pairs(base) do
defaults(app, base, field)
end
return app
end
local function script(src, base)
if not src and package and package.jspath then
src = {}
end
if type(src) == 'table' or type(src) == 'userdata' then
return normalize(src, base)
end
local application = type(src) == 'function' and src
if not application then
if type(src) ~= 'string' or #src == 0 then
src = 'game'
end
if src:find('\n') then
local ok, app = eval_code.script(src)
application = ok and app
else
local ok, app = eval_file.script(src)
application = ok and app
end
if not application and has_io_open then
local app_file = io.open(src)
if app_file then
local app_src = app_file:read('*a')
local ok, app = eval_code.script(app_src)
application = ok and app
app_file:close()
end
end
end     
while type(application) == 'function' do
application = application()
end
return normalize(application, base)
end
local P = {
script = script
}
return P
end)
b48aa[6] = r48aa(6, function()
local function make_handler(engine, std, quit)
local last_msg
return function(msg)
msg = tostring(msg)
if msg == last_msg then return end
last_msg = msg
local handler = engine.root and engine.root.callbacks.error
if not handler then
print('[error] ' .. msg)
quit()
return
end
local ok, should_quit = pcall(handler, engine.root.data, std, msg)
if not ok or should_quit == true then
quit()
end
end
end
return { make_handler = make_handler }
end)
b48aa[7] = r48aa(7, function()
local function draw_fps(std, engine, show, pos_x, pos_y)
if show < 1 then return end
local x = engine.current.config.offset_x + pos_x
local y = engine.current.config.offset_y + pos_y
local s = 4
std.draw.color(0xFFFF00FF)
if show >= 1 then
std.draw.rect(0, x, y, 40, 24)
end
if show >= 2 then
std.draw.rect(0, x + 48, y, 40, 24)
end
if show >= 3 then
std.draw.rect(0, x + 96, y, 40, 24)
end
std.draw.color(0x000000FF)
std.text.font_size(16)
if show >= 3 then
local floor = std.math.floor or math.floor or function() return 'XX' end
local fps =  floor((1/std.delta) * 1000)
std.text.print(x + s, y, fps)
s = s + 46
end
if show >= 1 then
std.text.print(x + s, y, engine.fps)
s = s + 46
end
if show >= 2 then
std.text.print(x + s, y, engine.root.config.fps_max)
s = s + 46
end
end
local function install(std, engine)
std.app = std.app or {}
std.app.fps_show = function(show)
engine.root.config.fps_show = show
end
std.bus.listen('post_draw', function()
engine.current = engine.root
draw_fps(std, engine, engine.root.config.fps_show, 8, 8)
end)
end
local P = {
install=install
}
return P
end)
b48aa[8] = r48aa(8, function()
local function decorator_poo(object, func)
if not object or not func then return func end
return function(a, b, c, d)
return func(object, a, b, c, d)
end
end
local function decorator_line(func_draw_line)
return function(mode, verts)
local index = 4
while index <= #verts do
func_draw_line(verts[index - 3], verts[index - 2], verts[index - 1], verts[index])
index = index + 2
end
end
end
local function decorator_triangle(func_draw_poly, std, func_draw_triangle)
if not func_draw_triangle then
return func_draw_poly
end
local point = function(x, y, px, py, scale, angle, ox, oy)
local xx = x + ((ox - px) * -scale * std.math.cos(angle)) - ((ox - py) * -scale * std.math.sin(angle))
local yy = y + ((oy - px) * -scale * std.math.sin(angle)) + ((oy - py) * -scale * std.math.cos(angle))
return xx, yy
end
return function(engine_mode, verts, x, y, scale, angle, ox, oy)
if #verts ~= 6 then
return func_draw_poly(engine_mode, verts, x, y, scale, angle, ox, oy)
end
ox = ox or 0
oy = oy or ox or 0
local x1, y1 = point(x, y, verts[1], verts[2], scale, angle, ox, oy)
local x2, y2 = point(x, y, verts[3], verts[4], scale, angle, ox, oy)
local x3, y3 = point(x, y, verts[5], verts[6], scale, angle, ox, oy)
return func_draw_triangle(engine_mode, x1, y1, x2, y2, x3, y3)
end
end
local function decorator_poly(func_draw_poly, std, modes, repeats)
local func_repeat = function(verts, mode)
if repeats and repeats[mode + 1] then
verts[#verts + 1] = verts[1]
verts[#verts + 1] = verts[2]
end
end
return function (engine_mode, verts, x, y, scale, angle, ox, oy)
if #verts < 6 or #verts % 2 ~= 0 then return end
local mode = modes and modes[engine_mode + 1] or engine_mode
local rotated = std.math.cos and angle and angle ~= 0
ox = ox or 0
oy = oy or ox or 0
if x and y and not rotated then
local index = 1
local verts2 = {}
scale = scale or 1
while index <= #verts do
if index % 2 ~= 0 then
verts2[index] = x + (verts[index] * scale)
else
verts2[index] = y + (verts[index] * scale)
end
index = index + 1
end
func_repeat(verts2, engine_mode)
func_draw_poly(mode, verts2)
elseif x and y then
local index = 1
local verts2 = {}
while index < #verts do
local px = verts[index]
local py = verts[index + 1]
local xx = x + ((ox - px) * -scale * std.math.cos(angle)) - ((ox - py) * -scale * std.math.sin(angle))
local yy = y + ((oy - px) * -scale * std.math.sin(angle)) + ((oy - py) * -scale * std.math.cos(angle))
verts2[index] = xx
verts2[index + 1] = yy
index = index + 2
end
func_repeat(verts2, engine_mode)
func_draw_poly(mode, verts2)
else
func_draw_poly(mode, verts)
end
end
end
local function decorator_position(engine, func)
return function(mode, verts, pos_x, pos_y, scale, angle, ox, oy)
local x = engine.current.config.offset_x + (pos_x or 0)
local y = engine.current.config.offset_y + (pos_y or 0)
ox = ox or 0
oy = ox or oy or 0
scale = scale or 1
angle = angle or 0
return func(mode, verts, x, y, scale, angle, ox, oy)
end
end
local function install(std, engine, config)
local draw_line = decorator_poo(config.object, config.line)
local draw_poly = decorator_poo(config.object, config.poly) or decorator_line(draw_line)
local draw_poly2 = config.poly2 or decorator_poly(draw_poly, std, config.modes, config.repeats)
local draw_verts = decorator_triangle(draw_poly2, std, config.triangle)
std.draw.poly = decorator_position(engine, draw_verts)
end
local P = {
install=install
}
return P
end)
b48aa[9] = r48aa(9, function()
local function text_put(std, engine, font_previous)
return function(pos_x, pos_y, text, size)
size = size or 2
local hem = engine.current.data.width / 80
local vem = engine.current.data.height / 24
local font_size = hem * size
std.text.font_default(0)
std.text.font_size(font_size)
std.text.print(pos_x * hem, pos_y * vem, text)
font_previous()
end
end
local function text_print_ex(std, engine)
return function(x, y, text, align_x, align_y)
local w, h = std.text.mensure(text)
local aligns_x, aligns_y = {w, w/2, 0}, {h, h/2, 0}
std.text.print(x - aligns_x[(align_x or 1) + 2], y - aligns_y[(align_y or 1) + 2], text)
return w, h
end
end
local function install(std, engine, config)
std.text.font_previous = config.font_previous
std.text.is_tui = config.is_tui or function() return false end
std.text.print_ex = text_print_ex(std, engine)
std.text.put = text_put(std, engine, config.font_previous)
end
local P = {
install=install
}
return P
end)
b48aa[10] = r48aa(10, function()
local browser_ui = b48aa[40]('source_engine_browser_ui')
local browser_jsx = b48aa[41]('source_engine_browser_jsx')
local function install(std, engine, application)
browser_ui.install(std, engine)
browser_jsx.install(std, engine)
end
local P = {
install = install
}
return P
end)
b48aa[11] = r48aa(11, function()
local function image_draw(func, engine)
return function(src, pos_x, pos_y)
local x = engine.offset_x + (pos_x or 0)
local y = engine.offset_y + (pos_y or 0)
func(src, x, y)
end  
end
local function image_mensure(func)
return function(src)
return func(src)
end
end
local function image_load(func)
return function(src, url_wip)
return func(src, url_wip)
end
end
local function image_exists(func)
return function(src)
return not not func(src)
end
end
local function image_unload(func)
return function(src)
return func(src)
end
end
local function image_unload_all(func)
return function(src)
return func(src)
end
end
local function install(std, engine, func)
local f = func.unload or function() end
std.image.load = image_load(func.load)
std.image.draw = image_draw(func.draw, engine)
std.image.exists = image_exists(func.load)
std.image.mensure = image_mensure(func.mensure)
std.image.unload = image_unload(func.unload or f)
std.image.unload_all = image_unload_all(func.unload_all or f)
end
return {
install = install
}
end)
b48aa[12] = r48aa(12, function()
local function install(std, engine, library, name)
std = std or {}
std[name] = {
encode=library.encode,
decode=library.decode
}
return {[name]=std[name]}
end
local P = {
install=install
}
return P
end)
b48aa[13] = r48aa(13, function()
local function djb2(digest)
local index = 1
local hash = 5381
while index <= #digest do
local char = string.byte(digest, index)
hash = (hash * 33 + char) % 4294967296
index = index + 1
end
return hash
end
local function install(std, engine, cfg_system)
local id = djb2(cfg_system.get_secret())
std = std or {}
std.hash = std.hash or {}
std.hash.djb2 = djb2
std.hash.fingerprint = function() return id end
end
local P = {
install = install
}
return P
end)
b48aa[14] = r48aa(14, function()
local language = 'en-US'
local language_default = 'en-US'
local language_list = {}
local language_inverse_list = {}
local translate = {}
local function update_languages(texts)
local index = 1
translate = texts
language_list = {language_default}
language_inverse_list = {[language_default]=1}
repeat
local lang = next(texts)
if lang then
index = index + 1
language_inverse_list[lang] = index
language_list[#language_list + 1] = lang
end
until lang
end
local function get_text(old_text)
local new_text = translate[language] and translate[language][old_text]
return new_text or old_text
end
local function get_language()
return language
end
local function set_language(l)
if language_inverse_list[l] then
language = l
else 
language = language_default
end
end
local function next_language(to)
local index = language_inverse_list[language]
local incr = to or 1
if index then
index = index + incr
if index > #language_list then
index = 1
end
if index <= 0 then
index = #language_list
end
index = index == 0 and 1 or index
set_language(language_list[index])
end
end
local function back_language()
next_language(-1)
end
local function decorator_draw_text(func)
return function (x, y, text, a, b, c)
return func(x, y, get_text(text), a, b, c)
end
end
local function install(std, engine, cfg)
if not (std and std.text and std.text.print) then
error('missing draw text')
end
local old_put = std.text.put
local old_print = std.text.print
local old_print_ex = std.text.print_ex
local callback_lang = function(result)
update_languages(result)
if cfg and cfg.get_language then
set_language(cfg.get_language())
end
end
if not std.node and engine.root.callbacks.i18n then
callback_lang(engine.root.callbacks.i18n())
else
std.bus.listen('ret_i18n', callback_lang)
std.bus.emit_next('i18n')
end
std.text.put = decorator_draw_text(old_put)
std.text.print = decorator_draw_text(old_print)
std.text.print_ex = decorator_draw_text(old_print_ex)
std.i18n = {}
std.i18n.get_text = get_text
std.i18n.get_language = get_language
std.i18n.set_language = set_language
std.i18n.back = back_language
std.i18n.next = next_language
end
local P = {
install=install
}
return P
end)
b48aa[15] = r48aa(15, function()
local yaml = b48aa[42]('source_shared_string_encode_yaml')
local levels = { none = 0, fatal = 1, error = 2, warn = 3, info = 4, debug = 5, trace = 6}
local function printer(engine, printers, func_a, func_b)
local fn_a = func_a and printers[func_a]
local fn_b = func_b and printers[func_b]
local func = fn_a or fn_b or function() end
local level = levels[func_a] or 7
return function (...)
local msgs = {...}
local count = #msgs
if level <= engine.loglevel then
local content = ''
for i = 1, count do
local v = msgs[i]
local t = type(v)
if t == 'table' then
content = content..'\n'..yaml.encode(v)..'\n'
elseif t ~= 'function' then
local add_space = i ~= count and i > 1 and content:sub(-1) ~= '\n'
local prefix = add_space and ' ' or ''
content = content..prefix..tostring(v)
end
end
func(content)
end
end
end
local function level(engine)
return function(n)
local lv = levels[n] or (type(n) == 'number' and n) or -1
if lv < 0 or 6 < lv then
error('logging level not exist: '..tostring(level)) 
end
engine.loglevel = lv
end
end
local function init(std, engine)
return function(printers)
std.log.fatal = printer(engine, printers, 'fatal', 'error')
std.log.error = printer(engine, printers, 'error')
std.log.warn = printer(engine, printers, 'warn')
std.log.info = printer(engine, printers, 'info')
std.log.debug = printer(engine, printers, 'debug', 'info')
std.log.trace = printer(engine, printers, 'trace', 'info')
end    
end
local function install(std, engine, printers)
std.log = std.log or {}
std.log.init = init(std, engine)
std.log.level = level(engine)
std.log.init(printers)
std.log.level('debug')
end
local P = {
install = install
}
return P
end)
b48aa[16] = r48aa(16, function()
local zeebo_pipeline = b48aa[36]('source_shared_functional_pipeline')
local create_counter = b48aa[43]('source_shared_functional_counter')
local nextId, clearId = create_counter()
local function json(self)
print('std.http.get():json() is deprecated.')
self.options['json'] = true
return self
end
local function noforce(self)
self.options['noforce'] = true
return self
end
local function fast(self)
self.speed = '_fast'
return self
end
local function param(self, name, value)
local index = #self.param_list + 1
self.param_list[index] = tostring(name)
self.param_dict[name] = tostring(value)
return self
end
local function header(self, name, value)
local index = #self.header_list + 1
self.header_list[index] = tostring(name)
self.header_dict[name] = tostring(value)
return self
end
local function body(self, content, json_encode)
if type(content) == 'table' then
header(self, 'Content-Type', 'application/json')
content = json_encode(content)
end
self.body_content=content
return self
end
local function success(self, handler_func)
self.success_handler = handler_func
return self
end
local function failed(self, handler_func)
self.failed_handler = handler_func
return self
end
local function http_error(self, handler_func)
self.error_handler = handler_func
return self
end
local function off(self, name, func)
local count = 1
local list = self.handlers[name] or {}
for i = 1, #list do
if list[i] ~= func then
list[count] = list[i]
count = count + 1
end     
end
for i = count, #list do
list[i] = nil
end
self.handlers[name] = list
return self
end
local function on(self, name, func)
off(self, name, func)
local list = self.handlers[name]
list[#list + 1] = func
return self
end
local function websocket_create(request, engine, protocol)
return {
id = request.id,
on = function(self, name, func)
on(request, name, func)
end,
off = function(self, name, func)
off(request, name, func)
end,
send = function(self, data)
if not engine.http[self.id] then return false end
return protocol.sock(self.id, 1, data) 
end,
close = function(self)
protocol.sock(self.id, 2)
engine.http[self.id] = nil
end,
is_connected = function(self)
if not engine.http[self.id] then return false end
return protocol.sock(self.id, 3)
end
}
end
local function websocket_request(std, engine, protocol)
return function(url, upgrade)
local self = {
url = url,
method = 'SOCK',
upgrade = upgrade,
header_list = {},
header_dict = {},
param_list = {},
param_dict = {},
handlers = {},
on = on,
off = off,
param = param,
header = header,
run = zeebo_pipeline.run,
}
self.promise = function()
zeebo_pipeline.stop(self)
end
self.resolve = function()
zeebo_pipeline.resume(self)
end
self.set = function (key, value)
std.http[key] = value
end
self:on('disconnect', function()
if self.id then engine.http[self.id] = nil end
end)
self.pipeline = {
function()
self.id = nextId()
engine.http[self.id] = self
end,
function()
protocol.handler(self, self.id)
end,
function()
if std.http.ok then
local sock = websocket_create(self, engine, protocol)
for _, h in ipairs(self.handlers.open or {}) do h(sock) end
else
if not std.http.error then self.set('error', 'core not upgrade to ws') end
for _, h in ipairs(self.handlers.error or {}) do h(std.http.error) end
engine.http[self.id] = nil
clearId(self.id)
self.id = nil
end
end,
function()
std.http.ok = nil
std.http.error = nil
zeebo_pipeline.reset(self)
end
}
return self
end
end
local function request(method, std, engine, protocol)
return function (url)
local json_encode = std.json and std.json.encode
local json_decode = std.json and std.json.decode
local http_body = function(self, content) return body(self, content, json_encode) end
local game = engine.current.data
local self = {
url = url,
speed = '',
options = {},
method = method,
body_content = '',
header_list = {},
header_dict = {},
param_list = {},
param_dict = {},
success_handler = function (std, game) end,
failed_handler = function (std, game) end,
error_handler = function (std, game) end,
fast = fast,
json = json,
noforce = noforce,
body = http_body,
param = param,
header = header,
success = success,
failed = failed,
error = http_error,
run = zeebo_pipeline.run,
}
self.promise = function()
zeebo_pipeline.stop(self)
end
self.resolve = function()
zeebo_pipeline.resume(self)
end
self.set = function (key, value)
std.http[key] = value
end
self.pipeline = {
function()
self.id = nextId()
engine.http[self.id] = self
if protocol.force and not self.options['noforce'] then
self.url = url:gsub("^[^:]+://", protocol.force.."://")
end
end,
function()
protocol.handler(self, self.id)
end,
function()
if self.options['json'] and json_decode and std.http.body then
local ok, err = pcall(function()
local new_body = json_decode(std.http.body)
std.http.body = new_body
end)
if not ok then
self.set('ok', false)
self.set('error', err)
end
end
local lower_header = {}
for k, v in pairs(std.http.headers or {}) do
lower_header[string.lower(k)] = v
end
std.http.headers = lower_header
end,
function()
if std.http.ok then
self.success_handler(std, game)
elseif std.http.error then
self.error_handler(std, game)
elseif not std.http.status then
self.set('error', 'missing protocol response')
self.error_handler(std, game)
else
self.failed_handler(std, game)
end
end,
function ()
std.http.ok = nil
std.http.body = nil
std.http.error = nil
std.http.status = nil
std.http.body_is_table = nil
end,
function()
engine.http[self.id] = nil
zeebo_pipeline.reset(self)
clearId(self.id)
self.id = nil
end
}
return self
end
end
local function install(std, engine, protocol)
assert(protocol and protocol.handler, 'missing protocol handler')
engine.http = {}
std.http = std.http or {}
std.http.get=request('GET', std, engine, protocol)
std.http.head=request('HEAD', std, engine, protocol)
std.http.post=request('POST', std, engine, protocol)
std.http.put=request('PUT', std, engine, protocol)
std.http.delete=request('DELETE', std, engine, protocol)
std.http.patch=request('PATCH', std, engine, protocol)
if protocol.sock then
std.http.connect = websocket_request(std, engine, protocol)
end
if protocol.install then
protocol.install(std, engine)
end
end
local P = {
install=install
}
return P
end)
b48aa[17] = r48aa(17, function()
local function media_create(node, channels, handler)
local decorator = function(func)
func = func or function() end
return function(self, a, b, c, d, e, f)
func(0, a, b, c, d, e, f)
return self
end
end
local self = { 
src = decorator(handler.source),
play = decorator(handler.play),
prepare = decorator(handler.prepare),
pause = decorator(handler.pause),
resume = decorator(handler.resume),
stop = decorator(handler.stop),
position = decorator(handler.position),
in_mutex = handler.mutex or function() return false end,
get_error = handler.error or function() return nil end,
node = node,
apply = function() end
}
return function()
return self
end
end
local function install(std, engine, handler, name)
std.media = std.media or {}
local mediatype = name:match('%w+%.(%w+)')
if handler.install then
handler.install(std, engine, mediatype, name)
end
if not std.media[mediatype] then
local channels = handler.bootstrap and handler.bootstrap(mediatype)
if (not channels or channels == 0) and handler.bootstrap then
error('media '..mediatype..' is not supported!')
end
local node = std.node and std.node.load({})
std.media[mediatype] = media_create(node, channels, handler)
end
end
local P = {
install=install
}
return P
end)
b48aa[18] = r48aa(18, function()
local zeebo_pipeline = b48aa[36]('source_shared_functional_pipeline')
local function storage_as(engine, self, name, cast)
if cast == nil then
cast = function(v) return v end
elseif type(cast) ~= 'function' then
local value = cast
cast = function() return value end
end
local node = engine.current
self.callbacks[#self.callbacks + 1] = function(value)
node.data[name] = cast(value)
end
return self
end
local function storage_callback(self, handler)
self.callbacks[#self.callbacks + 1] = handler
return self
end
local function storage_default(self, value)
self.default_value = tostring(value)
return self
end
local function storage_command(cmd, std, engine, handlers)
return function(name, value)
if type(value) == 'table' and std.json then
value = std.json.encode(value)
end
value = tostring(value or '')
local self = {
value = '',
default_value = '',
default = storage_default,
callback = storage_callback,
as = function(a, b, c) return storage_as(engine, a, b, c) end,
run = zeebo_pipeline.run,
callbacks = {}
}
self.promise = function() zeebo_pipeline.stop(self) end
self.resolve = function() zeebo_pipeline.resume(self) end
self.pipeline = {
function()
if cmd == 'set' then
handlers.set(name, value or '',  self.promise, self.resolve)
elseif cmd == 'get' then
local save = function(value) self.value = value end
handlers.get(name, save, self.promise, self.resolve)
end
end,
function()
if type(self.value) ~= 'string' or #self.value == 0 then
self.value = #self.default_value > 0 and self.default_value or nil
end
end,
function()
local index = 1
while index <= #self.callbacks do
self.callbacks[index](self.value)
index = index + 1
end
end
}
return self
end
end
local function storage_mutex(mutex_func)
return function()
if mutex_func then return mutex_func() end
return false
end
end
local function install(std, engine, handlers)
if handlers.install then
handlers.install(std, engine)
end
if not handlers.set or not handlers.get then
error('missing handlers')
end
std.storage = std.storage or {}
std.storage.in_mutex = storage_mutex(handlers.mutex)
std.storage.set = storage_command('set', std, engine, handlers)
std.storage.get = storage_command('get', std, engine, handlers)
end
local P = {
install=install
}
return P
end)
b48aa[19] = r48aa(19, function()
local ev_prefixes = {
'pre_',
'',
'post_'
}
local buses = {
list = {},
dict = {},
queue = {},
all = {}
}
local must_abort = false
local function abort()
must_abort = true
end
local function emit_next(key, a, b, c, d, e, f)
buses.queue[#buses.queue + 1] = {key, a, b, c, d, e, f}
end
local function emit(engine, prefixes, key, a, b, c, d, e, f)
local index1, index2, index3 = 1, 1, 1
while index1 <= #prefixes do
index2 = 1
local prefix = prefixes[index1]
local topic = prefix..key
local bus = buses.dict[topic]
while not must_abort and bus and index2 <= #bus do
xpcall(function() bus[index2](a, b, c, d, e, f) end, engine.handler)
index2 = index2 + 1
end
index3 = 1
while index3 <= #buses.all do
xpcall(function() buses.all[index3](topic, a, b, c, d, e, f) end, engine.handler)
index3 = index3 + 1
end
index1 = index1 + 1
end
must_abort = false
end
local function trigger(engine)
return function (key)
return function (a, b, c, d, e, f)
emit(engine, ev_prefixes, key, a, b, c, d, e, f)
end
end
end
local function listen(key, handler_func)
if not key or not handler_func then return end
if not buses.dict[key] then
buses.list[#buses.list + 1] = key
buses.dict[key] = {}
end
local index = #buses.dict[key] + 1
buses.dict[key][index] = handler_func 
end
local function listen_all(handler_func)
buses.all[#buses.all + 1] = handler_func
end
local function install(std, engine)
std.bus = std.bus or {}
std.bus.abort = abort
std.bus.listen = listen
std.bus.trigger = trigger(engine)
std.bus.emit_next = emit_next
std.bus.listen_all = listen_all
engine.bus_emit_ret = function(key, a)
emit(engine, {'ret_'}, key, a)
end
std.bus.emit = function(key, a, b, c, d, e, f)
emit(engine, ev_prefixes, key, a, b, c, d, e, f)
end
std.bus.listen_std = function(key, handler_func)
listen(key, function(a, b, c, d, e, f)
handler_func(std, a, b, c, d, e, f)
end)
end
std.bus.listen_std_data = function(key, handler_func)
listen(key, function(a, b, c, d, e, f)
handler_func(std, engine.current.data, a, b, c, d, e, f)
end)
end
std.bus.listen_std_engine = function(key, handler_func)
listen(key, function(a, b, c, d, e, f)
handler_func(std, engine, a, b, c, d, e, f)
end)
end
listen('pre_loop', function()
local index = 1
while index <= #buses.queue do
local pid = buses.queue[index]
emit(engine, {''}, pid[1], pid[2], pid[3], pid[4], pid[5], pid[6])
index = index + 1
end
buses.queue = {}
end)
return {
bus=std.bus
}
end
local P = {
install=install
}
return P
end)
b48aa[20] = r48aa(20, function()
local memory_dict_unload = {}
local memory_dict = {}
local memory_list = {}
local function cache_get(key)
return memory_dict[key]
end
local function cache_set(key, load_func, unload_func)
local value = load_func()
memory_list[#memory_list + 1] = key
memory_dict_unload[key] = unload_func
memory_dict[key] = value
end
local function cache(key, load_func, unload_func)
local value = cache_get(key)
if value == nil then
cache_set(key, load_func, unload_func)
value = cache_get(key)
end    
return value
end
local function unset(key)
if memory_dict_unload[key] then
memory_dict_unload[key](memory_dict[key])
end
memory_dict[key] = nil
end
local function gc_clear_all()
local index = 1
local items = #memory_list
while index <= items do
unset(memory_list[index])
index = index + 1
end
memory_list = {}
return items
end
local function install(std)
std = std or {}
std.mem = std.mem or {}
std.mem.cache = cache
std.mem.cache_get = cache_get
std.mem.cache_set = cache_set
std.mem.unset = unset
std.mem.gc_clear_all = gc_clear_all
return {
mem=std.mem
}
end
local P = {
install=install
}
return P
end)
b48aa[21] = r48aa(21, function()
local dom = b48aa[3]('source_engine_browser_dom')
local pause = b48aa[33]('source_engine_browser_pause')
local loadgame = b48aa[5]('source_shared_engine_loadgame')
local LIFECYCLE = { init=true, exit=true, focus=true, unfocus=true, hover=true, unhover=true }
local node_default = b48aa[44]('source_shared_var_object_node')
local function emit(std, application, key, a, b, c, d, e, f)
end
local function load(application)
return loadgame.script(application, node_default)
end
local function spawn(engine)
return function(application, parent)
dom.node_add(engine.dom, application, {parent=parent or engine.current})
return application
end
end
local function kill(engine)
return function(application)
dom.node_del(engine.dom, application)
end
end
local function node_pause(engine)
return function(application, key)
pause.node_pause(engine.dom, application, key)
end
end
local function node_resume(engine)
return function(application, key)
pause.node_resume(engine.dom, application, key)
end
end
local function install(std, engine)
std.node = std.node or {}
std.node.kill   = kill(engine)
std.node.pause  = node_pause(engine)
std.node.spawn  = spawn(engine)
std.node.resume = node_resume(engine)
std.node.load   = load
std.node.emit = function(application, key, a, b, c, d, e, f)
return emit(std, application, key, a, b, c, e, f)
end
std.bus.listen_all(function(key, a, b, c, d, e, f)
dom.bus(engine.dom, key, function(node)
engine.current = node
engine.offset_x = node.config.offset_x
engine.offset_y = node.config.offset_y
if node.callbacks[key] and (node.config.uid == 0 or not LIFECYCLE[key]) then
xpcall(function() node.callbacks[key](node.data, std, a, b, c, d, e, f) end, engine.handler)
end
end)
end)
end
local P = {
install = install
}
return P
end)
b48aa[22] = r48aa(22, function()
local function setenv(engine)
return function(varname, value)
if engine.root ~= engine.current then
error('unauthorized set environment', 0)
end
if varname then
engine.overrides_envs[varname] = tostring(value)
end
end
end
local function getenv(engine, get_env)
return function(varname) 
local game_envs = engine.root and engine.root.envs
local core_envs = engine.envs
if not (varname or #varname > 0) then
return nil
end
if engine.overrides_envs[varname] then
return engine.overrides_envs[varname]
end
if game_envs and game_envs[varname] then
return game_envs[varname]
end
if core_envs and core_envs[varname] then
return core_envs[varname]
end    
if get_env then
return get_env(varname)
end
return nil
end
end
local function install(std, engine, cfg)
engine.overrides_envs = {}
std.getenv = getenv(engine, cfg.get_env)
std.setenv = setenv(engine)
end
local P = {
install = install
}
return P
end)
b48aa[23] = r48aa(23, function()
local function install(std)
std.color = std.color or {}
std.color.white = 0xFFFFFFFF
std.color.lightgray = 0xC8CCCCFF
std.color.gray = 0x828282FF
std.color.darkgray = 0x505050FF
std.color.yellow = 0xFDF900FF
std.color.gold = 0xFFCB00FF
std.color.orange = 0xFFA100FF
std.color.pink = 0xFF6DC2FF
std.color.red = 0xE62937FF
std.color.maroon = 0xBE2137FF
std.color.green = 0x00E430FF
std.color.lime = 0x009E2FFF
std.color.darkgreen = 0x00752CFF
std.color.skyblue = 0x66BFFFFF
std.color.blue = 0x0079F1FF
std.color.darkblue = 0x0052ACFF
std.color.purple = 0xC87AFFFF
std.color.violet = 0x873CBEFF
std.color.darkpurple = 0x701F7EFF
std.color.beige = 0xD3B083FF
std.color.brown = 0x7F6A4FFF
std.color.darkbrown = 0x4C3F2FFF
std.color.black = 0x000000FF
std.color.blank = 0x00000000
std.color.magenta = 0xFF00FFFF
end
local P = {
install = install
}
return P
end)
b48aa[24] = r48aa(24, function()
local function reset(std, engine)
if std.node then
return function()
std.bus.emit('exit')
std.bus.emit('init')
end
end
return function()
engine.root.callbacks.exit(engine.root.data, std)
engine.root.callbacks.init(engine.root.data, std)
end
end
local function exit(std)
return function()
std.bus.emit('exit')
std.bus.emit('quit')
end
end
local function title(func)
return function(window_name)
if func then
func(window_name)
end
end
end
local function get_info(my, info)
return function()
return my.root.meta[info]
end
end
local function install(std, engine, config)
std = std or {}
config = config or {}
std.app = std.app or {}
std.bus.listen('post_quit', config.quit or config.exit or function() end)
std.app.title = title(config.set_title)
std.app.exit = exit(std)
std.app.reset = reset(std, engine)
std.app.get_name = get_info(engine, 'title')
std.app.get_version = get_info(engine, 'version')
std.app.get_fps = config.get_fps
return std.app
end
local P = {
install=install
}
return P
end)
b48aa[25] = r48aa(25, function()
local function real_key(std, engine, rkey, rvalue)
local value = (rvalue == 1 or rvalue == true) or false
local key = engine.key_bindings[rkey] or rkey
if std.key.press[key] ~= nil or not engine.keyboard_lock then
std.key.press[key] = value
if key == 'right' or key == 'left' then
std.key.axis.x = (std.key.press['right'] and 1 or 0) - (std.key.press['left'] and 1 or 0) 
end
if key == 'down' or key == 'up' then
std.key.axis.y = (std.key.press['down'] and 1 or 0) - (std.key.press['up'] and 1 or 0)
end
std.key.any = false
for _, value in pairs(std.key.press) do
if value then std.key.any = true end
end
if std.bus and std.bus.emit and engine.keyboard_lock then
std.bus.emit('key', key, value)
end
end
end
local function real_keydown(std, engine, key)
real_key(std, engine, key, 1)
end
local function real_keyup(std, engine, key)
real_key(std, engine, key, 0)
end
local function install(std, engine, config)
config = config or {}
engine.key_bindings = config.bindings or {}
engine.keyboard = real_key
for _, key in pairs(engine.key_bindings) do
real_key(std, engine, key, false)
end
if std.bus.listen_std_engine then
std.bus.listen('load', function() engine.keyboard_lock = true end)
std.bus.listen_std_engine('rkey', real_key)
std.bus.listen_std_engine('rkey1', real_keydown)
std.bus.listen_std_engine('rkey0', real_keyup)
end
end
return {
install = install
}
end)
b48aa[26] = r48aa(26, function()
local function abs(value)
if value < 0 then
return -value
end
return value
end
local function clamp(value, value_min, value_max)
if value < value_min then
return value_min
elseif value > value_max then
return value_max
else
return value
end
end
local function clamp2(value, value_min, value_max)
return (value - value_min) % (value_max - value_min + 1) + value_min
end
local function dir(value, alpha)
alpha = alpha or 0
if value < -alpha then
return -1
elseif value > alpha then
return 1
else
return 0
end
end
local function dis(x1,y1,x2,y2)
local sqr = 1/2
return ((x2 - x1) ^ 2 + (y2 - y1) ^ 2) ^ (sqr ~= 0 and sqr or 1)
end
local function dis2(x1,y1,x2,y2)
return (x2 - x1) ^ 2 + (y2 - y1) ^ 2
end
local function dis3(x1,y1,x2,y2)
return abs(x1 - x2) + abs(x2 - y2)
end
local function lerp(a, b, alpha)
return a + alpha * ( b - a )
end 
local function map(value, in_min, in_max, out_min, out_max)
return (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end
local function max(...)
local args = {...}
local index = 1
local value = nil
local max_value = nil
if #args == 1 then
args = args[1]
end
while index <= #args do
value = args[index]
if max_value == nil or value > max_value then
max_value = value
end
index = index + 1
end
return max_value
end
local function min(...)
local args = {...}
local index = 1
local value = nil
local min_value = nil
if #args == 1 then
args = args[1]
end
while index <= #args do
value = args[index]
if min_value == nil or value < min_value then
min_value = value
end
index = index + 1
end
return min_value
end
local function install(std)
std.math = std.math or {}
std.math.abs=abs
std.math.clamp=clamp
std.math.clamp2=clamp2
std.math.dir=dir
std.math.dis=dis
std.math.dis2=dis2
std.math.dis3=dis3
std.math.lerp=lerp
std.math.map=map
std.math.max=max
std.math.min=min
end
local P = {
install = install
}
return P
end)
b48aa[27] = r48aa(27, function()
local function install(std)
assert(math and (1/2 ~= 0))
std.math = std.math or {}
std.math.acos=math.acos
std.math.asin=math.asin
std.math.atan=math.atan
std.math.atan2=math.atan2
std.math.ceil=math.ceil
std.math.cos=math.cos
std.math.cosh=math.cosh
std.math.deg=math.deg
std.math.exp=math.exp
std.math.floor=math.floor
std.math.fmod=math.fmod
std.math.frexp=math.frexp
std.math.huge=math.huge
std.math.ldexp=math.ldexp
std.math.log=math.log
std.math.log10=math.log10
std.math.modf=math.modf
std.math.pi=math.pi
std.math.pow=math.pow
std.math.rad=math.rad
std.math.sin=math.sin
std.math.sinh=math.sinh
std.math.sqrt=math.sqrt
std.math.tan=math.tan
std.math.tanh=math.tanh
end
local P = {
install = install
}
return P
end)
b48aa[28] = r48aa(28, function()
local function install(std)
assert(math and (1/2 ~= 0))
std.math = std.math or {}
std.math.random = function(a, b)
a = a and math.floor(a)
b = b and math.floor(b)
if a > b then a, b = b, a end
return math.random(a, b)
end
end
local P = {
install = install
}
return P
end)
b48aa[29] = r48aa(29, function()
local str_http = b48aa[46]('source_shared_string_encode_http')
local str_url = b48aa[47]('source_shared_string_encode_url')
local callbacks = {
['async-promise'] = function(self)
return self:promise()
end,
['async-resolve'] = function(self)
return self:resolve()
end,
['get-url'] = function(self)
return self.url
end,
['get-fullurl'] = function(self)
return self.url..str_url.search_param(self.param_list, self.param_dict)
end,
['get-method'] = function(self)
return self.method
end,
['get-body'] = function(self)
return self.body_content
end,
['get-param-count'] = function(self)
return #self.param_list
end,
['get-param-name'] = function(self, data)
return self.param_list[self.data]
end,
['get-param-data'] = function(self, data)
return self.param_dict[self.data] or self.param_dict[self.param_list[self.data]]
end,
['get-header-count'] = function(self)
return #self.header_list
end,
['get-header-name'] = function(self, data)
return self.header_list[self.data]
end,
['get-header-data'] = function(self, data)
return self.heeader_dict[self.data] or self.heeader_dict[self.header_list[self.data]]
end,
['get-sock-upgrade'] = function(self)
return self.upgrade
end,
['set-status'] = function(self, data)
self.set('status', data)
self.set('ok', str_http.is_ok(data))
end,
['set-error'] = function(self, data)
self.set('error', data)
end,
['set-ok'] = function(self, data)
self.set('ok', data)
end,
['set-body'] = function(self, data)
self.set('body', data)
end,
['set-headers'] = function(self, data)
self.set('headers', data or {})
end,
['add-body-data'] = function(self, data, std)
self.set('body', (std.http.body or '')..data)
end,
['sock-event'] = function(self, data)
for _, h in ipairs(self.handlers[data] or {}) do h() end
end,
['sock-message']  = function(self, data)
for _, h in ipairs(self.handlers.message or {}) do h(data) end
end
}
local function native_http_callback(self, evt, data, std)
if not callbacks[evt] then
error('http evt '..evt..' not exist!')
end
return callbacks[evt](self, data, std)
end
local P = {
func = native_http_callback
}
return P
end)
b48aa[30] = r48aa(30, function()
local P = {
data={
width=1280,
height=720
},
meta={
id='',
title='',
author='',
company='',
description='',
tizen_package='',
version=''
},
config = {
offset_x = 0,
offset_y = 0,
require = '',
fps_max = 60,
fps_show = 0,
fps_drop = 5,
fps_time = 5
},
callbacks={
}
}
return P;
end)
b48aa[31] = r48aa(31, function()
local P = {
milis = 0,
delta = 0,
math = {
},
media = {
},
draw = {
image = function() end,
clear = function () end,
color = function () end,
rect = function () end,
line = function () end,
poly = function () end,
tui_text = function() end
},
text = {
put = function() end,
print = function() end,
mensure = function() end,
font_size = function() end,
font_name = function() end,
font_default = function() end
},
image = {
load = function() end,
draw = function() end
},
app = {
width = 1280,
height = 720,
title = function() end,
reset = function () end,
load = function() end,
exit = function () end
},
key = {
any = false,
axis = {
x = 0,
y = 0,
},
press = {
menu=false,
up=false,
down=false,
left=false,
right=false,
a=false,
b=false,
c=false,
d=false
}
}
}
return P;
end)
b48aa[32] = r48aa(32, function()
local _mark_dirty
local function init(mark_dirty_fn)
_mark_dirty = mark_dirty_fn
end
local function parse_unit(value, screen_w, screen_h)
if type(value) == 'number' then
return { value = value, unit = 'px' }
end
local num, unit = value:match('^([%d%.%-]+)(%%?p?x?v?w?h?)$')
num = tonumber(num)
if unit == '%' then
return { value = num / 100, unit = 'pct' }
elseif unit == 'vw' then
return { value = (num / 100) * (screen_w or 1280), unit = 'px' }
elseif unit == 'vh' then
return { value = (num / 100) * (screen_h or 720), unit = 'px' }
end
return { value = num or 0, unit = 'px' }
end
local function resolve(parsed, parent_size)
if parsed.unit == 'pct' then
return parsed.value * parent_size
end
return parsed.value
end
local function stylesheet(self, name, options)
local css = self.stylesheet_dict[name] or {}
local exe = self.stylesheet_func[name]
if options then
local keys = {}
for k in pairs(options) do
if k ~= 'class' and k ~= 'children' then
keys[#keys + 1] = k
end
end
table.sort(keys)
local parts = {}
for _, k in ipairs(keys) do
parts[#parts + 1] = k .. '=' .. tostring(options[k])
end
local closure_key = table.concat(parts)
if self.stylesheet_key and self.stylesheet_key[name] == closure_key and exe then
return exe
end
css.left      = options.left   or options.margin or nil
css.right     = options.right  or options.margin or nil
css.top       = options.top    or options.margin or nil
css.bottom    = options.bottom or options.margin or nil
css.height    = options.height or nil
css.width     = options.width  or nil
css.span      = options.span or nil
css.z         = options['z-index'] or options.z or nil
css.invisible = options.invisible
if not self.stylesheet_key then self.stylesheet_key = {} end
self.stylesheet_key[name] = closure_key
exe = nil
end
if not exe then
local sw = self.width  or 1280
local sh = self.height or 720
local p_left   = css.left   and parse_unit(css.left,   sw, sh) or nil
local p_right  = css.right  and parse_unit(css.right,  sw, sh) or nil
local p_top    = css.top    and parse_unit(css.top,    sw, sh) or nil
local p_bottom = css.bottom and parse_unit(css.bottom, sw, sh) or nil
local p_width  = css.width  and parse_unit(css.width,  sw, sh) or nil
local p_height = css.height and parse_unit(css.height, sw, sh) or nil
exe = function(x, y, width, height)
local has_left   = p_left   ~= nil
local has_right  = p_right  ~= nil
local has_top    = p_top    ~= nil
local has_bottom = p_bottom ~= nil
local css_left   = has_left   and resolve(p_left,   width)  or 0
local css_right  = has_right  and resolve(p_right,  width)  or 0
local css_top    = has_top    and resolve(p_top,    height) or 0
local css_bottom = has_bottom and resolve(p_bottom, height) or 0
if p_width then
local css_width = resolve(p_width, width)
if (has_left and has_right) or (not has_left and not has_right) then
local free = width - css_left - css_right - css_width
x = x + css_left + free * (1/2)
width = css_width
elseif not has_left and has_right then
x = x + width - css_right - css_width
width = css_width
else
x = x + css_left
width = css_width
end
else
if has_left then
x = x + css_left
width = width - css_left
end
if has_right then
width = width - css_right
end
end
if p_height then
local css_height = resolve(p_height, height)
if (has_top and has_bottom) or (not has_top and not has_bottom) then
local free = height - css_top - css_bottom - css_height
y = y + css_top + free * (1/2)
height = css_height
elseif not has_top and has_bottom then
y = y + height - css_bottom - css_height
height = css_height
else
y = y + css_top
height = css_height
end
else
if has_top then
y = y + css_top
height = height - css_top
end
if has_bottom then
height = height - css_bottom
end
end
return x, y, width, height
end
end
self.stylesheet_dict[name] = css
self.stylesheet_func[name] = exe
self.stylesheet_meta = self.stylesheet_meta or {}
self.stylesheet_meta[exe] = { span = css.span, z = css.z, invisible = css.invisible }
return exe
end
local function resolve_style_props(self, node)
local cfg  = node.config
local meta = self.stylesheet_meta
local span, z, invisible
if meta then
local styles = cfg.css
for i = 1, #styles do
local m = meta[styles[i]]
if m then
if m.span      ~= nil then span      = m.span      end
if m.z         ~= nil then z         = m.z         end
if m.invisible ~= nil then invisible = m.invisible end
end
end
end
local invisible_changed = invisible ~= cfg._style_invisible
cfg._style_invisible = invisible
local span_changed = span ~= cfg._style_span or invisible_changed
cfg._style_span = span
if z ~= cfg._style_z then
cfg._style_z = z
self.flag_resort = true
end
return span_changed
end
local function css_add(self, func, node, name)
local cfg    = node.config
local styles = cfg.css
local found  = false
for i = 1, #styles do
if styles[i] == func then found = true; break end
end
if not found then
styles[#styles + 1] = func
end
if name then
local names = cfg.style_names or {}
cfg.style_names = names
local present = false
for i = 1, #names do
if names[i] == name then present = true; break end
end
if not present then names[#names + 1] = name end
end
resolve_style_props(self, node)
if _mark_dirty then
_mark_dirty(self, node.config.parent or node)
end
end
local function css_del(self, func, node, name)
local cfg    = node.config
local styles = cfg.css
local src, dst = 1, 1
while src <= #styles do
local item = styles[src]
if item ~= func then
styles[dst] = item
dst = dst + 1
end
src = src + 1
end
while dst <= #styles do
styles[dst] = nil
dst = dst + 1
end
if name and cfg.style_names then
local names = cfg.style_names
local s, d = 1, 1
while s <= #names do
if names[s] ~= name then names[d] = names[s]; d = d + 1 end
s = s + 1
end
while d <= #names do names[d] = nil; d = d + 1 end
end
resolve_style_props(self, node)
if _mark_dirty then
_mark_dirty(self, node.config.parent or node)
end
end
local function css_scroll(scroll_state)
return function(x, y, w, h)
return x - (scroll_state.offset_x or 0), y - (scroll_state.offset_y or 0), w, h
end
end
local P = {
init       = init,
parse_unit = parse_unit,
resolve    = resolve,
stylesheet = stylesheet,
css_add    = css_add,
css_del    = css_del,
css_scroll = css_scroll,
}
return P
end)
b48aa[33] = r48aa(33, function()
local function walk(node, fn)
fn(node)
if node.childs then
for _, child in ipairs(node.childs) do
walk(child, fn)
end
end
end
local function node_pause(self, node_root, key)
walk(node_root, function(node)
local uid = node.config.uid
if not uid then return end
local entry = self.pause_registry[uid]
if not entry then
entry = { all = false, keys = nil }
self.pause_registry[uid] = entry
end
if key then
entry.keys = entry.keys or {}
entry.keys[key] = true
else
entry.all  = true
entry.keys = nil
end
end)
end
local function node_resume(self, node_root, key)
local parent_uid = node_root.config.parent
and node_root.config.parent.config.uid
local parent_entry = parent_uid and self.pause_registry[parent_uid]
local parent_all = parent_entry and parent_entry.all
if parent_all and not key then return end
walk(node_root, function(node)
local uid   = node.config.uid
if not uid then return end
local entry = self.pause_registry[uid]
if not entry then return end
if key then
entry.keys = entry.keys or {}
entry.keys[key] = false
else
self.pause_registry[uid] = nil
end
end)
end
local function is_paused(self, uid, key)
local entry = self.pause_registry[uid]
if not entry then return false end
if entry.keys and entry.keys[key] == false then return false end
if entry.keys and entry.keys[key] == true  then return true  end
return entry.all
end
local P = {
node_pause  = node_pause,
node_resume = node_resume,
is_paused   = is_paused,
}
return P
end)
b48aa[34] = r48aa(34, function()
local function cells(node)
local cfg = node.config
local dat = node.data
if cfg.type == 'grid' then
return dat.width / cfg.cols, dat.height / cfg.rows
end
return dat.width, dat.height
end
local function parse_span(span)
if type(span) == 'number' then
return span, 1
end
if type(span) == 'string' then
local c, r = span:match('^(%d+)x(%d+)$')
if c then return tonumber(c), tonumber(r) end
local n = tonumber(span)
if n then return n, 1 end
end
return 1, 1
end
local function effective_span(cc)
if cc._style_invisible then return 0 end
local s = cc._style_span
if s == nil then return cc.size end
return s
end
local function slide_step(scroll)
if scroll.mode == 'page' then
return scroll.cols * scroll.rows
elseif scroll.mode == 'peek' then
return 1
elseif scroll.dir == 'row' then
return scroll.cols
else
return scroll.rows
end
end
local function peek_axis(childs, dir_val)
local place  = {}
local cursor = 0
for i, child in ipairs(childs) do
local cc   = child.config
local size = effective_span(cc)
if size == 0 then
place[i] = cursor
else
local span_x, span_y = parse_span(size or 1)
if dir_val == 'row' and type(size) == 'number' then
span_x, span_y = 1, span_x
end
local axis_span = (dir_val == 'col') and span_x or span_y
cursor   = cursor + (cc.offset or 0)
place[i] = cursor
cursor   = cursor + axis_span + (cc.after or 0)
end
end
return place, cursor
end
local _clip = 0
local _hide = 0
local function dom_layout(self, node, parent_x, parent_y, parent_w, parent_h)
local cfg = node.config
local dat = node.data
cfg._scroll_clipped = _clip > 0 or nil
cfg._span_hidden    = _hide > 0 or nil
cfg.offset_x = parent_x
cfg.offset_y = parent_y
dat.width    = parent_w
dat.height   = parent_h
if cfg.type == 'grid' then
local cols    = cfg.cols
local rows    = cfg.rows
local dir_val = cfg.dir
local cell_w, cell_h = cells(node)
local x, y = 0, 0
local scroll      = self.scroll_registry[node]
local peek_total  = 0
local peek_anchor = 1
local peek_loop   = false
local peek_place
local peek_span_total = 0
if scroll then
if scroll.mode == 'page' then
if dir_val == 'col' then
x = -(scroll.index * scroll.cols)
else
y = -(scroll.index * scroll.rows)
end
elseif scroll.mode == 'peek' then
peek_total  = node.childs and #node.childs or 0
peek_anchor = scroll.anchor or 1
if peek_total > 0 then
peek_place, peek_span_total = peek_axis(node.childs, dir_val)
local focus_cell = peek_place[scroll.index + 1] or 0
local axis_max   = (dir_val == 'col') and cols or rows
local lo  = peek_anchor == 0
and -(peek_span_total - 1)
or  -(peek_span_total - axis_max + peek_anchor)
local raw = peek_anchor - focus_cell
local looped = scroll.vindex and scroll.vindex >= peek_span_total
peek_loop = raw <= lo or looped
local pos = peek_loop and peek_anchor or math.max(math.min(raw, peek_anchor), lo)
if dir_val == 'col' then x = pos else y = pos end
end
else
if dir_val == 'col' then
x = -scroll.index
else
y = -scroll.index
end
end
end
if node.childs then
for i, child in ipairs(node.childs) do
local cc   = child.config
local size = effective_span(cc)
if size == 0 then
_hide = _hide + 1
dom_layout(self, child, parent_x, parent_y, 0, 0)
_hide = _hide - 1
else
local offset_val = cc.offset or 0
local after_val  = cc.after  or 0
local span_x, span_y = parse_span(size or 1)
if dir_val == 'row' and type(size) == 'number' then
span_x, span_y = 1, span_x
end
if scroll and scroll.mode == 'peek' and peek_loop then
local focus_cell = peek_place[scroll.index + 1] or 0
local slot = (peek_place[i] - focus_cell + peek_anchor) % peek_span_total
if dir_val == 'col' then
x = slot
y = 0
else
x = 0
y = slot
end
else
if dir_val == 'col' then
y = y + offset_val
if y >= rows then
local wrap = math.floor(y / rows)
y = y % rows
x = x + wrap
end
else
x = x + offset_val
if x >= cols then
local wrap = math.floor(x / cols)
x = x % cols
y = y + wrap
end
end
end
local cx = parent_x + cell_w * x
local cy = parent_y + cell_h * y
local w  = span_x * cell_w
local h  = span_y * cell_h
for _, css_fn in ipairs(cc.css) do
cx, cy, w, h = css_fn(cx, cy, w, h)
end
local outside = scroll
and (cx + w <= parent_x or cx >= parent_x + parent_w
or cy + h <= parent_y or cy >= parent_y + parent_h)
if outside then _clip = _clip + 1 end
dom_layout(self, child, cx, cy, w, h)
if outside then _clip = _clip - 1 end
if dir_val == 'col' then
y = y + span_y + after_val
if y >= rows then
local wrap = math.floor(y / rows)
y = y % rows
x = x + span_x + (wrap - 1)
end
else
x = x + span_x + after_val
if x >= cols then
local wrap = math.floor(x / cols)
x = x % cols
y = y + span_y + (wrap - 1)
end
end
end
end
end
elseif node.childs then
for _, child in ipairs(node.childs) do
if effective_span(child.config) == 0 then
_hide = _hide + 1
dom_layout(self, child, parent_x, parent_y, 0, 0)
_hide = _hide - 1
else
local cx, cy, w, h = parent_x, parent_y, parent_w, parent_h
for _, css_fn in ipairs(child.config.css) do
cx, cy, w, h = css_fn(cx, cy, w, h)
end
dom_layout(self, child, cx, cy, w, h)
end
end
end
end
local P = {
cells      = cells,
parse_span = parse_span,
slide_step = slide_step,
dom_layout = dom_layout,
}
return P
end)
b48aa[35] = r48aa(35, function()
local function call(self, node, key, ...)
if node and node.callbacks and node.callbacks[key] and self.std then
local prev = self.current_node
self.current_node = node
node.callbacks[key](node.data, self.std, ...)
self.current_node = prev
end
end
local function spawn(self, node)
call(self, node, 'init')
end
local function kill(self, node)
call(self, node, 'exit')
end
local function focus(self, node)
call(self, node, 'focus')
end
local function unfocus(self, node)
call(self, node, 'unfocus')
end
local function hover(self, node)
call(self, node, 'hover')
end
local function unhover(self, node)
call(self, node, 'unhover')
end
local P = {
spawn   = spawn,
kill    = kill,
focus   = focus,
unfocus = unfocus,
hover   = hover,
unhover = unhover,
}
return P
end)
b48aa[36] = r48aa(36, function()
local function pipe(self)
return function()
self:run()
end
end
local function stop(self)
if self.pipeline and not self.pipeline2 then
self.pipeline2 = self.pipeline
self.pipeline = nil
end
end
local function resume(self)
if not self.pipeline and self.pipeline2 then
self.pipeline = self.pipeline2
self.pipeline2 = nil
self:run()
end
end
local function run(self)
self.pipeline_current = self.pipeline_current or 1
while self.pipeline and self.pipeline_current and self.pipeline_current <= #self.pipeline do
self.pipeline[self.pipeline_current]()
if self.pipeline_current then
self.pipeline_current = self.pipeline_current + 1
end
end
return self
end
local function reset(self)
self.pipeline = self.pipeline or self.pipeline2
self.pipeline2 = nil
self.pipeline_current = nil
end
local function clear(self)
self.pipeline_current = nil
self.pipeline2 = nil
self.pipeline = nil
end
local P = {
reset=reset,
clear=clear,
pipe=pipe,
stop=stop,
resume=resume,
run=run
}
return P
end)
b48aa[37] = r48aa(37, function()
local function encode(dsl_string)
local spec = {
list = {},
required = {},
all = false
}
for entry in (dsl_string or ''):gmatch("[^%s]+") do
if entry == "*" then
spec.all = true
else
local is_optional = entry:sub(-1) == "?"
local name = is_optional and entry:sub(1, -2) or entry
spec.list[#spec.list + 1] = name
spec.required[#spec.required + 1] = not is_optional
end
end
return spec
end
local function missing(spec, imported)
local result = {}
do
local index = 1
while spec.list[index] do
local name = spec.list[index]
if spec.required[index] and not imported[name] then
result[#result + 1] = name
end
index = index + 1
end
end
return result
end
local function should_import(spec, libname)
local index = 1
while spec.list[index] do
if spec.list[index] == libname then return true end
index = index + 1
end
return spec.all
end
local P = {
encode = encode,
missing = missing,
should_import = should_import
}
return P
end)
b48aa[38] = r48aa(38, function()
local function script(src)
local ok, app = false, nil
if require then
ok, app = pcall(require, src:gsub('%.lua$', ''))
end
if not ok and dofile then
ok, app =  pcall(dofile, src)
end
if not ok and loadfile then
ok, app = pcall(loadfile, src)
end
if type(app) == 'function' then
ok, app = pcall(app)
end
if not ok then
return false, 'failed to eval file'
end
return ok, app
end
local P = {
script = script,
}
return P
end)
b48aa[39] = r48aa(39, function()
local function script(src)
local loader = loadstring or load
if not loader then
error('eval not allowed')
end
local ok, chunk = pcall(loader, src)
if not ok then
return false, chunk
end
if type(chunk) ~= 'function' then
return false, 'failed to eval code'
end
return pcall(chunk)
end
local P = {
script = script,
}
return P
end)
b48aa[40] = r48aa(40, function()
local nav = b48aa[48]('source_engine_browser_navigator')
local query = b48aa[49]('source_engine_browser_query')
local dom_mod = b48aa[3]('source_engine_browser_dom')
local ui_grid = b48aa[50]('source_engine_browser_grid')
local ui_style = b48aa[51]('source_engine_api_draw_ui_style')
local util_decorator = b48aa[2]('source_shared_functional_decorator')
local function resolve_node(dom_obj, target)
if target == nil then
return dom_obj.current_node
elseif type(target) == 'string' and target:sub(1, 1) == '#' then
return dom_obj.index_id[target:sub(2)]
elseif type(target) == 'table' then
return target.config and target or target.node
end
end
local function install(std, engine)
std.ui = std.ui or {}
engine.dom.std = std
std.ui.grid  = util_decorator.prefix2(std, engine, ui_grid.component)
std.ui.style = util_decorator.prefix1(engine, ui_style.component)
std.ui.focus = function(target)
local dom_obj = engine.dom
if not target then
target = dom_obj.current_node
elseif type(target) == 'string' then
local dir, sel = target:match('^(%a+)%s+(.+)$')
dir = dir or target
if dir == 'right' or dir == 'left'
or dir == 'up'   or dir == 'down' then
if not dom_obj.focus_current then
local seed = nav.find_first(dom_obj)
if not seed then return nil end
local placed = nav.set_focus(dom_obj, seed)
if not placed then return nil end
end
if sel then
local filter = query.make_filter(sel)
local moved  = filter and nav.focus_navigate(dom_obj, dir, filter)
return moved and query.wrap(dom_obj, moved) or nil
end
local moved = nav.focus_navigate(dom_obj, dir)
if moved then return query.wrap(dom_obj, moved) end
return dom_obj.focus_current and query.wrap(dom_obj, dom_obj.focus_current) or nil
end
if target == 'first' then
local found = nav.find_first(dom_obj)
if not found then return nil end
if dom_obj.focus_current == found then return query.wrap(dom_obj, found) end
local placed = nav.set_focus(dom_obj, found)
if not placed then return nil end
return query.wrap(dom_obj, placed)
end
if target:sub(1, 1) == '#' then
target = dom_obj.index_id[target:sub(2)]
elseif target:sub(1, 1) == '.' then
target = query.nodes_by_style(dom_obj, target:sub(2))[1]
end
end
if not target then return nil end
if type(target) == 'table' and not target.config.focusable then
local found = nav.find_focusable(target)
if not found and target.config.parent then
found = nav.find_focusable(target.config.parent)
end
target = found
end
if not target then return nil end
if dom_obj.focus_current == target then return query.wrap(dom_obj, target) end
local placed = nav.set_focus(dom_obj, target)
if not placed then return nil end
return query.wrap(dom_obj, placed)
end
std.ui.press = function()
nav.press(engine.dom)
end
std.ui.isFocused = function(target)
local dom_obj = engine.dom
if not target then
target = dom_obj.current_node
end
return nav.is_focused(dom_obj, target)
end
std.ui.span = function(span_value, target)
local node = resolve_node(engine.dom, target)
if not node then return end
node.config.size = span_value
local parent = node.config.parent
if parent then
dom_mod.mark_dirty(engine.dom, parent)
end
end
std.ui.class = function(layout, target)
local node = resolve_node(engine.dom, target)
if not node then return end
if node.config.type ~= 'grid' then
local p = node.config.parent
if p and p.config.type == 'grid' then
node = p
else
return
end
end
local cols, rows = layout:match('(%d+)x(%d+)')
if not cols then return end
node.config.cols = tonumber(cols)
node.config.rows = tonumber(rows)
local scroll = engine.dom.scroll_registry[node]
if scroll then
scroll.cols = node.config.cols
scroll.rows = node.config.rows
end
dom_mod.mark_dirty(engine.dom, node)
end
std.ui.queryOne = function(selector)
return query.query_one(engine.dom, selector)
end
std.ui.query = function(selector)
return query.query(engine.dom, selector)
end
end
local P = {
install = install,
}
return P
end)
b48aa[41] = r48aa(41, function()
local function add_style(std, node, stylesheet_str)
for style in stylesheet_str:gmatch('%S+') do
std.ui.style(style):add(node)
end
end
local function flat_childs(src, dest)
for i = 1, #src do
local c = src[i]
if type(c) == 'table' and c[1] ~= nil and not c.node and not c.config then
flat_childs(c, dest)
else
dest[#dest + 1] = c
end
end
return dest
end
local function create_h(std, engine)
local function h(element, attribute, ...)
local el_type = type(element)
attribute = attribute or {}
local childs = flat_childs({...}, {})
if element == std then
return error
elseif element == std.h then
for i = 1, #childs do
std.node.spawn(std.node.load(childs[i]))
end
return childs
elseif element == std.ui then
return childs
elseif element == 'node' then
local parent = std.node.spawn(std.node.load(attribute))
for i = 1, #childs do
local c = childs[i]
if c.node then
local is_invalid = (c.span or 1) > 1 or c.offset or c.after
if is_invalid then
error('[error] JSX forbidden attributes in \'node\' child')
end
std.node.spawn(c.node, parent)
if c.span ~= nil then c.node.config.size = c.span end
if c.id and not c.node.config.id then
c.node.config.id = c.id
engine.dom.index_id[c.id] = c.node
end
if c.style then add_style(std, c.node, c.style) end
else
std.node.spawn(c, parent)
end
end
return parent
elseif element == 'grid' then
local has_scroll = attribute.scroll or attribute.anchor
local has_opts   = has_scroll or attribute.id
local grid_opts  = has_opts and {
scroll = attribute.scroll,
anchor = attribute.anchor,
id     = attribute.id,
} or nil
local grid = std.ui.grid(attribute.class, grid_opts)
if attribute.dir then grid:dir(attribute.dir) end
if attribute.style then add_style(std, grid.node, attribute.style) end
for i = 1, #childs do
local item = childs[i]
if has_scroll and item.span and type(item.span) == 'string' then
error('[error] scrollable grid does not support 2D span, use number')
end
if item.node then
grid:add(item.node, {span=item.span, offset=item.offset, after=item.after, id=item.id})
if item.style then add_style(std, grid:get_item(i), item.style) end
else
grid:add(item)
end
end
grid.span   = attribute.span
grid.after  = attribute.after
grid.style  = attribute.style
grid.offset = attribute.offset
return grid
elseif element == 'item' then
return {
type   = 'item',
node   = childs[1],
span   = attribute.span,
after  = attribute.after,
style  = attribute.style,
offset = attribute.offset,
id     = attribute.id,
}
elseif element == 'style' then
local name = attribute.class
if not name then
local keys = {}
for k in pairs(attribute) do
if k ~= 'children' then
keys[#keys + 1] = k
end
end
table.sort(keys)
local parts = {}
for _, k in ipairs(keys) do
parts[#parts + 1] = k .. '=' .. tostring(attribute[k])
end
name = table.concat(parts)
end
if childs and #childs > 0 then
local style_obj = std.ui.style(name, attribute)
local child = childs[1]
local target = child.node or child
style_obj:add(target)
return child
else
return std.ui.style(name, attribute)
end
elseif el_type == 'function' then
attribute.children = (#childs > 1) and childs or childs[1]
return element(attribute, std)
elseif el_type == 'table' then
return element
else
error('[error] JSX invalid element type: ' .. el_type)
end
end
return h
end
local function install(std, engine)
std.h = create_h(std, engine)
end
local P = {
create_h = create_h,
install  = install,
}
return P
end)
b48aa[42] = r48aa(42, function()
local function get_max_width(indent)
if indent <= 40 then
return 80
else
return nil
end
end
local function wrap_text(text, indent)
local max_width = get_max_width(indent)
local prefix = string.rep("  ", indent)
if not max_width then
local lines = {}
for line in text:gmatch("[^\n]+") do
table.insert(lines, prefix .. line)
end
return table.concat(lines, "\n")
end
local words = {}
for word in text:gmatch("%S+") do table.insert(words, word) end
local lines = {}
local line = ""
for _, word in ipairs(words) do
if #line + #word + 1 > max_width - indent * 2 then
table.insert(lines, prefix .. line)
line = word
else
if line == "" then
line = word
else
line = line .. " " .. word
end
end
end
if line ~= "" then table.insert(lines, prefix .. line) end
return table.concat(lines, "\n")
end
local function sanitize_key(key)
if type(key) ~= "string" then
key = tostring(key)
end
key = key:gsub("[^%w_-]", "_")
return key
end
local function should_quote(s)
if type(s) ~= "string" then return false end
if s:match("^[^%a_]") or s:match("^%d+$") then
return true
end
if s == "true" or s == "false" or s == "null" then
return false
end
return false
end
local function format_string(s, indent)
if type(s) ~= "string" then
return tostring(s)
end
local max_width = get_max_width(indent)
if s:find("\n") then
local lines = {}
for line in s:gmatch("[^\n]+") do
if max_width then
line = wrap_text(line, indent + 1)
else
line = string.rep("  ", indent + 1) .. line
end
table.insert(lines, line)
end
return "|-\n" .. table.concat(lines, "\n")
elseif max_width and #s > max_width - indent * 2 then
return ">-\n" .. wrap_text(s, indent + 1)
elseif should_quote(s) then
return string.format("%q", s)
else
return s
end
end
local function to_yaml(tbl, indent)
indent = indent or 0
local yaml = ""
local prefix = string.rep("  ", indent)
local nums = {}
local keys = {}
for k, v in pairs(tbl) do
if type(v) ~= "function" then
if type(k) == "number" then
table.insert(nums, k)
else
table.insert(keys, k)
end
end
end
table.sort(keys)
for _, k in ipairs(keys) do
local v = tbl[k]
local safe_key = sanitize_key(k)
if type(v) == "table" then
yaml = yaml .. prefix .. safe_key .. ":\n" .. to_yaml(v, indent + 1)
else
yaml = yaml .. prefix .. safe_key .. ": " .. format_string(v, indent) .. "\n"
end
end
table.sort(nums)
for _, k in ipairs(nums) do
local v = tbl[k]
if type(v) == "table" then
yaml = yaml .. prefix .. "-\n" .. to_yaml(v, indent + 1)
else
yaml = yaml .. prefix .. "- " .. format_string(v, indent) .. "\n"
end
end
return yaml
end
return {
encode = to_yaml
}
end)
b48aa[43] = r48aa(43, function()
local function creater_counter(start)
local next_id = start or 0
local free = {}
local free_top = 0
local function nextId()
if free_top > 0 then
local id = free[free_top]
free[free_top] = nil
free_top = free_top - 1
return id
end
next_id = next_id + 1
return next_id
end
local function clearId(id)
if id == nil then return end
free_top = free_top + 1
free[free_top] = id
end
local function clearAll(value)
next_id = value or 0
free = {}
free_top = 0
end
return nextId, clearId, clearAll
end
return creater_counter
end)
b48aa[44] = r48aa(44, function()
local P = {
data={
width=1280,
height=720
},
meta={
},
config = {
offset_x = 0,
offset_y = 0
},
callbacks={
}
}
return P;
end)
b48aa[46] = r48aa(46, function()
local function is_ok(status)
return (status and 200 <= status and status < 300) or false
end
local function is_ok_header(header)
local status = tonumber(header:match('HTTP/%d.%d (%d%d%d)'))
local ok = status and is_ok(status) or false
return ok, status
end
local function is_redirect(status)
return (status and 300 <= status and status < 400) or false
end
local function get_content(response)
local header, body = response:match("^(.-\r\n\r\n)(.*)")
if not header or not body then return nil end
local content_length = tonumber(header:match("Content%-Length:%s*(%d+)"))
if not content_length then return nil end
if #body < content_length then return nil end
local content = body:sub(1, content_length)
return content
end
local function get_user_agent()
return 'Ginga (GlyOS;SmartTv/Linux)'
end
local function create_request(method, uri)
local self = {
body_content = '',
header_list = {},
header_dict = {},
header_imutable = {},
print_http_status = true
}
self.add_body_content = function (body)
self.body_content = self.body_content..(body or '')
return self
end
self.add_imutable_header = function (header, value, cond)
if cond == false then return self end
if self.header_imutable[header] == nil then
self.header_list[#self.header_list + 1] = header
self.header_dict[header] = value
elseif self.header_imutable[header] == false then
self.header_dict[header] = value
end
self.header_imutable[header] = true
return self
end
self.add_mutable_header = function (header, value, cond)
if cond == false then return self end
if self.header_imutable[header] == nil then
self.header_list[#self.header_list + 1] = header
self.header_imutable[header] = false
self.header_dict[header] = value
end
return self
end
self.add_custom_headers = function(header_list, header_dict)
local index = 1
while header_list and #header_list >= index do
local header = header_list[index]
local value = header_dict[header]
if self.header_imutable[header] == nil then
self.header_list[#self.header_list + 1] = header
self.header_imutable[header] = false
self.header_dict[header] = value
elseif self.header_imutable[header] == false then
self.header_dict[header] = value
end
index = index + 1
end
return self
end
self.not_status = function()
self.print_http_status = false
return self
end
self.to_http_protocol = function ()
local index = 1
local request = method..' '..uri..' HTTP/1'..'.1\r\n'
while index <= #self.header_list do
local header = self.header_list[index]
local value = self.header_dict[header]
request = request..header..': '..value..'\r\n'
index = index + 1
end
request = request..'\r\n'
if method ~= 'GET' and method ~= 'HEAD' and #self.body_content > 0 then
request = request..self.body_content..'\r\n\r\n'
end
return request, function() end
end
self.to_curl_cmd = function ()
local index = 1
local request = 'curl -L -'..'-silent -'..'-insecure '
if self.print_http_status then
request = request..'-w "\n%{http_code}" '
end
if method == 'HEAD' then
request = request..'-'..'-HEAD '
else
request = request..'-X '..method..' '
end
while index <= #self.header_list do
local header = self.header_list[index]
local value = self.header_dict[header]
request = request..'-H "'..header..': '..value..'" '
index = index + 1
end
if method ~= 'GET' and method ~= 'HEAD' and #self.body_content > 0 then
request = request..'-d \''..self.body_content..'\' '
end
request = request..uri
return request, function() end
end
self.to_wget_cmd = function ()
local request = 'wget -'..'-quiet -'..'-output-document=-'
if method == 'HEAD' then
request = request..' -'..'-method=HEAD'
elseif method ~= 'GET' then
request = request..' -'..'-method='..method
end
for index, header in ipairs(self.header_list) do
local value = self.header_dict[header]
if value then
local escaped_value = value:gsub('"', '\\"')
request = request..' -'..'-header="'..header..': '..escaped_value..'"'
end
end
if method ~= 'GET' and method ~= 'HEAD' and #self.body_content > 0 then
local escaped_body = self.body_content:gsub('"', '\\"')
request = request..' -'..'-body-data="'..escaped_body..'"'
end
request = request..' '..uri
return request, function() end
end
return self
end
return {
is_ok=is_ok,
is_ok_header=is_ok_header,
is_redirect=is_redirect,
get_content=get_content,
get_user_agent=get_user_agent,
create_request=create_request
}
end)
b48aa[47] = r48aa(47, function()
local function percent_encode(str)
return (str:gsub('[^A-Za-z0-9%-_%.~]', function(c)
return string.format('%%%02X', string.byte(c))
end))
end
local function search_param(param_list, param_dict)
local index, params = 1, ''
while param_list and param_dict and index <= #param_list do
local param = param_list[index]
local value = param_dict[param]
if #params == 0 then
params = params..'?'
else
params = params..'&'
end
params = params..percent_encode(param)..'='..percent_encode(value or '')
index = index + 1
end
return params
end
local P = {
search_param = search_param
}
return P
end)
b48aa[48] = r48aa(48, function()
local ss = b48aa[32]('source_engine_browser_stylesheet')
local layout = b48aa[34]('source_engine_browser_layout')
local lifecycle = b48aa[35]('source_engine_browser_lifecycle')
local dom = b48aa[3]('source_engine_browser_dom')
local pause = b48aa[33]('source_engine_browser_pause')
local function is_descendant(node, needle)
if node == needle then return true end
if node.childs then
for _, child in ipairs(node.childs) do
if is_descendant(child, needle) then return true end
end
end
return false
end
local function find_focusable(node)
if node.config.parent == nil then return nil end
if node.config._span_hidden then return nil end
if node.config.focusable then return node end
if node.childs then
for _, child in ipairs(node.childs) do
local found = find_focusable(child)
if found then return found end
end
end
return nil
end
local function find_first(self, node)
node = node or self.root
local cfg = node.config
if node ~= self.root and cfg.parent == nil then return nil end
if cfg.visible == false
or cfg._scroll_clipped
or cfg._span_hidden
or (cfg.uid and pause.is_paused(self, cfg.uid, '*')) then
return nil
end
if cfg.focusable then return node end
if node.childs then
for _, child in ipairs(node.childs) do
local found = find_first(self, child)
if found then return found end
end
end
return nil
end
local function find_scroll_parent(self, node)
local current = node.config.parent
while current do
if self.scroll_registry[current] then return current end
current = current.config.parent
end
return nil
end
local function ensure_visible(self, grid_node, focus_node)
local scroll = self.scroll_registry[grid_node]
if not scroll then return end
local childs = grid_node.childs
if not childs then return end
local function is_desc(root, needle)
if root == needle then return true end
if root.childs then
for _, c in ipairs(root.childs) do
if is_desc(c, needle) then return true end
end
end
return false
end
local child_index = -1
for i, child in ipairs(childs) do
if is_desc(child, focus_node) then
child_index = i - 1
break
end
end
if child_index < 0 then return end
if scroll.mode == 'peek' then
if scroll.index == child_index then return end
scroll.index = child_index
dom.mark_dirty(self, grid_node)
return
end
local step          = layout.slide_step(scroll)
local visible_count = scroll.cols * scroll.rows
local first_visible = scroll.index * step
local last_visible  = first_visible + visible_count - 1
if child_index < first_visible then
if scroll.mode == 'page' then
scroll.index = math.floor(child_index / step)
else
scroll.index = child_index
end
elseif child_index > last_visible then
if scroll.mode == 'page' then
scroll.index = math.floor(child_index / step)
else
scroll.index = child_index - visible_count + 1
end
else
return
end
if scroll.index < 0 then scroll.index = 0 end
dom.mark_dirty(self, grid_node)
end
local function set_focus(self, node)
if not node then return nil end
if node ~= self.root and node.config.parent == nil then return nil end
if node.config._span_hidden then return nil end
if pause.is_paused(self, node.config.uid, '*') then return nil end
local old = self.focus_current
if old == node then return nil end
local std = self.std
if old then
for name, focus_func in pairs(old.config.style_focus or {}) do
ss.css_del(self, focus_func, old)
local base_func = self.stylesheet_func[name]
if base_func then ss.css_add(self, base_func, old) end
end
lifecycle.unfocus(self, old)
local left_scroll = find_scroll_parent(self, old)
while left_scroll do
if not is_descendant(left_scroll, node) then
local scroll = self.scroll_registry[left_scroll]
scroll.vindex = nil
if scroll.index ~= 0 then
scroll.index = 0
dom.mark_dirty(self, left_scroll)
end
end
left_scroll = find_scroll_parent(self, left_scroll)
end
end
self.focus_current = node
for name, focus_func in pairs(node.config.style_focus or {}) do
local base_func = self.stylesheet_func[name]
if base_func then ss.css_del(self, base_func, node) end
ss.css_add(self, focus_func, node)
end
lifecycle.focus(self, node)
local scroll_parent = find_scroll_parent(self, node)
while scroll_parent do
ensure_visible(self, scroll_parent, node)
scroll_parent = find_scroll_parent(self, scroll_parent)
end
return node
end
local function best_directional_candidate(self, current, direction, filter)
local cx = current.config.offset_x + current.data.width  / 2
local cy = current.config.offset_y + current.data.height / 2
local c_left   = current.config.offset_x
local c_right  = current.config.offset_x + current.data.width
local c_top    = current.config.offset_y
local c_bottom = current.config.offset_y + current.data.height
local best_node  = nil
local best_score = math.huge
for i = 1, #self.focus_list do
local candidate = self.focus_list[i]
if candidate ~= current
and candidate.config.visible ~= false
and not candidate.config._scroll_clipped
and not candidate.config._span_hidden
and candidate.config.focusable
and not pause.is_paused(self, candidate.config.uid, '*')
and filter(candidate) then
local px = candidate.config.offset_x + candidate.data.width  / 2
local py = candidate.config.offset_y + candidate.data.height / 2
local dx, dy = px - cx, py - cy
local valid = false
local score = 0
local p_left   = candidate.config.offset_x
local p_right  = p_left + candidate.data.width
local p_top    = candidate.config.offset_y
local p_bottom = p_top  + candidate.data.height
local y_overlap = p_top < c_bottom and p_bottom > c_top
if direction == 'right' and p_left >= c_right and y_overlap then
valid = true; score = dx + math.abs(dy) * 3
elseif direction == 'left' and p_right <= c_left and y_overlap then
valid = true; score = -dx + math.abs(dy) * 3
elseif direction == 'down' and p_top >= c_bottom then
valid = true; score = dy + math.abs(dx) * 3
elseif direction == 'up' and p_bottom <= c_top then
valid = true; score = -dy + math.abs(dx) * 3
end
if valid and score < best_score then
best_score = score
best_node  = candidate
end
end
end
return best_node
end
local function accept_all() return true end
local function focus_navigate_spatial(self, current, direction, filter)
filter = filter or accept_all
local best_node = best_directional_candidate(self, current, direction, filter)
if not best_node then return nil end
if filter == accept_all then
local scroll_parent = find_scroll_parent(self, best_node)
local target = scroll_parent and find_focusable(scroll_parent) or best_node
return set_focus(self, target or best_node)
end
return set_focus(self, best_node)
end
local function step_grid_index(self, grid_node, current, direction)
local cfg    = grid_node.config
local childs = grid_node.childs
if not childs then return nil end
local cols = cfg.cols
local rows = cfg.rows
local dir  = cfg.dir
local idx = 0
for i, child in ipairs(childs) do
if child == current or is_descendant(child, current) then
idx = i; break
end
end
if idx == 0 then return nil end
local next_idx = idx
local total    = #childs
local scroll_state = self.scroll_registry[grid_node]
local mode = scroll_state and scroll_state.mode or 'shift'
if dir == 'col' then
if rows == 1 and (direction == 'down' or direction == 'up') then
return nil
end
local current_row = (idx - 1) % rows
if direction == 'down' then
if mode == 'page' and current_row == rows - 1 then return nil end
next_idx = idx + 1
elseif direction == 'up' then
if mode == 'page' and current_row == 0 then return nil end
next_idx = idx - 1
elseif direction == 'right' then next_idx = idx + rows
elseif direction == 'left'  then next_idx = idx - rows
end
else
if cols == 1 and (direction == 'left' or direction == 'right') then
return nil
end
local current_col = (idx - 1) % cols
if direction == 'right' then
if mode == 'page' and current_col == cols - 1 then return nil end
next_idx = idx + 1
elseif direction == 'left' then
if mode == 'page' and current_col == 0 then return nil end
next_idx = idx - 1
elseif direction == 'down'  then next_idx = idx + cols
elseif direction == 'up'    then next_idx = idx - cols
end
end
if mode == 'peek' then
local step = next_idx - idx
local vindex = scroll_state.vindex
if not vindex or vindex % total ~= idx - 1 then
vindex = idx - 1
end
if step > 0 then
vindex = vindex + step
elseif step < 0 then
if vindex + step < 0 then return nil end
vindex = vindex + step
end
scroll_state.vindex = vindex
next_idx = (vindex % total) + 1
end
if next_idx < 1 or next_idx > total then return nil end
return find_focusable(childs[next_idx])
end
local function focus_navigate_grid(self, grid_node, current, direction, filter)
filter = filter or accept_all
local scroll_state = self.scroll_registry[grid_node]
local saved_vindex = scroll_state and scroll_state.vindex
local probe   = current
local visited = {}
while true do
local next_node = step_grid_index(self, grid_node, probe, direction)
if not next_node or visited[next_node] then
if scroll_state then scroll_state.vindex = saved_vindex end
return nil
end
visited[next_node] = true
if filter(next_node) then return next_node end
probe = next_node
end
end
local function focus_navigate(self, direction, filter)
local current = self.focus_current
if not current then return nil end
local scroll_parent = find_scroll_parent(self, current)
while scroll_parent do
local next_node = focus_navigate_grid(self, scroll_parent, current, direction, filter)
if next_node then
return set_focus(self, next_node)
end
scroll_parent = find_scroll_parent(self, scroll_parent)
end
return focus_navigate_spatial(self, current, direction, filter)
end
local function is_focused(self, node)
return self.focus_current == node
end
local function press(self)
local node = self.focus_current
if node and not pause.is_paused(self, node.config.uid, '*') and node.callbacks.click then
local prev = self.current_node
self.current_node = node
if self.std then
node.callbacks.click(node.data, self.std)
end
self.current_node = prev
end
end
local P = {
set_focus              = set_focus,
focus_navigate         = focus_navigate,
focus_navigate_spatial = focus_navigate_spatial,
focus_navigate_grid    = focus_navigate_grid,
find_scroll_parent     = find_scroll_parent,
find_focusable         = find_focusable,
find_first             = find_first,
is_descendant          = is_descendant,
is_focused             = is_focused,
press                  = press,
}
return P
end)
b48aa[49] = r48aa(49, function()
local ss = b48aa[32]('source_engine_browser_stylesheet')
local nav = b48aa[48]('source_engine_browser_navigator')
local Query = {}
Query.__index = Query
function Query:focus(index)
if not index then
nav.set_focus(self.dom, self.node)
elseif type(index) == 'number' then
local child = self.node.childs and self.node.childs[index]
if child then
local focusable = nav.find_focusable(child)
if focusable then nav.set_focus(self.dom, focusable) end
end
end
return self
end
function Query:count()
return self.node.childs and #self.node.childs or 0
end
function Query:addStyle(name)
local func = ss.stylesheet(self.dom, name)
ss.css_add(self.dom, func, self.node, name)
return self
end
function Query:delStyle(name)
local func = self.dom.stylesheet_func and self.dom.stylesheet_func[name]
if func then ss.css_del(self.dom, func, self.node, name) end
return self
end
function Query:setAttr(key, value)
self.node.data[key] = value
return self
end
function Query:getAttr(key)
return self.node.data[key]
end
function Query:getId()
return self.node.config.id
end
function Query:isVisible()
return self.node.config.visible ~= false
end
local function wrap(self, node)
return setmetatable({ dom = self, node = node }, Query)
end
local function has_style(node, name)
local styles = node.config.style_names
if not styles then return false end
for i = 1, #styles do
if styles[i] == name then return true end
end
return false
end
local function nodes_by_style(self, name)
local result = {}
local nodes  = self.node_list
local root   = self.root
for i = 1, #nodes do
local node = nodes[i]
if (node == root or node.config.parent ~= nil) and has_style(node, name) then
result[#result + 1] = node
end
end
return result
end
local function make_filter(selector)
local prefix = selector:sub(1, 1)
local name   = selector:sub(2)
if prefix == '.' then
return function(node) return has_style(node, name) end
elseif prefix == '#' then
return function(node) return node.config.id == name end
end
return nil
end
local function query_one(self, selector)
local prefix = selector:sub(1, 1)
local name   = selector:sub(2)
local node
if prefix == '#' then
node = self.index_id[name]
elseif prefix == '.' then
node = nodes_by_style(self, name)[1]
elseif selector == 'focused' then
node = self.focus_current
elseif selector == 'self' then
node = self.current_node
end
if not node then return nil end
return wrap(self, node)
end
local function query(self, selector)
local prefix = selector:sub(1, 1)
local name   = selector:sub(2)
if prefix == '.' then
local list   = nodes_by_style(self, name)
local result = {}
for i = 1, #list do
result[i] = wrap(self, list[i])
end
return result
end
local node = query_one(self, selector)
return node and { node } or {}
end
local P = {
query_one      = query_one,
query          = query,
wrap           = wrap,
nodes_by_style = nodes_by_style,
has_style      = has_style,
make_filter    = make_filter,
}
return P
end)
b48aa[50] = r48aa(50, function()
local dom = b48aa[3]('source_engine_browser_dom')
local util_decorator = b48aa[2]('source_shared_functional_decorator')
local function add(std, engine, self, application, options)
if not application then return self end
local node   = application.node or std.node.load(application)
local size   = (type(options) == 'number' and options) or (options or {}).span
local after  = type(options) == 'table' and options.after
local offset = type(options) == 'table' and options.offset
local id     = type(options) == 'table' and options.id
local class  = type(options) == 'table' and options.class
dom.node_add(engine.dom, node, {
parent = self.node,
offset = offset,
after  = after,
size   = size,
id     = id,
class  = class,
})
return self
end
local function add_items(std, engine, self, applications)
local index = 1
while applications and index <= #applications do
add(std, engine, self, applications[index])
index = index + 1
end
return self
end
local function get_item(self, id)
return self.node.childs[id]
end
local function get_items(self)
return self.node.childs
end
local function scroll_register(dom_obj, node, options)
options = options or {}
local cols = node.config.cols
local rows = node.config.rows
local default_mode = (cols > 1 and rows > 1) and 'page' or 'shift'
local mode = options.mode or options.scroll or default_mode
local default_anchor
if mode == 'peek' then
local dim = (rows == 1) and cols or rows
default_anchor = dim >= 3 and 1 or 0
end
dom_obj.scroll_registry[node] = {
mode   = mode,
index  = 0,
anchor = options.anchor or default_anchor,
total  = 0,
cols   = cols,
rows   = rows,
dir    = node.config.dir,
}
end
local function dir(self, mode)
if mode then
self.node.config.dir = mode
end
return self
end
local function component(std, engine, layout, options)
local cols, rows = layout:match('(%d+)x(%d+)')
local node = std.node.load({})
dom.node_add(engine.dom, node, {
parent = engine.current,
id     = options and options.id,
class  = options and options.class,
})
node.config.type = 'grid'
node.config.cols = tonumber(cols)
node.config.rows = tonumber(rows)
if node.config.rows == 1 and node.config.cols > 1 then
node.config.dir = 'col'
elseif node.config.cols == 1 and node.config.rows > 1 then
node.config.dir = 'row'
else
node.config.dir = 'row'
end
if options then
scroll_register(engine.dom, node, options)
end
return {
node      = node,
add       = util_decorator.prefix2(std, engine, add),
add_items = util_decorator.prefix2(std, engine, add_items),
get_items = get_items,
get_item  = get_item,
dir       = dir,
}
end
local P = {
component       = component,
scroll_register = scroll_register,
add             = add,
add_items       = add_items,
get_item        = get_item,
get_items       = get_items,
}
return P
end)
b48aa[51] = r48aa(51, function()
local ss = b48aa[32]('source_engine_browser_stylesheet')
local function add(engine, self, node)
local dom_obj = engine.dom
ss.css_add(dom_obj, self.func, node, self.name)
if self.name then
local focus_name = self.name .. ':focus'
if dom_obj.stylesheet_func and dom_obj.stylesheet_func[focus_name] then
node.config.style_focus = node.config.style_focus or {}
node.config.style_focus[self.name] = dom_obj.stylesheet_func[focus_name]
end
end
return self
end
local function add_items(engine, self, nodes)
local index = 1
while nodes and index <= #nodes do
add(engine, self, nodes[index])
index = index + 1
end
return self
end
local function remove(engine, self, node)
ss.css_del(engine.dom, self.func, node, self.name)
return self
end
local function component(engine, name, options)
local self = {
name = name,
func = ss.stylesheet(engine.dom, name, options),
add = function(a, b) return add(engine, a, b) end,
add_items = function(a, b) return add_items(engine, a, b) end,
remove = function(a, b) return remove(engine, a, b) end
}
return self
end
local P = {
component = component
}
return P
end)
return m48aa()
