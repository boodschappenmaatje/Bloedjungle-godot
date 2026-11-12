"""Meshy-begroeiing, stap 1: een zwaar Meshy-model (6 tot 8 miljoen driehoeken, door Dennis gemaakt) terugbrengen tot de
meester van ~40.000 driehoeken. Dubbele punten samenvoegen, daarna in stappen (hoogstens 5x per stap) met 'collapse'
decimeren. De UV's en de originele texturen blijven zoals Meshy ze maakte: het blad blijft scherp.
Gebruik: python3 stap1_verklein.py <invoer.glb> <uitvoer.glb> <doel-driehoeken>   (ca. 4 minuten voor 7 miljoen, 9 GB geheugen)"""
import bpy, sys, time
IN=sys.argv[-3]; OUTP=sys.argv[-2]; target=int(sys.argv[-1])
t0=time.time()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN)
ob=[o for o in bpy.context.scene.objects if o.type=='MESH'][0]
bpy.context.view_layer.objects.active=ob; ob.select_set(True)
n=len(ob.data.polygons); print('start',n,round(time.time()-t0),'s',flush=True)
# stap 1: dubbele punten samenvoegen (Meshy-puin is vaak los), dan in stappen decimeren
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.remove_doubles(threshold=0.00002); bpy.ops.object.mode_set(mode='OBJECT')
print('na dubbelen',len(ob.data.polygons),round(time.time()-t0),'s',flush=True)
cur=len(ob.data.polygons)
while cur>target*1.03:
    step=max(target/cur, 0.2)
    m=ob.modifiers.new('d','DECIMATE'); m.decimate_type='COLLAPSE'; m.ratio=step; m.use_collapse_triangulate=True
    bpy.ops.object.modifier_apply(modifier='d')
    cur=len(ob.data.polygons); print('stap ->',cur,round(time.time()-t0),'s',flush=True)
bpy.ops.export_scene.gltf(filepath=OUTP,export_format='GLB',export_image_format='JPEG',export_jpeg_quality=88)
print('klaar',round(time.time()-t0),'s',flush=True)
