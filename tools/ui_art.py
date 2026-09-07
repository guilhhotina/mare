
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
        im=Image.new('RGBA',(24,24));d=ImageDraw.Draw(im);fn(d);add('icon_'+name,im,(0,0))
    def house(d):
        d.rectangle((5,11,19,20),fill=INK);d.rectangle((6,10,18,18),fill=CREAM)
        d.polygon([(2,11),(11,3),(21,11),(21,13),(2,13)],fill='#a95146')
        d.polygon([(2,10),(11,2),(21,10)],fill=CORAL)
        d.line((4,9,11,3,18,8),fill='#ffc798');d.rectangle((9,13,13,18),fill=TEAL)
        d.rectangle((15,13,17,15),fill=GOLD);d.rectangle((4,20,20,21),fill=GOLD)
    icon('build',house)
    for name,mode in (('raise',1),('lower',-1),('level',0),('pull',2)):
        def hill(d,mode=mode):
            d.polygon([(2,17),(7,10),(15,11),(21,17),(13,22)],fill='#9d7553')
            d.polygon([(2,16),(7,9),(15,10),(21,16),(13,19)],fill='#8fba78')
            d.line((4,16,12,19,19,16),fill='#d1d88c')
            if mode==1:d.polygon([(11,2),(6,7),(9,7),(9,13),(13,13),(13,7),(16,7)],fill=CREAM)
            elif mode==-1:d.polygon([(9,2),(13,2),(13,8),(16,8),(11,13),(6,8),(9,8)],fill=CREAM)
            elif mode==0:d.rectangle((3,4,20,6),fill=CREAM);d.rectangle((10,7,13,13),fill=WOOD)
            else:d.line((4,7,16,7),fill=CREAM,width=3);d.polygon([(15,3),(21,7),(15,11)],fill=CREAM)
        icon(name,hill)
    def hammer(d):
        d.line((6,20,16,5),fill=WOOD,width=4);d.line((5,19,14,6),fill=GOLD,width=2)
        d.polygon([(11,3),(14,1),(22,7),(19,11)],fill='#83a9ad');d.line((12,3,19,8),fill=CREAM,width=2)
    icon('remove',hammer)
    def undo(d):
        d.line((7,7,16,7,20,11,20,16,16,20,11,20),fill=INK,width=5)
        d.line((7,6,16,6,19,10,19,15,15,18,11,18),fill=GOLD,width=3)
        d.polygon([(2,6),(9,1),(9,11)],fill=CREAM)
    icon('undo',undo)
    def zoom(d):
        d.ellipse((2,2,16,16),fill=GOLD);d.ellipse((4,4,14,14),fill=TEAL)
        d.line((7,6,10,6),fill=CREAM,width=2);d.line((15,15,21,21),fill=WOOD,width=5)
        d.line((17,15,22,20),fill=GOLD,width=2)
    icon('zoom',zoom)
    def book(d):
        d.rectangle((4,2,20,21),fill=INK);d.rectangle((3,1,18,19),fill=WOOD)
        d.rectangle((5,2,18,17),fill='#ead7ab');d.rectangle((3,2,5,18),fill=TEAL)
        d.rectangle((13,1,15,8),fill=CORAL)
        for y in (10,13):d.line((8,y,15,y),fill=WOOD)
    icon('goals',book)
    icon('pause',lambda d:(d.rectangle((5,3,9,20),fill=CREAM),d.rectangle((15,3,19,20),fill=GOLD)))
    def coin(d):
        d.ellipse((3,4,21,22),fill=WOOD);d.ellipse((2,2,20,20),fill=GOLD);d.ellipse((5,5,17,17),outline='#bc8545',width=2)
        d.line((10,6,10,15),fill=CREAM,width=2);d.line((5,4,11,3),fill=CREAM,width=2)
    icon('coin',coin)
    def person(d):
        d.rectangle((8,2,14,8),fill=GOLD);d.rectangle((7,3,15,7),fill=GOLD)
        d.polygon([(6,11),(16,11),(19,21),(3,21)],fill=TEAL);d.rectangle((10,10,12,13),fill=CREAM)
    icon('people',person)
    icon('power',lambda d:d.polygon([(13,1),(4,13),(10,13),(8,23),(20,8),(13,8),(17,1)],fill=GOLD))
    def heart(d):
        d.polygon([(3,5),(7,2),(11,5),(15,2),(20,5),(20,11),(11,21),(2,11)],fill='#a75350')
        d.polygon([(3,4),(7,2),(11,6),(15,2),(19,5),(19,10),(11,18),(3,10)],fill=CORAL);d.line((5,5,7,4),fill=CREAM,width=2)
    icon('happy',heart)
    def sun(d):
        for x,y in ((11,0),(11,21),(0,11),(21,11),(3,3),(19,3),(3,19),(19,19)):d.rectangle((x,y,x+1,y+1),fill=GOLD)
        d.ellipse((5,5,17,17),fill=GOLD);d.line((8,7,12,6),fill=CREAM,width=2)
    icon('sun',sun)
    def moon(d):
        d.polygon([(13,1),(6,3),(3,8),(3,14),(7,19),(15,20),(20,16),(13,16),(9,12),(9,6)],fill=CREAM)
        d.rectangle((18,3,19,6),fill=GOLD);d.rectangle((17,4,20,5),fill=GOLD)
    icon('moon',moon)
    icon('water',lambda d:(d.polygon([(11,1),(3,13),(3,17),(7,21),(15,21),(19,17),(19,13)],fill=TEAL),d.line((6,13,6,16,9,18),fill=CREAM,width=2)))
    def check(d):d.line((3,11,8,17,20,4),fill=INK,width=5);d.line((3,9,8,15,20,2),fill=CREAM,width=3)
    icon('check',check)
    def gear(d):
        d.rectangle((9,1,14,22),fill=GOLD);d.rectangle((1,9,22,14),fill=GOLD)
        d.polygon([(3,5),(5,3),(20,17),(18,20)],fill=GOLD);d.polygon([(3,18),(5,20),(20,5),(18,3)],fill=GOLD)
        d.ellipse((5,5,18,18),fill=GOLD);d.ellipse((8,8,15,15),fill=INK)
    icon('settings',gear)
    def save(d):
        d.polygon([(3,2),(18,2),(21,5),(21,21),(3,21)],fill=TEAL)
        d.rectangle((7,2,16,9),fill=CREAM);d.rectangle((13,3,14,7),fill=WOOD)
        d.rectangle((6,13,18,20),fill='#dbceae');d.line((9,15,15,15),fill=WOOD)
    icon('save',save)
    def leaf(d):
        d.polygon([(3,17),(4,8),(10,3),(21,2),(20,12),(13,19),(5,19)],fill='#8fba78')
        d.line((2,21,17,6),fill=CREAM,width=2);d.line((9,13,9,7),fill=TEAL)
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
