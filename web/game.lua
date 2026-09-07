local Platform=(function()
return {
    text = mare_text,
    text_width = mare_text_width,
    sprite = mare_sprite,
    skin = mare_skin,
    sound = mare_sound,
    load = mare_load,
    backup = mare_backup,
    save = mare_save,
    cache_begin = mare_cache_begin,
    cache_end = mare_cache_end,
    scene = mare_scene,
    shadow = mare_shadow,
    ground_light = mare_ground_light,
    world = mare_world,
    effects = mare_effects,
    thumb = mare_thumb,
    minimap = mare_minimap,
    burst = mare_burst,
    options = mare_options,
    get_options = mare_get_options,
    register = mare_register,
    take_key = mare_take_key,
    ui_begin = mare_ui_begin,
    ui_end = mare_ui_end
}

end)()
local Catalog=(function()
return {{"Trilha de terra","Vias",1,1,8,0,0,0,"terra","Trilha de","terra"},{"Passeio","Vias",1,1,16,0,0,0,"pedestres","Passeio",""},{"Rua","Vias",1,1,25,0,0,0,"rua","Rua",""},{"Avenida","Vias",2,2,70,1,0,0,"avenida","Avenida",""},{"Ponte de madeira","Vias",1,1,60,0,0,0,"bridge","Ponte de","madeira"},{"Ponte rodovi\195\161ria","Vias",2,2,150,1,0,0,"bridge","Ponte","rodovi\195\161ria"},{"Escadaria","Vias",1,1,30,0,0,0,"steps","Escadaria",""},{"Ponto de \195\180nibus","Vias",1,1,110,1,0,0,"bus","Ponto de","\195\180nibus"},{"Terminal de balsas","Vias",3,2,650,6,0,0,"ferry","Terminal de","balsas"},{"Porto de cargas","Vias",4,3,1200,10,0,0,"port","Porto de","cargas"},{"Casinha","Moradia",1,1,90,0,4,0,"house","Casinha",""},{"Casa com jardim","Moradia",2,1,160,1,8,0,"garden","Casa com","jardim"},{"Vila de sobrados","Moradia",3,1,330,2,18,0,"row","Vila de","sobrados"},{"Predinho","Moradia",1,1,240,1,14,0,"apart","Predinho",""},{"Edif\195\173cio","Moradia",2,1,480,3,32,0,"apart","Edif\195\173cio",""},{"Torre residencial","Moradia",2,2,1000,6,72,0,"tower","Torre","residencial"},{"Mercadinho","Com\195\169rcio",1,1,160,2,0,12,"shop","Mercadinho",""},{"Padaria e caf\195\169","Com\195\169rcio",1,1,180,2,0,14,"caf\195\169","Padaria e","caf\195\169"},{"Pet shop","Com\195\169rcio",1,1,170,2,0,12,"pet","Pet shop",""},{"Restaurante","Com\195\169rcio",2,1,300,3,0,25,"rest","Restaurante",""},{"Feira ao ar livre","Com\195\169rcio",4,1,360,2,0,28,"market","Feira ao ar","livre"},{"Hotel da ilha","Com\195\169rcio",2,3,900,7,0,65,"hotel","Hotel da ilha",""},{"Jardim comercial","Com\195\169rcio",3,2,650,5,0,48,"mall","Jardim","comercial"},{"Oficina","Com\195\169rcio",3,2,600,5,0,60,"factory","Oficina",""},{"Gerador","Servi\195\167os",2,1,220,7,0,0,"diesel","Gerador",""},{"Turbina e\195\179lica","Servi\195\167os",2,2,700,3,0,0,"wind","Turbina","e\195\179lica"},{"Usina solar","Servi\195\167os",3,2,950,2,0,0,"solar","Usina solar",""},{"\195\129gua e saneamento","Servi\195\167os",3,2,650,5,0,0,"water","\195\129gua e","saneamento"},{"Reciclagem","Servi\195\167os",3,2,580,5,0,0,"waste","Reciclagem",""},{"Cl\195\173nica","Servi\195\167os",2,1,420,4,0,0,"clinic","Cl\195\173nica",""},{"Escola","Servi\195\167os",3,2,500,4,0,0,"school","Escola",""},{"Bombeiros","Servi\195\167os",2,2,430,4,0,0,"fire","Bombeiros",""},{"Posto policial","Servi\195\167os",2,2,400,3,0,0,"police","Posto policial",""},{"Administra\195\167\195\163o","Servi\195\167os",2,2,500,3,0,0,"admin","","Administra\195\167\195\163o"},{"Pra\195\167a e playground","Natureza",2,2,100,1,0,0,"park","Pra\195\167a e","playground"},{"Mirante","Natureza",2,1,140,1,0,4,"lookout","Mirante",""},{"Quiosque de praia","Natureza",1,1,120,1,0,8,"kiosk","Quiosque de","praia"},{"Cerca e port\195\163o","Natureza",1,1,15,0,0,0,"fence","Cerca e","port\195\163o"},{"Abrigo de animais","Natureza",2,2,320,3,0,16,"shelter","Abrigo de","animais"},{"Centro veterin\195\161rio","Natureza",3,2,650,5,0,32,"vet","Centro","veterin\195\161rio"}}
end)()
local Casters={}
local World=(function()

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
local building_info={[1]='Caminhos que acompanham o relevo',[2]='Passeios e rampas para pedestres',[3]='Conecta moradias e servi\195\167os',[4]='Uma via larga para sua cidade',[5]='Atravesse canais e margens baixas',[6]='Conecte duas margens com uma via',[7]='Ligue diferentes alturas da ilha',[8]='+2 de felicidade com acesso',[9]='Balsas: receita e felicidade',[10]='Porto: 85 de receita por dia',[25]='35 de energia para a ilha',[26]='60 de energia limpa',[27]='90 de energia limpa',[28]='\195\129gua para 150 moradores',[29]='Reciclagem para 150 moradores',[30]='Sa\195\186de para 100 moradores',[31]='Educa\195\167\195\163o para 100 moradores',[32]='Seguranca para 100 moradores',[33]='Seguranca para 100 moradores',[34]='20 de receita por dia',[35]='+4 de felicidade na ilha',[36]='+4 de felicidade na ilha',[38]='Delimite jardins e recintos'}
function W.describe(id)
    local d=Catalog[id]
    if d[7]>0 then return d[7]..' moradores com acesso vi\195\161rio' end
    if d[8]>0 then return d[8]..' de receita base por dia' end

    return building_info[id] or 'Cuidados e vida para sua ilha'
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
    local w={h={},base={},mask={},top={},occ={},road={},bid={},rot={},linked={},deco={},cash=3200,day=1,seed=seed,free=free,revision=0,undo={},reward=0,ticks=0}
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
    if x<0 or y<0 or x+nx>N or y+ny>N then return false,'Fora dos limites da ilha' end
    if not ignore_cost and not w.free and w.cash<W.price(w,id,x,y) then return false,'Faltam moedas. Espere a renda ou use o modo livre.' end
    local base=w.base[cell(x,y)];local bridge=id==5 or id==6;local v=0;local coast=false
    while v<ny do local u=0
        while u<nx do
            local k=cell(x+u,y+v);local mask=w.mask[k]
            if w.occ[k]>0 then
                if id<=3 and w.bid[k]>=1 and w.bid[k]<=3 then
                    if w.bid[k]==id then return false,'Esta via j\195\161 tem esse piso' end
                else return false,'Este espa\195\167o j\195\161 est\195\161 ocupado' end
            end
            if not bridge then
                if base<1 or w.base[k]~=base then return false,'Eleve e nivele o terreno primeiro' end
                if mask~=0 then
                    if id>3 and id~=7 then return false,'Esta constru\195\167\195\163o precisa de terreno plano' end
                    if mask~=3 and mask~=6 and mask~=9 and mask~=12 then return false,'Use Nivelar para criar uma rampa reta' end
                end
            elseif w.top[k]>1 then return false,'Pontes atravessam \195\161gua ou margens baixas' end
            if (x+u>0 and w.base[k-1]==0) or (x+u<N-1 and w.base[k+1]==0) or (y+v>0 and w.base[k-N]==0) or (y+v<N-1 and w.base[k+N]==0) then coast=true end
            u=u+1
        end
        v=v+1
    end
    if (id==9 or id==10 or id==37) and not coast then return false,'Escolha um terreno plano junto da \195\161gua' end
    return true,'Pronto para construir'
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
    W.rebuild(w);return true,Catalog[id][1]..': pronto!'
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
    if k==0 then return false,'Nada para remover aqui' end
    local id=w.bid[k];local snapshot=W.snapshot(w);snapshot.refund=w.free and 0 or -floor(Catalog[id][5]*3/4);W.record(w,snapshot);w.bid[k]=0;w.rot[k]=0
    if not w.free then w.cash=w.cash+floor(Catalog[id][5]*3/4) end
    W.rebuild(w);return true,'Removido. Reembolso de 75%.'
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
    if stroke then stroke.graph=g;stroke.visited=stroke.visited or {} end
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
                if (xx-x)*(xx-x)+(yy-y)*(yy-y)<=(radius+1)*(radius+1) then visits[vertex(xx,yy)]=true end
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
    W.rebuild(w);return true,'Relevo e funda\195\167\195\181es ajustados'
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
    {'A vida la fora','3 pra\195\167as ou mirantes e 2 com\195\169rcios',1000},
    {'Amigos de todas as esp\195\169cies','Tenha 6 animais e uma cl\195\173nica',1250},
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
    if not w.free and w.cash==0 and w.balance<0 then w.cash=300;return 'Fundo de apoio: +300 moedas para recuperar a ilha.' end
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
    local w={h={},base={},mask={},top={},occ={},road={},bid={},rot={},linked={},deco={},seed=values[2],free=values[3]==1,cash=values[4],day=values[5],reward=values[6],undo={},revision=0,ticks=0}
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
return W

end)()
local Lighting=(function()



local L={revision=-1,bin=-1}
local floor,min,max=math.floor,math.min,math.max
local R,N=8,192
local phases={'Ciclo natural','Manh\195\163','Golden hour','Noite'}
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
    local sun=(phase-.18)/.61
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

end)()
local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local S={screen='title',selection=1,category=1,item=1,tool='inspect',cx=11,cy=13,camx=11,camy=11,zoom=2,brush=1,rotation=0,time=0,skytime=0,light=1,elapsed=0,saveclock=0,toast='',toast_time=0,keys={},held={},sound=true,motion=true,contrast=false,slot=1,seed=2706,gesture=nil,detail=1}
local C={ink=0xF5E7C6FF,panel=0x182536FF,paper=0xF5E7C6FF,muted=0xA8B4BAFF,gold=0xD6B574FF,teal=0x99BCADFF,line=0x344354FF,red=0xE6A18CFF,dark=0x131F2DFF}
local categories={'Vias','Moradia','Com\195\169rcio','Servi\195\167os','Natureza'}
local ranges={{1,10},{11,16},{17,24},{25,34},{35,40}}
local tool_names={'Construir','Terreno','Remover','Desfazer'}
local tool_ids={'build','raise','remove','undo'}
local terrain_names={'Elevar','Baixar','Nivelar','Distorcer'}
local terrain_ids={'raise','lower','level','pull'}
local terrain_notes={'Pinte um n\195\173vel acima. As constru\195\167\195\181es sobem junto.','Pinte um n\195\173vel abaixo. As vias se acomodam.','Copie uma altura e pinte o terreno com as setas.','Segure a costa e puxe. As funda\195\167\195\181es acompanham.'}
local tool_notes={'Escolha uma pe\195\167a e coloque direto na ilha.','Molde morros, praias e enseadas.','Libere espa\195\167o e receba 75% do custo de volta.','Desfaca uma constru\195\167\195\163o, remocao ou gesto inteiro.'}
local brush_names={'pequeno','m\195\169dio','grande'}
local captions={inspect='Explore a ilha',raise='Elevar terreno',lower='Baixar terreno',level='Nivelar terreno',pull='Distorcer a costa',remove='Remover constru\195\167\195\163o',build='Construir'}
local function text(std,x,y,str,size,col,width,face)
    return Platform.text(x,y,tostring(str),size or 30,col or C.paper,width or max(40,1212-x),face or 'body')
end
local function title(std,x,y,str,size,col,width)
    return text(std,x,y,string.upper(str),size or 40,col or C.paper,width,'display')
end
local function paragraph(std,x,y,str,size,col,width)
    local row='';local yy=y
    for word in str:gmatch('%S+') do
        local nextrow=row=='' and word or row..' '..word
        if row~='' and Platform.text_width(nextrow,size,'body')>width then
            text(std,x,yy,row,size,col,width);row=word;yy=yy+size+6
        else row=nextrow end
    end
    if row~='' then text(std,x,yy,row,size,col,width) end
    return yy+size+6
end
local function box(std,x,y,w,h,col)
    if w>=40 and h>=32 then
        local kind=col==C.panel and 'panel' or col==C.dark and 'inset' or col==C.gold and 'focus' or col==C.line and 'button'
        if kind then Platform.skin(kind,x,y,w,h,col==C.gold,S.time,S.motion);return end
    end
    std.draw.color(col);std.draw.rect(0,x,y,w,h)
end
local function icon(name,x,y,scale) Platform.sprite('icon_'..name,x,y,scale or 2,1) end
local function line(std,x1,y1,x2,y2,col)
    std.draw.color(col);std.draw.line(x1,y1,x2,y2)
end
local function pill(std,x,y,label,focus,width)
    if focus and S.tab_focus and S.screen=='catalog' then Platform.skin('focus',x,y,width or 100,44,false,S.time,false) end
    text(std,x+12,y+6,label,28,focus and C.gold or C.muted,(width or 100)-20)
    if focus then std.draw.color(C.gold);std.draw.rect(0,x+12,y+39,(width or 100)-24,2) end
end
local function notify(msg,good)
    S.toast=msg;S.toast_time=3400;S.toast_good=good
    if S.sound then Platform.sound(good==false and 2 or 1) end
end
local function open(screen,selection)
    if screen=='new' and not S.preview then S.preview=World.new(S.seed,S.new_free or false) end
    S.screen=screen;S.selection=selection or 1;S.entered=S.time
    if screen=='load' then
        S.saved=S.saved or {};local i=1
        while i<=3 do
            local data=Platform.load(i);S.saved[i]=World.decode(data) or World.decode(Platform.backup(i)) or false;i=i+1
        end
    end
    if S.sound then Platform.sound(0) end
end
local function save_game(silent)
    if S.gesture then return end
    local ok=Platform.save(S.slot,World.encode(S.world))
    if not silent then notify(ok and 'Ilha salva. Pode voltar quando quiser.' or 'N\195\163o foi poss\195\173vel salvar neste dispositivo.',ok) end
    S.has_save=ok or S.has_save;S.saveclock=0
end
local function pos(x,y,z)
    local zoom=S.zoom
    return floor(S.ox+(x-y-S.camx+S.camy)*32*zoom),floor(S.oy+((x+y-S.camx-S.camy)*16-z)*zoom)
end
local function home_camera()
    local shift=S.world.base[World.cell(S.cx,S.cy)]/2
    S.camx=S.cx-shift;S.camy=S.cy-shift;S.world.dirty=true
end
local function road_sprite(w,i,id)
    local mask=w.mask[i]
    if mask~=0 then
        local dir=mask==3 and 'N' or mask==6 and 'E' or mask==12 and 'S' or 'W'
        return 'ramp'..id..'_'..dir
    end
    local x=(i-1)%24;local y=floor((i-1)/24);local bits=0
    local nx,ny=World.footprint(id,w.rot[i]);local u=0
    while u<nx do
        if y>0 and w.occ[World.cell(x+u,y-1)]>0 and bits%2==0 then bits=bits+1 end
        if y+ny<24 and w.occ[World.cell(x+u,y+ny)]>0 and floor(bits/4)%2==0 then bits=bits+4 end
        u=u+1
    end
    local v=0
    while v<ny do
        if x+nx<24 and w.occ[World.cell(x+nx,y+v)]>0 and floor(bits/2)%2==0 then bits=bits+2 end
        if x>0 and w.occ[World.cell(x-1,y+v)]>0 and floor(bits/8)%2==0 then bits=bits+8 end
        v=v+1
    end
    if bits==0 then bits=10 end
    return 'road'..id..'_'..bits
end
local function render_world(std)
    local w=(S.screen=='new' or S.screen=='confirm') and S.preview or S.world
    if S.rendered_world~=w then w.dirty=true;S.rendered_world=w end
    S.phase=S.screen=='title' and .68 or Lighting.phase(S.light,S.skytime)
    if Lighting.update(w,S.phase,S.detail) then w.dirty=true end
    if w.dirty then
        Platform.cache_begin(table.concat(w.h,','),S.camx,S.camy,S.zoom,S.ox,S.oy,w.revision);S.visible=0
        local scene=S.scene or {};S.scene=scene;local sn=0;local si=1
        while si<=576 do
            local id=w.bid[si];local x=(si-1)%24;local y=floor((si-1)/24);local key
            if id>4 then key='b'..id..'_'..w.rot[si]
            elseif id==0 and w.occ[si]==0 and w.deco[si]>0 and w.base[si]>0 and w.mask[si]==0 and S.detail==1 then
                key=(w.base[si]==1 and 'palm' or 'tree')..(w.deco[si]-1)
            end
            if key then sn=sn+1;scene[sn]=key..','..x..','..y..','..(World.elevation(w,id,x,y,w.rot[si])*16)..',0' end
            if id==3 and (x+y)%4==0 and w.mask[si]==0 then
                sn=sn+1;scene[sn]='lamp,'..x..','..y..','..(w.base[si]*16)..','..(w.linked[si] and w.power>=w.need and '1' or '0')
            end
            si=si+1
        end
        Platform.scene(table.concat(scene,';',1,sn),S.phase,S.detail)
        S.flies=S.flies or {};local flies=S.flies;local fly_count=0
        local commands=w.drawlist;local n=1
        while n<=#commands do
            local command=commands[n]%4096;local kind=floor(command/1024);local i=command%1024
            local x=(i-1)%24;local y=floor((i-1)/24);local id=w.bid[i]
            local base=kind==2 and id>0 and World.elevation(w,id,x,y,w.rot[i]) or w.base[i];local sx,sy=pos(x,y,base*16)
            if sx>-280 and sx<1560 and sy>-180 and sy<960 then
                if kind==0 then
                    local coast=w.base[i]==0 or (w.base[i]==1 and ((x>0 and w.base[i-1]==0) or (y>0 and w.base[i-24]==0) or (x<23 and w.base[i+1]==0) or (y<23 and w.base[i+24]==0)))
                    local key=(coast and 'sand' or 'grass')..w.mask[i]..'_'..((x*7+y*11+w.seed)%6)
                    Platform.sprite(key,sx,sy,S.zoom,1);S.visible=S.visible+1
                    if not (w.occ[i]>0 and w.bid[w.occ[i]]<=4) then Platform.shadow(Lighting.masks[i],sx,sy,S.zoom,w.mask[i],Lighting.R,x,y) end
                    Platform.ground_light(x,y,sx,sy,S.zoom,w.mask[i])
                elseif kind==1 then
                    Platform.shadow(Lighting.masks[i],sx,sy,S.zoom,0,Lighting.R,x,y)
                    Platform.ground_light(x,y,sx,sy,S.zoom,0)
                elseif id>0 then
                    local key=id<=4 and road_sprite(w,i,id) or 'b'..id..'_'..w.rot[i]
                    if id==7 then local m=w.mask[i];key=m==0 and 'road2_10' or 'b7_'..(m==12 and 0 or m==9 and 1 or m==3 and 2 or 3) end
                    local powered=w.linked[i] and w.power>=w.need
                    Platform.sprite(key,sx,sy,S.zoom,1,powered)
                    if id<=4 then
                        local nx,ny=World.footprint(id,w.rot[i]);local v=0
                        while v<ny do local u=0
                            while u<nx do
                                local k=World.cell(x+u,y+v);local px,py=pos(x+u,y+v,w.base[k]*16)
                                Platform.shadow(Lighting.masks[k],px,py,S.zoom,w.mask[k],Lighting.R,x+u,y+v)
                                Platform.ground_light(x+u,y+v,px,py,S.zoom,w.mask[k]);u=u+1
                            end;v=v+1
                        end
                    end
                    if id==3 and (x+y)%4==0 and w.mask[i]==0 then Platform.sprite('lamp',sx,sy,S.zoom,1,powered) end
                elseif S.detail==1 then
                    Platform.sprite((w.base[i]==1 and 'palm' or 'tree')..(w.deco[i]-1),sx,sy,S.zoom,1)
                    if fly_count<6 and w.base[i]>1 then fly_count=fly_count+1;flies[fly_count*2-1]=sx;flies[fly_count*2]=sy end
                end
            end
            n=n+1
        end
        S.fly_count=fly_count;Platform.cache_end();w.dirty=false
    end
    Platform.world(S.phase,S.time,S.motion)
    Platform.effects(S.time,S.motion)
    if S.motion and S.phase>.2 and S.phase<.8 then

        local k=0
        while k<3 do
            local x=(S.time/85+k*417)%1370-45;local y=155+k*115+math.sin(S.time/1800+k)*13
            line(std,x-7,y+2,x-2,y,C.paper);line(std,x-2,y,x+3,y+2,C.paper);k=k+1
        end
    elseif S.motion and S.detail==1 then
        local k=1
        while k<=(S.fly_count or 0) do
            if math.sin(S.time/900+k*1.7)>.15 then
                local x=S.flies[k*2-1]+floor(math.sin(S.time/2100+k)*18)*2
                local y=S.flies[k*2]-14+floor(math.cos(S.time/1800+k)*8)*2
                box(std,x,y,4,4,C.gold)
            end;k=k+1
        end
    end
end
local function ornament(std,x,y,w)
    line(std,x,y,x+w,y,C.line)
    line(std,x,y,x+min(w,80),y,C.gold)
    box(std,x-3,y-3,6,6,C.gold)
end
local function frame(std,label,sub)
    box(std,0,0,1280,720,0x101923EC)
    title(std,76,48,label,40)
    if sub then text(std,78,104,sub,28,C.muted,1120) end
    ornament(std,78,150,1122)
end
local function footer(std,hint)
    line(std,78,630,1200,630,C.line)
    text(std,78,650,hint,26,C.muted,1122)
end
local function menu_button(std,x,y,w,label,sub,focus,glyph)
    local h=sub and 94 or 62
    if focus then
        Platform.skin('focus',x,y,w,h,false,S.time,false)
        box(std,x+4,y+18,4,h-36,C.gold)
    else
        line(std,x+20,y+h-2,x+w-20,y+h-2,C.line)
    end
    if glyph then icon(glyph,x+22,y+12,1) end
    local tx=x+(glyph and 68 or 26)
    text(std,tx,y+(sub and 12 or 15),label,32,focus and C.paper or C.muted,w-(glyph and 96 or 58))
    if sub then text(std,x+26,y+52,sub,26,C.muted,w-58) end
end
local function title_draw(std)
    box(std,0,0,532,720,0x101923EF)
    title(std,78,78,'MAR\195\137',96,C.paper,432)
    ornament(std,82,180,354)
    text(std,82,208,'Seu mundo, no seu ritmo.',30,C.muted,400)
    local items={'Continuar','Nova ilha','Como jogar','Ajustes'}
    local n=1
    while n<=4 do
        menu_button(std,66,302+(n-1)*72,398,items[n],nil,S.selection==n)
        n=n+1
    end
    text(std,84,644,'SETAS escolher   OK entrar',26,C.muted,400)
    title(std,962,54,'MAR ABERTO',16,C.paper,246)
end
local function header(std)
    local w=S.world

    box(std,48,32,1184,82,C.panel)
    title(std,74,46,'DIA '..w.day,20,C.muted,144)
    text(std,74,73,w.free and 'Modo livre' or 'Jornada',26,C.paper,140)
    icon('coin',246,54,1);text(std,286,45,w.free and 'Livre' or w.cash,34,C.gold,190)
    text(std,286,82,'moedas',22,C.muted)
    icon('people',472,54,1);text(std,512,45,w.population,34,C.paper,174)
    text(std,512,82,'moradores',22,C.muted)
    icon('power',708,54,1);text(std,746,45,w.power..' / '..w.need,34,w.power>=w.need and C.teal or C.red,188)
    text(std,746,82,'energia',22,C.muted)
    icon('happy',978,54,1);text(std,1018,45,w.happy..'%',34,C.paper,166)
    text(std,1018,82,'felicidade',22,C.muted)
end
local function terrain_tool()
    return S.tool=='raise' or S.tool=='lower' or S.tool=='level' or S.tool=='pull'
end
local function ground_pos(x,y)
    x=max(0,min(24,x));y=max(0,min(24,y))
    local xx=min(23,floor(x));local yy=min(23,floor(y));local u=x-xx;local v=y-yy
    local k=yy*25+xx+1;local h=S.world.h;local a,b,c,d=h[k],h[k+1],h[k+26],h[k+25]
    local z=u>=v and a+u*(b-a)+v*(c-b) or a+u*(c-d)+v*(d-a)
    return pos(x,y,z*16)
end

local brush_ring={};local ring_i=0
while ring_i<=48 do local angle=ring_i*math.pi/24;brush_ring[ring_i*2+1]=math.cos(angle);brush_ring[ring_i*2+2]=math.sin(angle);ring_i=ring_i+1 end
local function brush_draw(std)
    local pulling=S.gesture and S.tool=='pull'
    local cx=pulling and S.gx or S.cx;local cy=pulling and S.gy or S.cy
    local radius=S.brush+1;local lastx,lasty;local n=0
    while n<=48 do

        local xx=cx+brush_ring[n*2+1]*radius
        local yy=cy+brush_ring[n*2+2]*radius
        local x,y=ground_pos(xx,yy)
        if lastx then line(std,lastx,lasty+2,x,y+2,C.dark);line(std,lastx,lasty,x,y,C.gold) end
        lastx=x;lasty=y;n=n+1
    end
    local x,y=ground_pos(cx,cy)
    line(std,x-6,y,x+6,y,C.paper);line(std,x,y-4,x,y+4,C.paper)
    if pulling then
        local tx,ty=ground_pos(S.cx,S.cy);line(std,x,y,tx,ty,C.gold)
        box(std,tx-4,ty-3,8,6,C.paper)
    end
end
local function selection_draw(std)
    if terrain_tool() then brush_draw(std);return end
    local w=S.world;local i=World.cell(S.cx,S.cy);local nx,ny=1,1
    if S.tool=='build' then nx,ny=World.footprint(S.build_id,S.rotation) end
    local good=true
    if S.tool=='build' then good=(S.paint and w.bid[i]==S.build_id) or World.valid(w,S.build_id,S.cx,S.cy,S.rotation)
    elseif S.tool=='remove' then good=w.occ[i]>0 end
    local col=good and C.gold or C.red
    local x0=S.cx;local y0=S.cy
    local v=0
    while v<ny do local u=0
        while u<nx do
            local xx=x0+u;local yy=y0+v
            if xx>=0 and yy>=0 and xx<24 and yy<24 then
                local k=World.cell(xx,yy);local h=w.base[k]*16;local mask=w.mask[k]
                local a,b=pos(xx,yy,h+(mask%2>=1 and 16 or 0));local c,d=pos(xx+1,yy,h+(floor(mask/2)%2==1 and 16 or 0))
                local e,f=pos(xx+1,yy+1,h+(floor(mask/4)%2==1 and 16 or 0));local g,j=pos(xx,yy+1,h+(floor(mask/8)%2==1 and 16 or 0))
                line(std,a,b,c,d,col);line(std,c,d,e,f,col);line(std,e,f,g,j,col);line(std,g,j,a,b,col)
                line(std,a,b+1,c,d+1,col);line(std,c,d+1,e,f+1,col)
            end
            u=u+1
        end;v=v+1
    end
    local sx,sy=pos(S.cx,S.cy,(S.tool=='build' and World.elevation(w,S.build_id,S.cx,S.cy,S.rotation) or w.base[i])*16)
    if S.tool=='build' then
        local id=S.build_id;local key=id<=4 and road_sprite(w,i,id) or 'b'..id..'_'..S.rotation
        Platform.sprite(key,sx,sy,S.zoom,good and 65/100 or 35/100)
    end
    box(std,sx-5,sy-9,10,6,col)
end
local function play_draw(std)
    selection_draw(std);header(std)
    local w=S.world;local i=World.cell(S.cx,S.cy);local id=w.occ[i]>0 and w.bid[w.occ[i]] or 0
    box(std,48,580,1184,100,C.panel)
    local label=S.tool=='build' and Catalog[S.build_id][1] or S.tool=='inspect' and id>0 and Catalog[id][1] or captions[S.tool]
    if S.tool=='level' and S.stroke then label='Nivelar: '..(S.stroke.target==0 and 'altura do mar' or 'altura '..S.stroke.target) end
    text(std,76,594,label,32,C.paper,890)
    local msg='SETAS explorar    OK criar    VOLTAR pausa'
    local color=C.muted
    if S.tool=='build' then
        local good,reason=World.valid(w,S.build_id,S.cx,S.cy,S.rotation)
        msg=good and ('OK construir  /  '..World.price(w,S.build_id,S.cx,S.cy)..' moedas  /  VOLTAR op\195\167\195\181es') or (reason..'  /  VOLTAR op\195\167\195\181es')
        color=good and C.muted or C.red
        if S.paint then
            msg=S.gesture and 'SETAS tracar    OK terminar    VOLTAR cancelar' or 'OK comecar via    VOLTAR op\195\167\195\181es'
            color=S.gesture and C.gold or C.muted
        end
    elseif S.tool=='inspect' and id>0 then
        msg=(w.linked[w.occ[i]] and 'Acesso vi\195\161rio' or 'Precisa de uma via ao lado')..'    OK criar    VOLTAR pausa'
    elseif S.gesture then
        msg=S.tool=='pull' and 'SETAS puxar    OK soltar    VOLTAR cancelar' or 'SETAS pintar    OK concluir    VOLTAR cancelar';color=C.gold
    elseif S.tool~='inspect' then
        msg=S.tool=='remove' and 'OK remover e recuperar 75%    VOLTAR explorar' or ((S.tool=='pull' and 'OK segurar' or S.tool=='level' and 'OK copiar altura' or 'OK comecar')..'    Pincel '..brush_names[S.brush]..'    VOLTAR op\195\167\195\181es')
    end
    text(std,76,635,msg,26,color,1110)
    text(std,1006,600,(w.balance>=0 and '+' or '')..w.balance..' / dia',26,w.balance>=0 and C.teal or C.red,190)
    if S.tool=='inspect' and w.reward<5 then
        local ready=World.goal_ready(w)
        box(std,48,134,396,80,C.panel)
        text(std,70,147,ready and 'Conquista pronta!' or World.goals[w.reward+1][1],24,C.gold,352)
        text(std,70,180,ready and 'VOLTAR > Di\195\161rio para receber' or (floor(World.progress(w)*100)..'%  /  Di\195\161rio na pausa'),22,C.muted,336)
        box(std,70,204,332,2,C.line);box(std,70,204,max(2,floor(332*World.progress(w))),2,C.gold)
    end
end

local function dock(std,heading,names,icons,note,back)
    header(std);box(std,48,icons and 410 or 470,1184,icons and 270 or 210,C.panel)
    title(std,80,icons and 432 or 488,heading,32,C.paper,1080)
    text(std,80,icons and 480 or 530,note,26,C.muted,1090)
    local width=floor(1104/#names);local n=1
    while n<=#names do
        local x=80+(n-1)*width;local focus=S.selection==n
        if focus then box(std,x,icons and 526 or 572,width-14,icons and 84 or 48,C.gold) end
        if icons then icon(icons[n],x+14,540,1) end
        text(std,x+14,icons and 568 or 576,names[n],28,focus and C.paper or C.muted,width-40)
        n=n+1
    end
    footer(std,'SETAS escolher    OK usar    VOLTAR '..back)
end
local function toolbar_draw(std)
    local note=tool_notes[S.selection]
    if S.selection==4 then note=#S.world.undo>0 and ('Desfazer disponivel: '..#S.world.undo..' a\195\167\195\181es. O gesto inteiro volta.') or 'Nada para desfazer ainda.' end
    dock(std,'O que vamos criar?',tool_names,tool_ids,note,'explorar')
end
local function terrain_draw(std)
    dock(std,'Moldar a ilha',terrain_names,terrain_ids,terrain_notes[S.selection],'ferramentas')
end
local function context_draw(std)
    selection_draw(std)
    local names,heading,note
    if S.tool=='build' then
        heading=Catalog[S.build_id][1]
        if S.paint then names={'Trocar via','Concluir'};note='Cada tra\195\167ado pode ser desfeito de uma vez.'
        else names={'Girar pe\195\167a','Trocar pe\195\167a','Concluir'};note=S.selection==1 and 'OK gira 90 graus e volta para a ilha.' or S.selection==2 and 'Escolha outra pe\195\167a. A ilha fica como esta.' or 'Volte a explorar a ilha.' end
    else
        heading=captions[S.tool];names={'Pincel: '..brush_names[S.brush],'Trocar ferramenta','Concluir'}
        note=S.selection==1 and 'OK muda o tamanho. A terra leva as constru\195\167\195\181es junto.' or S.selection==2 and 'Troque entre elevar, baixar, nivelar e distorcer.' or 'Volte a explorar a ilha.'
    end
    dock(std,heading,names,nil,note,'explorar')
end
local function catalog_draw(std)
    frame(std,'Construir','Escolha o que vai fazer parte da sua ilha.')
    local cat=1
    while cat<=5 do pill(std,78+(cat-1)*224,170,categories[cat],S.category==cat,210);cat=cat+1 end
    local range=ranges[S.category];local count=range[2]-range[1]+1;local page=floor((S.item-1)/6);local n=page*6+1
    while n<=min(count,page*6+6) do
        local id=range[1]+n-1;local d=Catalog[id];local index=n-page*6-1;local x=78+(index%3)*238;local y=234+floor(index/3)*182;local focus=S.item==n and not S.tab_focus
        box(std,x,y,222,166,focus and C.gold or C.line)
        local key=id<=4 and 'road'..id..'_10' or 'b'..id..'_0'
        Platform.thumb(key,x+111,y+42,186,76)
        text(std,x+16,y+82,d[10],26,focus and C.paper or C.muted,194)
        text(std,x+16,y+108,d[11],26,focus and C.paper or C.muted,194)
        text(std,x+16,y+131,d[5]..'  /  '..d[3]..'x'..d[4],22,C.gold,190)
        n=n+1
    end
    local id=range[1]+S.item-1;local d=Catalog[id]
    line(std,812,234,812,590,C.line)
    title(std,842,242,'SELECIONADO',18,C.gold,350)
    Platform.thumb(id<=4 and 'road'..id..'_10' or 'b'..id..'_0',1018,376,348,186)
    text(std,842,488,d[3]..' x '..d[4]..' terrenos',28,C.paper,352)
    text(std,842,528,'Custo: '..d[5]..' moedas',28,C.gold,352)
    text(std,842,564,d[6]..' moedas / dia',26,C.muted,352)
    text(std,80,600,World.describe(id),24,C.teal,960)
    text(std,1100,600,(page+1)..' / '..math.ceil(count/6),24,C.muted,100)
    footer(std,S.tab_focus and 'ESQUERDA / DIREITA categorias    OK ver constru\195\167\195\181es    VOLTAR' or 'SETAS escolher    CIMA categorias    OK colocar    VOLTAR')
end
local function pause_draw(std)
    frame(std,'Um respiro','Sua ilha fica guardada enquanto voc\195\170 faz uma pausa.')
    local opts={'Continuar jogando','Salvar a ilha','Di\195\161rio da ilha','Ajustes','Como jogar','Contemplar a ilha','Salvar e ir ao inicio'}
    local n=1;while n<=7 do
        menu_button(std,78,168+(n-1)*64,572,opts[n],nil,S.selection==n);n=n+1
    end
    Platform.minimap(722,234,420)
    title(std,766,474,'ILHA '..S.slot,24,C.gold,380)
    text(std,766,520,'Dia '..S.world.day..'  /  '..S.world.population..' moradores',28,C.paper,380)
    text(std,766,564,S.world.free and 'Modo livre' or 'Jornada',26,C.muted,380)
    footer(std,'SETAS escolher    OK confirmar    VOLTAR continuar')
end
local function settings_draw(std)
    frame(std,'Ajustes','Deixe a ilha confort\195\161vel para voc\195\170.')
    local opts={'Som: '..(S.sound and 'ligado' or 'desligado'),'Movimento: '..(S.motion and 'ligado' or 'reduzido'),'Detalhes: '..(S.detail==1 and 'completos' or 'econ\195\180micos'),'Zoom: '..S.zoom..'x','Luz: '..Lighting.names[S.light],'Concluir'}
    local notes={'Sons curtos ao navegar e construir.','Reduz ondas, passaros e animacoes.','Ajusta vegetacao e custo das sombras.','Pixels inteiros nas duas distancias.','Escolha um momento do dia.','Salva as preferencias neste dispositivo.'}
    local n=1;while n<=6 do menu_button(std,78,170+(n-1)*74,680,opts[n],nil,S.selection==n);n=n+1 end
    icon(S.phase>.8 and 'moon' or 'sun',934,250,3)
    paragraph(std,808,384,notes[S.selection],28,C.paper,380)
    text(std,808,468,'Manh\195\163, p\195\180r do sol',28,C.muted,380)
    text(std,808,504,'e luzes da noite.',28,C.muted,380)
    footer(std,'SETAS escolher    OK alterar    VOLTAR concluir')
end
local help_pages={
    {'Sua ilha, seu ritmo','Setas movem o cursor pelas diagonais da ilha.','OK abre \195\160s ferramentas durante a exploracao.','Voltar cancela gestos ou abre op\195\167\195\181es da pe\195\167a.','Ao explorar, Voltar abre a pausa e o di\195\161rio.'},
    {'Moldar a terra','Elevar e Baixar: OK, setas para pintar, OK.','Nivelar: OK copia a altura; setas pintam nela.','Distorcer: OK segura; setas puxam; OK solta.','Casas sobem e descem; vias ganham rampas.'},
    {'Fazer a ilha crescer','Casas e lojas precisam de uma via ao lado.','Geradores e usinas precisam de acesso vi\195\161rio.','Energia e servi\195\167os atendem a ilha inteira.','Pra\195\167as e servi\195\167os melhoram a felicidade.'},
    {'Experimentar','Um dia passa a cada 12 segundos de partida.','Troque o piso de vias pagando a diferen\195\167a.','Remover devolve 75%; Desfazer recupera tudo.','No modo livre, construa sem limite de moedas.'},
    {'Pontes e praias','Pontes ocupam \195\161gua ou margens na altura 1.','Portos e quiosques precisam ficar junto da \195\161gua.','Rampas retas aceitam trilhas, passeios e ruas.','Abrigos de animais atraem visitas para a ilha.'}
}

local function help_draw(std)
    local p=help_pages[S.selection];frame(std,p[1],'GUIA DE BOLSO  /  '..S.selection..' DE '..#help_pages)
    local n=2;while n<=5 do
        pill(std,84,186+(n-2)*94,tostring(n-1),true,46)
        text(std,155,190+(n-2)*94,p[n],32,C.paper,1030);n=n+1
    end
    footer(std,'ESQUERDA / DIREITA  p\195\161ginas     OK ou VOLTAR  fechar')
end
local function goals_draw(std)
    local w=S.world;frame(std,'Di\195\161rio da ilha',w.free and 'MODO LIVRE  /  Sem limites para experimentar' or 'JORNADA  /  Cada conquista abre novas possibilidades')
    local g=min(5,w.reward+1);local goal=World.goals[g]
    box(std,82,180,654,180,C.line)
    text(std,104,200,w.reward>=5 and 'A ilha \195\169 toda sua.' or goal[1],32,C.gold)
    text(std,104,250,w.reward>=5 and 'Todas as conquistas foram completadas.' or goal[2],26)
    text(std,104,306,w.reward>=5 and 'Continue criando, sem um fim obrigat\195\179rio.' or ('Recompensa: '..goal[3]..' moedas'),23,C.muted)
    menu_button(std,82,387,654,World.goal_ready(w) and 'Receber conquista' or 'Continuar explorando',nil,true)
    text(std,82,484,'Conquistas: '..w.reward..' / 5',26,C.muted)
    text(std,82,528,'Animais: '..w.animals..'    Pra\195\167as: '..w.parks..'    Lojas: '..w.shops,25,C.muted)
    text(std,795,190,'A CIDADE EM N\195\154MEROS',21,C.gold)
    local rows={{'Receita por dia',w.revenue},{'Manuten\195\167\195\163o',w.upkeep},{'Saldo por dia',w.balance},{'\195\129gua / pessoas',w.water..' / '..w.population},{'Sa\195\186de / pessoas',w.health..' / '..w.population},{'Educa\195\167\195\163o / pessoas',w.school..' / '..w.population}}
    local n=1;while n<=#rows do
        text(std,795,239+(n-1)*57,rows[n][1],20,C.muted);text(std,1070,236+(n-1)*57,rows[n][2],24);n=n+1
    end
    footer(std,'OK receber ou explorar    VOLTAR pausa')
end
local function new_draw(std)
    frame(std,'Nova ilha','Escolha a paisagem e o ritmo da partida.')
    local opts={'Jornada: construir e prosperar','Modo livre: criar sem custos','Paisagem: semente '..S.seed,'Arquivo: ilha '..S.slot,'Criar esta ilha'}
    local n=1;while n<=5 do
        menu_button(std,84,179+(n-1)*83,776,opts[n],nil,S.selection==n)
        if n==1 and not S.new_free or n==2 and S.new_free then icon('check',792,194+(n-1)*83,1) end
        n=n+1
    end
    line(std,878,180,878,595,C.line)
    Platform.minimap(896,225,284)
    text(std,910,434,'Sua paisagem',22,C.gold)
    text(std,910,482,'40 constru\195\167\195\181es',23,C.muted)
    text(std,910,524,'5 conquistas',23,C.muted)
    text(std,910,565,'3 ilhas salvas',21,C.muted)
    footer(std,'OK escolher    VOLTAR inicio    Confirme a criacao no final')
end
local function confirm_draw(std)
    frame(std,'Substituir esta ilha?','O arquivo '..S.slot..' j\195\161 tem uma ilha salva.')
    text(std,86,204,'Seu novo mundo vai ocupar este arquivo.',30)
    text(std,86,266,'Os outros dois arquivos ficam guardados.',26,C.muted)
    menu_button(std,84,380,538,'Escolher outro arquivo',nil,S.selection==1)
    menu_button(std,84,474,538,'Substituir e criar a nova ilha',nil,S.selection==2)
    footer(std,'SETAS  escolher     OK  confirmar     VOLTAR  cancelar')
end
local function load_draw(std)
    frame(std,'Suas ilhas','Tres pequenos mundos, guardados neste dispositivo.')
    local n=1;while n<=3 do
        local data=Platform.load(n);local w=S.saved[n]
        menu_button(std,84,191+(n-1)*127,1108,'Ilha '..n,w and ('Dia '..w.day..'  /  '..w.population..' moradores  /  '..(w.free and 'Modo livre' or 'Jornada')) or (#data>0 and 'Arquivo inv\195\161lido. Escolha outra ilha.' or 'Este arquivo est\195\161 vazio'),S.selection==n);n=n+1
    end
    footer(std,'SETAS  escolher     OK  continuar     VOLTAR  inicio')
end
local function start_game()
    S.world=S.preview or World.new(S.seed,S.new_free or false);S.world.free=S.new_free or false;S.preview=nil;S.cx=11;S.cy=13;S.zoom=S.preferred_zoom or 2;S.ox=640;S.oy=375;home_camera();S.tool='inspect';S.gesture=nil;S.stroke=nil;S.elapsed=0;S.skytime=0
    open('play');save_game(true);notify('Bem-vindo a sua ilha! OK abre \195\160s ferramentas.',true)
end
local function follow_cursor()
    local sx,sy=ground_pos(S.cx,S.cy);local margin=terrain_tool() and (S.brush+1)*46*S.zoom or 112
    if sx<48+margin or sx>1232-margin or sy<150+margin/2 or sy>550-margin/2 then home_camera() end
end
local function move_cursor(dx,dy)
    if S.toast_good==false then S.toast_time=0 end
    local nx=max(0,min(23,S.cx+dx));local ny=max(0,min(23,S.cy+dy))
    if nx==S.cx and ny==S.cy then return end
    if S.gesture then
        if S.tool=='build' and S.paint then
            S.cx=nx;S.cy=ny;local ok,msg=World.paint(S.world,S.build_id,nx,ny);if not ok then notify(msg,false) end
        elseif S.tool=='pull' then
            nx=max(S.gx-S.brush-1,min(S.gx+S.brush+1,nx));ny=max(S.gy-S.brush-1,min(S.gy+S.brush+1,ny))
            S.cx=nx;S.cy=ny
            local ok,msg=World.terraform(S.world,'pull',S.gx,S.gy,S.brush,S.gesture,nx-S.gx,ny-S.gy)
            if not ok then notify(msg,false) end
        else
            S.cx=nx;S.cy=ny
            World.terraform(S.world,S.tool,nx,ny,S.brush,S.gesture,0,0,S.stroke)
        end
        follow_cursor();return
    end
    S.cx=nx;S.cy=ny;follow_cursor()
end
local function changed(snapshot)
    local w=S.world;local i=1
    while i<=625 do if snapshot.h[i]~=w.h[i] then return true end;i=i+1 end
    i=1;while i<=576 do if snapshot.bid[i]~=w.bid[i] or snapshot.rot[i]~=w.rot[i] then return true end;i=i+1 end
    return false
end
local function finish_edit(snapshot,label)
    if not changed(snapshot) then notify('Nenhuma alteracao neste gesto.',true);return end
    snapshot.refund=snapshot.cash-S.world.cash;World.record(S.world,snapshot);notify(label,true);follow_cursor()
    local x,y=pos(S.cx,S.cy,S.world.base[World.cell(S.cx,S.cy)]*16);Platform.burst(x,y,true)
end
local function explore()
    S.tool='inspect';open('play')
end
local function catalog_open()
    S.tab_focus=false;open('catalog')
end
local function act(key)
    local screen=S.screen;local delta=key=='down' and 1 or key=='up' and -1 or 0
    if screen~='play' and screen~='view' and (delta~=0 or key=='left' or key=='right') and S.sound and S.time-(S.focus_sound or -100)>70 then
        S.focus_sound=S.time;Platform.sound(0)
    end
    if screen=='view' then
        if key=='a' then S.light=S.light%4+1;Platform.options(S.sound,S.motion,S.detail,S.preferred_zoom or 2,S.light)
        elseif key=='menu' then S.zoom=S.view_zoom;home_camera();open('pause',6) end
        return
    end
    if screen=='play' then
        if key=='left' then move_cursor(-1,0) elseif key=='right' then move_cursor(1,0) elseif key=='up' then move_cursor(0,-1) elseif key=='down' then move_cursor(0,1)
        elseif key=='menu' then
            if S.gesture then World.restore(S.world,S.gesture);S.cx=S.gx;S.cy=S.gy;S.gesture=nil;S.stroke=nil;follow_cursor();notify('Gesto cancelado.',true)
            elseif S.tool=='inspect' then open('pause')
            elseif S.tool=='remove' then explore()
            else open('context') end
        elseif key=='a' then
            if S.tool~='inspect' then S.toast_time=0 end
            if S.tool=='inspect' then open('tools',S.tool_focus or 1)
            elseif S.tool=='build' then
                if S.paint then
                    if S.gesture then finish_edit(S.gesture,'Via pronta.');S.gesture=nil
                    else S.gesture=World.snapshot(S.world);S.gx=S.cx;S.gy=S.cy;local ok,msg=World.paint(S.world,S.build_id,S.cx,S.cy);if not ok then S.gesture=nil;notify(msg,false) end end
                else local ok,msg=World.build(S.world,S.build_id,S.cx,S.cy,S.rotation);notify(msg,ok);if ok then local x,y=pos(S.cx,S.cy,S.world.base[World.cell(S.cx,S.cy)]*16);Platform.burst(x,y,true) end end
            elseif S.tool=='remove' then local ok,msg=World.remove(S.world,S.cx,S.cy);notify(msg,ok);if ok then local x,y=pos(S.cx,S.cy,S.world.base[World.cell(S.cx,S.cy)]*16);Platform.burst(x,y,false) end
            elseif S.tool=='pull' then
                if S.gesture then finish_edit(S.gesture,'Costa redesenhada.');S.gesture=nil
                else S.gesture=World.snapshot(S.world);S.gx=S.cx;S.gy=S.cy end
            else
                if S.gesture then finish_edit(S.gesture,'Relevo e constru\195\167\195\181es ajustados.');S.gesture=nil;S.stroke=nil
                else
                    S.gesture=World.snapshot(S.world);S.gx=S.cx;S.gy=S.cy
                    S.stroke={target=S.gesture.h[S.cy*25+S.cx+1]}
                    if S.tool~='level' then World.terraform(S.world,S.tool,S.cx,S.cy,S.brush,S.gesture,0,0,S.stroke);follow_cursor() end
                end
            end
        end
        return
    end
    if screen=='tools' or screen=='terrain' or screen=='context' then
        local count=screen=='context' and (S.tool=='build' and S.paint and 2 or 3) or 4
        if key=='menu' then
            if screen=='terrain' then open('tools',2) else explore() end
        elseif key=='left' or key=='up' then S.selection=max(1,S.selection-1)
        elseif key=='right' or key=='down' then S.selection=min(count,S.selection+1)
        elseif key=='a' then
            local n=S.selection
            if screen=='tools' then
                S.tool_focus=n
                if n==1 then catalog_open()
                elseif n==2 then open('terrain',S.terrain_focus or 1)
                elseif n==3 then S.tool='remove';open('play')
                else local ok=World.undo(S.world);notify(ok and '\195\154ltima a\195\167\195\163o desfeita.' or 'Nada para desfazer ainda.',ok);if ok then explore() end end
            elseif screen=='terrain' then S.terrain_focus=n;S.tool=terrain_ids[n];follow_cursor();open('play')
            elseif n==count then explore()
            elseif S.tool=='build' then
                if n==1 and not S.paint then S.rotation=(S.rotation+1)%4;open('play') else catalog_open() end
            elseif n==1 then S.brush=S.brush%3+1;follow_cursor();open('play')
            else open('terrain',S.terrain_focus or 1) end
        end
        return
    end
    if screen=='catalog' then
        local count=ranges[S.category][2]-ranges[S.category][1]+1
        if key=='menu' then open('tools',1)
        elseif S.tab_focus then
            if key=='left' then S.category=(S.category+3)%5+1;S.item=1
            elseif key=='right' then S.category=S.category%5+1;S.item=1
            elseif key=='down' or key=='a' then S.tab_focus=false end
        elseif key=='right' then S.item=min(count,S.item+1)
        elseif key=='left' then S.item=max(1,S.item-1)
        elseif key=='down' then S.item=min(count,S.item+3)
        elseif key=='up' then if S.item<=3 then S.tab_focus=true else S.item=S.item-3 end
        elseif key=='a' then S.build_id=ranges[S.category][1]+S.item-1;S.rotation=0;S.tool='build';S.paint=S.build_id<=3;open('play') end
        return
    end
    if screen=='help' then
        if key=='left' then S.selection=max(1,S.selection-1) elseif key=='right' then S.selection=min(#help_pages,S.selection+1)
        elseif key=='a' or key=='menu' then open(S.return_to or 'title',S.return_selection) end;return
    end
    if screen=='goals' then
        if key=='a' then if World.claim(S.world) then notify('Conquista recebida! Sua ilha esta crescendo.',true) else explore() end
        elseif key=='menu' then open('pause',3) end;return
    end
    local lengths={title=4,new=5,confirm=2,load=3,pause=7,settings=6}
    local count=lengths[screen] or 1
    if delta~=0 then S.selection=(S.selection-1+delta+count)%count+1;return end
    if screen=='pause' and (key=='left' or key=='right') then return end
    if key=='menu' then
        if screen=='title' then return
        elseif screen=='new' or screen=='load' then open('title')
        elseif screen=='confirm' then open('new',4)
        elseif screen=='settings' then open(S.return_to or 'title',S.return_selection)
        elseif screen=='pause' then S.tool='inspect';open('play') end
        return
    end
    if key~='a' then return end
    local n=S.selection
    if screen=='title' then
        if n==1 then open('load') elseif n==2 then open('new') elseif n==3 then S.return_to='title';S.return_selection=3;open('help') else S.return_to='title';S.return_selection=4;open('settings') end
    elseif screen=='load' then
        local w=S.saved[n]
        if w then S.world=w;S.slot=n;S.cx=11;S.cy=13;S.ox=640;S.oy=375;S.zoom=S.preferred_zoom or 2;S.tool='inspect';S.elapsed=0;home_camera();open('play') else notify('Este arquivo n\195\163o tem uma ilha v\195\161lida.',false) end
    elseif screen=='new' then
        if n==1 then S.new_free=false elseif n==2 then S.new_free=true elseif n==3 then S.seed=(S.seed+137)%9999;S.preview=World.new(S.seed,S.new_free or false) elseif n==4 then S.slot=S.slot%3+1
        else if #Platform.load(S.slot)>0 then open('confirm') else start_game() end end
    elseif screen=='confirm' then if n==1 then open('new',4) else start_game() end
    elseif screen=='pause' then
        if n==1 then S.tool='inspect';open('play') elseif n==2 then save_game(false) elseif n==3 then open('goals')
        elseif n==4 then S.return_to='pause';S.return_selection=4;open('settings') elseif n==5 then S.return_to='pause';S.return_selection=5;open('help')
        elseif n==6 then S.view_zoom=S.zoom;S.zoom=1;S.camx=11;S.camy=11;S.world.dirty=true;open('view')
        elseif n==7 then save_game(true);S.ox=880;S.oy=350;S.camx=11;S.camy=11;S.zoom=1;S.world.dirty=true;open('title') end
    elseif screen=='settings' then
        if n==1 then S.sound=not S.sound elseif n==2 then S.motion=not S.motion elseif n==3 then S.detail=3-S.detail;S.world.dirty=true
        elseif n==4 then S.zoom=S.zoom==1 and 2 or 1;S.preferred_zoom=S.zoom;S.world.dirty=true
        elseif n==5 then S.light=S.light%4+1 else open(S.return_to or 'title',S.return_selection) end
        Platform.options(S.sound,S.motion,S.detail,S.preferred_zoom or 2,S.light)
    end
    if S.sound then Platform.sound(0) end
end
local function init(self,std)
    S.world=World.new(2706,true);S.ox=872;S.oy=354;S.zoom=1
    S.selection=(#Platform.load(1)>0 or #Platform.load(2)>0 or #Platform.load(3)>0) and 1 or 2

    local demo={14,12,18,19,35};local n=1
    while n<=#demo do local placed=false;local y=8
        while y<17 and not placed do local x=6
            while x<18 and not placed do
                if World.valid(S.world,demo[n],x,y,0,true) then S.world.bid[World.cell(x,y)]=demo[n];World.rebuild(S.world);placed=true end
                x=x+1
            end;y=y+1
        end;n=n+1
    end
    std.text.font_name('Mare, Arial, sans-serif')
    local options=Platform.get_options()
    if options then
        S.sound=not string.find(options,'silent',1,true);S.motion=not string.find(options,'still',1,true)
        local detail,zoom,light=string.match(options,',[^,]+,(%d),(%d),?(%d?)');S.detail=tonumber(detail)==2 and 2 or 1;S.preferred_zoom=tonumber(zoom)==1 and 1 or 2;S.light=max(1,min(4,tonumber(light) or 1))
    end
    if Platform.register then Platform.register(function(command,arg)
        if command=='state' then return S.screen..','..S.cx..','..S.cy..','..S.world.cash..','..S.world.population..','..S.selection..','..S.world.revision end
        if command=='tool' then return S.tool..','..S.brush..','..S.rotation..','..(S.gesture and 'gesture' or 'ready')..','..(S.paint and 'trace' or 'single')..','..S.category..','..S.item..','..(S.tab_focus and 'tabs' or 'cards') end
        if command=='level' then return S.stroke and tostring(S.stroke.target) or '' end
        if command=='save' then return World.encode(S.world) end
        if command=='checkpoint' then return not S.gesture and S.screen~='title' and S.screen~='new' and S.screen~='load' and World.encode(S.world) or '' end
        if command=='slot' then return S.slot end
        if command=='metrics' then return (S.visible or 0)..','..#S.world.undo..','..S.world.count..','..S.world.balance end
        if command=='lighting' then return S.light..','..S.phase..','..(Lighting.rebuilds or 0)..','..Lighting.R end
        if command=='key' then act(arg);return S.screen end
    end) end

    render_world(std)
end
local input_keys={'up','down','left','right','a','menu'}
local function loop(self,std)
    local dt=min(std.delta or 16,100);S.time=S.time+dt
    S.toast_time=max(0,S.toast_time-dt)
    local queued=Platform.take_key and Platform.take_key();local drained=0
    while queued do act(queued);drained=drained+1;queued=Platform.take_key() end
    local keys=input_keys;local i=1
    while i<=6 do
        local k=keys[i];local down=std.key.press[k] or false
        if down and not S.keys[k] then S.held[k]=0;if not Platform.take_key then act(k) end
        elseif down and i<=4 then
            S.held[k]=(S.held[k] or 0)+dt
            if S.held[k]>=340 then S.held[k]=240;act(k) end
        end
        S.keys[k]=down;i=i+1
    end
    if S.screen=='play' and not S.gesture then
        S.skytime=S.skytime+dt
        S.elapsed=S.elapsed+dt;S.saveclock=S.saveclock+dt
        if S.elapsed>=12000 then S.elapsed=S.elapsed-12000;local msg=World.tick(S.world);if msg then notify(msg,true) end end
        if S.saveclock>=30000 then save_game(true) end
    end
end
local function draw(self,std)
    render_world(std)
    Platform.ui_begin(S.time-(S.entered or 0),S.motion)
    if S.screen=='title' then title_draw(std) elseif S.screen=='play' then play_draw(std) elseif S.screen=='tools' then toolbar_draw(std)
    elseif S.screen=='catalog' then catalog_draw(std) elseif S.screen=='terrain' then terrain_draw(std) elseif S.screen=='context' then context_draw(std)
    elseif S.screen=='pause' then pause_draw(std) elseif S.screen=='settings' then settings_draw(std) elseif S.screen=='help' then help_draw(std)
    elseif S.screen=='goals' then goals_draw(std) elseif S.screen=='new' then new_draw(std) elseif S.screen=='confirm' then confirm_draw(std) elseif S.screen=='load' then load_draw(std)
    elseif S.screen=='view' then box(std,350,624,580,56,C.panel);text(std,378,640,'OK mudar a luz   VOLTAR continuar',28,C.paper,530) end
    if S.toast_time>0 and (S.screen=='play' or S.toast_good==false) then
        box(std,448,128,784,56,C.dark);box(std,448,128,5,56,S.toast_good==false and C.red or C.gold)
        text(std,472,138,S.toast,26,S.toast_good==false and C.red or C.paper,738)
    end
    Platform.ui_end()
end
return {meta={title='Mar\195\169',author='Ilhas Studio',description='Um pedacinho de mundo, do seu jeito.',version='0.4.0',id='studio.ilhas.mare'},callbacks={init=init,loop=loop,draw=draw}}
