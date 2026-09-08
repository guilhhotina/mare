
from PIL import Image, ImageDraw
import random

INK='#182536'; DEEP='#101923'; CREAM='#f5e7c6'; GOLD='#d6b574'
TEAL='#91b1ad'; CORAL='#db8e78'; WOOD='#75604c'

def generate(add):

    for kind in ('panel','button','focus','inset','tab','danger'):
        im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
        fill={'panel':'#182536','button':'#202f40','focus':'#33404a','inset':'#131f2d','tab':'#182536','danger':'#412f36'}[kind]
        edge=GOLD if kind=='focus' else '#4b5360' if kind=='panel' else '#344354'


        d.rectangle((1,1,30,30),fill=DEEP)
        d.rectangle((2,2,29,29),fill=edge)
        d.rectangle((3,3,28,28),fill=fill)
        for x,y in ((0,0),(30,0),(0,30),(30,30)):
            d.rectangle((x,y,x+1,y+1),fill=(0,0,0,0))
        if kind in ('panel','focus'):
            for x,y,sx,sy in ((2,2,1,1),(29,2,-1,1),(2,29,1,-1),(29,29,-1,-1)):
                d.line((x,y,x+sx*3,y),fill=GOLD)
                d.line((x,y,x,y+sy*3),fill=GOLD)
                d.point((x,y),fill=CREAM)
        add('ui_'+kind,im,(0,0))

    def icon(name,fn):
        im=Image.new('RGBA',(24,24))
        fn(ImageDraw.Draw(im))
        add('icon_'+name,im,(0,0))

    def house(d):
        d.rectangle((16,3,18,8),fill=WOOD)
        d.rectangle((16,3,18,4),fill=GOLD)
        d.rectangle((5,10,19,20),fill=WOOD)
        d.rectangle((5,10,18,19),fill=CREAM)
        d.polygon([(2,10),(11,2),(21,10),(21,12),(2,12)],fill='#a95146')
        d.polygon([(2,10),(11,2),(20,10)],fill=CORAL)
        d.line((4,9,11,3,17,8),fill='#ffc798')
        d.rectangle((8,14,11,19),fill='#527c83')
        d.rectangle((8,14,10,18),fill=TEAL)
        d.rectangle((14,13,16,15),fill=GOLD)
        d.line((14,13,16,13),fill=CREAM)
        d.rectangle((4,20,20,21),fill=GOLD)
    icon('build',house)

    def terrain(d):
        d.polygon([(2,13),(6,10),(17,10),(22,14),(22,17),(18,21),(6,21),(1,17),(1,15)],fill='#527c83')
        d.line((3,18,7,20,16,20,20,17),fill=TEAL)
        d.polygon([(3,12),(6,8),(10,8),(13,5),(17,6),(20,11),(20,15),(16,18),(7,18),(3,15)],fill=GOLD)
        d.polygon([(4,11),(7,8),(10,8),(13,5),(17,7),(19,11),(18,14),(15,16),(7,16),(4,14)],fill='#6f956b')
        d.polygon([(5,11),(8,9),(11,9),(13,6),(16,8),(18,11),(17,13),(14,15),(8,15),(5,13)],fill='#8fba78')
        d.line((7,11,10,10,12,8,14,8,16,10,16,12,13,14,9,14),fill='#d1d88c')
        d.polygon([(10,11),(12,9),(14,10),(14,12),(12,13),(10,12)],fill='#6f956b')
        d.line((11,11,12,10,13,10),fill='#d1d88c')
        d.line((3,20,5,21),fill=CREAM)
    icon('terrain',terrain)

    def parcel_map(d):
        d.polygon([(3,3),(19,3),(22,6),(22,21),(3,21)],fill=DEEP)
        d.polygon([(2,2),(18,2),(21,5),(21,20),(2,20)],fill=GOLD)
        d.polygon([(3,3),(17,3),(20,6),(20,19),(3,19)],fill=CREAM)
        d.rectangle((4,4,18,18),fill='#527c83')
        d.rectangle((10,4,12,18),fill=CREAM)
        d.rectangle((10,10,18,12),fill=CREAM)
        d.rectangle((4,11,9,12),fill=GOLD)
        d.polygon([(5,5),(8,5),(8,9),(5,9)],fill=CORAL)
        d.line((5,5,7,5),fill=CREAM)
        d.rectangle((14,5,17,8),fill=GOLD)
        d.line((14,5,16,5),fill=CREAM)
        d.polygon([(5,14),(8,14),(8,17),(5,17)],fill='#8fba78')
        d.polygon([(14,14),(17,14),(17,17),(16,17),(16,16),(14,16)],fill=CORAL)
        d.polygon([(17,3),(20,6),(17,6)],fill=TEAL)
    icon('zones',parcel_map)

    def terrain_base(d):
        d.polygon([(3,16),(10,12),(20,15),(20,19),(12,22),(3,19)],fill=WOOD)
        d.polygon([(3,15),(10,12),(20,15),(12,19),(3,17)],fill='#8fba78')
        d.line((4,16,12,18,18,15),fill='#d1d88c')
        d.line((4,19,12,21,19,18),fill=GOLD)

    def raise_land(d):
        terrain_base(d)
        d.polygon([(11,3),(6,8),(9,8),(9,14),(13,14),(13,8),(16,8)],fill=WOOD)
        d.polygon([(11,2),(6,7),(9,7),(9,13),(13,13),(13,7),(16,7)],fill=CREAM)
        d.line((12,8,12,12),fill=GOLD)
    icon('raise',raise_land)

    def lower_land(d):
        terrain_base(d)
        d.polygon([(9,3),(13,3),(13,9),(16,9),(11,14),(6,9),(9,9)],fill=WOOD)
        d.polygon([(9,2),(13,2),(13,8),(16,8),(11,13),(6,8),(9,8)],fill=CREAM)
        d.line((12,3,12,7),fill=GOLD)
    icon('lower',lower_land)

    def level_land(d):
        terrain_base(d)
        d.rectangle((3,9,20,11),fill=GOLD)
        d.line((3,9,20,9),fill=CREAM)
        d.polygon([(5,2),(7,2),(7,4),(9,4),(6,7),(3,4),(5,4)],fill=CREAM)
        d.polygon([(16,12),(19,15),(17,15),(17,17),(15,17),(15,15),(13,15)],fill=CREAM)
    icon('level',level_land)

    def pull_land(d):
        terrain_base(d)
        d.polygon([(14,3),(21,8),(14,13),(14,10),(6,10),(6,6),(14,6)],fill=WOOD)
        d.polygon([(14,2),(21,7),(14,12),(14,9),(6,9),(6,5),(14,5)],fill=CREAM)
        d.rectangle((3,5,5,9),fill=GOLD)
        d.line((7,8,13,8),fill=GOLD)
    icon('pull',pull_land)

    def remove(d):
        d.rectangle((9,2,14,4),fill=GOLD)
        d.rectangle((3,6,20,8),fill=WOOD)
        d.rectangle((3,5,20,7),fill=CREAM)
        d.polygon([(5,9),(18,9),(18,17),(17,17),(17,21),(6,21),(6,17),(5,17)],fill='#a95146')
        d.polygon([(5,9),(17,9),(17,16),(16,16),(16,19),(7,19),(7,16),(5,16)],fill=CORAL)
        d.rectangle((8,11,9,17),fill=CREAM)
        d.rectangle((13,11,14,17),fill=CREAM)
    icon('remove',remove)

    def undo(d):
        d.polygon([(2,9),(8,3),(8,7),(15,7),(19,10),(21,13),(21,17),(18,21),(11,21),(11,17),(16,17),(17,15),(17,13),(15,11),(8,11),(8,15)],fill=DEEP)
        d.polygon([(2,8),(8,2),(8,6),(15,6),(19,9),(21,12),(21,16),(18,20),(11,20),(11,16),(16,16),(17,14),(17,12),(15,10),(8,10),(8,14)],fill=GOLD)
        d.polygon([(2,8),(8,2),(8,12)],fill=CREAM)
        d.line((8,6,15,6,18,9),fill=CREAM,width=2)
    icon('undo',undo)

    def zoom(d):
        d.polygon([(14,12),(22,20),(20,22),(12,14)],fill=WOOD)
        d.polygon([(15,13),(21,19),(19,21),(13,15)],fill=GOLD)
        d.line((16,14,20,18),fill=CREAM)
        d.polygon([(7,3),(12,3),(17,8),(17,13),(13,17),(7,17),(2,12),(2,7)],fill=WOOD)
        d.polygon([(7,2),(12,2),(16,6),(16,12),(12,16),(6,16),(2,12),(2,6)],fill=GOLD)
        d.polygon([(7,5),(11,5),(13,7),(13,11),(11,13),(7,13),(5,11),(5,7)],fill='#527c83')
        d.polygon([(7,5),(11,5),(13,7),(13,10),(10,12),(7,12),(5,10),(5,7)],fill=TEAL)
        d.line((6,8,6,7,8,5,10,5),fill=CREAM)
    icon('zoom',zoom)

    def book(d):
        d.rectangle((4,3,20,21),fill=DEEP)
        d.rectangle((3,2,19,20),fill=WOOD)
        d.rectangle((6,3,18,18),fill=CREAM)
        d.rectangle((3,3,5,19),fill=TEAL)
        d.line((6,19,18,19),fill=GOLD)
        d.polygon([(14,2),(16,2),(16,7),(15,6),(14,7)],fill=CORAL)
        d.line((7,9,8,10,11,7),fill='#527c83',width=2)
        d.line((13,9,16,9),fill=WOOD)
        d.rectangle((8,13,10,15),outline='#527c83')
        d.line((13,14,16,14),fill=WOOD)
    icon('goals',book)

    def pause(d):
        for x in (4,14):
            d.rectangle((x+1,4,x+5,21),fill=DEEP)
            d.rectangle((x,3,x+4,20),fill=GOLD)
            d.rectangle((x,3,x+3,18),fill=CREAM)
    icon('pause',pause)

    def coin(d):
        d.polygon([(8,4),(15,4),(21,10),(21,16),(16,21),(7,21),(2,16),(2,10)],fill=WOOD)
        d.polygon([(8,2),(15,2),(20,7),(20,14),(15,19),(7,19),(2,14),(2,8)],fill=GOLD)
        d.polygon([(8,5),(14,5),(17,8),(17,13),(14,16),(8,16),(5,13),(5,8)],outline='#bc8545')
        d.polygon([(11,6),(13,9),(15,11),(12,15),(9,12),(8,10)],fill='#bc8545')
        d.polygon([(11,6),(13,10),(11,13),(9,10)],fill=CREAM)
        d.line((4,8,4,7,8,3,12,3),fill=CREAM)
    icon('coin',coin)

    def person(d):
        d.polygon([(8,12),(15,12),(19,16),(20,21),(3,21),(4,16)],fill=DEEP)
        d.polygon([(8,11),(15,11),(19,15),(20,20),(3,20),(4,15)],fill=TEAL)
        d.rectangle((10,8,13,12),fill=GOLD)
        d.polygon([(9,2),(14,2),(16,4),(16,7),(14,9),(9,9),(7,7),(7,4)],fill=GOLD)
        d.line((8,5,8,4,10,3,12,3),fill=CREAM)
        d.polygon([(8,11),(11,14),(15,11),(14,11),(11,12),(9,11)],fill=CREAM)
        d.line((5,16,7,14),fill=CREAM)
    icon('people',person)

    def power(d):
        d.polygon([(12,3),(19,3),(14,10),(20,10),(8,22),(10,14),(4,14)],fill=WOOD)
        d.polygon([(12,2),(19,2),(14,9),(20,9),(8,21),(10,13),(4,13)],fill=GOLD)
        d.polygon([(12,2),(16,2),(10,11),(6,11)],fill=CREAM)
    icon('power',power)

    def heart(d):
        d.polygon([(3,6),(5,4),(8,4),(11,7),(14,4),(18,4),(20,6),(20,11),(18,14),(11,21),(4,14),(2,11),(2,7)],fill='#a75350')
        d.polygon([(3,5),(5,3),(8,3),(11,6),(14,3),(18,3),(20,5),(20,10),(18,12),(11,19),(4,12),(2,10),(2,6)],fill=CORAL)
        d.rectangle((5,5,7,6),fill=CREAM)
        d.line((3,7,3,9),fill='#ffc798')
    icon('happy',heart)

    def sun(d):
        for box in ((11,1,12,3),(11,20,12,22),(1,11,3,12),(20,11,22,12),(4,4,5,5),(18,4,19,5),(4,18,5,19),(18,18,19,19)):
            d.rectangle(box,fill=GOLD)
        d.polygon([(9,6),(14,6),(17,9),(17,14),(14,17),(9,17),(6,14),(6,9)],fill=GOLD)
        d.line((7,14,10,16,14,16,16,14),fill='#bc8545')
        d.line((8,10,8,9,10,7,13,7),fill=CREAM,width=2)
    icon('sun',sun)

    def moon(d):
        d.polygon([(12,2),(7,3),(3,7),(2,11),(3,16),(7,20),(12,21),(17,19),(20,15),(15,16),(11,14),(8,10),(9,6)],fill=CREAM)
        d.line((4,16,8,19,12,20,16,18),fill=GOLD,width=2)
        d.rectangle((18,3,19,8),fill=GOLD)
        d.rectangle((16,5,21,6),fill=GOLD)
    icon('moon',moon)

    def water(d):
        d.polygon([(11,2),(13,5),(18,12),(20,15),(20,18),(17,21),(6,21),(3,18),(3,15),(6,10)],fill='#527c83')
        d.polygon([(11,2),(13,6),(17,12),(18,15),(18,17),(16,19),(7,19),(5,17),(5,14),(7,10)],fill=TEAL)
        d.rectangle((7,12,8,15),fill=CREAM)
        d.rectangle((8,16,10,17),fill=CREAM)
    icon('water',water)

    def check(d):
        d.polygon([(2,12),(5,9),(9,13),(18,4),(21,7),(9,19)],fill=GOLD)
        d.polygon([(2,10),(5,7),(9,11),(18,2),(21,5),(9,17)],fill=CREAM)
    icon('check',check)

    def gear(d):
        d.polygon([(9,2),(14,2),(14,5),(16,6),(18,4),(20,6),(18,8),(19,10),(22,10),(22,14),(19,14),(18,16),(20,18),(18,20),(16,18),(14,19),(14,22),(9,22),(9,19),(7,18),(5,20),(3,18),(5,16),(4,14),(1,14),(1,10),(4,10),(5,8),(3,6),(5,4),(7,6),(9,5)],fill=GOLD)
        d.line((5,11,6,9,9,6,12,6),fill=CREAM,width=2)
        d.polygon([(10,7),(13,7),(16,10),(16,13),(13,16),(10,16),(7,13),(7,10)],fill=WOOD)
        d.polygon([(10,9),(13,9),(14,10),(14,13),(13,14),(10,14),(9,13),(9,10)],fill=(0,0,0,0))
    icon('settings',gear)

    def save(d):
        d.polygon([(3,2),(17,2),(21,6),(21,20),(20,21),(3,21)],fill='#527c83')
        d.polygon([(3,2),(17,2),(20,5),(20,19),(3,19)],fill=TEAL)
        d.rectangle((7,2,16,8),fill=CREAM)
        d.rectangle((13,3,15,6),fill=WOOD)
        d.rectangle((6,12,17,19),fill=CREAM)
        d.line((8,14,15,14),fill=WOOD)
        d.line((8,17,15,17),fill=GOLD)
        d.rectangle((18,17,19,19),fill=GOLD)
    icon('save',save)

    def leaf(d):
        d.polygon([(3,16),(3,10),(6,6),(11,3),(21,2),(20,11),(17,16),(12,20),(6,20)],fill='#6f956b')
        d.polygon([(3,15),(4,9),(8,5),(13,3),(21,2),(19,10),(16,15),(11,18),(6,18)],fill='#8fba78')
        d.line((2,21,17,6),fill=GOLD,width=2)
        d.line((5,18,17,6),fill=CREAM)
        d.line((10,13,9,8),fill='#d1d88c')
        d.line((12,11,17,11),fill='#d1d88c')
    icon('leaf',leaf)

    glyphs={'M':['10001','11011','10101','10001','10001','10001','10001'],
            'A':['01110','11011','10001','11111','10001','10001','10001'],
            'R':['11110','10001','10001','11110','10100','10010','10001'],
            'E':['11111','10000','10000','11110','10000','10000','11111']}
    im=Image.new('RGBA',(160,54));d=ImageDraw.Draw(im)
    for shadow in (True,False):
        for k,ch in enumerate('MARE'):
            for y,row in enumerate(glyphs[ch]):
                for x,v in enumerate(row):
                    if v=='1':
                        xx=8+k*37+x*6;yy=6+y*5
                        d.rectangle((xx+(2 if shadow else 0),yy+(3 if shadow else 0),xx+5+(2 if shadow else 0),yy+4+(3 if shadow else 0)),fill=WOOD if shadow else CREAM)
    d.polygon([(131,3),(137,0),(145,0),(139,3)],fill=GOLD)
    d.line((8,49,40,49,44,47,72,47,76,49,112,49,116,47,151,47),fill=TEAL,width=2)
    add('ui_logo',im,(0,0))

    im=Image.new('RGBA',(28,24));d=ImageDraw.Draw(im)
    d.polygon([(3,8),(7,3),(13,1),(20,3),(25,9),(24,14),(16,22),(11,22),(3,14)],fill=WOOD)
    d.polygon([(3,7),(7,2),(13,0),(20,2),(25,8),(24,12),(16,20),(11,20),(3,12)],fill='#e9c999')
    for x in (6,10,14,18,22):d.line((x,6,14,19),fill='#bc956f')
    d.line((8,3,16,2,20,4),fill=CREAM,width=2);add('ui_shell',im,(0,0))
    for n in range(4):
        im=Image.new('RGBA',(13,13));d=ImageDraw.Draw(im);r=(1,3,5,2)[n]
        d.line((6-r,6,6+r,6),fill=CREAM);d.line((6,6-r,6,6+r),fill=CREAM)
        d.rectangle((5,5,7,7),fill=GOLD);add('fx_spark'+str(n),im,(6,6))
