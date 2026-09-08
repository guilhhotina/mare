local L={}
local floor,min,max,abs,sqrt=math.floor,math.min,math.max,math.abs,math.sqrt
local buildings={11,17,30}
local status_codes={reserved=1,worker=2,route=3,terrain=4,demand=5,resources=6,access=7,walking=8,working=9}
local statuses={'reserved','worker','route','terrain','demand','resources','access','walking','working'}
local legacy_states={'walk','wait','work','arrive','leave'}
local states={'walk','wait','work','approach','enter','interior','exit','activity','depart'}
local anchor_names={'door','front','yard','counter','bench','lookout','shore','garden','work_edge','work_surface'}
local construction={'survey','mark','mix_mortar','stack_bricks','lay_bricks','carry_timber','saw','hammer','paint','inspect_work'}
local stages={'reserved','foundation','frame'}
local function index(t,value) for i=1,#t do if t[i]==value then return i end end end
local function copy(t) local r={};for k,v in pairs(t) do r[k]=v end;return r end
function L.install(W,Catalog,P,Activities,Appearance,InteractionAnchors)
    local actions,visits,work_actions={},{},{}
    for i=1,#Activities do
        local a=Activities[i];actions[a.id]=a
        if a.kind=='resident' then
            for j=1,#a.buildings do
                local id=a.buildings[j];visits[id]=visits[id] or {};visits[id][#visits[id]+1]=a
            end
        end
    end
    local first,last=0,0
    for i=1,#construction do
        local a=assert(actions[construction[i]],'Missing construction activity')
        if i<=5 then first=first+a.frames*a.frame_ms else last=last+a.frames*a.frame_ms end
    end
    local stop=0
    for i=1,#construction do
        local a=actions[construction[i]]
        stop=stop+a.frames*a.frame_ms*(i<=5 and 4000/first or 8000/last)
        work_actions[i]={activity=a,stop=i==5 and 4000 or i==#construction and 12000 or stop}
    end
    local function work_action(j)
        for i=1,#work_actions do
            if (j.work_ms or 0)<work_actions[i].stop then return work_actions[i].activity,work_actions[i].stop,i==1 and 0 or work_actions[i-1].stop end
        end
        return work_actions[#work_actions].activity,12000,work_actions[#work_actions-1].stop
    end
    local function action(p,id)
        if p.action~=id then p.action=id;p.action_time=0 end
    end
    local function duration(id)
        local a=actions[id];return a.frames*a.frame_ms*(a.loop and 2 or 1)
    end
    W.zone_buildings=buildings
    W.job_status={reserved='Lote reservado',worker='Sem trabalhador: conecte uma moradia',route='Sem rota: reconecte o caminho',terrain='Terreno invalido: nivele o lote',demand='Sem demanda para este uso',resources='Faltam moedas para reservar a obra',access='Lote sem acesso viario',walking='Trabalhador a caminho',working='Construcao em andamento',occupied='Aguarde a pessoa atravessar o lote',capacity='Aguarde uma obra terminar',footprint='Autorize todo o lote desta construcao'}
    local function init(w)
        w.zones={};w.reserved={};w.zone_status={};w.jobs={};w.people={};w.events={}
        for k=1,576 do w.zones[k]=0 end
        w.life_time=0;w.life_accumulator=0;w.life_step=0;w.life_epoch=0;w.next_job_id=1;w.next_person_id=1;w.lot_revision=0;w.trip_clock=0;w.schedule_cursor=1;w.completed_lots=0
        w.life_doors={};w.life_homes={};w.life_targets={};w.life_owners={};w.life_candidate={};w.life_places={};w.life_place_revision=-1
        return w
    end
    local old_new=W.new
    W.new=function(seed,free) return init(old_new(seed,free)) end
    local function reindex(w)
        for k=1,576 do w.reserved[k]=nil end
        for i=1,#w.jobs do
            local j=w.jobs[i];local nx,ny=W.footprint(j.building_id,j.rotation)
            for v=0,ny-1 do for u=0,nx-1 do w.reserved[W.cell(j.x+u,j.y+v)]=j.id end end
        end
        w.lot_revision=w.lot_revision+1
    end
    local function event(w,kind,j)
        if #w.events==8 then table.remove(w.events,1) end
        w.events[#w.events+1]={kind=kind,building_id=j.building_id,x=j.x,y=j.y}
    end
    function W.take_event(w) if #w.events>0 then return table.remove(w.events,1) end end
    local function person(w,id) for i=1,#w.people do if w.people[i].id==id then return w.people[i],i end end end
    local function job(w,id) for i=1,#w.jobs do if w.jobs[i].id==id then return w.jobs[i],i end end end
    local function return_home(p)
        p.job_id=0;p.phase=2;p.path=nil;p.path_index=1;p.pause=0;p.destination=0;p.destination_id=0;p.activity='none';p.home_route_failed=nil
        if p.interaction then
            p.state=p.local_cursor>p.interaction.stand and 'exit' or 'depart';p.visible=true
            action(p,p.state=='exit' and 'exit' or 'walk')
        else p.state='wait';action(p,'wait') end
    end
    local function cancel(w,id,erase)
        local j,i=job(w,id)
        if not j then return false,I18n.t('Obra nao encontrada') end
        local nx,ny=W.footprint(j.building_id,j.rotation);local kind=index(buildings,j.building_id)
        if erase then for v=0,ny-1 do for u=0,nx-1 do local k=W.cell(j.x+u,j.y+v);if w.zones[k]==kind then w.zones[k]=0 end end end end
        w.cash=w.cash+j.escrow;j.escrow=0
        local p=person(w,j.worker_id);if p then return_home(p) end
        table.remove(w.jobs,i);reindex(w);w.life_epoch=w.life_epoch+1;w.dirty=true;event(w,'canceled',j)
        return true,I18n.t('Obra cancelada; saldo nao gasto devolvido')
    end
    function W.cancel_job(w,id) return cancel(w,id,true) end
    local function authorized(w,j)
        local nx,ny=W.footprint(j.building_id,j.rotation);local kind=index(buildings,j.building_id)
        for v=0,ny-1 do for u=0,nx-1 do if w.zones[W.cell(j.x+u,j.y+v)]~=kind then return false end end end
        return true
    end
    local function reconcile(w)
        for i=#w.jobs,1,-1 do if not authorized(w,w.jobs[i]) then cancel(w,w.jobs[i].id,false) end end
    end
    function W.zone_valid(w,kind,x,y)
        if type(kind)~='number' or kind~=floor(kind) or kind<0 or kind>3 then return false,I18n.t('Uso de zona invalido') end
        if type(x)~='number' or type(y)~='number' or x~=floor(x) or y~=floor(y) or x<0 or y<0 or x>=24 or y>=24 then return false,I18n.t('Fora dos limites da ilha') end
        if kind==0 then return true,I18n.t('Apagar autorizacao sem demolir construcoes') end
        local k=W.cell(x,y)
        if w.occ[k]>0 then return false,I18n.t('Este espaco ja esta ocupado') end
        if w.base[k]<1 then return false,I18n.t('Eleve a terra antes de zonear') end
        return true,I18n.t(kind==3 and 'Clinica: autorize um lote de 2 por 1 com acesso' or 'Autorizar crescimento com acesso viario')
    end
    function W.zone(w,kind,x,y)
        local ok,msg=W.zone_valid(w,kind,x,y);if not ok then return false,msg end
        local k=W.cell(x,y);if w.zones[k]==kind then return false,I18n.t('Esta celula ja tem esse uso') end
        w.zones[k]=kind;w.dirty=true
        return true,msg
    end
    local function crossing(w,id,x,y,r)
        local nx,ny=W.footprint(id,r)
        for i=1,#w.people do local p=w.people[i]
            local px,py=floor(p.x+.5),floor(p.y+.5)
            if px>=x and px<x+nx and py>=y and py<y+ny then return true end
            if p.interaction then
                for t=1,#p.interaction.points do
                    local q=p.interaction.points[t];local qx,qy=floor(q.x+.5),floor(q.y+.5)
                    if qx>=x and qx<x+nx and qy>=y and qy<y+ny then return true end
                end
            end
            local ax,ay=(p.cell-1)%24,floor((p.cell-1)/24)
            if ax>=x and ax<x+nx and ay>=y and ay<y+ny then return true end
            if p.next_cell~=0 then
                local bx,by=(p.next_cell-1)%24,floor((p.next_cell-1)/24)
                if bx>=x and bx<x+nx and by>=y and by<y+ny then return true end
            end
        end
        return false
    end
    local old_valid=W.valid
    W.valid=function(w,id,x,y,r,ignore_cost)
        local ok,msg=old_valid(w,id,x,y,r,ignore_cost);if not ok then return ok,msg end
        local nx,ny=W.footprint(id,r)
        for v=0,ny-1 do for u=0,nx-1 do if w.reserved[W.cell(x+u,y+v)] then return false,I18n.t('Lote reservado para uma obra') end end end
        if id>7 and crossing(w,id,x,y,r) then return false,I18n.t('Aguarde a pessoa atravessar antes de construir') end
        return ok,msg
    end
    local old_remove=W.remove
    W.remove=function(w,x,y)
        local k=w.occ[W.cell(x,y)]
        if k>0 and (w.bid[k]==5 or w.bid[k]==6) and crossing(w,w.bid[k],(k-1)%24,floor((k-1)/24),w.rot[k]) then return false,I18n.t('Ha uma pessoa atravessando esta ponte; aguarde antes de remover') end
        return old_remove(w,x,y)
    end
    local old_terraform=W.terraform
    local function moved_ground(w,heights,q)
        local x,y=q.x+.5,q.y+.5;local ax,ay=max(0,min(23,floor(x))),max(0,min(23,floor(y)))
        local u,v=max(0,min(1,x-ax)),max(0,min(1,y-ay));local k=ay*25+ax+1
        local delta=(w.h[k]-heights[k])*(1-u)*(1-v)+(w.h[k+1]-heights[k+1])*u*(1-v)+(w.h[k+25]-heights[k+25])*(1-u)*v+(w.h[k+26]-heights[k+26])*u*v
        return abs(delta)>1e-8
    end
    local function supported(w,heights)
        local nav=P.refresh(w)
        for i=1,#w.people do
            local p=w.people[i]
            if not nav.walk[p.cell] or (p.next_cell~=0 and not P.edge(w,p.cell,p.next_cell)) then return false end
            if p.interaction then
                if moved_ground(w,heights,p) then return false end
                for t=1,#p.interaction.points do if moved_ground(w,heights,p.interaction.points[t]) then return false end end
            else
                local z=nav.height[p.cell]
                if p.next_cell~=0 then z=z+(nav.height[p.next_cell]-z)*p.edge_progress end
                if abs(z-p.z)>1e-8 then return false end
            end
        end
        return true
    end
    W.terraform=function(w,tool,x,y,radius,reference,dx,dy,stroke)
        local heights
        if #w.people>0 then heights=copy(w.h) end
        local revision=w.revision
        local ok,msg=old_terraform(w,tool,x,y,radius,reference,dx,dy,stroke)
        if not ok or #w.people==0 then return ok,msg end
        if not supported(w,heights) then
            for k=1,625 do w.h[k]=heights[k] end
            W.rebuild(w)
            for i=1,#w.people do local p=w.people[i];if p.path_revision==revision then p.path_revision=w.revision end end
            return false,I18n.t('O ajuste afeta uma pessoa ou seu acesso, inclusive alem do pincel. Aguarde o local ficar livre.')
        end
        return ok,msg
    end
    local old_snapshot=W.snapshot
    W.snapshot=function(w)
        local s=old_snapshot(w);s.zones=copy(w.zones);s.life_epoch=w.life_epoch;s.navigation_revision=w.revision;s.navigation_lots=w.lot_revision;return s
    end
    local old_record=W.record
    W.record=function(w,s)
        local same=true;local zoned=false
        for k=1,625 do if w.h[k]~=s.h[k] then same=false;break end end
        for k=1,576 do if w.bid[k]~=s.bid[k] or w.rot[k]~=s.rot[k] then same=false end;if w.zones[k]~=s.zones[k] then zoned=true end end
        if same and zoned then s.zone_only=true;s.zone_after=copy(w.zones) end
        old_record(w,s)
    end
    local old_restore=W.restore
    W.restore=function(w,s)
        if w.life_epoch~=s.life_epoch then return false,I18n.t('A ilha progrediu; esta transacao nao pode substituir a simulacao') end
        for i=1,#w.people do
            local interaction=w.people[i].interaction
            if interaction and (w.bid[interaction.target]~=s.bid[interaction.target] or w.rot[interaction.target]~=s.rot[interaction.target]) then
                return false,I18n.t('Ha uma pessoa nesta travessia; mantenha o terreno seguro ate ela passar')
            end
        end
        if #w.people>0 then
            for k=1,576 do
                if s.bid[k]>7 and (s.bid[k]~=w.bid[k] or s.rot[k]~=w.rot[k]) and crossing(w,s.bid[k],(k-1)%24,floor((k-1)/24),s.rot[k]) then
                    return false,I18n.t('Ha uma pessoa nesta travessia; mantenha o terreno seguro ate ela passar')
                end
            end
        end
        local previous=#w.people>0 and old_snapshot(w)
        local revision=w.revision
        old_restore(w,s)
        if previous and not supported(w,previous.h) then
            old_restore(w,previous)
            for i=1,#w.people do local p=w.people[i];if p.path_revision==revision then p.path_revision=w.revision end end
            return false,I18n.t('Ha uma pessoa nesta travessia; mantenha o terreno seguro ate ela passar')
        end
        for k=1,576 do w.zones[k]=s.zones[k] end
        for i=1,#w.people do local p=w.people[i]
            if p.path_revision==s.navigation_revision and p.path_lots==s.navigation_lots then p.path_revision=w.revision end
        end
        return true
    end
    W.undo=function(w)
        local n=#w.undo;if n==0 then return false,I18n.t('Nada para desfazer') end
        local s=w.undo[n]
        if s.zone_only then
            for k=1,576 do
                if s.zone_after[k]~=s.zones[k] and w.zones[k]~=s.zone_after[k] then return false,I18n.t('Uma zona posterior ocupa esta transacao') end
            end
            for k=1,576 do if s.zone_after[k]~=s.zones[k] then w.zones[k]=s.zones[k] end end
            reconcile(w);w.dirty=true
        else
            if w.life_epoch~=s.life_epoch then return false,I18n.t('Obras progrediram; desfazer terreno antigo apagaria progresso') end
            local cash=w.cash+(s.refund or 0)
            if cash<0 then return false,I18n.t('Faltam moedas para desfazer este reembolso') end
            local ok,msg=W.restore(w,s);if not ok then return false,msg end;w.cash=cash
        end
        w.undo[n]=nil;return true,I18n.t('Ultima acao desfeita')
    end
    local function terrain(w,j)
        local nx,ny=W.footprint(j.building_id,j.rotation);local base=w.base[W.cell(j.x,j.y)]
        for v=0,ny-1 do for u=0,nx-1 do local k=W.cell(j.x+u,j.y+v)
            if w.occ[k]>0 or base<1 or w.base[k]~=base or w.mask[k]~=0 then return false end
        end end
        return true
    end
    local function demand(w,j)
        local homes,shops,health=0,0,w.health
        for i=1,#w.jobs do local q=w.jobs[i]
            if q.id~=j.id and q.funded then
                if q.building_id==11 then homes=homes+4 elseif q.building_id==17 then shops=shops+1 else health=health+100 end
            end
        end
        if j.building_id==11 then return w.power>=w.need+max(1,floor((homes+4)/4))+shops*2 and w.population+homes<max(16,(w.shops+shops)*16) end
        if j.building_id==17 then return w.population>=8*(w.shops+shops+1) and w.power>=w.need+2+shops*2+homes/4 end
        return w.population>health and w.power>=w.need+3+shops*2+homes/4
    end
    local function condition(w,j)
        if not terrain(w,j) then return 'terrain' end
        local a=work_action(j)
        if P.approaches(w,j.building_id,j.x,j.y,j.rotation,W,InteractionAnchors,a.anchor,w.life_targets)==0 then return 'access' end
        if not j.funded then
            if crossing(w,j.building_id,j.x,j.y,j.rotation) then return 'occupied' end
            if not demand(w,j) then return 'demand' end
            if not w.free and w.cash<j.cost then return 'resources' end
            j.funded=true;j.escrow=w.free and 0 or j.cost;w.cash=w.cash-j.escrow;w.life_epoch=w.life_epoch+1
        end
        return nil
    end
    local function complete(w,p,j)
        local _,i=job(w,j.id);local k=W.cell(j.x,j.y)
        w.bid[k]=j.building_id;w.rot[k]=j.rotation
        table.remove(w.jobs,i);reindex(w);W.rebuild(w);w.completed_lots=w.completed_lots+1;w.life_epoch=w.life_epoch+1
        event(w,'completed',j);return_home(p)
    end
    local function home_doors(w,home,out)
        local id=w.bid[home]
        if id<11 or id>16 or not w.linked[home] then for i=#out,1,-1 do out[i]=nil end;return 0 end
        return P.approaches(w,id,(home-1)%24,floor((home-1)/24),w.rot[home],W,InteractionAnchors,'door',out)
    end
    local function separation(a,b)
        local dx,dy,dz=b.x-a.x,b.y-a.y,(b.z-a.z)/16
        return sqrt(dx*dx+dy*dy+dz*dz)
    end
    local function bind(w,p,target,id,rotation,anchor)
        local point=P.anchor(w,id,(target-1)%24,floor((target-1)/24),rotation,W,InteractionAnchors,anchor,p.cell)
        if not point then return false end
        local points={{x=(p.cell-1)%24,y=floor((p.cell-1)/24),z=P.refresh(w).height[p.cell]}}
        for i=1,#point.approach do
            local q=point.approach[i];points[#points+1]={x=q.x,y=q.y,z=q.z}
        end
        local stand=#points
        if anchor=='door' then
            points[#points+1]={x=point.contact_x,y=point.contact_y,z=point.contact_z}
            points[#points+1]={x=point.interior_x,y=point.interior_y,z=point.interior_z}
        end
        for i=1,#points-1 do points[i].distance=separation(points[i],points[i+1]) end
        p.interaction={target=target,building_id=id,rotation=rotation,anchor=anchor,stand=stand,facing=point.facing,site_stage=point.site_stage,points=points,contact_x=point.contact_x,contact_y=point.contact_y,contact_z=point.contact_z}
        p.local_cursor=1;p.local_revision=w.revision;p.local_lots=w.lot_revision;p.local_valid=true
        return true
    end
    local function spawn(w,role,home,start,path,destination,j,activity)
        local p={id=w.next_person_id,role=role,x=(start-1)%24,y=floor((start-1)/24),z=P.refresh(w).height[start],facing=0,state='exit',animation_time=0,action='exit',action_time=0,appearance=Appearance.make(w.seed,w.next_person_id,role),visible=false,home=home,job_id=j and j.id or 0,phase=1,cell=start,next_cell=0,edge_progress=0,path=path,path_index=1,path_revision=w.revision,path_lots=w.lot_revision,pause=0,destination=destination,destination_id=destination>0 and w.bid[destination] or 0,activity=activity and activity.id or 'none',local_cursor=0}
        if not bind(w,p,home,w.bid[home],w.rot[home],'door') then return nil end
        local points=p.interaction.points;local interior=points[#points]
        p.local_cursor=#points;p.x=interior.x;p.y=interior.y;p.z=interior.z;p.facing=(p.interaction.facing+2)%4
        w.next_person_id=w.next_person_id+1;w.people[#w.people+1]=p
        if j then j.worker_id=p.id;j.status='walking' end
        return p
    end
    local function find_origin(w,role)
        local homes=w.life_homes;local count=0
        for k=1,576 do
            if w.bid[k]>=11 and w.bid[k]<=16 and w.linked[k] then
                local busy=false
                for i=1,#w.people do if w.people[i].home==k and w.people[i].role==role then busy=true;break end end
                if not busy and home_doors(w,k,w.life_doors)>0 then
                    for i=1,#w.life_doors do
                        count=count+1;local h=homes[count] or {};h.home=k;h.door=w.life_doors[i];homes[count]=h
                    end
                end
            end
        end
        for i=count+1,#homes do homes[i]=nil end
        return homes
    end
    local function assign(w,j,budget)
        if #w.people>=32 then j.status='worker';return budget end
        local homes=find_origin(w,'worker')
        if #homes==0 then j.status='worker';return budget end
        if budget==0 then j.status='route';return budget end
        local a=work_action(j)
        P.approaches(w,j.building_id,j.x,j.y,j.rotation,W,InteractionAnchors,a.anchor,w.life_targets)
        local targets=w.life_targets
        local starts=w.life_doors;for i=1,#homes do starts[i]=homes[i].door end;for i=#homes+1,#starts do starts[i]=nil end
        local path,door,target=P.route(w,targets,starts);budget=budget-1
        if not path then j.status='route';return budget end
        local reversed={};for i=#path-1,1,-1 do reversed[#reversed+1]=path[i] end
        if door~=target then reversed[#reversed+1]=target end
        local home=homes[1].home;for i=1,#homes do if homes[i].door==door then home=homes[i].home;break end end
        spawn(w,'worker',home,door,reversed,0,j)
        return budget
    end
    local function reserve(w)
        for k=1,576 do w.zone_status[k]=nil end
        for step=1,576 do
            local k=(w.schedule_cursor+step-2)%576+1;local kind=w.zones[k]
            if kind>0 and w.occ[k]==0 and not w.reserved[k] then
                local x,y=(k-1)%24,floor((k-1)/24);local id=buildings[kind];local r=0;local fit=false
                for rotation=0,1 do
                    local nx,ny=W.footprint(id,rotation);fit=x+nx<=24 and y+ny<=24
                    if fit then for v=0,ny-1 do for u=0,nx-1 do local c=W.cell(x+u,y+v);if w.zones[c]~=kind or w.occ[c]>0 or w.reserved[c] then fit=false end end end end
                    if fit then r=rotation;break end
                end
                if fit and #w.jobs<4 then
                    local candidate=w.life_candidate
                    candidate.id=w.next_job_id;candidate.x=x;candidate.y=y;candidate.building_id=id;candidate.rotation=r;candidate.cost=Catalog[id][5];candidate.funded=false
                    local blocked=condition(w,candidate)
                    if blocked then w.zone_status[k]=blocked
                    else
                        local j={id=candidate.id,x=x,y=y,building_id=id,rotation=r,stage='reserved',progress=0,work_ms=0,status='reserved',worker_id=0,escrow=candidate.escrow,spent=0,cost=candidate.cost,funded=true}
                        w.next_job_id=w.next_job_id+1;w.jobs[#w.jobs+1]=j;w.life_epoch=w.life_epoch+1;reindex(w);w.dirty=true
                    end
                else w.zone_status[k]=fit and 'capacity' or 'footprint' end
            end
        end
        w.schedule_cursor=w.schedule_cursor%576+1
    end
    local function destinations(w,p,out)
        if p.phase==2 then return home_doors(w,p.home,out) end
        if p.role=='worker' then
            local j=job(w,p.job_id)
            if not j then return_home(p);return 0 end
            local a=work_action(j)
            return P.approaches(w,j.building_id,j.x,j.y,j.rotation,W,InteractionAnchors,a.anchor,out)
        end
        local k=p.destination;local id=w.bid[k];local a=actions[p.activity]
        if id~=p.destination_id or not a or not index(a.buildings,id) then return_home(p);return 0 end
        return P.approaches(w,id,(k-1)%24,floor((k-1)/24),w.rot[k],W,InteractionAnchors,a.anchor,out)
    end
    local function reroute(w,p,budget)
        if p.interaction or p.pause>0 or p.next_cell~=0 then return budget end
        if p.path and p.path_revision==w.revision and p.path_lots==w.lot_revision then return budget end
        p.path=nil;p.state='wait';p.wait_reason='route';action(p,'wait')
        if budget==0 then return budget end
        local targets=w.life_targets;local count=destinations(w,p,targets)
        local alternative=p.phase==2 and (count==0 or p.home_route_failed)
        if alternative then
            count=0
            for k=1,576 do
                if home_doors(w,k,w.life_doors)>0 then
                    for d=1,#w.life_doors do count=count+1;targets[count]=w.life_doors[d];w.life_owners[count]=k end
                end
            end
            for i=count+1,#targets do targets[i]=nil end
            if count==0 then p.wait_reason='home';return budget end
        elseif count==0 then return budget end
        local door
        p.path,door=P.route(w,p.cell,targets);budget=budget-1;p.path_index=1;p.path_revision=w.revision;p.path_lots=w.lot_revision
        if p.path then
            p.state='walk';p.wait_reason=nil;p.home_route_failed=nil;action(p,'walk')
            if alternative then for i=1,count do if targets[i]==door then p.home=w.life_owners[i];break end end end
        elseif p.phase==2 then p.home_route_failed=true end
        return budget
    end
    local function trips(w,budget)
        if w.trip_clock<8000 or budget==0 or #w.people>=32 then return budget end
        local residents=0;for i=1,#w.people do if w.people[i].role=='resident' then residents=residents+1 end end
        if residents>=4 then return budget end
        local places=w.life_places
        if w.life_place_revision~=w.revision then
            local count=0
            for k=1,576 do if visits[w.bid[k]] and w.linked[k] then count=count+1;places[count]=k end end
            for i=count+1,#places do places[i]=nil end
            w.life_place_revision=w.revision
        end
        if #places==0 then return budget end
        local homes=find_origin(w,'resident');if #homes==0 then return budget end
        local home=homes[(w.next_person_id-1)%#homes+1]
        for offset=1,#places do
            local k=places[(w.next_person_id+offset-2)%#places+1];local id=w.bid[k];local choices=visits[id]
            local first=floor((w.next_person_id-1)/#places)%#choices
            for c=1,#choices do
                local a=choices[(first+c-1)%#choices+1]
                if P.approaches(w,id,(k-1)%24,floor((k-1)/24),w.rot[k],W,InteractionAnchors,a.anchor,w.life_targets)>0 then
                    local path=P.route(w,home.door,w.life_targets);budget=budget-1
                    if path then
                        spawn(w,'resident',home.home,home.door,path,k,nil,a);w.trip_clock=0;return budget
                    end
                    break
                end
            end
            if budget==0 then return budget end
        end
        return budget
    end
    local function schedule(w)
        reconcile(w);reserve(w);local budget=2
        for i=1,#w.people do local p=w.people[i];if p.job_id==0 then budget=reroute(w,p,budget) end end
        for offset=1,#w.jobs do
            local i=(w.schedule_cursor+offset-2)%#w.jobs+1
            local j=w.jobs[i];local blocked=condition(w,j)
            if blocked then
                j.status=blocked;local p=person(w,j.worker_id)
                if p then action(p,'wait');if not p.interaction then p.state='wait';p.path=nil end end
            elseif j.worker_id==0 then budget=assign(w,j,budget)
            else
                local p=person(w,j.worker_id)
                if p then
                    if j.work_ms==12000 then j.status='walking'
                    else
                        budget=reroute(w,p,budget)
                        j.status=p.state=='work' and 'working' or (p.interaction or p.path) and 'walking' or 'route'
                    end
                end
            end
        end
        trips(w,budget)
    end
    local function arrive(w,p)
        p.path=nil;p.path_index=1
        local target,id,rotation,anchor,assigned
        if p.phase==2 then
            target=p.home;id=w.bid[target];rotation=w.rot[target];anchor='door'
            if id<11 or id>16 then p.state='wait';p.home_route_failed=true;action(p,'wait');return end
        elseif p.role=='resident' then
            target=p.destination;id=w.bid[target];rotation=w.rot[target]
            local a=actions[p.activity]
            if id~=p.destination_id or not a or not index(a.buildings,id) then return_home(p);return end
            anchor=a.anchor
        else
            local j=job(w,p.job_id)
            if not j then return_home(p);return end
            target=W.cell(j.x,j.y);id=j.building_id;rotation=j.rotation;anchor=work_action(j).anchor
            assigned=j
        end
        if bind(w,p,target,id,rotation,anchor) then
            p.state='approach';p.visible=true;action(p,'walk');if assigned then assigned.status='walking' end
        else p.state='wait';p.path=nil;action(p,'wait') end
    end
    local function move(w,p,dt)
        local nav=P.refresh(w)
        if p.path_revision~=w.revision or p.path_lots~=w.lot_revision then p.path=nil end
        local distance=dt*.0025
        while distance>0 do
            if p.next_cell==0 then
                if not p.path then p.state='wait';action(p,'wait');return end
                local next=p.path[p.path_index]
                if not next then arrive(w,p);return end
                if not P.edge(w,p.cell,next) then p.path=nil;p.state='wait';action(p,'wait');return end
                p.next_cell=next;p.edge_progress=0;p.path_index=p.path_index+1
            end
            if not P.edge(w,p.cell,p.next_cell) then p.path=nil;p.state='wait';action(p,'wait');return end
            local amount=min(distance,1-p.edge_progress);p.edge_progress=p.edge_progress+amount;distance=distance-amount
            local ax,ay=(p.cell-1)%24,floor((p.cell-1)/24);local bx,by=(p.next_cell-1)%24,floor((p.next_cell-1)/24)
            p.x=ax+(bx-ax)*p.edge_progress;p.y=ay+(by-ay)*p.edge_progress
            p.z=nav.height[p.cell]+(nav.height[p.next_cell]-nav.height[p.cell])*p.edge_progress
            p.facing=bx>ax and 0 or by>ay and 1 or bx<ax and 2 or 3;p.state='walk';p.visible=true;action(p,'walk')
            if p.edge_progress>=1 then p.cell=p.next_cell;p.next_cell=0;p.edge_progress=0 end
        end
    end
    local function local_position(p)
        local points=p.interaction.points
        if p.local_shift then
            local from=p.local_shift;local to=points[p.interaction.stand];local t=from.progress
            return from.x+(to.x-from.x)*t,from.y+(to.y-from.y)*t,from.z+(to.z-from.z)*t
        end
        local i=floor(p.local_cursor);local t=p.local_cursor-i;local a=points[i]
        if t==0 then return a.x,a.y,a.z end
        local b=points[i+1]
        return a.x+(b.x-a.x)*t,a.y+(b.y-a.y)*t,a.z+(b.z-a.z)*t
    end
    local function local_move(w,p,dt,target)
        local points=p.interaction.points;local direction=p.local_cursor<target and 1 or -1;local distance=dt*.0025
        if p.local_shift then
            local from=p.local_shift;local length=from.distance
            local amount=min(distance,(1-from.progress)*length);from.progress=length<1e-10 and 1 or min(1,from.progress+amount/length);distance=distance-amount
            if 1-from.progress<1e-10 then p.local_shift=nil end
            p.facing=p.interaction.facing
        end
        while not p.local_shift and distance>0 and p.local_cursor~=target do
            local i=direction==1 and floor(p.local_cursor) or math.ceil(p.local_cursor)-1
            local a,b=points[i],points[i+1];local dx,dy=b.x-a.x,b.y-a.y
            local length=a.distance;local limit=direction==1 and i+1 or i
            if length<1e-10 then p.local_cursor=limit
            else
                local amount=min(distance,abs(limit-p.local_cursor)*length)
                p.local_cursor=p.local_cursor+direction*amount/length;distance=distance-amount
                if abs(p.local_cursor-limit)<1e-10 then p.local_cursor=limit end
                if abs(dx)+abs(dy)>1e-10 then
                    dx=dx*direction;dy=dy*direction
                    p.facing=abs(dx)>=abs(dy) and (dx>0 and 0 or 2) or (dy>0 and 1 or 3)
                end
            end
        end
        p.x,p.y,p.z=local_position(p);p.visible=true
        return not p.local_shift and p.local_cursor==target
    end
    local function valid_interaction(w,p)
        if p.local_revision==w.revision and p.local_lots==w.lot_revision then return p.local_valid end
        p.local_revision=w.revision;p.local_lots=w.lot_revision
        local s=p.interaction
        local point=P.anchor(w,s.building_id,(s.target-1)%24,floor((s.target-1)/24),s.rotation,W,InteractionAnchors,s.anchor,p.cell)
        local stand=s.points[s.stand]
        p.local_valid=point~=nil and abs(point.x-stand.x)<1e-8 and abs(point.y-stand.y)<1e-8 and abs(point.z-stand.z)<1e-8 and point.facing==s.facing
        return p.local_valid
    end
    local function inspect(w,p)
        if p.checked_revision==w.revision and p.checked_lots==w.lot_revision then return end
        p.checked_revision=w.revision;p.checked_lots=w.lot_revision
        if p.phase==1 and p.role=='resident' and w.bid[p.destination]~=p.destination_id then return_home(p) end
        local s=p.interaction
        if not s or p.state=='exit' or p.state=='depart' then return end
        if p.job_id>0 then
            local j=job(w,p.job_id)
            if not j then return_home(p);return end
            local blocked=condition(w,j)
            if blocked then j.status=blocked;action(p,'wait')
            elseif not valid_interaction(w,p) then p.state='depart';p.path=nil;j.status='route';action(p,'walk')
            else j.status=p.state=='work' and 'working' or 'walking' end
        elseif w.bid[s.target]~=s.building_id or w.rot[s.target]~=s.rotation or not valid_interaction(w,p) then
            return_home(p);p.home_route_failed=s.target==p.home or nil
        end
    end
    local function work(w,p,j,dt)
        if j.status~='working' and j.status~='walking' then action(p,'wait');return end
        local a,stop,start=work_action(j);local s=p.interaction
        if not s or p.local_cursor~=s.stand or s.target~=W.cell(j.x,j.y) or s.anchor~=a.anchor or s.site_stage~=j.stage then
            p.state='depart';p.path=nil;j.status='walking';action(p,'walk');return
        end
        action(p,a.id);p.facing=s.facing
        local previous=j.stage
        j.work_ms=min(stop,j.work_ms+dt);j.progress=j.work_ms/12000;j.stage=j.work_ms<4000 and 'foundation' or 'frame';j.status='working'
        p.action_time=(j.work_ms-start)/(stop-start)*duration(a.id)
        if j.stage~=previous then w.dirty=true end
        local spent=w.free and 0 or floor(j.cost*j.progress);j.escrow=j.escrow-(spent-j.spent);j.spent=spent;w.life_epoch=w.life_epoch+1
        if j.work_ms==12000 then
            p.state='depart';p.path=nil;j.status='walking';action(p,'walk')
        elseif j.stage~=previous then
            j.status='walking'
            local next_action=work_action(j)
            if next_action.anchor==s.anchor and bind(w,p,s.target,s.building_id,s.rotation,s.anchor) then
                p.local_cursor=p.interaction.stand;p.local_shift={x=p.x,y=p.y,z=p.z,progress=0};p.state='approach';action(p,'walk')
                p.local_shift.distance=separation(p.local_shift,p.interaction.points[p.interaction.stand])
            else p.state='depart';p.path=nil;action(p,'walk') end
        end
    end
    local function advance(w,dt)
        for i=#w.people,1,-1 do
            local p=w.people[i];p.animation_time=(p.animation_time+dt)%120000;p.action_time=(p.action_time+dt)%120000
            inspect(w,p)
            local s=p.interaction;local j=p.job_id>0 and job(w,p.job_id) or nil
            if s then
                local blocked=j and j.status~='walking' and j.status~='working' and j.status~='route'
                if p.state=='exit' then
                    action(p,'exit')
                    if local_move(w,p,dt,s.stand) then p.state='depart';action(p,'walk') end
                elseif p.state=='depart' then
                    action(p,'walk')
                    if local_move(w,p,dt,1) then
                        p.interaction=nil;p.local_cursor=0;p.local_valid=nil;p.state='walk'
                        if not p.path and p.phase==1 and j and j.work_ms<12000 then p.path={};p.path_index=1;p.path_revision=w.revision;p.path_lots=w.lot_revision end
                    end
                elseif not blocked then
                    if p.state=='approach' then
                        action(p,'walk')
                        if local_move(w,p,dt,s.stand) then
                            p.facing=s.facing;p.action_time=0
                            if j then p.state='work';j.status='working';action(p,work_action(j).id)
                            else
                                p.state='activity';if p.phase==1 then p.phase=4 end
                                action(p,p.phase==2 and 'unlock_door' or p.activity)
                            end
                        end
                    elseif p.state=='work' then
                        if j then work(w,p,j,dt) else return_home(p) end
                    elseif p.state=='activity' then
                        p.facing=s.facing
                        if p.action_time>=duration(p.action) then
                            if s.anchor=='door' then p.state='enter';action(p,'enter')
                            else return_home(p) end
                        end
                    elseif p.state=='enter' then
                        action(p,'enter')
                        if local_move(w,p,dt,#s.points) then
                            p.state='interior';p.visible=false;p.pause=p.phase==2 and 500 or 1800
                            if p.phase==2 then p.phase=3 end
                            action(p,'wait')
                        end
                    elseif p.state=='interior' then
                        p.pause=max(0,p.pause-dt)
                        if p.pause==0 then
                            if p.phase==3 then table.remove(w.people,i)
                            else return_home(p) end
                        end
                    end
                end
            elseif j and j.work_ms==12000 then
                if j.status=='walking' or j.status=='working' or j.status=='route' then
                    local blocked=condition(w,j)
                    if blocked then j.status=blocked;p.state='wait';action(p,'wait') else complete(w,p,j) end
                end
            elseif not j or j.status=='walking' or j.status=='working' or j.status=='route' then move(w,p,dt)
            else action(p,'wait') end
        end
    end
    function W.update(w,dt)
        if type(dt)~='number' or dt~=dt or dt<=0 or dt==math.huge then return end
        reconcile(w)
        w.life_step=w.life_step+dt
        while w.life_step>=10 do
            local step=10;w.life_step=w.life_step-step
            w.life_time=w.life_time+step;w.trip_clock=min(8000,w.trip_clock+step);w.life_accumulator=w.life_accumulator+step
            if w.life_accumulator>=500 then w.life_accumulator=w.life_accumulator-500;schedule(w) end
            advance(w,step)
            W.traffic_step(w,step)
        end
    end
    local old_encode,old_decode=W.encode,W.decode
    function W.encode(w)
        local out={(old_encode(w):gsub('^MARE2','MARE5'))}
        for k=1,576 do out[#out+1]=w.zones[k] end
        local function put(...) for i=1,select('#',...) do local value=select(i,...);out[#out+1]=string.format('%.17g',value) end end
        put(w.life_time,w.life_accumulator,w.life_step,w.next_job_id,w.next_person_id,w.trip_clock,w.schedule_cursor,w.completed_lots,w.ticks,#w.jobs)
        for i=1,#w.jobs do local j=w.jobs[i];put(j.id,j.x,j.y,j.building_id,j.rotation,index(stages,j.stage),j.work_ms,status_codes[j.status],j.worker_id,j.escrow,j.spent,j.cost,j.funded and 1 or 0) end
        put(#w.people)
        for i=1,#w.people do
            local p=w.people[i]
            put(p.id,p.role=='worker' and 1 or 2,p.x,p.y,p.z,p.facing,index(states,p.state),p.animation_time,p.home,p.job_id,p.phase,p.cell,p.next_cell,p.edge_progress,p.pause,p.destination)
            out[#out+1]=p.action;put(p.action_time,p.appearance,p.visible and 1 or 0,p.destination_id);out[#out+1]=p.activity
            put(p.local_cursor,p.interaction and 1 or 0)
            local s=p.interaction
            if s then
                put(s.target,s.building_id,s.rotation,index(anchor_names,s.anchor),s.stand,s.facing,index(stages,s.site_stage) or 0,s.contact_x,s.contact_y,s.contact_z,#s.points)
                for t=1,#s.points do local q=s.points[t];put(q.x,q.y,q.z) end
                put(p.local_shift and 1 or 0)
                if p.local_shift then local q=p.local_shift;put(q.x,q.y,q.z,q.progress) end
            end
        end
        return table.concat(out,',')
    end
    function W.decode(text)
        if type(text)~='string' or #text>100000 or text:find(',,',1,true) or text:sub(-1)==',' then return nil end
        if text:sub(1,6)=='MARE2,' then local w=old_decode(text);if w then init(w) end;return w end
        local old=text:sub(1,6)=='MARE3,'
        if not old and text:sub(1,6)~='MARE5,' then return nil end
        local raw={};for token in text:gmatch('[^,]+') do raw[#raw+1]=token end
        local base_count=6+625+576*2
        if #raw<base_count+576+11 then return nil end
        local legacy={'MARE2'};for i=2,base_count do legacy[i]=raw[i] end
        local w=old_decode(table.concat(legacy,','));if not w then return nil end;init(w)
        local cursor=base_count+1;local failed=false
        local function get(lo,hi,integer)
            local v=tonumber(raw[cursor]);cursor=cursor+1
            if not v or v~=v or v<lo or v>hi or (integer and v~=floor(v)) then failed=true;return lo end
            return v
        end
        local function get_action(optional)
            local id=raw[cursor];cursor=cursor+1
            if not actions[id] and not (optional and id=='none') then failed=true;return optional and 'none' or 'wait' end
            return id
        end
        for k=1,576 do w.zones[k]=get(0,3,true) end
        w.life_time=get(0,1e15);w.life_accumulator=get(0,500);w.life_step=get(0,10);w.next_job_id=get(1,100000000,true);w.next_person_id=get(1,100000000,true);w.trip_clock=get(0,8000);w.schedule_cursor=get(1,576,true);w.completed_lots=get(0,100000000,true);w.ticks=get(0,100000000,true)
        if w.life_accumulator==500 or w.life_step==10 then return nil end
        local count=get(0,4,true);local ids={};local occupied={}
        for i=1,count do
            local j={id=get(1,w.next_job_id-1,true),x=get(0,23,true),y=get(0,23,true),building_id=get(11,30,true),rotation=get(0,1,true),stage=stages[get(1,3,true)],work_ms=get(0,12000),status=statuses[get(1,9,true)],worker_id=get(0,w.next_person_id-1,true),escrow=get(0,100000000,true),spent=get(0,100000000,true),cost=get(0,100000000,true),funded=get(0,1,true)==1}
            if old and j.work_ms==12000 then return nil end
            j.progress=j.work_ms/12000
            if not index(buildings,j.building_id) or ids[j.id] or j.cost~=Catalog[j.building_id][5] then return nil end
            ids[j.id]=j
            if j.spent~=(w.free and 0 or floor(j.cost*j.progress)) or j.escrow+j.spent~=(j.funded and not w.free and j.cost or 0) or (not j.funded and (j.work_ms>0 or j.worker_id>0)) then return nil end
            if j.work_ms>0 and (j.worker_id==0 or j.stage~=(j.work_ms<4000 and 'foundation' or 'frame')) then return nil end
            if j.work_ms==0 and j.stage~='reserved' then return nil end
            local nx,ny=W.footprint(j.building_id,j.rotation);if j.x+nx>24 or j.y+ny>24 then return nil end
            for v=0,ny-1 do for u=0,nx-1 do local k=W.cell(j.x+u,j.y+v);if occupied[k] or w.occ[k]>0 then return nil end;occupied[k]=true end end
            w.jobs[i]=j
        end
        count=get(0,32,true);local people={}
        for i=1,count do
            local p={id=get(1,w.next_person_id-1,true),role=get(1,2,true)==1 and 'worker' or 'resident',x=get(old and 0 or -1,old and 23 or 24),y=get(old and 0 or -1,old and 23 or 24),z=get(0,old and 80 or 160),facing=get(0,3,true),state=(old and legacy_states or states)[get(1,old and 5 or #states,true)],animation_time=get(0,120000),home=get(1,576,true),job_id=get(0,w.next_job_id-1,true),phase=get(1,4,true),cell=get(1,576,true),next_cell=get(0,576,true),edge_progress=get(0,1),pause=get(0,1800),destination=get(0,576,true),path_index=1}
            if not old then
                p.action=get_action(false);p.action_time=get(0,120000);p.appearance=get(0,32767,true);p.visible=get(0,1,true)==1;p.destination_id=get(0,#Catalog,true);p.activity=get_action(true);p.local_cursor=get(0,32)
                if get(0,1,true)==1 then
                    local s={target=get(1,576,true),building_id=get(8,#Catalog,true),rotation=get(0,3,true),anchor=anchor_names[get(1,#anchor_names,true)],stand=get(2,30,true),facing=get(0,3,true),site_stage=stages[get(0,3,true)],contact_x=get(-1,24),contact_y=get(-1,24),contact_z=get(0,160),points={}}
                    local length=get(2,32,true)
                    for t=1,length do s.points[t]={x=get(-1,24),y=get(-1,24),z=get(0,160)} end
                    for t=1,length-1 do s.points[t].distance=separation(s.points[t],s.points[t+1]) end
                    p.interaction=s
                    if get(0,1,true)==1 then p.local_shift={x=get(-1,24),y=get(-1,24),z=get(0,160),progress=get(0,1)} end
                end
            end
            if p.animation_time==120000 or p.edge_progress==1 then return nil end
            if people[p.id] or (p.role=='resident' and p.job_id~=0) then return nil end;people[p.id]=p
            local ax,ay=(p.cell-1)%24,floor((p.cell-1)/24);local bx,by=ax,ay
            if p.next_cell>0 then bx,by=(p.next_cell-1)%24,floor((p.next_cell-1)/24);if math.abs(ax-bx)+math.abs(ay-by)~=1 then return nil end
            elseif p.edge_progress~=0 then return nil end
            if old or not p.interaction then
                if abs(p.x-(ax+(bx-ax)*p.edge_progress))>1e-8 or abs(p.y-(ay+(by-ay)*p.edge_progress))>1e-8 then return nil end
            else
                local s=p.interaction;local points=s.points;local start=points[1]
                if p.next_cell~=0 or p.local_cursor<1 or p.local_cursor>#points or abs(start.x-ax)>1e-8 or abs(start.y-ay)>1e-8 then return nil end
                if #points~=(s.anchor=='door' and s.stand+2 or s.stand) then return nil end
                if (s.anchor=='work_edge' or s.anchor=='work_surface')~=(s.site_stage~=nil) then return nil end
                if p.local_shift then
                    local q=p.local_shift;local to=points[s.stand]
                    if not s.site_stage or p.local_cursor~=s.stand or (p.state~='approach' and p.state~='depart') or q.progress==1 or abs(q.x-to.x)>.5 or abs(q.y-to.y)>.5 or abs(q.z-to.z)>16 then return nil end
                    q.distance=separation(q,to)
                end
                local tx,ty=(s.target-1)%24,floor((s.target-1)/24);local nx,ny=W.footprint(s.building_id,s.rotation)
                if tx+nx>24 or ty+ny>24 then return nil end
                for t=1,#points do
                    local q=points[t]
                    if q.x<tx-2 or q.x>tx+nx+1 or q.y<ty-2 or q.y>ty+ny+1 then return nil end
                end
                local x,y,z=local_position(p)
                if abs(p.x-x)>1e-8 or abs(p.y-y)>1e-8 or abs(p.z-z)>1e-8 then return nil end
            end
            if p.job_id>0 then local j=ids[p.job_id];if not j or j.worker_id~=p.id or p.phase~=1 or p.role~='worker' then return nil end end
            if p.state=='work' and (p.job_id==0 or p.next_cell~=0) then return nil end
            if old then
                if p.phase==3 and (p.state~='leave' or p.pause==0) then return nil end
                if p.phase==4 and (p.role~='resident' or p.state~='arrive' or p.pause==0) then return nil end
            else
                local s=p.interaction
                if not s then
                    if p.local_cursor~=0 or not p.visible or p.pause~=0 or (p.state~='walk' and p.state~='wait') or p.phase>2 then return nil end
                else
                    if p.state=='walk' or p.state=='wait' then return nil end
                    if (p.state=='work' or p.state=='activity') and p.local_cursor~=s.stand then return nil end
                    if (p.state=='enter' or p.state=='exit') and (s.anchor~='door' or p.local_cursor<s.stand) then return nil end
                    if (p.state=='approach' or p.state=='depart') and p.local_cursor>s.stand then return nil end
                    if p.state=='interior' then
                        if s.anchor~='door' or p.local_cursor~=#s.points or p.visible or p.pause==0 or (p.phase~=3 and p.phase~=4) then return nil end
                    elseif p.pause~=0 or (not p.visible and not (p.state=='exit' and p.phase==1 and s.target==p.home and p.local_cursor==#s.points)) then return nil end
                    if p.phase==3 and (p.state~='interior' or s.target~=p.home) then return nil end
                    if p.phase==4 and (p.role~='resident' or s.target~=p.destination or (p.state~='activity' and p.state~='enter' and p.state~='interior')) then return nil end
                    if p.state=='activity' then
                        local a=actions[p.action]
                        if a.kind~='resident' or a.anchor~=s.anchor or not index(a.buildings,s.building_id) then return nil end
                    end
                    if p.state=='work' then
                        local j=ids[p.job_id]
                        if not j or s.target~=W.cell(j.x,j.y) or s.building_id~=j.building_id or s.rotation~=j.rotation or (s.anchor~='work_edge' and s.anchor~='work_surface') then return nil end
                    end
                end
                if p.role=='resident' and (p.phase==1 or p.phase==4) then
                    local a=actions[p.activity]
                    if not a or a.kind~='resident' or not index(a.buildings,p.destination_id) then return nil end
                end
            end
            if p.role=='worker' and p.phase==1 and p.job_id==0 then return nil end
            if p.role=='resident' and (p.phase==1 or p.phase==4) and p.destination==0 then return nil end
            w.people[i]=p
        end
        for i=1,#w.jobs do local j=w.jobs[i];if j.worker_id>0 and (not people[j.worker_id] or people[j.worker_id].job_id~=j.id) then return nil end end
        if failed or cursor~=#raw+1 then return nil end
        reindex(w)
        local nav=P.refresh(w)
        for i=1,#w.people do local p=w.people[i]
            if not nav.walk[p.cell] or (p.next_cell~=0 and not P.edge(w,p.cell,p.next_cell)) then return nil end
            if old then
                p.appearance=Appearance.make(w.seed,p.id,p.role);p.visible=true;p.action=p.state=='walk' and 'walk' or 'wait';p.action_time=0;p.local_cursor=0;p.destination_id=p.destination>0 and w.bid[p.destination] or 0;p.activity='none';p.pause=0
                if p.phase==3 then p.phase=2 elseif p.phase==4 then p.phase=1 end
                p.state=p.state=='walk' and 'walk' or 'wait'
                if p.role=='resident' and p.phase==1 then
                    local choices=visits[p.destination_id]
                    if choices and #choices>0 then p.activity=choices[(p.id-1)%#choices+1].id else return_home(p) end
                end
                if p.job_id>0 then local j=ids[p.job_id];if j.status=='working' then j.status='walking' end end
            end
        end
        return w
    end
end
return L
