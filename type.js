

window.MareType=function(canvas,perf,atlas,metrics){
 'use strict';
 var ctx=canvas.getContext('2d'),cache=new Map(),bytes=0,limit=4*1024*1024;
 function spec(size,face){
  face=face==='display'?'display':'body';
  var native=face==='display'?Math.max(8,Math.round(size/16)*8):Math.max(11,Math.round(size/2));
  return face+native;
 }
 function width(value,size,face){
  var font=metrics[spec(size,face)],str=String(value),w=0;
  for(var i=0;i<str.length;i++){var glyph=font[str.charAt(i)]||font['?'];w+=glyph[4];}
  return w*2;
 }
 function draw(x,y,value,size,color,maxWidth,face){
  var str=String(value),fontKey=spec(size,face),font=metrics[fontKey],key=fontKey+'|'+color+'|'+(maxWidth||0)+'|'+str,entry=cache.get(key);
  if(!str)return 0;
  if(!entry){
   if(maxWidth&&width(str,size,face)>maxWidth){
    while(str.length&&width(str+'…',size,face)>maxWidth)str=str.slice(0,-1);
    str+='…';
   }
   var w=width(str,size,face)/2,top=100,bottom=0;
   for(var j=0;j<str.length;j++){var b=font[str.charAt(j)]||font['?'];if(b[2]){top=Math.min(top,b[6]);bottom=Math.max(bottom,b[6]+b[3]);}}
   if(!bottom)return w*2;
   var c=document.createElement('canvas');c.width=Math.max(1,w+4);c.height=bottom-top;
   var g=c.getContext('2d');g.imageSmoothingEnabled=false;var cursor=1;
   for(var i=0;i<str.length;i++){
    var glyph=font[str.charAt(i)]||font['?'];
    if(glyph[2])g.drawImage(atlas,glyph[0],glyph[1],glyph[2],glyph[3],cursor+glyph[5],glyph[6]-top,glyph[2],glyph[3]);
    cursor+=glyph[4];
   }
   var co=Number(color)>>>0;
   g.globalCompositeOperation='source-in';g.fillStyle='rgb('+(co>>>24)+','+((co>>>16)&255)+','+((co>>>8)&255)+')';g.fillRect(0,0,c.width,c.height);
   entry={canvas:c,width:w*2,top:top*2};var cost=c.width*c.height*4;
   while(bytes+cost>limit&&cache.size){var first=cache.keys().next().value,old=cache.get(first).canvas;bytes-=old.width*old.height*4;cache.delete(first);}
   cache.set(key,entry);bytes+=cost;perf.textBytes=bytes;perf.textRasters=(perf.textRasters||0)+1;
  }
  ctx.imageSmoothingEnabled=false;ctx.drawImage(entry.canvas,Math.round(x/2)*2,Math.round(y/2)*2+entry.top,entry.canvas.width*2,entry.canvas.height*2);
  return entry.width;
 }
 return{draw:draw,width:width};
};
