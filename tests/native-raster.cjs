const fs=require('fs'),path=require('path');
const {LuaFactory}=require('wasmoon');
const root=path.resolve(__dirname,'..');
(async()=>{
 const factory=new LuaFactory();
 for(const name of ['assets','bits','binary','work','pixels','runs','surface','depth','raster','ocean','raycast','shadow_cache','shadows'])await factory.mountFile(`lua/native/${name}.lua`,fs.readFileSync(path.join(root,`src/native/${name}.lua`)));
 await factory.mountFile('assets/shadow-shapes.bin',fs.readFileSync(path.join(root,'assets/shadow-shapes.bin')));
 const atlas=JSON.parse(fs.readFileSync(path.join(root,'assets/atlas.json')));
 const shapes=['lamp','b11_0','b5_0'].map(key=>`${key}={cast={${atlas[key].cast.join(',')}}}`).join(',');
 const lua=await factory.createEngine();
 try{
  await lua.doString(`
   local Surface=require('lua.native.surface')
   local Depth=require('lua.native.depth')
   local Raster=require('lua.native.raster')
   local Runs=require('lua.native.runs')
   local image=Surface.new(9,7)
   local depths={}
   for y=0,6 do for x=0,8 do
    local k=y*9+x+1
    image.pixels[k]=(x+y)%3==0 and 0x90bb6b88 or 0xeac67dff
    depths[k]=string.pack('<i2',(x+y)%5==0 and -32768 or x*32-y*64)
   end end
   local data=table.concat(depths)
   image.depth={0}
   local palette=Runs.palette(string.pack('<I4I4',0xabcdef80,0x45ab78ff))
   local runs=Runs.new(string.pack('<I1I1I1I1I2',0,0,9,3,0)..string.pack('<I1I1I1I1I2',2,3,5,4,1),palette)
   local packed={w=9,h=7,runs=runs,depth={0}}
   local function sprite(target,source,x,y,scale,base,alpha)
    target.land:blit(source,x,y,scale,alpha)
    target.lights:blit(source,x,y,scale,alpha,true)
    target.depth:stamp(source,x,y,scale,base,data)
   end
   local function plane(target,x,y,scale,base)
    target.land:blit_plane(image,x,y,scale,target.depth,base)
    target.lights:rect(x,y,9*scale,7*scale,0xffce7748)
   end
   local function equal(a,b,label)
    for i=1,37*29 do assert(a.pixels[i]==b.pixels[i],label..' pixel '..i) end
   end
   for _,scale in ipairs({.5,1,1.5,2}) do
    local raster=Raster.new(37,29,8)
    for step=1,18 do
     local full={land=Surface.new(37,29),lights=Surface.new(37,29),depth=Depth.new(37,29)}
     local old_depth,old_pixels=raster.depth,{}
     for i=1,37*29 do old_pixels[i]=old_depth.pixels[i] end
     raster:begin()
     local function add(method,x,y,width,height,...)
      method(full,...)
      raster:add(method,x,y,width,height,...)
     end
     local shift=math.floor(step/3)
     add(sprite,-2.5,4.5,9*scale,7*scale,packed,-2.5,4.5,scale,2,.7)
     if step%6<3 then add(plane,6,7,9*scale,7*scale,6,7,scale,1.4) end
     if step<14 then add(sprite,7+shift,8,9*scale,7*scale,image,7+shift,8,scale,3,1) end
     if step%6>=3 then add(plane,6,7,9*scale,7*scale,6,7,scale,1.4) end
     add(sprite,31,24,9*scale,7*scale,packed,31,24,scale,5,1)
     raster:render()
     equal(raster.land,full.land,'land '..scale..'/'..step)
     equal(raster.lights,full.lights,'light '..scale..'/'..step)
     equal(raster.depth,full.depth,'occlusion '..scale..'/'..step)
     for i=1,37*29 do assert(old_depth.pixels[i]==old_pixels[i],'displayed occlusion remains immutable while a replacement is prepared') end
    end
   end
   local raster=Raster.new(37,29,8)
   local transient=Surface.new(9,7)
   transient.depth={0}
   transient:rect(0,0,9,7,0xffce7748)
   local retained=setmetatable({transient},{__mode='v'})
   raster:begin()
   raster:add(sprite,6,7,9,7,transient,6,7,1,2,1)
   raster:render()
   transient=nil
   raster:begin()
   raster:render()
   collectgarbage('collect')
   assert(retained[1]==nil,'removed scene sources are released after their replacement is rendered')
  `);
  console.log('PASS native regional raster: clipped alpha, packed sprites, ordering, removal, idle rebuilds, fractional scales and atomic occlusion match full-frame rendering.');
  await lua.doString(`
   local Ocean=require('lua.native.ocean')
   local heights={}
   for i=1,625 do heights[i]=0 end
   for y=8,16 do for x=7,15 do heights[y*25+x+1]=1 end end
   local ocean=Ocean.new()
   local changes={{9,7,1},{9,7,0},{0,0,1},{24,24,2},{23,23,1},{24,24,0},{11,10,2},{11,10,1}}
   for step,change in ipairs(changes) do
    heights[change[2]*25+change[1]+1]=change[3]
    local csv=table.concat(heights,',')
    local zoom=step<5 and 2 or 1
    local cx=step<5 and 10.5 or 13.25
    ocean:prepare(csv,cx,11,zoom,640,375)
    local fresh=Ocean.new()
    fresh:prepare(csv,cx,11,zoom,640,375)
    for _,name in ipairs({'ocean','sea'}) do
     local a,b=ocean[name],fresh[name]
     for i=1,a.w*a.h do assert(a.pixels[i]==b.pixels[i],name..' coast transition '..step..' pixel '..i) end
    end
   end
  `);
  console.log('PASS native regional ocean: coast expansion, removal, inland edits, map edges and camera/zoom changes match a fresh projection.');
  await lua.doString(`
   local Shadows=require('lua.native.shadows')
   local resources={sprites={${shapes}}}
   local heights={}
   for i=1,625 do heights[i]=1 end
   local cached=Shadows.new(resources,heights)
   local cases={
    {.72,1,1,'b11_0,10,10,16,0;lamp,10,10,16,1'},
    {.72,1,2,'b11_0,10,10,16,0;lamp,10,10,16,1'},
    {.72,1,1,'b11_0,10,10,16,0;lamp,10,10,16,1'},
    {.91,1,1,'lamp,10,10,16,1;lamp,11,10,16,1'},
    {.91,1,2,'lamp,10,10,16,1;lamp,11,10,16,1;b5_0,10,10,32,0'},
    {.91,1,2,'lamp,10,10,16,0;lamp,11,10,16,1'},
    {.72,2,1,'b11_0,10,10,16,0;b5_0,10,10,32,0'}
   }
   for step,case in ipairs(cases) do
    heights[10*25+11]=case[3]
    local csv=table.concat(heights,',')
    cached:prepare(csv,case[4],case[1],case[2])
    local fresh=Shadows.new(resources,heights)
    fresh:prepare(csv,case[4],case[1],case[2])
    for y=9,12 do for x=9,12 do for kind=1,3 do
     local corners=x==10 and y==10 and (case[3]-1) or 0
     local receiver=kind==3 and cached.decks[y*24+x+1] or nil
     local a=cached:tile(x,y,corners,'',8,kind==2,receiver)
     local b=fresh:tile(x,y,corners,'',8,kind==2,receiver)
     assert(not a==not b,'receiver visibility '..step)
     if a then for i=1,65*65 do assert(a.pixels[i]==b.pixels[i],'receiver transition '..step..' pixel '..i) end end
    end end end
    cached:finish()
   end
  `);
  console.log('PASS native regional receivers: edited slopes, caster removal, lamp power, bridges, day/night and quality changes match uncached lighting.');
 }finally{lua.global.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
