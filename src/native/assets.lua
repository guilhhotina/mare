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
