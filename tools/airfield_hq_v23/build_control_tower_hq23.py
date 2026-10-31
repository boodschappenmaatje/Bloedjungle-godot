"""Build the Airfield HQ 2.3 tower from repeatable Blender geometry.

Blender 4.5.15:
  blender --background --threads 4 --python tools/airfield_hq_v23/build_control_tower_hq23.py

Coordinates are metres, Blender Z-up. The model is centered on the tower shaft,
with ground at z=0; it is exported as a separate GLB so the approved HQ 2.2
hangar and its source remain untouched.
"""
from __future__ import annotations

import bpy
import math
import os
from array import array
from mathutils import Vector

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
SOURCE = os.path.join(ROOT, "source_assets/airfield_hq_v23/tower")
OUTPUT = os.path.join(ROOT, "assets/airfield_hq_v23/tower")
POLY = os.path.join(ROOT, "source_assets/airfield_hq/polyhaven")
BLEND = os.path.join(SOURCE, "Control_Tower_HQ_23_Source.blend")
GLB = os.path.join(OUTPUT, "Control_Tower_HQ_23.glb")
os.makedirs(SOURCE, exist_ok=True)
os.makedirs(OUTPUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = "Airfield HQ 2.3 — USAAF control tower"
scene["ASSET_ID"] = "bloedjungle_airfield_hq23_control_tower"
scene["HISTORICAL_REFERENCE"] = "1942–1944 USAAF field control tower: raised glazed cab, weather/radio rooms, external steel stair, no radar"
scene["AUTHORING_UNITS"] = "metres; Blender Z-up; centered at tower shaft"
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.render.resolution_x = 1280
scene.render.resolution_y = 1280
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.world = bpy.data.worlds.new("HQ23 tower neutral overcast studio")
scene.world.color = (0.17, 0.19, 0.2)
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.46, 0.49, 0.52, 1.0)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.75

asset = bpy.data.collections.new("AIRFIELD HQ 2.3 — CONTROL TOWER")
scene.collection.children.link(asset)

TEXTURES = os.path.join(SOURCE, "textures")
os.makedirs(TEXTURES, exist_ok=True)

def save_generated_map(filename: str, pixels: np.ndarray, channels: int, colorspace: str) -> str:
    height, width = pixels.shape[:2]
    image = bpy.data.images.new(filename, width=width, height=height, alpha=(channels == 4), float_buffer=False)
    rgba = np.zeros((height, width, 4), dtype=np.float32)
    if channels == 1:
        gray = pixels.astype(np.float32) / 255.0
        rgba[:, :, 0] = gray
        rgba[:, :, 1] = gray
        rgba[:, :, 2] = gray
    else:
        rgba[:, :, :channels] = pixels.astype(np.float32) / 255.0
    rgba[:, :, 3] = 1.0
    image.pixels.foreach_set(array("f", rgba.ravel()))
    image.update()
    # Blender 4.5 clears generated-image pixel buffers when the color space is
    # changed after foreach_set(). Keep generated pixels in their default sRGB
    # space while writing the PNG. The PBR material nodes tag normal and
    # roughness maps Non-Color after reloading these saved files.
    print("HQ23_TEXTURE_CHECK", filename, int(pixels.min()), int(pixels.max()), list(image.pixels[:4]))
    path = os.path.join(TEXTURES, filename)
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    return path

def make_tower_pbr_maps() -> tuple[str, str, str, str, str, str]:
    """Authored, controlled wartime plaster/paint PBR; no downloaded dependency."""
    n = 1024
    rng = np.random.default_rng(1944)
    yy, xx = np.mgrid[0:n, 0:n]
    grain = rng.normal(0.0, 1.0, (n,n))
    coarse = rng.normal(0.0, 1.0, (64,64))
    coarse = np.repeat(np.repeat(coarse, n//64, axis=0), n//64, axis=1)
    medium = rng.normal(0.0, 1.0, (256,256))
    medium = np.repeat(np.repeat(medium, n//256, axis=0), n//256, axis=1)
    texture_noise = grain*2.0 + medium*2.4 + coarse*3.0
    # Fine mortar joints and a few restrained vertical rain traces at sill lines.
    mortar = (np.mod(yy,128) < 2).astype(np.float32) * -8.0
    mortar += ((np.mod(xx + (yy//128%2)*64,128) < 2) & (np.mod(yy,128) > 2)).astype(np.float32)*-5.0
    streak = np.zeros((n,n),dtype=np.float32)
    for center_x in (81,174,305,432,586,713,864,954):
        length = int(rng.integers(90,430))
        top = int(rng.integers(0,450))
        active = (yy >= top) & (yy < top+length)
        width = float(rng.uniform(2.5,6.0))
        vertical = np.exp(-((xx-center_x)/width)**2) * active
        taper = np.clip((top+length-yy)/36.0,0.0,1.0)
        streak += vertical*taper*float(rng.uniform(3.0,7.0))
    gray = np.clip(171.0 + texture_noise + mortar - streak, 0, 255)
    masonry = np.stack((gray*1.035,gray*1.005,gray*0.94),axis=2).clip(0,255).astype(np.uint8)
    height_map = np.clip(128.0 + texture_noise*1.9 + mortar*0.35,0,255).astype(np.float32)/255.0
    gy,gx=np.gradient(height_map)
    nx=-gx*10.0; ny=-gy*10.0; nz=np.ones_like(nx)
    norm=np.sqrt(nx*nx+ny*ny+nz*nz)
    normal_pixels=np.stack(((nx/norm*0.5+0.5)*255,(ny/norm*0.5+0.5)*255,(nz/norm*0.5+0.5)*255),axis=2).clip(0,255).astype(np.uint8)
    rough=np.clip(218.0 + coarse*2.5 + medium*2.0 - streak*0.5,170,245).astype(np.uint8)

    paintgrain=rng.normal(0.0,1.0,(n,n))*2.0 + medium*1.4 + coarse*2.1
    seam=(np.mod(xx,128)<2).astype(np.float32)*-5.0
    roof=np.clip(108.0+paintgrain+seam,0,255)
    roof_pixels=np.stack((roof*0.91,roof*0.97,roof*0.88),axis=2).clip(0,255).astype(np.uint8)
    roof_height=np.clip(128.0+paintgrain*1.5+seam*0.6,0,255).astype(np.float32)/255.0
    rgy,rgx=np.gradient(roof_height)
    rnx=-rgx*12.0; rny=-rgy*12.0; rnz=np.ones_like(rnx)
    rnorm=np.sqrt(rnx*rnx+rny*rny+rnz*rnz)
    roof_normal=np.stack(((rnx/rnorm*0.5+0.5)*255,(rny/rnorm*0.5+0.5)*255,(rnz/rnorm*0.5+0.5)*255),axis=2).clip(0,255).astype(np.uint8)
    roof_rough=np.clip(191.0+paintgrain*2.0,160,235).astype(np.uint8)
    return (
        save_generated_map("tower_masonry_albedo_1k.png",masonry,3,"sRGB"),
        save_generated_map("tower_masonry_normal_1k.png",normal_pixels,3,"Non-Color"),
        save_generated_map("tower_masonry_roughness_1k.png",rough,1,"Non-Color"),
        save_generated_map("tower_roof_albedo_1k.png",roof_pixels,3,"sRGB"),
        save_generated_map("tower_roof_normal_1k.png",roof_normal,3,"Non-Color"),
        save_generated_map("tower_roof_roughness_1k.png",roof_rough,1,"Non-Color"),
    )

masonry_maps=make_tower_pbr_maps()

def new_pbr(name: str, family: str, metallic: float = 0.0) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (0.46, 0.45, 0.40, 1.0) if family == "concrete" else (0.24, 0.27, 0.22, 1.0)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = 0.82 if family == "concrete" else 0.58
    mat.node_tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    if family in ("concrete", "metal"):
        offsets=(0,1,2) if family=="concrete" else (3,4,5)
        tex = bpy.data.images.load(masonry_maps[offsets[0]], check_existing=True)
        nor = bpy.data.images.load(masonry_maps[offsets[1]], check_existing=True)
        rough = bpy.data.images.load(masonry_maps[offsets[2]], check_existing=True)
        tex_node = nodes.new("ShaderNodeTexImage")
        tex_node.image = tex
        tex_node.label = "HQ23 authored physically based base color"
        nor_node = nodes.new("ShaderNodeTexImage")
        nor_node.image = nor
        nor_node.label = "HQ23 authored OpenGL normal"
        nor_node.image.colorspace_settings.name = "Non-Color"
        normal = nodes.new("ShaderNodeNormalMap")
        normal.inputs["Strength"].default_value = 0.72
        rough_node = nodes.new("ShaderNodeTexImage")
        rough_node.image = rough
        rough_node.label = "HQ23 authored tower roughness"
        rough_node.image.colorspace_settings.name = "Non-Color"
        mat.node_tree.links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])
        mat.node_tree.links.new(nor_node.outputs["Color"], normal.inputs["Color"])
        mat.node_tree.links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
        mat.node_tree.links.new(rough_node.outputs["Color"], bsdf.inputs["Roughness"])
        # The roof sheet is painted metal; the metallic response remains a
        # constant glTF factor, while weathered roughness is mapped per pixel.
        tex_node.location = (-620, 200)
        nor_node.location = (-620, -60)
        rough_node.location = (-620, -280)
        normal.location = (-340, -40)
        bsdf.location = (-80, 140)
        out.location = (200, 140)
    return mat

concrete = new_pbr("HQ23 | aged poured concrete and wartime painted masonry", "concrete")
metal_skin = new_pbr("HQ23 | faded galvanized wartime roof sheet", "metal", 0.28)
steel = bpy.data.materials.new("HQ23 | dark oxide steel and stair structure")
steel.diffuse_color = (0.13, 0.16, 0.15, 1)
steel.use_nodes = True
steel_bsdf = steel.node_tree.nodes.get("Principled BSDF")
steel_bsdf.inputs["Base Color"].default_value = (0.16, 0.18, 0.17, 1)
steel_bsdf.inputs["Metallic"].default_value = 0.72
steel_bsdf.inputs["Roughness"].default_value = 0.62
glass = bpy.data.materials.new("HQ23 | lightly smoky wartime laminated glass")
glass.diffuse_color = (0.24, 0.32, 0.34, 0.32)
glass.use_nodes = True
glass_bsdf = glass.node_tree.nodes.get("Principled BSDF")
glass_bsdf.inputs["Base Color"].default_value = (0.31, 0.40, 0.42, 1)
glass_bsdf.inputs["Metallic"].default_value = 0.10
glass_bsdf.inputs["Roughness"].default_value = 0.22
glass_bsdf.inputs["Alpha"].default_value = 0.34
glass.surface_render_method = "DITHERED"
wood = bpy.data.materials.new("HQ23 | dark varnished operations timber")
wood.diffuse_color = (0.19, 0.13, 0.08, 1)
wood.use_nodes = True
wood.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (0.24, 0.16, 0.095, 1)
wood.node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value = 0.68
canvas = bpy.data.materials.new("HQ23 | folded map and canvas")
canvas.diffuse_color = (0.48, 0.39, 0.24, 1)
canvas.use_nodes = True
canvas.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (0.50, 0.41, 0.26, 1)
canvas.node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value = 0.94
black = bpy.data.materials.new("HQ23 | radio bakelite and dial glass")
black.diffuse_color = (0.075, 0.083, 0.078, 1)
black.use_nodes = True
black.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (0.07, 0.08, 0.075, 1)
black.node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value = 0.46
materials = [concrete, metal_skin, steel, glass, wood, canvas, black]

created: list[bpy.types.Object] = []

def set_material(obj: bpy.types.Object, mat: bpy.types.Material) -> bpy.types.Object:
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    obj.color = tuple(mat.diffuse_color)
    obj.name = "HQ23 Tower | " + obj.name
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    asset.objects.link(obj)
    created.append(obj)
    return obj

def box(name: str, loc: tuple[float, float, float], size: tuple[float, float, float], mat: bpy.types.Material,
        bevel: float = 0.0) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    set_material(obj, mat)
    if bevel > 0:
        mod = obj.modifiers.new("Small cast edge radius", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    return obj

def beam(name: str, a: tuple[float,float,float], b: tuple[float,float,float], width: float,
         depth: float, mat: bpy.types.Material, bevel: float = 0.0) -> bpy.types.Object:
    va, vb = Vector(a), Vector(b)
    d = vb - va
    obj = box(name, tuple((va + vb) * 0.5), (width, depth, d.length), mat, bevel)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = d.to_track_quat("Z", "Y")
    return obj

def rod(name: str, a: tuple[float,float,float], b: tuple[float,float,float], radius: float,
        mat: bpy.types.Material, sides: int = 10) -> bpy.types.Object:
    va, vb = Vector(a), Vector(b)
    d = vb - va
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=d.length,
                                       location=tuple((va + vb) * 0.5))
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = d.to_track_quat("Z", "Y")
    return set_material(obj, mat)

def pane(name: str, points: list[tuple[float,float,float]], mat: bpy.types.Material) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name + " mesh")
    mesh.from_pydata(points, [], [tuple(range(len(points)))])
    mesh.materials.append(mat)
    mesh.update()
    obj = bpy.data.objects.new("HQ23 Tower | " + name, mesh)
    asset.objects.link(obj)
    created.append(obj)
    return obj

def floor_slab(name: str, height: float, sx: float, sy: float, thickness: float = 0.24) -> None:
    box(name, (0,0,height-thickness/2), (sx,sy,thickness), concrete, 0.045)

# ---------- base and working levels: cast concrete, framed openings, weathering ledges ----------
box("battered concrete plinth with beveled drip edge", (0,0,0.31), (11.4,10.8,0.62), concrete, 0.12)
box("foundation upper reveal", (0,0,0.67), (10.5,9.9,0.18), steel, 0.025)
floor_slab("ground floor solid slab", 0.82, 10.0, 9.3)

# Ground floor shell, with a real south entrance opening for the preserved HQ2.2 animated door.
z0, z1 = 0.92, 4.15
box("south facade left of animated entrance", (-3.00,4.04,(z0+z1)/2), (3.40,0.40,z1-z0), concrete, 0.045)
box("south facade right of animated entrance", (2.02,4.04,(z0+z1)/2), (4.00,0.40,z1-z0), concrete, 0.045)
box("south facade over entrance lintel", (-0.70,4.04,3.43), (1.75,0.40,1.44), concrete, 0.035)
box("east ground wall", (4.46,0,2.55), (0.40,8.15,3.25), concrete, 0.035)
box("west ground wall", (-4.46,0,2.55), (0.40,8.15,3.25), concrete, 0.035)
box("north ground wall", (0,-4.04,2.55), (8.90,0.40,3.25), concrete, 0.035)
for z in (1.04,4.05):
    box("ground story cast string course", (0,0,z), (9.55,8.92,0.14), concrete, 0.025)

# Front vestibule, side office windows and sill/keystone details.
box("entrance reveal shadow", (-0.675,4.264,1.88), (1.68,0.035,2.72), steel, 0.015)
for x in (-3.08,2.07):
    box("ground floor deep-set window shadow", (x,4.253,2.42), (1.18,0.045,1.45), steel, 0.018)
    box("ground floor opaque glass", (x,4.218,2.45), (0.98,0.025,1.22), glass)
    for dx in (-0.51,0.51):
        box("ground floor steel window jamb", (x+dx,4.18,2.44), (0.07,0.12,1.42), steel, 0.014)
    for zz in (1.73,3.14):
        box("ground floor steel sash", (x,4.18,zz), (1.09,0.12,0.07), steel, 0.014)
for x in (-4.42,4.42):
    for y in (-2.75,0.0,2.75):
        box("cast concrete corner pilaster", (x,y,2.55), (0.16,0.18,3.3), concrete, 0.035)

# First operations / weather room level: slightly recessed, strong lintels and a real floor slab.
floor_slab("first floor operations room slab", 4.30, 10.0, 9.3)
z0, z1 = 4.44, 8.05
for x in (-4.45,4.45):
    box("first floor facade wall", (x,0,(z0+z1)/2), (0.38,8.15,z1-z0), concrete, 0.035)
for y in (-4.04,4.04):
    box("first floor facade wall", (0,y,(z0+z1)/2), (8.90,0.38,z1-z0), concrete, 0.035)
for x in (-4.40,4.40):
    for y in (-2.65,0.0,2.65):
        # Narrow 1940s steel-framed observation windows in the weather/radio room.
        box("first-floor inset window dark reveal", (x*1.006,y,6.15), (0.045,1.55,1.75), steel)
        box("first-floor inset glazing", (x*1.002,y,6.15), (0.027,1.34,1.52), glass)
        for dy in (-0.76,0.0,0.76):
            box("first-floor window mullion", (x*1.012,y+dy,6.15), (0.075,0.055,1.70), steel, 0.012)
        for zz in (5.29,6.99):
            box("first-floor window crossbar", (x*1.012,y,zz), (0.075,1.5,0.055), steel, 0.012)
for y in (-4.00,4.00):
    for x in (-2.85,0.0,2.85):
        box("first-floor inset front window shadow", (x,y*1.006,6.15), (1.60,0.045,1.75), steel)
        box("first-floor inset front glazing", (x,y*1.002,6.15), (1.39,0.027,1.52), glass)
        for dx in (-0.79,0.0,0.79):
            box("first-floor front window mullion", (x+dx,y*1.012,6.15), (0.055,0.075,1.70), steel, 0.012)
        for zz in (5.29,6.99):
            box("first-floor front window crossbar", (x,y*1.012,zz), (1.55,0.075,0.055), steel, 0.012)
for z in (4.52,7.98):
    box("first-floor exterior belt course", (0,0,z), (9.75,8.95,0.14), concrete, 0.025)

# Tapered reinforced support shaft: corner piers and inset wall panels rather than a stack of cubes.
floor_slab("tower cab support transfer slab", 8.25, 9.3, 8.7)
for x in (-3.08,3.08):
    for y in (-2.72,2.72):
        beam("tapered reinforced concrete cab pier", (x*1.22,y*1.22,8.30), (x,y,12.50), 0.55,0.58, concrete,0.04)
for z in (8.8,10.0,11.25,12.3):
    for x in (-3.08,3.08):
        box("tower shaft cast belt and rain ledge", (x,0,z), (0.28,5.75,0.13), concrete,0.03)
    for y in (-2.72,2.72):
        box("tower shaft cast belt and rain ledge", (0,y,z), (6.45,0.28,0.13), concrete,0.03)
for x in (-3.07,3.07):
    box("shaft sheltered radio-room infill", (x,0,10.42), (0.20,5.15,3.68), concrete,0.04)
    # High, small windows protect the equipment while admitting daylight.
    box("shaft radio slit dark reveal", (x*1.018,0,10.75), (0.035,1.55,0.85), steel)
    box("shaft radio slit glazing", (x*1.02,0,10.75), (0.025,1.35,0.68), glass)
    box("shaft radio slit cross member", (x*1.03,0,10.75), (0.08,1.45,0.06), steel)
for y in (-2.72,2.72):
    box("shaft side infill", (0,y,10.42), (5.95,0.2,3.68), concrete,0.04)

# Observation deck and undercroft braces.
floor_slab("cantilevered observation cab floor", 12.48, 11.6, 10.2,0.36)
for x in (-4.8,4.8):
    for y in (-4.1,4.1):
        beam("observation deck steel knee brace", (x*0.72,y*0.72,11.55),(x,y,12.34),0.16,0.18,steel,0.018)
for x in (-5.4,5.4):
    for y in (-4.6,4.6):
        box("deck balcony stanchion shoe", (x,y,12.70),(0.18,0.18,0.28),steel,0.025)

# Eight-sided clipped-corner observation cab; large true glazing, fine sash and a deep roof overhang.
cab_z0, cab_z1 = 12.72, 18.12
half_x, half_y, clip = 5.15,4.55,1.05
outline = [(-half_x+clip,-half_y),(half_x-clip,-half_y),(half_x,-half_y+clip),(half_x,half_y-clip),
           (half_x-clip,half_y),(-half_x+clip,half_y),(-half_x,half_y-clip),(-half_x,-half_y+clip)]
center = Vector((0,0))
for idx,(ax,ay) in enumerate(outline):
    bx,by = outline[(idx+1)%len(outline)]
    # Keep each panel plane slightly raked inward toward its head.
    r = (Vector((ax,ay)) + Vector((bx,by))) * 0.5
    inward = (-r.normalized()*0.12) if r.length > 0 else Vector((0,0))
    low_a=(ax,ay,13.55); low_b=(bx,by,13.55)
    top_a=(ax+inward.x,ay+inward.y,17.84); top_b=(bx+inward.x,by+inward.y,17.84)
    pane("slightly raked full-height cab glazing %02d"%idx,[low_a,low_b,top_b,top_a],glass)
    beam("cab window lower steel sill",(ax,ay,13.54),(bx,by,13.54),0.11,0.12,steel,0.012)
    beam("cab window upper steel sash",top_a,top_b,0.09,0.10,steel,0.01)
    # Paired narrow vertical stiles, at each pane end and its midline.
    for t in (0.0,0.5,1.0):
        x=ax+(bx-ax)*t; y=ay+(by-ay)*t
        xt=x+inward.x*t; yt=y+inward.y*t
        beam("slender 1940s observation window stile",(x,y,13.54),(xt,yt,17.84),0.075,0.095,steel,0.01)
    for zz in (14.95,16.45):
        t=(zz-13.54)/(17.84-13.54)
        p1=(ax+inward.x*t,ay+inward.y*t,zz)
        p2=(bx+inward.x*t,by+inward.y*t,zz)
        beam("cab sash cross rail",p1,p2,0.075,0.10,steel,0.01)
    # Masonry corner piers and brass/steel tie plates give the cab a load path.
    box("observation cab clipped corner pier",(ax,ay,13.12),(0.28,0.28,0.92),concrete,0.045)
for z in (12.78,13.52,17.88,18.05):
    # Octagonal perimeter belt; eight independent rods keep the clipped plan visible.
    for i,(ax,ay) in enumerate(outline):
        bx,by=outline[(i+1)%len(outline)]
        rod("cab continuous perimeter metal rail",(ax,ay,z),(bx,by,z),0.052,steel,8)

# Shallow hipped roof: broad eaves, fascia, formed standing seam panels and drainage edge.
box("wide observation cab soffit and eave",(0,0,18.10),(12.65,11.35,0.26),metal_skin,0.055)
roof_base=[(-6.28,-5.63,18.20),(6.28,-5.63,18.20),(6.28,5.63,18.20),(-6.28,5.63,18.20)]
roof_ridge=[(-5.75,-5.05,19.12),(5.75,-5.05,19.12),(5.75,5.05,19.12),(-5.75,5.05,19.12)]
for i in range(4):
    j=(i+1)%4
    pane("shallow hipped sheet-metal roof slope",[roof_base[i],roof_base[j],roof_ridge[j],roof_ridge[i]],metal_skin)
box("raised flat roof inspection deck",(0,0,19.11),(11.5,10.1,0.12),metal_skin,0.035)
for x in (-6.15,6.15):
    box("formed eave drip fascia",(x,0,18.12),(0.10,11.2,0.36),steel,0.025)
for y in (-5.55,5.55):
    box("formed eave drip fascia",(0,y,18.12),(12.3,0.10,0.36),steel,0.025)

# Fully modeled operations-room desk, chart table, analog radios and lamps, visible through the cab.
box("center operations chart table timber top",(0,0,14.40),(4.25,1.65,0.14),wood,0.045)
for x in (-1.8,1.8):
    for y in (-0.62,0.62):
        box("chart table turned leg",(x,y,13.96),(0.11,0.11,0.78),wood,0.025)
box("folded 1944 airfield map",(0,0,14.49),(3.2,1.18,0.035),canvas,0.012)
for x in (-1.24,-0.42,0.42,1.24):
    box("map grid fold and pencilled plot line",(x,0,14.513),(0.018,1.04,0.006),steel)

# Radio desk against the rear quarter, five separate period tube sets with knobs and analog meters.
box("radio console timber bench",(0,-2.75,13.96),(4.65,0.75,0.94),wood,0.035)
box("radio desk steel equipment plinth",(0,-2.75,14.53),(4.65,0.76,0.10),steel,0.025)
for x in (-1.8,-0.9,0.0,0.9,1.8):
    box("1944 tube radio face chassis",(x,-2.40,15.02),(0.68,0.58,0.78),black,0.035)
    # Dial bezels and luminous ivory dial faces.
    bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=0.16,depth=0.045,location=(x,-2.085,15.13),rotation=(math.radians(90),0,0))
    dial=set_material(bpy.context.object,steel); dial.name="HQ23 Tower | machined radio dial bezel"
    bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=0.12,depth=0.049,location=(x,-2.055,15.13),rotation=(math.radians(90),0,0))
    dial_face=set_material(bpy.context.object,canvas); dial_face.name="HQ23 Tower | ivory radio dial face"
    beam("radio meter needle",(x,-2.021,15.13),(x+0.065,-2.021,15.22),0.018,0.018,black)
    for k in range(3):
        bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=0.045,depth=0.06,location=(x-0.18+k*0.18,-2.06,14.89),rotation=(math.radians(90),0,0))
        set_material(bpy.context.object,steel)
box("route coordinator map and signal table",(-2.4,0.25,14.06),(0.62,2.7,0.82),wood,0.03)
for x in (-3.85,3.85):
    box("cab operator bench",(x,0.0,13.92),(0.55,2.4,0.72),wood,0.04)

# Suspended map boards, an analog wind indicator, rotary telephone and period ceiling lamps.
box("wall operations map board",(-2.0,-3.78,16.45),(2.55,0.08,1.32),wood,0.025)
box("folded wall chart",(-2.0,-3.724,16.45),(2.28,0.025,1.08),canvas,0.008)
for x in (-2.72,-2.0,-1.28):
    for z in (16.12,16.43,16.73):
        rod("map route pin",(x,-3.69,z),(x,-3.65,z),0.028,steel,8)
box("wartime field telephone box",(3.92,-2.95,15.38),(0.28,0.30,0.45),black,0.025)
rod("field telephone handset cord",(4.07,-2.8,15.28),(4.07,-2.55,15.1),0.012,steel,6)
for x,y in ((-2.6,2.75),(2.6,2.75),(0.0,-1.25)):
    box("interior ceiling lamp brass canopy",(x,y,17.83),(0.25,0.25,0.09),steel,0.018)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=0.13,location=(x,y,17.67))
    lamp=set_material(bpy.context.object,canvas); lamp.name="HQ23 Tower | frosted incandescent interior lamp"

# Large wraparound observation balcony and low safety rail.
for x in (-5.4,5.4):
    for y in (-4.95,0,4.95):
        box("balcony vertical baluster",(x,y,13.17),(0.065,0.065,1.0),steel,0.012)
for y in (-4.95,4.95):
    for x in (-5.35,0,5.35):
        box("balcony vertical baluster",(x,y,13.17),(0.065,0.065,1.0),steel,0.012)
for z in (13.62,13.75):
    for x in (-5.4,5.4): beam("balcony steel handrail",(x,-4.95,z),(x,4.95,z),0.065,0.065,steel,0.01)
    for y in (-4.95,4.95): beam("balcony steel handrail",(-5.4,y,z),(5.4,y,z),0.065,0.065,steel,0.01)

# Period external steel switchback stair, 4 credible flights with open risers, landings, stringers and rails.
flight_xs=(5.10,7.45,5.10,7.45)
flight_dirs=(1,-1,1,-1)  # positive is toward the north (+Y in Blender)
flight_rise=3.03
flight_run=5.30
steps=18
for fi,(x0,direction) in enumerate(zip(flight_xs,flight_dirs)):
    low=0.45+fi*flight_rise
    y_start=-2.65 if direction>0 else 2.65
    y_end=y_start+direction*flight_run
    tread_depth=flight_run/steps
    for step in range(steps):
        t=(step+0.5)/steps
        yy=y_start+(y_end-y_start)*t
        zz=low+flight_rise*t
        box("open-riser galvanized stair tread",(x0,yy,zz),(1.18,tread_depth*0.88,0.065),metal_skin,0.018)
    for side in (-0.48,0.48):
        beam("stair channel stringer",(x0+side,y_start,low-0.06),(x0+side,y_end,low+flight_rise-0.06),0.13,0.18,steel,0.015)
        # Slim handrail stanchions at 0.75 m spacing.
        for idx in range(8):
            t=idx/7.0
            yy=y_start+(y_end-y_start)*t
            zz=low+flight_rise*t
            box("stair baluster base plate",(x0+side,yy,zz+0.07),(0.16,0.16,0.06),steel,0.012)
            rod("stair guardrail stanchion",(x0+side,yy,zz+0.10),(x0+side,yy,zz+1.0),0.042,steel,8)
        beam("continuous stair handrail",(x0+side,y_start,low+1.02),(x0+side,y_end,low+flight_rise+1.02),0.055,0.055,steel,0.01)
    # Side support frame to the building and two diagonal knees.
    for y in (y_start,y_end):
        beam("external stair wall bracket",(4.48,y,low+flight_rise*((y-y_start)/(y_end-y_start))),(x0-0.62,y,low+flight_rise*((y-y_start)/(y_end-y_start))),0.11,0.12,steel,0.01)
    for k in (0,1):
        t0=0.22+k*0.42
        yy=y_start+(y_end-y_start)*t0
        zz=low+flight_rise*t0
        beam("stair diagonal frame brace",(4.62,yy,zz-1.0),(x0-0.58,yy+direction*0.7,zz-0.04),0.10,0.11,steel,0.01)

# Top landing from final stair to observation balcony; intermediate alternating landings.
for level in range(1,5):
    high=0.45+level*flight_rise
    x=flight_xs[level-1]
    y=-2.65 if level%2==1 else 2.65
    box("switchback stair landing steel deck",((x+4.55)/2,y,high-0.06),(abs(x-4.55)+1.4,1.48,0.13),metal_skin,0.025)
    for xx in (min(x,4.55)+0.10,max(x,4.55)-0.10):
        for yy in (y-0.66,y+0.66):
            rod("stair landing support post",(xx,yy,high-1.25),(xx,yy,high-0.12),0.048,steel,8)
    beam("stair landing outer handrail",(x+0.68,y-0.67,high+0.90),(x+0.68,y+0.67,high+0.90),0.055,0.055,steel,0.01)
    beam("stair landing wall-side guardrail",(4.55,y-0.67,high+0.90),(4.55,y+0.67,high+0.90),0.055,0.055,steel,0.01)
    # Small fixed access doors on the east facade align with every landing.
    box("upper stair landing steel access door",(4.31,y,high-0.98),(0.08,0.96,1.95),metal_skin,0.022)
    box("stair access door frame head",(4.27,y,high+0.05),(0.16,1.18,0.12),steel,0.015)
    rod("stair door lever",(4.19,y-0.30,high-0.98),(4.12,y-0.30,high-0.98),0.035,steel,8)

# Heavy but restrained exterior lamps with metal shades, no extra dynamic lights in the game asset.
for x,y in ((-4.78,4.52),(4.78,4.52),(-4.75,-4.55),(4.75,-4.55)):
    beam("cast wall lamp bracket",(x*0.93,y*0.93,4.85),(x,y,4.85),0.08,0.08,steel,0.012)
    rod("hooded 1940s wall lamp shade",(x,y,4.72),(x,y,4.60),0.17,steel,12)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=6,radius=0.07,location=(x,y,4.58))
    bulb=set_material(bpy.context.object,canvas); bulb.name="HQ23 Tower | warm lamp lens"

# Roof-mounted radio aerials, porcelain insulators, lightning finial and guy cables.
for x in (-4.32,4.32):
    rod("1944 twin-wire radio mast",(x,-3.15,19.14),(x,-3.15,22.65),0.055,steel,12)
    for z in (20.0,21.6,22.48):
        beam("aerial mast crossarm",(x-0.75,-3.15,z),(x+0.75,-3.15,z),0.038,0.038,steel)
        for dx in (-0.62,0.0,0.62):
            bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=6,radius=0.09,location=(x+dx,-3.15,z))
            set_material(bpy.context.object,canvas)
    for dx in (-0.75,0.75):
        beam("roof mast stay cable",(x,-3.15,21.0),(x+dx,-3.15+dx*0.7,19.35),0.018,0.018,steel)
beam("aerial terminal bar",(-4.32,-3.15,22.65),(4.32,-3.15,22.65),0.035,0.035,steel)
rod("earth lightning rod",(0,-4.35,19.15),(0,-4.35,21.0),0.035,steel,8)
for x in (-4.5,4.5):
    rod("porcelain radio terminal",(x,3.7,18.55),(x,3.7,18.9),0.11,canvas,10)
beam("taut aerial feeder wire",(-4.5,3.7,18.88),(4.5,3.7,18.88),0.018,0.018,steel)

# Three external cable runs in insulated conduit, routed down service corners.
for x in (-4.72,4.72):
    rod("vertical insulated tower service conduit",(x,-3.88,0.72),(x,-3.88,12.05),0.038,steel,8)
    for z in (1.0,3.0,5.0,7.0,9.0,11.0):
        box("service conduit fixing clip",(x,-3.88,z),(0.12,0.10,0.07),steel,0.01)
beam("roof cable takeoff",(4.72,-3.88,12.0),(4.32,-3.15,19.12),0.025,0.025,steel)

# Subtle site-specific rain deposits and rust halos at fasteners, only on the tower.
# These are thin geometry accents on the facade, not airfield/terrain wear.
for x in (-4.02,4.02):
    for y in (-3.35,-1.7,1.7,3.35):
        box("window sill underside damp shadow",(x,y,4.40),(0.19,0.07,0.025),steel)
for x in (-4.58,4.58):
    for z in (1.4,2.7,4.9,6.6,9.2,11.4):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=5,radius=0.04,location=(x*1.01,2.2,z))
        set_material(bpy.context.object,steel)

# Pack maps into the editable source; GLB embeds the same shared PBR maps.
for image in bpy.data.images:
    if image.source == "FILE" and image.filepath:
        image.filepath = os.path.abspath(bpy.path.abspath(image.filepath))
        image.pack()

# Join static geometry by material to keep mobile draw submissions low while
# preserving one clean glass surface set and coherent PBR materials.
bpy.ops.object.select_all(action="DESELECT")
for obj in created:
    if obj.name in bpy.data.objects:
        obj.select_set(True)
for mat in materials:
    group=[o for o in asset.objects if o.type=="MESH" and any(m==mat for m in o.data.materials)]
    if not group:
        continue
    bpy.ops.object.select_all(action="DESELECT")
    for obj in group: obj.select_set(True)
    bpy.context.view_layer.objects.active=group[0]
    if len(group)>1:
        bpy.ops.object.join()
    joined=bpy.context.object
    joined.name="HQ23 Tower | Combined | "+mat.name.split("|")[-1].strip()
    for p in joined.data.polygons: p.use_smooth = False
    joined.select_set(False)

# Authoring metadata and pack all images for a self-contained source.
scene.render.image_settings.file_format="PNG"
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=GLB,export_format="GLB",export_apply=True,export_image_format="AUTO",export_materials="EXPORT",export_cameras=False,export_lights=False)

# Mobile LOD exports share the same embedded material set. The high-quality
# source remains untouched; decimation only affects temporary export copies.
lod_collection=bpy.data.collections.new("TEMPORARY GENERATED LOD COPIES")
scene.collection.children.link(lod_collection)
high_meshes=[o for o in asset.objects if o.type=="MESH"]
lod_materials={}
for source_material in materials:
    lod_material=bpy.data.materials.new(source_material.name+" | mobile flat-color LOD")
    lod_material.diffuse_color=source_material.diffuse_color
    lod_material.use_nodes=True
    lod_bsdf=lod_material.node_tree.nodes.get("Principled BSDF")
    source_bsdf=source_material.node_tree.nodes.get("Principled BSDF") if source_material.use_nodes else None
    lod_bsdf.inputs["Base Color"].default_value=source_material.diffuse_color
    if source_bsdf is not None:
        lod_bsdf.inputs["Metallic"].default_value=source_bsdf.inputs["Metallic"].default_value
        lod_bsdf.inputs["Roughness"].default_value=source_bsdf.inputs["Roughness"].default_value
        lod_bsdf.inputs["Alpha"].default_value=source_bsdf.inputs["Alpha"].default_value
    if source_material.diffuse_color[3] < 0.99:
        lod_material.surface_render_method="DITHERED"
    lod_materials[source_material.name]=lod_material
for lod_index, ratio in ((1,0.55),(2,0.24)):
    copies=[]
    for source_obj in high_meshes:
        clone=source_obj.copy()
        clone.data=source_obj.data.copy()
        lod_collection.objects.link(clone)
        clone.name="HQ23 Tower LOD%d | %s"%(lod_index,source_obj.name)
        for slot_index, source_material in enumerate(list(clone.data.materials)):
            if source_material.name in lod_materials:
                clone.data.materials[slot_index]=lod_materials[source_material.name]
        bpy.ops.object.select_all(action="DESELECT")
        clone.select_set(True)
        bpy.context.view_layer.objects.active=clone
        for modifier in list(clone.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        decimate=clone.modifiers.new("mobile LOD %d polygon reduction"%lod_index,"DECIMATE")
        decimate.ratio=ratio
        bpy.ops.object.modifier_apply(modifier=decimate.name)
        # Decimation can collapse coincident surfaces around the joined stair
        # and frame parts. Remove duplicate/degenerate faces before export;
        # the returned mesh is the cleaned LOD asset.
        clone.data.validate(verbose=False, clean_customdata=True)
        clone.select_set(False)
        copies.append(clone)
    bpy.ops.object.select_all(action="DESELECT")
    for clone in copies: clone.select_set(True)
    bpy.context.view_layer.objects.active=copies[0]
    lod_path=os.path.join(OUTPUT,"Control_Tower_HQ_23_LOD%d.glb"%lod_index)
    bpy.ops.export_scene.gltf(filepath=lod_path,export_format="GLB",use_selection=True,export_apply=True,export_image_format="AUTO",export_materials="EXPORT",export_cameras=False,export_lights=False)
    for clone in copies:
        bpy.data.objects.remove(clone,do_unlink=True)
bpy.data.collections.remove(lod_collection)

# Camera previews from authentic asset geometry. Keep editable, reproducible render setup in source only.
def aim(obj, point): obj.rotation_euler=(Vector(point)-obj.location).to_track_quat("-Z","Y").to_euler()
def render_preview(filename, loc, target, focal=54):
    cam_data=bpy.data.cameras.new("Preview Camera")
    cam=bpy.data.objects.new("Preview Camera",cam_data)
    scene.collection.objects.link(cam)
    cam.location=loc; aim(cam,target); cam_data.lens=focal; scene.camera=cam
    light_data=bpy.data.lights.new("Large softbox",type="AREA")
    light=bpy.data.objects.new("Large softbox",light_data); scene.collection.objects.link(light)
    light.location=(18,-22,31); light_data.energy=5600; light_data.shape="DISK"; light_data.size=17; aim(light,(0,0,9))
    light_data2=bpy.data.lights.new("Facade fill",type="AREA")
    fill=bpy.data.objects.new("Facade fill",light_data2); scene.collection.objects.link(fill)
    fill.location=(-16,14,18); light_data2.energy=2600; light_data2.shape="DISK"; light_data2.size=12; aim(fill,(0,0,8))
    scene.render.filepath=os.path.join(OUTPUT,filename)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam,do_unlink=True); bpy.data.cameras.remove(cam_data)
    bpy.data.objects.remove(light,do_unlink=True); bpy.data.lights.remove(light_data)
    bpy.data.objects.remove(fill,do_unlink=True); bpy.data.lights.remove(light_data2)

scene.view_settings.view_transform="AgX"
scene.view_settings.look="AgX - Medium High Contrast"
scene.view_settings.exposure=0.65
scene.render.resolution_percentage=100
render_preview("Control_Tower_HQ_23_blender.png",(24,32,24),(0,0,10),46)
render_preview("Control_Tower_HQ_23_interieur_blender.png",(0.2,-0.9,16.15),(-1.6,-4.2,15.35),38)

print("HQ23_TOWER_BUILD_COMPLETE",GLB,BLEND)
print("mesh_objects",sum(1 for o in asset.objects if o.type=="MESH"),"faces",sum(len(o.data.polygons) for o in asset.objects if o.type=="MESH"))
