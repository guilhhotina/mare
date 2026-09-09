local S={}
local floor,abs=math.floor,math.abs
local states={'travel','wait','dock','exit'}
local function code(values,value) for i=1,#values do if values[i]==value then return i end end;return 0 end
function S.install(W,Traffic,Nav,P)
    local old_encode,old_decode=W.encode,W.decode
    function W.encode(w)
        local out={};local n=W.traffic_navigation(w);local s=w.traffic_state
        local function put(...) for i=1,select('#',...) do out[#out+1]=string.format('%.17g',select(i,...)) end end
        local function path(p,index,previous)
            if not p then out[#out+1]='n';return end
            local encoded={'p'}
            for i=index,#p do
                local k=p[i];local ax,ay=(previous-1)%24,floor((previous-1)/24);local bx,by=(k-1)%24,floor((k-1)/24);local direction='?'
                for d=1,8 do if Nav.dx[d]==bx-ax and Nav.dy[d]==by-ay then direction=string.char(47+d);break end end
                encoded[#encoded+1]=direction;previous=k
            end
            out[#out+1]=table.concat(encoded)
        end
        put(w.life_epoch,#w.people)
        for i=1,#w.people do local p=w.people[i]
            put(p.path_revision==w.revision and p.path_lots==w.lot_revision and 1 or 0,p.wait_reason=='route' and 1 or p.wait_reason=='home' and 2 or 0,p.home_route_failed and 1 or 0)
            path(p.path,p.path_index,p.next_cell~=0 and p.next_cell or p.cell)
        end
        put(s.rng,s.time,s.step,s.plan_clock,s.next_id,s.cursor,s.spawn_cursor,s.car_due,s.boat_due,s.fish_due,s.dolphin_due,s.whale_due,#w.traffic)
        for i=1,#w.traffic do local e=w.traffic[i]
            put(e.id,code(Traffic.kinds,e.kind),e.home,e.destination,e.phase,e.cell,e.next_cell,e.progress,e.heading,e.incoming,e.facing,e.x,e.y,e.z,code(states,e.state),e.wait,e.waited_cell,e.age,e.duration,e.animation_time,e.exit_progress,e.retry,e.blocked,e.goal,e.path_generation==n.generation and 1 or 0)
            path(e.path,e.path_index,e.next_cell~=0 and e.next_cell or e.cell)
        end
        return (old_encode(w):gsub('^MARE5','MARE6'))..'|TRAFFIC2,'..table.concat(out,',')
    end
    function W.decode(text)
        if type(text)~='string' or #text>100000 then return nil end
        if text:sub(1,6)=='MARE2,' or text:sub(1,6)=='MARE3,' or text:sub(1,6)=='MARE5,' then
            local w=old_decode(text);return w and Traffic.init(w) or nil
        end
        local version=text:sub(1,6)
        if version~='MARE4,' and version~='MARE6,' or text:find(',,',1,true) or text:sub(-1)==',' then return nil end
        local split,last,traffic_version=text:find('|TRAFFIC([12]),');if not split then return nil end
        local body=text:sub(last+1);if body:find('|',1,true) then return nil end
        local w=old_decode((version=='MARE4,' and 'MARE3' or 'MARE5')..text:sub(6,split-1));if not w then return nil end
        Traffic.init(w)
        local raw={};for token in body:gmatch('[^,]+') do raw[#raw+1]=token end
        local cursor,failed=1,false
        local function get(lo,hi,integer)
            local value=tonumber(raw[cursor]);cursor=cursor+1
            if not value or value~=value or value<lo or value>hi or integer and value~=floor(value) then failed=true;return lo end
            return value
        end
        local function path(previous)
            local token=raw[cursor];cursor=cursor+1
            if token=='n' then return nil end
            if not token or token:sub(1,1)~='p' or #token>577 then failed=true;return nil end
            local p={}
            for i=2,#token do
                local direction=token:byte(i)-47
                if direction<1 or direction>8 then failed=true;return nil end
                local x,y=(previous-1)%24+Nav.dx[direction],floor((previous-1)/24)+Nav.dy[direction]
                if x<0 or y<0 or x>=24 or y>=24 then failed=true;return nil end
                previous=y*24+x+1;p[#p+1]=previous
            end
            return p
        end
        w.life_epoch=get(0,1e15,true)
        if get(0,32,true)~=#w.people then return nil end
        for i=1,#w.people do local p=w.people[i]
            local valid=get(0,1,true);local reason=get(0,2,true)
            p.wait_reason=reason==1 and 'route' or reason==2 and 'home' or nil;p.home_route_failed=get(0,1,true)==1 or nil
            p.path=path(p.next_cell~=0 and p.next_cell or p.cell);p.path_index=1;p.path_revision=valid==1 and w.revision or -1;p.path_lots=valid==1 and w.lot_revision or -1
            local previous=p.next_cell~=0 and p.next_cell or p.cell
            if p.path then for j=1,#p.path do
                local k=p.path[j];local ax,ay=(previous-1)%24,floor((previous-1)/24);local bx,by=(k-1)%24,floor((k-1)/24)
                if abs(ax-bx)+abs(ay-by)~=1 or valid==1 and not P.edge(w,previous,k) then return nil end
                previous=k
            end end
        end
        local s=w.traffic_state
        s.rng=get(1,2147483646,true);s.time=get(0,1e15,true);s.step=get(0,49,true);s.plan_clock=get(0,499,true);s.next_id=get(1,100000000,true);s.cursor=get(1,20,true);s.spawn_cursor=get(1,5,true)
        s.car_due=get(0,1e15,true);s.boat_due=get(0,1e15,true);s.fish_due=get(0,1e15,true);s.dolphin_due=get(0,1e15,true);s.whale_due=get(0,1e15,true)
        if s.time%50~=0 or s.step%10~=0 or s.plan_clock%50~=0 then return nil end
        local count=get(0,20,true);local ids,counts={},{};local n=W.traffic_navigation(w)
        for i=1,count do
            local id=get(1,s.next_id-1,true);local kind=Traffic.kinds[get(1,5,true)]
            if ids[id] then return nil end;ids[id]=true
            counts[kind]=(counts[kind] or 0)+1;if counts[kind]>Traffic.caps[kind] then return nil end
            local e={id=id,kind=kind,home=get(0,576,true),destination=get(0,576,true),phase=get(1,2,true),cell=get(1,576,true),next_cell=get(0,576,true),progress=get(0,1),heading=get(0,7,true),incoming=get(0,7,true),facing=get(0,7,true),x=get(-2,25),y=get(-2,25),z=get(0,80),state=states[get(1,4,true)],wait=get(0,2200,true),waited_cell=get(0,576,true),age=get(0,1e15,true),duration=get(0,24000,true),animation_time=get(0,120000,true),exit_progress=get(0,1.8),retry=get(0,1e15,true),blocked=get(0,1e15,true),goal=get(1,576,true),path_index=1}
            e.path_generation=get(0,1,true)==1 and n.generation or -1;e.path=path(e.next_cell~=0 and e.next_cell or e.cell)
            if e.progress==1 or e.animation_time==120000 or e.exit_progress==1.8 then return nil end
            if kind=='car' or kind=='boat' then
                if e.home==0 or e.duration~=0 or kind=='car' and (e.destination==0 or e.heading%2~=0 or e.incoming%2~=0) then return nil end
            elseif e.home~=0 or e.destination~=0 or e.duration==0 or e.age>=e.duration or e.phase~=1 or e.wait>0 or e.state=='dock' or e.state=='exit' then return nil end
            local duration=Traffic.surfacing_ms[kind]
            if duration then
                if traffic_version=='1' then e.age=floor(e.age*duration/e.duration);e.duration=duration
                elseif e.duration~=duration then return nil end
            end
            if kind~='car' and e.z~=0 then return nil end
            if e.next_cell~=0 then
                if not Nav.edge(n,kind,e.cell,e.next_cell) then return nil end
                local ax,ay=(e.cell-1)%24,floor((e.cell-1)/24);local bx,by=(e.next_cell-1)%24,floor((e.next_cell-1)/24)
                if Nav.dx[e.heading+1]~=bx-ax or Nav.dy[e.heading+1]~=by-ay then return nil end
            elseif e.progress~=0 then return nil end
            local x,y=(e.cell-1)%24,floor((e.cell-1)/24)
            if e.state=='exit' then
                if kind~='boat' or e.next_cell~=0 or e.phase~=1 or e.destination~=0 or e.wait~=0 or e.path or (x~=0 and y~=0 and x~=23 and y~=23) then return nil end
            elseif e.exit_progress~=0 then return nil end
            if e.state=='dock' and (e.next_cell~=0 or e.wait==0) then return nil end
            local px,py=Traffic.position(w,e)
            if abs(e.x-px)>1e-8 or abs(e.y-py)>1e-8 then return nil end
            if kind=='car' then if not n.pass.car[e.cell] then return nil end
            elseif not Nav.water(w,e.x,e.y,Nav.radius[kind]) then return nil end
            local previous=e.next_cell~=0 and e.next_cell or e.cell
            if e.path then for j=1,#e.path do
                local k=e.path[j];local ax,ay=(previous-1)%24,floor((previous-1)/24);local bx,by=(k-1)%24,floor((k-1)/24)
                if abs(ax-bx)>1 or abs(ay-by)>1 or ax==bx and ay==by or kind=='car' and abs(ax-bx)+abs(ay-by)~=1 or e.path_generation==n.generation and not Nav.edge(n,kind,previous,k) then return nil end
                previous=k
            end end
            Traffic.prepare(e);w.traffic[i]=e
        end
        if failed or cursor~=#raw+1 then return nil end
        return w
    end
end
return S
