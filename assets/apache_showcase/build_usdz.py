"""Package the animated mobile GLB as a static iPhone Quick Look USDZ.
Requires Python packages usd-core and pygltflib. Run with python build_usdz.py.
The source GLB retains animation; USDZ is the static Quick Look presentation.
"""
import json, struct, zipfile, shutil, tempfile, re
from pathlib import Path
from pxr import Usd, UsdGeom, UsdShade, Sdf, Gf, Vt, Tf

ROOT=Path(__file__).resolve().parent
src=ROOT/'Apache_Showcase_Mobile.glb'
out=ROOT/'Apache_Showcase_iPhone.usdz'
b=src.read_bytes(); jlen=struct.unpack_from('<I',b,12)[0]; doc=json.loads(b[20:20+jlen]); blob=b[20+jlen+8:]

def accessor(i):
 a=doc['accessors'][i]; bv=doc['bufferViews'][a['bufferView']]; off=bv.get('byteOffset',0)+a.get('byteOffset',0); comps={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]; fmt={5120:'b',5121:'B',5122:'h',5123:'H',5125:'I',5126:'f'}[a['componentType']]; size=struct.calcsize('<'+fmt); stride=bv.get('byteStride',comps*size); vals=[]
 for k in range(a['count']): vals.append(struct.unpack_from('<'+fmt*comps,blob,off+k*stride))
 return vals

def safe(s): return Tf.MakeValidIdentifier(s or 'Part')

tmp=Path(tempfile.mkdtemp(prefix='apache_usdz_')); (tmp/'textures').mkdir(); stage_path=tmp/'Apache_Showcase_iPhone.usda'
stage=Usd.Stage.CreateNew(str(stage_path)); UsdGeom.SetStageUpAxis(stage,UsdGeom.Tokens.y); UsdGeom.SetStageMetersPerUnit(stage,1.0)
root=UsdGeom.Xform.Define(stage,'/ApacheShowcase'); stage.SetDefaultPrim(root.GetPrim())
# unpack embedded image bytes
image_paths=[]
for i,img in enumerate(doc.get('images',[])):
 bv=doc['bufferViews'][img['bufferView']]; data=blob[bv.get('byteOffset',0):bv.get('byteOffset',0)+bv['byteLength']]; ext='jpg' if img.get('mimeType')=='image/jpeg' else 'png'; p=tmp/'textures'/f'texture_{i}.{ext}'; p.write_bytes(data); image_paths.append(p)
# materials
materials=[]
for i,mat in enumerate(doc.get('materials',[])):
 path=Sdf.Path(f'/ApacheShowcase/Materials/Mat_{i}'); m=UsdShade.Material.Define(stage,path); sh=UsdShade.Shader.Define(stage,path.AppendChild('PreviewSurface')); sh.CreateIdAttr('UsdPreviewSurface')
 pbr=mat.get('pbrMetallicRoughness',{}); factor=pbr.get('baseColorFactor',[1,1,1,1]); sh.CreateInput('diffuseColor',Sdf.ValueTypeNames.Color3f).Set(Gf.Vec3f(*factor[:3])); sh.CreateInput('metallic',Sdf.ValueTypeNames.Float).Set(pbr.get('metallicFactor',0.0)); sh.CreateInput('roughness',Sdf.ValueTypeNames.Float).Set(pbr.get('roughnessFactor',1.0)); sh.CreateInput('opacity',Sdf.ValueTypeNames.Float).Set(factor[3]); m.CreateSurfaceOutput().ConnectToSource(sh.ConnectableAPI(),'surface')
 texinfo=pbr.get('baseColorTexture')
 if texinfo:
  image=doc['textures'][texinfo['index']]['source']; tex=UsdShade.Shader.Define(stage,path.AppendChild('BaseColorTexture')); tex.CreateIdAttr('UsdUVTexture'); tex.CreateInput('file',Sdf.ValueTypeNames.Asset).Set(Sdf.AssetPath('textures/'+image_paths[image].name)); tex.CreateInput('st',Sdf.ValueTypeNames.Float2).ConnectToSource(UsdShade.Shader.Get(stage,path).CreateInput('st',Sdf.ValueTypeNames.Float2)) if False else None
  uv=UsdShade.Shader.Define(stage,path.AppendChild('PrimvarReader_st')); uv.CreateIdAttr('UsdPrimvarReader_float2'); uv.CreateInput('varname',Sdf.ValueTypeNames.Token).Set('st'); tex.CreateInput('st',Sdf.ValueTypeNames.Float2).ConnectToSource(uv.ConnectableAPI(),'result'); sh.GetInput('diffuseColor').ConnectToSource(tex.ConnectableAPI(),'rgb')
 materials.append(m)
# Build local transforms and mesh data on node hierarchy.
nodes=doc['nodes']; parents={}
for pi,n in enumerate(nodes):
 for ch in n.get('children',[]): parents[ch]=pi
paths={}
def node_path(i):
 if i in paths:return paths[i]
 n=nodes[i]; par=parents.get(i); base=safe(n.get('name',f'Node_{i}'))
 p=(node_path(par) if par is not None else Sdf.Path('/ApacheShowcase')).AppendChild(f'{base}_{i}')
 paths[i]=p; return p
for i,n in enumerate(nodes):
 p=node_path(i); xf=UsdGeom.Xform.Define(stage,p); prim=xf.GetPrim(); xfable=UsdGeom.Xformable(prim)
 if n.get('matrix'):
  # glTF matrices are column-major, USD Gf.Matrix4d rows
  a=n['matrix']; mat=Gf.Matrix4d(*[a[r+4*c] for r in range(4) for c in range(4)]); xfable.AddTransformOp().Set(mat)
 else:
  t=n.get('translation',[0,0,0]); q=n.get('rotation',[0,0,0,1]); sc=n.get('scale',[1,1,1]); xfable.AddTranslateOp().Set(Gf.Vec3d(*t)); xfable.AddOrientOp().Set(Gf.Quatf(q[3],Gf.Vec3f(*q[:3]))); xfable.AddScaleOp().Set(Gf.Vec3d(*sc))
 mi=n.get('mesh')
 if mi is None:continue
 for pi,primdoc in enumerate(doc['meshes'][mi]['primitives']):
  attrs=primdoc['attributes']; pos=accessor(attrs['POSITION']); idx=accessor(primdoc['indices']); indices=[v[0] for v in idx]; counts=[3]*(len(indices)//3); meshpath=p.AppendChild(f'Mesh_{pi}'); mesh=UsdGeom.Mesh.Define(stage,meshpath); mesh.CreatePointsAttr(Vt.Vec3fArray([Gf.Vec3f(*v[:3]) for v in pos])); mesh.CreateFaceVertexCountsAttr(Vt.IntArray(counts)); mesh.CreateFaceVertexIndicesAttr(Vt.IntArray(indices)); mesh.CreateSubdivisionSchemeAttr(UsdGeom.Tokens.none)
  if 'NORMAL' in attrs: mesh.CreateNormalsAttr(Vt.Vec3fArray([Gf.Vec3f(*v[:3]) for v in accessor(attrs['NORMAL'])])); mesh.SetNormalsInterpolation(UsdGeom.Tokens.vertex)
  if 'TEXCOORD_0' in attrs:
   uv=UsdGeom.PrimvarsAPI(mesh).CreatePrimvar('st',Sdf.ValueTypeNames.TexCoord2fArray,UsdGeom.Tokens.vertex); uv.Set(Vt.Vec2fArray([Gf.Vec2f(v[0],1-v[1]) for v in accessor(attrs['TEXCOORD_0'])]))
  matidx=primdoc.get('material')
  if matidx is not None and matidx<len(materials): UsdShade.MaterialBindingAPI(mesh.GetPrim()).Bind(materials[matidx])
stage.GetRootLayer().Save(); stage=None
# USDZ: uncompressed ZIP, with every file payload aligned to 64 bytes.
files=[stage_path]+sorted((tmp/'textures').iterdir())
with open(out,'wb') as raw:
 with zipfile.ZipFile(raw,'w',compression=zipfile.ZIP_STORED) as z:
  for f in files:
   name=f.relative_to(tmp).as_posix(); info=zipfile.ZipInfo(name); info.compress_type=zipfile.ZIP_STORED
   offset=raw.tell(); pad=(-((offset+30+len(name.encode()))%64))%64
   if pad and pad<4: pad+=64
   if pad: info.extra=struct.pack('<HH',0x1986,pad-4)+bytes(pad-4)
   z.writestr(info,f.read_bytes())
# Validate archive and OpenUSD package loading.
with zipfile.ZipFile(out) as z:
 assert z.testzip() is None
 assert z.namelist()[0].endswith('.usda')
s=Usd.Stage.Open(str(out)); assert s and len(list(s.Traverse()))>10
print(f'created {out} ({out.stat().st_size} bytes), prims={len(list(s.Traverse()))}')
shutil.rmtree(tmp)
