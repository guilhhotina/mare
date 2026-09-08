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
