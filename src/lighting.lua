


local L={revision=-1,bin=-1}
local floor,min,max=math.floor,math.min,math.max
local R,N=8,192
local phases={'Ciclo natural','Manha','Golden hour','Noite'}
L.names=phases
local function ground(w,x,y)
    local xx=min(23,max(0,floor(x)));local yy=min(23,max(0,floor(y)))
    local u=x-xx;local v=y-yy;local k=yy*25+xx+1
    local a,b,c,d=w.h[k],w.h[k+1],w.h[k+26],w.h[k+25]
    if u>=v then return (a+u*(b-a)+v*(c-b))*16 end
    return (a+u*(c-d)+v*(d-a))*16
end
L.ground=ground
function L.phase(mode,time)
    if mode==2 then return .31 elseif mode==3 then return .72 elseif mode==4 then return .91 end
    return (time/360000+.31)%1
end
function L.prepare(w,detail)
    R=detail==1 and 8 or 4;N=24*R;L.R=R;L.N=N
    local h=L.height or {};local g=L.groundmap or {};L.height=h;L.groundmap=g
    local previous=L.vertices or {};L.vertices=previous
    local changed=L.changed or {};L.changed=changed;local all=L.detail~=detail;local i=1
    while i<=576 do changed[i]=all;i=i+1 end
    i=1
    while i<=625 do
        if previous[i]~=w.h[i] then
            previous[i]=w.h[i];local vx=(i-1)%25;local vy=floor((i-1)/25)
            local y=max(0,vy-1)
            while y<=min(23,vy) do local x=max(0,vx-1)
                while x<=min(23,vx) do changed[y*24+x+1]=true;x=x+1 end
                y=y+1
            end
        end;i=i+1
    end

    i=1
    while i<=576 do
        if changed[i] then
            local xx=(i-1)%24;local yy=floor((i-1)/24);local y=0
            while y<R do local x=0
                while x<R do local k=(yy*R+y)*N+xx*R+x+1;g[k]=ground(w,xx+(x+.5)/R,yy+(y+.5)/R);x=x+1 end
                y=y+1
            end
        end;i=i+1
    end
    i=1;while i<=N*N do h[i]=g[i];i=i+1 end
    L.revision=w.revision;L.detail=detail;L.world=w;L.bin=-1
end
function L.update(w,phase,detail)
    if L.world~=w or L.revision~=w.revision or L.detail~=detail then L.prepare(w,detail) end
    local daylight=phase>.18 and phase<.79
    local bin=daylight and floor(phase*48) or -2
    if bin==L.bin then return false end
    L.bin=bin;L.rebuilds=(L.rebuilds or 0)+1
    local masks=L.masks or {};L.masks=masks
    if not daylight then local i=1;while i<=576 do masks[i]='';i=i+1 end;return true end
    local sun=((bin+.5)/48-.18)/.61
    local angle=-math.pi*.92+sun*math.pi*1.1
    local dx,dy=math.cos(angle),math.sin(angle)
    local altitude=.33+math.sin(sun*math.pi)*1.8
    local major=max(math.abs(dx),math.abs(dy));dx=dx/major;dy=dy/major
    local drop=16/R*altitude/major
    local horizon=L.horizon or {};L.horizon=horizon
    local shaded=L.shaded or {};L.shaded=shaded

    local horizontal=math.abs(dx)>=math.abs(dy)
    local step=(horizontal and dx or dy)<0 and -1 or 1
    local start=step<0 and N-1 or 0
    local offset=horizontal and dy or dx;local lo=floor(-offset);local fraction=-offset-lo
    local outer=0
    while outer<N do local axis=start+outer*step;local inner=0
        while inner<N do
            local x=horizontal and axis or inner;local y=horizontal and inner or axis;local k=y*N+x+1
            local upstream=axis-step;local v0=inner+lo;local v1=v0+1;local sunheight=-100
            if upstream>=0 and upstream<N and v0>=0 and v1<N then
                local a=horizontal and v0*N+upstream+1 or upstream*N+v0+1
                local b=horizontal and v1*N+upstream+1 or upstream*N+v1+1
                sunheight=horizon[a]*(1-fraction)+horizon[b]*fraction-drop
            end
            horizon[k]=max(L.height[k],sunheight)
            shaded[k]=sunheight>L.groundmap[k]+2 and 1 or 0
            inner=inner+1
        end;outer=outer+1
    end

    local parts=L.parts or {};L.parts=parts
    local i=1
    while i<=576 do
        local xx=((i-1)%24)*R;local yy=floor((i-1)/24)*R;local n=0;local hits=0;local y=0
        while y<R do local x=0
            while x<R do n=n+1;local v=shaded[(yy+y)*N+xx+x+1];parts[n]=v==1 and '1' or '0';hits=hits+v;x=x+1 end
            y=y+1
        end
        masks[i]=hits>0 and table.concat(parts,'',1,n) or '';i=i+1
    end
    return true
end
return L
