

const fs=require('fs'),path=require('path'),assert=require('assert');
const {JSDOM}=require('jsdom');const {createCanvas,Image,GlobalFonts}=require('@napi-rs/canvas');const wasmoon=require('wasmoon');
const root=path.resolve(__dirname,'../web'),docs=path.resolve(__dirname,'../docs');
const uiCopy=JSON.parse(fs.readFileSync(path.resolve(root,'../assets/locales/ui.json'),'utf8'));
GlobalFonts.registerFromPath(root+'/vendor/PixelifySans.ttf','MarePixel');
GlobalFonts.registerFromPath(root+'/vendor/Silkscreen.ttf','MareDisplay');
const dom=new JSDOM(fs.readFileSync(root+'/index.html','utf8'),{url:'http://localhost:8787/',runScripts:'outside-only',pretendToBeVisual:true});
const win=dom.window;let time=0,rafs=[],errors=[],text_truncations=[],text_issues=[],text_calls=[],timings=[],steady=[],rebuilt=[],slowFrames=[];
const canvases=new WeakMap();
win.HTMLCanvasElement.prototype.getContext=function(){
 if(!canvases.has(this)){
  const c=createCanvas(this.width,this.height),ctx=c.getContext('2d');const old=ctx.drawImage.bind(ctx);
  ctx.drawImage=function(im,...args){return old(canvases.has(im)?canvases.get(im).canvas:im,...args);};
  const fillText=ctx.fillText.bind(ctx);ctx.fillText=function(text,x,y,...rest){
   const width=ctx.measureText(String(text)).width;text_calls.push({text,x,y,width,font:ctx.font});
   if(x<0||y<0||x+width>1280||y>720)text_issues.push({text,x,y,width});return fillText(String(text),x,y,...rest);
  };canvases.set(this,{canvas:c,ctx});
 }return canvases.get(this).ctx;
};
win.Image=class extends Image{set src(s){super.src=fs.readFileSync(path.join(root,s));}get src(){return super.src;}};
win.fetch=async function(url){const name=new URL(String(url),'http://localhost:8787/').pathname;const p=path.join(root,name);const data=fs.readFileSync(p);return{ok:true,status:200,json:async()=>JSON.parse(data),text:async()=>data.toString(),arrayBuffer:async()=>data.buffer.slice(data.byteOffset,data.byteOffset+data.byteLength)};};
win.wasmoon={...wasmoon,LuaFactory:function(){return new wasmoon.LuaFactory();}};
win.requestAnimationFrame=fn=>{rafs.push(fn);return rafs.length;};
Object.defineProperty(win.performance,'now',{value:()=>time});
win.console={...console,error:(...a)=>{errors.push(a.map(String).join(' '));console.error(...a);}};
win.eval(fs.readFileSync(root+'/vendor/gly-html5.js','utf8'));
win.eval(fs.readFileSync(root+'/shadows.js','utf8'));
win.eval(fs.readFileSync(root+'/actors.js','utf8'));
win.eval(fs.readFileSync(root+'/pixels.js','utf8'));
win.eval(fs.readFileSync(root+'/type.js','utf8'));
win.eval(fs.readFileSync(root+'/locales.js','utf8'));
win.eval(fs.readFileSync(root+'/locale.js','utf8'));
const Type=win.MareType;
win.MareType=function(canvas,perf){const t=Type.apply(null,arguments),draw=t.draw;
 t.draw=function(x,y,str,size,color,maxWidth,face){
  const width=t.width(str,size,face);if(x<0||y<0||x+Math.min(width,maxWidth||width)>1232||y+size>700)text_issues.push({text:str,x,y,width,size});
  text_calls.push({text:str,x,y,width,size});
  if(maxWidth&&width>maxWidth&&!text_truncations.some(v=>v.text===str))text_truncations.push({text:str,x,y,width,maxWidth});
  return draw.apply(null,arguments);
 };return t;
};
win.eval(fs.readFileSync(root+'/host.js','utf8'));
async function frames(n=1){for(let i=0;i<n;i++){time+=34;text_calls.length=0;const f=rafs;rafs=[];for(const fn of f){const before=win.mare&&win.mare.metrics.rebuilds;const started=process.hrtime.bigint();fn(time);const ms=Number(process.hrtime.bigint()-started)/1e6;timings.push(ms);const changed=win.mare&&before!==win.mare.metrics.rebuilds;(changed?rebuilt:steady).push(ms);if(ms>=16)slowFrames.push({ms,rebuild:changed,screen:win.mare&&win.mare.inspect('state').split(',')[0]});}await new Promise(r=>setImmediate(r));}}
async function key(code){win.document.dispatchEvent(new win.KeyboardEvent('keydown',{code,bubbles:true}));win.document.dispatchEvent(new win.KeyboardEvent('keyup',{code,bubbles:true}));await frames(5);}
function capture(name){const c=win.document.getElementById('gameCanvas');fs.writeFileSync(docs+'/'+name+'.png',canvases.get(c).canvas.toBuffer('image/png'));}
function screen(){return win.mare.inspect('state').split(',')[0];}
const state=()=>win.mare.inspect('state').split(',');
const tool=()=>win.mare.inspect('tool').split(',');
const worldData=()=>win.mare.inspect('save').split(',').slice(6,6+625+576*3).join(',');
const history=()=>Number(win.mare.inspect('metrics').split(',')[1]);
const visibleCopy=()=>text_calls.map(call=>String(call.text)).join(' ');
const message=key=>uiCopy[key][win.document.documentElement.lang.split('-')[0]];
async function focus(n){const horizontal=['tools','terrain','context'].includes(screen());while(+state()[5]!==n)await key(+state()[5]<n?(horizontal?'ArrowRight':'ArrowDown'):(horizontal?'ArrowLeft':'ArrowUp'));}
async function go(x,y){while(+state()[1]!==x)await key(+state()[1]<x?'ArrowRight':'ArrowLeft');while(+state()[2]!==y)await key(+state()[2]<y?'ArrowDown':'ArrowUp');}
async function toolsMenu(n){assert.equal(tool()[0],'inspect');await key('Enter');assert.equal(screen(),'tools');await focus(n);await key('Enter');}
async function exitTool(){await key('Escape');assert.equal(screen(),'context');await key('Escape');assert.equal(tool()[0],'inspect');}
async function category(n){assert.equal(screen(),'catalog');while(tool()[7]!=='tabs')await key('ArrowUp');while(+tool()[5]!==n)await key('ArrowRight');await key('ArrowDown');while(+tool()[6]>1)await key('ArrowLeft');}
const tasks=[];
(async()=>{
 for(let i=0;i<200&&!win.mare;i++)await new Promise(r=>setTimeout(r,10));
 assert(win.mare,'Runtime did not start: '+errors.join('\n'));await frames(2);assert.equal(screen(),'title');capture('01-inicio');
 await focus(4);await key('Enter');assert.equal(screen(),'settings');
 win.dispatchEvent(new win.Event('pagehide'));
 assert.equal(win.localStorage.getItem('mare.island.1'),null,'Leaving title settings must not save the demonstration island');
 await key('Escape');await focus(3);await key('Enter');
 win.dispatchEvent(new win.Event('pagehide'));
 assert.equal(win.localStorage.getItem('mare.island.1'),null,'Leaving title help must not create a saved game');
 await key('Escape');await focus(2);
 tasks.push('title settings and help never checkpoint the demonstration island');
 await key('Enter');assert.equal(screen(),'new');capture('02-nova-ilha');
 await focus(5);await key('Enter');assert.equal(screen(),'play');await frames(110);capture('03-ilha');
 await key('Enter');assert.equal(screen(),'tools');capture('04-ferramentas');
 await key('Enter');assert.equal(screen(),'catalog');assert.equal(tool()[7],'cards','Catalog starts on a usable item');capture('05-catalogo');
 await key('Enter');assert.equal(screen(),'play','Choosing a piece immediately enters placement');assert.equal(tool()[4],'trace','Road tracing is the default');capture('07-posicionar');
 tasks.push('catalog: direct card focus and direct placement');

 await go(11,15);const roadBefore=worldData(),roadHistory=history(),cashBefore=state()[3];
 await key('Enter');await key('ArrowRight');await key('ArrowRight');assert.notEqual(worldData(),roadBefore,'Trace changes road cells');capture('26-tracar-via');
 assert.equal(win.mare.inspect('checkpoint'),'','Uncommitted road never autosaves');
 await key('Escape');assert.equal(worldData(),roadBefore);assert.equal(state()[3],cashBefore);assert.equal(history(),roadHistory);assert.equal(tool()[3],'ready');
 await key('Enter');await key('ArrowRight');await key('ArrowRight');await key('Enter');assert.equal(history(),roadHistory+1,'One undo for the whole road');
 await exitTool();await toolsMenu(4);assert.equal(worldData(),roadBefore,'Undo restores every road cell');assert.equal(screen(),'play');tasks.push('road: three cells, cancel with exact refund, commit and undo once');

 await toolsMenu(1);await category(2);capture('22-moradias');await key('Enter');assert.equal(screen(),'play');
 const encoded=win.mare.inspect('save').split(',').map(Number);let spot;
 for(let y=7;y<18&&!spot;y++)for(let x=5;x<18&&!spot;x++){
  const h=[encoded[6+y*25+x],encoded[6+y*25+x+1],encoded[6+(y+1)*25+x],encoded[6+(y+1)*25+x+1]];
  if(!h.every(z=>z===h[0]&&z>0))continue;let empty=true;
  for(let yy=y-2;yy<=y+1;yy++)for(let xx=x-2;xx<=x+1;xx++)if(encoded[631+2*(yy*24+xx)]>0)empty=false;
  if(empty)spot=[x,y];
 }
 assert(spot,'A free flat parcel exists');await go(...spot);
 await key('Escape');assert.equal(screen(),'context');capture('06-opcoes-peca');await key('Enter');assert.equal(tool()[2],'1');assert.equal(screen(),'play');
 const houseBefore=worldData(),houseHistory=history();await key('Enter');assert.notEqual(worldData(),houseBefore,'House actually built');assert.equal(history(),houseHistory+1);capture('27-casa-construida');
 const roadSpot=[[spot[0]-1,spot[1]],[spot[0]+1,spot[1]],[spot[0],spot[1]-1],[spot[0],spot[1]+1]].find(([x,y])=>{
  const h=[encoded[6+y*25+x],encoded[6+y*25+x+1],encoded[6+(y+1)*25+x],encoded[6+(y+1)*25+x+1]];
  return h.every(z=>z===h[0]&&z>0);
 });
 assert(roadSpot,'The house has a flat adjacent cell for a partial road stroke');
 await exitTool();await toolsMenu(1);await category(1);await key('Enter');await go(...roadSpot);
 const partialRoadBefore=worldData(),partialRoadHistory=history();
 await key('Enter');await go(...spot);await go(...roadSpot);await key('Enter');
 assert(visibleCopy().includes(message('Gesto parcial: %s').split('%s')[0]),'Confirmation retains a rejected section after the cursor leaves it');
 assert(!visibleCopy().includes(message('Via pronta.')),'A partial road is not announced as fully complete');
 assert.equal(history(),partialRoadHistory+1);capture('33-via-parcial');
 await exitTool();await toolsMenu(4);assert.equal(worldData(),partialRoadBefore,'Undo restores every accepted section while keeping the obstructing house');
 await toolsMenu(1);await category(2);await key('Enter');await go(...spot);
 tasks.push('partial road: rejected occupied cell remains explicit at confirmation and one undo restores the accepted section');
 await exitTool();await toolsMenu(3);await key('Enter');assert.equal(worldData(),houseBefore,'Removal clears the house');await key('Escape');assert.equal(tool()[0],'inspect','Removal exits with one Back');
 await toolsMenu(4);assert.notEqual(worldData(),houseBefore,'Undo restores removed house');await toolsMenu(4);assert.equal(worldData(),houseBefore,'Next undo removes the construction');
 tasks.push('house: rotate, build, remove, undo removal and construction');

 await toolsMenu(2);assert.equal(screen(),'terrain');capture('08-terreno');await key('Enter');assert.equal(screen(),'play');assert.equal(tool()[0],'raise');
 await go(4,13);const groundBefore=worldData(),groundHistory=history();await key('Enter');assert.equal(tool()[3],'gesture');assert.notEqual(worldData(),groundBefore,'First OK previews a stroke');assert.equal(history(),groundHistory);await key('ArrowRight');await key('ArrowRight');await key('ArrowLeft');await key('Enter');assert.equal(tool()[3],'ready');assert.equal(history(),groundHistory+1,'Whole stroke is one undo');capture('09-relevo');
 await key('Escape');capture('28-opcoes-pincel');await key('Enter');assert.equal(tool()[1],'2');assert.equal(screen(),'play','Size change returns directly to the map');
 await exitTool();await toolsMenu(4);assert.equal(worldData(),groundBefore,'Undo restores terrain');

 await toolsMenu(2);await focus(4);await key('Enter');assert.equal(tool()[0],'pull');const pullBefore=worldData(),pullHistory=history();
 await key('Enter');await key('ArrowRight');await key('ArrowRight');assert.equal(tool()[3],'gesture');capture('29-distorcer');await key('Escape');assert.equal(worldData(),pullBefore);assert.equal(history(),pullHistory);
 await key('Enter');await key('ArrowRight');await key('ArrowRight');assert.notEqual(worldData(),pullBefore,'Pull changes the coast');await key('Enter');assert.equal(history(),pullHistory+1);await exitTool();await toolsMenu(4);assert.equal(worldData(),pullBefore);

 await toolsMenu(2);await focus(4);await key('Enter');const emptyHistory=history();await key('Enter');await key('Enter');assert.equal(history(),emptyHistory);await exitTool();
 tasks.push('terrain: continuous raise, resize, undo, pull cancel/commit and no empty undo');

 await toolsMenu(2);await focus(3);await key('Enter');await go(4,13);
 const levelBefore=worldData(),levelHistory=history(),heightBefore=win.mare.inspect('save').split(',')[6+13*25+4];
 await key('Enter');assert.equal(worldData(),levelBefore,'Copying height alone leaves the island intact');assert.equal(win.mare.inspect('level'),heightBefore);
 await key('ArrowRight');await key('ArrowRight');assert.equal(win.mare.inspect('level'),heightBefore);await key('Escape');assert.equal(worldData(),levelBefore);assert.equal(history(),levelHistory);
 await key('Enter');await go(4,7);await go(11,7);assert.equal(win.mare.inspect('level'),heightBefore,'Painting never resamples the destination');assert.notEqual(worldData(),levelBefore);capture('31-nivelar');
 await key('Enter');assert.equal(history(),levelHistory+1);await exitTool();await toolsMenu(4);assert.equal(worldData(),levelBefore,'Undo restores entire leveling stroke');

 await toolsMenu(1);await category(2);await key('Enter');await go(...spot);await key('Enter');await exitTool();
 assert.equal(win.mare.inspect('save').split(',')[631+2*(spot[1]*24+spot[0])],'11','Terrain scenario contains the selected home');
 await toolsMenu(2);await focus(1);await key('Enter');await go(...spot);
 const villageBefore=worldData(),homeVertex=6+spot[1]*25+spot[0],homeHeight=+win.mare.inspect('save').split(',')[homeVertex];
 await key('Enter');await key('ArrowRight');assert.equal(+win.mare.inspect('save').split(',')[homeVertex],homeHeight+1,'Occupied home rises with ground');capture('30-fundacoes');
 await key('Enter');await exitTool();await toolsMenu(4);assert.equal(worldData(),villageBefore);
 await toolsMenu(2);await focus(2);await key('Enter');await go(...spot);await key('Enter');assert.equal(+win.mare.inspect('save').split(',')[homeVertex],homeHeight-1,'Occupied home descends');await key('Escape');assert.equal(worldData(),villageBefore);await exitTool();
 tasks.push('level: capture once, paint, cancel and undo; occupied home rises and descends');

 await key('Escape');assert.equal(screen(),'pause');capture('10-pausa');await focus(2);await key('Enter');assert(win.localStorage.getItem('mare.island.1'));
 assert.equal(screen(),'pause');assert.equal(state()[5],'2','Saving preserves the selected action');
 assert(visibleCopy().includes(message('Ilha salva. Pode voltar quando quiser.')),'Successful save acknowledgment is visible while paused');
 await focus(3);await key('Enter');assert.equal(screen(),'goals');await frames(110);capture('11-diario');await key('Escape');assert.equal(screen(),'pause');assert.equal(state()[5],'3');await key('Escape');
 await frames(380);assert(+win.mare.inspect('save').split(',')[4]>=2,'Simulation advances day');
 await key('Escape');await focus(4);await key('Enter');assert.equal(screen(),'settings');capture('12-ajustes');await focus(5);await key('Enter');assert.equal(win.mare.inspect('lighting').split(',')[0],'2');
 await key('Escape');assert.equal(screen(),'pause');assert.equal(state()[5],'4','Settings restores parent focus');await focus(6);await key('Enter');assert.equal(screen(),'view');
 const frozen=win.mare.inspect('save');await frames(8);capture('13-manha');await key('Enter');capture('14-golden-hour');await key('Enter');capture('15-noite');
 assert.equal(win.mare.inspect('save'),frozen,'Photo mode freezes the simulation');const lightRebuilds=win.mare.metrics.rebuilds;await frames(90);assert.equal(win.mare.metrics.rebuilds,lightRebuilds,'No frame-by-frame world rebuild');
 await key('Escape');await focus(5);await key('Enter');capture('16-guia');for(let i=0;i<4;i++)await key('ArrowRight');capture('17-guia-pontes');await key('Escape');assert.equal(state()[5],'5','Help restores parent focus');await key('Escape');
 await toolsMenu(1);await category(1);for(let i=0;i<9;i++)await key('ArrowRight');capture('18-catalogo-pagina-2');await category(3);capture('23-comercio');await category(4);capture('24-servicos');await category(5);capture('25-natureza');
 await key('Escape');await key('Escape');await go(11,13);await frames(110);capture('21-postes');await key('Escape');await focus(7);await key('Enter');assert.equal(screen(),'title');
 await key('Enter');assert.equal(screen(),'load');capture('19-arquivos');await key('Escape');await focus(2);await key('Enter');assert.equal(screen(),'new');
 const savedSlot=win.localStorage.getItem('mare.island.1');await focus(5);await key('Enter');assert.equal(screen(),'confirm');capture('20-confirmacao');await key('Escape');assert.equal(win.localStorage.getItem('mare.island.1'),savedSlot,'Cancel replacement protects the existing island');
 await key('Escape');await key('Enter');await key('Enter');assert.equal(screen(),'play');
 tasks.push('pause, restored focus, diary, lighting, help, all categories, save/load and replacement cancel');
 await go(11,13);await toolsMenu(5);assert.equal(screen(),'zones');capture('28-zonas');await focus(1);await key('Enter');
 const zoneBefore=worldData();await key('Enter');assert.notEqual(worldData(),zoneBefore,'Zone gesture previews authorization');const zoneFrozen=win.mare.inspect('save');
 await frames(30);assert.equal(win.mare.inspect('save'),zoneFrozen,'Unconfirmed zone gesture suspends all autonomous activity');assert.equal(win.mare.inspect('checkpoint'),'');
 await key('Escape');assert.equal(worldData(),zoneBefore,'Cancel restores zone authorization');await key('Enter');await key('Enter');await exitTool();
 await frames(50);await key('Escape');await focus(2);await key('Enter');
 const midway=win.localStorage.getItem('mare.island.1').split(','),lifeOffset=6+625+576*3;
 assert(Number(midway[lifeOffset+9])>0,'A real worker job exists before saving');capture('29-obra-pausada');
 await focus(7);await key('Enter');await key('Enter');await key('Enter');assert.equal(screen(),'play');
 const resumed=win.mare.inspect('save').split(',');
 assert.equal(resumed[3],midway[3],'Reload does not charge construction escrow twice');
 assert.equal(resumed[lifeOffset+10],midway[lifeOffset+10],'Reload resumes the same job');
 await frames(950);const finished=win.mare.inspect('save').split(',');
 assert.equal(finished[6+625+(13*24+11)*2],'11','Worker finishes the authorized house');
 assert.equal(finished[lifeOffset+9],'0','Completed job leaves the active work queue');capture('30-bairro-construido');
 tasks.push('zones: visible preview, frozen transaction, cancel, worker arrival, midwork save/load without double payment and finished house');
 await toolsMenu(5);await focus(4);await key('Enter');
 const eraseBefore=worldData();await key('Enter');await key('Enter');
 assert.notEqual(worldData(),eraseBefore,'Zone erasure removes the authorization');
 assert.equal(win.mare.inspect('save').split(',')[6+625+(13*24+11)*2],'11','Zone erasure preserves the completed house');
 assert(visibleCopy().includes(message('Zona removida. Construcoes prontas foram mantidas.')),'Erasure confirms removal rather than promising construction');
 assert(!visibleCopy().includes(message('Zona confirmada. Acompanhe as obras.')),'Erasure never announces new construction');
 capture('32-zona-removida');await exitTool();await toolsMenu(4);
 assert.equal(worldData(),eraseBefore,'Undo restores the zone without replacing its completed house');
 tasks.push('zone erasure: clear confirmation, completed house preserved, undo restores authorization');
 await key('Escape');await focus(7);await key('Enter');
 const recoverySave=win.localStorage.getItem('mare.island.1');
 win.localStorage.setItem('mare.island.1.backup',recoverySave);win.localStorage.setItem('mare.island.1','invalid');
 await key('Enter');await key('Enter');assert.equal(screen(),'play');
 assert.equal(win.mare.inspect('save').split(',')[6+625+(13*24+11)*2],'11','Backup recovery restores the completed house');
 await key('Escape');await focus(2);
 const setItem=win.Storage.prototype.setItem;
 win.Storage.prototype.setItem=function(key,value){if(key==='mare.island.1')throw new win.DOMException('write failed','QuotaExceededError');return setItem.call(this,key,value);};
 try{
  await key('Enter');await focus(7);await key('Enter');
  assert.equal(screen(),'pause','A failed save must not exit the active island');
  assert.notEqual(win.mare.inspect('checkpoint'),'','Unsaved progress remains available after the refused exit');
  assert(visibleCopy().includes(message('Nao foi possivel salvar neste dispositivo.')),'Failed save displays its error');
  assert(!visibleCopy().includes(message('Ilha salva. Pode voltar quando quiser.')),'Failed save never displays a success acknowledgment');
  await focus(2);
 }finally{win.Storage.prototype.setItem=setItem;}
 assert.equal(win.localStorage.getItem('mare.island.1.backup'),recoverySave,'Failed recovery save preserves the valid backup');
 assert.equal(win.localStorage.getItem('mare.island.1'),'invalid','Failed commit does not report repaired primary data');
 await key('Enter');assert.equal(win.localStorage.getItem('mare.island.1'),win.mare.inspect('checkpoint'),'Retry persists the complete recovered island');capture('31-backup-recuperado');
 assert(visibleCopy().includes(message('Ilha salva. Pode voltar quando quiser.')),'Successful retry displays its acknowledgment');
 tasks.push('corrupt primary: recover completed house, preserve valid backup after failed commit, retry successfully');
 assert.equal(errors.length,0,'Runtime errors');
 const stats=a=>({mean:a.reduce((a,b)=>a+b,0)/a.length,p95:[...a].sort((a,b)=>a-b)[Math.floor(a.length*.95)],max:Math.max(...a)});
 const renderMetrics=Object.fromEntries(['waterRebuilds','waterBuildMaxMs','uiBytes','textBytes','textRasters','shadowBuilds','shadowBytes','shadowTileBytes','shadowPoints','renderBufferBytes','sprites'].map(k=>[k,win.mare.metrics[k]]));
 fs.writeFileSync(docs+'/runtime-validation.json',JSON.stringify({runtime:'Gly + Wasmoon 1.16.0 + DOM/Canvas2D harness; not a real browser',errors,text_issues,text_truncations,tasks,state:win.mare.inspect('state'),frames:win.mare.metrics.frames,rebuilds:win.mare.metrics.rebuilds,lighting:win.mare.inspect('lighting'),render_metrics:renderMetrics,frame_cost_native_harness_ms:stats(timings),steady_frames_ms:stats(steady),rebuild_frames_ms:stats(rebuilt),slow_frames:slowFrames.sort((a,b)=>b.ms-a.ms).slice(0,12)},null,2));
 console.log('PASS runtime:',tasks.join('; '));console.log('Text bounds:',text_issues.slice(0,5));console.log('Truncated copy:',text_truncations);assert.equal(text_issues.length,0,'TV safe-area text bounds');assert.equal(text_truncations.length,0,'No truncated UI copy in reviewed tasks');
 dom.window.close();
})().catch(e=>{console.error(e);capture('failure');dom.window.close();process.exitCode=1;});
