do
local checks=0
local floor,abs=math.floor,math.abs
local function expect(value,message) checks=checks+1;assert(value,message) end
local function empty(seed,water)
    local w=World.new(seed or 37,true)
    for k=1,625 do w.h[k]=water and 0 or 1 end
    for k=1,576 do w.bid[k]=0;w.rot[k]=0;w.deco[k]=0 end
    World.rebuild(w);return w
end
local function roads(seed)
    local w=empty(seed)
    for x=2,20 do w.bid[World.cell(x,5)]=3 end
    w.bid[World.cell(2,4)]=11;w.bid[World.cell(20,4)]=17
    World.rebuild(w);return w
end
local function first(w,kind)
    for i=1,#w.traffic do if w.traffic[i].kind==kind then return w.traffic[i] end end
end
local function present(w,id)
    for i=1,#w.traffic do if w.traffic[i].id==id then return true end end
    return false
end
local function until_true(w,predicate,limit)
    for i=1,limit or 1200 do if predicate() then return true end;World.update(w,50) end
    return predicate()
end
local function ports(seed,two)
    local w=empty(seed,true)
    for y=0,24 do for x=0,8 do w.h[y*25+x+1]=1 end end
    for x=1,7 do w.bid[World.cell(x,8)]=3 end
    w.bid[World.cell(2,9)]=11;w.bid[World.cell(4,5)]=10
    if two then
        for x=1,7 do w.bid[World.cell(x,18)]=3 end
        w.bid[World.cell(5,16)]=9
    end
    World.rebuild(w);return w
end
for _,id in ipairs({1,2,5,7}) do
    local w=roads();w.bid[World.cell(10,5)]=id;World.rebuild(w)
    World.update(w,15000)
    expect(not first(w,'car'),'cars cannot route through pedestrian surface '..id)
end
local avenue=roads();avenue.bid[World.cell(10,5)]=4;avenue.bid[World.cell(11,5)]=0;World.rebuild(avenue)
expect(until_true(avenue,function() local e=first(avenue,'car');return e and e.x>11 end),'avenue footprint carries a real trip across both occupied cells')
local deck=empty(3,true);deck.bid[World.cell(10,10)]=6;World.rebuild(deck)
local deck_nav=World.traffic_navigation(deck)
expect(deck_nav.pass.car[World.cell(10,10)] and deck_nav.pass.car[World.cell(11,11)] and deck_nav.height[World.cell(11,11)]==16,'road bridge footprint provides one consistent deck for vehicles')
local w=roads()
expect(until_true(w,function() local e=first(w,'car');return e and e.next_cell~=0 and e.progress>0 end),'residents depart a real home on a purpose-linked car trip')
local car=first(w,'car')
expect(car.home==World.cell(2,4) and car.destination==World.cell(20,4) and car.kind=='car' and car.sprite:match('^vehicle_car_[0-7]_[01]$'),'car exposes its origin, destination and ready sprite')
local frozen=World.encode(w);local resumed=World.decode(frozen)
expect(resumed and World.encode(resumed)==frozen,'mid-edge car save roundtrip retains exact traffic state')
for i=1,200 do World.update(w,17);World.update(w,33);World.update(resumed,50) end
expect(World.encode(w)==World.encode(resumed),'reload and elapsed-time partitions preserve routes, queues and future RNG decisions')
local gesture=World.snapshot(w);local before=World.encode(w)
expect(World.terraform(w,'raise',21,21,0,gesture,0,0),'remote terrain gesture can begin during a trip')
expect(World.restore(w,gesture) and World.encode(w)==before,'canceled gesture does not rewind traffic or invalidate an unchanged route')
local moving=World.encode(w);World.update(w,0)
expect(World.encode(w)==moving,'paused traffic preserves travel, appearance clocks and random state')
local cut=roads(11)
expect(until_true(cut,function() local e=first(cut,'car');return e and e.x>5 and e.x<7 end),'access cut starts with an actual traveling car')
local interrupted=first(cut,'car');local id=interrupted.id
local occupied=interrupted.next_cell~=0 and interrupted.next_cell or interrupted.cell
local original=World.encode(cut)
expect(not World.remove(cut,(occupied-1)%24,floor((occupied-1)/24)) and World.encode(cut)==original,'occupied road cannot disappear beneath a vehicle')
expect(World.remove(cut,12,5),'unoccupied road ahead can be removed')
World.update(cut,8000)
expect(present(cut,id) and interrupted.x<12 and interrupted.state=='wait','disconnected car waits on its safe side without jumping across the missing road')
expect(World.build(cut,3,12,5,0),'access can be restored without replacing the waiting car')
expect(until_true(cut,function() return interrupted.phase==2 end),'restored access completes the original outward journey')
expect(until_true(cut,function() return not present(cut,id) end),'dead-end arrival makes a real return trip before parking at home')
local removed=roads(19)
expect(until_true(removed,function() local e=first(removed,'car');return e and e.x>5 end),'destination removal starts after departure')
local returning=first(removed,'car');local returning_id=returning.id
expect(World.remove(removed,20,4),'destination may close while a car is traveling')
expect(until_true(removed,function() return returning.phase==2 end),'closed destination causes a physical homeward reroute')
expect(until_true(removed,function() return not present(removed,returning_id) end),'rerouted car reaches home rather than disappearing at the closed destination')
local ramp=roads(29)
for y=0,24 do for x=10,24 do ramp.h[y*25+x+1]=2 end end
World.rebuild(ramp)
expect(until_true(ramp,function() local e=first(ramp,'car');return e and e.x>9.1 and e.x<9.8 end),'car reaches the real road ramp')
expect(first(ramp,'car').z>16 and first(ramp,'car').z<32,'vehicle contact height follows the sloped surface')
local junction=empty(43)
for x=2,20 do junction.bid[World.cell(x,12)]=3 end
for y=2,20 do junction.bid[World.cell(12,y)]=3 end
junction.bid[World.cell(2,11)]=14;junction.bid[World.cell(20,13)]=14;junction.bid[World.cell(13,2)]=17
World.rebuild(junction)
local turned,waited,completed=false,false,false;local departures={}
for step=1,1600 do
    World.update(junction,50)
    for i=1,#junction.traffic do local e=junction.traffic[i]
        if e.kind=='car' then
            departures[e.id]=true;turned=turned or e.facing%2==1;waited=waited or e.wait>0
            for j=i+1,#junction.traffic do local q=junction.traffic[j]
                if q.kind=='car' then local dx,dy=e.x-q.x,e.y-q.y;expect(dx*dx+dy*dy>=.12,'intersection traffic maintains body separation') end
            end
        end
    end
    for id in pairs(departures) do if not present(junction,id) then completed=true end end
end
expect(turned and waited and completed,'crossing reservations allow visible curves, yielding and complete out-and-back trips')
local demand=empty(59)
for x=2,21 do demand.bid[World.cell(x,6)]=3 end
demand.bid[World.cell(2,4)]=16;demand.bid[World.cell(21,5)]=17;World.rebuild(demand)
expect(until_true(demand,function() return #demand.traffic==8 end),'large occupied housing can supply the full bounded vehicle fleet')
for step=1,600 do World.update(demand,50);expect(#demand.traffic<=8,'continued household demand cannot exceed eight simultaneous cars') end
local ocean=empty(71,true)
World.update(ocean,30000)
expect(not first(ocean,'boat') and first(ocean,'fish'),'open water supports foraging fish but cannot invent a harbor or embarkation')
local harbor=ports(97,true)
local harbor_nav=World.traffic_navigation(harbor)
expect(#harbor_nav.ports==2,'real coastal buildings expose reachable offshore berths across the shore ramp')
expect(until_true(harbor,function() local e=first(harbor,'boat');return e and e.state=='travel' and e.next_cell~=0 end),'boat loads at a real port and starts a water route')
local boat=first(harbor,'boat');local boat_id=boat.id
expect(boat.home~=0 and boat.destination~=0 and boat.home~=boat.destination,'boat trip links distinct real embarkation and landing points')
for i=1,#boat.path do expect(harbor_nav.pass.boat[boat.path[i]],'boat path preserves full body clearance from island and bridge cells') end
local sea_save=World.encode(harbor);local sea_resume=World.decode(sea_save)
expect(sea_resume and World.encode(sea_resume)==sea_save,'mid-voyage save retains the boat without another boarding spawn')
local quay=boat.destination
expect(World.remove(harbor,(quay-1)%24,floor((quay-1)/24)),'unused destination port can be removed during a voyage')
expect(until_true(harbor,function() return boat.phase==2 end),'removed landing point reroutes the same vessel to its real origin')
expect(until_true(harbor,function() return not present(harbor,boat_id) end),'rerouted vessel unloads at a reachable berth before retiring')
local rerouted=first(sea_resume,'boat');local reef=rerouted.path[math.min(#rerouted.path,rerouted.path_index+3)]
local rx,ry=(reef-1)%24,floor((reef-1)/24)
for y=ry,ry+1 do for x=rx,rx+1 do sea_resume.h[y*25+x+1]=1 end end
World.rebuild(sea_resume)
local landed=false
for i=1,1200 do
    local x,y=rerouted.x,rerouted.y;World.update(sea_resume,50)
    local dx,dy=rerouted.x-x,rerouted.y-y
    expect(dx*dx+dy*dy<=.001057,'changed coastline cannot relocate a traveling boat')
    expect(TrafficPaths.water(sea_resume,rerouted.x,rerouted.y,TrafficPaths.radius.boat),'rerouting preserves hull clearance around the new coast')
    if rerouted.phase==2 then landed=true;break end
end
expect(landed,'a new reef invalidates the cached voyage and the vessel navigates around it to land')
local coast=ports(101,false)
expect(until_true(coast,function() local e=first(coast,'boat');return e and e.next_cell~=0 end),'coast edit fixture starts an actual outbound vessel')
local vessel=first(coast,'boat');local cx,cy=vessel.x,vessel.y
local sea_gesture=World.snapshot(coast)
local safe_edit=World.terraform(coast,'raise',floor(cx+.5),floor(cy+.5),0,sea_gesture,0,0)
expect(not safe_edit and abs(vessel.x-cx)<1e-9 and abs(vessel.y-cy)<1e-9,'coast cannot rise through an occupied hull or teleport it out of the edit')
expect(World.restore(coast,sea_gesture),'blocked coastal gesture remains cancelable')
local barrier=empty(103,true)
for y=0,24 do barrier.h[y*25+12+1]=1 end
World.rebuild(barrier)
local bn=World.traffic_navigation(barrier)
local path=TrafficPaths.route(bn,'boat',World.cell(5,10),{World.cell(18,10)},World.cell(5,10),4019,2)
expect(not path,'marine planning cannot cross a continuous island barrier')
local bridge_block=empty(107,true);bridge_block.bid[World.cell(10,10)]=6;World.rebuild(bridge_block)
local bridge_water=World.traffic_navigation(bridge_block)
expect(not bridge_water.pass.boat[World.cell(10,10)] and not bridge_water.pass.whale[World.cell(9,9)],'bridge deck and body clearance exclude unsupported underwater crossings')
local function waiting_fish(text)
    local w=assert(World.decode(text));local e=first(w,'fish');local x,y=e.x,e.y
    e.path=nil;e.retry=w.traffic_state.time+10000
    local jumped,landed,saved=false,false,false
    for step=1,125 do
        World.update(w,50)
        local key=Traffic.sprite(e,0);local pose=tonumber(key:match('_(%d+)$'))
        if pose>=4 then
            jumped=true
            if pose>=15 and not saved then
                local checkpoint=World.encode(w);local reload=World.decode(checkpoint)
                expect(reload and World.encode(reload)==checkpoint and Traffic.sprite(first(reload,'fish'),0)==key,'reload retains an airborne fish without resetting its jump')
                saved=true
            end
        elseif jumped then landed=true end
    end
    expect(jumped and landed and saved and e.x==x and e.y==y,'a fish waiting for a route still completes its jump and returns to the water')
end
local function legacy_whale(text)
    local old=assert(World.decode(text));local original=first(old,'whale')
    original.age,original.duration=9000,18000
    local migrated=World.decode((World.encode(old):gsub('|TRAFFIC2,','|TRAFFIC1,',1)))
    local expected=assert(World.decode(text));first(expected,'whale').age=1600
    expect(migrated and World.encode(migrated)==World.encode(expected),'a legacy half-completed whale keeps its island, route and animation phase when its old duration is migrated')
    for step=1,34 do World.update(migrated,50) end
    expect(not present(migrated,original.id),'a migrated whale finishes its remaining dive instead of retaining the legacy nine-second wait')
end
local fish_checked=false
local wildlife=empty(131,true);local twin=empty(131,true)
local seen={fish=false,dolphin=false,whale=false};local saved_appearance={};local cycles={};local complete={}
for step=1,7600 do
    World.update(wildlife,50);World.update(twin,20);World.update(twin,30)
    local counts={car=0,boat=0,fish=0,dolphin=0,whale=0}
    for i=1,#wildlife.traffic do local e=wildlife.traffic[i]
        counts[e.kind]=counts[e.kind]+1;seen[e.kind]=true
        expect(TrafficPaths.water(wildlife,e.x,e.y,TrafficPaths.radius[e.kind]),'visible fauna retains species-sized navigable clearance')
        if e.kind=='fish' and not fish_checked then waiting_fish(World.encode(wildlife));fish_checked=true end
        if e.kind=='dolphin' or e.kind=='whale' then
            local cycle=cycles[e.id] or {kind=e.kind,started=wildlife.traffic_state.time-e.age,poses={}};cycles[e.id]=cycle
            for elapsed=0,48,16 do
                local pose=tonumber(Traffic.sprite(e,elapsed):match('_(%d+)$'))
                cycle.poses[pose]=true
            end
        end
        if (e.kind=='dolphin' or e.kind=='whale') and e.age>e.duration*.45 and not saved_appearance[e.kind] then
            local text=World.encode(wildlife);local reload=World.decode(text)
            expect(reload and World.encode(reload)==text,'reload retains the middle of a rare surfacing cycle')
            if e.kind=='whale' then legacy_whale(text) end
            saved_appearance[e.kind]=true
            twin=reload
        end
    end
    for kind,n in pairs(counts) do expect(n<=World.traffic_caps[kind],'species cap remains bounded: '..kind) end
    for id,cycle in pairs(cycles) do if not present(wildlife,id) then
        if cycle.kind=='dolphin' then expect(wildlife.traffic_state.time-cycle.started<=2000,'a dolphin completes its jump within two seconds instead of hanging above the water') end
        if cycle.kind=='whale' then expect(wildlife.traffic_state.time-cycle.started<=4000,'a whale surfaces and dives within four seconds instead of holding each pose for seconds') end
        for pose=0,(cycle.kind=='dolphin' and 48 or 96)-1 do expect(cycle.poses[pose],'draw-time sampling retains every surfacing pose through the complete rare appearance') end
        complete[cycle.kind]=true;cycles[id]=nil
    end end
    if step%100==0 then expect(World.encode(wildlife)==World.encode(twin),'seed and save preserve subsequent wildlife timing and movement') end
end
expect(seen.fish and saved_appearance.dolphin and saved_appearance.whale and complete.dolphin and complete.whale,'seeded simulated time reaches complete rare-species cycles, including reloadable appearances')
local cached=roads(149);World.update(cached,500)
local navigation=World.traffic_navigation(cached);local builds=navigation.builds
for i=1,80 do local searches=navigation.searches;World.update(cached,500);expect(navigation.searches-searches<=2,'one planning slice cannot exceed two bounded searches') end
expect(navigation.builds==builds,'stable source topology reuses passability while vehicles move')
local saved=World.encode(cached);local duplicate=World.decode(saved)
duplicate.traffic[2]=duplicate.traffic[1]
expect(World.decode(World.encode(duplicate))==nil,'persistence rejects duplicate vehicle identities instead of duplicating a trip')
expect(World.decode(saved..',0')==nil and World.decode(saved:gsub('|TRAFFIC2,','|TRAFFIC3,',1))==nil,'extension version and trailing field corruption remain detectable')
print('PASS traffic domain: '..checks..' assertions.')
end
