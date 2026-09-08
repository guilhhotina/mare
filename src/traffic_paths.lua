local T={}
local floor,abs,max,min=math.floor,math.abs,math.max,math.min
local dx={1,1,0,-1,-1,-1,0,1}
local dy={0,1,1,1,0,-1,-1,-1}
local radius={car=.28,boat=.6,fish=.14,dolphin=.48,whale=1.05}
local aquatic={'boat','fish','dolphin','whale'}
T.dx=dx;T.dy=dy;T.radius=radius
local function xy(k) return (k-1)%24,floor((k-1)/24) end
local function trim(t,n) for i=n+1,#t do t[i]=nil end end
function T.water(w,x,y,r)
    for yy=max(0,floor(y+.5-r)),min(23,floor(y+.5+r)) do
        for xx=max(0,floor(x+.5-r)),min(23,floor(x+.5+r)) do
            local k=yy*24+xx+1
            local ax=max(abs(xx-x)-.5,0);local ay=max(abs(yy-y)-.5,0)
            if ax*ax+ay*ay<r*r and (w.top[k]~=0 or w.occ[k]~=0 or w.reserved[k]) then return false end
        end
    end
    return true
end
local function source(w,n)
    if n.revision==w.revision and n.lots==w.lot_revision then return false end
    n.revision=w.revision;n.lots=w.lot_revision
    local changed=false
    for k=1,625 do if n.h[k]~=w.h[k] then n.h[k]=w.h[k];changed=true end end
    for k=1,576 do
        local occupied=w.reserved[k] and 1 or 0
        if n.bid[k]~=w.bid[k] or n.rot[k]~=w.rot[k] or n.reserved[k]~=occupied then changed=true end
        n.bid[k]=w.bid[k];n.rot[k]=w.rot[k];n.reserved[k]=occupied
    end
    return changed
end
local function perimeter(w,k,id,W,visit)
    local x,y=xy(k);local nx,ny=W.footprint(id,w.rot[k])
    for v=-1,ny do for u=-1,nx do
        if (u>=0 and u<nx and (v==-1 or v==ny)) or (v>=0 and v<ny and (u==-1 or u==nx)) then
            local xx,yy=x+u,y+v
            if xx>=0 and yy>=0 and xx<24 and yy<24 then visit(xx,yy,u<0 and -1 or u==nx and 1 or 0,v<0 and -1 or v==ny and 1 or 0) end
        end
    end end
end
function T.refresh(w,W,P)
    local n=w.traffic_navigation
    if not n then
        n={h={},bid={},rot={},reserved={},pass={car={},boat={},fish={},dolphin={},whale={}},height={},degree={},places={},homes={},destinations={},ports={},boundary={boat={},fish={},dolphin={},whale={}},waters={boat={},fish={},dolphin={},whale={}},edges={},queue={},seen={},parent={},targets={},stamp=0,routes={},route_cursor=1,generation=0,builds=0,searches=0,expanded=0}
        for i=1,576 do n.edges[i]={} end
        w.traffic_navigation=n
    end
    if not source(w,n) then return n end
    n.generation=n.generation+1;n.builds=n.builds+1
    trim(n.routes,0);n.route_cursor=1
    local walk=P.refresh(w)
    for k=1,576 do
        local a=w.occ[k];local id=a>0 and w.bid[a] or 0
        n.pass.car[k]=(id==3 or id==4 or id==6) and walk.walk[k] or false
        n.height[k]=walk.height[k]
        local x,y=xy(k)
        for i=1,4 do local kind=aquatic[i];n.pass[kind][k]=T.water(w,x,y,radius[kind]) end
    end
    for k=1,576 do
        local x,y=xy(k);local degree=0
        for d=1,8 do
            local xx,yy=x+dx[d],y+dy[d];local b=yy*24+xx+1
            local allowed=d%2==1 and xx>=0 and yy>=0 and xx<24 and yy<24 and n.pass.car[k] and n.pass.car[b] and P.edge(w,k,b) or false
            n.edges[k][d]=allowed
            if allowed then degree=degree+1 end
        end
        n.degree[k]=degree
    end
    local homes,destinations,ports=0,0,0
    for k=1,576 do
        local id=w.bid[k];local p=n.places[k]
        if id>=8 then
            p=p or {car={},boat={}};n.places[k]=p;p.id=id
            local cars,boats=0,0
            perimeter(w,k,id,W,function(x,y,sx,sy)
                local b=y*24+x+1
                if n.pass.car[b] and abs(n.height[b]-w.base[k]*16)<=8 then cars=cars+1;p.car[cars]=b end
                if (id==9 or id==10) and w.linked[k] and (id==10 or w.population>0) then
                    for step=0,2 do
                        local xx,yy=x+sx*step,y+sy*step
                        if xx<0 or yy<0 or xx>=24 or yy>=24 then break end
                        local a=yy*24+xx+1
                        if w.base[a]~=0 or w.occ[a]~=0 then break end
                        if n.pass.boat[a] then
                            local found=false;for i=1,boats do if p.boat[i]==a then found=true;break end end
                            if not found then boats=boats+1;p.boat[boats]=a end
                            break
                        end
                    end
                end
            end)
            trim(p.car,cars);trim(p.boat,boats)
            if cars>0 then
                if id>=11 and id<=16 and w.linked[k] then homes=homes+1;n.homes[homes]=k
                elseif (id>=17 and id<=34) or id==8 or id==9 or id==10 or id==35 or id==36 or id==39 or id==40 then destinations=destinations+1;n.destinations[destinations]=k end
            end
            if boats>0 then ports=ports+1;n.ports[ports]=k end
        elseif p then p.id=0;trim(p.car,0);trim(p.boat,0) end
    end
    trim(n.homes,homes);trim(n.destinations,destinations);trim(n.ports,ports)
    for i=1,4 do
        local kind=aquatic[i];local boundary,water=0,0
        for k=1,576 do if n.pass[kind][k] then
            water=water+1;n.waters[kind][water]=k
            local x,y=xy(k)
            if x==0 or y==0 or x==23 or y==23 then boundary=boundary+1;n.boundary[kind][boundary]=k end
        end end
        trim(n.waters[kind],water);trim(n.boundary[kind],boundary)
    end
    return n
end
function T.edge(n,kind,a,b)
    if not n.pass[kind][a] or not n.pass[kind][b] then return false end
    local ax,ay=xy(a);local bx,by=xy(b);local x,y=bx-ax,by-ay
    if abs(x)>1 or abs(y)>1 or x==0 and y==0 then return false end
    if kind=='car' then
        local d=x==1 and 1 or y==1 and 3 or x==-1 and 5 or 7
        return abs(x)+abs(y)==1 and n.edges[a][d]
    end
    return x==0 or y==0 or n.pass[kind][ay*24+bx+1] and n.pass[kind][by*24+ax+1]
end
function T.route(n,kind,starts,targets,source_key,target_key,budget)
    if budget==0 then return nil,nil,nil,0 end
    for i=1,#n.routes do local c=n.routes[i]
        if c.kind==kind and c.source==source_key and c.target==target_key then return c.path,c.start,c.finish,budget-1 end
    end
    n.searches=n.searches+1;n.stamp=n.stamp+1;local stamp=n.stamp
    local first,last=1,0;local seen,parent,queue=n.seen,n.parent,n.queue
    if type(starts)=='number' then
        if n.pass[kind][starts] then last=1;queue[1]=starts;seen[starts]=stamp;parent[starts]=0 end
    else
        for i=1,#starts do local k=starts[i]
            if n.pass[kind][k] and seen[k]~=stamp then last=last+1;queue[last]=k;seen[k]=stamp;parent[k]=0 end
        end
    end
    for i=1,#targets do n.targets[targets[i]]=stamp end
    local path,start,finish
    while first<=last do
        local k=queue[first];first=first+1;n.expanded=n.expanded+1
        if n.targets[k]==stamp then
            path={};finish=k;start=k
            while parent[start]~=0 do path[#path+1]=start;start=parent[start] end
            for a=1,floor(#path/2) do local b=#path-a+1;path[a],path[b]=path[b],path[a] end
            break
        end
        local x,y=xy(k)
        for d=1,8,kind=='car' and 2 or 1 do
            local xx,yy=x+dx[d],y+dy[d];local b=yy*24+xx+1
            if xx>=0 and yy>=0 and xx<24 and yy<24 and seen[b]~=stamp and T.edge(n,kind,k,b) then
                seen[b]=stamp;parent[b]=k;last=last+1;queue[last]=b
            end
        end
    end
    local c=n.routes[n.route_cursor] or {};n.routes[n.route_cursor]=c
    c.kind=kind;c.source=source_key;c.target=target_key;c.path=path;c.start=start;c.finish=finish
    n.route_cursor=n.route_cursor%32+1
    return path,start,finish,budget-1
end
function T.height(w,n,x,y,cell)
    local a=w.occ[cell]
    if a>0 and w.bid[a]==6 then return n.height[cell] end
    local xx,yy=max(0,min(23.999999,x+.5)),max(0,min(23.999999,y+.5))
    local ix,iy=floor(xx),floor(yy);local u,v=xx-ix,yy-iy;local k=iy*25+ix+1
    return (w.h[k]*(1-u)*(1-v)+w.h[k+1]*u*(1-v)+w.h[k+25]*(1-u)*v+w.h[k+26]*u*v)*16
end
return T
