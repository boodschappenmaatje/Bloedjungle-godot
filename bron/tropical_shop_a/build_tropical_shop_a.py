"""Build a modular, walkable tropical WWII shop from the approved Meshy source.
Run from the repository root with Blender 4.3+: blender -b --python ... -- <output-dir>
The approved source GLB is retained unmodified under source/; only its tiled roof faces
are reused in the game asset. The clean shell below gives the building real openings.
"""
import bpy, bmesh, math, os, sys, json, struct
import numpy as np
from mathutils import Vector, Matrix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
SOURCE = os.path.join(os.path.dirname(__file__), 'source/Meshy_AI_Photorealistic_1940s__1113185619_texture.glb')
args = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
OUT = os.path.abspath(args[0] if args else os.path.join(os.path.dirname(__file__), 'output'))
os.makedirs(OUT, exist_ok=True)

# In-game envelope: 10.3 x 8.6 m, two 3.15 m storeys. The approved source's
# nearly square roof is uniformly scaled and aligned to the upper wall eaves.
W, D = 10.3, 8.6
X0, X1 = -W/2, W/2
Y0, Y1 = -D/2, D/2
WALL = 0.24
FLOOR0, FLOOR1, CEIL1 = 0.22, 3.55, 6.72

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x = 1200
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.view_transform = 'AgX'
scene.render.film_transparent = False
scene.world = bpy.data.worlds.new('Tropical daylight')
scene.world.color = (0.20, 0.24, 0.22)

# Small reusable 1K PBR sets keep the game GLB self-contained. The roof maps are
# extracted from the approved embedded Meshy source below; the shell textures are
# generated here at meter-aware repeat scale, without external downloads.
TEXDIR=os.path.join(OUT,'textures'); os.makedirs(TEXDIR,exist_ok=True)
def texture_set(stem, rgb, seed, kind='plaster', size=512):
    rng=np.random.default_rng(seed)
    low=rng.normal(0,1,(size//32,size//32)).astype(np.float32)
    low=np.repeat(np.repeat(low,32,axis=0),32,axis=1)[:size,:size]
    med=np.repeat(np.repeat(rng.normal(0,1,(size//8,size//8)).astype(np.float32),8,axis=0),8,axis=1)[:size,:size]
    fine=rng.normal(0,1,(size,size)).astype(np.float32)
    yy,xx=np.mgrid[0:size,0:size].astype(np.float32); v=yy/size
    if kind=='plaster':
        value=low*5+med*3+fine*2
        damp=np.clip((v-.82)/.18,0,1)*np.clip(.65+low*.08,0,1)
        base=np.array(rgb,dtype=np.float32)[None,None,:]
        arr=np.clip(base+value[...,None]+damp[...,None]*np.array([-27,-24,-17],dtype=np.float32),0,255)
        # Irregular exposed brick flecks at low wall heights.
        chip=(low>.8)&(v>.62)&(v<.99)
        arr[chip]=np.clip(arr[chip]*.52+np.array([56,28,16]),0,255)
        height=(low*.003+med*.0015+fine*.00025+damp*.004).astype(np.float32)
    elif kind=='wood':
        grain=np.sin(yy*.31+low*3)*8+np.sin(yy*.045+med)*5+fine*3
        knots=np.exp(-((xx-size*.35)**2/(size*.07)**2+(yy-size*.42)**2/(size*.025)**2))*18
        arr=np.clip(np.array(rgb,dtype=np.float32)[None,None,:]+(grain-knots)[...,None],0,255)
        height=(grain/255*.015+low*.002).astype(np.float32)
    else:
        grain=low*5+med*3+fine*2
        arr=np.clip(np.array(rgb,dtype=np.float32)[None,None,:]+grain[...,None],0,255)
        chips=(fine>2.2)&(low<-.4)
        arr[chips]=np.clip(arr[chips]*.58+np.array([60,47,32]),0,255)
        height=(grain/255*.025).astype(np.float32)
    base=np.empty((size,size,4),dtype=np.float32); base[:,:,:3]=arr/255.0; base[:,:,3]=1
    # A subtle OpenGL tangent normal from the height field.
    dx=np.roll(height,-1,axis=1)-np.roll(height,1,axis=1); dy=np.roll(height,-1,axis=0)-np.roll(height,1,axis=0)
    nx=-dx*900; ny=-dy*900; nz=np.ones_like(nx); norm=np.sqrt(nx*nx+ny*ny+nz*nz)
    normal=np.stack((nx/norm*.5+.5,ny/norm*.5+.5,nz/norm*.5+.5,np.ones_like(nz)),axis=2).astype(np.float32)
    def save_map(name, pixels, colorspace):
        image=bpy.data.images.new(name,width=size,height=size,alpha=True,float_buffer=False)
        image.pixels.foreach_set(pixels.ravel()); image.filepath_raw=os.path.join(TEXDIR,name+'.png'); image.file_format='PNG'; image.save()
        image.colorspace_settings.name=colorspace
        image.pack(); return image
    return save_map(stem+'_albedo',base,'sRGB'),save_map(stem+'_normal',normal,'Non-Color')

plaster_maps=texture_set('shop_plaster',(158,139,106),11,'plaster')
light_maps=texture_set('shop_limestone',(183,166,132),12,'plaster')
brick_maps=texture_set('shop_brick',(136,65,37),13,'plaster')
wood_maps=texture_set('shop_teak',(106,66,35),21,'wood')
shutter_maps=texture_set('shop_shutter',(51,91,79),31,'paint')
canvas_maps=texture_set('shop_canvas',(89,101,70),41,'paint')

def mat(name, color, rough=0.82, metallic=0.0, maps=None):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metallic
    if maps:
        albedo,normal=maps; tex=m.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=albedo; tex.label='1K baked albedo'; m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
        ntex=m.node_tree.nodes.new('ShaderNodeTexImage'); ntex.image=normal; ntex.label='OpenGL tangent normal'; ntex.image.colorspace_settings.name='Non-Color'
        nm=m.node_tree.nodes.new('ShaderNodeNormalMap'); nm.space='TANGENT'; nm.inputs['Strength'].default_value=.35; m.node_tree.links.new(ntex.outputs['Color'],nm.inputs['Color']); m.node_tree.links.new(nm.outputs['Normal'],p.inputs['Normal'])
        m['maps']='1K albedo + OpenGL normal; UV repeat = 1 m'
    return m
PLASTER=mat('Weathered lime plaster · warm ivory',(0.56,0.49,0.37),.92,maps=plaster_maps)
PLASTER_LIGHT=mat('Plaster trim · faded limestone',(0.70,0.64,0.52),.88,maps=light_maps)
BRICK=mat('Exposed hand-fired brick',(0.31,0.105,0.052),.9,maps=brick_maps)
WOOD=mat('Aged teak · interior and doors',(0.20,0.095,0.040),.78,maps=wood_maps)
WOOD_LIGHT=mat('Worn teak edges',(0.39,0.22,0.095),.78,maps=wood_maps)
SHUTTER=mat('Blue-green shutter paint',(0.105,0.19,0.17),.83,maps=shutter_maps)
GLASS=mat('Dark glass',(0.035,0.07,0.065),.28)
METAL=mat('Blackened iron',(0.075,0.073,0.060),.66,.55)
FLOOR=mat('Interior hardwood',(0.26,0.15,0.075),.78)
CANVAS=mat('Faded green awning canvas',(0.20,0.25,0.18),.88,maps=canvas_maps)
GROUND=mat('Damp stone ground',(0.20,0.23,0.18),.95)

static = {'ExteriorLower':[], 'ExteriorUpper':[], 'TrimLower':[], 'TrimUpper':[], 'Trim':[], 'GroundFloor':[], 'UpperFloor':[], 'InteriorLower':[], 'InteriorUpper':[], 'FurnitureLower':[], 'FurnitureUpper':[], 'Stairs':[], 'Balcony':[]}
def cube(name, loc, size, material, group=None, bevel=0.0, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o=bpy.context.object; o.name=name; o.dimensions=size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if material: o.data.materials.append(material)
    if material and material.get('maps') and o.data.uv_layers:
        uv=o.data.uv_layers.active
        for poly in o.data.polygons:
            normal=poly.normal; axis=0 if abs(normal.x)>.7 else (1 if abs(normal.y)>.7 else 2)
            axes=[i for i in range(3) if i!=axis]
            for li in poly.loop_indices:
                co=o.data.vertices[o.data.loops[li].vertex_index].co
                uv.data[li].uv=(co[axes[0]],co[axes[1]])
    if bevel:
        mod=o.modifiers.new('Soft worn edges','BEVEL'); mod.width=bevel; mod.segments=2
        mod.profile=.5; bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL'); mod.keep_sharp=True
    if parent:
        o.parent=parent; o.matrix_parent_inverse=Matrix.Identity(4); o.location=loc
    if group: static[group].append(o)
    return o

def empty(name, loc=(0,0,0)):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o); o.empty_display_type='PLAIN_AXES'; o.location=loc
    return o

def panel_wall_y(name, y, zlo, zhi, xlo, xhi, openings, material, group='ExteriorLower', thickness=WALL, trim_group='TrimLower'):
    """Wall in XZ plane with rectangular openings (center along X, width, bottom, top)."""
    cuts=sorted(set([xlo,xhi]+[max(xlo,min(xhi,c+s*w/2)) for c,w,b,t in openings for s in (-1,1)]))
    for a,b in zip(cuts,cuts[1:]):
        c=(a+b)*.5; opening=next((op for op in openings if op[0]-op[1]/2 < c < op[0]+op[1]/2),None)
        intervals=[(zlo,zhi)] if opening is None else [(zlo,opening[2]),(opening[3],zhi)]
        for za,zb in intervals:
            if zb-za>.025: cube(name,(c,y,(za+zb)/2),(b-a,thickness,zb-za),material,group,.025)
    # Vertical opening jambs and lintels are solid, dressed masonry.
    for c,w,b,t in openings:
        for xx in (c-w/2,c+w/2): cube(name+'_jamb',(xx,y,(b+t)/2),(.10,thickness*1.15,t-b),PLASTER_LIGHT,trim_group,.025)
        cube(name+'_lintel',(c,y,t+.045),(w+.16,thickness*1.2,.11),PLASTER_LIGHT,trim_group,.025)
        if b>zlo+.05: cube(name+'_sill',(c,y,b-.04),(w+.2,thickness*1.35,.12),PLASTER_LIGHT,trim_group,.025)

def panel_wall_x(name, x, zlo, zhi, ylo, yhi, openings, material, group='ExteriorLower', thickness=WALL, trim_group='TrimLower'):
    cuts=sorted(set([ylo,yhi]+[max(ylo,min(yhi,c+s*w/2)) for c,w,b,t in openings for s in (-1,1)]))
    for a,b in zip(cuts,cuts[1:]):
        c=(a+b)*.5; opening=next((op for op in openings if op[0]-op[1]/2 < c < op[0]+op[1]/2),None)
        intervals=[(zlo,zhi)] if opening is None else [(zlo,opening[2]),(opening[3],zhi)]
        for za,zb in intervals:
            if zb-za>.025: cube(name,(x,c,(za+zb)/2),(thickness,b-a,zb-za),material,group,.025)
    for c,w,b,t in openings:
        for yy in (c-w/2,c+w/2): cube(name+'_jamb',(x,yy,(b+t)/2),(thickness*1.15,.10,t-b),PLASTER_LIGHT,trim_group,.025)
        cube(name+'_lintel',(x,c,t+.045),(thickness*1.2,w+.16,.11),PLASTER_LIGHT,trim_group,.025)
        if b>zlo+.05: cube(name+'_sill',(x,c,b-.04),(thickness*1.35,w+.2,.12),PLASTER_LIGHT,trim_group,.025)

def window_set(label, x, y, z, width=1.15, height=1.35, front=True):
    # Real aperture remains open in the wall; glazed muntin panels and hinged shutters
    # sit on the exterior plane as separate pieces.
    plane=y-.06 if front else x+.06
    for sign in (-1,1):
        if front:
            cube(label+'_shutter',(x+sign*(width*.5+.26),plane,z),(0.42,.10,height),SHUTTER,'Trim',.035)
            for k in range(5): cube(label+'_louver',(x+sign*(width*.5+.26),plane-.058,z-height*.38+k*height*.19),(.37,.03,.045),WOOD_LIGHT,'Trim',.01)
        else:
            cube(label+'_shutter',(plane,y+sign*(width*.5+.26),z),(.10,.42,height),SHUTTER,'Trim',.035)
            for k in range(5): cube(label+'_louver',(plane+.058,y+sign*(width*.5+.26),z-height*.38+k*height*.19),(.03,.37,.045),WOOD_LIGHT,'Trim',.01)
    # dark inset backing and wood frame/muntins
    if front:
        cube(label+'_glazing',(x,y-.13,z),(width-.12,.04,height-.12),GLASS,'Trim')
        for xx in (x-width/2,x+width/2): cube(label+'_frame',(xx,y-.16,z),(.07,.08,height+.06),WOOD_LIGHT,'Trim',.012)
        for zz in (z-height/2,z+height/2): cube(label+'_frame',(x,y-.16,zz),(width+.06,.08,.07),WOOD_LIGHT,'Trim',.012)
        cube(label+'_muntin',(x,y-.18,z),(.045,.05,height),WOOD_LIGHT,'Trim')
        cube(label+'_muntin',(x,y-.18,z),(width,.05,.045),WOOD_LIGHT,'Trim')
    else:
        cube(label+'_glazing',(x+.13,y,z),(.04,width-.12,height-.12),GLASS,'Trim')
        for yy in (y-width/2,y+width/2): cube(label+'_frame',(x+.16,yy,z),(.08,.07,height+.06),WOOD_LIGHT,'Trim',.012)
        for zz in (z-height/2,z+height/2): cube(label+'_frame',(x+.16,y,zz),(.08,width+.06,.07),WOOD_LIGHT,'Trim',.012)
        cube(label+'_muntin',(x+.18,y,z),(.05,.045,height),WOOD_LIGHT,'Trim')
        cube(label+'_muntin',(x+.18,y,z),(.05,width,.045),WOOD_LIGHT,'Trim')

def swing_door(label, hinge, width, height, material=WOOD, front=True, sign=1):
    p=empty(label+'_Pivot',hinge)
    d=cube(label+'_Leaf',(sign*width/2,0,height/2),(width,height*.0+0.085,height),material,parent=p,bevel=.025)
    # raised/recessed plank details on the door face
    for i in range(4):
        if front: cube(label+'_Board'+str(i),(sign*width/2,-.05,.18+i*(height-.36)/4),(width*.78,.035,.045),WOOD_LIGHT,parent=p,bevel=.008)
    knob=cube(label+'_Handle',(sign*(width*.82),-.11,height*.50),(.045,.045,.10),METAL,parent=p,bevel=.018)
    p['interaction']='swing'; p['open_angle_degrees']=92
    return p

def stair_run():
    count=18; x=-3.25; width=1.15; y_start=2.95; run=.245; rise=(FLOOR1-.18)/count
    for i in range(count):
        y=y_start-(i+.5)*run; z=.18+(i+.5)*rise
        cube('Stair tread %02d'%i,(x,y,z),(width,run+.025,.13),WOOD_LIGHT if i%3==0 else WOOD,'Stairs',.025)
        cube('Stair riser %02d'%i,(x,y+run*.48,z-rise*.18),(width,.055,rise),WOOD,'Stairs',.012)
    # stringers provide real continuous structure at both sides
    length=math.sqrt((count*run)**2+(FLOOR1-.18)**2)
    angle=math.atan2(FLOOR1-.18,count*run)
    for xx in (x-width*.47,x+width*.47):
        o=cube('Stair stringer',(xx,y_start-count*run/2,(FLOOR1+.18)/2),(0.11,length,.22),WOOD,'Stairs',.025)
        o.rotation_euler.x=angle
    cube('Stair upper landing',(x, -1.67,FLOOR1-.07),(1.35,1.05,.18),WOOD,'Stairs',.02)
    # open guard rail follows flight and upper landing
    for xx in (x-width*.58,x+width*.58):
        cube('Stair handrail',(xx,y_start-count*run/2,2.05),(0.08,length,.08),WOOD_LIGHT,'Stairs',.025).rotation_euler.x=angle
        for i in range(0,count,2):
            y=y_start-(i+.5)*run; z=.18+(i+.5)*rise
            cube('Stair baluster',(xx,y,z+.72),(.055,.055,1.35),WOOD,'Stairs',.012)

def add_balcony():
    y=Y0-1.15; z=FLOOR1
    cube('Balcony slab',(0,y,z),(4.1,1.65,.24),PLASTER_LIGHT,'Balcony',.04)
    cube('Balcony fascia',(0,y-.79,z-.14),(4.0,.10,.34),PLASTER,'Balcony',.025)
    # railing front and returns, with masonry/wood posts and iron balusters
    cube('Balcony top rail',(0,y-.77,z+1.0),(4.05,.10,.11),WOOD_LIGHT,'Balcony',.025)
    for x in [ -2.0+i*.25 for i in range(17) ]:
        cube('Balcony baluster',(x,y-.77,z+.53),(.055,.055,.92),METAL,'Balcony',.012)
    for x in (-2.03,2.03):
        cube('Balcony corner post',(x,y-.77,z+.54),(.16,.16,1.10),WOOD,'Balcony',.025)
        cube('Balcony return rail',(x,(Y0+y)/2,z+1.0),(.10,1.15,.11),WOOD_LIGHT,'Balcony',.02)

# Structural floors, with a genuine stairwell cut in the upper floor.
cube('Ground floor structural slab',(0,0,.11),(W,D,.22),PLASTER_LIGHT,'GroundFloor',.025)
# Hardwood surface boards, each a real board for localized replacement/inspection
for i in range(36):
    x=X0+.18+i*.285
    cube('Shop floor board %02d'%i,(x,0,.235),(.275,D-.35,.045),FLOOR,'GroundFloor',.006)
# upper floor leaves a full stair opening; four independent floor panels around it.
hole=(-3.95,-2.55,-1.75,2.75)
for xa,xb,ya,yb in [(X0+.12,hole[0],Y0+.12,Y1-.12),(hole[1],X1-.12,Y0+.12,Y1-.12),(hole[0],hole[1],Y0+.12,hole[2]),(hole[0],hole[1],hole[3],Y1-.12)]:
    if xb>xa and yb>ya:
        cube('Upper floor structural panel',((xa+xb)/2,(ya+yb)/2,FLOOR1-.08),(xb-xa,yb-ya,.22),PLASTER_LIGHT,'UpperFloor',.025)
        if yb-ya>1:
            for j in range(max(1,int((xb-xa)/.34))):
                xx=xa+.17+j*.34
                if xx<xb-.1: cube('Upper hardwood board',(xx,(ya+yb)/2,FLOOR1+.045),(.32,yb-ya-.24,.04),FLOOR,'UpperFloor',.006)

# Ground-floor walls: front retail facade, rear entry, and two side windows.
# Every opening is an actual omission from the wall mesh, not a painted rectangle.
front0=[(-3.28,1.30,.92,2.52),(0,1.52,.02,2.40),(3.28,1.30,.92,2.52)]
panel_wall_y('Shop front wall',Y0+.07,FLOOR0,3.38,X0+.05,X1-.05,front0,PLASTER,'ExteriorLower',trim_group='TrimLower')
back0=[(2.5,1.22,.02,2.35)]
panel_wall_y('Shop rear wall',Y1-.07,FLOOR0,3.38,X0+.05,X1-.05,back0,PLASTER,'ExteriorLower',trim_group='TrimLower')
side0=[(-.35,1.15,1.05,2.45),(2.4,1.0,1.05,2.45)]
panel_wall_x('West shop wall',X0+.07,FLOOR0,3.38,Y0+.05,Y1-.05,side0,PLASTER,'ExteriorLower',trim_group='TrimLower')
panel_wall_x('East shop wall',X1-.07,FLOOR0,3.38,Y0+.05,Y1-.05,side0,PLASTER,'ExteriorLower',trim_group='TrimLower')
# Exposed brick panels at damp corners and around the shop entry.
for xx in (X0+.35,X1-.35):
    cube('Exposed brick ground corner',(xx,Y0-.04,.47),(.7,.055,.62),BRICK,'ExteriorLower',.025)
# storefront windows and blue-green shutters
for x in (-3.28,3.28): window_set('Shop window',x,Y0-.15,1.72,1.30,1.58,True)
window_set('Storage side window',X1-.16,-.35,1.78,1.15,1.40,False)
window_set('Shop side window',X1-.16,2.4,1.78,1.0,1.40,False)
# hinged, independent double front door and service rear door
swing_door('Front door left',(-.76,Y0-.18,.02),.76,2.4,WOOD,True,1)
swing_door('Front door right',(.76,Y0-.18,.02),.76,2.4,WOOD,True,-1)
swing_door('Rear service door',(1.89,Y1-.18,.02),1.22,2.35,WOOD,False,1)

# Upper residence, with balcony doors, living-room and bedroom windows.
front1=[(-3.18,1.28,4.45,5.95),(0,1.56,3.57,6.02),(3.18,1.28,4.45,5.95)]
panel_wall_y('Residence front wall',Y0+.07,FLOOR1,CEIL1,X0+.05,X1-.05,front1,PLASTER,'ExteriorUpper',trim_group='TrimUpper')
back1=[(-1.5,1.0,4.55,5.80),(2.4,1.0,4.55,5.80)]
panel_wall_y('Residence rear wall',Y1-.07,FLOOR1,CEIL1,X0+.05,X1-.05,back1,PLASTER,'ExteriorUpper',trim_group='TrimUpper')
side1=[(-.6,1.15,4.5,5.85),(2.25,1.15,4.5,5.85)]
panel_wall_x('West residence wall',X0+.07,FLOOR1,CEIL1,Y0+.05,Y1-.05,side1,PLASTER,'ExteriorUpper',trim_group='TrimUpper')
panel_wall_x('East residence wall',X1-.07,FLOOR1,CEIL1,Y0+.05,Y1-.05,side1,PLASTER,'ExteriorUpper',trim_group='TrimUpper')
for x in (-3.18,3.18): window_set('Residence shutter window',x,Y0-.15,5.2,1.28,1.5,True)
window_set('Bedroom window',X1-.16,-.6,5.2,1.15,1.5,False)
window_set('Rear bedroom window',X1-.16,2.25,5.2,1.15,1.5,False)
swing_door('Balcony door left',(-.78,Y0-.18,FLOOR1),.78,2.45,WOOD,True,1)
swing_door('Balcony door right',(.78,Y0-.18,FLOOR1),.78,2.45,WOOD,True,-1)
add_balcony()

# Continuous exterior belt course and plaster cornices make the storeys legible.
for z in (3.36,6.62):
    cube('Limestone belt course front',(0,Y0-.10,z),(W+.16,.32,.20),PLASTER_LIGHT,'Trim',.045)
    cube('Limestone belt course rear',(0,Y1+.10,z),(W+.16,.32,.20),PLASTER_LIGHT,'Trim',.045)
    for x in (X0-.10,X1+.10): cube('Limestone belt course side',(x,0,z),(.32,D+.16,.20),PLASTER_LIGHT,'Trim',.045)
# timber shop sign, awning and iron brackets
cube('Shop sign board',(0,Y0-.28,2.93),(3.25,.12,.48),WOOD,'Trim',.06)
for i in range(7): cube('Sign inlay plank',(0,Y0-.35,2.76+i*.055),(3.0,.025,.018),WOOD_LIGHT,'Trim',.005)
# sloped canvas canopy with supports
awning=cube('Striped canvas awning',(0,Y0-.82,2.70),(4.35,1.35,.12),CANVAS,'Trim',.025); awning.rotation_euler.x=math.radians(-7)
for x in (-2.0,2.0):
    cube('Awning iron bracket',(x,Y0-.35,2.65),(.07,.82,.07),METAL,'Trim',.02).rotation_euler.x=math.radians(-10)
for x in (-2.13,-1.42,-.71,0,.71,1.42,2.13): cube('Awning seam',(x,Y0-.82,2.77),(.022,1.2,.012),PLASTER_LIGHT,'Trim',.004)

# Real 18-tread wooden staircase, landing, and upper guard rail.
stair_run()
# Small storage partition and interior doorway behind the shop counter.
panel_wall_x('Shop and store partition',2.25,.25,3.25,-.4,3.9,[(1.65,1.05,.25,2.28)],PLASTER,'InteriorLower',.16)
swing_door('Stockroom interior door',(2.17,1.13,.25),1.02,2.0,WOOD,False,1)
# Shop counter, shelves, stock crates and boxed goods.
cube('Shop counter carcass',(-.25,-1.75,.80),(2.55,.72,1.10),WOOD,'FurnitureLower',.04)
cube('Shop counter top',(-.25,-1.75,1.38),(2.72,.82,.12),WOOD_LIGHT,'FurnitureLower',.03)
for i in range(5): cube('Counter panel',(-1.22+i*.49,-2.12,.83),(.38,.035,.72),WOOD_LIGHT,'FurnitureLower',.018)
for y in (1.2,2.1,3.0):
    cube('Shop wall shelf',(1.25,y,1.55),(2.0,.36,.12),WOOD_LIGHT,'FurnitureLower',.025)
    cube('Shop wall shelf',(1.25,y,2.40),(2.0,.36,.12),WOOD_LIGHT,'FurnitureLower',.025)
    for j in range(5): cube('Shelf stock crate',(.48+j*.38,y-.04,1.84),( .27,.28,.42),WOOD,'FurnitureLower',.025)
for xx in (-4.1,-3.2):
    for yy in (2.0,3.2): cube('Stock crate',(xx,yy,.58),(.72,.72,.66),WOOD,'FurnitureLower',.035)
# Upper residence partition: living area to front, bedroom/storage to rear.
panel_wall_x('Residence partition',.45,FLOOR1,CEIL1,-.1,3.95,[(1.05,1.05,3.57,5.75)],PLASTER,'InteriorUpper',.15)
swing_door('Bedroom door',(.37,.52,FLOOR1),1.02,2.18,WOOD,False,1)
# Living room: sofa, table, lamp, bookcase.
cube('Living room sofa base',(-2.7,-1.55,4.08),(2.4,.82,.38),WOOD,'FurnitureUpper',.07)
cube('Living room sofa back',(-2.7,-1.9,4.47),(2.4,.18,.85),WOOD_LIGHT,'FurnitureUpper',.06)
for x in (-3.4,-2.7,-2.0): cube('Sofa cushion',(x,-1.53,4.35),(.65,.64,.18),PLASTER_LIGHT,'FurnitureUpper',.055)
cube('Living room coffee table',(-2.6,.15,4.14),(1.55,.86,.12),WOOD_LIGHT,'FurnitureUpper',.035)
for x in (-3.2,-2.0):
  for y in (-.13,.43): cube('Coffee table leg',(x,y,3.94),(.08,.08,.38),WOOD,'FurnitureUpper',.015)
cube('Residence bookcase',(3.55,1.5,4.65),(.65,2.0,2.0),WOOD,'FurnitureUpper',.03)
for z in (3.9,4.45,5.0,5.55): cube('Bookcase shelf',(3.20,1.5,z),(.08,1.9,.08),WOOD_LIGHT,'FurnitureUpper',.015)
# Bedroom, built around walkable circulation.
cube('Bedroom bed frame',(2.75,2.65,3.86),(1.75,2.15,.36),WOOD,'FurnitureUpper',.04)
cube('Bedroom mattress',(2.75,2.56,4.12),(1.62,1.95,.20),PLASTER_LIGHT,'FurnitureUpper',.07)
for i in range(2): cube('Bedroom pillow',(2.30+i*.88,1.78,4.25),(.72,.48,.18),WOOD_LIGHT,'FurnitureUpper',.06)
cube('Bedroom wardrobe',(4.12,1.1,4.7),(.48,1.7,2.0),WOOD,'FurnitureUpper',.035)
for z in (4.1,4.55,5.0,5.45): cube('Wardrobe door panel',(3.86,1.1,z),(.035,.72,.38),WOOD_LIGHT,'FurnitureUpper',.02)
# Rooftop retaining beams and timber rafters visible from the upper storey.
for x in range(-4,5,2): cube('Upper roof support beam',(x,0,6.55),(.18,D-.4,.24),WOOD,'InteriorUpper',.025)

# Preserve a real separated section of the approved Meshy roof. It is copied from
# the original textured triangles by face orientation/height; original source remains packed.
def extract_embedded_pbr(glb_path):
    with open(glb_path,'rb') as f: raw=f.read()
    if raw[:4]!=b'glTF': raise RuntimeError('Expected binary GLB source')
    offset=12; doc=None; binary=None
    while offset<len(raw):
        length,kind=struct.unpack_from('<I4s',raw,offset); offset+=8
        chunk=raw[offset:offset+length]; offset+=length
        if kind.startswith(b'JSON'): doc=json.loads(chunk)
        elif kind.startswith(b'BIN'): binary=chunk
    paths={}
    for item in doc.get('images',[]):
        view=doc['bufferViews'][item['bufferView']]; start=view.get('byteOffset',0); data=binary[start:start+view['byteLength']]
        stem=item.get('name','source_map'); path=os.path.join(TEXDIR,'meshy_'+stem+'.png')
        with open(path,'wb') as f: f.write(data)
        paths[stem]=path
    return paths

def meshy_roof_material(paths):
    albedo=bpy.data.images.load(paths['texture_0'],check_existing=False); albedo.name='Meshy roof base color · original 2K'; albedo.colorspace_settings.name='sRGB'; albedo.pack()
    normal=bpy.data.images.load(paths['normal'],check_existing=False); normal.name='Meshy roof normal · original 2K'; normal.colorspace_settings.name='Non-Color'; normal.pack()
    orm=bpy.data.images.load(paths['texture_0_metallic_roughness'],check_existing=False); orm.name='Meshy roof metallic roughness · original 2K'; orm.colorspace_settings.name='Non-Color'; orm.pack()
    m=bpy.data.materials.new('Meshy Terracotta Roof · original PBR'); m.use_nodes=True; nodes=m.node_tree.nodes; links=m.node_tree.links; nodes.clear()
    out=nodes.new('ShaderNodeOutputMaterial'); out.location=(620,80)
    p=nodes.new('ShaderNodeBsdfPrincipled'); p.location=(350,80); p.inputs['Roughness'].default_value=.84
    base=nodes.new('ShaderNodeTexImage'); base.image=albedo; base.label='Original Meshy albedo (2K)'; base.location=(-500,220); links.new(base.outputs['Color'],p.inputs['Base Color'])
    ntex=nodes.new('ShaderNodeTexImage'); ntex.image=normal; ntex.label='Original Meshy OpenGL normal (2K)'; ntex.location=(-500,-20)
    nmap=nodes.new('ShaderNodeNormalMap'); nmap.space='TANGENT'; nmap.location=(-170,-10); links.new(ntex.outputs['Color'],nmap.inputs['Color']); links.new(nmap.outputs['Normal'],p.inputs['Normal'])
    ot=nodes.new('ShaderNodeTexImage'); ot.image=orm; ot.label='Original glTF metallic / roughness'; ot.location=(-500,-250)
    sep=nodes.new('ShaderNodeSeparateColor'); sep.mode='RGB'; sep.location=(-180,-250); links.new(ot.outputs['Color'],sep.inputs['Color'])
    links.new(sep.outputs['Green'],p.inputs['Roughness']); links.new(sep.outputs['Blue'],p.inputs['Metallic']); links.new(p.outputs['BSDF'],out.inputs['Surface'])
    m['source_maps']='Original Meshy embedded 2K albedo, OpenGL normal and metallic-roughness'; return m

source_maps=extract_embedded_pbr(SOURCE)
roof_material=meshy_roof_material(source_maps)
bpy.ops.import_scene.gltf(filepath=SOURCE)
src=next(o for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith('output_unwrapped'))
source_mesh=src.data
roof_faces=[]
for p in source_mesh.polygons:
    if p.center.z > 0.25 and p.normal.z > 0.48:
        roof_faces.append(p)
if len(roof_faces)<1500:
    # robust fallback uses only the upper half of the source and upward normals
    roof_faces=[p for p in source_mesh.polygons if p.center.z>0.0 and p.normal.z>0.30]
print('SOURCE ROOF FACES',len(roof_faces),'of',len(source_mesh.polygons))
uvsrc=source_mesh.uv_layers.active.data if source_mesh.uv_layers.active else None
lookup={}; verts=[]; faces=[]; uvcoords=[]
for p in roof_faces:
    face=[]
    for loop_i,vi in zip(p.loop_indices,p.vertices):
        uv=tuple(uvsrc[loop_i].uv) if uvsrc else (0.0,0.0)
        key=(vi,round(uv[0],7),round(uv[1],7))
        if key not in lookup:
            lookup[key]=len(verts); verts.append(tuple(src.matrix_world@source_mesh.vertices[vi].co)); uvcoords.append(uv)
        face.append(lookup[key])
    faces.append(face)
mesh=bpy.data.meshes.new('Meshy original tile roof geometry'); mesh.from_pydata(verts,[],faces); mesh.update()
roof=bpy.data.objects.new('Roof_Meshy',mesh); bpy.context.collection.objects.link(roof)
roof.data.materials.append(roof_material)
uv=mesh.uv_layers.new(name='UVMap')
for poly in mesh.polygons:
    for li in poly.loop_indices: uv.data[li].uv=uvcoords[poly.vertices[poly.loop_indices.index(li)]]
# Transform the roof proportionally; anchor the lower cut to the upper storey cornice.
xs=[v.co.x for v in roof.data.vertices]; ys=[v.co.y for v in roof.data.vertices]; zs=[v.co.z for v in roof.data.vertices]
scale=5.10; sx=scale; sy=4.35; sz=4.85
zbase=min(zs)
for v in roof.data.vertices:
    v.co.x=v.co.x*sx; v.co.y=v.co.y*sy; v.co.z=(v.co.z-zbase)*sz+6.18
roof.data.update()
# roof visibility group for Godot runtime and viewer
roof['module']='removable_roof'; roof['source']='Meshy_AI_Photorealistic_1940s__1113185619_texture.glb'; roof['source_faces']=len(roof_faces)
# Hide original combined mesh; keep in the editable .blend for provenance, exclude from GLB.
src.name='Meshy_Original_Reference'; src.data.materials.clear(); src.data.materials.append(roof_material); src.hide_render=True; src.hide_viewport=True; src.hide_set(True); src['source_reference_only']=True

# Merge static details per functional category/material to keep mesh count controlled.
for group, objects in static.items():
    visible=[o for o in objects if o and o.name in bpy.data.objects]
    if len(visible)<2: continue
    bpy.ops.object.select_all(action='DESELECT')
    for o in visible: o.select_set(True)
    bpy.context.view_layer.objects.active=visible[0]
    bpy.ops.object.join()
    joined=bpy.context.object; joined.name={'Exterior':'Exterior_Walls','ExteriorLower':'Exterior_Walls_Ground','ExteriorUpper':'Exterior_Walls_Upper','Trim':'Exterior_Details','TrimLower':'Exterior_Details_Ground','TrimUpper':'Exterior_Details_Upper','GroundFloor':'Ground_Floor','UpperFloor':'Upper_Floor','InteriorLower':'Interior_Walls_Ground','InteriorUpper':'Interior_Walls_Upper','FurnitureLower':'Shop_Furniture','FurnitureUpper':'Residence_Furniture','Stairs':'Walkable_Staircase','Balcony':'Accessible_Balcony'}[group]
    joined['module']=group.lower()
# Assign metadata to modular geometry and create useful named root.
root=empty('Tropical_Shop_A', (0,0,0)); root['asset']='Bloedjungle City Buildings 2.0 / Tropical Shop A'; root['dimensions_m']='10.3 x 8.6; two storeys'
for o in list(bpy.context.scene.objects):
    if o is root or o.name=='Meshy_Original_Reference': continue
    if o.parent is None: o.parent=root; o.matrix_parent_inverse=Matrix.Identity(4)
# Original mesh nodes are excluded from export by hiding collection/object. Save source in .blend packed.
for im in bpy.data.images:
    try: im.pack()
    except Exception: pass
blend=os.path.join(os.path.dirname(__file__),'Tropical_Shop_A.blend')
bpy.ops.wm.save_as_mainfile(filepath=blend)
# Preserve the 2K Meshy maps in the editable source, while exporting a 1K roof
# set for mobile. The exact source GLB remains untouched alongside this script.
for node in roof_material.node_tree.nodes:
    if node.type=='TEX_IMAGE' and node.image and node.image.size[0]>1024:
        runtime=node.image.copy(); runtime.name=node.image.name+' · optimized 1K'; runtime.scale(1024,1024)
        runtime.filepath_raw=os.path.join(TEXDIR,runtime.name.replace(' · optimized 1K','_runtime_1k')+'.png'); runtime.file_format='PNG'; runtime.save(); runtime.pack(); node.image=runtime
# Export only non-hidden visible scene assets. Export glTF separates roof, floors, furniture and doors.
glb=os.path.join(OUT,'tropical_shop_a.glb')
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.context.scene.objects:
    if obj != src and not obj.hide_get(): obj.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True,
    export_apply=True, export_cameras=False, export_lights=False, export_materials='EXPORT',
    export_image_format='AUTO', export_yup=True, export_attributes=False)
print('SAVED',blend,os.path.getsize(blend),'GLB',glb,os.path.getsize(glb))
