local tests=0
local function check(value,msg) tests=tests+1;assert(value,msg) end
local w=World.new(2706,false)
check(w.population>0,'starter population')
check(w.power>w.need,'starter electricity')
check(w.balance>0,'starter economy')
local serialized=World.encode(w)
check(World.decode(serialized)~=nil,'generated world decodes')
check(World.encode(World.decode(serialized))==serialized,'save exact round trip')
check(World.decode('invalid')==nil,'invalid header rejected')
check(World.decode(serialized..',1')==nil,'invalid length rejected')
local before=World.snapshot(w)
local ok=World.terraform(w,'raise',3,14,2,before,0,0)
check(ok,'coast can be raised')
check(World.encode(w)~=serialized,'brush changes terrain')
check(World.decode(World.encode(w))~=nil,'edited terrain retains slope invariant')
World.restore(w,before)
check(World.encode(w)==serialized,'cancel gesture exact')
World.record(w,before)
World.terraform(w,'lower',4,14,1,before,0,0)
World.undo(w)
check(World.encode(w)==serialized,'undo exact')
local count=0
for id=1,40 do
 for r=0,3 do
  local ww=World.new(1234,true)

  for k=1,625 do ww.h[k]=1 end
  for k=1,576 do ww.bid[k]=0 end
  if id==9 or id==10 or id==37 then for y=0,24 do ww.h[y*25+5]=0 end end
  World.rebuild(ww)
  local x,y=5,5
  local good,msg=World.build(ww,id,x,y,r)
  check(good,'build '..id..' r'..r..': '..tostring(msg))
  local nx,ny=World.footprint(id,r)
  check(ww.occ[World.cell(x+nx-1,y+ny-1)]==World.cell(x,y),'footprint occupied '..id)
  check(not World.valid(ww,11,x,y,0),'overlap rejected '..id)
  check(not World.valid(ww,id,24,24,r),'bounds rejected '..id)
  check(World.decode(World.encode(ww))~=nil,'building save valid '..id)
  check(World.remove(ww,x+nx-1,y+ny-1),'remove via footprint '..id)
  check(ww.occ[World.cell(x,y)]==0,'all footprint cleared '..id)
  count=count+1
 end
end
local poor=World.new(1,false);poor.cash=0
check(not World.valid(poor,16,5,5,0),'unaffordable blocked')
local sandbox=World.new(1,true);sandbox.cash=0
for k=1,625 do sandbox.h[k]=2 end
for k=1,576 do sandbox.bid[k]=0 end
World.rebuild(sandbox)
check(World.build(sandbox,16,5,5,0),'sandbox unlimited')
local saved=World.encode(sandbox)
local corrupt=saved:gsub('^MARE%d+','MARE999',1)
check(World.decode(corrupt)==nil,'save version rejected')
print('PASS '..tests..' assertions; '..count..' building/rotation combinations; save, terrain, undo, economy.')

local p=World.new(2706,false)
for k=1,625 do p.h[k]=2 end
for k=1,576 do p.bid[k]=0 end
World.rebuild(p)
local cash=p.cash
check(World.build(p,11,8,8,0),'paid construction')
World.tick(p);local earned=p.balance
World.undo(p)
check(p.cash==cash+earned,'undo keeps revenue earned after construction')
local snapshot=World.snapshot(p)
check(World.paint(p,3,4,4),'paint start')
check(World.paint(p,3,5,4),'paint continuation')
check(p.cash==snapshot.cash-50,'paint exact cost')
World.restore(p,snapshot)
check(p.cash==snapshot.cash and p.bid[World.cell(5,4)]==0,'cancel entire painted road')
local terrain=World.new(2706,true)
local original=World.snapshot(terrain)
local encoded=World.encode(terrain)
World.terraform(terrain,'pull',3,14,2,original,2,0)
check(World.decode(World.encode(terrain))~=nil,'distortion remains valid')
World.restore(terrain,original)
check(World.encode(terrain)==encoded,'distortion cancel exact')
for seed=1,50 do check(World.decode(World.encode(World.new(seed,true)))~=nil,'seed slope invariant '..seed) end
for goal=1,5 do
 p.population=120;p.power=100;p.need=50;p.parks=5;p.shops=3;p.animals=6;p.health=100;p.happy=90;p.reward=goal-1
 check(World.goal_ready(p),'goal reachable '..goal)
 local before=p.cash;check(World.claim(p),'goal claim '..goal)
 check(p.reward==goal and p.cash==before+World.goals[goal][3],'goal exact reward '..goal)
end
check(not World.claim(p),'completed journey gives no repeated rewards')
local legacy=World.decode(legacy_save)
check(legacy~=nil and legacy.population==8,'Original v0.1 world loads with original residents')
local migrated=World.decode(World.encode(legacy))
check(migrated~=nil and migrated.cash==legacy.cash and migrated.day==legacy.day,'Migration preserves economy')
for k=1,625 do check(migrated.h[k]==legacy.h[k],'Migration preserves terrain') end
for k=1,576 do check(migrated.bid[k]==legacy.bid[k] and migrated.rot[k]==legacy.rot[k] and migrated.zones[k]==0,'Migration preserves buildings without inventing authorization') end
local road=World.new(87,false)
for i=1,625 do road.h[i]=1 end
for i=1,576 do road.bid[i]=0;road.deco[i]=0 end
road.cash=1000;World.rebuild(road)
check(World.build(road,1,4,4,0),'Build a dirt path')
check(World.price(road,3,4,4)==17,'Only the upgrade price difference is charged')
check(World.build(road,3,4,4,0) and road.cash==975,'Upgrade directly without demolishing')
local undo_count=#road.undo
check(not World.build(road,3,4,4,0) and #road.undo==undo_count,'Identical road is a no-op')
check(World.undo(road) and road.bid[World.cell(4,4)]==1 and road.cash==992,'Undo restores previous paving and exact cost')
check(World.paint(road,3,4,4) and road.cash==975,'Road dragging can upgrade a path')
check(World.build(road,1,4,4,0) and road.cash==975,'Changing to cheaper paving costs zero without manufacturing coins')
print('PASS final total: '..tests..' assertions.')
