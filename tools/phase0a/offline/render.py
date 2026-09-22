#!/usr/bin/env python3
"""Offline renderer for the Phase 0.A rig.

Draws the exact boxes the Studio bench builds, from the exact transforms the
real modules solve, so the character's construction and poses can be inspected
without Roblox. Flat-shaded z-buffer rasteriser, one neutral key plus ambient,
a one-stud ground grid so foot contact is judgeable by eye.

This is NOT a Studio screenshot: no Roblox materials, no real shadows, no
engine lighting. It shows geometry, proportion, silhouette and pose - which is
most of what a rig review is about - and nothing else.
"""
import json,math,struct,zlib,sys,pathlib

W,H=640,820
AMBIENT=0.40
LIGHT=(0.42,0.80,0.43)   # from camera-ish upper right, normalised below

FONT={
" ":["     "]*7,
"A":[" ### ","#   #","#   #","#####","#   #","#   #","#   #"],
"B":["#### ","#   #","#### ","#   #","#   #","#   #","#### "],
"C":[" ####","#    ","#    ","#    ","#    ","#    "," ####"],
"D":["#### ","#   #","#   #","#   #","#   #","#   #","#### "],
"E":["#####","#    ","#### ","#    ","#    ","#    ","#####"],
"F":["#####","#    ","#### ","#    ","#    ","#    ","#    "],
"G":[" ####","#    ","#    ","#  ##","#   #","#   #"," ####"],
"H":["#   #","#   #","#####","#   #","#   #","#   #","#   #"],
"I":["#####","  #  ","  #  ","  #  ","  #  ","  #  ","#####"],
"J":["    #","    #","    #","    #","#   #","#   #"," ### "],
"K":["#   #","#  # ","###  ","# #  ","#  # ","#  # ","#   #"],
"L":["#    ","#    ","#    ","#    ","#    ","#    ","#####"],
"M":["#   #","## ##","# # #","#   #","#   #","#   #","#   #"],
"N":["#   #","##  #","# # #","#  ##","#   #","#   #","#   #"],
"O":[" ### ","#   #","#   #","#   #","#   #","#   #"," ### "],
"P":["#### ","#   #","#   #","#### ","#    ","#    ","#    "],
"Q":[" ### ","#   #","#   #","#   #","# # #","#  # "," ## #"],
"R":["#### ","#   #","#   #","#### ","# #  ","#  # ","#   #"],
"S":[" ####","#    ","#    "," ### ","    #","    #","#### "],
"T":["#####","  #  ","  #  ","  #  ","  #  ","  #  ","  #  "],
"U":["#   #","#   #","#   #","#   #","#   #","#   #"," ### "],
"V":["#   #","#   #","#   #","#   #","#   #"," # # ","  #  "],
"W":["#   #","#   #","#   #","# # #","# # #","## ##","#   #"],
"X":["#   #","#   #"," # # ","  #  "," # # ","#   #","#   #"],
"Y":["#   #","#   #"," # # ","  #  ","  #  ","  #  ","  #  "],
"Z":["#####","    #","   # ","  #  "," #   ","#    ","#####"],
"0":[" ### ","#   #","#  ##","# # #","##  #","#   #"," ### "],
"1":["  #  "," ##  ","  #  ","  #  ","  #  ","  #  "," ### "],
"2":[" ### ","#   #","    #","   # ","  #  "," #   ","#####"],
"3":["#####","   # ","  ## ","    #","    #","#   #"," ### "],
"4":["   # ","  ## "," # # ","#  # ","#####","   # ","   # "],
"5":["#####","#    ","#### ","    #","    #","#   #"," ### "],
"6":["  ## "," #   ","#    ","#### ","#   #","#   #"," ### "],
"7":["#####","    #","   # ","  #  "," #   "," #   "," #   "],
"8":[" ### ","#   #","#   #"," ### ","#   #","#   #"," ### "],
"9":[" ### ","#   #","#   #"," ####","    #","   # "," ##  "],
"-":["     ","     ","     ","#####","     ","     ","     "],
".":["     ","     ","     ","     ","     ","  ## ","  ## "],
"/":["    #","    #","   # ","  #  "," #   ","#    ","#    "],
":":["     ","  ## ","  ## ","     ","  ## ","  ## ","     "],
"(":["   # ","  #  "," #   "," #   "," #   ","  #  ","   # "],
")":[" #   ","  #  ","   # ","   # ","   # ","  #  "," #   "],
}

def norm(v):
    m=math.sqrt(sum(c*c for c in v))
    return tuple(c/m for c in v) if m else (0.0,0.0,0.0)
LIGHT=norm(LIGHT)

def sub(a,b): return (a[0]-b[0],a[1]-b[1],a[2]-b[2])
def cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def dot(a,b): return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]

class Canvas:
    def __init__(self,w,h,bg):
        self.w,self.h=w,h
        self.col=[bg[0],bg[1],bg[2]]*(w*h)
        self.buf=bytearray()
        for _ in range(w*h): self.buf+=bytes(bg)
        self.depth=[1e30]*(w*h)
    def px(self,x,y,rgb):
        i=(y*self.w+x)*3
        self.buf[i]=rgb[0]; self.buf[i+1]=rgb[1]; self.buf[i+2]=rgb[2]
    def text(self,x,y,s,rgb=(240,244,250),scale=2):
        cx=x
        for ch in s.upper():
            g=FONT.get(ch,FONT[" "])
            for r,row in enumerate(g):
                for c,v in enumerate(row):
                    if v=="#":
                        for dy in range(scale):
                            for dx in range(scale):
                                px,py=cx+c*scale+dx,y+r*scale+dy
                                if 0<=px<self.w and 0<=py<self.h: self.px(px,py,rgb)
            cx+=6*scale
    def png(self,path):
        raw=b""
        for y in range(self.h):
            raw+=b"\x00"+bytes(self.buf[y*self.w*3:(y+1)*self.w*3])
        def chunk(tag,data):
            c=struct.pack(">I",len(data))+tag+data
            return c+struct.pack(">I",zlib.crc32(tag+data)&0xffffffff)
        png=b"\x89PNG\r\n\x1a\n"
        png+=chunk(b"IHDR",struct.pack(">IIBBBBB",self.w,self.h,8,2,0,0,0))
        png+=chunk(b"IDAT",zlib.compress(raw,9))
        png+=chunk(b"IEND",b"")
        pathlib.Path(path).write_bytes(png)

class Camera:
    def __init__(self,eye,target,fov=40.0,aspect=W/H):
        self.eye=eye
        zc=norm(sub(eye,target))
        xc=norm(cross((0,1,0),zc))
        yc=cross(zc,xc)
        self.b=(xc,yc,zc)
        self.ty=math.tan(math.radians(fov)/2)
        self.tx=self.ty*aspect
    def view(self,p):
        d=sub(p,self.eye)
        return (dot(d,self.b[0]),dot(d,self.b[1]),dot(d,self.b[2]))
    def project(self,v,w,h):
        z=-v[2]
        if z<=0.05: return None
        return ((v[0]/z/self.tx*0.5+0.5)*w,(1-(v[1]/z/self.ty*0.5+0.5))*h,z)

# Strictly INSIDE Camera.project's own near cutoff (0.05). Clipping exactly
# onto it puts every new vertex on the reject boundary, project() hands back
# None for it, and the clipped triangle is dropped by the very check the
# clipping exists to avoid.
NEAR=0.0625

def _clip_near(poly):
    """Sutherland-Hodgman against the near plane, in view space.

    A vertex is in front of the lens when its view Z is <= -NEAR (project()
    negates it). `poly` is a list of (view, world) pairs and the world coords
    are carried through the same interpolation so the ground grid still lands
    on whole studs across a clipped triangle.
    """
    out=[]
    for i in range(len(poly)):
        cur,nxt=poly[i],poly[(i+1)%len(poly)]
        cin,nin=cur[0][2]<=-NEAR,nxt[0][2]<=-NEAR
        if cin: out.append(cur)
        if cin!=nin:
            t=(-NEAR-cur[0][2])/(nxt[0][2]-cur[0][2])
            out.append((tuple(cur[0][k]+(nxt[0][k]-cur[0][k])*t for k in range(3)),
                        tuple(cur[1][k]+(nxt[1][k]-cur[1][k])*t for k in range(3))))
    return out

def tri(canvas,cam,p0,p1,p2,shade,world=None,grid=False):
    """Rasterise a world-space triangle, clipping it to the near plane first.

    Dropping a triangle whole because ONE vertex is behind the lens is only
    safe while every part is small and fully in front. It is not: the Arctic
    set's ground is a single 1100-stud slab, and every one of its faces has
    corners behind any camera standing on it, so the entire snow surface
    silently vanished from these renders - the frame showed the sky where the
    ground should be, which is worse than showing nothing, because it reads as
    a hole in the world that Studio does not actually have. draw_floor's own
    docstring has described this hazard since it was written; this fixes the
    cause instead of tessellating around it.
    """
    vs=[cam.view(p) for p in (p0,p1,p2)]
    front=[v[2]<=-NEAR for v in vs]
    if not any(front): return
    if not all(front):
        poly=_clip_near(list(zip(vs,world if world else (p0,p1,p2))))
        if len(poly)<3: return
        # Fan-triangulate the clipped polygon (3-4 vertices here).
        for i in range(1,len(poly)-1):
            part=(poly[0],poly[i],poly[i+1])
            _raster(canvas,cam,[q[0] for q in part],shade,
                    tuple(q[1] for q in part) if grid else None,grid)
        return
    _raster(canvas,cam,vs,shade,world,grid)

def _raster(canvas,cam,vs,shade,world=None,grid=False):
    pts=[cam.project(v,canvas.w,canvas.h) for v in vs]
    if any(p is None for p in pts): return
    (x0,y0,z0),(x1,y1,z1),(x2,y2,z2)=pts
    minx=max(0,int(min(x0,x1,x2))); maxx=min(canvas.w-1,int(max(x0,x1,x2))+1)
    miny=max(0,int(min(y0,y1,y2))); maxy=min(canvas.h-1,int(max(y0,y1,y2))+1)
    if minx>maxx or miny>maxy: return
    area=(x1-x0)*(y2-y0)-(x2-x0)*(y1-y0)
    if abs(area)<1e-9: return
    # PERSPECTIVE-CORRECT DEPTH. Depth is NOT linear across a triangle in
    # screen space; its reciprocal is. Interpolating z directly is close
    # enough to invisible on a small part and catastrophic on a large one:
    # the Arctic ground is a single 1100-stud slab, and the error was big
    # enough that its UNDERSIDE won the depth test against its own top face,
    # so the whole snowfield rendered as the flat ambient-only dark grey of a
    # surface lit from behind. That is what "the snow looks dark" was here,
    # and it was the tool, not the set.
    iz0,iz1,iz2=1.0/z0,1.0/z1,1.0/z2
    for py in range(miny,maxy+1):
        for px in range(minx,maxx+1):
            fx,fy=px+0.5,py+0.5
            w0=((x1-fx)*(y2-fy)-(x2-fx)*(y1-fy))/area
            w1=((x2-fx)*(y0-fy)-(x0-fx)*(y2-fy))/area
            w2=1-w0-w1
            if w0<0 or w1<0 or w2<0: continue
            iz=w0*iz0+w1*iz1+w2*iz2
            if iz<=0: continue
            z=1.0/iz
            i=py*canvas.w+px
            if z>=canvas.depth[i]: continue
            canvas.depth[i]=z
            rgb=shade
            if grid and world:
                # Same correction for the world coordinates the grid is drawn
                # from, or the stud lines bow across a large floor cell.
                wx=(w0*world[0][0]*iz0+w1*world[1][0]*iz1+w2*world[2][0]*iz2)*z
                wz=(w0*world[0][2]*iz0+w1*world[1][2]*iz1+w2*world[2][2]*iz2)*z
                near=min(abs(wx-round(wx)),abs(wz-round(wz)))
                major=min(abs(wx-round(wx/5)*5),abs(wz-round(wz/5)*5))
                fade=max(0.0,1.0-z/70.0)
                if major<0.035: rgb=tuple(int(c*(1-0.42*fade)) for c in shade)
                elif near<0.022: rgb=tuple(int(c*(1-0.20*fade)) for c in shade)
            canvas.px(px,py,rgb)

FACES=[((0,1,2,3),(0,0,1)),((5,4,7,6),(0,0,-1)),((4,0,3,7),(-1,0,0)),
       ((1,5,6,2),(1,0,0)),((4,5,1,0),(0,1,0)),((3,2,6,7),(0,-1,0))]

def box_corners(part):
    p=part["p"]; sx,sy,sz=[c/2 for c in part["size"]]
    X,Y,Z=part["x"],part["y"],part["z"]
    out=[]
    for ix,iy,iz in ((-1,1,1),(1,1,1),(1,-1,1),(-1,-1,1),(-1,1,-1),(1,1,-1),(1,-1,-1),(-1,-1,-1)):
        out.append(tuple(p[k]+X[k]*ix*sx+Y[k]*iy*sy+Z[k]*iz*sz for k in range(3)))
    return out

def draw_box(canvas,cam,part,silhouette):
    c=box_corners(part)
    X,Y,Z=part["x"],part["y"],part["z"]
    base=part["c"]
    for idx,n in FACES:
        nw=tuple(X[k]*n[0]+Y[k]*n[1]+Z[k]*n[2] for k in range(3))
        if silhouette:
            col=(14,15,18)
        else:
            lam=max(0.0,dot(nw,LIGHT))
            f=AMBIENT+(1-AMBIENT)*lam
            col=tuple(min(255,int(v*f)) for v in base)
        a,b,cc,d=[c[i] for i in idx]
        tri(canvas,cam,a,b,cc,col); tri(canvas,cam,a,cc,d,col)

def draw_floor(canvas,cam,silhouette,centre):
    """Tessellated so it actually draws.

    A single huge quad has corners behind the camera, and any triangle with a
    vertex behind the near plane is discarded whole - so the floor silently
    never rendered at all, leaving dark legs on a dark background with no
    ground reference. Splitting it into cells around the camera target keeps
    every triangle small and in front.
    """
    col=(146,152,162) if not silhouette else (232,235,240)
    cx,cz=centre[0],centre[2]
    R,STEP=46,2
    for gx in range(-R,R,STEP):
        for gz in range(-R,R,STEP):
            x0,z0=cx+gx,cz+gz
            x1,z1=x0+STEP,z0+STEP
            a,b,c,d=(x0,0,z0),(x1,0,z0),(x1,0,z1),(x0,0,z1)
            tri(canvas,cam,a,b,c,col,world=(a,b,c),grid=True)
            tri(canvas,cam,a,c,d,col,world=(a,c,d),grid=True)

def draw_marker(canvas,cam,pos,rgb):
    s=0.30
    q=[(pos[0]-s,0.012,pos[2]-s),(pos[0]+s,0.012,pos[2]-s),
       (pos[0]+s,0.012,pos[2]+s),(pos[0]-s,0.012,pos[2]+s)]
    tri(canvas,cam,q[0],q[1],q[2],rgb); tri(canvas,cam,q[0],q[2],q[3],rgb)

def render(frame,eye,target,path,label,silhouette=False,markers=True):
    bg=(58,64,74) if not silhouette else (250,251,253)
    canvas=Canvas(W,H,bg)
    cam=Camera(eye,target)
    draw_floor(canvas,cam,silhouette,target)
    if markers and not silhouette:
        for side,f in frame["feet"].items():
            draw_marker(canvas,cam,f["target"],(96,190,120) if f["mode"]=="planted" else (214,158,72))
    for part in frame["parts"]:
        if part["name"]=="HumanoidRootPart": continue
        draw_box(canvas,cam,part,silhouette)
    fg=(232,238,246) if not silhouette else (40,44,52)
    canvas.text(16,16,label,fg,2)
    canvas.png(path)
    return path

if __name__=="__main__":
    frames={f["tag"]:f for f in json.load(open(sys.argv[1]))}
    outdir=pathlib.Path(sys.argv[2]); outdir.mkdir(parents=True,exist_ok=True)
    def actorpos(f): return f["root"]
    def rel(f,off):
        p=actorpos(f)
        return (p[0]+off[0],off[1],p[2]+off[2]),(p[0],2.55,p[2])
    jobs=[]
    n=frames["neutral"]
    for name,off in (("front",(0,3.2,-11.0)),("side",(11.0,3.2,0)),("threequarter",(7.6,4.3,-9.2))):
        e,t=rel(n,off); jobs.append((n,e,t,f"01-neutral-{name}.png",f"NEUTRAL STAND - {name}",False))
    e,t=rel(n,(7.6,4.3,-9.2)); jobs.append((n,e,t,"02-neutral-silhouette.png","NEUTRAL STAND - SILHOUETTE",True))
    for tag,label in (("look_small_left","SMALL LOOK - NECK ONLY"),("look_large_left","LARGE LOOK - TORSO ASSISTS")):
        f=frames[tag]; e,t=rel(f,(7.6,4.3,-9.2)); jobs.append((f,e,t,f"03-{tag}.png",label,False))
    for tag in ("gesture_peak","gesture_late"):
        f=frames[tag]
        e,t=rel(f,(7.6,4.3,-9.2)); jobs.append((f,e,t,f"04-{tag}-threequarter.png",f"{tag.replace('_',' ')} - 3Q",False))
        e,t=rel(f,(11.0,3.2,0)); jobs.append((f,e,t,f"04-{tag}-side.png",f"{tag.replace('_',' ')} - SIDE",False))
    for tag,label in (("turn_mid","TURN 90 - MID"),("turn_end","TURN 90 - SETTLED")):
        f=frames[tag]; e,t=rel(f,(7.6,4.3,-9.2)); jobs.append((f,e,t,f"05-{tag}.png",label,False))
    # Walk: one FIXED world camera across four strides, so a planted foot can be
    # checked against the grid rather than against the character.
    wa=frames["walk_stride_a"]; wd=frames["walk_stride_d"]
    mx=(wa["root"][0]+wd["root"][0])/2; mz=(wa["root"][2]+wd["root"][2])/2
    # Put the fixed camera on the walker's own RIGHT, whatever direction it is
    # travelling - it has already turned 90 degrees by this point, so a camera
    # pinned to +X framed its back instead of its side.
    yaw=wa["yaw"]; rx,rz=math.cos(yaw),-math.sin(yaw)
    fixed_eye=(mx+rx*13.5,3.0,mz+rz*13.5); fixed_tgt=(mx,2.3,mz)
    for i,tag in enumerate(("walk_stride_a","walk_stride_b","walk_stride_c","walk_stride_d")):
        f=frames[tag]
        jobs.append((f,fixed_eye,fixed_tgt,f"06-walk-{i+1}-fixedcam.png",f"WALK {i+1}/4 - FIXED WORLD CAMERA",False))
    for tag,label in (("walk_stop","WALK - STOPPED AND SETTLED"),("walk_turn","TURN WHILE WALKING"),
                      ("step_back","BACKWARD STEP"),("flinch","FLINCH"),("final_idle","FINAL IDLE AFTER EVERYTHING")):
        f=frames[tag]; e,t=rel(f,(7.6,4.3,-9.2)); jobs.append((f,e,t,f"07-{tag}.png",label,False))
    f=frames["final_idle"]; e,t=rel(f,(0,3.2,-11.0))
    jobs.append((f,e,t,"08-final-idle-front.png","FINAL IDLE - FRONT (COMPARE 01)",False))
    e,t=rel(f,(7.6,4.3,-9.2)); jobs.append((f,e,t,"08-final-idle-silhouette.png","FINAL IDLE - SILHOUETTE",True))
    # Silhouette variants of the action frames. Dark trousers under low-key
    # shading read as one mass in a flat-shaded render, so pose shape is
    # judged in silhouette, where nothing can hide.
    for tag,label in (("walk_stride_a","WALK A"),("walk_stride_b","WALK B"),
                      ("walk_stride_c","WALK C"),("walk_stride_d","WALK D")):
        f=frames[tag]
        yaw=f["yaw"]; rx,rz=math.cos(yaw),-math.sin(yaw)
        p0=f["root"]
        e=(p0[0]+rx*12.5,3.0,p0[2]+rz*12.5); t=(p0[0],2.5,p0[2])
        jobs.append((f,e,t,f"09-sil-{tag}.png",f"{label} - SILHOUETTE",True))
    for tag,label in (("gesture_peak","GESTURE PEAK"),("turn_mid","TURN MID"),
                      ("step_back","STEP BACK"),("flinch","FLINCH"),("walk_stop","STOPPED")):
        f=frames[tag]
        yaw=f["yaw"]; lx,lz=-math.sin(yaw),-math.cos(yaw); rx,rz=math.cos(yaw),-math.sin(yaw)
        p0=f["root"]
        e=(p0[0]+lx*8.2+rx*7.4,4.1,p0[2]+lz*8.2+rz*7.4); t=(p0[0],2.5,p0[2])
        jobs.append((f,e,t,f"09-sil-{tag}.png",f"{label} - SILHOUETTE 3Q",True))
    for fr,e,t,name,label,sil in jobs:
        render(fr,e,t,str(outdir/name),label,sil)
        print(name)
