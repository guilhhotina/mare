local T={}
local floor,min,max,abs=math.floor,math.min,math.max,math.abs
local kinds={'car','boat','fish','dolphin','whale'}
local caps={car=8,boat=4,fish=6,dolphin=1,whale=1}
local fish_swim_frames,fish_jump_frames=4,32
local fish_jump_rate=fish_jump_frames/1000
local frames={car=2,boat=4,fish=fish_swim_frames+fish_jump_frames,dolphin=48,whale=96}
local surfacing_ms={dolphin=1600,whale=3200}
local speed={car=.0014,boat=.00065,fish=.00038,dolphin=.0008,whale=.00048}
local sprites={}
for i=1,#kinds do local kind=kinds[i];sprites[kind]={}
    for d=0,7 do local row={};sprites[kind][d]=row
        for f=0,frames[kind]-1 do row[f]=(i<=2 and 'vehicle_' or 'fauna_')..kind..'_'..d..'_'..f end
    end
end
T.kinds=kinds;T.caps=caps;T.surfacing_ms=surfacing_ms
local function xy(k) return (k-1)%24,floor((k-1)/24) end
local function random(s,n) s.rng=(s.rng*48271)%2147483647;return s.rng%n end
local function count(w,kind) local n=0;for i=1,#w.traffic do if w.traffic[i].kind==kind then n=n+1 end end;return n end
local function facing(x,y)
    if abs(y)<abs(x)*.41421356237 then return x>0 and 0 or 4 end
    if abs(x)<abs(y)*.41421356237 then return y>0 and 2 or 6 end
    return x>0 and (y>0 and 1 or 7) or (y>0 and 3 or 5)
end
function T.remember_position(e)
    e.previous_x,e.previous_y,e.previous_z=e.x,e.y,e.z
end
function T.sprite(e,elapsed)
    if e.kind=='dolphin' or e.kind=='whale' then
        return sprites[e.kind][e.facing][min(frames[e.kind]-1,floor((e.age+elapsed)*e.frame_rate))]
    elseif e.kind=='fish' then
        local time=e.age+elapsed;local cycle=(time+e.animation_phase)%6000
        local jumping=cycle>=5000 and time<e.last_jump_end
        local frame=jumping and fish_swim_frames+floor((cycle-5000)*fish_jump_rate) or floor(time*e.frame_rate)%fish_swim_frames
        return sprites.fish[e.facing][frame]
    end
    return e.sprite
end
local function render(e)
    local surfacing=e.kind=='dolphin' or e.kind=='whale'
    if surfacing or e.kind=='fish' then e.sprite=T.sprite(e,0)
    else e.sprite=sprites[e.kind][e.facing][floor(e.animation_time*e.frame_rate)%frames[e.kind]] end
    e.visible=true
    e.still_sprite=surfacing and e.sprite or sprites[e.kind][e.facing][0]
end
function T.prepare(e)
    e.frame_rate=(e.kind=='dolphin' or e.kind=='whale') and frames[e.kind]/e.duration or e.kind=='car' and 1/130 or 1/180
    if e.kind=='fish' then
        e.animation_phase=e.id*911%5000
        e.last_jump_end=floor((e.duration+e.animation_phase)/6000)*6000-e.animation_phase
    end
    T.remember_position(e);render(e)
end
function T.init(w)
    local s={rng=w.seed%2147483646+1,time=0,step=0,plan_clock=0,next_id=1,cursor=1,spawn_cursor=1,car_due=3000,boat_due=7000,fish_due=2000}
    s.dolphin_due=45000+random(s,45001);s.whale_due=180000+random(s,180001)
    w.traffic={};w.traffic_state=s;w.traffic_navigation=nil;w.traffic_targets={}
    return w
end
function T.install(W,Catalog,P,Nav)
    W.traffic_caps=caps
    local function navigation(w) return Nav.refresh(w,W,P) end
    W.traffic_navigation=navigation
    local function clear(w,kind,x,y,heading,except)
        for i=1,#w.traffic do local q=w.traffic[i]
            if q~=except and (kind=='car')==(q.kind=='car') then
                local gap
                if kind=='car' then
                    local diff=abs(heading-q.facing)
                    gap=diff==0 and .76 or diff==4 and .36 or .59
                else gap=Nav.radius[kind]+Nav.radius[q.kind]+.12 end
                local dx,dy=x-q.x,y-q.y
                if dx*dx+dy*dy<gap*gap then return false end
            end
        end
        return true
    end
    local function positioned(w,n,e,progress)
        local ax,ay=xy(e.cell);local bx,by=xy(e.next_cell);local dx,dy=bx-ax,by-ay
        local x,y,fx,fy=ax+dx*progress,ay+dy*progress,dx,dy
        if e.kind=='car' then
            local ix,iy=Nav.dx[e.incoming+1],Nav.dy[e.incoming+1]
            if e.incoming~=e.heading and progress<.4 then
                local t=progress/.4;local u=1-t
                local sx,sy=ax-iy*.21,ay+ix*.21
                local ex,ey=ax+dx*.4-dy*.21,ay+dy*.4+dx*.21
                local cx,cy=sx+ix*.3,sy+iy*.3
                x=u*u*sx+2*u*t*cx+t*t*ex;y=u*u*sy+2*u*t*cy+t*t*ey
                fx=u*(cx-sx)+t*(ex-cx);fy=u*(cy-sy)+t*(ey-cy)
            else x=x-dy*.21;y=y+dx*.21 end
        end
        return x,y,facing(fx,fy)
    end
    local function spawn(w,n,kind,home,destination,path,start,duration)
        local next=path[1];if not next then return nil end
        local x,y=xy(start);local bx,by=xy(next);local heading=facing(bx-x,by-y)
        if kind=='car' then x=x-Nav.dy[heading+1]*.21;y=y+Nav.dx[heading+1]*.21 end
        if not clear(w,kind,x,y,heading) then return nil end
        local s=w.traffic_state
        local e={id=s.next_id,kind=kind,home=home,destination=destination,phase=1,cell=start,next_cell=0,progress=0,path=path,path_index=1,path_generation=n.generation,heading=heading,incoming=heading,facing=heading,x=x,y=y,z=kind=='car' and Nav.height(w,n,x,y,start) or 0,state=kind=='boat' and 'dock' or 'travel',wait=kind=='boat' and 1800 or 0,waited_cell=0,age=0,duration=duration or 0,animation_time=0,exit_progress=0,retry=0,blocked=0,goal=path[#path]}
        s.next_id=s.next_id+1;w.traffic[#w.traffic+1]=e;T.prepare(e)
        return e
    end
    function T.position(w,e)
        if e.next_cell~=0 then return positioned(w,navigation(w),e,e.progress) end
        local x,y=xy(e.cell)
        if e.kind=='car' then return x-Nav.dy[e.heading+1]*.21,y+Nav.dx[e.heading+1]*.21 end
        if e.state=='exit' then
            local dx,dy=x==0 and -1 or x==23 and 1 or 0,y==0 and -1 or y==23 and 1 or 0
            if dx~=0 then dy=0 end
            return x+dx*e.exit_progress,y+dy*e.exit_progress
        end
        return x,y
    end
    local function target(w,n,e)
        if e.kind=='car' then
            local k=e.phase==1 and e.destination or e.home;local p=n.places[k]
            local valid=p and #p.car>0 and (e.phase==1 and not (p.id>=11 and p.id<=16) or e.phase==2 and p.id>=11 and p.id<=16)
            if valid then return p.car,k+1000 end
            e.phase=2
            p=n.places[e.home]
            if p and p.id>=11 and p.id<=16 and #p.car>0 then return p.car,e.home+1000 end
            if #n.homes>0 then e.home=n.homes[(e.id-1)%#n.homes+1];return n.places[e.home].car,e.home+1000 end
        elseif e.kind=='boat' then
            local k=e.phase==1 and e.destination or e.home
            local p=n.places[k]
            if p and #p.boat>0 then return p.boat,k+2000 end
            if e.phase==1 and e.destination==0 then return n.boundary.boat,3000 end
            e.phase=2
            if #n.ports>0 then e.home=n.ports[(e.id-1)%#n.ports+1];return n.places[e.home].boat,e.home+2000 end
            e.destination=0;e.phase=1;return n.boundary.boat,3000
        else
            local waters=n.waters[e.kind];if #waters==0 then return nil end
            local s=w.traffic_state;local x,y=xy(e.cell);local k
            for attempt=1,8 do
                local candidate=waters[random(s,#waters)+1];local xx,yy=xy(candidate);local distance=abs(x-xx)+abs(y-yy)
                if distance>=2 and distance<=(e.kind=='fish' and 7 or 18) then k=candidate;break end
            end
            if k then w.traffic_targets[1]=k;return w.traffic_targets,k+4000 end
        end
        return nil
    end
    local function plan(w,n,e,budget)
        if e.next_cell~=0 or e.state=='exit' or e.wait>0 then return budget end
        if e.path and e.path_generation==n.generation then return budget end
        if e.retry>w.traffic_state.time and e.path_generation==n.generation then return budget end
        local targets,key=target(w,n,e)
        e.retry=w.traffic_state.time+2000;e.path_generation=n.generation
        if not targets or #targets==0 then return budget end
        local path,_,finish
        path,_,finish,budget=Nav.route(n,e.kind,e.cell,targets,e.cell,key,budget)
        if path then e.path=path;e.path_index=1;e.goal=finish;e.state='travel';e.blocked=0 end
        return budget
    end
    local function spawn_car(w,n,budget)
        local s=w.traffic_state;s.car_due=s.time+1200
        if count(w,'car')>=min(8,max(1,floor(w.population/8))) or w.population==0 or #n.homes==0 or #n.destinations==0 then return budget end
        local home=n.homes[random(s,#n.homes)+1];local busy=0
        for i=1,#w.traffic do if w.traffic[i].kind=='car' and w.traffic[i].home==home then busy=busy+1 end end
        if busy>=max(1,min(8,floor(Catalog[w.bid[home]][7]/8))) then return budget end
        local destination=n.destinations[random(s,#n.destinations)+1]
        local path,start,finish
        path,start,finish,budget=Nav.route(n,'car',n.places[home].car,n.places[destination].car,home+1000,destination+1000,budget)
        if path and #path>0 and spawn(w,n,'car',home,destination,path,start) then s.car_due=s.time+3000 end
        return budget
    end
    local function spawn_boat(w,n,budget)
        local s=w.traffic_state;s.boat_due=s.time+4000
        if count(w,'boat')>=4 or #n.ports==0 then return budget end
        local home=n.ports[random(s,#n.ports)+1];local destination=0
        if #n.ports>1 then
            local index=random(s,#n.ports)+1;destination=n.ports[index]
            if destination==home then destination=n.ports[index%#n.ports+1] end
        end
        for i=1,#w.traffic do local e=w.traffic[i]
            if e.kind=='boat' and (e.home==home or e.destination==home or destination>0 and (e.home==destination or e.destination==destination)) then return budget end
        end
        local targets=destination==0 and n.boundary.boat or n.places[destination].boat
        if #targets==0 then return budget end
        local path,start,finish
        path,start,finish,budget=Nav.route(n,'boat',n.places[home].boat,targets,home+2000,destination==0 and 3000 or destination+2000,budget)
        if path and #path>0 and spawn(w,n,'boat',home,destination,path,start) then s.boat_due=s.time+11000+random(s,6001) end
        return budget
    end
    local function spawn_fauna(w,n,kind,budget)
        local s=w.traffic_state;local due=kind..'_due';s[due]=s.time+(kind=='fish' and 2500 or 5000)
        if count(w,kind)>=caps[kind] then return budget end
        local waters=n.waters[kind];if #waters<8 then return budget end
        local start=waters[random(s,#waters)+1];local x,y=xy(start);local destination
        for attempt=1,12 do
            local k=waters[random(s,#waters)+1];local xx,yy=xy(k);local distance=abs(xx-x)+abs(yy-y)
            if distance>=(kind=='fish' and 2 or kind=='dolphin' and 6 or 8) and distance<=(kind=='fish' and 7 or 18) then destination=k;break end
        end
        if not destination or not clear(w,kind,x,y,0) then return budget end
        w.traffic_targets[1]=destination
        local path,origin,finish
        path,origin,finish,budget=Nav.route(n,kind,start,w.traffic_targets,start,destination+4000,budget)
        if path and #path>0 then
            local duration=kind=='fish' and 16000+random(s,8001) or surfacing_ms[kind]
            if spawn(w,n,kind,0,0,path,start,duration) then
                s[due]=s.time+(kind=='fish' and 2500 or kind=='dolphin' and 45000+random(s,45001) or 180000+random(s,180001))
            end
        end
        return budget
    end
    local function schedule(w,n)
        local s=w.traffic_state;local budget=2;local total=#w.traffic
        for offset=1,total do
            local i=(s.cursor+offset-2)%total+1;local e=w.traffic[i]
            if not e.path or e.path_generation~=n.generation then
                local before=budget;budget=plan(w,n,e,budget)
                if budget<before then s.cursor=i%max(1,total)+1;break end
            end
        end
        for offset=1,5 do
            if budget==0 then break end
            local i=(s.spawn_cursor+offset-2)%5+1;local kind=kinds[i]
            if s.time>=s[kind..'_due'] then
                if kind=='car' then budget=spawn_car(w,n,budget)
                elseif kind=='boat' then budget=spawn_boat(w,n,budget)
                else budget=spawn_fauna(w,n,kind,budget) end
            end
        end
        s.spawn_cursor=s.spawn_cursor%5+1
    end
    local function intersection(w,n,e,next,heading)
        if n.degree[next]<3 and n.degree[e.cell]<3 and heading==e.heading then return true end
        for i=1,#w.traffic do local q=w.traffic[i]
            if q~=e and q.kind=='car' then
                if n.degree[next]>=3 and (q.next_cell==next or q.cell==next and (q.next_cell==0 or q.progress<.65)) then return false end
                if q.cell==e.cell and q.next_cell~=0 and q.progress<.65 then return false end
            end
        end
        return true
    end
    local function arrived(e)
        e.path=nil;e.path_index=1;e.next_cell=0;e.progress=0;e.retry=0
        if e.kind=='car' then e.state='dock';e.wait=e.phase==1 and 1800 or 600
        elseif e.kind=='boat' then
            if e.destination==0 and e.phase==1 then e.state='exit';e.exit_progress=0
            else e.state='dock';e.wait=2200 end
        else e.state='wait' end
    end
    local function exit(w,e,dt)
        local x,y=xy(e.cell);local dx,dy=x==0 and -1 or x==23 and 1 or 0,y==0 and -1 or y==23 and 1 or 0
        if dx~=0 then dy=0 end
        e.exit_progress=e.exit_progress+speed.boat*dt;e.x=x+dx*e.exit_progress;e.y=y+dy*e.exit_progress;e.facing=facing(dx,dy)
        e.animation_time=(e.animation_time+dt)%120000
        return e.exit_progress>=1.8
    end
    local function move(w,n,e,dt)
        if e.path_generation~=n.generation then e.path=nil;e.retry=0 end
        if e.next_cell==0 then
            if not e.path then e.state='wait';return end
            local next=e.path[e.path_index]
            if not next then arrived(e);return end
            if not Nav.edge(n,e.kind,e.cell,next) then e.path=nil;e.state='wait';e.retry=0;return end
            local ax,ay=xy(e.cell);local bx,by=xy(next);local heading=facing(bx-ax,by-ay)
            if e.kind=='car' then
                if e.waited_cell~=e.cell and (n.degree[e.cell]>=3 or heading~=e.heading) then
                    e.wait=250;e.waited_cell=e.cell;e.state='wait';return
                end
                if not intersection(w,n,e,next,heading) then e.state='wait';return end
            end
            e.incoming=e.heading;e.heading=heading
            e.next_cell=next;e.progress=0;e.path_index=e.path_index+1
        end
        if not Nav.edge(n,e.kind,e.cell,e.next_cell) then e.path=nil;e.state='wait';return end
        local ax,ay=xy(e.cell);local bx,by=xy(e.next_cell)
        local length=ax~=bx and ay~=by and 1.4142135623730951 or 1
        local progress=min(1,e.progress+dt*speed[e.kind]/length)
        local x,y,d=positioned(w,n,e,progress)
        if not clear(w,e.kind,x,y,d,e) then e.blocked=e.blocked+dt;e.state='wait';return end
        e.x=x;e.y=y;e.facing=d;e.progress=progress;e.state='travel';e.blocked=0
        e.z=e.kind=='car' and Nav.height(w,n,x,y,progress<.5 and e.cell or e.next_cell) or 0
        e.animation_time=(e.animation_time+dt)%120000
        if progress==1 then e.cell=e.next_cell;e.next_cell=0;e.progress=0;e.waited_cell=0 end
    end
    function W.traffic_step(w,dt)
        local s=w.traffic_state;s.step=s.step+dt
        if s.step<50 then return end
        s.step=s.step-50;s.time=s.time+50;s.plan_clock=s.plan_clock+50
        local n=navigation(w)
        local total=#w.traffic
        if s.plan_clock>=500 then s.plan_clock=s.plan_clock-500;schedule(w,n) end
        for i=total,1,-1 do
            local e=w.traffic[i];local remove=false;e.age=e.age+50
            T.remember_position(e)
            if e.kind~='car' and e.kind~='boat' and e.age>=e.duration then remove=true
            elseif e.state=='exit' then remove=exit(w,e,50)
            elseif e.wait>0 then
                e.wait=max(0,e.wait-50)
                if e.wait==0 and e.state=='dock' then
                    if e.kind=='boat' and e.path then e.state='travel'
                    elseif e.phase==2 then remove=true
                    else e.phase=2;e.path=nil;e.retry=0;e.state='wait' end
                end
            else move(w,n,e,50) end
            if remove then table.remove(w.traffic,i) else render(e) end
        end
    end
    local old_new=W.new
    W.new=function(seed,free) return T.init(old_new(seed,free)) end
    local function overlap(w,x,y,nx,ny)
        for i=1,#w.traffic do local e=w.traffic[i];local r=Nav.radius[e.kind]
            if e.x+r+.5>x and e.y+r+.5>y and e.x-r+.5<x+nx and e.y-r+.5<y+ny then return true end
            if e.next_cell~=0 then local xx,yy=xy(e.next_cell)
                if xx+r+.5>x and yy+r+.5>y and xx-r+.5<x+nx and yy-r+.5<y+ny then return true end
            end
        end
        return false
    end
    local old_valid=W.valid
    W.valid=function(w,id,x,y,r,ignore_cost)
        local ok,msg=old_valid(w,id,x,y,r,ignore_cost);if not ok then return ok,msg end
        local nx,ny=W.footprint(id,r)
        if w.traffic and #w.traffic>0 and overlap(w,x,y,nx,ny) then return false,I18n.t('Aguarde o transito liberar este espaco') end
        return ok,msg
    end
    local old_remove=W.remove
    W.remove=function(w,x,y)
        local k=w.occ[W.cell(x,y)]
        if k>0 and (w.bid[k]==3 or w.bid[k]==4 or w.bid[k]==6) then
            local nx,ny=W.footprint(w.bid[k],w.rot[k]);local xx,yy=xy(k)
            if overlap(w,xx,yy,nx,ny) then return false,I18n.t('Aguarde o veiculo sair desta via') end
        end
        return old_remove(w,x,y)
    end
    local function safe(w)
        local n=P.refresh(w)
        for i=1,#w.traffic do local e=w.traffic[i]
            if e.kind=='car' then
                local a=w.occ[e.cell];local id=a>0 and w.bid[a] or 0
                if not (id==3 or id==4 or id==6) or not n.walk[e.cell] then return false end
                if e.next_cell~=0 then
                    a=w.occ[e.next_cell];id=a>0 and w.bid[a] or 0
                    if not (id==3 or id==4 or id==6) or not P.edge(w,e.cell,e.next_cell) then return false end
                end
                local cell=e.next_cell~=0 and e.progress>=.5 and e.next_cell or e.cell
                if abs(e.z-Nav.height(w,n,e.x,e.y,cell))>1e-8 then return false end
            else
                if not Nav.water(w,e.x,e.y,Nav.radius[e.kind]) then return false end
                if e.next_cell~=0 then local x,y=xy(e.next_cell);if not Nav.water(w,x,y,Nav.radius[e.kind]) then return false end end
            end
        end
        return true
    end
    local old_terraform=W.terraform
    W.terraform=function(w,tool,x,y,radius,reference,dx,dy,stroke)
        if #w.traffic==0 then return old_terraform(w,tool,x,y,radius,reference,dx,dy,stroke) end
        local heights=w.traffic_heights or {};w.traffic_heights=heights
        for k=1,625 do heights[k]=w.h[k] end
        local ok,msg=old_terraform(w,tool,x,y,radius,reference,dx,dy,stroke)
        if not ok or safe(w) then return ok,msg end
        for k=1,625 do w.h[k]=heights[k] end
        W.rebuild(w);return false,I18n.t('Aguarde a travessia antes de mudar esta costa ou via')
    end
    local old_restore=W.restore
    W.restore=function(w,s)
        if #w.traffic==0 then return old_restore(w,s) end
        local previous=W.snapshot(w);local valid={}
        for i=1,#w.people do local p=w.people[i];valid[i]=p.path_revision==w.revision and p.path_lots==w.lot_revision end
        local ok,msg=old_restore(w,s)
        if not ok or safe(w) then return ok,msg end
        old_restore(w,previous)
        for i=1,#w.people do local p=w.people[i];p.path_revision=valid[i] and w.revision or -1;p.path_lots=valid[i] and w.lot_revision or -1 end
        return false,I18n.t('Aguarde o transito liberar o terreno antes de desfazer')
    end
end
return T
