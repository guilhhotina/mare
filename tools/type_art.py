
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json, math
ROOT=Path(__file__).resolve().parents[1]
def build():
    chars=''.join(chr(n) for n in range(32,127))+'ÁÀÂÃÄÉÊÍÓÔÕÖÚÜÇáàâãäéêíóôõöúüçß…–—×'
    faces={'body':('PixelifySans.ttf',[11,12,13,14,15,16,17,18,19,20,24]),'display':('Silkscreen.ttf',[8,16,24,32,40,48])}
    glyphs=[];data={};x=y=1;row=0
    for face,(name,sizes) in faces.items():
        for size in sizes:
            font=ImageFont.truetype(str(ROOT/'web/vendor'/name),size);out={};data[face+str(size)]=out
            for ch in chars:
                advance=max(2,round(font.getlength(ch)));im=Image.new('RGBA',(advance+4,math.ceil(size*1.5)+6));d=ImageDraw.Draw(im)
                d.text((1,1),ch,font=font,fill='white',stroke_width=0)
                alpha=im.getchannel('A').point(lambda a:255 if a>=112 else 0);im.putalpha(alpha);bb=im.getbbox()
                if not bb:out[ch]=[0,0,0,0,advance,0,0];continue
                cut=im.crop(bb)
                if x+cut.width+1>1024:x=1;y+=row+1;row=0
                out[ch]=[x,y,cut.width,cut.height,advance,bb[0]-1,bb[1]-1]
                glyphs.append((x,y,cut));x+=cut.width+1;row=max(row,cut.height)
    atlas=Image.new('RGBA',(1024,math.ceil((y+row+1)/32)*32))
    for x,y,im in glyphs:atlas.paste(im,(x,y))
    atlas.save(ROOT/'web/typefaces.png',optimize=True)
    (ROOT/'web/typefaces.json').write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')))
    print('Pixel fonts:',atlas.size,'native glyph atlas')
if __name__=='__main__':build()
