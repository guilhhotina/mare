local checks=0
local function check(ok,msg) checks=checks+1;assert(ok,msg) end
local function empty()
    local w=World.new(2706,true)
    for i=1,625 do w.h[i]=2 end
    for i=1,576 do w.bid[i]=0;w.rot[i]=0 end
    World.rebuild(w);return w
end
local function validate(w,s)
    for i=1,576 do
        check(w.top[i]-w.base[i]<=1,'adjacent heights remain bounded')
        check(w.bid[i]==s.bid[i] and w.rot[i]==s.rot[i],'pieces and orientation preserved')
        local id=w.bid[i]
        if id>0 then
            local x,y=(i-1)%24,math.floor((i-1)/24)
            if id<=3 or id==7 then
                local m=w.mask[i];check(m==0 or m==3 or m==6 or m==9 or m==12,'usable automatic road ramp')
            elseif id~=5 and id~=6 then
                local nx,ny=World.footprint(id,w.rot[i]);local h=w.base[i]
                check(h>=1,'dry foundation at sea level')
                for v=0,ny-1 do for u=0,nx-1 do
                    local k=World.cell(x+u,y+v);check(w.base[k]==h and w.mask[k]==0,'rigid flat foundation')
                end end
            end
        end
    end
    check(w.cash==s.cash,'terrain never charges or refunds buildings')
    check(World.decode(World.encode(w))~=nil,'edited save remains valid')
end

local w=empty();check(World.build(w,12,8,8,0),'garden house fixture')
for x=5,14 do check(World.build(w,3,x,9,0),'street fixture') end
check(World.elevation(w,6,23,23,0)==2,'invalid bridge preview at map edge stays renderable')
local s=World.snapshot(w);check(World.terraform(w,'raise',8,8,1,s,0,0),'raise occupied land')
check(w.base[World.cell(8,8)]==3,'house rises exactly one level');validate(w,s)
local ramps=0;for x=5,14 do if w.mask[World.cell(x,9)]~=0 then ramps=ramps+1 end end
check(ramps>0,'street receives transition ramps')
for i=1,625 do check(w.h[i]>=s.h[i],'raising never lowers other ground') end
World.restore(w,s);check(World.terraform(w,'lower',8,8,1,s,0,0),'lower occupied land')
check(w.base[World.cell(8,8)]==1,'house descends exactly one level');validate(w,s)
for i=1,625 do check(w.h[i]<=s.h[i],'lowering never raises other ground') end
World.restore(w,s);World.record(w,s);World.terraform(w,'raise',8,8,1,s,0,0);World.undo(w)
check(World.encode(w)==World.encode(World.decode(World.encode(w))),'undo round trip')
for i=1,625 do check(w.h[i]==s.h[i],'undo restores every height') end

for id=1,40 do for rotation=0,3 do
    local q=empty();q.bid[World.cell(8,8)]=id;q.rot[World.cell(8,8)]=rotation;World.rebuild(q)
    local before=World.snapshot(q)
    check(World.terraform(q,'raise',8,8,1,before,0,0),'raise catalog footprint');validate(q,before)
    if id==5 or id==6 then check(World.elevation(q,id,8,8,rotation)==3,'bridge deck follows raised land')
    else check(q.base[World.cell(8,8)]==3,'all structures rise') end
end end

local q=empty();local before=World.snapshot(q);local stroke={target=2}
World.terraform(q,'raise',5,5,1,before,0,0,stroke)
World.terraform(q,'raise',6,5,1,before,0,0,stroke)
World.terraform(q,'raise',5,5,1,before,0,0,stroke)
for i=1,625 do check(q.h[i]<=3,'overlap raises each vertex once') end
validate(q,before)

local raised=World.snapshot(q);local level={target=2}
World.terraform(q,'level',5,5,1,raised,0,0,level)
World.terraform(q,'level',6,5,1,raised,0,0,level)
check(q.h[5*25+5+1]==2 and q.h[5*25+6+1]==2,'level keeps captured height');validate(q,raised)
World.restore(q,raised);for i=1,625 do check(q.h[i]==raised.h[i],'stroke cancellation exact') end

local city=World.new(2706,true)
for j=1,40 do
    local ref=World.snapshot(city);local mode=({'raise','lower','level','pull'})[(j-1)%4+1]
    local x,y=(j*7)%24,(j*11)%24
    check(World.terraform(city,mode,x,y,j%3+1,ref,j%5-2,(j+1)%5-2),'mixed edit always resolves')
    validate(city,ref)
end
print('PASS adaptive terrain: moving foundations, automatic ramps, 160 footprints, bridges, captured height, overlapping strokes, mixed edits and exact restoration ('..checks..' checks).')
