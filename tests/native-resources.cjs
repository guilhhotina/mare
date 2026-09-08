const fs=require('fs'),path=require('path');
const {LuaFactory}=require('wasmoon');
const root=path.resolve(__dirname,'..');
(async()=>{
 const lua=await new LuaFactory().createEngine();
 try{
  lua.global.set('module_source',fs.readFileSync(root+'/src/native/resources.lua','utf8'));
  lua.global.set('surface_source',fs.readFileSync(root+'/src/native/surface.lua','utf8'));
  lua.global.set('work_source',fs.readFileSync(root+'/src/native/work.lua','utf8'));
  lua.global.set('bits_source',fs.readFileSync(root+'/src/native/bits.lua','utf8'));
  lua.global.set('binary_source',fs.readFileSync(root+'/src/native/binary.lua','utf8'));
  lua.global.set('queue_source',fs.readFileSync(root+'/src/native/render_queue.lua','utf8'));
  lua.global.set('assets_source',fs.readFileSync(root+'/src/native/assets.lua','utf8'));
  await lua.doString(`
   package.preload['lua.native.assets']=assert(load(assets_source))
   package.preload['lua.native.bits']=assert(load(bits_source))
   package.preload['lua.native.binary']=assert(load(binary_source))
   package.preload['lua.native.work']=assert(load(work_source))
   package.preload['lua.native.surface']=assert(load(surface_source))
   local Resources=assert(load(module_source))()
   local loaded=false
   local removed=false
   local std={image={load=function() return 1 end,mensure=function() if loaded then return 2,2 else return 0,0 end end,unload=function() removed=true end,draw=function() end}}
   local resources=setmetatable({std=std,textures={},pending={},writing={},serial=0,frame=0,bytes=0,count=0,limit=1024},Resources)
   local surface={w=2,h=2,write=function() end}
   local entry=resources:add('scene',surface,1,255,255,255,nil,nil,true)
   resources:poll(6000)
   assert(not entry.ready and not removed,'slow frame before request does not fail or discard an upload')
   loaded=true
   resources:poll(34)
   assert(entry.ready,'completed upload remains usable')
   loaded=false
   local failure=resources:add('failed',surface,1,255,255,255,nil,nil,true)
   resources:poll(34)
   local ok,message=pcall(function() resources:poll(5001) end)
   assert(not ok and message:find('native image did not load',1,true),'a request actually pending beyond its deadline still fails explicitly')
   local Work=require('lua.native.work')
   local budgeted=setmetatable({std=std,textures={},pending={},writing={},serial=0,frame=0,bytes=0,count=0,limit=16},Resources)
   local encoding={w=2,h=2,write=function() Work.check() end}
   local worker=coroutine.create(function() budgeted:add('building',encoding,1,255,255,255,nil,nil,true) end)
   assert(not Work.resume(worker,0),'large encoding can pause before its upload')
   local admitted,reason=pcall(function() budgeted:add('menu',surface,1,255,255,255,nil,nil,true) end)
   assert(not admitted and reason:find('working set exceeds cache budget',1,true),'encoding reserves its texture budget before another UI upload can consume it')
   assert(Work.resume(worker,1),'reserved encoding completes after the unrelated request is rejected')
   loaded=true;budgeted:poll(16)
   assert(budgeted:find('building').ready,'the original reserved texture remains usable')
   local Queue=assert(load(queue_source))()
   local clock,time=os.clock,0
   os.clock=function() return time end
   local completed={}
   local world={
    begin=function(self,value) self.value=value;time=time+.01 end,
    finish=function(self) completed[#completed+1]=self.value;time=time+.01 end
   }
   local queue=Queue.new(world)
   queue:begin(1);queue:finish();queue:step()
   queue:begin(2);queue:finish()
   queue:begin(3);queue:finish()
   for i=1,8 do queue:step() end
   os.clock=clock
   assert(#completed==2 and completed[1]==1 and completed[2]==3,'active scene completes while queued scenes coalesce to the latest update')
  `);
  console.log('PASS native resources: upload deadlines, texture budgets and non-starving scene updates.');
 }finally{lua.global.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
