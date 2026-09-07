


window.MareShadows=function(buffer,rects,perf){
 'use strict';
 var points=new Uint32Array(buffer),res=64,n=1536,field=new Uint8Array(n*n),shadowCells=new Uint8Array(576),height=[],objects=[],lamps=[],signature='',sun=false;
 var tile=document.createElement('canvas');tile.width=65;tile.height=65;
 var tc=tile.getContext('2d'),image=tc.createImageData(65,65),cells=[],projections={};
 var tiles=new Map(),tileBytes=0,tileLimit=2*1024*1024;
 function ground(x,y){
  var xx=Math.max(0,Math.min(23,Math.floor(x))),yy=Math.max(0,Math.min(23,Math.floor(y)));
  var u=Math.max(0,Math.min(1,x-xx)),v=Math.max(0,Math.min(1,y-yy)),k=yy*25+xx;
  var a=height[k],b=height[k+1],c=height[k+26],d=height[k+25];
  return (u>=v?a+u*(b-a)+v*(c-b):a+u*(c-d)+v*(d-a))*16;
 }
 function prepare(csv,scene,phase,detail){
  var daylight=phase>.18&&phase<.79,bin=daylight?Math.floor(phase*48):-2;
  var key=csv+'|'+scene+'|'+bin+'|'+detail;if(key===signature)return;
  signature=key;height=csv.split(',').map(Number);res=detail===1?64:32;n=24*res;
  tiles.clear();tileBytes=0;perf.shadowTileBytes=0;
  if(field.length!==n*n)field=new Uint8Array(n*n);else field.fill(0);
  shadowCells.fill(0);
  objects=scene?scene.split(';').map(function(row){var p=row.split(',');return{key:p[0],x:+p[1],y:+p[2],z:+p[3],powered:p[4]==='1'};}):[];
  lamps=objects.filter(function(o){return o.key==='lamp'&&o.powered;});
  cells=new Array(576);
  lamps.forEach(function(o){
   var x=o.x+.71,y=o.y+.185;
   for(var yy=Math.max(0,Math.floor(y-1));yy<=Math.min(23,Math.floor(y+1));yy++)
    for(var xx=Math.max(0,Math.floor(x-1));xx<=Math.min(23,Math.floor(x+1));xx++){
     var k=yy*24+xx;if(!cells[k])cells[k]=[];cells[k].push([x,y,o.z+23]);
    }
  });
  perf.shadowBuilds=(perf.shadowBuilds||0)+1;perf.shadowPoints=0;perf.shadowBytes=field.byteLength+points.byteLength;sun=daylight;
  if(!daylight)return;
  var t=((bin+.5)/48-.18)/.61,angle=-Math.PI*.92+t*Math.PI*1.1;
  var altitude=.33+Math.sin(t*Math.PI)*1.8,dx=Math.cos(angle)/(16*altitude),dy=Math.sin(angle)/(16*altitude);
  function cast(x,y,z){
   var distance=Math.max(0,z-ground(x,y)),px=x+dx*distance,py=y+dy*distance;

   for(var j=0;j<4;j++){distance=Math.max(0,z-ground(px,py));px=x+dx*distance;py=y+dy*distance;}
   var xx=Math.round(px*res),yy=Math.round(py*res);
   if(xx<0||yy<0||xx>=n-2||yy>=n-2)return;


   var k=yy*n+xx;
   for(var row=0;row<3;row++){var kk=k+row*n;field[kk]=1;field[kk+1]=1;field[kk+2]=1;}
   shadowCells[Math.floor(yy/res)*24+Math.floor(xx/res)]=1;
   shadowCells[Math.floor((yy+2)/res)*24+Math.floor((xx+2)/res)]=1;
   shadowCells[Math.floor(yy/res)*24+Math.floor((xx+2)/res)]=1;
   shadowCells[Math.floor((yy+2)/res)*24+Math.floor(xx/res)]=1;
  }
  objects.forEach(function(o){
   var r=rects[o.key];if(!r||!r.cast)return;
   var end=r.cast[0]+r.cast[1];
   for(var i=r.cast[0];i<end;i++){
    var p=points[i];cast(o.x+((p&1023)-64)/64,o.y+(((p>>>10)&1023)-64)/64,o.z+(p>>>20));
   }
   perf.shadowPoints+=r.cast[1];
  });
 }
 function projection(corners){
  if(projections[corners])return projections[corners];
  var hs=[corners&1?16:0,corners&2?16:0,corners&4?16:0,corners&8?16:0],out=[];

  [[0,1,2],[0,2,3]].forEach(function(ids){
   var uv=[[0,0],[1,0],[1,1],[0,1]],p=ids.map(function(k){var u=uv[k][0],v=uv[k][1];return[32+(u-v)*32,17+(u+v)*16-hs[k],u,v];});
   var a=p[0],b=p[1],c=p[2],det=(b[0]-a[0])*(c[1]-a[1])-(c[0]-a[0])*(b[1]-a[1]);if(!det)return;
   for(var y=0;y<65;y++)for(var x=0;x<65;x++){
    var v=((x-a[0])*(c[1]-a[1])-(y-a[1])*(c[0]-a[0]))/det,w=((y-a[1])*(b[0]-a[0])-(x-a[0])*(b[1]-a[1]))/det;
    if(v<-.001||w<-.001||v+w>1.001)continue;
    var u=a[2]+v*(b[2]-a[2])+w*(c[2]-a[2]),vv=a[3]+v*(b[3]-a[3])+w*(c[3]-a[3]);
    out[y*65+x]=[Math.min(.99999,Math.max(0,u)),Math.min(.99999,Math.max(0,vv)),hs[ids[0]]+v*(hs[ids[1]]-hs[ids[0]])+w*(hs[ids[2]]-hs[ids[0]])];
   }
  });
  projections[corners]=out;return out;
 }
 function paint(context,wx,wy,sx,sy,zoom,corners,mask,coarse,light){
  var near=cells[wy*24+wx];if(light&&!near)return;
  if(!light&&!sun)return;
  if(!light&&!shadowCells[wy*24+wx]&&!mask)return;
  var key=wx+','+wy+','+corners+','+!!light+','+mask,cached=tiles.get(key);
  if(cached){
   if(cached.c)context.drawImage(cached.c,Math.round(sx+cached.x*zoom),Math.round(sy+cached.y*zoom),cached.c.width*zoom,cached.c.height*zoom);
   return;
  }
  var a=image.data,p=projection(corners),hits=0;a.fill(0);
  var x0=65,y0=65,x1=0,y1=0;
  for(var i=0;i<p.length;i++){
   var uv=p[i];if(!uv)continue;var u=uv[0],v=uv[1],q=i*4,alpha=0;
   if(light){
    var x=wx+u,y=wy+v,z=ground(x,y);
    for(var l=0;l<near.length;l++){
     var emitter=near[l],du=x-emitter[0],dv=y-emitter[1],radius=Math.min(.9,Math.max(.2,(emitter[2]-z)/30));
     var d=(du*du+dv*dv)/(radius*radius);
     if(d<1)alpha=Math.max(alpha,d<.12?72:d<.4?46:d<.7?26:12);
    }
    a[q]=255;a[q+1]=206;a[q+2]=119;
   }else{
    var hit=field[(wy*res+Math.floor(v*res))*n+wx*res+Math.floor(u*res)];
    var terrain=mask&&mask.charCodeAt(Math.floor(v*coarse)*coarse+Math.floor(u*coarse))===49;
    alpha=hit||terrain?80:0;a[q]=25;a[q+1]=39;a[q+2]=62;
   }
   a[q+3]=alpha;if(alpha){hits++;var xx=i%65,yy=Math.floor(i/65);x0=Math.min(x0,xx);x1=Math.max(x1,xx);y0=Math.min(y0,yy);y1=Math.max(y1,yy);}
  }
  if(!hits){tiles.set(key,{});return;}
  var c=document.createElement('canvas');c.width=x1-x0+1;c.height=y1-y0+1;c.getContext('2d').putImageData(image,-x0,-y0);
  var cost=c.width*c.height*4;
  while(tileBytes+cost>tileLimit&&tiles.size){var first=tiles.keys().next().value,old=tiles.get(first);if(old.c)tileBytes-=old.c.width*old.c.height*4;tiles.delete(first);}
  cached={c:c,x:x0-32,y:y0-17};tiles.set(key,cached);tileBytes+=cost;perf.shadowTileBytes=tileBytes;
  context.imageSmoothingEnabled=false;context.drawImage(c,Math.round(sx+cached.x*zoom),Math.round(sy+cached.y*zoom),c.width*zoom,c.height*zoom);
 }
 return{prepare:prepare,paint:paint,ground:ground,
  inspect:function(){return{field:field,res:res,lamps:lamps,objects:objects,points:points};}};
};
