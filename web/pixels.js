

window.MarePixels=function(canvas,atlas,rects,perf,shapes,depths){
 'use strict';
 var ctx=canvas.getContext('2d',{alpha:false}),W=1280,H=720;
 function layer(w,h){var c=document.createElement('canvas');c.width=w;c.height=h;return c;}
 var land=layer(W,H),lc=land.getContext('2d'),lights=layer(W,H),ec=lights.getContext('2d');
 var sea=layer(640,360),sc=sea.getContext('2d'),ocean=layer(512,512),oc=ocean.getContext('2d'),caching=false,view={},seaKey='',heightKey='',shoreKey='',field,heights,phase=.31;
 var waves=[],bursts=[],clock=0,skins=new Map(),skinBytes=0,skinLimit=6*1024*1024;
 var shadowField=MareShadows(shapes,rects,perf),worldCSV='';
 var actors=MareActors(canvas,atlas,rects,depths);
 [ctx,lc,ec,sc].forEach(function(c){c.imageSmoothingEnabled=false;});
 perf.waterRebuilds=0;perf.uiBytes=0;perf.renderBufferBytes=(W*H*2+640*360+512*512)*4;
 function sprite(key,x,y,s,alpha,lit){
  var r=rects[key];if(!r)throw Error('Sprite ausente: '+key);
  var c=caching?lc:ctx,xx=Math.round(x-r.ox*s),yy=Math.round(y-r.oy*s);
  c.imageSmoothingEnabled=false;c.globalAlpha=alpha;
  c.drawImage(atlas,r.x,r.y,r.w,r.h,xx,yy,r.w*s,r.h*s);c.globalAlpha=1;perf.sprites++;
  if(caching){

   ec.globalCompositeOperation='destination-out';ec.drawImage(atlas,r.x,r.y,r.w,r.h,xx,yy,r.w*s,r.h*s);ec.globalCompositeOperation='source-over';
   if(r.light&&lit!==false){
    if(key==='lamp'){

     var px=x+(.71-.185)*32*s,py=y+((.71+.185)*16-23)*s;
     ec.fillStyle='rgba(255,202,111,0.14)';ec.fillRect(Math.round(px-4*s),Math.round(py-3*s),8*s,6*s);
     ec.fillStyle='rgba(255,227,155,0.22)';ec.fillRect(Math.round(px-3*s),Math.round(py-2*s),6*s,4*s);
    }
    for(var i=0;i<r.light.length;i+=4){ec.fillStyle=r.light[i+3]?'#ffedb1':'#ffd384';ec.fillRect(xx+r.light[i]*s,yy+r.light[i+1]*s,r.light[i+2]*s,s);}
   }
  }
 }
 function distField(csv){
  heights=csv.split(',').map(Number);var n=128,a=new Float32Array(n*n);
  var signature='';
  for(var gy=0;gy<24;gy++)for(var gx=0;gx<24;gx++){var gk=gy*25+gx;signature+=Math.max(heights[gk],heights[gk+1],heights[gk+25],heights[gk+26])>0?'1':'0';}
  if(signature===shoreKey)return;shoreKey=signature;
  for(var y=0;y<n;y++)for(var x=0;x<n;x++){
   var wx=Math.floor(x/4)-4,wy=Math.floor(y/4)-4,k=wy*25+wx;
   a[y*n+x]=wx>=0&&wx<24&&wy>=0&&wy<24&&Math.max(heights[k],heights[k+1],heights[k+25],heights[k+26])>0?0:100;
  }

  for(var j=0;j<n;j++)for(var i=0;i<n;i++){
   var q=j*n+i,v=a[q];if(i)v=Math.min(v,a[q-1]+1);if(j)v=Math.min(v,a[q-n]+1);
   if(i&&j)v=Math.min(v,a[q-n-1]+1.4142);if(i<n-1&&j)v=Math.min(v,a[q-n+1]+1.4142);a[q]=v;
  }
  for(var yy=n-1;yy>=0;yy--)for(var xx=n-1;xx>=0;xx--){
   var p=yy*n+xx,b=a[p];if(xx<n-1)b=Math.min(b,a[p+1]+1);if(yy<n-1)b=Math.min(b,a[p+n]+1);
   if(xx<n-1&&yy<n-1)b=Math.min(b,a[p+n+1]+1.4142);if(xx&&yy<n-1)b=Math.min(b,a[p+n-1]+1.4142);a[p]=b;
  }
  field=a;oceanBuild();
 }
 function distance(x,y){
  x=x*4+15.5;y=y*4+15.5;if(x<0||y<0||x>=127||y>=127)return 12;
  var ix=x|0,iy=y|0,u=x-ix,v=y-iy,k=iy*128+ix;
  return ((field[k]*(1-u)+field[k+1]*u)*(1-v)+(field[k+128]*(1-u)+field[k+129]*u)*v)/4;
 }
 var caustics=new Uint8Array(64*64);
 for(var py=0;py<64;py++)for(var px=0;px<64;px++)caustics[py*64+px]=Math.sin(px*.61+py*.37)+Math.cos(px*.43-py*.51)>1.68?7:0;
 function oceanBuild(){
  var started=Date.now(),im=oc.createImageData(512,512),a=im.data;
  var palette=[[118,192,174],[84,175,171],[53,151,166],[39,132,155],[35,117,144],[35,117,144]];
  for(var y=0;y<512;y++)for(var x=0;x<512;x++){
   var wx=(x+.5)/16-4,wy=(y+.5)/16-4,d=distance(wx,wy),f=d*2.35,band=Math.min(4,Math.floor(f)),blend=Math.min(1,Math.round((f-band)*4)/4),c=palette[band],b=palette[band+1];
   var hash=((x*374761393+y*668265263)>>>0);hash=(hash^(hash>>>13))>>>0;
   var grain=d<2.2?(hash%3)-1:0,caustic=d<1.4?caustics[(y%64)*64+x%64]:0,q=(y*512+x)*4;
   for(var k=0;k<3;k++)a[q+k]=Math.round(c[k]+(b[k]-c[k])*blend+grain+caustic);
   if(d>.09&&d<.17&&(x+y*3)%17<11){a[q]=179;a[q+1]=219;a[q+2]=191;}
   a[q+3]=255;
  }
  oc.putImageData(im,0,0);perf.waterRebuilds++;perf.waterBuildMaxMs=Math.max(perf.waterBuildMaxMs||0,Date.now()-started);
 }
 function seaBuild(){
  var s=view.zoom,ox=view.ox,oy=view.oy,cx=view.cx,cy=view.cy;
  sc.setTransform(1,0,0,1,0,0);sc.fillStyle='#237590';sc.fillRect(0,0,640,360);sc.imageSmoothingEnabled=false;
  sc.setTransform(s,s/2,-s,s/2,(ox+(-cx+cy)*32*s)/2,(oy+(-8-cx-cy)*16*s)/2);
  sc.drawImage(ocean,0,0);sc.setTransform(1,0,0,1,0,0);
  waves.length=0;
  for(var j=0;j<240;j++){
   var wx=((j*73+13)%310)/10-3,wy=((j*137+39)%310)/10-3,d=distance(wx,wy);
   if(d<.25)continue;
   var sx=ox+(wx-wy-cx+cy)*32*s,sy=oy+(wx+wy-cx-cy)*16*s;
   if(sx>0&&sx<W&&sy>90&&sy<H)waves.push([sx,sy,8+(j%5)*4,j,d]);
   if(waves.length===44)break;
  }
 }
 function cacheBegin(csv,cx,cy,zoom,ox,oy,revision){
  worldCSV=csv;
  actors.begin(cx,cy,zoom,ox,oy);
  if(heightKey!==csv){distField(csv);heightKey=csv;}
  view={cx:cx,cy:cy,zoom:zoom,ox:ox,oy:oy};var k=revision+','+cx+','+cy+','+zoom+','+ox+','+oy;
  if(k!==seaKey){seaBuild();seaKey=k;}
  caching=true;perf.rebuilds++;lc.clearRect(0,0,W,H);ec.clearRect(0,0,W,H);
 }
 function shadow(mask,sx,sy,zoom,corners,res,wx,wy){
  shadowField.paint(lc,wx,wy,sx,sy,zoom,corners,mask,res,false);
 }
 function groundLight(wx,wy,sx,sy,zoom,corners){
  shadowField.paint(ec,wx,wy,sx,sy,zoom,corners,'',8,true);
 }
 function skin(kind,x,y,w,h,focus,time,motion){
  var key=kind+':'+w+':'+h,c=skins.get(key);
  if(!c){
   var sw=Math.ceil(w/2),sh=Math.ceil(h/2);c=layer(sw,sh);var g=c.getContext('2d'),r=rects['ui_'+kind],b=6;
   g.imageSmoothingEnabled=false;
   function blit(sx,sy,ww,hh,dx,dy,dw,dh){g.drawImage(atlas,r.x+sx,r.y+sy,ww,hh,dx,dy,dw,dh);}
   for(var yy=b;yy<sh-b;yy+=20)for(var xx=b;xx<sw-b;xx+=20){var tw=Math.min(20,sw-b-xx),th=Math.min(20,sh-b-yy);blit(6,6,tw,th,xx,yy,tw,th);}
   for(var xx=b;xx<sw-b;xx+=20){var tw=Math.min(20,sw-b-xx);blit(6,0,tw,b,xx,0,tw,b);blit(6,26,tw,b,xx,sh-b,tw,b);}
   for(var yy=b;yy<sh-b;yy+=20){var th=Math.min(20,sh-b-yy);blit(0,6,b,th,0,yy,b,th);blit(26,6,b,th,sw-b,yy,b,th);}
   blit(0,0,b,b,0,0,b,b);blit(26,0,b,b,sw-b,0,b,b);blit(0,26,b,b,0,sh-b,b,b);blit(26,26,b,b,sw-b,sh-b,b,b);
   var bytes=sw*sh*4;
   while(skinBytes+bytes>skinLimit&&skins.size){var first=skins.keys().next().value;var old=skins.get(first);skinBytes-=old.width*old.height*4;skins.delete(first);}
   skins.set(key,c);skinBytes+=bytes;perf.uiBytes=skinBytes;
  }
  ctx.imageSmoothingEnabled=false;ctx.drawImage(c,x,y,w,h);
  if(focus){
   ctx.fillStyle='#d6b574';ctx.fillRect(x+4,y+16,4,h-32);
  }
 }
 function tone(p){
  var stops=[[0,[86,109,161]],[.14,[91,112,164]],[.21,[191,159,170]],[.28,[255,244,218]],[.5,[255,255,244]],[.64,[255,241,207]],[.72,[255,210,161]],[.79,[153,132,174]],[.87,[88,111,163]],[1,[86,109,161]]];
  var a=stops[0],b=stops[1];for(var i=1;i<stops.length;i++)if(p<=stops[i][0]){a=stops[i-1];b=stops[i];break;}
  var t=(p-a[0])/(b[0]-a[0]);return a[1].map(function(v,i){return Math.round(v+(b[1][i]-v)*t);});
 }
 function drawWorld(p,time,motion){
  clock=time;phase=p;ctx.globalAlpha=1;ctx.imageSmoothingEnabled=false;ctx.drawImage(sea,0,0,W,H);
  var night=Math.max(0,Math.min(1,p>.73?(p-.73)/.13:p<.25?(.25-p)/.1:0));
  if(motion){
   for(var i=0;i<waves.length;i++){
    var w=waves[i],t=(Math.floor(time/220)+w[3])%12;
    ctx.fillStyle=p>.65&&p<.79&&i%3===0?'#e2bd8b':w[4]<1.5?'#95cfbf':'#4d95ab';ctx.globalAlpha=(t<6?t:12-t)/10;
    var xx=Math.round((w[0]+t*2)/2)*2,yy=Math.round(w[1]/2)*2;ctx.fillRect(xx,yy,w[2],2);
    if(t>3&&t<8)ctx.fillRect(xx+4,yy+4,Math.max(2,w[2]-8),2);
   }ctx.globalAlpha=1;
  }
  ctx.drawImage(land,0,0);
  var rgb=tone(p);ctx.globalCompositeOperation='multiply';ctx.fillStyle='rgb('+rgb.join(',')+')';ctx.fillRect(0,0,W,H);ctx.globalCompositeOperation='source-over';
  if(night>0){ctx.globalAlpha=night*.94;ctx.drawImage(lights,0,0);ctx.globalAlpha=1;}
  actors.tone(rgb);
 }
 function burst(x,y,good){bursts.push({x:x,y:y,time:clock,good:good});if(bursts.length>4)bursts.shift();}
 function effects(time,motion){
  if(!motion){bursts.length=0;return;}
  for(var i=bursts.length-1;i>=0;i--){var b=bursts[i],t=(time-b.time)/720;if(t>=1){bursts.splice(i,1);continue;}
   ctx.globalAlpha=1-t;
   for(var j=0;j<8;j++){var a=j*Math.PI/4,x=Math.round((b.x+Math.cos(a)*t*46)/2)*2,y=Math.round((b.y-18-Math.sin(a)*t*24-t*25)/2)*2;
    ctx.fillStyle=b.good?(j%2?'#fff0bd':'#a8d098'):'#e98c78';ctx.fillRect(x,y,j%3===0?6:4,4);
   }ctx.globalAlpha=1;
  }
 }
 function minimap(x,y,size){
  if(!heights)return;
  var unit=Math.max(2,Math.floor(size/48)),ox=x+size/2,oy=y;
  for(var j=0;j<24;j++)for(var i=0;i<24;i++){
   var k=j*25+i,h=Math.max(heights[k],heights[k+1],heights[k+25],heights[k+26]);if(!h)continue;
   ctx.fillStyle=h===1?'#e5c992':h===2?'#96b67a':h===3?'#6f945f':'#c6bb95';
   ctx.fillRect(ox+(i-j)*unit,oy+(i+j)*unit/2-h*2,unit*2,unit);
  }
 }
 function uiBegin(elapsed,motion){ctx.save();if(motion&&elapsed<140)ctx.translate(0,Math.floor((1-elapsed/140)*4)*2);}
 return {sprite:sprite,begin:cacheBegin,end:function(){caching=false;},world:drawWorld,shadow:shadow,skin:skin,burst:burst,effects:effects,minimap:minimap,
  scene:function(scene,phase,detail){shadowField.prepare(worldCSV,scene,phase,detail);},groundLight:groundLight,
  depth:actors.stamp,actor:actors.actor,
  bridge:function(wx,wy,sx,sy,zoom,z){
   lc.save();ec.save();actors.clipPlane(lc,ec,wx,wy,z,sx,sy,zoom);
   shadowField.paint(lc,wx,wy,sx,sy,zoom,0,'',8,false,z);shadowField.paint(ec,wx,wy,sx,sy,zoom,0,'',8,true,z);
   lc.restore();ec.restore();
  },
  uiBegin:uiBegin,uiEnd:function(){ctx.restore();},
  thumb:function(key,x,y,w,h){var r=rects[key],s=Math.min(3,w/r.w,h/r.h);s=s>=1?Math.floor(s):s;sprite(key,x+(r.ox-r.w/2)*s,y+(r.oy-r.h/2)*s,s,1);}};
};
