from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
root=Path(__file__).resolve().parents[1]
atlas=Image.open(root/'assets/atlas.png');meta=json.loads((root/'assets/atlas.json').read_text())
keys=['palm0','palm1','palm2','b11_0','b12_0','b13_0','b35_0','b35_1','b35_2','b35_3']
labels=['Palmeira 1','Palmeira 2','Palmeira 3','Casinha','Casa com jardim','Vila de sobrados','Parquinho / 0','Parquinho / 90','Parquinho / 180','Parquinho / 270']
im=Image.new('RGB',(1500,620),'#152635');d=ImageDraw.Draw(im);font=ImageFont.truetype(str(root/'web/vendor/PixelifySans.ttf'),24)
for i,(key,label) in enumerate(zip(keys,labels)):
 x=(i%5)*300;y=(i//5)*310;r=meta[key];tile=atlas.crop((r['x'],r['y'],r['x']+r['w'],r['y']+r['h']))
 scale=max(1,min(4,276//tile.width,230//tile.height));tile=tile.resize((tile.width*scale,tile.height*scale),Image.Resampling.NEAREST)
 im.paste(tile,(x+(300-tile.width)//2,y+20+(230-tile.height)//2),tile)
 d.text((x+16,y+264),label,fill='#f5e7c6',font=font)
im.save(root/'docs/arte-v04.png')
