local I={}
local floor,abs=math.floor,math.abs
local N=24
local models={}
local function point(u,v,z) return {u,v,z or 0} end
local function route(side,slot,...)
    return {side=side,slot=slot,points={...}}
end
local function south(u,m,z,...)
    return route(1,floor(u),point(u,m,z),...)
end
local function location(id,name,position,facing,contact,interior,routes,water)
    local anchors=models[id].anchors
    local entries=anchors[name]
    if not entries then entries={};anchors[name]=entries end
    entries[#entries+1]={position=position,facing=facing,contact=contact,interior=interior,routes=routes,water=water}
end
local sizes={{1,1},{1,1},{1,1},{2,2},{1,1},{2,2},{1,1},{1,1},{3,2},{4,3},{1,1},{2,1},{3,1},{1,1},{2,1},{2,2},{1,1},{1,1},{1,1},{2,1},{4,1},{2,3},{3,2},{3,2},{2,1},{2,2},{3,2},{3,2},{3,2},{2,1},{3,2},{2,2},{2,2},{2,2},{2,2},{2,1},{1,1},{1,1},{2,2},{3,2}}
for id=1,#sizes do models[id]={n=sizes[id][1],m=sizes[id][2],anchors={}} end
local function entrance(id,u,facade,stand,ground,threshold,depth,routes)
    local position=point(u,stand,ground)
    location(id,'door',position,3,point(u,facade,threshold),point(u,facade-depth,1),routes)
    location(id,'front',position,1,position,nil,routes)
end
local function planter(id,u,v,z,stand_u,stand_v,routes,facing)
    location(id,'garden',point(stand_u,stand_v,z),facing or 0,point(u,v,9),nil,routes)
end
local function corner_planter(id)
    local model=models[id];local u,v=model.n-.13,model.m-.12
    planter(id,u,v,0,u-.21875,v,{south(u-.21875,model.m,0)},0)
end

location(8,'front',point(.64,.91,1),0,point(.86,.76,23),nil,{south(.5,1,1,point(.5,.91,1))})
location(8,'bench',point(.45,.31,3),1,point(.45,.31,7),nil,{south(.45,1,1,point(.45,.61,1),point(.45,.4,1))})

local ferry_entry={south(.75,2,1,point(.75,1.4,1),point(.36,1.4,1)),route(2,1,point(0,1.4,1),point(.36,1.4,1))}
entrance(9,.36,1.12,1.4,1,1,.28,ferry_entry)
models[9].anchors.door[1].position=point(.36,1.27625,1)
location(9,'bench',point(2.22,.295,3),1,point(2.22,.295,7),nil,{route(0,0,point(3,.89,1),point(2.22,.89,1),point(2.22,.39,1))})
location(9,'shore',point(.75,1.88,1),1,point(.75,1.97,1),nil,{route(2,1,point(0,1.4,1),point(.75,1.4,1)),south(1.15,2,1,point(1.15,1.9,1),point(.75,1.9,1))},{side=1,slot=0})
location(9,'shore',point(.12,1.44,1),2,point(.02,1.44,1),nil,{south(.75,2,1,point(.75,1.44,1))},{side=2,slot=1})
location(9,'shore',point(2.86,.95,1),0,point(2.98,.95,1),nil,{route(2,1,point(0,1.24,1),point(1.77,1.24,1),point(1.77,.95,1)),south(.75,2,1,point(.75,1.24,1),point(1.77,1.24,1),point(1.77,.95,1))},{side=0,slot=0})

entrance(10,.36,2.81,2.96,1,1,.26,{south(.36,3,1)})
location(10,'yard',point(1.51875,1.61,1),2,point(1.3,1.61,8),nil,{south(2.55,3,1,point(2.55,1.96,1),point(1.51875,1.96,1))})
location(10,'shore',point(3.72,2.26,1),0,point(3.97,2.26,1),nil,{south(2.55,3,1,point(2.55,2.26,1))},{side=0,slot=2})
location(10,'shore',point(2.5,2.87,1),1,point(2.5,2.97,1),nil,{route(0,2,point(4,2.3,1),point(2.5,2.3,1))},{side=1,slot=2})
location(10,'shore',point(.1,2.04,1),2,point(.03,2.04,1),nil,{south(1.6,3,1,point(1.6,2.04,1))},{side=2,slot=2})

for _,id in ipairs({11,12}) do
    entrance(id,.3,.8,.94,1,2,.28,{south(.3,1,1)})
end
corner_planter(11)
planter(12,1.4,.75125,0,1.4,.97,{south(1.4,1,0),route(0,0,point(2,.61,0),point(2,1,0),point(1.4,1,0))},3)
location(12,'yard',point(1.72,.6,.4),0,point(1.8,.6,.4),nil,{route(0,0,point(2,.61,0),point(1.85,.61,.4))})
for k=0,2 do
    entrance(13,k+.26,.75,.93,1,2,.27,{south(k+.27,1,1,point(k+.27,.93,1))})
    planter(13,k+.69,.88,0,k+.47125,.88,{south(k+.47125,1,0)},0)
end
for _,id in ipairs({14,15}) do
    entrance(id,.3,.8,.94,0,1,.28,{south(.3,1,0)})
    corner_planter(id)
end
entrance(16,.3,1.6,1.79,0,1,.3,{south(.3,2,0)})
corner_planter(16)

for _,id in ipairs({17,18,19,20}) do
    entrance(id,.3,.78,.94,0,1,.27,{south(.3,1,0)})
    models[id].anchors.front={}
    location(id,'front',point(.33,.935,0),2,point(.135,.875,7),nil,{south(.33,1,0)})
    corner_planter(id)
end
models[20].anchors.front={}
location(20,'front',point(.6,.935,0),2,point(.6,.935,0),nil,{south(.6,1,0)})
for k=0,3 do
    location(21,'counter',point(k+.49,.85625,0),3,point(k+.49,.7,12),nil,{south(k+.49,1,0)})
    location(21,'front',point(k+.49,.94,0),1,point(k+.49,.94,0),nil,{south(k+.49,1,0)})
end
corner_planter(21)

local hotel_entry={route(2,1,point(0,1.76,0)),route(0,1,point(2,1.76,0),point(1.72,1.76,0))}
entrance(22,.3,1.6,1.76,0,1,.3,hotel_entry)
planter(22,.45,2.8,0,.66875,2.8,{south(.66875,3,0)},2)
location(22,'yard',point(1.44,2.1,0),0,point(1.65,2.1,0),nil,{route(0,2,point(2,2.3,0),point(1.44,2.3,0))})
for _,id in ipairs({23,24,33,34,40}) do
    entrance(id,.3,1.25,1.44,0,1,.3,{south(.3,2,0)})
    corner_planter(id)
    location(id,'yard',point(1.55,1.69,0),0,point(1.76875,1.69,0),nil,{south(1.55,2,0)})
end
entrance(25,.3,.78,.94,0,1,.27,{south(.3,1,0)})
location(25,'yard',point(1.26,.94,0),3,point(1.26,.78,6),nil,{south(1.26,1,0)})
corner_planter(25)
location(26,'yard',point(1.36875,1,0),2,point(1.15,1,4),nil,{route(0,1,point(2,1.4,0),point(1.36875,1.4,0)),south(1.4,2,0,point(1.4,1,0))})
location(27,'yard',point(2.82,1.4,0),2,point(2.7,1.4,10),nil,{route(0,1,point(3,1.4,0)),south(2.82,2,0)})

entrance(28,.3,1.25,1.3,0,1,.27,{route(2,1,point(0,1.3,0),point(.18,1.3,0))})
models[28].anchors.front={}
location(28,'front',point(1.37,1.65,0),3,point(1.37,1.25,7),nil,{south(1.37,2,0)})
location(28,'yard',point(1.33875,1.62,0),2,point(1.12,1.62,8),nil,{south(1.33875,2,0)})
corner_planter(28)
entrance(29,.3,1.25,1.35,0,1,.27,{route(2,1,point(0,1.35,0)),south(.975,2,0,point(.975,1.35,0))})
location(29,'yard',point(.975,1.65,0),2,point(.85,1.65,8),nil,{south(.975,2,0)})
corner_planter(29)
entrance(30,.3,.78,.94,0,1,.27,{south(.3,1,0)})
corner_planter(30)
entrance(31,.3,1.25,1.4,0,1,.28,{south(.3,2,0,point(.3,1.85,1),point(.3,1.45,1))})
models[31].anchors.front={}
location(31,'front',point(.62,1.63,1),1,point(.62,1.63,1),nil,{south(.62,2,0,point(.62,1.85,1))})
location(31,'yard',point(1.5,1.66,1),0,point(1.71875,1.66,1),nil,{south(1.5,2,0,point(1.5,1.85,1))})
corner_planter(31)
entrance(32,.3,1.25,1.275,0,1,.28,{})
models[32].anchors.front={}
location(32,'front',point(.925,1.61,0),2,point(.8,1.61,11),nil,{south(.925,2,0)})

location(35,'front',point(.96,1.83,1),1,point(.96,1.83,1),nil,{south(.96,2,1)})
location(35,'yard',point(1.16,1.12,1),0,point(1.37875,1.12,1),nil,{south(.96,2,1,point(.96,1.72,1),point(.97,1.29,1))})
location(35,'bench',point(1.475,1.56,3),1,point(1.475,1.56,7),nil,{south(1.475,2,0,point(1.475,1.7,1)),south(.96,2,1,point(.96,1.75,1),point(1.475,1.7,1))})
planter(35,1.83,1.88,0,1.61125,1.88,{south(1.61125,2,0)},0)
location(36,'front',point(.5,.7,10),1,point(.5,.7,10),nil,{south(.5,1,0,point(.5,.9,10))})
location(36,'lookout',point(.52,.36,10),3,point(.52,.15,22),nil,{south(.52,1,0,point(.52,.9,10),point(.52,.6,10))})

entrance(37,.36,.75,.93,0,1,.25,{south(.36,1,0)})
planter(37,.1,.86,0,.31875,.86,{south(.31875,1,0)},2)
location(37,'shore',point(.92,.45,0),0,point(.985,.45,0),nil,{route(3,0,point(.5,0,0),point(.5,.08,0),point(.92,.08,0))},{side=0,slot=0})
location(37,'shore',point(.085,.5,0),2,point(.015,.5,0),nil,{route(3,0,point(.5,0,0),point(.5,.08,0),point(.085,.08,0)),route(0,0,point(1,.4,0),point(.92,.4,0),point(.92,.08,0),point(.085,.08,0))},{side=2,slot=0})
location(37,'shore',point(.63,.09,0),3,point(.63,.015,0),nil,{route(0,0,point(1,.4,0),point(.92,.4,0),point(.92,.09,0)),route(2,0,point(0,.45,0),point(.08,.45,0),point(.08,.09,0))},{side=3,slot=0})
location(37,'shore',point(.55,.92,0),1,point(.55,.985,0),nil,{}, {side=1,slot=0})
location(38,'front',point(.5,.74,0),3,point(.5,.48,6),nil,{south(.5,1,0)})
location(38,'yard',point(.5,.74,0),1,point(.5,.74,0),nil,{south(.5,1,0)})
entrance(39,.28,.9,1.08,0,1,.28,{south(.28,2,0)})
location(39,'yard',point(1.28125,1.22,1),0,point(1.5,1.22,8),nil,{south(1.25,2,0,point(1.25,1.72,1),point(1.25,1.22,1))})
corner_planter(39)

local function rotate(u,v,n,m,r)
    if r==1 then return m-v,u end
    if r==2 then return n-u,m-v end
    if r==3 then return v,n-u end
    return u,v
end
local function boundary_cell(model,rotation,x,y,side,slot)
    local u,v
    if side==0 then u,v=model.n+.5,slot+.5
    elseif side==1 then u,v=slot+.5,model.m+.5
    elseif side==2 then u,v=-.5,slot+.5
    else u,v=slot+.5,-.5 end
    u,v=rotate(u,v,model.n,model.m,rotation)
    u,v=floor(x+u),floor(y+v)
    if u<0 or v<0 or u>=N or v>=N then return nil end
    return v*N+u+1
end
local function world_point(p,model,rotation,x,y,z)
    local u,v=rotate(p[1],p[2],model.n,model.m,rotation)
    return {x=x+u-.5,y=y+v-.5,z=z+p[3]}
end
local function road_access(w,k,z)
    if not k or not w.road[k] or (w.reserved and w.reserved[k]) then return false end
    local navigation=w.navigation
    if navigation and navigation.revision==w.revision and navigation.lots==w.lot_revision then
        return navigation.walk[k] and abs(navigation.height[k]-z)<=8
    end
    if w.base[k]<=0 or (w.mask[k]~=0 and w.mask[k]~=3 and w.mask[k]~=6 and w.mask[k]~=9 and w.mask[k]~=12) then return false end
    local u,v=(k-1)%N,floor((k-1)/N);local vertex=v*(N+1)+u+1
    local height=(w.h[vertex]+w.h[vertex+1]+w.h[vertex+N+1]+w.h[vertex+N+2])*4
    return abs(height-z)<=8
end
local function water_access(w,model,rotation,x,y,water,z)
    if not water then return true end
    local k=boundary_cell(model,rotation,x,y,water.side,water.slot)
    return k~=nil and w.base[k]==0 and w.occ[k]==0 and z==16
end
local function resolve_location(w,model,rotation,x,y,z,entry,access)
    local standing=world_point(entry.position,model,rotation,x,y,z)
    local contact=world_point(entry.contact,model,rotation,x,y,z)
    local interior=entry.interior and world_point(entry.interior,model,rotation,x,y,z) or standing
    local result={x=standing.x,y=standing.y,z=standing.z,facing=(entry.facing+rotation)%4,contact_x=contact.x,contact_y=contact.y,contact_z=contact.z,interior_x=interior.x,interior_y=interior.y,interior_z=interior.z,has_interior=entry.interior~=nil,reachable=access~=nil,approach={},approach_cell=access and access.cell or 0}
    if entry.water then result.water_z=0 end
    if access then
        local points=access.route.points;local approach=result.approach
        for i=1,#points do approach[#approach+1]=world_point(points[i],model,rotation,x,y,z) end
        local last=approach[#approach]
        if not last or last.x~=standing.x or last.y~=standing.y or last.z~=standing.z then approach[#approach+1]=standing end
    end
    return result
end
local function site_job(w,id,rotation,x,y)
    if not w.jobs then return nil end
    for i=1,#w.jobs do
        local job=w.jobs[i]
        if job.building_id==id and job.rotation==rotation and job.x==x and job.y==y then return job end
    end
    return nil
end
local function append_site(points,u,v,z,x,y,base)
    local last=points[#points];local xx,yy,zz=x+u-.5,y+v-.5,base+z
    if not last or last.x~=xx or last.y~=yy or last.z~=zz then points[#points+1]={x=xx,y=yy,z=zz} end
end
local function site_anchor(w,id,rotation,x,y,name,approach_cell)
    local job=site_job(w,id,rotation,x,y)
    local model=models[id];local nx,ny=model.n,model.m
    if rotation%2==1 then nx,ny=ny,nx end
    if not job then
        if name~='work_edge' or x<0 or y<0 or x+nx>N or y+ny>N then return nil end
        local height=w.base[y*N+x+1]
        if not height or height<1 then return nil end
        for v=0,ny-1 do
            for u=0,nx-1 do
                local k=(y+v)*N+x+u+1
                if w.occ[k]~=0 or (w.reserved and w.reserved[k]) or w.base[k]~=height or w.mask[k]~=0 then return nil end
            end
        end
    elseif name=='work_surface' and job.stage=='reserved' then return nil end
    local base=w.base[y*N+x+1]*16
    local tile_x,tile_y,side=x,y,1
    local matched=false
    if approach_cell and approach_cell>=1 and approach_cell<=N*N then
        local ax,ay=(approach_cell-1)%N,floor((approach_cell-1)/N)
        if ax==x-1 and ay>=y and ay<y+ny then tile_y,side,matched=ay,2,true
        elseif ax==x+nx and ay>=y and ay<y+ny then tile_x,tile_y,side,matched=x+nx-1,ay,0,true
        elseif ay==y-1 and ax>=x and ax<x+nx then tile_x,side,matched=ax,3,true
        elseif ay==y+ny and ax>=x and ax<x+nx then tile_x,tile_y,side,matched=ax,y+ny-1,1,true end
    end
    local reachable=matched and road_access(w,approach_cell,base)
    local stage=job and job.stage or 'reserved'
    local points={}
    local u,v,ground,cu,cv,cz,facing
    if name=='work_surface' then
        cu,cv,cz=stage=='frame' and .72 or .69,stage=='frame' and .335 or .555,stage=='frame' and 4 or 3
        u,v,ground,facing=cu+.21875,cv,0,2
        if reachable then
            if side==0 then
                append_site(points,1,.5,0,tile_x,tile_y,base)
                append_site(points,.96,.5,0,tile_x,tile_y,base)
            elseif side==1 then
                append_site(points,.5,1,0,tile_x,tile_y,base)
                append_site(points,.5,.96,0,tile_x,tile_y,base)
                append_site(points,.96,.96,0,tile_x,tile_y,base)
            elseif side==3 then
                append_site(points,.5,0,0,tile_x,tile_y,base)
                append_site(points,.5,.06,0,tile_x,tile_y,base)
                append_site(points,.96,.06,0,tile_x,tile_y,base)
            else
                append_site(points,0,.5,0,tile_x,tile_y,base)
                append_site(points,.06,.5,0,tile_x,tile_y,base)
                local edge=stage=='frame' and .06 or .96
                append_site(points,.06,edge,0,tile_x,tile_y,base)
                append_site(points,.96,edge,0,tile_x,tile_y,base)
            end
            append_site(points,.96,v,0,tile_x,tile_y,base)
        end
    else
        local edge=stage=='reserved' and .86 or .835
        ground,cz=stage=='reserved' and 0 or 2.1,stage=='reserved' and 2 or 4
        local inner=edge-.21875
        if side==0 then u,v,cu,cv,facing=inner,.68,edge,.68,0
        elseif side==1 then u,v,cu,cv,facing=.25,inner,.25,edge,1
        elseif side==2 then u,v,cu,cv,facing=1-inner,.68,1-edge,.68,2
        else u,v,cu,cv,facing=.25,1-inner,.25,1-edge,3 end
        if reachable then
            if side==0 then append_site(points,1,.68,0,tile_x,tile_y,base)
            elseif side==1 then append_site(points,.25,1,0,tile_x,tile_y,base)
            elseif side==2 then append_site(points,0,.68,0,tile_x,tile_y,base)
            else append_site(points,.25,0,0,tile_x,tile_y,base) end
            append_site(points,cu,cv,stage=='reserved' and 0 or 4,tile_x,tile_y,base)
        end
    end
    if reachable then append_site(points,u,v,ground,tile_x,tile_y,base) end
    return {x=tile_x+u-.5,y=tile_y+v-.5,z=base+ground,facing=facing,contact_x=tile_x+cu-.5,contact_y=tile_y+cv-.5,contact_z=base+cz,interior_x=tile_x+u-.5,interior_y=tile_y+v-.5,interior_z=base+ground,has_interior=false,reachable=reachable,approach=points,approach_cell=matched and approach_cell or 0,site_stage=stage,site_cell=tile_y*N+tile_x+1,preview=not job}
end
function I.resolve(w,building_id,rotation,x,y,anchor,approach_cell)
    local model=models[building_id]
    if not model then return nil end
    rotation=rotation%4
    if anchor=='work_edge' or anchor=='work_surface' then return site_anchor(w,building_id,rotation,x,y,anchor,approach_cell) end
    local entries=model.anchors[anchor]
    if not entries or #entries==0 then return nil end
    local z=w.base[y*N+x+1]*16
    local selected=entries[1]
    local access
    if road_access(w,approach_cell,z) then
        for i=1,#entries do
            local entry=entries[i]
            if water_access(w,model,rotation,x,y,entry.water,z) then
                for j=1,#entry.routes do
                    local candidate=entry.routes[j]
                    if boundary_cell(model,rotation,x,y,candidate.side,candidate.slot)==approach_cell then
                        selected=entry;access={route=candidate,cell=approach_cell};break
                    end
                end
            end
            if access then break end
        end
    end
    return resolve_location(w,model,rotation,x,y,z,selected,access)
end
return I
