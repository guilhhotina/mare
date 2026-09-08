
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import ast, json, math, random, io, struct
ROOT=Path(__file__).resolve().parents[1]
KIT=ROOT/'art_source/transport'
from primitives import Art, windows, shelter, container
from depth_art import DepthAtlas
from shadow_art import collect as shadow_caster
entries={}; images={}; unique_images={}; casters={}; shadow_points=[]
depth_atlas=DepthAtlas()
def add(name,im,origin,depth=None):
 bb=im.getbbox();assert bb,name
 assert set(im.getchannel('A').tobytes())<={0,255},name
 image=im.crop(bb);signature=(image.size,image.tobytes())
 images[name]=unique_images.setdefault(signature,image);entries[name]={'ox':origin[0]-bb[0],'oy':origin[1]-bb[1]}
 if depth is not None:entries[name]['depth']=depth_atlas.add(name,im,depth)
def save(name,a):
 add(name,a.im,(a.ox,a.oy),a.depth)


 if name.startswith(('b','tree','palm','rock','lamp','site_')):
  caster,points=shadow_caster(a,name.startswith(('b5_','b6_')))
  casters[name]=caster
  entries[name]['cast']=[len(shadow_points),len(points)]
  shadow_points.extend(points)

rows=[
('Trilha de terra','Vias',1,1,8,0,0,0,'terra'),('Passeio','Vias',1,1,16,0,0,0,'pedestres'),('Rua','Vias',1,1,25,0,0,0,'rua'),('Avenida','Vias',2,2,70,1,0,0,'avenida'),
('Ponte de madeira','Vias',1,1,60,0,0,0,'bridge'),('Ponte rodoviaria','Vias',2,2,150,1,0,0,'bridge'),('Escadaria','Vias',1,1,30,0,0,0,'steps'),('Ponto de onibus','Vias',1,1,110,1,0,0,'bus'),('Terminal de balsas','Vias',3,2,650,6,0,0,'ferry'),('Porto de cargas','Vias',4,3,1200,10,0,0,'port'),
('Casinha','Moradia',1,1,90,0,4,0,'house'),('Casa com jardim','Moradia',2,1,160,1,8,0,'garden'),('Vila de sobrados','Moradia',3,1,330,2,18,0,'row'),('Predinho','Moradia',1,1,240,1,14,0,'apart'),('Edificio','Moradia',2,1,480,3,32,0,'apart'),('Torre residencial','Moradia',2,2,1000,6,72,0,'tower'),
('Mercadinho','Comercio',1,1,160,2,0,12,'shop'),('Padaria e cafe','Comercio',1,1,180,2,0,14,'cafe'),('Pet shop','Comercio',1,1,170,2,0,12,'pet'),('Restaurante','Comercio',2,1,300,3,0,25,'rest'),('Feira ao ar livre','Comercio',4,1,360,2,0,28,'market'),('Hotel da ilha','Comercio',2,3,900,7,0,65,'hotel'),('Jardim comercial','Comercio',3,2,650,5,0,48,'mall'),('Oficina','Comercio',3,2,600,5,0,60,'factory'),
('Gerador','Servicos',2,1,220,7,0,0,'diesel'),('Turbina eolica','Servicos',2,2,700,3,0,0,'wind'),('Usina solar','Servicos',3,2,950,2,0,0,'solar'),('Agua e saneamento','Servicos',3,2,650,5,0,0,'water'),('Reciclagem','Servicos',3,2,580,5,0,0,'waste'),('Clinica','Servicos',2,1,420,4,0,0,'clinic'),('Escola','Servicos',3,2,500,4,0,0,'school'),('Bombeiros','Servicos',2,2,430,4,0,0,'fire'),('Posto policial','Servicos',2,2,400,3,0,0,'police'),('Administracao','Servicos',2,2,500,3,0,0,'admin'),
('Praca e playground','Natureza',2,2,100,1,0,0,'park'),('Mirante','Natureza',2,1,140,1,0,4,'lookout'),('Quiosque de praia','Natureza',1,1,120,1,0,8,'kiosk'),('Cerca e portao','Natureza',1,1,15,0,0,0,'fence'),('Abrigo de animais','Natureza',2,2,320,3,0,16,'shelter'),('Centro veterinario','Natureza',3,2,650,5,0,32,'vet')]
(ROOT/'assets/catalog.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))

def terrain(mask,sand,variant):
 im=Image.new('RGBA',(65,65));d=ImageDraw.Draw(im);oy=17
 h=[16 if mask&(1<<i) else 0 for i in range(4)]
 depth=depth_atlas.tile(mask)
 pts=[(32,oy-h[0]),(64,oy+16-h[1]),(32,oy+32-h[2]),(0,oy+16-h[3])]
 base=(216,195,149) if sand else (106,143,88)
 faces=[((0,1,2),(h[1]-h[0]),(h[2]-h[1])),((0,2,3),(h[2]-h[3]),(h[3]-h[0]))]
 for face,du,dv in faces:
  light=1+(du*.3+dv*.45)/80
  col=tuple(max(0,min(255,round(v*light))) for v in base)
  d.polygon([pts[i] for i in face],fill=col)
  if mask and not sand and du+dv<0:


   poly=[(pts[i][0],pts[i][1],h[i]) for i in face]
   for height,color in ((7,(146,127,93)),(3,(126,109,84))):
    clipped=[]
    for aa,bb in zip(poly,poly[1:]+poly[:1]):
     ina=aa[2]<=height;inb=bb[2]<=height
     if ina:clipped.append(aa)
     if ina!=inb:
      t=(height-aa[2])/(bb[2]-aa[2]);clipped.append((aa[0]+(bb[0]-aa[0])*t,aa[1]+(bb[1]-aa[1])*t,height))
    if len(clipped)>2:d.polygon([(round(p[0]),round(p[1])) for p in clipped],fill=tuple(round(v*light) for v in color))
 mk=im.getchannel('A');surface=im.copy();r=random.Random(701+variant*7919)


 def point(u,v):
  z=(h[0]+u*(h[1]-h[0])+v*(h[2]-h[1])) if u>=v else (h[0]+u*(h[2]-h[3])+v*(h[3]-h[0]))
  return round(32+32*(u-v)),round(oy+16*(u+v)-z),z
 def material(u,v):
  if not (0.025<u<.975 and .025<v<.975):return None
  x,y,z=point(u,v)
  du,dv=(h[1]-h[0],h[2]-h[1]) if u>=v else (h[2]-h[3],h[3]-h[0])
  return ('sand' if sand else 'soil' if mask and du+dv<0 and z<=7 else 'grass'),1+(du*.3+dv*.45)/80
 def mark(u,v,delta,kind):
  mat=material(u,v)
  if not mat or mat[0]!=kind:return
  x,y,_=point(u,v)
  if 0<=x<65 and 0<=y<65 and mk.getpixel((x,y)):
   src=surface.getpixel((x,y));d.point((x,y),fill=tuple(max(0,min(255,c+delta)) for c in src[:3]))


 for k in range(5):
  u=.14+r.random()*.72;v=.14+r.random()*.72;mat=material(u,v)
  if not mat:continue
  delta=r.choice((-5,-3,3,5))
  for b in range(-3,4):
   for a in range(-4,5):
    if a*a/21+b*b/11<1:mark(u+a/48,v+b/48,delta,mat[0])

 for k in range(18 if sand else 22):
  u=.08+r.random()*.84;v=.08+r.random()*.84;mat=material(u,v)
  if not mat:continue
  kind=mat[0];delta=r.choice((-9,-5,5,8))
  length=r.randrange(2,5)
  for j in range(length):
   mark(u+j/64,v,delta,kind)
   if j%2==0:mark(u+j/64,v+1/32,delta,kind)


 tufts=[]
 if not sand:
  for k in range(7):
   u=.12+r.random()*.76;v=.12+r.random()*.76
   mat=material(u,v)
   if not mat or mat[0]!='grass':continue
   x,y,z=point(u,v);tufts.append((y,u,v,mat[1],k))
  for _,u,v,light,k in sorted(tufts):
   for du,dv,height in ((-.025,0,1),(0,0,2),(.022,.022,1)):
    if not material(u+du,v+dv) or material(u+du,v+dv)[0]!='grass':continue
    x,y,z=point(u+du,v+dv)

    d.point((x,y),fill=tuple(round(c*light) for c in (81,119,71)))
    d.line((x,y-1,x,y-height),fill=tuple(round(c*light) for c in (137,165,99)))
    for py in range(y-height,y+1):depth[py*65+x]=u+du+v+dv+(z+y-py)/16
   if k==variant and variant%3==0:
    x,y,z=point(u,v);d.point((x,y-3),fill='#ddce91');depth[(y-3)*65+x]=u+v+(z+3)/16

 if mask and not sand:
  for k in range(20):
   u=.08+r.random()*.84;v=.08+r.random()*.84
   mat=material(u,v)
   if not mat or mat[0]!='soil':continue
   du,dv=(h[1]-h[0],h[2]-h[1]) if u>=v else (h[2]-h[3],h[3]-h[0])
   mag=max(abs(du),abs(dv),1);delta=r.choice((-7,6,11))
   for j in range(r.randrange(2,6)):
    mark(u+j*dv/mag/64,v-j*du/mag/64,delta,'soil')
 add(('sand' if sand else 'grass')+str(mask)+'_'+str(variant),im,(32,oy),depth)

for mask in range(16):
 im=Image.new('RGBA',(65,33));d=ImageDraw.Draw(im)
 for y in range(33):
  for x in range(65):
   u=(x-32)/64+y/32;v=y/32-(x-32)/64
   if 0<=u<=1 and 0<=v<=1:
    distances=[]
    if mask&1:distances.append(v)
    if mask&2:distances.append(1-u)
    if mask&4:distances.append(1-v)
    if mask&8:distances.append(u)
    t=min(distances) if distances else 1
    if t<.65:d.point((x,y),fill='#6eb4ac' if t<.12 else '#5ca69f' if t<.28 else '#4a98a0')
 add('water'+str(mask),im if mask else Image.new('RGBA',(1,1),'#397f91'),(32,0))
for sand in (False,True):
 for mask in range(16):
  for variant in range(6):terrain(mask,sand,variant)

manifest=json.loads((KIT/'manifest.json').read_text())
for a in manifest['assets']:
 family=int(a['family'][:2]);variant=a['variant'];name=None
 if family<=4:
  if variant.startswith('plano_'):name=f'road{family}_{a["mask"]}'
  elif variant.startswith('rampa_'):name=f'ramp{family}_{variant[-1]}'
 elif family<=7:
  if variant.startswith('rot_'):name=None


 if name:
  add(name,Image.open(KIT/a['file']).convert('RGBA'),a['origin_px'])

def roof(a,x0,y0,x1,y1,z,color='teal',pitch=True):
 if pitch:
  mid=(y0+y1)/2;h=10
  a.poly([(x0,y0,z),(x1,y0,z),(x1,mid,z+h),(x0,mid,z+h)],'#e59a70' if color=='coral' else '#72aaa0')
  a.poly([(x0,mid,z+h),(x1,mid,z+h),(x1,y1,z),(x0,y1,z)],color)
  a.poly([(x1,y0,z),(x1,mid,z+h),(x1,y1,z)],'cream')
  a.poly([(x0,y0,z),(x0,mid,z+h),(x0,y1,z)],'shade')
  for v in (y0,y1):a.line([(x0,v,z),(x1,v,z)],'#985a45' if color=='coral' else '#2b625d')
  for k in range(1,max(2,int((x1-x0)*8))):
   x=x0+(x1-x0)*k/int((x1-x0)*8);a.line([(x,mid,z+h),(x,y1,z)],'#bd654e' if color=='coral' else '#3b827d')
  a.line([(x0,mid,z+h),(x1,mid,z+h)],'light')

  for row in range(1,4):
   v=mid+(y1-mid)*row/4;zz=z+h*(1-row/4)+.2
   count=max(2,round((x1-x0)*8))
   for k in range(count):
    u=x0+(k+(row%2)*.45)*(x1-x0)/count
    if u+(x1-x0)/count*.6<x1:
     a.line([(u,v,zz),(u+(x1-x0)/count*.6,v,zz)],'#db895e' if color=='coral' else '#58948a')
 else:
  a.block(x0,y0,x1,y1,z,z+3,'teal','mint','deep')
  a.block(x0+.1,y0+.1,x1-.1,y1-.1,z+3,z+4,'stone','shade','shade')
def building(a,x0,y0,x1,y1,h=24,color='coral',pitch=True):
 a.block(x0,y0,x1,y1,1,h,'cream','cream','shade')

 for z in range(6,h-6,18):
  yy=y1 if a.rot in (0,3) else y0;xx=x1 if a.rot in (0,1) else x0
  for side in (0,1):
   lo=x0 if side==0 else y0;hi=x1 if side==0 else y1
   count=max(1,int((hi-lo)*3));width=(hi-lo)/count
   for k in range(count):
    a0=lo+k*width+width*.22;a1=lo+(k+1)*width-width*.22
    if side==0:
     a.poly([(a0,yy,z),(a1,yy,z),(a1,yy,z+9),(a0,yy,z+9)],'glass')
     a.line([(a0,yy,z+8),(a1,yy,z+8)],'blue');a.line([(a0-.015,yy,z-1),(a1+.015,yy,z-1)],'light')
     a.line([((a0+a1)/2,yy,z),((a0+a1)/2,yy,z+9)],'stone')
    else:
     a.poly([(xx,a0,z),(xx,a1,z),(xx,a1,z+9),(xx,a0,z+9)],'glass')
     a.line([(xx,a0,z+8),(xx,a1,z+8)],'blue');a.line([(xx,a0-.015,z-1),(xx,a1+.015,z-1)],'light')

 for z in range(19,h-4,18):
  a.line([(x0,y1,z),(x1,y1,z),(x1,y0,z)],'#c1b597')
 roof(a,x0-.055,y0-.055,x1+.055,y1+.055,h,color,pitch)
 a.poly([(x0+.08,y1,1),(x0+.24,y1,1),(x0+.24,y1,13),(x0+.08,y1,13)],'deep')
 a.dot(x0+.20,y1,6,'woodL')
def awning(a,x0,x1,v,z,color='coral'):
 a.plane(x0,v,x1,v+.19,z,color)
 for k in range(int((x1-x0)*12)):
  if k%2==0:a.plane(x0+k/12,v,min(x1,x0+(k+1)/12),v+.19,z,'cream')
 a.line([(x0,v+.19,z),(x1,v+.19,z)],'red')
def sign(a,u,v,z,kind):
 a.poly([(u-.12,v,z),(u+.12,v,z),(u+.12,v,z+11),(u-.12,v,z+11)],'teal')
 if kind in ('clinic','vet'):
  a.line([(u-.07,v,z+5),(u+.07,v,z+5)],'light',2);a.line([(u,v,z+2),(u,v,z+9)],'light',2)
 elif kind=='pet':
  a.line([(u-.025,v,z+3),(u+.04,v,z+3)],'light',3)
  for off in (-.075,0,.075):a.dot(u+off,v,z+7,'light')
 elif kind=='shop':
  a.poly([(u-.065,v,z+3),(u+.065,v,z+3),(u+.08,v,z+7),(u-.08,v,z+7)],'cream')
  a.line([(u-.04,v,z+7),(u-.04,v,z+9),(u+.04,v,z+9),(u+.04,v,z+7)],'light')
  a.line([(u-.065,v,z+3),(u+.065,v,z+3)],'sand')
 elif kind=='cafe':
  a.poly([(u-.065,v,z+4),(u+.025,v,z+4),(u+.045,v,z+7),(u-.08,v,z+7)],'cream')
  a.line([(u+.045,v,z+7),(u+.1,v,z+7),(u+.1,v,z+5),(u+.025,v,z+5)],'light')
  a.line([(u-.085,v,z+3),(u+.07,v,z+3)],'sand')
  a.line([(u-.025,v,z+8),(u-.04,v,z+9)],'mint')
 elif kind=='rest':
  a.line([(u-.065,v,z+3),(u-.065,v,z+8)],'light')
  a.line([(u-.105,v,z+9),(u-.105,v,z+7),(u-.025,v,z+7),(u-.025,v,z+9)],'cream')
  a.line([(u+.065,v,z+3),(u+.065,v,z+9),(u+.105,v,z+7),(u+.065,v,z+6)],'light')
 else:a.line([(u-.07,v,z+4),(u+.07,v,z+4),(u+.07,v,z+8)],'light',2)

def make_building(idx,row,rot):
 name,cat,n,m,cost,up,pop,inc,kind=row;a=Art(n,m,180 if kind=='tower' else 140 if kind in ('apart','hotel') else 100,rot)
 a.block(.015,.015,n-.015,m-.015,-2,0,'grass' if cat in ('Moradia','Natureza') else 'cream','stone','shade')

 for k in range(n*6):
  u=(k+.5)/6
  a.line([(u,m-.16,1),(u,m-.03,1)],'#b9b798' if cat!='Moradia' else '#a3b478')
 for k in range(m*5):
  v=(k+.5)/5
  a.line([(n-.15,v,1),(n-.03,v,1)],'#c7c4a1' if cat!='Moradia' else '#718f54')
 if kind in ('house','garden','row','apart','tower','hotel'):
  if kind=='row':
   for k in range(3):
    building(a,k+.1,.12,k+.85,.75,28+(k%2)*3,'coral' if k!=1 else 'teal')
    a.block(k+.12,.75,k+.4,.84,0,2,'cream','stone','shade')
    a.plane(k+.17,.84,k+.37,.98,1,'sand')
    a.planter(k+.69,.88,0)
    a.line([(k+.87,.14,1),(k+.87,.74,1)],'stone')
  else:
   h={'house':20,'garden':23,'apart':58 if n==1 else 82,'tower':141,'hotel':65}[kind]
   home_x=1.18 if kind=='garden' else min(n-.16,1.6)
   building(a,.14,.13,home_x,min(m-.2,1.6),h,'coral',h<40)
   if h<40:

    yy=min(m-.2,1.6)
    a.block(.2,yy,.43,yy+.1,0,2,'cream','stone','shade')
    a.block(.18,yy-.01,.45,yy+.1,15,17,'teal','mint','deep')
    a.line([(home_x+.015,yy+.005,2),(home_x+.015,yy+.005,h-1)],'#8b9587')
    a.line([(.15,yy+.004,3),(home_x,yy+.004,3)],'#c9bea1')
    for u in (.55,home_x-.08):
     if u>.45:
      a.block(u-.055,yy+.006,u+.055,yy+.07,5,7,'coral','red','woodD')
      a.line([(u-.05,yy+.04,8),(u+.05,yy+.04,8)],'#5f8854',2)
      a.dot(u-.03,yy+.04,10,'light');a.dot(u+.04,yy+.04,9,'coral')

   if h>40:
    for z in range(18,h-6,18):
     a.block(.14,min(m-.2,1.6),min(n-.16,1.6),min(m-.2,1.6)+.09,z,z+2,'light','shade','stone')
    a.block(.3,.3,.55,.6,h+4,h+9,'stone','shade','deep')
    a.block(.65,.33,.89,.56,h+4,h+7,'cream','stone','shade')
    for j in range(3):a.line([(.68,.37+j*.05,h+8),(.85,.37+j*.05,h+8)],'deep')
   if kind=='hotel':
    a.plane(.2,1.9,1.3,2.7,1,'light');a.plane(.28,1.99,1.22,2.61,2,'blue')
    for u in (.45,1.55):a.planter(u,2.8)
   if kind=='garden':
    a.plane(1.28,.16,1.84,.78,.4,'grass2')
    a.block(1.48,.3,1.53,.36,0,17,'woodL','wood','woodD')
    for u,v,z in ((1.5,.35,22),(1.35,.33,18),(1.65,.35,18)):a.foliage(u,v,z)
    a.block(1.32,.72,1.8,.88,0,3,'woodL','wood','woodD')
    for u in (1.4,1.57,1.73):a.foliage(u,.8,6);a.dot(u,.8,8,'coral')
    a.line([(1.2,.93,1),(1.88,.93,1)],'sand')
   if h<40:
    a.block(.22,.24,.34,.39,h+3,h+16,'cream','shade','stone')
    a.line([(.17,min(m-.2,1.6),h-1),(min(n-.16,1.6),min(m-.2,1.6),h-1)],'light')
    a.plane(.24,min(m-.18,1.7),.49,m-.025,1,'sand')
 elif kind in ('shop','cafe','pet','rest','mall','factory','clinic','school','fire','police','admin','vet','water','waste','diesel'):
  x1=n-.18;y1=min(m-.22,1.25);h=25 if kind not in ('admin','mall','vet') else 38
  building(a,.14,.13,x1,y1,h,'coral' if kind in ('cafe','rest','fire','vet') else 'teal',kind in ('cafe','rest','school','vet'))
  if cat=='Comercio' or kind in ('clinic','vet'):awning(a,.17,min(x1,1.7),y1,h-8);sign(a,(.14+x1)/2,y1+.01,h+3,kind)
  if kind=='fire':
   for u in (.2,1.05):
    a.block(u,1.3,u+.6,1.84,1,11,'coral','red','red');a.block(u+.1,1.5,u+.4,1.8,11,17,'cream','glass','glass')
  if kind=='school':
   a.plane(.2,1.45,2.6,1.85,1,'coral');a.pole(2.75,1.7,0,45);a.poly([(2.75,1.7,45),(2.45,1.7,42),(2.75,1.7,38)],'coral')
  if kind in ('clinic','vet'):sign(a,x1,y1,h+4,'clinic')
  if kind=='diesel':
   a.block(.5,.35,1.3,.6,h+3,h+12,'stone','deep','stone');a.block(1.48,.2,1.57,.3,0,47,'stone','deep','deep')
  if kind=='water':
   for u in (.7,2.05):
    a.block(u-.42,1.35,u+.42,1.89,0,13,'stone','shade','stone');a.plane(u-.34,1.42,u+.34,1.82,14,'blue')
  if kind=='waste':
   for k in range(3):a.block(.3+k*.8,1.45,.85+k*.8,1.88,0,11,'mint' if k==0 else 'coral' if k==1 else 'blue','teal','deep')
  if kind=='factory':
   a.block(2.1,.25,2.35,.52,0,68,'stone','shade','deep');a.block(2.05,.2,2.4,.57,66,70,'cream','stone','shade')
  if kind in ('shop','cafe','pet','rest'):

   a.block(n-.38,m-.24,n-.16,m-.08,1,7,'woodL','wood','woodD')
   for u in (n-.34,n-.25):a.dot(u,m-.17,8,'coral' if kind=='shop' else 'grass2')
   a.block(.07,m-.19,.2,m-.13,0,11,'wood','woodL','woodD')
   a.poly([(.075,m-.125,3),(.195,m-.125,3),(.195,m-.125,10),(.075,m-.125,10)],'deep')
   a.line([(.1,m-.12,7),(.17,m-.12,7)],'cream')
 elif kind=='wind':
  a.block(.85,.85,1.15,1.15,0,8,'stone','shade','stone');a.block(.96,.96,1.04,1.04,8,91,'cream','shade','stone')
  a.block(.88,.92,1.17,1.12,86,94,'cream','shade','stone')
  a.poly([(1,1.14,91),(.93,1.14,131),(1.08,1.14,137),(1.09,1.14,94)],'light')
  a.poly([(1,1.14,91),(.24,1.14,60),(.2,1.14,66),(.92,1.14,94)],'cream')
  a.poly([(1,1.14,91),(1.8,1.14,69),(1.86,1.14,77),(1.07,1.14,94)],'cream')
 elif kind=='solar':
  for u in (.15,1.05,1.95):
   for v in (.15,1.05):
    a.block(u+.1,v+.1,u+.6,v+.6,0,4,'stone','stone','deep');a.poly([(u,v,6),(u+.75,v,6),(u+.75,v+.7,14),(u,v+.7,14)],'glass')
    for t in (.25,.5):a.line([(u+t,v,7),(u+t,v+.7,15)],'blue')
    a.line([(u,v+.35,11),(u+.75,v+.35,11)],'blue')
 elif kind=='market':
  for k in range(4):
   a.block(k+.13,.25,k+.83,.7,0,12,'woodL','wood','woodD');roof(a,k+.08,.1,k+.88,.8,22,'coral' if k%2 else 'teal')
   for j in range(4):a.block(k+.17+j*.15,.5,k+.27+j*.15,.65,12,15,'coral' if k%2 else 'grass2','wood','wood')
 elif kind in ('park','lookout','kiosk','shelter','fence'):
  if kind=='park':


   a.poly([(.16,.2,1),(1.76,.2,1),(1.85,.32,1),(1.85,1.6,1),(1.7,1.7,1),(.18,1.7,1),(.12,1.53,1)],'#cfb784')
   a.line([(.16,.2,1),(1.76,.2,1),(1.85,.32,1),(1.85,1.6,1),(1.7,1.7,1),(.18,1.7,1)],'#a99571')
   for j in range(24):
    u=.23+((j*29)%149)/100;v=.29+((j*41)%123)/100
    a.line([(u,v,1.1),(u+.035,v,1.1)],'#ddc799' if j%2 else '#bba57e')
   for u in (.3,.72):
    for v in (.33,.72):a.block(u-.025,v-.025,u+.025,v+.025,1,25,'woodL','wood','woodD')
   a.block(.25,.27,.78,.77,13,15,'woodL','wood','woodD')
   for v in (.37,.5,.64):a.line([(.26,v,15),(.77,v,15)],'#9b7652')
   roof(a,.2,.22,.83,.82,25,'coral')
   for u in (.29,.72):a.line([(u,.31,16),(u,.31,23)],'teal',2)
   a.line([(.28,.3,23),(.74,.3,23)],'mint',2)
   a.poly([(.39,.78,14),(.65,.78,14),(.65,1.49,2),(.39,1.49,2)],'#7aaeb0')
   a.line([(.52,.81,14),(.52,1.45,3)],'#abc6b5')
   for u in (.37,.67):a.line([(u,.74,18),(u,.88,14),(u,1.5,4)],'teal',2)
   a.block(.37,1.48,.67,1.59,1,3,'mint','teal','deep')
   for v in (.36,.59):a.line([(.8,v,19),(1.08,v,4)],'woodL',2)
   for k in range(5):
    u=.8+.28*k/4;z=14-12*k/4;a.line([(u,.36,z),(u,.59,z)],'woodL',2)
   for u in (1.22,1.77):
    a.line([(u,.22,1),(u,.5,23),(u,.86,1)],'teal',2)
    a.line([(u,.3,7),(u,.75,7)],'mint')
   a.line([(1.17,.5,23),(1.82,.5,23)],'woodL',3)
   for u in (1.37,1.6):a.line([(u,.5,21),(u,.51,5)],'deep')
   a.block(1.33,.45,1.65,.61,4,6,'coral','red','woodD')
   for u in (1.22,1.68):a.block(u,1.42,u+.04,1.65,1,6,'deep','deep','deep')
   a.block(1.15,1.43,1.8,1.64,5,7,'woodL','wood','woodD')
   for z in (8,11):a.line([(1.15,1.43,z),(1.8,1.43,z)],'woodL',2)
   a.plane(.78,1.71,1.17,1.99,1,'cream')
   for u,v in ((.12,.28),(.12,1.03),(1.88,.17),(1.83,1.88)):
    a.foliage(u,v,5);a.dot(u-.04,v,8,'coral');a.dot(u+.04,v,7,'light')
  elif kind=='lookout':
   a.block(.05,.1,1.95,.9,0,10,'woodL','wood','woodD')
   for u in (.1,.5,1,1.5,1.9):a.pole(u,.15,10,11)
   a.line([(.1,.15,22),(1.9,.15,22)],'cream',2);a.pole(1,.65,10,13)
  elif kind=='kiosk':
   building(a,.2,.2,.8,.75,18,'coral');a.planter(.1,.86)
  elif kind=='shelter':
   building(a,.12,.12,1.05,.9,23,'coral');a.plane(1.12,.18,1.82,1.78,1,'sand')
   for u,v in [(1.3,.6),(1.5,1.15)]:
    a.block(u,v,u+.19,v+.13,3,8,'cream','shade','wood');a.block(u+.15,v-.02,u+.27,v+.13,7,12,'cream','shade','wood')
    a.line([(u+.23,v,12),(u+.24,v,15)],'woodD',2)
  else:
   for u in (.05,.35,.65,.95):a.block(u,.45,u+.05,.5,0,17,'woodL','wood','woodD')
   for z in (6,13):a.line([(.05,.48,z),(.99,.48,z)],'woodL',2)
 elif kind=='bridge':
  a.block(0,0,n,m,-3,0,'woodL' if idx==5 else 'asphalt','woodD','stone')
  for u in (.08,n-.08):
   for v in (.08,m-.08):a.block(u-.025,v-.025,u+.025,v+.025,-35,12,'cream','wood','woodD')
  for u in (.06,n-.06):a.line([(u,0,12),(u,m,12)],'light',2)
  for k in range(1,n*8):a.line([(0,k/8,0),(n,k/8,0)],'wood' if idx==5 else 'lane')
 elif kind=='steps':
  for k in range(4):a.block(0,k/4,1,(k+1)/4,0,(k+1)*4,'cream','stone','shade')
 elif kind=='bus':
  a.plane(.02,.02,.98,.98,1,'stone')
  for u in (.15,.4,.65,.9):a.line([(u,.04,1),(u,.96,1)],'#b8b8a0')
  shelter(a,.13,.16,1)
  a.pole(.86,.76,0,26)
  a.poly([(.81,.76,19),(.94,.76,19),(.94,.76,26),(.81,.76,26)],'teal')
  a.line([(.835,.76,24),(.915,.76,24)],'light',2)
  a.block(.68,.68,.78,.79,0,9,'teal','deep','teal')
 elif kind=='ferry':
  a.plane(.02,.02,2.98,1.97,1,'woodL')
  for k in range(1,24):a.line([(.04,k/12,1),(2.96,k/12,1)],'wood')
  building(a,.2,.16,1.67,1.12,27,'teal',False)
  awning(a,.32,1.48,1.12,20,'teal')
  shelter(a,1.9,.15,1)
  for u in (.14,1.45,2.8):a.block(u,1.69,u+.085,1.78,1,8,'deep','stone','deep')

  a.poly([(1.79,1.3,2),(2.82,1.3,2),(2.99,1.55,2),(2.82,1.91,2),(1.79,1.91,2),(1.68,1.65,2)],'deep')
  a.block(1.81,1.4,2.76,1.85,2,9,'cream','cream','teal')
  a.block(2.03,1.46,2.53,1.76,9,20,'teal','glass','glass')
  a.plane(1.99,1.43,2.57,1.8,21,'light')
  a.line([(1.82,1.87,7),(2.75,1.87,7)],'coral',2)
  a.plane(1.3,1.41,1.89,1.64,10,'woodL')
 elif kind=='port':
  a.plane(.03,.03,3.97,2.97,1,'stone')
  for u in (.5,1,1.5,2,2.5,3,3.5):a.line([(u,.03,1),(u,2.96,1)],'#939e95')
  for v in (.5,1,1.5,2,2.5):a.line([(.03,v,1),(3.96,v,1)],'#b7b99e')
  container(a,.2,.15,'coral');container(a,1.24,.15,'teal');container(a,.2,.15,'cream',12)
  container(a,.2,.7,'teal');container(a,1.24,.7,'coral');container(a,.38,1.4,'cream')
  building(a,.2,2.17,1.34,2.81,20,'teal',False)

  for u in (2.35,3.22):
   for v in (.46,1.22):
    a.block(u-.07,v-.07,u+.07,v+.07,0,5,'deep','stone','deep')
    a.line([(u,v,4),(u,v,72)],'woodL',3)
   for z in (10,28,46):
    a.line([(u,.46,z),(u,1.22,z+18),(u,.46,z+18),(u,1.22,z)],'coral')
  a.block(2.24,.35,3.33,1.34,71,77,'woodL','coral','woodD')
  a.block(2.37,.56,2.8,1.16,77,90,'cream','glass','teal')
  for v in (.52,.69):a.line([(2.64,v,87),(3.88,v,62)],'woodL',2)
  for t in (.2,.4,.6,.8):
   a.line([(2.64+1.24*t,.52,87-25*t),(2.64+1.24*t,.69,87-25*t)],'light')
  a.line([(3.88,.62,63),(3.88,.62,17),(3.8,.62,14)],'deep')
  for v in (.2,1.7,2.7):a.block(3.77,v,3.9,v+.12,0,6,'woodL','deep','deep')
 if kind not in ('bridge','steps','fence','solar','wind','port','ferry','bus'):
  a.planter(n-.13,m-.12)
  if n>1:a.planter(.1,m-.14)
 save(f'b{idx}_{rot}',a)
for idx,row in enumerate(rows,1):
 if idx in range(1,5):continue
 for rot in range(4):make_building(idx,row,rot)

for kind in ('tree','palm','rock'):
 for variant in range(3):
  a=Art(1,1,54)
  if kind=='rock':
   a.poly([(.17,.4,0),(.32,.24,7),(.61,.29,10+variant*2),(.75,.61,3),(.51,.76,0)],'#8d9985')
   a.poly([(.17,.4,0),(.32,.24,7),(.61,.29,10+variant*2),(.5,.48,7)],'#c3c4a0')
   a.line([(.31,.27,7),(.51,.31,10)],'#e1d7b2')
  elif kind=='tree':
   a.block(.47,.47,.53,.53,0,22,'wood','wood','woodD')
   for u,v,z in [(.25,.57,20),(.63,.68,20),(.5,.4,22),(.27,.32,26),(.77,.4,25),(.52,.7,30),(.3,.56,32),(.55,.35,36),(.65,.53,34),(.4,.38,39)]:a.foliage(u,v,z+variant*2)
   a.line([(.49,.5,5),(.49,.5,17),(.35,.56,23)],'#b3996a')
  else:
   height=31+variant*3;lean=(-.13,.11,.04)[variant]
   def trunk(t):return (.47+lean*t*t,.53-.1*t*t,height*t)
   spine=[trunk(k/12) for k in range(13)]
   a.line(spine,'#685b42',4);a.line([(u-.018,v,z) for u,v,z in spine],'#b19763',2)
   for j in range(2,12):
    u,v,z=trunk(j/12);a.line([(u-.02,v-.018,z),(u+.04,v+.025,z-.4)],'#dcc18a')
   cu,cv,cz=trunk(1)
   for j in range(8):
    angle=j*math.pi/4+variant*.32;du,dv=math.cos(angle),math.sin(angle)
    length=.64+.07*math.sin(j*2.1+variant);shade=('#397153','#4d8257','#5f915c')[j%3]
    def frond(t):return (cu+du*length*t,cv+dv*length*t,cz+7*math.sin(math.pi*t)-12*t)
    for k in range(1,8):
     t=k/9;u,v,z=frond(t);wid=.125*math.sin(math.pi*t)
     for side in (-1,1):
      tip=(u+du*.075-dv*wid*side,v+dv*.075+du*wid*side,z-3.2)
      tail=frond(min(1,t+.14))
      a.poly([(u,v,z),tip,tail],shade)
      if side==-1 and k%2:a.line([(u,v,z),tip],'#819e68')
    a.line([frond(k/12) for k in range(13)],'#a2b474' if j%2 else '#6e985e')
   for du,dv in ((-.04,.03),(.04,.04),(0,-.02)):
    a.block(cu+du,cv+dv,cu+du+.04,cv+dv+.05,cz-3,cz,'#b59a57','#7b7048','#5b6645')
  save(kind+str(variant),a)

a=Art(1,1,36)
a.block(.8,.13,.89,.22,0,3,'stone','shade','deep')
a.line([(.845,.175,2),(.845,.175,27),(.7,.175,27)],'deep',2)
a.block(.66,.14,.76,.23,21,26,'cream','light','sand')
a.block(.64,.12,.78,.25,26,28,'teal','deep','deep')
save('lamp',a)

from ui_art import generate
generate(add)
from life_art import build as build_life
build_life(add,save)
from traffic_art import build as build_traffic
build_traffic(add)

glows={}
for name,im in images.items():
 if name!='lamp' and (not name.startswith('b') or int(name[1:].split('_')[0]) not in list(range(8,26))+list(range(28,35))+[37,39,40]):continue
 glow=Image.new('RGBA',im.size)
 for yy in range(im.height):
  for xx in range(im.width):
   co=im.getpixel((xx,yy))
   if co[3] and ((co[:3]==(56,104,117) and (xx//7+yy//11)%4!=0) or (name=='lamp' and co[:3] in ((255,240,207),(229,215,181),(214,189,139)))):
    glow.putpixel((xx,yy),(255,213,130,255))
 if glow.getbbox():glows[name]=glow


ordered=sorted(images,key=lambda k:(-images[k].height,k));x=y=2;rh=0;W=1024
placements={}
for key in ordered:
 im=images[key];identity=id(im)
 if identity not in placements:
  if x+im.width+2>W:x=2;y+=rh+2;rh=0
  placements[identity]={'x':x,'y':y,'w':im.width,'h':im.height}
  x+=im.width+2;rh=max(rh,im.height)
 entries[key].update(placements[identity])
H=((y+rh+33)//32)*32
atlas=Image.new('RGBA',(W,H))
painted=set()
for key in images:
 e=entries[key];identity=id(images[key])
 if identity not in painted:
  atlas.paste(images[key],(e['x'],e['y']));painted.add(identity)
 if key in glows:

  runs=[];im=glows[key]
  for yy in range(im.height):
   xx=0
   while xx<im.width:
    if not im.getpixel((xx,yy))[3]:xx+=1;continue
    x0=xx
    while xx<im.width and im.getpixel((xx,yy))[3]:xx+=1
    runs.extend([x0,yy,xx-x0,(yy//3)%2])
  e['light']=runs
buf=io.BytesIO();atlas.save(buf,format='PNG',optimize=True);(ROOT/'assets/atlas.png').write_bytes(buf.getvalue())
(ROOT/'assets/atlas.json').write_text(json.dumps(entries,separators=(',',':')))
(ROOT/'assets/glow.png').unlink(missing_ok=True)
(ROOT/'assets/casters.json').write_text(json.dumps(casters,separators=(',',':')))
(ROOT/'assets/shadow-shapes.bin').write_bytes(struct.pack('<'+'I'*len(shadow_points),*shadow_points))
(ROOT/'assets/depths.bin').write_bytes(depth_atlas.data)
logo=Image.new('RGBA',(160,54));logo.paste(images['ui_logo'],(-entries['ui_logo']['ox'],-entries['ui_logo']['oy']))
buf=io.BytesIO();logo.save(buf,format='PNG');(ROOT/'assets/logo.png').write_bytes(buf.getvalue())

ui_keys=[k for k in images if k.startswith(('ui_','icon_','fx_'))]
sheet=Image.new('RGBA',(384,224));d=ImageDraw.Draw(sheet)
for j,key in enumerate(ui_keys):
 if key=='ui_logo':continue
 x=(j%8)*48;y=(j//8)*40;sheet.paste(images[key],(x+4,y+4),images[key])
buf=io.BytesIO();sheet.save(buf,format='PNG');(ROOT/'assets/interface.png').write_bytes(buf.getvalue())

font=ImageFont.truetype(str(ROOT/'web/vendor/mare.ttf'),17)
preview=Image.new('RGB',(1200,1600),'#193d48');d=ImageDraw.Draw(preview)
for idx,row in enumerate(rows,1):
 x=((idx-1)%5)*240;y=((idx-1)//5)*200
 key=f'b{idx}_0' if idx>4 else f'road{idx}_10';im=images[key]
 scale=min(2,205//im.width,145//im.height);scale=max(1,scale)
 sprite=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST)
 preview.paste(sprite,(x+(240-sprite.width)//2,y+150-sprite.height),sprite)
 d.text((x+12,y+161),str(idx).zfill(2)+' '+row[0],font=font,fill='#f4e5c7')
buf=io.BytesIO();preview.save(buf,format='PNG');(ROOT/'docs/catalogo.png').write_bytes(buf.getvalue())
print(len(images),'sprites;',len(unique_images),'unique images;',W,H,'atlas;', (ROOT/'assets/atlas.png').stat().st_size,'bytes')
