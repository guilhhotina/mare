from pathlib import Path
import json, shutil, re
from PIL import ImageFont
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'web';(out/'vendor').mkdir(parents=True,exist_ok=True)
from type_art import build as build_type
build_type()
rows=json.loads((ROOT/'assets/catalog.json').read_text())
font=ImageFont.truetype(str(ROOT/'web/vendor/PixelifySans.ttf'),13)
for row in rows:
 words=row[0].split();line='';rest=[]
 for word in words:
  if rest or sum(max(2,round(font.getlength(ch)))*2 for ch in (line+' '+word).strip())>184:rest.append(word)
  else:line=(line+' '+word).strip()
 row.extend([line,' '.join(rest)])
def lua(x):
 if isinstance(x,str):return ''.join(c if ord(c)<128 else ''.join('\\'+str(b).zfill(3) for b in c.encode()) for c in json.dumps(x,ensure_ascii=False))
 if isinstance(x,bool):return 'true' if x else 'false'
 if isinstance(x,dict):return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in x.items())+'}'
 if isinstance(x,list):return '{'+','.join(lua(v) for v in x)+'}'
 return str(x)
catalog='return '+lua(rows)+'\n'
(ROOT/'src/catalog.lua').write_text(catalog)
from localization import build as build_locales
locales=build_locales(ROOT,rows,lua)
activities='return '+lua(json.loads((ROOT/'art_source/activities.json').read_text()))+'\n'
(ROOT/'src/activities.lua').write_text(activities)
casters={}
caster_lua='{'+','.join('['+json.dumps(k)+']='+lua(v) for k,v in casters.items())+'}'
simulation=''.join('local '+name+'=(function()\n'+(ROOT/'src'/file).read_text()+'\nend)()\n' for name,file in [('Activities','activities.lua'),('Appearance','appearance.lua'),('InteractionAnchors','interaction_anchors.lua'),('ActorRender','actor_render.lua'),('Paths','paths.lua'),('Life','life.lua'),('TrafficPaths','traffic_paths.lua'),('Traffic','traffic.lua'),('TrafficStore','traffic_store.lua')])
bundle='local Catalog=(function()\n'+catalog+'end)()\nlocal LocaleData=(function()\n'+locales+'end)()\nlocal I18n=(function()\n'+(ROOT/'src/i18n.lua').read_text()+'\nend)()\nlocal Casters='+caster_lua+'\n'+simulation+'local World=(function()\n'+(ROOT/'src/world.lua').read_text()+'\nend)()\nlocal Lighting=(function()\n'+(ROOT/'src/lighting.lua').read_text()+'\nend)()\n'+(ROOT/'src/main.lua').read_text()
def ascii_literal(match):
 return ''.join(c if ord(c)<128 else ''.join('\\'+str(b).zfill(3) for b in c.encode()) for c in match.group(0))
bundle=re.sub(r"'(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\"",ascii_literal,bundle)
from remote_bundle import build as build_remote
web_bundle=build_remote(bundle,(ROOT/'src/platform/web.lua').read_text(),ROOT,out)
(out/'game.lua').write_text(web_bundle)

shutil.copy2(ROOT/'assets/logo.png',out/'logo.png');shutil.copy2(ROOT/'assets/atlas.png',out/'atlas.png');shutil.copy2(ROOT/'assets/atlas.json',out/'atlas.json')
shutil.copy2(ROOT/'assets/shadow-shapes.bin',out/'shadow-shapes.bin')
shutil.copy2(ROOT/'assets/depths.bin',out/'depths.bin')
print('Built',out,'Lua bytes',len(bundle),'total bytes',sum(p.stat().st_size for p in out.rglob('*') if p.is_file()))
shutil.copytree(out,ROOT/'dist',dirs_exist_ok=True,ignore=shutil.ignore_patterns('*.db','*.db-*'))
