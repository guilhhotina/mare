const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert');
const {createCanvas,loadImage}=require('@napi-rs/canvas');
const {LuaFactory}=require('wasmoon');
const root=path.resolve(__dirname,'..');
const outfits=['casual','worker','maid','bunny','dress','suit','coat','overalls'];
const markerColors=[0xfa01fa,0xfb01fb,0xfc01fc,0x01fafa,0x01fbfb,0x01fcfc,0xfafa01,0xfbfb01,0xfcfc01];
const skinColors=[['bc8465','e4b38d','f7d2aa'],['c7927c','efc4ac','ffe1c2'],['9f684b','ca9167','e5b58a'],['815038','b17b53','d29a6c'],['573c31','82563f','ab7958'],['372b29','594033','855c46'],['9a795a','bea078','dec39d'],['a86855','ce957a','edb9a0']];
const shirtColors=[['245958','337c77','74afa0'],['822e3f','c44853','ec7b7a'],['9b652f','d59a49','f1c97c'],['625875','9789b0','c1b4d4'],['3f5876','647fa7','9ab1d0'],['4a644a','769363','a8be84'],['ada080','dfd3b1','fff0cf'],['38494e','5c6c6a','94a59c']];
const hairColors=[['2d292b','493a33','72604a'],['533c32','79513b','ae7851'],['977245','c7a365','ead094'],['693f33','9d5d3f','ce8f57'],['697779','9ba7a1','d3d7c6'],['25272b','383338','5a5050'],['46342f','6a4c3c','a27758'],['4b3d50','755879','aa88a4']];
function packed(skin,shirt,hair,outfit,accessory){return skin+shirt*8+hair*64+outfit*512+accessory*4096;}
(async()=>{
 const rects=JSON.parse(fs.readFileSync(root+'/assets/atlas.json'));
 const activities=JSON.parse(fs.readFileSync(root+'/art_source/activities.json'));
 const actions=new Map(activities.map(action=>[action.id,action]));
 const atlas=await loadImage(root+'/assets/atlas.png');
 const bytes=fs.readFileSync(root+'/assets/depths.bin');
 const webCanvas=createCanvas(1280,720),nativeCanvas=createCanvas(1280,720),referenceCanvas=createCanvas(1280,720);
 const webCtx=webCanvas.getContext('2d'),native=nativeCanvas.getContext('2d'),reference=referenceCanvas.getContext('2d');
 reference.imageSmoothingEnabled=false;
 const realm={window:{},document:{createElement:()=>createCanvas(1,1)}};
 vm.runInNewContext(fs.readFileSync(root+'/web/actors.js','utf8'),realm);
 const web=realm.window.MareActors(webCanvas,atlas,rects,bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength));
 const raisedHead=rects.actor_casual_0_teach_board_6;
 const poseCanvas=createCanvas(raisedHead.w,raisedHead.h),poseContext=poseCanvas.getContext('2d');
 poseContext.drawImage(atlas,raisedHead.x,raisedHead.y,raisedHead.w,raisedHead.h,0,0,raisedHead.w,raisedHead.h);
 const posePixels=poseContext.getImageData(0,0,raisedHead.w,raisedHead.h).data;
 const head=(raisedHead.oy-11)*raisedHead.w+raisedHead.ox,torso=(raisedHead.oy-6)*raisedHead.w+raisedHead.ox;
 const connected=new Uint8Array(raisedHead.w*raisedHead.h),pending=[head];
 connected[head]=1;
 for(let i=0;i<pending.length;i++){
  const x=pending[i]%raisedHead.w,y=Math.floor(pending[i]/raisedHead.w);
  for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){
   const nx=x+dx,ny=y+dy;
   if(nx<0||ny<0||nx>=raisedHead.w||ny>=raisedHead.h)continue;
   const next=ny*raisedHead.w+nx;
   if(!connected[next]&&posePixels[next*4+3]){connected[next]=1;pending.push(next);}
  }
 }
 assert(connected[torso],'the raised teaching head remains visibly connected to the torso');
 const actionIds=['walk','hammer','serve_coffee','hopscotch','greet_neighbor','file_papers','look_out','water_planter'];
 const details=[0,2,0,0,5,4,1,3];
 const cases=outfits.map((outfit,i)=>{
  const facing=i%4,action=actionIds[i],frame=i===0?0:Math.min(3,actions.get(action).frames-1);
  return{key:`actor_${outfit}_${facing}_${action}_${frame}`,appearance:packed(i,(i+3)%8,(i+5)%8,i,details[i]),accessory:details[i]?`actor_accessory_${details[i]}_${facing}_${action}_${frame}`:undefined};
 });
 for(const detail of [6,7])cases.push({key:'actor_casual_0_wait_0',appearance:packed(5,1,2,0,detail),accessory:`actor_accessory_${detail}_0_wait_0`});
 cases.push({key:'vehicle_car_0_0'},{key:'fauna_whale_1_36'});
 const masks=Array.from({length:4},(_,facing)=>({key:`actor_coat_${facing}_walk_0`,appearance:packed(5,1,3,6,1),accessory:`actor_accessory_1_${facing}_walk_0`}));
 const pressureKeys=[],pressureRegions=new Set();
 for(const key of Object.keys(rects)){
  if(!key.startsWith('actor_')||key.startsWith('actor_accessory_'))continue;
  const region=rects[key].y*atlas.width+rects[key].x;
  if(pressureRegions.has(region))continue;
  pressureRegions.add(region);pressureKeys.push(key);if(pressureKeys.length===520)break;
 }
 const keys=new Set([...cases,...masks].flatMap(item=>[item.key,item.accessory]).filter(key=>key&&rects[key]));
 for(const key of pressureKeys)keys.add(key);
 for(const action of ['walk','unlock_door'])for(let frame=0;frame<actions.get(action).frames;frame++)keys.add(`actor_casual_0_${action}_${frame}`);
 for(const key of ['actor_dress_0_walk_0','vehicle_car_0_1'])keys.add(key);
 const sprites={},runData=[],parts=[];
 const runPalette=[],paletteIndices=new Map();
 let depthLength=0;
 function depthMeta(key,meta){
  if(meta.depth){
   sprites[key].depth=[depthLength,meta.depth[1]];
   parts.push(bytes.subarray(meta.depth[0],meta.depth[0]+meta.depth[1]));depthLength+=meta.depth[1];
  }
 }
 for(const key of ['b11_0','grass15_0']){sprites[key]={...rects[key]};depthMeta(key,rects[key]);}
 for(const key of keys){
  const meta=rects[key];assert(meta,`Missing authored actor ${key}`);
  const sample=createCanvas(meta.w,meta.h),sampleCtx=sample.getContext('2d');
  sampleCtx.drawImage(atlas,meta.x,meta.y,meta.w,meta.h,0,0,meta.w,meta.h);
  const pixels=sampleCtx.getImageData(0,0,meta.w,meta.h).data,runs=[];
  const colors=new DataView(pixels.buffer,pixels.byteOffset,pixels.byteLength);
  for(let x=0;x<meta.w;x++)for(let y=0;y<meta.h;){
   const color=colors.getUint32((y*meta.w+x)*4);let end=y+1;
   while(end<meta.h&&colors.getUint32((end*meta.w+x)*4)===color)end++;
   if(color&255){
    let index=paletteIndices.get(color);
    if(index===undefined){index=runPalette.length;runPalette.push(color);paletteIndices.set(color,index);}
    runs.push(x,y,1,end-y,index);
   }
   y=end;
  }
  runData.push(runs);sprites[key]={...meta,offset:runData.length};depthMeta(key,meta);
 }
 function pixels(context){return context.getImageData(0,0,1280,720).data;}
 function opaque(image){let n=0;for(let i=3;i<image.length;i+=4)if(image[i])n++;return n;}
 function beginWeb(zoom,phase,obstacle){
  webCtx.clearRect(0,0,1280,720);web.begin(10,10,zoom,640,360);web.tone(phase===1?[255,255,244]:[86,109,161]);
  if(obstacle==='house')web.stamp('b11_0',640,360-16*zoom,zoom,10,10,16);
  if(obstacle==='ground')web.stamp('grass15_0',640,360,zoom,10,10,0);
 }
 function referenceLayer(key,appearance,zoom,phase,wx,wy,z){
  const meta=rects[key];if(!meta)return;
  const sample=createCanvas(meta.w,meta.h),g=sample.getContext('2d');
  g.drawImage(atlas,meta.x,meta.y,meta.w,meta.h,0,0,meta.w,meta.h);
  const image=g.getImageData(0,0,meta.w,meta.h),rgb=phase===1?[255,255,244]:[86,109,161];
  const ramp=appearance===undefined?null:[...skinColors[appearance%8],...shirtColors[Math.floor(appearance/8)%8],...hairColors[Math.floor(appearance/64)%8]].map(value=>parseInt(value,16));
  for(let i=0;i<image.data.length;i+=4){
   let color=(image.data[i]<<16)|(image.data[i+1]<<8)|image.data[i+2];
   const marker=markerColors.indexOf(color);if(ramp&&marker>=0)color=ramp[marker];
   image.data[i]=Math.round((color>>>16)*rgb[0]/255);
   image.data[i+1]=Math.round(((color>>>8)&255)*rgb[1]/255);
   image.data[i+2]=Math.round((color&255)*rgb[2]/255);
  }
  g.putImageData(image,0,0);
  const x=Math.floor(640+(wx-wy)*32*zoom-meta.ox*zoom),y=Math.floor(360+(wx+wy-20)*16*zoom-z*zoom-meta.oy*zoom);
  reference.drawImage(sample,x,y,meta.w*zoom,meta.h*zoom);
 }
 const lua=await new LuaFactory().createEngine({enableProxy:false});
 try{
  lua.global.set('actor_module',fs.readFileSync(root+'/src/native/actors.lua','utf8'));
  lua.global.set('depth_module',fs.readFileSync(root+'/src/native/depth.lua','utf8'));
  lua.global.set('work_module',fs.readFileSync(root+'/src/native/work.lua','utf8'));
  lua.global.set('bits_module',fs.readFileSync(root+'/src/native/bits.lua','utf8'));
  lua.global.set('binary_module',fs.readFileSync(root+'/src/native/binary.lua','utf8'));
  lua.global.set('runs_module',fs.readFileSync(root+'/src/native/runs.lua','utf8'));
  lua.global.set('appearance_module',fs.readFileSync(root+'/src/appearance.lua','utf8'));
  lua.global.set('render_module',fs.readFileSync(root+'/src/actor_render.lua','utf8'));
  lua.global.set('traffic_module',fs.readFileSync(root+'/src/traffic.lua','utf8'));
  lua.global.set('activities',activities);
  lua.global.set('sprites',sprites);
  lua.global.set('actor_runs',runData);
  lua.global.set('actor_palette',runPalette);
  lua.global.set('depth_bytes',Array.from(Buffer.concat(parts)));
  lua.global.set('draw_color',color=>{native.fillStyle=`rgba(${(color>>>24)&255},${(color>>>16)&255},${(color>>>8)&255},${(color&255)/255})`;});
  lua.global.set('draw_rect',(_mode,x,y,w,h)=>native.fillRect(x,y,w,h));
  await lua.doString(`
   package.preload['lua.native.bits']=assert(load(bits_module))
   package.preload['lua.native.binary']=assert(load(binary_module))
   package.preload['lua.native.work']=assert(load(work_module))
   package.preload['lua.native.runs']=assert(load(runs_module))
   local Runs=require('lua.native.runs')
   local palette_parts={}
   for _,color in ipairs(actor_palette) do palette_parts[#palette_parts+1]=string.pack('<I4',color) end
   local palette=Runs.palette(table.concat(palette_parts))
   local Depth=assert(load(depth_module))()
   local Actors=assert(load(actor_module))()
   local Appearance=assert(load(appearance_module))()
   local ActorRender=assert(load(render_module))()
   local Traffic=assert(load(traffic_module))()
   local resources={sprites=sprites,std={draw={color=draw_color,rect=draw_rect}}}
   function resources:source(meta)
    if not meta.runs then
     local source,chunks=actor_runs[meta.offset],{}
     for i=1,#source,5 do chunks[#chunks+1]=string.pack('<I1I1I1I1I2',source[i],source[i+1],source[i+2],source[i+3],source[i+4]) end
     meta.runs=Runs.new(table.concat(chunks),palette)
    end
    return meta
   end
   local chunks={}
   for i=1,#depth_bytes,4096 do chunks[#chunks+1]=string.char(table.unpack(depth_bytes,i,math.min(i+4095,#depth_bytes))) end
   local data=table.concat(chunks)
   local actors=Actors.new(resources,data)
   local fields={[1]=Depth.new(1280,720),[2]=Depth.new(640,360)}
   fields[1].obstacle=false;fields[2].obstacle=false
   local serial,scene=0,nil
   local function prepare(zoom,phase,obstacle)
    local factor=zoom>=2 and 2 or 1
    local depth=fields[zoom]
    if depth.obstacle~=obstacle then
     depth:clear();depth.obstacle=obstacle
     if obstacle then
      local r=sprites[obstacle=='house' and 'b11_0' or 'grass15_0']
      local z=obstacle=='house' and 16 or 0
      depth:stamp(r,(640-r.ox*zoom)/factor,(360-z*zoom-r.oy*zoom)/factor,zoom/factor,20+z/16,data)
     end
    end
    serial=serial+1
    scene={zoom=zoom,factor=factor,cx=10,cy=10,ox=640,oy=360,depth=depth,generation=serial,tone_red=phase==1 and 255 or 86,tone_green=phase==1 and 255 or 109,tone_blue=phase==1 and 244 or 161}
   end
   function render(zoom,phase,obstacle,wx,wy,key,appearance,accessory,z)
    prepare(zoom,phase,obstacle)
    actors:draw(scene,key,wx,wy,z or 16,appearance,accessory)
   end
   local renderer=ActorRender.new(activities,{actor=function(...) actors:draw(scene,...) end},Traffic.sprite)
   function render_world(motion)
    prepare(1,1,false)
    local p=fixture_world.people[1]
    local action,time,appearance=p and p.action,p and p.action_time,p and p.appearance
    renderer:draw(fixture_world,motion)
    assert(fixture_world.dirty==false,'Actor rendering invalidated the world')
    assert(not p or p.action==action and p.action_time==time and p.appearance==appearance,'Rendering changed simulation activity or rerolled appearance')
   end
   local skins,shirts,hairs,outfits,accessories={},{},{},{},{}
   local themed=0
   for id=1,4096 do
    local value=Appearance.make(734,id,'resident')
    assert(value==Appearance.make(734,id,'resident'),'Appearance changed on replay')
    assert(value>=0 and value<=32767 and value%1==0,'Invalid packed appearance')
    skins[value%8]=true;shirts[math.floor(value/8)%8]=true;hairs[math.floor(value/64)%8]=true
    local outfit,accessory=math.floor(value/512)%8,math.floor(value/4096)%8
    outfits[outfit]=true;accessories[accessory]=true
    if outfit==3 or accessory==1 or accessory==7 then themed=themed+1 end
    if outfit==2 or outfit==3 then assert(accessory==0 or accessory==2,'Built-in headwear received another hat') end
    local worker=Appearance.make(734,id,'worker')
    assert(math.floor(worker/512)%8==1,'Worker lost work clothing')
    local detail=math.floor(worker/4096)%8
    assert(detail==0 or detail==1 or detail==2,'Worker received doubled headwear')
   end
   for i=0,7 do assert(skins[i] and shirts[i] and hairs[i] and accessories[i],'An appearance choice is unreachable') end
   for _,i in ipairs({0,2,3,4,5,6,7}) do assert(outfits[i],'A resident outfit is unreachable') end
   assert(themed>0 and themed<4096*.04,'Themed appearances stopped being rare')
   math.randomseed(171)
   local expected=math.random()
   math.randomseed(171)
   Appearance.make(41,19,'resident')
   assert(math.random()==expected,'Appearance generation altered simulation randomness')
   local different=0
   for id=1,32 do if Appearance.make(734,id,'resident')~=Appearance.make(735,id,'resident') then different=different+1 end end
   assert(different>24,'Island seed does not diversify appearances')
  `);
  const render=lua.global.get('render');
  let checks=0;const coverage=new Map();
  async function compare(item,zoom,phase,obstacle,x,y,z=16){
   beginWeb(zoom,phase,obstacle);native.clearRect(0,0,1280,720);
   web.actor(item.key,x,y,z,item.appearance,item.accessory);
   await render(zoom,phase,obstacle,x,y,item.key,item.appearance,item.accessory,z);
   const actual=pixels(native),expected=pixels(webCtx);
   assert.deepEqual(actual,expected,`actor parity key=${item.key}, zoom=${zoom}, phase=${phase}, obstacle=${obstacle}, position=${x},${y},${z}`);
   if(!obstacle){
    reference.clearRect(0,0,1280,720);referenceLayer(item.key,item.appearance,zoom,phase,x,y,z);
    if(item.accessory)referenceLayer(item.accessory,item.appearance,zoom,phase,x,y,z);
    assert.deepEqual(actual,pixels(reference),`authored palette and layers key=${item.key}, appearance=${item.appearance}, zoom=${zoom}, phase=${phase}`);
   }
   checks++;return actual;
  }
  for(const item of cases)for(const zoom of [1,2])for(const phase of [1,2])for(const obstacle of [false,'house'])for(const [x,y] of [[9.75,10.25],[10.75,10.25],[12.5,10.5],[10.53,10.42]]){
   const actual=await compare(item,zoom,phase,obstacle,x,y);
   if(item===cases[0])coverage.set([zoom,phase,obstacle,x,y].join(','),opaque(actual));
  }
  for(const zoom of [1,2])for(const phase of [1,2]){
   const covered=coverage.get([zoom,phase,'house',9.75,10.25].join(','));
   const open=coverage.get([zoom,phase,false,9.75,10.25].join(','));
   assert(covered<open/2,'House hides the actor behind it');
   assert.equal(coverage.get([zoom,phase,'house',12.5,10.5].join(',')),coverage.get([zoom,phase,false,12.5,10.5].join(',')),'Actor in front of house remains fully visible');
   const buried=await compare(cases[0],zoom,phase,'ground',10.5,10.5,0);
   const raised=await compare(cases[0],zoom,phase,'ground',10.5,10.5,16);
   assert(opaque(buried)<opaque(raised),'Raised terrain hides lower actor pixels without hiding an actor standing on it');
  }
  for(const item of masks)for(const zoom of [1,2])for(const phase of [1,2])for(const obstacle of [false,'house'])await compare(item,zoom,phase,obstacle,9.75,10.25);
  const initial=await compare(cases[0],1,1,false,12.5,10.5);
  for(let i=0;i<pressureKeys.length;i++){
   const appearance=i%512;
   web.actor(pressureKeys[i],12.5,10.5,16,appearance);
   await render(1,1,false,12.5,10.5,pressureKeys[i],appearance,undefined,16);
  }
  assert.deepEqual(await compare(cases[0],1,1,false,12.5,10.5),initial,'Retired frame and appearance caches changed a returning actor');
  assert.throws(()=>web.actor('actor_resident_0_arrive_0',10,10,16,0));
  assert.throws(()=>render(1,1,false,10,10,'actor_resident_0_arrive_0',0));
  function person(action,time,appearance=cases[0].appearance,visible=true,x=9.5,y=9.5){return{x,y,z:16,facing:0,action,action_time:time,appearance,visible};}
  function world(people,traffic=[],step=0,lifeStep=0){return{people,traffic,traffic_state:{step},life_step:lifeStep,dirty:false};}
  async function worldImage(fixture,motion,expected){
   lua.global.set('fixture_world',fixture);native.clearRect(0,0,1280,720);beginWeb(1,1,false);
   await lua.global.get('render_world')(motion);
   for(const item of expected)web.actor(item.key,item.x,item.y,item.z,item.appearance,item.accessory);
   assert.deepEqual(pixels(native),pixels(webCtx),'World actor visibility, frame timing, interpolation and compositing');
   checks++;
  }
  for(const action of ['walk','unlock_door']){
   const meta=actions.get(action);
   for(const time of [0,meta.frame_ms-.01,meta.frame_ms,meta.frames*meta.frame_ms+meta.frame_ms]){
    let frame=Math.floor(time/meta.frame_ms);frame=meta.loop?frame%meta.frames:Math.min(frame,meta.frames-1);
    const p=person(action,time);
    await worldImage(world([p]),true,[{key:`actor_casual_0_${action}_${frame}`,x:10,y:10,z:16,appearance:p.appearance}]);
   }
  }
  const moving=person('walk',actions.get('walk').frame_ms*3);
  await worldImage(world([moving]),false,[{key:'actor_casual_0_walk_0',x:10,y:10,z:16,appearance:moving.appearance}]);
  await worldImage(world([person('walk',0,0,false)]),true,[]);
  const front=person('walk',0,packed(2,1,3,0,0),true,10,10),back=person('walk',0,packed(5,2,6,4,0),true,9.75,9.75);
  const traffic={previous_x:9.5,previous_y:9.5,previous_z:16,x:10,y:10,z:16,visible:true,sprite:'vehicle_car_0_1',still_sprite:'vehicle_car_0_0'};
  await worldImage(world([front,back],[traffic],30,7.5),true,[
   {key:'actor_dress_0_walk_0',x:10.25,y:10.25,z:16,appearance:back.appearance},
   {key:'vehicle_car_0_1',x:10.375,y:10.375,z:16},
   {key:'actor_casual_0_walk_0',x:10.5,y:10.5,z:16,appearance:front.appearance}
  ]);
  for(const [step,lifeStep,x] of [[40,9,10.49],[0,0,10]])await worldImage(world([],[traffic],step,lifeStep),false,[{key:'vehicle_car_0_0',x,y:x,z:16}]);
  lua.global.set('fixture_world',world([person('legacy_work',0)]));
  assert.throws(()=>lua.global.get('render_world')(true));
  console.log('PASS actors: '+checks+' pixel comparisons covering deterministic appearances, action timing, visibility, compositing, cache turnover, both zooms, day/night and building/ground occlusion.');
 }finally{lua.global.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
