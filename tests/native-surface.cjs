const fs=require('fs'),path=require('path');
const {LuaFactory}=require('wasmoon');
const root=path.resolve(__dirname,'..');
(async()=>{
 const factory=new LuaFactory();
 for(const name of ['bits','binary','work','pixels','runs','surface'])await factory.mountFile(`lua/native/${name}.lua`,fs.readFileSync(path.join(root,`src/native/${name}.lua`)));
 const lua=await factory.createEngine();
 try{
  await lua.doString(`
   local Surface=require('lua.native.surface')
   local cases={
    {0xfffffffe,0xffffffff,0xffffffff},
    {0xff000080,0x0000ffff,0x80007fff},
    {0x00ff007f,0xff00ffff,0x807f80ff},
    {0xff000001,0x000000ff,0x010000ff},
    {0xff000080,0x0000ff80,0xaa0055c0},
    {0xff000001,0x0000ff01,0x80007f02}
   }
   for _,case in ipairs(cases) do
    local image=Surface.new(1,1)
    image:rect(0,0,1,1,case[2])
    image:rect(0,0,1,1,case[1])
    assert(image.pixels[1]==case[3],string.format('alpha composition: %08x over %08x produced %08x instead of %08x',case[1],case[2],image.pixels[1],case[3]))
   end
   local Runs=require('lua.native.runs')
   local palette=Runs.palette(string.pack('<I4',0xffffffff):rep(256)..string.pack('<I4',0x12345678))
   local data=string.pack('<I1I1I1I1I2',255,0,1,255,0)..string.pack('<I1I1I1I1I2',0,255,1,1,256)
   local image=Surface.new(256,256)
   image:blit({w=256,h=256,runs=Runs.new(data,palette)},0,0,1)
   assert(image.pixels[256]==0xffffffff and image.pixels[255*256+1]==0x12345678,'packed sprites preserve coordinate limits, channel order and alpha')
   assert(image.pixels[255*256]==0xffffffff and image.pixels[256*256]==0,'vertical rectangles stop at their exact height')
   assert(image.pixels[1]==0,'packed sprite runs leave transparent gaps intact')
   local function decode(path)
    local file=assert(io.open(path,'rb'))
    local data=file:read('*a');file:close()
    local width,height=string.unpack('<I2I2',data,13)
    local parts,offset={},19
    while offset<=#data do
     local header=data:byte(offset);local count=header%128+1;offset=offset+1
     if header>=128 then
      parts[#parts+1]=data:sub(offset,offset+3):rep(count);offset=offset+4
     else
      parts[#parts+1]=data:sub(offset,offset+count*4-1);offset=offset+count*4
     end
    end
    return width,height,table.concat(parts)
   end
   local light=Surface.new(259,131)
   image=Surface.new(259,131)
   for y=0,130 do
    for x=0,258 do
     local index=y*259+x+1
     image.pixels[index]=(x%256)*16777216+y*65536+((x+y)%256)*256+(x*3+y)%256
     light.pixels[index]=(x+y)%3==0 and 0xffce7748 or 0
    end
   end
   local region={x=128,y=128,w=131,h=3}
   image:write('full.tga',2,121,199,231,light,.63)
   image:write('region.tga',2,121,199,231,light,.63,region)
   local full_width,_,full=decode('full.tga')
   local width,height,cropped=decode('region.tga')
   assert(width==region.w*2 and height==region.h*2,'cropped output keeps scaled edge dimensions')
   for y=0,height-1 do
    local from=((region.y*2+y)*full_width+region.x*2)*4+1
    assert(cropped:sub(y*width*4+1,(y+1)*width*4)==full:sub(from,from+width*4-1),'cropped pixels preserve source stride, tint, alpha and light coordinates')
   end
  `);
  console.log('PASS native surfaces: alpha composition, packed sprites and pixel-exact lit texture regions.');
 }finally{lua.global.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
