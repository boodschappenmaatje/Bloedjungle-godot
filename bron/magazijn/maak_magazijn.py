"""Bloedjungle v78. Run: blender -b --python maak_magazijn.py -- OUTPUT_DIRECTORY.
Generates magazijn.blend and magazijn.glb. Forward in Blender -Y = Godot +Z.
Draft model; gameplay integration, collapses and colliders require separate validation."""
import bpy,random,os,sys
random.seed(78)
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
out=os.path.abspath(args[0] if args else os.path.dirname(__file__))
os.makedirs(out,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
def material(name,rgb,met=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*rgb,1);m.use_nodes=True
 p=m.node_tree.nodes.get("Principled BSDF");p.inputs["Base Color"].default_value=(*rgb,1)
 p.inputs["Roughness"].default_value=.83;p.inputs["Metallic"].default_value=met
 return m
wall=material("Weathered plaster",(.46,.44,.36))
iron=material("Dark painted metal",(.19,.24,.19),.6)
roofmat=material("Corrugated roof",(.26,.29,.23),.6)
wood=material("Wooden crates",(.34,.23,.12))
stone=material("Old concrete",(.39,.37,.31))
def node(name,parent=None):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o)
 if parent:o.parent=parent
 return o
def block(name,loc,dim,mat,parent):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=dim
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.data.materials.append(mat);o.parent=parent;return o
root=node("Magazijn");ground=node("Begane",root);dak=node("Dak",root);whole=node("Dak_heel",dak)
damaged=node("Dak_kapot",dak);ruin=node("Ruine",root);debris=node("Puin",root)
block("Fundering",(0,0,.13),(12,8,.26),stone,ground)
i=0
for side in (-1,1):
 for j in range(6):
  if side==-1 and j in (2,3):continue
  x=-5+j*2;y=side*3.9
  seg=node("M0"+str(i),ground)
  block("M0"+str(i)+"_heel",(x,y,2.15),(2,.2,3.8),wall,seg)
  b=block("M0"+str(i)+"_kapot",(x,y,1.4),(2,.2,2.3),wall,seg);b.hide_set(True);b.hide_render=True
  i+=1
for side in (-1,1):
 for j in range(4):
  x=side*5.9;y=-3+j*2;seg=node("M0"+str(i),ground)
  block("M0"+str(i)+"_heel",(x,y,2.15),(.2,2,3.8),wall,seg)
  b=block("M0"+str(i)+"_kapot",(x,y,1.35),(.2,2,2.2),wall,seg);b.hide_set(True);b.hide_render=True
  i+=1
for d in range(2):
 hinge=node("DeurVoor" if d==0 else "DeurVoorR",ground)
 block("Sliding_door_"+str(d),(-1.0 if d==0 else 1.,-3.95,2),(1.95,.1,3.5),iron,hinge)
block("Loading_pad",(0,-5,.3),(7,2,.6),stone,ground)
for j in range(24):
 x=-5.75+j*.5
 for sign in (-1,1):
  p=block("Roof_%s_%s"%(j,sign),(x,sign*2,5.1),(.48,4,.09),roofmat,whole)
  p.rotation_euler[0]=sign*.16
for j in range(8):
 p=block("Damaged_roof_"+str(j),(-5+j*1.4,(-1)**j*2,4.9),(1.2,2,.08),roofmat,damaged)
damaged.hide_set(True);damaged.hide_render=True
inside=node("Inrichting0",ground)
for x in (-4.2,4.2):
 for y in (-1.8,.2,2.2):
  for h in (.8,1.8,2.8):block("Rack",(x,y,h),(1.1,1.4,.08),iron,inside)
  for dx in (-.48,.48):block("Rack_leg",(x+dx,y,1.6),(.08,1.5,3.1),iron,inside)
  block("Military_crate",(x,y,1.13),(.7,.8,.5),wood,inside)
for j in range(10):
 x=random.uniform(-2.7,2.7);y=random.uniform(-2.7,2.7)
 block("Ammo_supply_crate_"+str(j),(x,y,.55),(.8,.65,.75),wood,inside)
for j in range(22):
 p=block("Ruined_block_"+str(j),(random.uniform(-5,5),random.uniform(-3,3),.35),(.8,.7,.45),stone,ruin)
 p.rotation_euler[2]=random.uniform(-.4,.4)
ruin.hide_set(True);ruin.hide_render=True
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out,"magazijn.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(out,"magazijn.glb"),export_format="GLB",export_visible=False)
print("Export complete:",out)
