
const fs=require('fs'),path=require('path'),vm=require('vm');
const {createCanvas,loadImage}=require('@napi-rs/canvas');const root=path.resolve(__dirname,'..');
(async()=>{
 const realm={window:{},document:{createElement:()=>createCanvas(1,1)},Uint8Array,Uint32Array,Math};
 for(const name of ['shadows','type'])vm.runInNewContext(fs.readFileSync(root+'/web/'+name+'.js','utf8'),realm);
 const canvas=createCanvas(1280,992),ctx=canvas.getContext('2d'),atlas=await loadImage(root+'/assets/atlas.png'),fonts=await loadImage(root+'/web/typefaces.png');
 const type=realm.window.MareType(canvas,{},fonts,JSON.parse(fs.readFileSync(root+'/web/typefaces.json')));
 const rects=JSON.parse(fs.readFileSync(root+'/assets/atlas.json')),bytes=fs.readFileSync(root+'/assets/shadow-shapes.bin');
 const shadow=realm.window.MareShadows(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),rects,{});
 ctx.fillStyle='#101923';ctx.fillRect(0,0,1280,992);type.draw(40,24,'SOMBRAS AO PÔR DO SOL',40,0xf5e7c6ff,1200,'display');
 type.draw(40,77,'Mesmos sprites e projeção usados no jogo.',26,0xa8b4baff,1200,'body');
 const specimens=[['b11_0','Casinha'],['tree0','Árvore'],['b26_1','Turbina eólica'],['b10_0','Porto de cargas']];
 for(let j=0;j<4;j++){
  const [key,label]=specimens[j],px=40+(j%2)*620,py=128+Math.floor(j/2)*424,ax=px+196,ay=py+180;
  ctx.fillStyle='#1e302d';ctx.fillRect(px,py,584,400);ctx.strokeStyle='#43535b';ctx.strokeRect(px+.5,py+.5,583,399);
  type.draw(px+20,py+12,label,30,0xf5e7c6ff,540,'body');
  shadow.prepare(Array(625).fill(1).join(','),key+',10,10,16,0',.72,1);
  ctx.save();ctx.beginPath();ctx.rect(px+4,py+58,576,338);ctx.clip();
  for(let sum=15;sum<=43;sum++)for(let x=7;x<=23;x++){
   const y=sum-x;if(y<7||y>20)continue;const sx=ax+(x-y)*32,sy=ay+(x+y-20)*16;
   const r=rects['grass0_'+((x*7+y*11)%6)];ctx.imageSmoothingEnabled=false;
   ctx.drawImage(atlas,r.x,r.y,r.w,r.h,sx-r.ox,sy-r.oy,r.w,r.h);
   shadow.paint(ctx,x,y,sx,sy,1,0,'',8,false);
  }
  const r=rects[key];ctx.drawImage(atlas,r.x,r.y,r.w,r.h,ax-r.ox,ay-r.oy,r.w,r.h);
  ctx.restore();
 }
 fs.writeFileSync(root+'/docs/sombras-v03.png',canvas.toBuffer('image/png'));
})().catch(e=>{console.error(e);process.exitCode=1;});
