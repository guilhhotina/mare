
local W = {}
local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local N, V = 24, 25
W.N=N
local function cell(x,y) return y*N+x+1 end
local function vertex(x,y) return y*V+x+1 end
local function inside(x,y) return x>=0 and y>=0 and x<N and y<N end
local function footprint(id,r)
    local d=Catalog[id]
    if r%2==1 then return d[4],d[3] end
    return d[3],d[4]
end
W.cell=cell; W.footprint=footprint
function W.access(w,id,x,y,r)
    if id<=7 or id==35 or id==36 or id==38 then return true end
    local nx,ny=footprint(id,r);local u=0
    while u<nx do
        if (y>0 and w.road[cell(x+u,y-1)]) or (y+ny<N and w.road[cell(x+u,y+ny)]) then return true end
        u=u+1
    end
    local v=0
    while v<ny do
        if (x>0 and w.road[cell(x-1,y+v)]) or (x+nx<N and w.road[cell(x+nx,y+v)]) then return true end
        v=v+1
    end
    return false
end
local building_info={[1]='Caminhos que acompanham o relevo',[2]='Passeios e rampas para pedestres',[3]='Conecta moradias e servicos',[4]='Uma via larga para sua cidade',[5]='Atravesse canais e margens baixas',[6]='Conecte duas margens com uma via',[7]='Ligue diferentes alturas da ilha',[8]='+2 de felicidade com acesso',[9]='Balsas: receita e felicidade',[10]='Porto: 85 de receita por dia',[25]='35 de energia para a ilha',[26]='60 de energia limpa',[27]='90 de energia limpa',[28]='Agua para 150 moradores',[29]='Reciclagem para 150 moradores',[30]='Saude para 100 moradores',[31]='Educacao para 100 moradores',[32]='Seguranca para 100 moradores',[33]='Seguranca para 100 moradores',[34]='20 de receita por dia',[35]='+4 de felicidade na ilha',[36]='+4 de felicidade na ilha',[38]='Delimite jardins e recintos'}
building_info[39]='2 animais ao conectar uma via ao lado'
building_info[40]='4 animais e saude para 100 moradores; requer via ao lado'
function W.describe(id)
    local d=Catalog[id]
    if building_info[id] then return I18n.t(building_info[id]) end
    if d[7]>0 then return I18n.f('%d moradores com acesso viario',d[7]) end
    if d[8]>0 then return I18n.f('%d de receita base por dia com acesso viario',d[8]) end

    return I18n.t('Cuidados e vida para sua ilha')
end
function W.rebuild(w)
    local i=1
    while i<=N*N do
        local x=(i-1)%N; local y=floor((i-1)/N);local k=vertex(x,y)
        local a,b,c,d=w.h[k],w.h[k+1],w.h[k+V+1],w.h[k+V]
        local lo=min(a,b,c,d);local hi=max(a,b,c,d)
        w.base[i]=lo;w.mask[i]=(a>lo and 1 or 0)+(b>lo and 2 or 0)+(c>lo and 4 or 0)+(d>lo and 8 or 0)
        w.top[i]=hi;w.occ[i]=0;w.road[i]=false
        i=i+1
    end
    i=1
    while i<=N*N do
        local id=w.bid[i]
        if id>0 then
            local nx,ny=footprint(id,w.rot[i]);local x=(i-1)%N;local y=floor((i-1)/N);local v=0
            while v<ny do local u=0
                while u<nx do local j=cell(x+u,y+v);w.occ[j]=i;w.road[j]=id<=7;u=u+1 end
                v=v+1
            end
        end
        i=i+1
    end

    local pop,power,need,income,upkeep,parks,animals,roads,shops,count=0,0,0,0,0,0,0,0,0,0
    local water,health,school,waste,safety,transit,pollution=0,0,0,0,0,0,0
    i=1
    while i<=N*N do
        local id=w.bid[i]
        if id>0 then
            local d=Catalog[id];local nx,ny=footprint(id,w.rot[i]);local x=(i-1)%N;local y=floor((i-1)/N)
            local linked=id<=7 or id==35 or id==36 or id==38;local u=0
            while u<nx and not linked do
                linked=(y>0 and w.road[cell(x+u,y-1)]) or (y+ny<N and w.road[cell(x+u,y+ny)]);u=u+1
            end
            local v=0
            while v<ny and not linked do
                linked=(x>0 and w.road[cell(x-1,y+v)]) or (x+nx<N and w.road[cell(x+nx,y+v)]);v=v+1
            end
            w.linked[i]=linked
            count=count+1;upkeep=upkeep+d[6]
            if id<=7 then roads=roads+nx*ny end
            if linked then
                pop=pop+d[7];income=income+d[8]
                if d[7]>0 then need=need+max(1,floor(d[7]/4)) end
                if id>=28 and id<=34 then need=need+3 elseif id==39 or id==40 then need=need+2 elseif id>=8 and id<=10 then need=need+1 end
                if id>=17 and id<=24 then shops=shops+1;need=need+2 end
                if id==8 then transit=transit+2 elseif id==9 then transit=transit+5;income=income+35
                elseif id==10 then income=income+85 elseif id==34 then income=income+20 end
                if id==24 then pollution=pollution+2 elseif id==25 then pollution=pollution+1 end
                if id==25 then power=power+35 elseif id==26 then power=power+60 elseif id==27 then power=power+90 end
                if id==28 then water=water+150 elseif id==29 then waste=waste+150 elseif id==30 or id==40 then health=health+100 elseif id==31 then school=school+100 elseif id==32 or id==33 then safety=safety+100 end
            end
            if id==35 or id==36 then parks=parks+1 end
            if linked then if id==39 then animals=animals+2 elseif id==40 then animals=animals+4 end end
        end
        i=i+1
    end
    local happiness=60+min(20,parks*4)+(shops>0 and 5 or 0)+min(10,transit)-max(0,pollution-(waste>0 and 4 or 0))
    if need>power then happiness=happiness-25 end
    if pop>40 and water<pop then happiness=happiness-8 end
    if pop>60 and health<pop then happiness=happiness-8 end
    if pop>80 and waste<pop then happiness=happiness-6 end
    if pop>80 and school<pop then happiness=happiness-6 end
    if pop>120 and safety<pop then happiness=happiness-6 end
    happiness=min(100,max(10,happiness))
    w.population=pop;w.power=power;w.need=need;w.happy=happiness;w.animals=animals;w.parks=parks;w.roads=roads;w.shops=shops;w.count=count
    w.upkeep=upkeep;w.revenue=floor(pop*happiness/100)+floor(income*(need<=power and 1 or 1/2))+25
    w.balance=w.revenue-upkeep;w.water=water;w.health=health;w.school=school;w.waste=waste;w.safety=safety

    w.drawlist=w.drawlist or {};local commands=w.drawlist;local n=0;i=1
    while i<=N*N do
        local x=(i-1)%N;local y=floor((i-1)/N);local id=w.bid[i]
        if w.top[i]>0 then n=n+1;commands[n]=(x+y)*4096+i end

        if w.top[i]==0 then n=n+1;commands[n]=(x+y)*4096+1024+i end
        if id>0 then local nx,ny=footprint(id,w.rot[i]);n=n+1;commands[n]=(x+y+nx+ny-2)*4096+2048+i
        elseif w.occ[i]==0 and w.deco[i]>0 and w.base[i]>0 and w.mask[i]==0 then n=n+1;commands[n]=(x+y)*4096+2048+i end
        i=i+1
    end
    i=n+1;while commands[i] do commands[i]=nil;i=i+1 end
    table.sort(commands)
    w.dirty=true;w.revision=w.revision+1
end
function W.new(seed,free)
    local w={h={},base={},mask={},top={},occ={},road={},bid={},rot={},linked={},deco={},reserved={},people={},cash=3200,day=1,seed=seed,free=free,revision=0,undo={},reward=0,ticks=0}
    local y=0
    while y<V do local x=0
        while x<V do
            local a=(x-11)*(x-11)/96+(y-12)*(y-12)/86
            local jitter=math.sin(x*.63+seed*.017)*math.cos(y*.49-seed*.013)*.13
            local h=0
            if a+jitter<1 then h=1 end
            if a+jitter<62/100 then h=2 end
            if (x-10)*(x-10)+(y-7)*(y-7)<15 then h=3 end
            if (x-10)*(x-10)+(y-7)*(y-7)<4 then h=4 end
            local b=(x-20)*(x-20)+(y-4)*(y-4)
            if b<10 then h=max(h,1) end
            if x>=7 and x<=17 and y>=10 and y<=16 then h=2 end
            w.h[vertex(x,y)]=h;x=x+1
        end
        y=y+1
    end
    local pass=0
    while pass<4 do
        local yy=0
        while yy<V do local xx=0
            while xx<V do
                local k=vertex(xx,yy);local vy=max(0,yy-1)
                while vy<=min(N,yy+1) do local vx=max(0,xx-1)
                    while vx<=min(N,xx+1) do w.h[k]=min(w.h[k],w.h[vertex(vx,vy)]+1);vx=vx+1 end
                    vy=vy+1
                end
                xx=xx+1
            end
            yy=yy+1
        end
        pass=pass+1
    end
    local i=1
    while i<=N*N do w.bid[i]=0;w.rot[i]=0;w.deco[i]=((i*137+(i%24)*53+seed*11)%29<3) and 1+(i%3) or 0;i=i+1 end
    W.rebuild(w)

    local x=7
    while x<=16 do
        local j=cell(x,12)
        if w.base[j]>=1 and w.mask[j]==0 then w.bid[j]=3 end
        x=x+1
    end
    W.rebuild(w)
    local starter={{11,7,11},{12,9,13},{17,11,11},{25,14,13},{35,12,13}};i=1
    while i<=#starter do
        local id=starter[i][1];local yy=13;local placed=false
        local sx,sy=starter[i][2],starter[i][3]
        if W.valid(w,id,sx,sy,0,true) then w.bid[cell(sx,sy)]=id;W.rebuild(w);placed=true end
        while yy>=10 and not placed do local xx=7
            while xx<17 and not placed do
                local ok=W.valid(w,id,xx,yy,0,true)
                if ok then w.bid[cell(xx,yy)]=id;W.rebuild(w);placed=true end
                xx=xx+1
            end
            yy=yy-1
        end
        i=i+1
    end
    return w
end
function W.valid(w,id,x,y,r,ignore_cost)
    local nx,ny=footprint(id,r)
    if x<0 or y<0 or x+nx>N or y+ny>N then return false,I18n.t('Fora dos limites da ilha') end
    if not ignore_cost and not w.free and w.cash<W.price(w,id,x,y) then return false,I18n.t('Faltam moedas. Espere a renda ou use o modo livre.') end
    local base=w.base[cell(x,y)];local bridge=id==5 or id==6;local v=0;local coast=false
    while v<ny do local u=0
        while u<nx do
            local k=cell(x+u,y+v);local mask=w.mask[k]
            if w.occ[k]>0 then
                if id<=3 and w.bid[k]>=1 and w.bid[k]<=3 then
                    if w.bid[k]==id then return false,I18n.t('Esta via ja tem esse piso') end
                else return false,I18n.t('Este espaco ja esta ocupado') end
            end
            if not bridge then
                if base<1 or w.base[k]~=base then return false,I18n.t('Eleve e nivele o terreno primeiro') end
                if mask~=0 then
                    if id>3 and id~=7 then return false,I18n.t('Esta construcao precisa de terreno plano') end
                    if mask~=3 and mask~=6 and mask~=9 and mask~=12 then return false,I18n.t('Use Nivelar para criar uma rampa reta') end
                end
            elseif w.top[k]>1 then return false,I18n.t('Pontes atravessam agua ou margens baixas') end
            if (x+u>0 and w.base[k-1]==0) or (x+u<N-1 and w.base[k+1]==0) or (y+v>0 and w.base[k-N]==0) or (y+v<N-1 and w.base[k+N]==0) then coast=true end
            u=u+1
        end
        v=v+1
    end
    if (id==9 or id==10 or id==37) and not coast then return false,I18n.t('Escolha um terreno plano junto da agua') end
    return true,I18n.t('Pronto para construir')
end
function W.price(w,id,x,y)
    local price=Catalog[id][5]
    if id<=3 and inside(x,y) then
        local old=w.bid[cell(x,y)]
        if old>=1 and old<=3 then price=max(0,price-Catalog[old][5]) end
    end
    return price
end
function W.snapshot(w)
    local s={h={},bid={},rot={},cash=w.cash};local i=1
    while i<=V*V do s.h[i]=w.h[i];i=i+1 end
    i=1;while i<=N*N do s.bid[i]=w.bid[i];s.rot[i]=w.rot[i];i=i+1 end
    return s
end
function W.restore(w,s)
    local i=1;while i<=V*V do w.h[i]=s.h[i];i=i+1 end
    i=1;while i<=N*N do w.bid[i]=s.bid[i];w.rot[i]=s.rot[i];i=i+1 end
    w.cash=s.cash;W.rebuild(w)
end
function W.record(w,s)
    local n=#w.undo
    if n==12 then table.remove(w.undo,1) end
    w.undo[#w.undo+1]=s
end
function W.undo(w)
    local n=#w.undo
    if n==0 then return false end
    local current_cash=w.cash;local snapshot=w.undo[n]
    W.restore(w,snapshot);w.cash=max(0,current_cash+(snapshot.refund or 0));w.undo[n]=nil;return true
end
function W.build(w,id,x,y,r)
    local ok,msg=W.valid(w,id,x,y,r)
    if not ok then return false,msg end
    local price=W.price(w,id,x,y);local snapshot=W.snapshot(w);snapshot.refund=w.free and 0 or price;W.record(w,snapshot);local k=cell(x,y);w.bid[k]=id;w.rot[k]=r
    if not w.free then w.cash=w.cash-price end
    W.rebuild(w);return true,I18n.f('%s: pronto!',I18n.catalog(id)[1])
end
function W.paint(w,id,x,y)
    local k=cell(x,y)
    if w.bid[k]==id then return true end
    local ok,msg=W.valid(w,id,x,y,0)
    if not ok then return false,msg end
    local price=W.price(w,id,x,y);w.bid[k]=id;w.rot[k]=0
    if not w.free then w.cash=w.cash-price end
    W.rebuild(w);return true
end
function W.remove(w,x,y)
    local k=w.occ[cell(x,y)]
    if k==0 then return false,I18n.t('Nada para remover aqui') end
    local id=w.bid[k];local snapshot=W.snapshot(w);snapshot.refund=w.free and 0 or -floor(Catalog[id][5]*3/4);W.record(w,snapshot);w.bid[k]=0;w.rot[k]=0
    if not w.free then w.cash=w.cash+floor(Catalog[id][5]*3/4) end
    W.rebuild(w);return true,I18n.t('Removido. Reembolso de 75%.')
end



local edge_a,edge_b={},{}
do
    local y=0
    while y<V do local x=0
        while x<V do
            local k=vertex(x,y)
            if x<N then edge_a[#edge_a+1]=k;edge_b[#edge_b+1]=k+1 end
            if y<N then
                edge_a[#edge_a+1]=k;edge_b[#edge_b+1]=k+V
                if x<N then edge_a[#edge_a+1]=k;edge_b[#edge_b+1]=k+V+1 end
                if x>0 then edge_a[#edge_a+1]=k;edge_b[#edge_b+1]=k+V-1 end
            end
            x=x+1
        end;y=y+1
    end
end
local function envelope(g,values,rising)
    local step=rising and -1 or 1;local h=rising and 5 or 0;local last=rising and 1 or 4
    while rising and h>=last or not rising and h<=last do
        local i=1;local next_h=h+step
        while i<=#edge_a do
            local a,b=g.parent[edge_a[i]],g.parent[edge_b[i]]
            if a~=b then
                local ah,bh=values[a],values[b]
                if ah==h and (rising and bh<next_h or not rising and bh>next_h) then values[b]=next_h end
                if bh==h and (rising and ah<next_h or not rising and ah>next_h) then values[a]=next_h end
            end;i=i+1
        end;h=h+step
    end
end
local function terrain_groups(w,reference)
    local g={parent={},pref={},minimum={},goal={},low={},high={},touched={}}
    local p=g.parent;local i=1;while i<=V*V do p[i]=i;i=i+1 end
    local function root(k) while p[k]~=k do p[k]=p[p[k]];k=p[k] end;return k end
    local function join(a,b) a=root(a);b=root(b);if a~=b then p[max(a,b)]=min(a,b) end end
    i=1
    while i<=N*N do
        local id=reference.bid[i]
        if id>0 then
            local x,y=(i-1)%N,floor((i-1)/N);local k=vertex(x,y)
            if id<=3 or id==7 then
                local along_x=(x>0 and w.road[i-1]) or (x<N-1 and w.road[i+1])
                local along_y=(y>0 and w.road[i-N]) or (y<N-1 and w.road[i+N])
                if along_x and not along_y then join(k,k+V);join(k+1,k+V+1)
                elseif along_y and not along_x then join(k,k+1);join(k+V,k+V+1)
                elseif not along_x and not along_y then

                    local a,b,c,d=reference.h[k],reference.h[k+1],reference.h[k+V+1],reference.h[k+V]
                    if a==d and b==c and a~=b then join(k,k+V);join(k+1,k+V+1)
                    elseif a==b and c==d and a~=c then join(k,k+1);join(k+V,k+V+1)
                    else join(k,k+1);join(k,k+V);join(k,k+V+1) end
                else join(k,k+1);join(k,k+V);join(k,k+V+1) end
            else
                local nx,ny=footprint(id,reference.rot[i]);local yy=0
                while yy<=ny do local xx=0
                    while xx<=nx do join(k,vertex(x+xx,y+yy));xx=xx+1 end;yy=yy+1
                end
            end
        end;i=i+1
    end
    i=1;while i<=V*V do p[i]=root(i);local k=p[i];g.pref[k]=max(g.pref[k] or 0,reference.h[i]);g.minimum[k]=0;i=i+1 end
    i=1
    while i<=N*N do
        local id=reference.bid[i]
        if id>0 and id~=5 and id~=6 then
            local x,y=(i-1)%N,floor((i-1)/N);local nx,ny=footprint(id,reference.rot[i]);local yy=0
            while yy<=ny do local xx=0
                while xx<=nx do g.minimum[p[vertex(x+xx,y+yy)]]=1;xx=xx+1 end;yy=yy+1
            end
        end;i=i+1
    end


    i=1;while i<=V*V do if p[i]==i then g.pref[i]=max(g.minimum[i],g.pref[i]) end;i=i+1 end
    envelope(g,g.pref,true);return g
end
function W.terraform(w,tool,x,y,radius,reference,dx,dy,stroke)
    local g=stroke and stroke.graph or terrain_groups(w,reference)
    if stroke and not g then g=terrain_groups(w,reference) end
    if stroke then stroke.graph=g;stroke.visited=stroke.visited or {};stroke.pending_visits=stroke.pending_visits or {} end
    local visits=stroke and stroke.visited;local target=stroke and stroke.target or reference.h[vertex(x,y)]
    local i=1
    while i<=V*V do
        local k=g.parent[i]
        if k==i then g.goal[k]=g.pref[k];g.low[k]=g.minimum[k];g.high[k]=5;g.touched[k]=false end
        i=i+1
    end
    if visits then
        local yy=max(0,y-radius-1)
        while yy<=min(N,y+radius+1) do local xx=max(0,x-radius-1)
            while xx<=min(N,x+radius+1) do
                local k=vertex(xx,yy)
                if not visits[k] and (xx-x)*(xx-x)+(yy-y)*(yy-y)<=(radius+1)*(radius+1) then
                    visits[k]=true;stroke.pending_visits[#stroke.pending_visits+1]=k
                end
                xx=xx+1
            end;yy=yy+1
        end
    end
    i=1
    while i<=V*V do
        local xx,yy2=(i-1)%V,floor((i-1)/V)
        local hit=visits and visits[i] or (not visits and (xx-x)^2+(yy2-y)^2<=(radius+1)^2)
        if hit then
            local k=g.parent[i];local h=reference.h[i]
            if tool=='raise' then h=max(g.pref[k],min(5,h+1))
            elseif tool=='lower' then h=max(0,h-1)
            elseif tool=='level' then h=target
            else h=reference.h[vertex(max(0,min(N,xx-(dx or 0))),max(0,min(N,yy2-(dy or 0))))] end
            h=max(g.minimum[k],h)
            if not g.touched[k] then g.goal[k]=h
            elseif tool=='lower' then g.goal[k]=min(g.goal[k],h)
            else g.goal[k]=max(g.goal[k],h) end
            g.touched[k]=true
        end;i=i+1
    end
    if tool=='raise' then envelope(g,g.goal,true)
    elseif tool=='lower' then envelope(g,g.goal,false)
    elseif tool=='level' then
        i=1;while i<=V*V do if g.parent[i]==i and g.touched[i] then g.low[i]=g.goal[i];g.high[i]=g.goal[i] end;i=i+1 end
        envelope(g,g.low,true);envelope(g,g.high,false)
        i=1;while i<=V*V do if g.parent[i]==i then g.goal[i]=max(g.low[i],min(g.high[i],g.pref[i])) end;i=i+1 end
    else
        i=1;while i<=V*V do if g.parent[i]==i then g.low[i]=g.goal[i];g.high[i]=g.goal[i] end;i=i+1 end
        envelope(g,g.low,false);envelope(g,g.high,true)
        i=1;while i<=V*V do if g.parent[i]==i then g.goal[i]=max(g.minimum[i],floor((g.low[i]+g.high[i]+1)/2)) end;i=i+1 end
        envelope(g,g.goal,true)
    end
    i=1;while i<=V*V do w.h[i]=g.goal[g.parent[i]];i=i+1 end
    W.rebuild(w);return true,I18n.t('Relevo e fundacoes ajustados')
end
function W.elevation(w,id,x,y,r)
    local h=w.base[cell(x,y)]
    if id==5 or id==6 then
        local nx,ny=footprint(id,r);nx=min(nx,N-x);ny=min(ny,N-y);local v=0;h=1
        while v<ny do local u=0;while u<nx do h=max(h,w.top[cell(x+u,y+v)]);u=u+1 end;v=v+1 end
    end
    return h
end
local goals={
    {'Um lugar para chamar de seu','Chegue a 20 moradores',500},
    {'A ilha funciona','40 moradores, energia suficiente',750},
    {'A vida la fora','3 pracas ou mirantes e 2 comercios',1000},
    {'Amigos de todas as especies','Tenha 6 animais e uma clinica',1250},
    {'Uma pequena grande ilha','100 moradores e 80% de felicidade',2000}
}
W.goals=goals
function W.progress(w)
    local g=w.reward+1
    if g==1 then return min(1,w.population/20) end
    if g==2 then return min(1,w.population/40,w.power/max(1,w.need)) end
    if g==3 then return min(1,w.parks/3,w.shops/2) end
    if g==4 then return min(1,w.animals/6,w.health>0 and 1 or 0) end
    if g==5 then return min(1,w.population/100,w.happy/80) end
    return 1
end
function W.goal_ready(w)
    local g=w.reward+1
    if g==1 then return w.population>=20 end
    if g==2 then return w.population>=40 and w.power>=w.need end
    if g==3 then return w.parks>=3 and w.shops>=2 end
    if g==4 then return w.animals>=6 and w.health>0 end
    if g==5 then return w.population>=100 and w.happy>=80 end
    return false
end
function W.tick(w)
    w.day=w.day+1;w.cash=max(0,w.cash+w.balance);w.ticks=w.ticks+1
    if not w.free and w.cash==0 and w.balance<0 then w.cash=300;return I18n.t('Fundo de apoio: +300 moedas para recuperar a ilha.') end
end
function W.claim(w)
    if not W.goal_ready(w) then return false end
    w.reward=w.reward+1;w.cash=w.cash+goals[w.reward][3];return true
end
function W.encode(w)
    local out={'MARE2',w.seed,w.free and 1 or 0,w.cash,w.day,w.reward};local i=1
    while i<=V*V do out[#out+1]=w.h[i];i=i+1 end
    i=1;while i<=N*N do out[#out+1]=w.bid[i];out[#out+1]=w.rot[i];i=i+1 end
    return table.concat(out,',')
end
function W.decode(text)
    if type(text)~='string' or #text>20000 then return nil end
    local values={};for token in string.gmatch(text,'[^,]+') do values[#values+1]=token end
    if #values~=6+V*V+N*N*2 or values[1]~='MARE2' then return nil end
    local i=2
    while i<=#values do
        local n=tonumber(values[i]);if not n or n~=floor(n) or n<0 or n>100000000 then return nil end
        values[i]=n;i=i+1
    end
    if values[3]>1 or values[6]>5 or values[5]<1 then return nil end
    local w={h={},base={},mask={},top={},occ={},road={},bid={},rot={},linked={},deco={},reserved={},people={},seed=values[2],free=values[3]==1,cash=values[4],day=values[5],reward=values[6],undo={},revision=0,ticks=0}
    i=1;while i<=V*V do if values[6+i]>5 then return nil end;w.h[i]=values[6+i];i=i+1 end
    local used={};i=1
    while i<=N*N do
        local p=7+V*V+(i-1)*2;local id,r=values[p],values[p+1]
        if id>40 or r>3 then return nil end
        if id>0 then
            local x=(i-1)%N;local y=floor((i-1)/N);local nx,ny=footprint(id,r)
            if x+nx>N or y+ny>N then return nil end
            local v=0;while v<ny do local u=0
                while u<nx do local j=cell(x+u,y+v);if used[j] then return nil end;used[j]=true;u=u+1 end;v=v+1
            end
        end
        w.bid[i]=id;w.rot[i]=r;w.deco[i]=((i*137+(i%24)*53+w.seed*11)%29<3) and 1+(i%3) or 0;i=i+1
    end
    local y=0
    while y<N do local x=0
        while x<N do local k=vertex(x,y)
            if max(w.h[k],w.h[k+1],w.h[k+V],w.h[k+V+1])-min(w.h[k],w.h[k+1],w.h[k+V],w.h[k+V+1])>1 then return nil end
            x=x+1
        end;y=y+1
    end
    W.rebuild(w);return w
end
Life.install(W,Catalog,Paths,Activities,Appearance,InteractionAnchors)
Traffic.install(W,Catalog,Paths,TrafficPaths)
TrafficStore.install(W,Traffic,TrafficPaths,Paths)
local terraform=W.terraform
W.terraform=function(w,tool,x,y,radius,reference,dx,dy,stroke)
    local ok,msg=terraform(w,tool,x,y,radius,reference,dx,dy,stroke)
    if stroke then
        for i=#stroke.pending_visits,1,-1 do
            if not ok then stroke.visited[stroke.pending_visits[i]]=nil end
            stroke.pending_visits[i]=nil
        end
    end
    return ok,msg
end
return W
