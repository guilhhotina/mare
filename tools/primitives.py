from PIL import Image, ImageDraw

import math, random

C={'ink':'#283e43','grass':'#8ba569','grass2':'#97af70','soil':'#a88c63','stone':'#aaa68d','cream':'#e5d7b5','light':'#fff0cf','shade':'#b9b18e','teal':'#337c77','deep':'#245958','mint':'#74afa0','coral':'#df7955','red':'#ad5140','glass':'#386875','blue':'#6ba2a8','asphalt':'#617471','lane':'#eddbad','sand':'#d6bd8b','wood':'#b08259','woodL':'#d0a574','woodD':'#795e48','water':'#438d99'}

def c(v):return C.get(v,v) if isinstance(v,str) else v

class Art:
 def __init__(self,n=1,m=1,head=40,rot=0):
  self.n=n;self.m=m;self.rot=rot;self.nw=m if rot%2 else n;self.mw=n if rot%2 else m
  self.ox=32*self.mw+12;self.oy=head+12
  self.im=Image.new('RGBA',(32*(self.nw+self.mw)+24,head+16*(self.nw+self.mw)+24))
  self.d=ImageDraw.Draw(self.im);self.depth=[-1e9]*(self.im.width*self.im.height)
 def rotate(self,u,v):
  if self.rot==1:return self.m-v,u
  if self.rot==2:return self.n-u,self.m-v
  if self.rot==3:return v,self.n-u
  return u,v
 def p(self,u,v,z=0):
  u,v=self.rotate(u,v);return (round(self.ox+32*(u-v)),round(self.oy+16*(u+v)-z))
 def dep(self,p):
  u,v=self.rotate(p[0],p[1]);return u+v+p[2]/16
 def paint(self,x,y,z,col):
  if 0<=x<self.im.width and 0<=y<self.im.height:
   k=y*self.im.width+x
   if z>=self.depth[k]-.055:
    self.d.point((x,y),fill=c(col));self.depth[k]=z
 def poly(self,pts,col):
  ps=[self.p(*p) for p in pts];zs=[self.dep(p) for p in pts]

  ox,oy=ps[0];base=zs[0];eq=None
  for j in range(1,len(ps)-1):
   ux,uy=ps[j][0]-ox,ps[j][1]-oy;vx,vy=ps[j+1][0]-ox,ps[j+1][1]-oy
   det=ux*vy-uy*vx
   if det:
    du,dv=zs[j]-base,zs[j+1]-base;eq=((du*vy-dv*uy)/det,(dv*ux-du*vx)/det);break
  if eq is None:
   self.line(pts,col);return
  mk=Image.new('1',self.im.size);ImageDraw.Draw(mk).polygon(ps,fill=1);bb=mk.getbbox()
  if not bb:return
  for y in range(bb[1],bb[3]):
   for x in range(bb[0],bb[2]):
    if mk.getpixel((x,y)):self.paint(x,y,base+eq[0]*(x-ox)+eq[1]*(y-oy),col)
 def line(self,pts,col,width=1):
  for pa,pb in zip(pts,pts[1:]):
   x0,y0=self.p(*pa);x1,y1=self.p(*pb);za=self.dep(pa)+.025;zb=self.dep(pb)+.025
   steps=max(abs(x1-x0),abs(y1-y0),1)
   for k in range(steps+1):
    t=k/steps;x=round(x0+(x1-x0)*t);y=round(y0+(y1-y0)*t);z=za+(zb-za)*t
    for dx in range(width):self.paint(x+dx,y,z,col)
 def dot(self,u,v,z,col):
  x,y=self.p(u,v,z);self.paint(x,y,self.dep((u,v,z))+.004,col)
 def plane(self,x0,y0,x1,y1,z,col):
  f=z if callable(z) else lambda u,v:z
  self.poly([(x0,y0,f(x0,y0)),(x1,y0,f(x1,y0)),(x1,y1,f(x1,y1)),(x0,y1,f(x0,y1))],col)
 def block(self,x0,y0,x1,y1,z0,z1,top='cream',left='shade',right='stone'):
  faces=[([(x0,y0,z0),(x1,y0,z0),(x1,y0,z1),(x0,y0,z1)]),
         ([(x1,y0,z0),(x1,y1,z0),(x1,y1,z1),(x1,y0,z1)]),
         ([(x1,y1,z0),(x0,y1,z0),(x0,y1,z1),(x1,y1,z1)]),
         ([(x0,y1,z0),(x0,y0,z0),(x0,y0,z1),(x0,y1,z1)])]
  for f in sorted(faces,key=lambda f:sum(sum(self.rotate(p[0],p[1])) for p in f)):
   pp=[self.rotate(p[0],p[1]) for p in f]

   shade=left if abs(pp[0][0]-pp[1][0])>.001 else right
   self.poly(f,shade)
  self.plane(x0,y0,x1,y1,z1,top)
 def foliage(self,u,v,z=0,r=.13):
  x,y=self.p(u,v,z);temp=Image.new('RGBA',(14,16));dd=ImageDraw.Draw(temp)
  dd.polygon([(0,7),(2,3),(5,2),(6,0),(10,1),(13,5),(12,10),(9,12),(4,12),(2,10)],fill='#476849')
  dd.polygon([(1,6),(3,3),(7,1),(11,3),(12,6),(10,9),(5,10),(2,8)],fill='#6d8e54')
  dd.polygon([(3,5),(4,3),(7,2),(10,4),(9,6),(6,7),(3,6)],fill='#93a969')
  dd.line((3,4,5,3,7,3),fill='#b2bd7d')
  dd.line((8,8,10,7),fill='#8b9f61');dd.point((3,9),fill='#59794b')
  dd.point((8,3),fill='#c0c68b');dd.point((10,5),fill='#a0b070')
  for yy in range(16):
   for xx in range(14):
    co=temp.getpixel((xx,yy))
    if co[3]:self.paint(x+xx-7,y+yy-10,self.dep((u,v,z+10-yy))+.08,co)
 def planter(self,u,v,z=0):
  self.block(u-.1,v-.1,u+.1,v+.1,z,z+4,'coral','red','woodD');self.foliage(u,v,z+5)
 def pole(self,u,v,z=0,h=15):
  self.line([(u,v,z),(u,v,z+h)],'deep',2)
  self.block(u-.025,v-.025,u+.025,v+.025,z+h-1,z+h+3,'light','cream','shade')

def windows(a,x0,y0,x1,y1,z0,z1):

 for k in range(3):
  lo=x0+.08+(x1-x0-.16)*k/3;hi=lo+(x1-x0-.16)/3-.035
  yy=y1 if a.rot in (0,3) else y0
  a.poly([(lo,yy,z0),(hi,yy,z0),(hi,yy,z1),(lo,yy,z1)],'glass')
  a.line([(lo,yy,z1-1),(hi,yy,z1-1)],'blue')
  a.line([(lo+.025,yy,z0+2),(lo+.025,yy,z1-2)],'mint')
 for k in range(2):
  lo=y0+.06+(y1-y0-.12)*k/2;hi=lo+(y1-y0-.12)/2-.03
  xx=x1 if a.rot in (0,1) else x0
  a.poly([(xx,lo,z0),(xx,hi,z0),(xx,hi,z1),(xx,lo,z1)],'glass')
  a.line([(xx,lo,z1-1),(xx,hi,z1-1)],'blue')

def shelter(a,x,y,z=0):
 a.block(x,y,x+.65,y+.32,z,z+2,'cream','stone','shade')

 a.poly([(x+.05,y+.05,z+3),(x+.61,y+.05,z+3),(x+.61,y+.05,z+15),(x+.05,y+.05,z+15)],'glass')
 a.line([(x+.08,y+.05,z+13),(x+.5,y+.05,z+13)],'blue')
 a.block(x+.12,y+.1,x+.52,y+.19,z+4,z+6,'woodL','wood','woodD')
 for u in (x+.05,x+.61):a.line([(u,y+.29,z+2),(u,y+.29,z+17)],'deep',2)
 a.block(x-.02,y-.025,x+.68,y+.36,z+17,z+19,'teal','mint','deep')
 a.line([(x-.02,y+.36,z+19),(x+.68,y+.36,z+19)],'light')

def container(a,u,v,col,z=0):
 shades={'coral':('coral','red'),'teal':('mint','teal'),'cream':('cream','shade')};top,side=shades[col]
 a.block(u,v,u+.92,v+.42,z,z+12,top,side,'deep' if col=='teal' else side)
 for k in range(1,9):
  uu=u+k*.1;a.line([(uu,v+.42,z+2),(uu,v+.42,z+10)],'wood' if col=='coral' else 'teal' if col=='teal' else 'stone')
 a.line([(u+.92,v+.12,z+1),(u+.92,v+.12,z+11)],'light')
