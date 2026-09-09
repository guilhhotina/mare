local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local app_meta={title=I18n.t('Mare'),author='Ilhas Studio',description=I18n.t('Um pedacinho de mundo, do seu jeito.'),version='0.4.0',id='studio.ilhas.mare'}
local S={screen='title',selection=1,category=1,item=1,tool='inspect',cx=11,cy=13,camx=11,camy=11,zoom=2,brush=1,rotation=0,time=0,skytime=0,light=1,elapsed=0,saveclock=0,toast='',toast_time=0,keys={},held={},sound=true,motion=true,contrast=false,slot=1,seed=2706,gesture=nil,detail=1}
local C={ink=0xF5E7C6FF,panel=0x182536FF,paper=0xF5E7C6FF,muted=0xA8B4BAFF,gold=0xD6B574FF,teal=0x99BCADFF,line=0x344354FF,red=0xE6A18CFF,dark=0x131F2DFF}
local categories={'Vias','Moradia','Comercio','Servicos','Natureza'}
local ranges={{1,10},{11,16},{17,24},{25,34},{35,40}}
local tool_names={'Construir','Terreno','Remover','Desfazer','Zonas'}
local tool_ids={'build','terrain','remove','undo','zones'}
local terrain_names={'Elevar','Baixar','Nivelar','Distorcer'}
local terrain_ids={'raise','lower','level','pull'}
local terrain_notes={'Pinte um nivel acima. As construcoes sobem junto.','Pinte um nivel abaixo. As vias se acomodam.','Copie uma altura e pinte o terreno com as setas.','Segure a costa e puxe. As fundacoes acompanham.'}
local tool_notes={'Escolha uma peca e coloque direto na ilha.','Molde morros, praias e enseadas.','Libere espaco e receba 75% do custo de volta.','Desfaca uma construcao, remocao ou gesto inteiro.'}
tool_notes[5]='Autorize bairros; moradores chegam e constroem.'
local zone_names={'Moradia','Comercio','Servicos','Apagar zona'}
local zone_notes={'Casas: acesso, energia e lojas sustentam novos moradores.','Lojas: atendem moradores e permitem mais casas.','Clinicas: lotes 2x1 para moradores sem cobertura.','Retira autorizacao e cancela obras; nao demole edificios.'}
local zone_colors={0x99BCADFF,0xD6B574FF,0xA4BEDCFF,0xE6A18CFF}
local site_keys={reserved='site_reserved',foundation='site_foundation',frame='site_frame'}
S.zone_kind=1
S.playing=false
local brush_names={'pequeno','medio','grande'}
local captions={inspect='Explore a ilha',raise='Elevar terreno',lower='Baixar terreno',level='Nivelar terreno',pull='Distorcer a costa',remove='Remover construcao',build='Construir',zone='Zonear bairro'}
local title_items={'Continuar','Nova ilha','Como jogar','Ajustes'}
local pause_items={'Continuar jogando','Salvar a ilha','Diario da ilha','Ajustes','Como jogar','Contemplar a ilha','Salvar e ir ao inicio'}
local context_road_names={'Trocar via','Concluir'}
local context_build_names={'Girar peca','Trocar peca','Concluir'}
local context_zone_names={'Trocar uso','Concluir'}
local context_terrain_names={'Pincel','Trocar ferramenta','Concluir'}
local settings_notes={'Sons curtos ao navegar e construir.','Reduz ondas, passaros e animacoes.','Ajusta vegetacao e custo das sombras.','Pixels inteiros nas duas distancias.','Escolha um momento do dia.','Escolha Portugues, English ou Deutsch. A troca e imediata.','Salva as preferencias neste dispositivo.'}
local language_codes={'pt','en','de'}
local language_names={pt='Português',en='English',de='Deutsch'}
local menu_lengths={title=4,new=5,confirm=2,load=3,pause=7,settings=7}
local function text(std,x,y,str,size,col,width,face)
    return Platform.text(x,y,tostring(str),size or 30,col or C.paper,width or max(40,1212-x),face or 'body')
end
local function title(std,x,y,str,size,col,width)
    return text(std,x,y,I18n.upper(str),size or 40,col or C.paper,width,'display')
end
local paragraph_lines,toast_lines,pause_toast_lines={},{},{}
local function wrap_lines(out,str,size,width)
    local row='';local count=0
    for word in str:gmatch('%S+') do
        local nextrow=row=='' and word or row..' '..word
        if row~='' and Platform.text_width(nextrow,size,'body')>width then
            count=count+1;out[count]=row;row=word
        else row=nextrow end
    end
    if row~='' then count=count+1;out[count]=row end
    for i=count+1,#out do out[i]=nil end
    return count
end
local function paragraph(std,x,y,str,size,col,width)
    local count=wrap_lines(paragraph_lines,str,size,width)
    for i=1,count do text(std,x,y+(i-1)*(size+6),paragraph_lines[i],size,col,width) end
    return y+max(1,count)*(size+6)
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
local function select_locale(locale)
    I18n.select(locale);S.toast='';S.toast_time=0;S.toast_height=0
    for i=1,#toast_lines do toast_lines[i]=nil end
    app_meta.description=I18n.t('Um pedacinho de mundo, do seu jeito.')
end
local function notify(msg,good)
    S.toast=msg;S.toast_time=3400;S.toast_good=good
    S.toast_height=24+wrap_lines(toast_lines,msg,26,738)*32
    wrap_lines(pause_toast_lines,msg,26,380)
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
local function previous_save()
    local value=Platform.load(S.slot)
    return World.decode(value) and value or ''
end
local function save_game(silent)
    if S.gesture then return end
    local ok=Platform.save(S.slot,World.encode(S.world),previous_save())
    if not silent or not ok then notify(I18n.t(ok and 'Ilha salva. Pode voltar quando quiser.' or 'Nao foi possivel salvar neste dispositivo.'),ok) end
    S.has_save=ok or S.has_save;S.saveclock=0
    return ok
end
local function pos(x,y,z)
    local zoom=S.zoom
    return floor(S.ox+(x-y-S.camx+S.camy)*32*zoom),floor(S.oy+((x+y-S.camx-S.camy)*16-z)*zoom)
end
local function display_pos(x,y,z)
    return floor(S.view_x+(x-y)*32*S.view_zoom),floor(S.view_y+((x+y)*16-z)*S.view_zoom)
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
local function world_sprite(key,sx,sy,scale,alpha,lit,x,y,z)
    Platform.sprite(key,sx,sy,scale,alpha,lit)
    Platform.depth(key,sx,sy,scale,x,y,z)
end
local actors=ActorRender.new(Activities,Platform,Traffic.sprite)
local function render_actors(w)
    actors:draw(w,S.motion)
end
local function render_world(std)
    local w=(S.screen=='new' or S.screen=='confirm') and S.preview or S.world
    if S.rendered_world~=w then w.dirty=true;S.rendered_world=w end
    S.phase=S.screen=='title' and .68 or Lighting.phase(S.light,S.skytime)
    if Lighting.update(w,S.phase,S.detail) then w.dirty=true end
    if w.dirty then
        Platform.cache_begin(table.concat(w.h,','),S.camx,S.camy,S.zoom,S.ox,S.oy,w.revision);S.visible=0
        local scene=S.scene or {};S.scene=scene;local sn=0;local si=1
        local sites=S.sites or {};S.sites=sites
        for i=1,576 do sites[i]=nil end
        for i=1,#w.jobs do
            local job=w.jobs[i];local nx,ny=World.footprint(job.building_id,job.rotation)
            for v=0,ny-1 do for u=0,nx-1 do sites[World.cell(job.x+u,job.y+v)]=site_keys[job.stage] end end
        end
        while si<=576 do
            local id=w.bid[si];local x=(si-1)%24;local y=floor((si-1)/24);local key
            if id>4 then key='b'..id..'_'..w.rot[si]
            elseif id==0 and w.occ[si]==0 and not sites[si] and w.deco[si]>0 and w.base[si]>0 and w.mask[si]==0 and S.detail==1 then
                key=(w.base[si]==1 and 'palm' or 'tree')..(w.deco[si]-1)
            end
            if key then sn=sn+1;scene[sn]=key..','..x..','..y..','..(World.elevation(w,id,x,y,w.rot[si])*16)..',0' end
            if id==3 and (x+y)%4==0 and w.mask[si]==0 then
                sn=sn+1;scene[sn]='lamp,'..x..','..y..','..(w.base[si]*16)..','..(w.linked[si] and w.power>=w.need and '1' or '0')
            end
            if sites[si] then sn=sn+1;scene[sn]=sites[si]..','..x..','..y..','..(w.base[si]*16)..',0' end
            si=si+1
        end
        Platform.scene(table.concat(scene,';',1,sn),S.phase,S.detail)
        local marks=S.zone_marks or {};S.zone_marks=marks;local mark_count=0
        for i=1,576 do
            if w.zones[i]>0 and w.occ[i]==0 then
                local x,y=(i-1)%24,floor((i-1)/24)
                mark_count=mark_count+1
                local mark=marks[mark_count] or {};marks[mark_count]=mark
                local z=w.base[i]*16;local mask=w.mask[i]
                mark[10],mark[11]=x,y
                mark[12],mark[13]=z+(mask%2==1 and 16 or 0),z+(floor(mask/2)%2==1 and 16 or 0)
                mark[14],mark[15]=z+(floor(mask/4)%2==1 and 16 or 0),z+(floor(mask/8)%2==1 and 16 or 0)
                mark[9]=w.zones[i]
            end
        end
        S.project_marks=true
        for i=mark_count+1,#marks do marks[i]=nil end
        S.flies=S.flies or {};local flies=S.flies;local fly_count=0
        local commands=S.render_commands or {};S.render_commands=commands
        local count=#w.drawlist
        for i=1,count do commands[i]=w.drawlist[i] end
        for i=1,576 do if sites[i] then count=count+1;commands[count]=(((i-1)%24)+floor((i-1)/24))*4096+3072+i end end
        for i=count+1,#commands do commands[i]=nil end
        table.sort(commands)
        local n=1
        while n<=#commands do
            local command=commands[n]%4096;local kind=floor(command/1024);local i=command%1024
            local x=(i-1)%24;local y=floor((i-1)/24);local id=w.bid[i]
            local base=kind==2 and id>0 and World.elevation(w,id,x,y,w.rot[i]) or w.base[i];local sx,sy=pos(x,y,base*16)
            if sx>-280 and sx<1560 and sy>-180 and sy<960 then
                if kind==0 then
                    local coast=w.base[i]==0 or (w.base[i]==1 and ((x>0 and w.base[i-1]==0) or (y>0 and w.base[i-24]==0) or (x<23 and w.base[i+1]==0) or (y<23 and w.base[i+24]==0)))
                    local key=(coast and 'sand' or 'grass')..w.mask[i]..'_'..((x*7+y*11+w.seed)%6)
                    world_sprite(key,sx,sy,S.zoom,1,true,x,y,base*16);S.visible=S.visible+1
                    if not (w.occ[i]>0 and w.bid[w.occ[i]]<=4) then Platform.shadow(Lighting.masks[i],sx,sy,S.zoom,w.mask[i],Lighting.R,x,y) end
                    Platform.ground_light(x,y,sx,sy,S.zoom,w.mask[i])
                elseif kind==1 then
                    Platform.shadow(Lighting.masks[i],sx,sy,S.zoom,0,Lighting.R,x,y)
                    Platform.ground_light(x,y,sx,sy,S.zoom,0)
                elseif kind==3 then
                    world_sprite(sites[i],sx,sy,S.zoom,1,false,x,y,base*16)
                elseif id>0 then
                    local key=id<=4 and road_sprite(w,i,id) or 'b'..id..'_'..w.rot[i]
                    if id==7 then local m=w.mask[i];key=m==0 and 'road2_10' or 'b7_'..(m==12 and 0 or m==9 and 1 or m==3 and 2 or 3) end
                    local powered=w.linked[i] and w.power>=w.need
                    world_sprite(key,sx,sy,S.zoom,1,powered,x,y,base*16)
                    if id<=4 then
                        local nx,ny=World.footprint(id,w.rot[i]);local v=0
                        while v<ny do local u=0
                            while u<nx do
                                local k=World.cell(x+u,y+v);local px,py=pos(x+u,y+v,w.base[k]*16)
                                Platform.shadow(Lighting.masks[k],px,py,S.zoom,w.mask[k],Lighting.R,x+u,y+v)
                                Platform.ground_light(x+u,y+v,px,py,S.zoom,w.mask[k]);u=u+1
                            end;v=v+1
                        end
                    elseif id==5 or id==6 then
                        local nx,ny=World.footprint(id,w.rot[i])
                        for v=0,ny-1 do for u=0,nx-1 do
                            local px,py=pos(x+u,y+v,base*16)
                            Platform.bridge(x+u,y+v,px,py,S.zoom,base*16)
                        end end
                    end
                    if id==3 and (x+y)%4==0 and w.mask[i]==0 then world_sprite('lamp',sx,sy,S.zoom,1,powered,x,y,base*16) end
                elseif S.detail==1 and not sites[i] then
                    world_sprite((w.base[i]==1 and 'palm' or 'tree')..(w.deco[i]-1),sx,sy,S.zoom,1,true,x,y,base*16)
                    if fly_count<6 and w.base[i]>1 then fly_count=fly_count+1;flies[fly_count*3-2]=x;flies[fly_count*3-1]=y;flies[fly_count*3]=base*16 end
                end
            end
            n=n+1
        end
        S.fly_count=fly_count;Platform.cache_end();w.dirty=false
    end
    Platform.world(S.phase,S.time,S.motion)
    local view=Platform.camera()
    S.view=view
    if not view then return end
    local vx=view.ox+(-view.cx+view.cy)*32*view.zoom
    local vy=view.oy+(-view.cx-view.cy)*16*view.zoom
    local changed=S.view_x~=vx or S.view_y~=vy or S.view_zoom~=view.zoom
    S.view_x,S.view_y,S.view_zoom=vx,vy,view.zoom
    if changed or S.project_marks then
        for i=1,#S.zone_marks do
            local m=S.zone_marks[i];local x,y=m[10],m[11]
            m[1],m[2]=display_pos(x,y,m[12]);m[3],m[4]=display_pos(x+1,y,m[13])
            m[5],m[6]=display_pos(x+1,y+1,m[14]);m[7],m[8]=display_pos(x,y+1,m[15])
        end
        S.project_marks=false
    end
    if S.screen=='play' and (S.tool=='zone' or S.tool=='inspect') then
        local marks=S.zone_marks
        for i=1,#marks do
            local m=marks[i];local color=zone_colors[m[9]]
            line(std,m[1],m[2],m[3],m[4],color);line(std,m[3],m[4],m[5],m[6],color)
            line(std,m[5],m[6],m[7],m[8],color);line(std,m[7],m[8],m[1],m[2],color)
            local sx,sy=(m[1]+m[5])*.5,(m[2]+m[6])*.5
            for dot=1,m[9] do box(std,sx+(dot-1)*5-3,sy-1,3,3,color) end
        end
    end
    render_actors(w)
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
                local x,y=display_pos(S.flies[k*3-2],S.flies[k*3-1],S.flies[k*3])
                x=x+floor(math.sin(S.time/2100+k)*18)*2
                y=y-14+floor(math.cos(S.time/1800+k)*8)*2
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
    title(std,78,78,I18n.t('MARE'),96,C.paper,432)
    ornament(std,82,180,354)
    text(std,82,208,I18n.t('Seu mundo, no seu ritmo.'),30,C.muted,400)
    local n=1
    while n<=4 do
        menu_button(std,66,302+(n-1)*72,398,I18n.t(title_items[n]),nil,S.selection==n)
        n=n+1
    end
    text(std,84,644,I18n.t('SETAS escolher   OK entrar'),26,C.muted,400)
    title(std,962,54,I18n.t('MAR ABERTO'),16,C.paper,246)
end
local function header(std)
    local w=S.world

    box(std,48,32,1184,82,C.panel)
    title(std,74,46,I18n.f('DIA %d',w.day),20,C.muted,144)
    text(std,74,73,I18n.t(w.free and 'Modo livre' or 'Jornada'),26,C.paper,140)
    icon('coin',246,54,1);text(std,286,45,w.free and I18n.t('Livre') or w.cash,34,C.gold,190)
    text(std,286,82,I18n.t('moedas'),22,C.muted)
    icon('people',472,54,1);text(std,512,45,w.population,34,C.paper,174)
    text(std,512,82,I18n.t('moradores'),22,C.muted)
    icon('power',708,54,1);text(std,746,45,I18n.f('%d / %d',w.power,w.need),34,w.power>=w.need and C.teal or C.red,188)
    text(std,746,82,I18n.t('energia'),22,C.muted)
    icon('happy',978,54,1);text(std,1018,45,I18n.f('%d%%',w.happy),34,C.paper,166)
    text(std,1018,82,I18n.t('felicidade'),22,C.muted)
end
local function terrain_tool()
    return S.tool=='raise' or S.tool=='lower' or S.tool=='level' or S.tool=='pull'
end
local function ground_pos(x,y,project)
    x=max(0,min(24,x));y=max(0,min(24,y))
    local xx=min(23,floor(x));local yy=min(23,floor(y));local u=x-xx;local v=y-yy
    local k=yy*25+xx+1;local h=S.world.h;local a,b,c,d=h[k],h[k+1],h[k+26],h[k+25]
    local z=u>=v and a+u*(b-a)+v*(c-b) or a+u*(c-d)+v*(d-a)
    return (project or display_pos)(x,y,z*16)
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
    if not S.view then return end
    if terrain_tool() then brush_draw(std);return end
    local w=S.world;local i=World.cell(S.cx,S.cy);local nx,ny=1,1
    if S.tool=='build' then nx,ny=World.footprint(S.build_id,S.rotation) end
    local good=true
    if S.tool=='build' then good=(S.paint and w.bid[i]==S.build_id) or World.valid(w,S.build_id,S.cx,S.cy,S.rotation)
    elseif S.tool=='zone' then good=World.zone_valid(w,S.zone_kind%4,S.cx,S.cy)
    elseif S.tool=='remove' then good=w.occ[i]>0 end
    local col=good and (S.tool=='zone' and zone_colors[S.zone_kind] or C.gold) or C.red
    local x0=S.cx;local y0=S.cy
    local v=0
    while v<ny do local u=0
        while u<nx do
            local xx=x0+u;local yy=y0+v
            if xx>=0 and yy>=0 and xx<24 and yy<24 then
                local k=World.cell(xx,yy);local h=w.base[k]*16;local mask=w.mask[k]
                local a,b=display_pos(xx,yy,h+(mask%2>=1 and 16 or 0));local c,d=display_pos(xx+1,yy,h+(floor(mask/2)%2==1 and 16 or 0))
                local e,f=display_pos(xx+1,yy+1,h+(floor(mask/4)%2==1 and 16 or 0));local g,j=display_pos(xx,yy+1,h+(floor(mask/8)%2==1 and 16 or 0))
                line(std,a,b,c,d,col);line(std,c,d,e,f,col);line(std,e,f,g,j,col);line(std,g,j,a,b,col)
                line(std,a,b+1,c,d+1,col);line(std,c,d+1,e,f+1,col)
            end
            u=u+1
        end;v=v+1
    end
    local sx,sy=display_pos(S.cx,S.cy,(S.tool=='build' and World.elevation(w,S.build_id,S.cx,S.cy,S.rotation) or w.base[i])*16)
    if S.tool=='build' then
        local id=S.build_id;local key=id<=4 and road_sprite(w,i,id) or 'b'..id..'_'..S.rotation
        Platform.sprite(key,sx,sy,S.view_zoom,good and 65/100 or 35/100)
    end
    box(std,sx-5,sy-9,10,6,col)
end
local function play_draw(std)
    selection_draw(std);header(std)
    local w=S.world;local i=World.cell(S.cx,S.cy);local id=w.occ[i]>0 and w.bid[w.occ[i]] or 0
    box(std,48,580,1184,100,C.panel)
    local label=S.tool=='zone' and I18n.t(zone_names[S.zone_kind]) or S.tool=='build' and I18n.catalog(S.build_id)[1] or S.tool=='inspect' and id>0 and I18n.catalog(id)[1] or I18n.t(captions[S.tool])
    if S.tool=='level' and S.stroke then label=S.stroke.target==0 and I18n.t('Nivelar: altura do mar') or I18n.f('Nivelar: altura %d',S.stroke.target) end
    text(std,76,594,label,32,C.paper,890)
    local msg=I18n.t('SETAS explorar    OK criar    VOLTAR pausa')
    local color=C.muted;local access_warning=false
    if S.tool=='build' then
        local good,reason=World.valid(w,S.build_id,S.cx,S.cy,S.rotation)
        msg=good and I18n.f('OK construir  /  Custo: %d  /  VOLTAR opcoes',World.price(w,S.build_id,S.cx,S.cy)) or I18n.f('%s  /  VOLTAR opcoes',reason)
        color=good and C.muted or C.red
        access_warning=good and not World.access(w,S.build_id,S.cx,S.cy,S.rotation)
        if S.paint then
            msg=I18n.t(S.gesture and 'SETAS tracar    OK terminar    VOLTAR cancelar' or 'OK comecar via    VOLTAR opcoes')
            color=S.gesture and C.gold or C.muted
        end
    elseif S.tool=='zone' then
        local valid,reason=World.zone_valid(w,S.zone_kind%4,S.cx,S.cy)
        msg=S.gesture and I18n.t('SETAS pintar    OK confirmar zona    VOLTAR cancelar') or valid and I18n.t('OK comecar zona    VOLTAR escolher uso') or reason
        color=valid and C.muted or C.red
    elseif S.tool=='inspect' and id>0 then
        access_warning=not w.linked[w.occ[i]]
        msg=I18n.t(access_warning and 'Sem acesso: construcao inativa    OK criar    VOLTAR pausa' or 'Com acesso    OK criar    VOLTAR pausa')
        color=access_warning and C.gold or C.muted
    elseif S.tool=='inspect' and w.reserved[i] then
        for j=1,#w.jobs do
            local job=w.jobs[j]
            if job.id==w.reserved[i] then
                msg=I18n.f('%s  /  %d%%',I18n.t(World.job_status[job.status]),floor(job.progress*100));break
            end
        end
    elseif S.tool=='inspect' and w.zones[i]>0 then
        local status=w.zone_status[i]
        msg=I18n.t(status=='footprint' and 'Autorize o lote inteiro: clinicas precisam de 2x1' or status=='capacity' and 'Aguardando uma das quatro equipes de obra' or status and World.job_status[status] or 'Zona autorizada: aguardando ocupacao')
    elseif S.gesture then
        msg=I18n.t(S.tool=='pull' and 'SETAS puxar    OK soltar    VOLTAR cancelar' or 'SETAS pintar    OK concluir    VOLTAR cancelar');color=C.gold
    elseif S.tool~='inspect' then
        msg=S.tool=='remove' and I18n.t('OK remover e recuperar 75%    VOLTAR explorar') or I18n.f(S.tool=='pull' and 'OK segurar    Pincel %s    VOLTAR opcoes' or S.tool=='level' and 'OK copiar altura    Pincel %s    VOLTAR opcoes' or 'OK comecar    Pincel %s    VOLTAR opcoes',I18n.t(brush_names[S.brush]))
    end
    text(std,76,635,msg,26,color,1110)
    text(std,1006,600,I18n.f('%+d / dia',w.balance),26,w.balance>=0 and C.teal or C.red,190)
    if access_warning then
        box(std,48,522,1184,50,C.panel)
        text(std,76,534,I18n.t('Sem acesso: ligue uma via ao lado para ativar.'),26,C.gold,1110)
    end
    if S.tool=='inspect' and w.reward<5 then
        local ready=World.goal_ready(w)
        box(std,48,134,396,80,C.panel)
        text(std,70,147,I18n.t(ready and 'Conquista pronta!' or World.goals[w.reward+1][1]),24,C.gold,352)
        text(std,70,180,ready and I18n.t('VOLTAR > Diario para receber') or I18n.f('%d%%  /  Diario na pausa',floor(World.progress(w)*100)),22,C.muted,336)
        box(std,70,204,332,2,C.line);box(std,70,204,max(2,floor(332*World.progress(w))),2,C.gold)
    end
end

local function dock(std,heading,names,icons,note,back,first_label)
    header(std);box(std,48,icons and 410 or 470,1184,icons and 270 or 210,C.panel)
    title(std,80,icons and 432 or 488,heading,32,C.paper,1080)
    text(std,80,icons and 480 or 530,note,26,C.muted,1090)
    local width=floor(1104/#names);local n=1
    while n<=#names do
        local x=80+(n-1)*width;local focus=S.selection==n
        if focus then box(std,x,icons and 526 or 572,width-14,icons and 84 or 48,C.gold) end
        if icons then icon(icons[n],x+14,540,1) end
        text(std,x+14,icons and 568 or 576,n==1 and first_label or I18n.t(names[n]),28,focus and C.paper or C.muted,width-40)
        n=n+1
    end
    footer(std,I18n.t(back))
end
local function toolbar_draw(std)
    local note=I18n.t(tool_notes[S.selection])
    if S.selection==4 then note=#S.world.undo>0 and I18n.f('Desfazer disponivel: %d acoes. O gesto inteiro volta.',#S.world.undo) or I18n.t('Nada para desfazer ainda.') end
    dock(std,I18n.t('O que vamos criar?'),tool_names,tool_ids,note,'SETAS escolher    OK usar    VOLTAR explorar')
end
local function terrain_draw(std)
    dock(std,I18n.t('Moldar a ilha'),terrain_names,terrain_ids,I18n.t(terrain_notes[S.selection]),'SETAS escolher    OK usar    VOLTAR ferramentas')
end
local function zones_draw(std)
    dock(std,I18n.t('Crescer em bairros'),zone_names,nil,I18n.t(zone_notes[S.selection]),'SETAS escolher    OK usar    VOLTAR ferramentas')
end
local function context_draw(std)
    selection_draw(std)
    local names,heading,note,first_label
    if S.tool=='build' then
        heading=I18n.catalog(S.build_id)[1]
        if S.paint then names=context_road_names;note='Cada tracado pode ser desfeito de uma vez.'
        else names=context_build_names;note=S.selection==1 and 'OK gira 90 graus e volta para a ilha.' or S.selection==2 and 'Escolha outra peca. A ilha fica como esta.' or 'Volte a explorar a ilha.' end
    elseif S.tool=='zone' then
        heading=I18n.t(zone_names[S.zone_kind]);names=context_zone_names;note=zone_notes[S.zone_kind]
    else
        heading=I18n.t(captions[S.tool]);names=context_terrain_names;first_label=I18n.f('Pincel: %s',I18n.t(brush_names[S.brush]))
        note=S.selection==1 and 'OK muda o tamanho. A terra leva as construcoes junto.' or S.selection==2 and 'Troque entre elevar, baixar, nivelar e distorcer.' or 'Volte a explorar a ilha.'
    end
    dock(std,heading,names,nil,I18n.t(note),'SETAS escolher    OK usar    VOLTAR explorar',first_label)
end
local function catalog_draw(std)
    frame(std,I18n.t('Construir'),I18n.t('Escolha o que vai fazer parte da sua ilha.'))
    local cat=1
    while cat<=5 do pill(std,78+(cat-1)*224,170,I18n.t(categories[cat]),S.category==cat,210);cat=cat+1 end
    local range=ranges[S.category];local count=range[2]-range[1]+1;local page=floor((S.item-1)/6);local n=page*6+1
    while n<=min(count,page*6+6) do
        local id=range[1]+n-1;local d=I18n.catalog(id);local index=n-page*6-1;local x=78+(index%3)*238;local y=234+floor(index/3)*182;local focus=S.item==n and not S.tab_focus
        box(std,x,y,222,166,focus and C.gold or C.line)
        local key=id<=4 and 'road'..id..'_10' or 'b'..id..'_0'
        Platform.thumb(key,x+111,y+42,186,76)
        text(std,x+16,y+82,d[10],26,focus and C.paper or C.muted,194)
        text(std,x+16,y+108,d[11],26,focus and C.paper or C.muted,194)
        text(std,x+16,y+131,I18n.f('%d  /  %dx%d',d[5],d[3],d[4]),22,C.gold,190)
        n=n+1
    end
    local id=range[1]+S.item-1;local d=Catalog[id]
    line(std,812,234,812,590,C.line)
    title(std,842,242,I18n.t('SELECIONADO'),18,C.gold,350)
    Platform.thumb(id<=4 and 'road'..id..'_10' or 'b'..id..'_0',1018,376,348,186)
    text(std,842,488,I18n.f('%d x %d terrenos',d[3],d[4]),28,C.paper,352)
    text(std,842,528,I18n.f('Custo: %d moedas',d[5]),28,C.gold,352)
    text(std,842,564,I18n.f('%d moedas / dia',d[6]),26,C.muted,352)
    text(std,80,600,World.describe(id),24,C.teal,960)
    text(std,1100,600,I18n.f('%d / %d',page+1,math.ceil(count/6)),24,C.muted,100)
    footer(std,I18n.t(S.tab_focus and 'ESQUERDA / DIREITA categorias    OK ver construcoes    VOLTAR' or 'SETAS escolher    CIMA categorias    OK colocar    VOLTAR'))
end
local function pause_draw(std)
    frame(std,I18n.t('Um respiro'),I18n.t('Sua ilha fica guardada enquanto voce faz uma pausa.'))
    local n=1;while n<=7 do
        menu_button(std,78,168+(n-1)*64,572,I18n.t(pause_items[n]),nil,S.selection==n);n=n+1
    end
    Platform.minimap(722,234,420)
    if S.toast_time>0 and S.toast_good then
        for i=1,#pause_toast_lines do text(std,766,474+(i-1)*32,pause_toast_lines[i],26,C.paper,380) end
    else
        title(std,766,474,I18n.f('ILHA %d',S.slot),24,C.gold,380)
        text(std,766,520,I18n.f('Dia %d  /  Moradores: %d',S.world.day,S.world.population),28,C.paper,380)
        text(std,766,564,I18n.t(S.world.free and 'Modo livre' or 'Jornada'),26,C.muted,380)
    end
    footer(std,I18n.t('SETAS escolher    OK confirmar    VOLTAR continuar'))
end
local function settings_draw(std)
    frame(std,I18n.t('Ajustes'),I18n.t('Deixe a ilha confortavel para voce.'))
    local n=1;while n<=7 do
        local label
        if n==1 then label=I18n.t(S.sound and 'Som: ligado' or 'Som: desligado')
        elseif n==2 then label=I18n.t(S.motion and 'Movimento: ligado' or 'Movimento: reduzido')
        elseif n==3 then label=I18n.t(S.detail==1 and 'Detalhes: completos' or 'Detalhes: economicos')
        elseif n==4 then label=I18n.f('Zoom: %dx',S.preferred_zoom or 2)
        elseif n==5 then label=I18n.f('Luz: %s',I18n.t(Lighting.names[S.light]))
        elseif n==6 then label=I18n.f('Idioma: %s',I18n.t(language_names[I18n.locale()]))
        else label=I18n.t('Concluir') end
        menu_button(std,78,170+(n-1)*64,680,label,nil,S.selection==n);n=n+1
    end
    icon(S.phase>.8 and 'moon' or 'sun',934,250,3)
    paragraph(std,808,380,I18n.t(settings_notes[S.selection]),28,C.paper,380)
    paragraph(std,808,532,I18n.t('Manha, por do sol e luzes da noite.'),28,C.muted,380)
    footer(std,I18n.t('SETAS escolher    OK alterar    VOLTAR concluir'))
end
local help_pages={
    {'Sua ilha, seu ritmo','Setas movem o cursor pelas diagonais da ilha.','OK abre as ferramentas durante a exploracao.','Voltar cancela gestos ou abre opcoes da peca.','Ao explorar, Voltar abre a pausa e o diario.'},
    {'Moldar a terra','Elevar e Baixar: OK, setas para pintar, OK.','Nivelar: OK copia a altura; setas pintam nela.','Distorcer: OK segura; setas puxam; OK solta.','Casas sobem e descem; vias ganham rampas.'},
    {'Fazer a ilha crescer','Casas, lojas e servicos precisam de via ao lado.','Geradores e usinas tambem precisam de acesso.','Sem via, a construcao fica inativa.','Com acesso, energia e servicos atendem a ilha.'},
    {'Experimentar','Um dia passa a cada 12 segundos de partida.','Troque o piso de vias pagando a diferenca.','Remover devolve 75%; Desfazer recupera tudo.','No modo livre, construa sem limite de moedas.'},
    {'Pontes e praias','Pontes ocupam agua ou margens na altura 1.','Portos e quiosques precisam ficar junto da agua.','Rampas retas aceitam trilhas, passeios e ruas.','Com via: abrigo tem 2 animais; centro vet., 4.'}
}

local function help_draw(std)
    local p=help_pages[S.selection];frame(std,I18n.t(p[1]),I18n.f('GUIA DE BOLSO  /  %d DE %d',S.selection,#help_pages))
    local n=2;while n<=5 do
        pill(std,84,186+(n-2)*94,tostring(n-1),true,46)
        paragraph(std,155,190+(n-2)*94,I18n.t(p[n]),32,C.paper,1030);n=n+1
    end
    footer(std,I18n.t('ESQUERDA / DIREITA  paginas     OK ou VOLTAR  fechar'))
end
local function goals_draw(std)
    local w=S.world;frame(std,I18n.t('Diario da ilha'),I18n.t(w.free and 'MODO LIVRE  /  Sem limites para experimentar' or 'JORNADA  /  Cada conquista abre novas possibilidades'))
    local g=min(5,w.reward+1);local goal=World.goals[g]
    box(std,82,180,654,180,C.line)
    text(std,104,200,I18n.t(w.reward>=5 and 'A ilha e toda sua.' or goal[1]),32,C.gold,610)
    paragraph(std,104,248,I18n.t(w.reward>=5 and 'Todas as conquistas foram completadas.' or goal[2]),26,C.paper,610)
    text(std,104,322,w.reward>=5 and I18n.t('Continue criando, sem um fim obrigatorio.') or I18n.f('Recompensa: %d moedas',goal[3]),23,C.muted,610)
    menu_button(std,82,387,654,I18n.t(World.goal_ready(w) and 'Receber conquista' or 'Continuar explorando'),nil,true)
    text(std,82,484,I18n.f('Conquistas: %d / 5',w.reward),26,C.muted,654)
    text(std,82,528,I18n.f('Animais: %d    Pracas: %d    Lojas: %d',w.animals,w.parks,w.shops),25,C.muted,654)
    text(std,795,190,I18n.t('A CIDADE EM NUMEROS'),21,C.gold)
    local rows={{'Receita por dia',w.revenue},{'Manutencao',w.upkeep},{'Saldo por dia',w.balance},{'Agua / pessoas',I18n.f('%d / %d',w.water,w.population)},{'Saude / pessoas',I18n.f('%d / %d',w.health,w.population)},{'Educacao / pessoas',I18n.f('%d / %d',w.school,w.population)}}
    local n=1;while n<=#rows do
        text(std,795,239+(n-1)*57,I18n.t(rows[n][1]),20,C.muted,265);text(std,1070,236+(n-1)*57,rows[n][2],24);n=n+1
    end
    footer(std,I18n.t('OK receber ou explorar    VOLTAR pausa'))
end
local function new_draw(std)
    frame(std,I18n.t('Nova ilha'),I18n.t('Escolha a paisagem e o ritmo da partida.'))
    local n=1;while n<=5 do
        local label=n==1 and I18n.t('Jornada: construir e prosperar') or n==2 and I18n.t('Modo livre: criar sem custos') or n==3 and I18n.f('Paisagem: semente %d',S.seed) or n==4 and I18n.f('Arquivo: ilha %d',S.slot) or I18n.t('Criar esta ilha')
        menu_button(std,84,179+(n-1)*83,776,label,nil,S.selection==n)
        if n==1 and not S.new_free or n==2 and S.new_free then icon('check',792,194+(n-1)*83,1) end
        n=n+1
    end
    line(std,878,180,878,595,C.line)
    Platform.minimap(896,225,284)
    text(std,910,434,I18n.t('Sua paisagem'),22,C.gold)
    text(std,910,482,I18n.t('40 construcoes'),23,C.muted)
    text(std,910,524,I18n.t('5 conquistas'),23,C.muted)
    text(std,910,565,I18n.t('Espaco para 3 ilhas'),21,C.muted)
    footer(std,I18n.t('OK escolher    VOLTAR inicio    Confirme a criacao no final'))
end
local function confirm_draw(std)
    frame(std,I18n.t('Substituir esta ilha?'),I18n.f('O arquivo %d ja tem uma ilha salva.',S.slot))
    text(std,86,204,I18n.t('Seu novo mundo vai ocupar este arquivo.'),30)
    text(std,86,266,I18n.t('Os outros dois arquivos ficam guardados.'),26,C.muted)
    menu_button(std,84,380,538,I18n.t('Escolher outro arquivo'),nil,S.selection==1)
    menu_button(std,84,474,538,I18n.t('Substituir e criar a nova ilha'),nil,S.selection==2)
    footer(std,I18n.t('SETAS  escolher     OK  confirmar     VOLTAR  cancelar'))
end
local function load_draw(std)
    frame(std,I18n.t('Suas ilhas'),I18n.t('Tres pequenos mundos, guardados neste dispositivo.'))
    local n=1;while n<=3 do
        local data=Platform.load(n);local w=S.saved[n]
        menu_button(std,84,191+(n-1)*127,1108,I18n.f('Ilha %d',n),w and I18n.f('Dia %d  /  Moradores: %d  /  %s',w.day,w.population,I18n.t(w.free and 'Modo livre' or 'Jornada')) or I18n.t(#data>0 and 'Arquivo invalido. Escolha outra ilha.' or 'Este arquivo esta vazio'),S.selection==n);n=n+1
    end
    footer(std,I18n.t('SETAS  escolher     OK  continuar     VOLTAR  inicio'))
end
local function start_game()
    S.playing=true
    S.world=S.preview or World.new(S.seed,S.new_free or false);S.world.free=S.new_free or false;S.preview=nil;S.cx=11;S.cy=13;S.zoom=S.preferred_zoom or 2;S.ox=640;S.oy=375;home_camera();S.tool='inspect';S.gesture=nil;S.stroke=nil;S.elapsed=0;S.skytime=0
    open('play');if save_game(true) then notify(I18n.t('Bem-vindo a sua ilha! OK abre as ferramentas.'),true) end
end
local function follow_cursor()
    local sx,sy=ground_pos(S.cx,S.cy,pos);local margin=terrain_tool() and (S.brush+1)*46*S.zoom or 112
    if sx<48+margin or sx>1232-margin or sy<150+margin/2 or sy>550-margin/2 then home_camera() end
end
local function move_cursor(dx,dy)
    if S.toast_good==false then S.toast_time=0 end
    local nx=max(0,min(23,S.cx+dx));local ny=max(0,min(23,S.cy+dy))
    if nx==S.cx and ny==S.cy then return end
    if S.gesture then
        if S.tool=='build' and S.paint then
            S.cx=nx;S.cy=ny;local ok,msg=World.paint(S.world,S.build_id,nx,ny);if not ok then S.stroke.failure=msg;notify(msg,false) end
        elseif S.tool=='zone' then
            S.cx=nx;S.cy=ny
            local valid,msg=World.zone_valid(S.world,S.zone_kind%4,nx,ny)
            if valid then World.zone(S.world,S.zone_kind%4,nx,ny) else notify(msg,false) end
        elseif S.tool=='pull' then
            nx=max(S.gx-S.brush-1,min(S.gx+S.brush+1,nx));ny=max(S.gy-S.brush-1,min(S.gy+S.brush+1,ny))
            S.cx=nx;S.cy=ny
            local ok,msg=World.terraform(S.world,'pull',S.gx,S.gy,S.brush,S.gesture,nx-S.gx,ny-S.gy)
            if not ok then notify(msg,false) end
        else
            S.cx=nx;S.cy=ny
            local ok,msg=World.terraform(S.world,S.tool,nx,ny,S.brush,S.gesture,0,0,S.stroke)
            if not ok then S.stroke.failure=msg;notify(msg,false) end
        end
        follow_cursor();return
    end
    S.cx=nx;S.cy=ny;follow_cursor()
end
local function changed(snapshot)
    local w=S.world;local i=1
    while i<=625 do if snapshot.h[i]~=w.h[i] then return true end;i=i+1 end
    i=1;while i<=576 do if snapshot.bid[i]~=w.bid[i] or snapshot.rot[i]~=w.rot[i] or snapshot.zones[i]~=w.zones[i] then return true end;i=i+1 end
    return false
end
local function finish_edit(snapshot,label,failure)
    if not changed(snapshot) then notify(failure or I18n.t('Nenhuma alteracao neste gesto.'),not failure);return end
    snapshot.refund=snapshot.cash-S.world.cash;World.record(S.world,snapshot);notify(failure and I18n.f('Gesto parcial: %s',failure) or label,not failure);follow_cursor()
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
        if key=='a' then S.light=S.light%4+1;Platform.options(S.sound,S.motion,S.detail,S.preferred_zoom or 2,S.light,I18n.locale())
        elseif key=='menu' then S.zoom=S.view_return_zoom;S.view_return_zoom=nil;home_camera();open('pause',6) end
        return
    end
    if screen=='play' then
        if key=='left' then move_cursor(-1,0) elseif key=='right' then move_cursor(1,0) elseif key=='up' then move_cursor(0,-1) elseif key=='down' then move_cursor(0,1)
        elseif key=='menu' then
            if S.gesture then World.restore(S.world,S.gesture);S.cx=S.gx;S.cy=S.gy;S.gesture=nil;S.stroke=nil;follow_cursor();notify(I18n.t('Gesto cancelado.'),true)
            elseif S.tool=='inspect' then open('pause')
            elseif S.tool=='remove' then explore()
            else open('context') end
        elseif key=='a' then
            if S.tool~='inspect' then S.toast_time=0 end
            if S.tool=='inspect' then open('tools',S.tool_focus or 1)
            elseif S.tool=='build' then
                if S.paint then
                    if S.gesture then finish_edit(S.gesture,I18n.t('Via pronta.'),S.stroke.failure);S.gesture=nil;S.stroke=nil
                    else S.gesture=World.snapshot(S.world);S.stroke={};S.gx=S.cx;S.gy=S.cy;local ok,msg=World.paint(S.world,S.build_id,S.cx,S.cy);if not ok then S.gesture=nil;S.stroke=nil;notify(msg,false) end end
                else
                    local ok,msg=World.build(S.world,S.build_id,S.cx,S.cy,S.rotation)
                    if ok and not S.world.linked[World.cell(S.cx,S.cy)] then msg=I18n.f('%s: pronta. Ligue uma via ao lado para ativar.',I18n.catalog(S.build_id)[1]) end
                    notify(msg,ok)
                    if ok then local x,y=pos(S.cx,S.cy,S.world.base[World.cell(S.cx,S.cy)]*16);Platform.burst(x,y,true) end
                end
            elseif S.tool=='zone' then
                if S.gesture then finish_edit(S.gesture,I18n.t(S.zone_kind==4 and 'Zona removida. Construcoes prontas foram mantidas.' or 'Zona confirmada. Acompanhe as obras.'));S.gesture=nil
                else
                    local valid,msg=World.zone_valid(S.world,S.zone_kind%4,S.cx,S.cy)
                    if valid then S.gesture=World.snapshot(S.world);S.gx=S.cx;S.gy=S.cy;World.zone(S.world,S.zone_kind%4,S.cx,S.cy)
                    else notify(msg,false) end
                end
            elseif S.tool=='remove' then local ok,msg=World.remove(S.world,S.cx,S.cy);notify(msg,ok);if ok then local x,y=pos(S.cx,S.cy,S.world.base[World.cell(S.cx,S.cy)]*16);Platform.burst(x,y,false) end
            elseif S.tool=='pull' then
                if S.gesture then finish_edit(S.gesture,I18n.t('Costa redesenhada.'));S.gesture=nil
                else S.gesture=World.snapshot(S.world);S.gx=S.cx;S.gy=S.cy end
            else
                if S.gesture then finish_edit(S.gesture,I18n.t('Relevo e construcoes ajustados.'),S.stroke.failure);S.gesture=nil;S.stroke=nil
                else
                    S.gesture=World.snapshot(S.world);S.gx=S.cx;S.gy=S.cy
                    S.stroke={target=S.gesture.h[S.cy*25+S.cx+1]}
                    if S.tool~='level' then
                        local ok,msg=World.terraform(S.world,S.tool,S.cx,S.cy,S.brush,S.gesture,0,0,S.stroke)
                        if not ok then S.stroke.failure=msg;notify(msg,false) end
                        follow_cursor()
                    end
                end
            end
        end
        return
    end
    if screen=='tools' or screen=='terrain' or screen=='context' or screen=='zones' then
        local count=screen=='context' and ((S.tool=='build' and S.paint) or S.tool=='zone') and 2 or screen=='context' and 3 or screen=='tools' and 5 or 4
        if key=='menu' then
            if screen=='terrain' then open('tools',2) elseif screen=='zones' then open('tools',5) else explore() end
        elseif key=='left' or key=='up' then S.selection=max(1,S.selection-1)
        elseif key=='right' or key=='down' then S.selection=min(count,S.selection+1)
        elseif key=='a' then
            local n=S.selection
            if screen=='tools' then
                S.tool_focus=n
                if n==1 then catalog_open()
                elseif n==2 then open('terrain',S.terrain_focus or 1)
                elseif n==3 then S.tool='remove';open('play')
                elseif n==4 then local ok,msg=World.undo(S.world);explore();notify(msg,ok)
                else open('zones',S.zone_kind) end
            elseif screen=='terrain' then S.terrain_focus=n;S.tool=terrain_ids[n];follow_cursor();open('play')
            elseif screen=='zones' then S.zone_kind=n;S.tool='zone';open('play')
            elseif n==count then explore()
            elseif S.tool=='zone' then open('zones',S.zone_kind)
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
        if key=='a' then if World.claim(S.world) then notify(I18n.t('Conquista recebida! Sua ilha esta crescendo.'),true) else explore() end
        elseif key=='menu' then open('pause',3) end;return
    end
    local count=menu_lengths[screen] or 1
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
        if w then S.playing=true;S.world=w;S.slot=n;S.cx=11;S.cy=13;S.ox=640;S.oy=375;S.zoom=S.preferred_zoom or 2;S.tool='inspect';S.elapsed=0;home_camera();open('play') else notify(I18n.t('Este arquivo nao tem uma ilha valida.'),false) end
    elseif screen=='new' then
        if n==1 then S.new_free=false elseif n==2 then S.new_free=true elseif n==3 then S.seed=(S.seed+137)%9999;S.preview=World.new(S.seed,S.new_free or false) elseif n==4 then S.slot=S.slot%3+1
        else if #Platform.load(S.slot)>0 then open('confirm') else start_game() end end
    elseif screen=='confirm' then if n==1 then open('new',4) else start_game() end
    elseif screen=='pause' then
        if n==1 then S.tool='inspect';open('play') elseif n==2 then save_game(false) elseif n==3 then open('goals')
        elseif n==4 then S.return_to='pause';S.return_selection=4;open('settings') elseif n==5 then S.return_to='pause';S.return_selection=5;open('help')
        elseif n==6 then S.view_return_zoom=S.zoom;S.zoom=1;S.camx=11;S.camy=11;S.world.dirty=true;open('view')
        elseif n==7 and save_game(true) then S.playing=false;S.ox=880;S.oy=350;S.camx=11;S.camy=11;S.zoom=1;S.world.dirty=true;open('title') end
    elseif screen=='settings' then
        if n==1 then S.sound=not S.sound elseif n==2 then S.motion=not S.motion elseif n==3 then S.detail=3-S.detail;S.world.dirty=true
        elseif n==4 then
            S.preferred_zoom=3-(S.preferred_zoom or 2)
            if S.return_to=='pause' then S.zoom=S.preferred_zoom;S.world.dirty=true end
        elseif n==5 then S.light=S.light%4+1
        elseif n==6 then local locale=I18n.locale();local index=locale=='pt' and 1 or locale=='en' and 2 or 3;select_locale(language_codes[index%3+1])
        else open(S.return_to or 'title',S.return_selection) end
        Platform.options(S.sound,S.motion,S.detail,S.preferred_zoom or 2,S.light,I18n.locale())
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
    local options=Platform.get_options();local locale='pt'
    if options then
        S.sound=not string.find(options,'silent',1,true);S.motion=not string.find(options,'still',1,true)
        local detail,zoom,light,stored_locale=string.match(options,'^[^,]+,[^,]+,(%d),(%d),(%d),([^,]+)$')
        if not detail then detail,zoom,light=string.match(options,',[^,]+,(%d),(%d),?(%d?)') end
        S.detail=tonumber(detail)==2 and 2 or 1;S.preferred_zoom=tonumber(zoom)==1 and 1 or 2;S.light=max(1,min(4,tonumber(light) or 1))
        if stored_locale=='en' or stored_locale=='de' then locale=stored_locale end
    end
    select_locale(locale)
    if options and string.match(options,'^[^,]+,[^,]+,[^,]+,[^,]+,[^,]+$') then
        Platform.options(S.sound,S.motion,S.detail,S.preferred_zoom or 2,S.light,'pt')
    end
    if Platform.register then Platform.register(function(command,arg)
        if command=='state' then return S.screen..','..S.cx..','..S.cy..','..S.world.cash..','..S.world.population..','..S.selection..','..S.world.revision end
        if command=='tool' then return S.tool..','..S.brush..','..S.rotation..','..(S.gesture and 'gesture' or 'ready')..','..(S.paint and 'trace' or 'single')..','..S.category..','..S.item..','..(S.tab_focus and 'tabs' or 'cards') end
        if command=='level' then return S.stroke and S.stroke.target~=nil and tostring(S.stroke.target) or '' end
        if command=='save' then return World.encode(S.world) end
        if command=='checkpoint' then return S.playing and not S.gesture and World.encode(S.world) or '' end
        if command=='previous-save' then return previous_save() end
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
        World.update(S.world,dt)
        local event=World.take_event(S.world)
        while event do
            local x,y=pos(event.x,event.y,S.world.base[World.cell(event.x,event.y)]*16)
            Platform.burst(x,y,event.kind=='completed')
            notify(event.kind=='completed' and I18n.f('%s: obra concluida!',I18n.catalog(event.building_id)[1]) or I18n.t('Obra cancelada. Saldo nao gasto devolvido.'),true)
            event=World.take_event(S.world)
        end
        S.skytime=S.skytime+dt
        S.elapsed=S.elapsed+dt;S.saveclock=S.saveclock+dt
        if S.elapsed>=12000 then S.elapsed=S.elapsed-12000;local msg=World.tick(S.world);if msg then notify(msg,true) end end
        if S.saveclock>=30000 then save_game(true) end
    end
end
local function draw(self,std)
    render_world(std)
    Platform.ui_begin(S.time-(S.entered or 0),S.motion)
    if S.screen=='zones' then zones_draw(std) end
    if S.screen=='title' then title_draw(std) elseif S.screen=='play' then play_draw(std) elseif S.screen=='tools' then toolbar_draw(std)
    elseif S.screen=='catalog' then catalog_draw(std) elseif S.screen=='terrain' then terrain_draw(std) elseif S.screen=='context' then context_draw(std)
    elseif S.screen=='pause' then pause_draw(std) elseif S.screen=='settings' then settings_draw(std) elseif S.screen=='help' then help_draw(std)
    elseif S.screen=='goals' then goals_draw(std) elseif S.screen=='new' then new_draw(std) elseif S.screen=='confirm' then confirm_draw(std) elseif S.screen=='load' then load_draw(std)
    elseif S.screen=='view' then box(std,350,624,580,56,C.panel);text(std,378,640,I18n.t('OK mudar a luz   VOLTAR continuar'),28,C.paper,530) end
    if S.toast_time>0 and (S.screen=='play' or S.toast_good==false) then
        box(std,448,128,784,S.toast_height,C.dark);box(std,448,128,5,S.toast_height,S.toast_good==false and C.red or C.gold)
        for i=1,#toast_lines do text(std,472,138+(i-1)*32,toast_lines[i],26,S.toast_good==false and C.red or C.paper,738) end
    end
    Platform.ui_end()
end
return {meta=app_meta,callbacks={init=init,loop=loop,draw=draw}}
