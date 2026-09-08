do
local checks=0
local function expect(value,message) checks=checks+1;assert(value,message) end
local function fixture()
    local w=World.new(17,false)
    for k=1,625 do w.h[k]=1 end
    for k=1,576 do w.bid[k]=0;w.rot[k]=0;w.deco[k]=0 end
    for x=2,20 do w.bid[World.cell(x,5)]=3 end
    w.bid[World.cell(2,4)]=12;w.bid[World.cell(5,4)]=25
    World.rebuild(w);return w
end
local function until_true(w,predicate,limit)
    for i=1,limit or 1000 do if predicate() then return true end;World.update(w,50) end
    return predicate()
end
local function authorize(w,kind,x,y)
    local s=World.snapshot(w);expect(World.zone(w,kind,x,y),'authorization accepted');World.record(w,s)
end
local function contains(w,id)
    for i=1,#w.people do if w.people[i].id==id then return true end end
    return false
end
local w=fixture();local initial=w.cash
local gesture=World.snapshot(w)
expect(World.zone(w,1,18,4),'zone paint changes authorization')
expect(#w.jobs==0 and w.cash==initial,'unconfirmed authorization cannot reserve money or spawn a worker')
expect(World.restore(w,gesture) and w.zones[World.cell(18,4)]==0,'cancel unconfirmed zone gesture')
authorize(w,1,18,4)
local paused=World.encode(w);World.update(w,0)
expect(World.encode(w)==paused,'zero elapsed time does not advance life')
World.update(w,500)
expect(#w.jobs==1 and #w.people==1,'authorized lot assigns one real household worker')
local j=w.jobs[1];local p=w.people[1]
expect(p.home==World.cell(2,4) and p.interaction and p.interaction.target==p.home and p.state=='exit','worker begins inside its own authored household doorway')
expect(j.stage=='reserved' and j.progress==0 and j.escrow==90 and w.cash==initial-90,'money reserved before work without instant construction')
expect(not World.valid(w,11,18,4,0),'reserved footprint excludes direct construction')
expect(until_true(w,function() return not p.interaction and p.next_cell~=0 end),'worker exits the doorway and porch before beginning road travel')
local revision=w.revision;local px,py=p.x,p.y
World.update(w,100)
expect(math.abs(p.x-px)+math.abs(p.y-py)<=.250001 and p.x>px,'movement respects elapsed time and route direction')
expect(w.revision==revision,'actor motion does not rebuild static world')
expect(until_true(w,function() return j.work_ms>=1000 end),'worker physically arrives and starts foundation')
expect(j.stage=='foundation' and j.spent>0 and j.escrow+j.spent==90,'work consumes reserved resources once')
local stance=p.interaction.points[p.interaction.stand]
expect(p.state=='work' and p.x==stance.x and p.y==stance.y and p.z==stance.z and p.facing==p.interaction.facing,'construction advances only while the worker occupies and faces the authored contact stance')
expect(math.abs(p.x-(p.cell-1)%24)+math.abs(p.y-math.floor((p.cell-1)/24))>.1,'worker steps off the road center before performing construction')
local erase_gesture=World.snapshot(w);local before_erase=World.encode(w)
expect(World.zone(w,0,18,4),'unconfirmed erasure changes authorization')
expect(#w.jobs==1 and w.jobs[1]==j and w.cash==erase_gesture.cash and not World.take_event(w),'unconfirmed erasure cannot refund, remove work, or leak cancellation events')
expect(World.restore(w,erase_gesture) and World.encode(w)==before_erase and not World.take_event(w),'escape rolls back active-lot erasure without touching life or escrow')
local frozen=World.encode(w)
local resume=World.decode(frozen)
expect(resume~=nil and World.encode(resume)==frozen,'work-in-progress save roundtrip preserves all persistent state')
expect(resume.people[1].x==p.x and resume.people[1].y==p.y and resume.jobs[1].work_ms==j.work_ms,'resumed worker position and completed work do not reset')
local invalid=World.decode(frozen);invalid.jobs[1].escrow=invalid.jobs[1].escrow+1
expect(World.decode(World.encode(invalid))==nil,'save cannot manufacture refundable escrow')
invalid=World.decode(frozen);invalid.people[1].x=invalid.people[1].x+2
expect(World.decode(World.encode(invalid))==nil,'save rejects inconsistent actor position and route edge')
invalid=World.decode(frozen);invalid.jobs[2]=invalid.jobs[1]
expect(World.decode(World.encode(invalid))==nil,'save rejects duplicate and overlapping work sites')
local cash,spent,time=w.cash,j.spent,w.life_time
expect(World.undo(w),'zone undo remains available after autonomous work')
expect(#w.jobs==0 and w.bid[World.cell(18,4)]==0 and w.cash==initial-spent,'zone undo refunds only unused escrow')
expect(w.life_time==time and w.people[1].phase==2,'zone undo preserves time and sends worker home')
expect(not World.cancel_job(w,j.id) and w.cash==initial-spent,'repeated cancellation cannot duplicate refunds')
World.update(w,500)
expect(#w.jobs==0,'undo authorization prevents rescheduling canceled lot')
local ev=World.take_event(w)
expect(ev and ev.kind=='canceled' and ev.x==18 and not World.take_event(w),'cancellation emits one transition event')
expect(until_true(w,function() return not contains(w,p.id) end),'canceled worker walks home and leaves')
expect(until_true(resume,function() return resume.bid[World.cell(18,4)]==11 end),'resumed worker finishes actual construction')
expect(resume.cash==initial-90 and #resume.jobs==0,'completion consumes exact price and releases live job')
expect(until_true(resume,function() return not contains(resume,p.id) end),'completed worker returns to original household')
local completed=World.take_event(resume)
expect(completed and completed.kind=='completed' and completed.building_id==11,'completion event identifies built structure')
local normal=fixture();authorize(normal,1,18,4)
local twin=World.decode(World.encode(normal))
for i=1,700 do World.update(normal,50);World.update(twin,17);World.update(twin,33) end
expect(World.encode(normal)==World.encode(twin),'elapsed time partition does not change deterministic completion')
local build=fixture();expect(World.build(build,1,1,1,0),'direct infrastructure remains available')
World.zone(build,1,18,4);World.update(build,500)
local before_undo=World.encode(build)
expect(not World.undo(build) and World.encode(build)==before_undo,'stale terrain transaction cannot erase autonomous jobs or resources')
local erased=fixture();authorize(erased,1,18,4)
expect(until_true(erased,function() return erased.bid[World.cell(18,4)]==11 end),'construction completes before authorization undo')
local completed_cash=erased.cash;local completed_time=erased.life_time
expect(World.undo(erased) and erased.bid[World.cell(18,4)]==11 and erased.cash==completed_cash and erased.life_time==completed_time,'undo authorization preserves completed unrelated world state')
local poor=fixture();poor.cash=20;World.zone(poor,1,18,4);World.update(poor,500)
expect(#poor.jobs==0 and poor.zone_status[World.cell(18,4)]=='resources' and poor.cash==20 and #poor.people==0,'insufficient resources wait without debt or consuming a live slot')
poor.cash=200;World.update(poor,500)
expect(poor.jobs[1].funded and #poor.people==1 and poor.cash==110,'funding recovery resumes reserved lot')
local homeless=fixture();homeless.bid[World.cell(2,4)]=0;World.rebuild(homeless)
World.zone(homeless,1,18,4);World.update(homeless,500)
expect(homeless.jobs[1].status=='worker' and #homeless.people==0,'no housing means no fake worker')
homeless.bid[World.cell(2,4)]=12;World.rebuild(homeless);World.update(homeless,500)
expect(#homeless.people==1,'restored accessible housing supplies worker')
local service=fixture();World.zone(service,3,18,4);World.update(service,500)
expect(#service.jobs==0 and service.zone_status[World.cell(18,4)]=='footprint','service requires exact fully authorized footprint')
World.zone(service,3,19,4);World.update(service,500)
expect(#service.jobs==1 and service.jobs[1].building_id==30 and service.reserved[World.cell(19,4)]==service.jobs[1].id,'clinic reserves every footprint cell')
expect(not World.valid(service,11,19,4,0),'secondary footprint cells cannot be overwritten')
expect(until_true(service,function() return service.bid[World.cell(18,4)]==30 end) and service.health==100,'completed clinic provides actual service capacity')
local access=fixture();World.zone(access,1,18,4);World.update(access,500)
expect(until_true(access,function() return access.jobs[1].work_ms>500 end),'access interruption fixture reaches work')
local held=access.jobs[1].work_ms
expect(World.remove(access,18,5),'destination access can be removed')
World.update(access,1500)
expect(access.jobs[1].status=='access' and access.jobs[1].work_ms==held,'removed site access pauses existing work')
expect(World.build(access,3,18,5,0),'destination access can be restored')
expect(until_true(access,function() return access.bid[World.cell(18,4)]==11 end),'restored site access resumes original work')
local terrain=fixture();World.zone(terrain,3,18,4);World.zone(terrain,3,19,4);World.update(terrain,500)
expect(until_true(terrain,function() return terrain.jobs[1].work_ms>500 end),'terrain interruption fixture reaches work')
local reference=World.snapshot(terrain);local work=terrain.jobs[1].work_ms
expect(not World.terraform(terrain,'raise',18,4,0,reference,0,0),'terrain cannot move the slab or exit corridor supporting a working person')
expect(World.terraform(terrain,'raise',20,3,0,reference,0,0),'unoccupied far corner of the clinic can change independently of its worker stance')
World.update(terrain,1000)
expect(terrain.jobs[1].status=='terrain' and terrain.jobs[1].work_ms==work,'invalid changed terrain pauses work without discarding progress')
expect(World.restore(terrain,reference),'terrain gesture can restore unchanged simulation resources')
expect(until_true(terrain,function() return terrain.bid[World.cell(18,4)]==30 end),'restored terrain resumes construction')
local bridge=fixture()
for y=0,24 do for x=10,13 do bridge.h[y*25+x+1]=0 end end
for x=9,13 do bridge.bid[World.cell(x,5)]=0 end
World.rebuild(bridge);World.zone(bridge,1,18,4);World.update(bridge,500)
expect(bridge.jobs[1].status=='route' and #bridge.people==0,'disconnected islands do not spawn a worker at destination')
for x=9,13 do expect(World.build(bridge,5,x,5,0),'bridge spans water with valid deck') end
World.update(bridge,500)
expect(#bridge.people==1,'connected bridge permits real household route')
expect(until_true(bridge,function() return #bridge.people>0 and bridge.people[1].x>10 and bridge.people[1].x<12 end),'worker walks across bridge rather than teleporting')
local traveler=bridge.people[1];local crossing=World.decode(World.encode(bridge))
expect(crossing and crossing.people[1].x==traveler.x and crossing.people[1].edge_progress==traveler.edge_progress,'mid-edge crossing persists without snapping to tile center')
local removed=traveler.next_cell~=0 and traveler.next_cell or traveler.cell
local before_removal=World.encode(bridge)
expect(not World.remove(bridge,(removed-1)%24,math.floor((removed-1)/24)) and World.encode(bridge)==before_removal,'occupied bridge cannot disappear beneath a crossing person')
expect(World.remove(bridge,13,5),'unoccupied bridge segment ahead can be removed')
World.update(bridge,2500)
expect(traveler.x<13 and bridge.jobs[1].work_ms==0,'worker reaches safe shoreward stopping point without water crossing or invisible completion')
expect(World.build(bridge,5,13,5,0),'missing bridge segment ahead can be restored')
expect(until_true(bridge,function() return bridge.bid[World.cell(18,4)]==11 end),'restored bridge recovers waiting worker and construction')
local ramp=fixture()
for y=0,24 do for x=10,24 do ramp.h[y*25+x+1]=2 end end
World.rebuild(ramp);World.zone(ramp,1,18,4);World.update(ramp,500)
expect(#ramp.people==1,'straight road ramp connects elevations')
expect(until_true(ramp,function() return ramp.people[1] and ramp.people[1].x>9 and ramp.people[1].x<10 end),'worker reaches elevation transition')
expect(ramp.people[1].z>16 and ramp.people[1].z<32,'ramp interpolates actual world height')
local demand=fixture();World.zone(demand,2,18,4);World.update(demand,500)
expect(demand.jobs[1].building_id==17 and demand.jobs[1].funded,'commercial zone responds to household demand')
expect(until_true(demand,function() return demand.bid[World.cell(18,4)]==17 end),'commercial worker cycle finishes')
World.zone(demand,2,19,4);World.update(demand,500)
expect(#demand.jobs==0 and demand.zone_status[World.cell(19,4)]=='demand','excess commerce waits without consuming a live slot')
expect(until_true(demand,function() for i=1,#demand.people do if demand.people[i].role=='resident' then return true end end;return false end),'completed worker cycle enables purposeful resident shopping trip')
local trip=fixture()
for k=1,625 do trip.h[k]=2 end
for k=1,576 do trip.bid[k]=0;trip.rot[k]=0 end
for x=7,16 do trip.bid[World.cell(x,12)]=3 end
trip.bid[World.cell(7,11)]=11;trip.bid[World.cell(11,11)]=17;trip.bid[World.cell(14,13)]=25
World.rebuild(trip);local trip_cash=trip.cash
authorize(trip,1,11,13)
expect(until_true(trip,function() return #trip.jobs==1 and trip.jobs[1].work_ms>=1000 end),'resident save fixture reaches real funded construction')
expect(until_true(trip,function() return trip.completed_lots==1 end),'resident save fixture completes its first house')
local trip_actor
expect(until_true(trip,function()
    for i=1,#trip.people do
        local actor=trip.people[i]
        if actor.role=='resident' and actor.phase==1 and not actor.interaction and actor.next_cell~=0 and actor.destination~=actor.home then trip_actor=actor;return true end
    end
    return false
end),'completed construction enables a resident to walk a real route to a compatible destination')
World.update(trip,5)
local trip_save=World.encode(trip)
local trip_resume=World.decode(trip_save)
expect(trip_resume and World.encode(trip_resume)==trip_save,'first completion and mid-edge resident trip survive a complete save roundtrip')
expect(trip_resume.completed_lots==1 and #trip_resume.jobs==0 and trip_resume.cash==trip_cash-90 and trip_resume.bid[324]==11,'resident reload retains the completed house and exact construction expense')
local trip_person
for i=1,#trip_resume.people do if trip_resume.people[i].id==trip_actor.id then trip_person=trip_resume.people[i] end end
expect(trip_person and trip_person.home==trip_actor.home and trip_person.destination==trip_actor.destination and trip_person.x==trip_actor.x and trip_person.y==trip_actor.y and trip_person.appearance==trip_actor.appearance and trip_resume.life_step==5,'resident reload retains origin, destination, continuous position, appearance and fractional simulation time')
expect(World.decode(trip_save:sub(1,4095))==nil,'native-size truncated save remains invalid rather than dropping simulation and people')
expect(until_true(trip_resume,function() return trip_person.phase==4 end),'reloaded resident reaches the shopping destination')
expect(until_true(trip_resume,function()
    for i=1,#trip_resume.people do if trip_resume.people[i].id==trip_person.id then return false end end
    return true
end),'reloaded resident completes the return journey without losing the completed house')
expect(trip_resume.bid[324]==11 and trip_resume.cash==trip_cash-90 and #trip_resume.jobs==0,'resumed resident travel cannot rebuild the house or charge construction twice')
local bounded=fixture()
bounded.bid[World.cell(8,4)]=17;bounded.bid[World.cell(9,4)]=17;World.rebuild(bounded)
for x=10,20 do World.zone(bounded,1,x,4) end
World.update(bounded,1000)
expect(#bounded.jobs==4 and #bounded.people<=32,'authorized area respects live job and actor bounds')
local blocked=fixture()
blocked.bid[World.cell(2,6)]=12;World.rebuild(blocked)
for x=10,16 do World.zone(blocked,1,x,4) end
World.zone(blocked,2,18,4);World.zone(blocked,3,19,4);World.zone(blocked,3,20,4)
World.update(blocked,500)
local commerce,clinic=false,false
for i=1,#blocked.jobs do commerce=commerce or blocked.jobs[i].building_id==17;clinic=clinic or blocked.jobs[i].building_id==30 end
expect(commerce and clinic and #blocked.jobs<=4,'housing demand waits cannot block shop and service lots that resolve city needs')
local rehoused=fixture();World.zone(rehoused,1,18,4);World.update(rehoused,500)
local walker=rehoused.people[1]
expect(World.remove(rehoused,2,4),'origin housing may be removed after departure')
expect(World.cancel_job(rehoused,rehoused.jobs[1].id),'canceled worker returns after origin disappears')
World.update(rehoused,1500)
expect(#rehoused.people==1 and walker.state=='wait' and walker.wait_reason=='home','homeless return waits explicitly instead of disappearing')
expect(World.build(rehoused,11,8,4,0),'new accessible household can be built elsewhere')
expect(until_true(rehoused,function() return walker.home==World.cell(8,4) end),'returning worker finds a real route to replacement housing')
expect(until_true(rehoused,function() return not contains(rehoused,walker.id) end),'rehoused worker walks to new entrance before disappearing')
local occupied=fixture();World.remove(occupied,4,5);World.zone(occupied,1,18,4);World.update(occupied,500)
expect(until_true(occupied,function() return occupied.people[1].x>3 and occupied.people[1].x<4 end),'worker crosses unpaved dry land')
local occupied_person=occupied.people[1];local actorx=occupied_person.x
World.zone(occupied,1,4,5);World.update(occupied,500)
expect(not occupied.reserved[World.cell(4,5)] and occupied.zone_status[World.cell(4,5)]=='occupied','lot reservation waits for in-flight pedestrian instead of blocking their edge')
expect(occupied_person.x>actorx,'pedestrian continues physically through deferred reservation')
local deck=fixture()
deck.bid[World.cell(10,10)]=6
deck.h[12*25+12+1]=2
World.rebuild(deck)
local deck_nav=Paths.refresh(deck)
expect(deck_nav.height[World.cell(10,10)]==World.elevation(deck,6,10,10,0)*16 and deck_nav.height[World.cell(11,11)]==32,'multi-cell bridge uses maximum footprint deck height at every cell')
local corrupt=World.encode(normal)
expect(World.decode(corrupt..',0')==nil and World.decode((corrupt:gsub(',',',,',1)))==nil,'corrupt trailing and missing fields are rejected')
local door=fixture()
door.bid[World.cell(5,4)]=17;door.next_person_id=2;World.rebuild(door)
local visitor
expect(until_true(door,function()
    for i=1,#door.people do local actor=door.people[i];if actor.role=='resident' and actor.destination==World.cell(5,4) then visitor=actor;return true end end
    return false
end),'resident visits a directly built shop before any zone construction')
expect(until_true(door,function() return visitor.state=='enter' end),'resident reaches the porch, acts on its door and begins entering')
local entering=World.encode(door);local entering_resume=World.decode(entering)
expect(entering_resume and World.encode(entering_resume)==entering,'doorway traversal reloads at its exact local position instead of the road cell')
local entered,continuous=false,true
for step=1,500 do
    local x,y=visitor.x,visitor.y
    World.update(door,10)
    continuous=continuous and math.abs(visitor.x-x)+math.abs(visitor.y-y)<=.035356
    if not visitor.visible then
        local interior=visitor.interaction.points[#visitor.interaction.points]
        entered=visitor.state=='interior' and visitor.x==interior.x and visitor.y==interior.y and visitor.z==interior.z and visitor.y<visitor.interaction.contact_y
        break
    end
end
expect(continuous,'door entry remains continuous at pedestrian speed')
expect(entered,'resident is hidden only after crossing the actual doorway threshold into the authored interior')
local interior_save=World.encode(door);World.update(door,0)
expect(World.encode(door)==interior_save,'paused interior activity preserves position, visibility and elapsed action')
local appearance=visitor.appearance;local cursor=visitor.local_cursor
expect(World.remove(door,5,4),'visited building can be demolished during an interior stay')
World.update(door,10)
expect(contains(door,visitor.id) and visitor.visible and visitor.state=='exit' and visitor.local_cursor<cursor and visitor.appearance==appearance,'removed destination interrupts the stay and visibly retraces the doorway without teleporting or replacing the person')
local retreat=World.encode(door);local retreat_resume=World.decode(retreat)
expect(retreat_resume and World.encode(retreat_resume)==retreat,'removed-building egress retains its original physical corridor across reload')
expect(until_true(door,function() return visitor.phase==3 and not visitor.visible end),'interrupted visitor walks home and crosses its original household threshold')
expect(until_true(door,function() return not contains(door,visitor.id) end),'returned resident retires only after arriving inside a real home')
local moving=fixture();moving.bid[World.cell(16,4)]=17;moving.next_person_id=2;World.rebuild(moving)
local pedestrian
expect(until_true(moving,function()
    for i=1,#moving.people do
        local actor=moving.people[i]
        if actor.role=='resident' and actor.next_cell~=0 then pedestrian=actor;return true end
    end
    return false
end),'directly built households supply pedestrians without a zoning milestone')
local distant=World.snapshot(moving)
expect(World.terraform(moving,'raise',20,20,0,distant,0,0),'distant terrain remains editable during a resident trip')
World.record(moving,distant);World.update(moving,50)
local px,py,pz,clock=pedestrian.x,pedestrian.y,pedestrian.z,moving.life_time
expect(World.undo(moving) and moving.base[World.cell(20,20)]==1 and moving.mask[World.cell(20,20)]==0,'pedestrian motion does not invalidate unrelated terrain undo')
expect(pedestrian.x==px and pedestrian.y==py and pedestrian.z==pz and moving.life_time==clock,'terrain undo preserves the current pedestrian position and simulation time')
local occupied_save=World.encode(moving)
expect(not World.terraform(moving,'raise',math.floor(px+.5),math.floor(py+.5),0,World.snapshot(moving),0,0) and World.encode(moving)==occupied_save,'terrain cannot lift the road underneath a moving resident')
local leveling=World.snapshot(moving);local stroke={target=2}
expect(not World.terraform(moving,'level',math.floor(px+.5),math.floor(py+.5),0,leveling,0,0,stroke),'leveling skips the occupied part of a stroke')
expect(World.terraform(moving,'level',20,20,0,leveling,0,0,stroke) and moving.h[20*25+21]==2,'a refused brush location does not block later safe locations in the same stroke')
local choreography=fixture();World.zone(choreography,1,18,4)
expect(until_true(choreography,function() return choreography.people[1] and choreography.people[1].local_shift end),'first foundation stage creates a short same-lot footing adjustment')
local shuffling=choreography.people[1];local shuffle_work=choreography.jobs[1].work_ms
local shuffle_x,shuffle_y,shuffle_z=shuffling.x,shuffling.y,shuffling.z
local shuffle_resume=World.decode(World.encode(choreography))
expect(shuffle_resume and shuffle_resume.people[1].z==shuffle_z,'mid-step foundation save retains the current elevation rather than snapping to either support')
World.update(choreography,10);World.update(shuffle_resume,10)
expect(choreography.jobs[1].work_ms==shuffle_work and shuffling.z>shuffle_z and math.abs(shuffling.x-shuffle_x)+math.abs(shuffling.y-shuffle_y)<.04,'foundation footing rises continuously without a road detour or work credited during movement')
expect(World.encode(shuffle_resume)==World.encode(choreography),'reloading a stage-height adjustment preserves its physical motion and future progress')
local gestures={}
expect(until_true(choreography,function()
    for i=1,#choreography.people do
        local actor=choreography.people[i]
        if actor.state=='work' then gestures[actor.action]=true end
    end
    return choreography.jobs[1] and choreography.jobs[1].work_ms==12000
end),'complete construction choreography finishes all funded work')
for _,id in ipairs({'survey','mark','mix_mortar','stack_bricks','lay_bricks','carry_timber','saw','hammer','paint','inspect_work'}) do
    expect(gestures[id],'construction physically performs its '..id..' stage')
end
expect(choreography.bid[World.cell(18,4)]==0 and shuffling.visible and shuffling.interaction,'finished walls wait until the worker has physically cleared the construction footprint')
local handover=World.decode(World.encode(choreography))
expect(handover and handover.jobs[1].work_ms==12000 and handover.jobs[1].escrow==0 and handover.bid[World.cell(18,4)]==0,'fully spent work awaiting safe handover survives reload without a refund or premature building')
for step=1,1000 do
    if choreography.bid[World.cell(18,4)]==11 then break end
    World.update(choreography,10);World.update(handover,10)
end
expect(choreography.bid[World.cell(18,4)]==11 and not shuffling.interaction and shuffling.x==(shuffling.cell-1)%24 and shuffling.y==math.floor((shuffling.cell-1)/24),'construction replaces the scaffold only after its worker reaches the actual road exit')
expect(World.encode(handover)==World.encode(choreography),'safe handover resumes deterministically without duplicate construction or expenditure')
local legacy=World.decode(life_legacy_save)
expect(legacy and legacy.life_time==60090 and legacy.completed_lots==1 and #legacy.jobs==0 and #legacy.people==1,'legacy completion save migrates without dropping its construction outcome or traveler')
local old_actor=legacy.people[1];local legacy_cash=legacy.cash;local legacy_x,legacy_y=old_actor.x,old_actor.y
local migrated=World.decode(World.encode(legacy))
expect(migrated and migrated.cash==legacy_cash and migrated.people[1].x==legacy_x and migrated.people[1].y==legacy_y and migrated.people[1].visible,'legacy traveler receives appearance and activity state without hidden relocation or economy changes')
local old_tokens={};for token in life_legacy_save:gmatch('[^,]+') do old_tokens[#old_tokens+1]=token end
local jobs_at=6+625+576*3+10;local x_at=jobs_at+13*tonumber(old_tokens[jobs_at])+4
old_tokens[x_at]=tostring(tonumber(old_tokens[x_at])+2)
expect(World.decode(table.concat(old_tokens,','))==nil,'legacy coordinates are validated against their actual walking edge before migration')
print('PASS life domain: '..checks..' assertions.')
end
