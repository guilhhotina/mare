

(function () {
'use strict';
var canvas=document.getElementById('gameCanvas'),ctx=canvas.getContext('2d',{alpha:false});
var pixels,type,atlas,rects,inspector;
var input_queue=new Array(32),input_read=0,input_write=0,pressed=Object.create(null);
var perf={frames:0,rebuilds:0,sprites:0,total:0,max:0,samples:[]};
var audio_ctx=null, opts='',load_error=false,active=true,display_ready=false;
function stored(key){try{return localStorage.getItem(key)||'';}catch(e){return '';}}
function write(key,text){try{localStorage.setItem(key,text);return localStorage.getItem(key)===text;}catch(e){return false;}}
function unlock_audio(){
 if(!audio_ctx){var A=window.AudioContext||window.webkitAudioContext;if(A)try{audio_ctx=new A();}catch(e){}}
 if(audio_ctx&&audio_ctx.state==='suspended')audio_ctx.resume().catch(function(){});
}
function sound(type){
 if(!audio_ctx||audio_ctx.state!=='running')return;
 try{var o=audio_ctx.createOscillator(),g=audio_ctx.createGain(),t=audio_ctx.currentTime,duration=type===0?.045:.12;
 o.type='sine';o.frequency.setValueAtTime(type===2?180:type===1?620:520,t);o.frequency.exponentialRampToValueAtTime(type===2?120:type===1?820:390,t+duration);
 g.gain.setValueAtTime(type===0?.013:.03,t);g.gain.exponentialRampToValueAtTime(0.0001,t+duration);o.connect(g);g.connect(audio_ctx.destination);o.start();o.stop(t+duration+.01);}catch(e){}
}
var adapter={
 prepare:async function(hv){
  Object.assign(hv.backend,{
   mare_take_key:function(){if(input_read===input_write)return false;var key=input_queue[input_read%32];input_read++;return key;},mare_cache_begin:function(){return pixels.begin.apply(null,arguments);},mare_cache_end:function(){pixels.end();},mare_world:function(){pixels.world.apply(null,arguments);},mare_sprite:function(){pixels.sprite.apply(null,arguments);},
   mare_shadow:function(){pixels.shadow.apply(null,arguments);},mare_skin:function(){pixels.skin.apply(null,arguments);},mare_burst:function(){pixels.burst.apply(null,arguments);},mare_effects:function(){pixels.effects.apply(null,arguments);},mare_minimap:function(){pixels.minimap.apply(null,arguments);},
   mare_ui_begin:function(){pixels.uiBegin.apply(null,arguments);},mare_ui_end:function(){pixels.uiEnd();},
   mare_text:function(){return type.draw.apply(null,arguments);},mare_text_width:function(){return type.width.apply(null,arguments);},
   mare_scene:function(){pixels.scene.apply(null,arguments);},mare_ground_light:function(){pixels.groundLight.apply(null,arguments);},
   mare_thumb:function(){pixels.thumb.apply(null,arguments);},
   mare_save:function(slot,text){
    if(slot<1||slot>3||typeof text!=='string'||text.length>20000)return false;
    var key='mare.island.'+slot,old=stored(key);if(old)write(key+'.backup',old);return write(key,text);
   },
   mare_load:function(slot){return stored('mare.island.'+slot);},mare_backup:function(slot){return stored('mare.island.'+slot+'.backup');},mare_sound:sound,
   mare_options:function(sound_on,motion,detail,zoom,light){opts=(sound_on?'sound':'silent')+','+(motion?'motion':'still')+','+detail+','+zoom+','+light;write('mare.options',opts);},
   mare_get_options:function(){return stored('mare.options');},mare_register:function(fn){inspector=fn;}
  });
 },install:async function(){},startup:async function(hv){
  hv.frontbus.on('keyboard',function(key,value){
   if(value&&!pressed[key]){if(input_write-input_read>=32)input_read++;input_queue[input_write%32]=key;input_write++;}
   pressed[key]=!!value;
  });
 },destroy:async function(){}
};

var clock={prepare:async function(){},install:async function(){},startup:async function(hv){
 hv.frontend.native_callback_init();var previous=performance.now(),last_draw=previous;
 document.addEventListener('visibilitychange',function(){previous=performance.now();});
 function tick(now){
  if(!hv.running)return;
  if(now-last_draw>=1000/30-1&&!document.hidden&&active){
   var started=performance.now();hv.frontend.native_callback_loop(Math.min(100,now-previous));hv.frontend.native_callback_draw();previous=now;last_draw=now;
   if(!display_ready&&inspector){display_ready=true;document.getElementById('loading').classList.add('hidden');canvas.focus();}
   var took=performance.now()-started;perf.frames++;perf.total+=took;perf.max=Math.max(perf.max,took);if(perf.samples.length<2000)perf.samples.push(took);
  }else if(document.hidden||!active){previous=now;last_draw=now;}
  window.requestAnimationFrame(tick);
 }
 window.requestAnimationFrame(tick);
},destroy:async function(){}};
function fail(e){load_error=true;document.getElementById('progress').textContent='Nao foi possivel abrir a ilha. Recarregue para tentar novamente.';document.getElementById('loading').classList.remove('hidden');var b=document.getElementById('retry');b.style.display='block';b.focus();console.error(e);}
async function start(){
 try{
  var results=await Promise.all([fetch('atlas.json').then(function(r){if(!r.ok)throw Error('atlas');return r.json();}),new Promise(function(resolve,reject){atlas=new Image();atlas.onload=resolve;atlas.onerror=reject;atlas.src='atlas.png';}),document.fonts?Promise.all([document.fonts.load('32px MarePixel'),document.fonts.load('32px MareDisplay')]):Promise.resolve(),fetch('shadow-shapes.bin').then(function(r){if(!r.ok)throw Error('shadow shapes');return r.arrayBuffer();}),Promise.all([fetch('typefaces.json').then(function(r){if(!r.ok)throw Error('typefaces');return r.json();}),new Promise(function(resolve,reject){var im=new Image();im.onload=function(){resolve(im);};im.onerror=reject;im.src='typefaces.png';})])]);rects=results[0];pixels=MarePixels(canvas,atlas,rects,perf,results[3]);type=MareType(canvas,perf,results[4][1],results[4][0]);
  var LocalFactory=function(){return new wasmoon.LuaFactory(new URL('vendor/glue.wasm',location.href).href);};
  var keymap=[['Enter','a'],['NumpadEnter','a'],['ArrowUp','up'],['ArrowDown','down'],['ArrowLeft','left'],['ArrowRight','right'],['Escape','menu'],['Backspace','menu'],['ShiftLeft','menu'],[461,'menu'],[10009,'menu'],[13,'a'],[38,'up'],[40,'down'],[37,'left'],[39,'right']];
  document.addEventListener('keydown',function(e){if(keymap.some(function(p){return p[0]===e.code||p[0]===e.keyCode;})){e.preventDefault();unlock_audio();}});
  window.gly=await CoreNativeHtml5().setElementRoot('main').setElementCanvas('#gameCanvas').addLibrary('mare',adapter).addLibrary('wasmoon',LocalFactory,wasmoon.LuaMultiReturn).addLibrary('keyboard',keymap).addLibrary(navigator.getGamepads?'gamepad':'none').addLibrary('mare-clock',clock).setEngine('main.lua').setGame('game.lua').build();
  ctx.imageSmoothingEnabled=false;ctx.lineWidth=2;
  window.mare={metrics:perf,inspect:function(command,arg){return inspector&&inspector(command,arg);},version:'0.4.0'};

  window.addEventListener('focus',function(){active=true;});
  window.addEventListener('blur',function(){active=false;['a','up','down','left','right','menu'].forEach(function(k){window.gly.frontend.native_callback_keyboard(k,0);});});
  function checkpoint(){if(!inspector)return;var data=inspector('checkpoint');if(data)write('mare.island.'+inspector('slot'),data);}
  window.addEventListener('pagehide',checkpoint);document.addEventListener('visibilitychange',function(){if(document.hidden)checkpoint();});

 }catch(e){fail(e);}
}
window.addEventListener('error',function(e){if(!load_error)fail(e.error||e.message);});
start();
})();
