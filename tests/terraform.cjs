const fs=require('fs'),path=require('path');const {LuaFactory}=require('wasmoon');
(async()=>{const lua=await new LuaFactory().createEngine();const root=path.resolve(__dirname,'..');
const simulation=[['LocaleData', 'locales'], ['I18n', 'i18n'], ['Activities', 'activities'], ['Appearance','appearance'],['InteractionAnchors','interaction_anchors'],['Paths','paths'],['Life','life'],['TrafficPaths','traffic_paths'],['Traffic','traffic'],['TrafficStore','traffic_store']].map(([name,file])=>'local '+name+'=(function()\n'+fs.readFileSync(root+'/src/'+file+'.lua','utf8')+'\nend)()\n').join('');
const base='local Catalog=(function()\n'+fs.readFileSync(root+'/src/catalog.lua','utf8')+'\nend)()\n'+simulation+'local World=(function()\n'+fs.readFileSync(root+'/src/world.lua','utf8')+'\nend)()\n';
await lua.doString(base+fs.readFileSync(__dirname+'/terraform.lua','utf8'));lua.global.close();})().catch(e=>{console.error(e);process.exitCode=1;});
