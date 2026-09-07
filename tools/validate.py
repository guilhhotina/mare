from pathlib import Path
from PIL import Image
import json,re,hashlib
root=Path(__file__).resolve().parents[1];atlas=Image.open(root/'assets/atlas.png');atlas.load();data=json.loads((root/'assets/atlas.json').read_text())
for kind in ('grass','sand'):
 for mask in range(16):
  for variant in range(6):assert f'{kind}{mask}_{variant}' in data
for kind in ('tree','palm','rock'):
 for variant in range(3):assert kind+str(variant) in data
for name in ('build','raise','lower','level','pull','remove','undo','zoom','goals','pause','coin','people','power','happy','sun','moon','water','check','settings','save','leaf'):
 assert 'icon_'+name in data,name
assert set(atlas.getchannel('A').tobytes())<={0,255},'non-pixel alpha'
for key,r in data.items():
 assert r['x']>=0 and r['y']>=0 and r['x']+r['w']<=atlas.width and r['y']+r['h']<=atlas.height,key
 assert atlas.crop((r['x'],r['y'],r['x']+r['w'],r['y']+r['h'])).getbbox(),key
 if 'light' in r:
  assert len(r['light'])%4==0
  for i in range(0,len(r['light']),4):
   x,y,w,c=r['light'][i:i+4];assert x>=0 and y>=0 and x+w<=r['w'] and y<r['h'] and c in (0,1),key
html=(root/'dist/index.html').read_text()
for url in re.findall(r'(?:src|href)="([^"]+)"',html):
 if not url.startswith('data:'):assert (root/'dist'/url).is_file(),url
for name in ['game.lua','main.lua','atlas.json','atlas.png','logo.png','pixels.js','shadows.js','shadow-shapes.bin','type.js','typefaces.json','typefaces.png','vendor/PixelifySans.ttf','vendor/Silkscreen.ttf','vendor/wasmoon.js','vendor/glue.wasm','vendor/gly-html5.js','vendor/mare.ttf']:
 assert (root/'dist'/name).stat().st_size>0,name
assert (root/'dist/atlas.png').read_bytes()==(root/'assets/atlas.png').read_bytes()
assert (root/'dist/game.lua').read_text().isascii(),'Lua source must remain ASCII'
assert "'MARE2'" in (root/'dist/game.lua').read_text(),'save schema localization regression'
assert len(json.loads((root/'assets/catalog.json').read_text()))==40
shape_bytes=(root/'assets/shadow-shapes.bin').stat().st_size
assert shape_bytes%4==0
for id in range(5,41):
 for rot in range(4):
  off,count=data[f'b{id}_{rot}']['cast'];assert count>0 and (off+count)*4<=shape_bytes
fonts=Image.open(root/'web/typefaces.png');assert set(fonts.getchannel('A').tobytes())<={0,255}
for key,face in json.loads((root/'web/typefaces.json').read_text()).items():
 for ch in 'áéíóúãõâêôçÁÉÇ':assert ch in face,(key,ch)
 for ch,g in face.items():assert g[0]+g[2]<=fonts.width and g[1]+g[3]<=fonts.height
assert (root/'dist/shadow-shapes.bin').read_bytes()==(root/'assets/shadow-shapes.bin').read_bytes()
assert (root/'dist/typefaces.png').read_bytes()==(root/'web/typefaces.png').read_bytes()

report={'sprites':len(data),'atlas_pixels':[atlas.width,atlas.height],'atlas_rgba_mib':atlas.width*atlas.height*4/(1024*1024),'binary_alpha':True,'distribution_bytes':sum(p.stat().st_size for p in (root/'dist').rglob('*') if p.is_file()),'files':{str(p.relative_to(root/'dist')):hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'dist').rglob('*') if p.is_file()}}
(root/'docs/assets-validation.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS',len(data),'sprites, binary alpha, atlas bounds, local resources, distribution integrity.')
