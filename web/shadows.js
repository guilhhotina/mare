


window.MareShadows=function(buffer,rects,perf){
 'use strict';
 var points=new Uint32Array(buffer),res=64,n=1536,field=new Uint8Array(n*n),shadowCells=new Uint8Array(576),height=[],objects=[],lamps=[],signature='',sun=false;
 var deckField=new Uint8Array(0),deckShadowCells=new Uint8Array(576);
 var tile=document.createElement('canvas');tile.width=65;tile.height=65;
 var tc=tile.getContext('2d'),image=tc.createImageData(65,65),cells=[],projections={};
 var tiles=new Map(),tileBytes=0,tileLimit=2*1024*1024;
 function ground(x,y){
  var xx=Math.max(0,Math.min(23,Math.floor(x))),yy=Math.max(0,Math.min(23,Math.floor(y)));
  var u=Math.max(0,Math.min(1,x-xx)),v=Math.max(0,Math.min(1,y-yy)),k=yy*25+xx;
  var a=height[k],b=height[k+1],c=height[k+26],d=height[k+25];
  return (u>=v?a+u*(b-a)+v*(c-b):a+u*(c-d)+v*(d-a))*16;
 }
 var projectedX,projectedY,projectedZ,decks=new Float32Array(576);
 function intersect(x,y,z,dx,dy){
  var epsilon=1e-8,enter=0,leave=z,a,b;
  if(dx!==0){
   a=-x/dx;b=(24-x)/dx;
   if(a>b){var swap=a;a=b;b=swap;}
   enter=Math.max(enter,a);leave=Math.min(leave,b);
  }else if(x<0||x>=24)return false;
  if(dy!==0){
   a=-y/dy;b=(24-y)/dy;
   if(a>b){var swapY=a;a=b;b=swapY;}
   enter=Math.max(enter,a);leave=Math.min(leave,b);
  }else if(y<0||y>=24)return false;
  if(enter>leave)return false;
  var px=x+dx*enter,py=y+dy*enter,xx=Math.floor(px),yy=Math.floor(py);
  if(dx<0&&px===xx)xx--;
  if(dy<0&&py===yy)yy--;
  xx=Math.max(0,Math.min(23,xx));yy=Math.max(0,Math.min(23,yy));
  var stepX=dx<0?-1:1,stepY=dy<0?-1:1;
  var nextX=dx===0?Infinity:(xx+(dx>0?1:0)-x)/dx;
  var nextY=dy===0?Infinity:(yy+(dy>0?1:0)-y)/dy;
  var strideX=dx===0?Infinity:stepX/dx,strideY=dy===0?Infinity:stepY/dy;
  while(xx>=0&&xx<24&&yy>=0&&yy<24){
   var finish=Math.min(leave,nextX,nextY),k=yy*25+xx;
   a=height[k]*16;b=height[k+1]*16;
   var c=height[k+26]*16,d=height[k+25]*16;
   var hit=z-decks[yy*24+xx];
   if(hit<enter-epsilon||hit>finish+epsilon)hit=Infinity;
   if(z-finish<=Math.max(a,b,c,d)+epsilon){
    var u=x-xx,v=y-yy,gx=b-a,gy=c-b,denominator=1+gx*dx+gy*dy;
    if(denominator>0){
     var t=(z-a-gx*u-gy*v)/denominator;
     if(t>=enter-epsilon&&t<=finish+epsilon&&u-v+(dx-dy)*t>=-epsilon)hit=Math.min(hit,t);
    }
    gx=c-d;gy=d-a;denominator=1+gx*dx+gy*dy;
    if(denominator>0){
     var other=(z-a-gx*u-gy*v)/denominator;
     if(other>=enter-epsilon&&other<=finish+epsilon&&u-v+(dx-dy)*other<=epsilon)hit=Math.min(hit,other);
    }
   }
   if(hit<Infinity){
    hit=Math.max(enter,hit);projectedX=x+dx*hit;projectedY=y+dy*hit;projectedZ=z-hit;return true;
   }
   if(finish>=leave)return false;
   enter=finish;
   if(nextX<=finish){xx+=stepX;nextX+=strideX;}
   if(nextY<=finish){yy+=stepY;nextY+=strideY;}
  }
  return false;
 }
 function prepare(csv,scene,phase,detail){
  var daylight=phase>.18&&phase<.79,bin=daylight?Math.floor(phase*48):-2;
  var key=csv+'|'+scene+'|'+bin+'|'+detail;if(key===signature)return;
  signature=key;height=csv.split(',').map(Number);res=detail===1?64:32;n=24*res;
  tiles.clear();tileBytes=0;perf.shadowTileBytes=0;
  if(field.length!==n*n)field=new Uint8Array(n*n);else field.fill(0);
  shadowCells.fill(0);
  deckShadowCells.fill(0);
  objects=scene?scene.split(';').map(function(row){var p=row.split(',');return{key:p[0],x:+p[1],y:+p[2],z:+p[3],powered:p[4]==='1'};}):[];
  decks.fill(-Infinity);
  objects.forEach(function(o){var bridge=/^b([56])_/.exec(o.key);if(bridge){var size=bridge[1]==='5'?1:2;for(var v=0;v<size;v++)for(var u=0;u<size;u++)decks[(o.y+v)*24+o.x+u]=o.z;}});
  if(objects.some(function(o){return /^b[56]_/.test(o.key);})){if(deckField.length!==n*n)deckField=new Uint8Array(n*n);else deckField.fill(0);}
  lamps=objects.filter(function(o){return o.key==='lamp'&&o.powered;});
  cells=new Array(576);
  lamps.forEach(function(o){
   var x=o.x+.71,y=o.y+.185;
   for(var yy=Math.max(0,Math.floor(y-1));yy<=Math.min(23,Math.floor(y+1));yy++)
    for(var xx=Math.max(0,Math.floor(x-1));xx<=Math.min(23,Math.floor(x+1));xx++){
     var k=yy*24+xx;if(!cells[k])cells[k]=[];cells[k].push([x,y,o.z+23]);
    }
  });
  perf.shadowBuilds=(perf.shadowBuilds||0)+1;perf.shadowPoints=0;perf.shadowBytes=field.byteLength+deckField.byteLength+points.byteLength;sun=daylight;
  if(!daylight)return;
  var t=((bin+.5)/48-.18)/.61,angle=-Math.PI*.92+t*Math.PI*1.1;
  var altitude=.33+Math.sin(t*Math.PI)*1.8,dx=Math.cos(angle)/(16*altitude),dy=Math.sin(angle)/(16*altitude);
  function surface(px,py,pz){
   var x=Math.min(23,Math.max(0,Math.floor(px))),y=Math.min(23,Math.max(0,Math.floor(py))),deck=decks[y*24+x];
   if(Math.abs(pz-deck)<.000001)return 1152+y*24+x;
   return(y*24+x)*2+(px-x>=py-y?0:1);
  }
  function mark(px,py,receiver){
   var target=receiver>=1152?deckField:field,marked=receiver>=1152?deckShadowCells:shadowCells;
   var xx=Math.max(0,Math.min(n-1,Math.round(px*res))),yy=Math.max(0,Math.min(n-1,Math.round(py*res)));
   var endX=Math.min(n-1,xx+2),endY=Math.min(n-1,yy+2);


   for(var row=yy;row<=endY;row++)for(var column=xx;column<=endX;column++)target[row*n+column]=1;
   marked[Math.floor(yy/res)*24+Math.floor(xx/res)]=1;
   marked[Math.floor(endY/res)*24+Math.floor(endX/res)]=1;
   marked[Math.floor(yy/res)*24+Math.floor(endX/res)]=1;
   marked[Math.floor(endY/res)*24+Math.floor(xx/res)]=1;
  }
  function cast(x,y,z){
   if(!intersect(x+dx*.00001,y+dy*.00001,z-.00001,dx,dy)){projectedX=null;return null;}
   var receiver=surface(projectedX,projectedY,projectedZ);
   mark(projectedX,projectedY,receiver);return receiver;
  }
  var minimumSpan=1/res;
  function connect(x,y,low,high,ax,ay,a,bx,by,b){
   if(ax!==null&&bx!==null&&a===b){
    var steps=Math.ceil(Math.max(Math.abs(bx-ax),Math.abs(by-ay))*res);
    if(steps>1){
     var sx=(bx-ax)/steps,sy=(by-ay)/steps;
     for(var j=1;j<steps;j++)mark(ax+sx*j,ay+sy*j,a);
    }
   }else if((ax!==null||bx!==null)&&high-low>minimumSpan){
    var middle=(low+high)*.5,receiver=cast(x,y,middle),mx=projectedX,my=projectedY;
    connect(x,y,low,middle,ax,ay,a,mx,my,receiver);
    connect(x,y,middle,high,mx,my,receiver,bx,by,b);
   }
  }
  var terrainOnly=!objects.some(function(o){return /^b[56]_/.test(o.key);});
  objects.forEach(function(o){
   var r=rects[o.key];if(!r||!r.cast)return;
   var end=r.cast[0]+r.cast[1],samples=0,previousColumn=-1,previousZ,previousX,previousY,previousSurface;
   for(var i=r.cast[0];i<end;i++){
    var p=points[i],span=p>>>28,column=p&0xfffff,low=(p>>>20)&255,x=o.x+((p&1023)-64)/64,y=o.y+(((p>>>10)&1023)-64)/64;
    var ax=null,ay,a,bx=null,by,b,sx=null,sy;
    if(terrainOnly&&span>1){
     a=cast(x,y,o.z+low);ax=projectedX;ay=projectedY;
     b=cast(x,y,o.z+low+span);bx=projectedX;by=projectedY;
     if(ax!==null&&bx!==null&&a===b){sx=(bx-ax)/span;sy=(by-ay)/span;}
    }
    for(var offset=0;offset<=span;offset++){
     var z=o.z+low+offset,receiver,px,py;
     if(offset===0&&ax!==null){px=ax;py=ay;receiver=a;}
     else if(offset===span&&bx!==null){px=bx;py=by;receiver=b;}
     else if(sx!==null){px=ax+sx*offset;py=ay+sy*offset;receiver=a;mark(px,py,receiver);}
     else{receiver=cast(x,y,z);px=projectedX;py=projectedY;}
     if(column===previousColumn&&z===previousZ+1)connect(x,y,previousZ,z,previousX,previousY,previousSurface,px,py,receiver);
     previousColumn=column;previousZ=z;previousX=px;previousY=py;previousSurface=receiver;
    }
    samples+=span+1;
   }
   perf.shadowPoints+=samples;
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
 function paint(context,wx,wy,sx,sy,zoom,corners,mask,coarse,light,receiver){
  var near=cells[wy*24+wx];if(light&&!near)return;
  if(!light&&!sun)return;
  var marked=receiver===undefined?shadowCells:deckShadowCells,target=receiver===undefined?field:deckField;
  if(!light&&!marked[wy*24+wx]&&!mask)return;
  var key=wx+','+wy+','+corners+','+!!light+','+mask+','+receiver,cached=tiles.get(key);
  if(cached){
   if(cached.c)context.drawImage(cached.c,Math.round(sx+cached.x*zoom),Math.round(sy+cached.y*zoom),cached.c.width*zoom,cached.c.height*zoom);
   return;
  }
  var a=image.data,p=projection(corners),hits=0;a.fill(0);
  var x0=65,y0=65,x1=0,y1=0;
  for(var i=0;i<p.length;i++){
   var uv=p[i];if(!uv)continue;var u=uv[0],v=uv[1],q=i*4,alpha=0;
   if(light){
    var x=wx+u,y=wy+v,z=receiver===undefined?ground(x,y):receiver;
    for(var l=0;l<near.length;l++){
     var emitter=near[l],du=x-emitter[0],dv=y-emitter[1],dz=emitter[2]-z;
     if(dz>0){
      var radius=Math.min(.9,Math.max(.2,dz/30)),d=(du*du+dv*dv)/(radius*radius);
      if(d<1&&intersect(emitter[0],emitter[1],emitter[2],du/dz,dv/dz)&&Math.abs(projectedX-x)<.001&&Math.abs(projectedY-y)<.001&&Math.abs(projectedZ-z)<.001)alpha=Math.max(alpha,d<.12?72:d<.4?46:d<.7?26:12);
     }
    }
    a[q]=255;a[q+1]=206;a[q+2]=119;
   }else{
    var hit=target[(wy*res+Math.floor(v*res))*n+wx*res+Math.floor(u*res)];
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
  inspect:function(){return{field:field,deckField:deckField,res:res,lamps:lamps,objects:objects,points:points};}};
};
