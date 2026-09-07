
const fs=require('fs'),path=require('path'),{LuaFactory}=require('wasmoon');
const root=path.resolve(__dirname,'..');
const luaValue=v=>Array.isArray(v)?'{'+v.map(luaValue).join(',')+'}':String(v);
const caster=JSON.parse(fs.readFileSync(root+'/assets/casters.json'));
(async()=>{
 const lua=await new LuaFactory().createEngine();
 let code='local Catalog=(function() '+fs.readFileSync(root+'/src/catalog.lua')+' end)()\n';
 code+='local Casters={'+Object.entries(caster).map(([k,v])=>'['+JSON.stringify(k)+']='+luaValue(v)).join(',')+'}\n';
 code+='local World=(function() '+fs.readFileSync(root+'/src/world.lua')+' end)()\n';
 code+='local Lighting=(function() '+fs.readFileSync(root+'/src/lighting.lua')+' end)()\n';
 code+=`
 local w=World.new(2706,true)
 for i=1,625 do w.h[i]=1 end
 for i=1,576 do w.bid[i]=0;w.deco[i]=0 end
 World.rebuild(w)
 Lighting.update(w,.72,1)
 for i=1,576 do assert(Lighting.masks[i]=='','Flat empty terrain must have no cast shadows') end
 assert(not Lighting.update(w,.72,1),'An unchanged sun must reuse the cache')
 local function count()
  local n=0;for i=1,576 do for c in Lighting.masks[i]:gmatch('1') do n=n+1 end end;return n
 end
 w.bid[World.cell(10,10)]=16;World.rebuild(w);Lighting.update(w,.72,1)
 assert(count()==0,'Object footprints must not produce coarse replacement shadows')
 Lighting.update(w,.91,1);assert(count()==0,'Night clears solar terrain shadows')
 Lighting.update(w,.72,2);assert(Lighting.R==4,'Economy terrain grid')
 local slope=World.new(3912,true);Lighting.update(slope,.31,1)
 for y=0,23 do for x=0,23 do
  local h=Lighting.ground(slope,x+.5,y+.5);local i=World.cell(x,y)
  assert(h>=slope.base[i]*16 and h<=slope.top[i]*16,'Shadows follow the terrain surface')
 end end
 print('PASS lighting: flat ground, separated object projection, night, economy mode, 576 terrain receivers, cached sun.')
 `;
 await lua.doString(code);lua.global.close();
})().catch(e=>{console.error(e);process.exitCode=1;});
