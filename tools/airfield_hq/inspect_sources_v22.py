import bpy, json, os
from mathutils import Vector
root=os.path.abspath(os.path.join(os.path.dirname(__file__),'../..'))
for rel in ['assets/bunker/high_quality/Bloedjungle_Bunker_HQ_Source.blend','assets/airfield_hq_v21/high_quality/Bloedjungle_Airfield_HQ_2_1_Source.blend']:
    bpy.ops.wm.open_mainfile(filepath=os.path.join(root,rel))
    print('SOURCE',rel)
    for c in bpy.data.collections:
        obs=[o for o in c.objects if o.type=='MESH']
        if not obs:continue
        mins=[1e12]*3;maxs=[-1e12]*3
        for o in obs:
            for p in o.bound_box:
                v=o.matrix_world@Vector(p)
                for i in range(3):mins[i]=min(mins[i],v[i]);maxs[i]=max(maxs[i],v[i])
        print('COLLECTION',c.name,len(obs),'bounds',tuple(round(x,2) for x in mins),tuple(round(x,2) for x in maxs),'samples',[o.name for o in obs[:14]])
    print('ACTIONS',[a.name for a in bpy.data.actions])
    print('MATERIALS',[m.name for m in bpy.data.materials[:30]])
    if 'airfield' in rel:
        for name in ['Hangar sliding door LEFT','Hangar sliding door RIGHT','Main landing runway','Taxiway','Hangar apron','Continuous hangar reinforced concrete floor','Compacted base around field']:
            o=bpy.data.objects.get(name)
            if o:print('OBJECT',name,'location',tuple(round(v,2) for v in o.location),'dimensions',tuple(round(v,2) for v in o.dimensions),'bounds',[(round(min(v[i] for v in (o.matrix_world@Vector(p) for p in o.bound_box)),2),round(max(v[i] for v in (o.matrix_world@Vector(p) for p in o.bound_box)),2)) for i in range(3)],'mats',[m.name for m in o.data.materials])
