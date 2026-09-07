const fs=require('fs'),path=require('path');const {LuaFactory}=require('wasmoon');
(async()=>{const lua=await new LuaFactory().createEngine();const root=path.resolve(__dirname,'..');
const base='local Catalog=(function()\n'+fs.readFileSync(root+'/src/catalog.lua','utf8')+'\nend)()\nlocal World=(function()\n'+fs.readFileSync(root+'/src/world.lua','utf8')+'\nend)()\n';
lua.global.set('legacy_save',fs.readFileSync(__dirname+'/fixtures/mare2-v01.txt','utf8'));
await lua.doString(base+fs.readFileSync(__dirname+'/world.lua','utf8'));lua.global.close();})().catch(e=>{console.error(e);process.exitCode=1;});
