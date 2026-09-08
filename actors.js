window.MareActors=function(canvas,atlas,rects,depths){
 'use strict';
 var ctx=canvas.getContext('2d'),data=new DataView(depths),field=new Float32Array(1280*720);
 var sources=cache(512,2*1024*1024),appearances=cache(64,64*72),colors=new Map(),colorOrder=[],colorCursor=0;
 var scratch=document.createElement('canvas'),sample=scratch.getContext('2d'),view,red=255,green=255,blue=255,toneId=0xffffff;
 var markers=new Map([[0xfa01faff,0],[0xfb01fbff,1],[0xfc01fcff,2],[0x01fafaff,3],[0x01fbfbff,4],[0x01fcfcff,5],[0xfafa01ff,6],[0xfbfb01ff,7],[0xfcfc01ff,8]]);
 var skins=[
  [0xbc8465ff,0xe4b38dff,0xf7d2aaff],[0xc7927cff,0xefc4acff,0xffe1c2ff],
  [0x9f684bff,0xca9167ff,0xe5b58aff],[0x815038ff,0xb17b53ff,0xd29a6cff],
  [0x573c31ff,0x82563fff,0xab7958ff],[0x372b29ff,0x594033ff,0x855c46ff],
  [0x9a795aff,0xbea078ff,0xdec39dff],[0xa86855ff,0xce957aff,0xedb9a0ff]
 ];
 var shirts=[
  [0x245958ff,0x337c77ff,0x74afa0ff],[0x822e3fff,0xc44853ff,0xec7b7aff],
  [0x9b652fff,0xd59a49ff,0xf1c97cff],[0x625875ff,0x9789b0ff,0xc1b4d4ff],
  [0x3f5876ff,0x647fa7ff,0x9ab1d0ff],[0x4a644aff,0x769363ff,0xa8be84ff],
  [0xada080ff,0xdfd3b1ff,0xfff0cfff],[0x38494eff,0x5c6c6aff,0x94a59cff]
 ];
 var hairs=[
  [0x2d292bff,0x493a33ff,0x72604aff],[0x533c32ff,0x79513bff,0xae7851ff],
  [0x977245ff,0xc7a365ff,0xead094ff],[0x693f33ff,0x9d5d3fff,0xce8f57ff],
  [0x697779ff,0x9ba7a1ff,0xd3d7c6ff],[0x25272bff,0x383338ff,0x5a5050ff],
  [0x46342fff,0x6a4c3cff,0xa27758ff],[0x4b3d50ff,0x755879ff,0xaa88a4ff]
 ];
 function cache(limit,bytes){return{entries:new Map(),first:null,last:null,count:0,bytes:0,limit:limit,byteLimit:bytes};}
 function touch(c,entry){
  if(c.last===entry)return;
  if(entry.previous)entry.previous.next=entry.next;else c.first=entry.next;
  if(entry.next)entry.next.previous=entry.previous;
  entry.previous=c.last;entry.next=null;c.last.next=entry;c.last=entry;
 }
 function remember(c,key,entry,bytes){
  if(bytes>c.byteLimit)throw new Error('Actor source exceeds cache budget');
  while(c.count>=c.limit||c.bytes+bytes>c.byteLimit){
   var old=c.first;c.entries.delete(old.key);c.first=old.next;
   if(c.first)c.first.previous=null;else c.last=null;
   c.count--;c.bytes-=old.bytes;
  }
  entry.key=key;entry.bytes=bytes;entry.previous=c.last;entry.next=null;
  if(c.last)c.last.next=entry;else c.first=entry;
  c.last=entry;c.entries.set(key,entry);c.count++;c.bytes+=bytes;return entry;
 }
 function tinted(color){
  var r=Math.round((color>>>24)*red/255),g=Math.round(((color>>>16)&255)*green/255),b=Math.round(((color>>>8)&255)*blue/255),a=color&255;
  return a===255?'rgb('+r+','+g+','+b+')':'rgba('+r+','+g+','+b+','+(a/255)+')';
 }
 function palette(appearance){
  if(appearance===undefined||appearance===null)return null;
  var entry=appearances.entries.get(appearance);
  if(entry)touch(appearances,entry);
  else{
   var skin=skins[appearance%8],shirt=shirts[Math.floor(appearance/8)%8],hair=hairs[Math.floor(appearance/64)%8];
   entry=remember(appearances,appearance,{base:[skin[0],skin[1],skin[2],shirt[0],shirt[1],shirt[2],hair[0],hair[1],hair[2]],colors:[],tone:-1},72);
  }
  if(entry.tone!==toneId){for(var i=0;i<9;i++)entry.colors[i]=tinted(entry.base[i]);entry.tone=toneId;}
  return entry.colors;
 }
 function color(original){
  var tint=colors.get(original);if(tint!==undefined)return tint;
  tint=tinted(original);
  if(colorOrder.length===512)colors.delete(colorOrder[colorCursor]);
  colorOrder[colorCursor]=original;colors.set(original,tint);colorCursor=(colorCursor+1)%512;return tint;
 }
 function begin(cx,cy,zoom,ox,oy){view={cx:cx,cy:cy,zoom:zoom,ox:ox,oy:oy};field.fill(-Infinity);}
 function stamp(key,x,y,scale,wx,wy,z){
  var r=rects[key];if(!r.depth)return;
  var x0=Math.floor(x-r.ox*scale+.5),y0=Math.floor(y-r.oy*scale+.5),w=Math.floor(r.w*scale+.5),h=Math.floor(r.h*scale+.5),inverse=1/scale,base=wx+wy+z/16;
  for(var yy=Math.max(0,-y0);yy<Math.min(h,720-y0);yy++){
   var sourceRow=Math.min(r.h-1,Math.floor((yy+.5)*inverse))*r.w,row=(y0+yy)*1280+x0;
   for(var xx=Math.max(0,-x0);xx<Math.min(w,1280-x0);xx++){
    var index=sourceRow+Math.min(r.w-1,Math.floor((xx+.5)*inverse)),value=data.getInt16(r.depth[0]+index*2,true);
    if(value!==-32768)field[row+xx]=base+value/256;
   }
  }
 }
 function source(key,r){
  key=r.y*atlas.width+r.x;
  var cached=sources.entries.get(key);if(cached){touch(sources,cached);return cached;}
  if(scratch.width!==r.w)scratch.width=r.w;
  if(scratch.height!==r.h)scratch.height=r.h;
  sample.clearRect(0,0,r.w,r.h);sample.drawImage(atlas,r.x,r.y,r.w,r.h,0,0,r.w,r.h);
  var pixels=sample.getImageData(0,0,r.w,r.h).data,runs=[];
  for(var y=0;y<r.h;y++)for(var x=0;x<r.w;){
   var at=(y*r.w+x)*4,rgba=(pixels[at]*16777216+pixels[at+1]*65536+pixels[at+2]*256+pixels[at+3])>>>0,end=x+1;
   while(end<r.w){var k=(y*r.w+end)*4;if(pixels[k]!==pixels[at]||pixels[k+1]!==pixels[at+1]||pixels[k+2]!==pixels[at+2]||pixels[k+3]!==pixels[at+3])break;end++;}
   if(pixels[at+3])runs.push(x,y,end-x,rgba);x=end;
  }
  cached={meta:r,runs:new Uint32Array(runs)};return remember(sources,key,cached,cached.runs.byteLength);
 }
 function tone(rgb){
  if(red!==rgb[0]||green!==rgb[1]||blue!==rgb[2]){
   red=rgb[0];green=rgb[1];blue=rgb[2];toneId=(red<<16)|(green<<8)|blue;colors.clear();colorOrder.length=0;colorCursor=0;
  }
 }
 function drawLayer(key,wx,wy,z,appearance){
  var r=rects[key];if(!r)throw new Error('Unknown actor sprite: '+key);
  var zoom=view.zoom;
  var sx=Math.floor(view.ox+(wx-wy-view.cx+view.cy)*32*zoom-r.ox*zoom),sy=Math.floor(view.oy+(wx+wy-view.cx-view.cy)*16*zoom-z*zoom-r.oy*zoom);
  if(sx>=1280||sy>=720||sx+r.w*zoom<=0||sy+r.h*zoom<=0)return;
  var runs=source(key,r).runs,base=wx+wy+z/16,inverse=1/zoom,lastColor;
  for(var i=0;i<runs.length;i+=4){
   var original=runs[i+3],marker=appearance&&markers.get(original),tint=appearance&&marker!==undefined?appearance[marker]:color(original);
   if(tint!==lastColor){ctx.fillStyle=tint;lastColor=tint;}
   var row=sy+runs[i+1]*zoom,left=Math.max(0,sx+runs[i]*zoom),right=Math.min(1280,sx+(runs[i]+runs[i+2])*zoom),value=base+(r.oy-runs[i+1])/16;
   var sourceRow=r.depth?r.depth[0]+runs[i+1]*r.w*2:-1;
   for(var yy=Math.max(0,row);yy<Math.min(720,row+zoom);yy++){
    var start=-1,offset=yy*1280;
    for(var xx=left;xx<right;xx++){
     if(sourceRow>=0)value=base+data.getInt16(sourceRow+Math.floor((xx-sx)*inverse)*2,true)/256;
     if(field[offset+xx]<=value+.08){if(start<0)start=xx;}
     else if(start>=0){ctx.fillRect(start,yy,xx-start,1);start=-1;}
    }
    if(start>=0)ctx.fillRect(start,yy,right-start,1);
   }
  }
 }
 function actor(key,wx,wy,z,appearance,accessoryKey){
  var ramp=palette(appearance);drawLayer(key,wx,wy,z,ramp);
  if(accessoryKey&&rects[accessoryKey])drawLayer(accessoryKey,wx,wy,z,ramp);
 }
 function clipPlane(first,second,wx,wy,z,sx,sy,zoom){
  var x0=Math.max(0,Math.floor(sx-32*zoom+.5)),y0=Math.max(0,Math.floor(sy-17*zoom+.5)),x1=Math.min(1280,Math.floor(sx+33*zoom+.5)),y1=Math.min(720,Math.floor(sy+48*zoom+.5));
  var base=wx+wy+z/16,inverse=1/(16*zoom);
  first.beginPath();second.beginPath();
  for(var y=y0;y<y1;y++){
   var start=-1,row=y*1280,value=base+(y-sy)*inverse+.08;
   for(var x=x0;x<x1;x++){
    if(field[row+x]<=value){if(start<0)start=x;}
    else if(start>=0){first.rect(start,y,x-start,1);second.rect(start,y,x-start,1);start=-1;}
   }
   if(start>=0){first.rect(start,y,x1-start,1);second.rect(start,y,x1-start,1);}
  }
  first.clip();second.clip();
 }
 return{begin:begin,stamp:stamp,actor:actor,tone:tone,clipPlane:clipPlane};
};
