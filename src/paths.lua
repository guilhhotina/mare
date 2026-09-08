local P={}
local floor,abs=math.floor,math.abs
local N=24
local function xy(k) return (k-1)%N,floor((k-1)/N) end
function P.refresh(w)
    local n=w.navigation
    if n and n.revision==w.revision and n.lots==w.lot_revision then return n end
    n=n or {height={},walk={},bridge={},queue={},seen={},parent={},targets={},stamp=0}
    for k=1,576 do
        local a=w.occ[k];local id=a>0 and w.bid[a] or 0
        local bridge=id==5 or id==6
        local mask=w.mask[k]
        n.bridge[k]=bridge
        n.walk[k]=(not w.reserved[k]) and (bridge or ((id==0 or id<=7) and w.base[k]>0 and (mask==0 or mask==3 or mask==6 or mask==9 or mask==12)))
        local x,y=xy(k);local v=y*25+x+1
        n.height[k]=bridge and 16 or (w.h[v]+w.h[v+1]+w.h[v+25]+w.h[v+26])*4
        if bridge then
            if k==a then
                local d=Catalog[id];local nx,ny=d[3],d[4]
                if w.rot[a]%2==1 then nx,ny=ny,nx end
                local deck=1
                for yy=0,ny-1 do for xx=0,nx-1 do deck=math.max(deck,w.top[a+yy*N+xx]) end end
                n.height[k]=deck*16
            else n.height[k]=n.height[a] end
        end
    end
    n.revision=w.revision;n.lots=w.lot_revision;n.interactions={};w.navigation=n
    return n
end
function P.edge(w,a,b)
    local n=P.refresh(w)
    if not n.walk[a] or not n.walk[b] then return false end
    local ax,ay=xy(a);local bx,by=xy(b)
    if abs(ax-bx)+abs(ay-by)~=1 then return false end
    if n.bridge[a] or n.bridge[b] then
        if n.bridge[a] and n.bridge[b] then return n.height[a]==n.height[b] end
        local dry=n.bridge[a] and b or a;local deck=n.bridge[a] and n.height[a] or n.height[b]
        local x,y=xy(dry);local v=y*25+x+1
        if ax<bx then
            if dry==a then v=v+1 end
            return w.h[v]*16==deck and w.h[v+25]*16==deck
        elseif ax>bx then
            if dry==b then v=v+1 end
            return w.h[v]*16==deck and w.h[v+25]*16==deck
        elseif ay<by then
            if dry==a then v=v+25 end
            return w.h[v]*16==deck and w.h[v+1]*16==deck
        else
            if dry==b then v=v+25 end
            return w.h[v]*16==deck and w.h[v+1]*16==deck
        end
    end
    return abs(n.height[a]-n.height[b])<=16
end
function P.doors(w,id,x,y,r,W,out)
    local n=P.refresh(w);local nx,ny=W.footprint(id,r);local count=0
    for v=-1,ny do
        for u=-1,nx do
            if (u>=0 and u<nx and (v==-1 or v==ny)) or (v>=0 and v<ny and (u==-1 or u==nx)) then
                local xx,yy=x+u,y+v
                if xx>=0 and yy>=0 and xx<N and yy<N then
                    local k=yy*N+xx+1
                    if w.road[k] and n.walk[k] and abs(n.height[k]-w.base[y*N+x+1]*16)<=8 then count=count+1;out[count]=k end
                end
            end
        end
    end
    for i=count+1,#out do out[i]=nil end
    return count
end
local function interaction(w,id,x,y,r,W,Anchors,anchor)
    local n=P.refresh(w);local key=((y*N+x)*64+id)*4+r
    local site=n.interactions[key]
    if not site then site={};n.interactions[key]=site end
    local stage
    if anchor=='work_edge' or anchor=='work_surface' then
        stage='reserved'
        for i=1,#w.jobs do
            local j=w.jobs[i]
            if j.building_id==id and j.rotation==r and j.x==x and j.y==y then stage=j.stage;break end
        end
    end
    local entry=site[anchor]
    if not entry or entry.stage~=stage then
        entry={cells={},anchors={},stage=stage};site[anchor]=entry
        P.doors(w,id,x,y,r,W,entry.cells)
        local count=0
        for i=1,#entry.cells do
            local cell=entry.cells[i];local point=Anchors.resolve(w,id,r,x,y,anchor,cell)
            if point and point.reachable then count=count+1;entry.cells[count]=cell;entry.anchors[cell]=point end
        end
        for i=count+1,#entry.cells do entry.cells[i]=nil end
    end
    return entry
end
function P.approaches(w,id,x,y,r,W,Anchors,anchor,out)
    local entry=interaction(w,id,x,y,r,W,Anchors,anchor)
    for i=1,#entry.cells do out[i]=entry.cells[i] end
    for i=#entry.cells+1,#out do out[i]=nil end
    return #entry.cells
end
function P.anchor(w,id,x,y,r,W,Anchors,anchor,cell)
    return interaction(w,id,x,y,r,W,Anchors,anchor).anchors[cell]
end
function P.route(w,start,targets)
    local n=P.refresh(w)
    n.stamp=n.stamp+1;local stamp=n.stamp;local queue,parent,seen=n.queue,n.parent,n.seen
    local first,last=1,0
    local targets_seen=n.targets
    for i=1,#targets do targets_seen[targets[i]]=stamp end
    if type(start)=='table' then
        for i=1,#start do local k=start[i]
            if n.walk[k] and seen[k]~=stamp then last=last+1;queue[last]=k;seen[k]=stamp;parent[k]=0 end
        end
    elseif n.walk[start] then last=1;queue[1]=start;seen[start]=stamp;parent[start]=0 end
    while first<=last do
        local k=queue[first];first=first+1
        if targets_seen[k]==stamp then
            local path={};local p=k
            while parent[p]~=0 do path[#path+1]=p;p=parent[p] end
            for a=1,floor(#path/2) do local b=#path-a+1;path[a],path[b]=path[b],path[a] end
            return path,k,p
        end
        local x,y=xy(k)
        for d=1,4 do
            local b=d==1 and k+1 or d==2 and k+N or d==3 and k-1 or k-N
            local inside=d==1 and x<N-1 or d==2 and y<N-1 or d==3 and x>0 or d==4 and y>0
            if inside and seen[b]~=stamp and P.edge(w,k,b) then seen[b]=stamp;parent[b]=k;last=last+1;queue[last]=b end
        end
    end
    return nil
end
return P
