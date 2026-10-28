import * as THREE from 'three';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {RoomEnvironment} from 'three/addons/environments/RoomEnvironment.js';

const $=id=>document.getElementById(id), stage=$('stage'), canvas=$('canvas');
const names={kazerne:'Kazerne',wachttoren:'Wachttoren',legerjeep:'Legerjeep',jeep:'Speelbare jeep',auto:'Personenauto',bus:'Stadsbus',straaljager:'Straaljager (napalm)',soldaat:'Soldaat (mannetjes)',wapens:'Wapens (bewegende delen)',jungle:'Jungle (palmen en rotsen)',props:'Props (zandzakken en kisten)',wachtpost:'Poortwachtpost (slagboom en wachthuis)',generator:'Generator (heel en wrak)'};
const NEW_ONLY=['jeep','auto','bus','straaljager','wapens','jungle','props','wachtpost','generator'];
// wapens: alle wapens staan in één glb op dezelfde plek (oorsprong = rechterhand); de keuzelijst laat er één zien. Clips heten <wapen>_schot / <wapen>_leeg.
const GUN_NODES=['M1911','Thompson','Garand','Trench','MG42','Bazooka','Huls','Raket'];
function applyGun(){
 if($('asset').value!=='wapens'||!slots.v2)return;const g=$('gun').value;
 slots.v2.root.traverse(o=>{if(GUN_NODES.includes(o.name))o.visible=o.name===g;});
 bounds.makeEmpty();slots.v2.root.traverse(o=>{if(o.isMesh&&o.visible&&GUN_NODES.every(n=>n===g||!isUnder(o,n)))bounds.expandByObject(o);});
 setCamera(false);setupClips();stats();dirty=true;
}
// jungle: palmen en rotsen staan in één glb op de oorsprong; de keuzelijst laat er één zien. Geen clips: de wind is een Godot-shader.
const JUNGLE_NODES=['Palm1','Palm1_far','Palm2','Palm2_far','Palm3','Palm3_far','Rots1','Rots2','Rots3','Boom1','Boom1_far','Boom2','Boom2_far','Stomp1','Stomp2'];
function applyJungle(){
 if($('asset').value!=='jungle'||!slots.v2)return;const g=$('plant').value;
 slots.v2.root.traverse(o=>{if(JUNGLE_NODES.includes(o.name))o.visible=o.name===g;});
 // zonder de Godot-shaders: vaste schors- en bladkleur, rotsen houden hun vertexkleuren (steen en mos)
 slots.v2.root.traverse(o=>{if(!o.isMesh)return;for(const m of [].concat(o.material)){if(m.name.startsWith('Palm_Stam')||m.name.startsWith('Boom_Stam')){m.vertexColors=false;m.color.set(0x5a4030);m.needsUpdate=true;}else if(m.name.startsWith('Boom_Liaan')){m.vertexColors=false;m.color.set(0x2c4a1c);m.side=THREE.DoubleSide;m.needsUpdate=true;}else if(m.name.startsWith('Palm_Blad')||m.name.startsWith('Boom_Blad')){m.vertexColors=false;m.color.set(0x3b6a2a);m.side=THREE.DoubleSide;m.needsUpdate=true;}}});
 // stronken: de vertexkleuren (schors, licht hout op de breuk) blijven zichtbaar, op een eigen kopie van het schorsmateriaal
 slots.v2.root.traverse(o=>{if(o.isMesh&&o.name.startsWith('Stomp')&&!o.userData.stumpMat){o.material=[].concat(o.material)[0].clone();o.material.vertexColors=true;o.material.color.set(0xffffff);o.material.needsUpdate=true;o.userData.stumpMat=true;}});
 bounds.makeEmpty();slots.v2.root.traverse(o=>{if(o.isMesh&&o.visible&&isUnder(o,g))bounds.expandByObject(o);});
 setCamera(false);stats();dirty=true;
}
// props: zandzakken en kisten staan in één glb op de oorsprong; de keuzelijst laat er één zien. Geen clips.
const PROP_NODES=['Zandzak1','Zandzak2','Zandzak3','Kist_Hout','Kist_Munitie'];
function applyProp(){
 if($('asset').value!=='props'||!slots.v2)return;const g=$('prop').value;
 slots.v2.root.traverse(o=>{if(PROP_NODES.includes(o.name))o.visible=o.name===g;});
 bounds.makeEmpty();slots.v2.root.traverse(o=>{if(o.isMesh&&o.visible&&isUnder(o,g))bounds.expandByObject(o);});
 setCamera(false);stats();dirty=true;
}
// wachtpost: slagboom (clip Open) en wachthuis staan in één glb; de keuzelijst toont beide of één van de twee.
const POST_NODES=['Slagboom','Wachthuis'];
function applyWachtpost(){
 if($('asset').value!=='wachtpost'||!slots.v2)return;const g=$('post').value;
 slots.v2.root.traverse(o=>{if(POST_NODES.includes(o.name))o.visible=g==='beide'||o.name===g;});
 bounds.makeEmpty();slots.v2.root.traverse(o=>{if(o.isMesh&&o.visible&&POST_NODES.some(n=>isUnder(o,n)&&(g==='beide'||g===n)))bounds.expandByObject(o);});
 setCamera(false);stats();dirty=true;
}
// generator: heel model (clip Draaien: de ventilator) en het gebrande wrak staan in één glb; de keuzelijst toont beide of één van de twee.
const GEN_NODES=['Generator','Wrak'];
function applyGenerator(){
 if($('asset').value!=='generator'||!slots.v2)return;const g=$('gen').value;
 slots.v2.root.traverse(o=>{if(GEN_NODES.includes(o.name))o.visible=g==='beide'||o.name===g;});
 bounds.makeEmpty();slots.v2.root.traverse(o=>{if(o.isMesh&&o.visible&&GEN_NODES.some(n=>isUnder(o,n)&&(g==='beide'||g===n)))bounds.expandByObject(o);});
 setCamera(false);stats();dirty=true;
}
function shown(o){for(let p=o;p;p=p.parent)if(!p.visible)return false;return true;}
function isUnder(o,name){for(let p=o;p;p=p.parent)if(p.name===name)return true;return false;}
const GRASS=['grass_short','grass_medium','grass_tall'];
Object.assign(names,{grass_short:'Kort 3D-gras',grass_medium:'Middelhoog 3D-gras',grass_tall:'Hoog 3D-gras'});
const DAMAGED=['auto','bus'];
// soldaat: V1 = oude pop, VQ2 = realistisch lichaam; zelfde skelet en clips. Looks = SoldierModel.LOOKS in Godot.
const FILES={soldaat:{v1:'soldaat.glb',v2:'soldaat_vq2.glb'}};
const EXTRA_CLIPS={soldaat:['klimmen.glb','zitten.glb','acties.glb']};
const LOOKS={eigen:['Lijf_Uniform','Helm','Vest','Koppel','Rugzak','Laarzen'],'speler:jungle':['Lijf_Uniform','Hoofdband','Koppel','Laarzen'],'speler:bloot':['Lijf_Bloot','Hoofdband','Koppel','Laarzen'],'speler:mouwloos':['Lijf_Mouwloos','Hoofdband','Koppel','Laarzen'],'speler:uniform':['Lijf_Uniform','Hoofdband','Koppel','Laarzen'],'speler:vest':['Lijf_Uniform','Hoofdband','Vest','Koppel','Laarzen'],'vijand:knife':['Lijf_Vijand','Bandana','Laarzen_V'],'vijand:rifle':['Lijf_Vijand','Boonie','Borsttuig','Laarzen_V'],'vijand:rocket':['Lijf_Vijand','Pet','Raketzak','Laarzen_V'],'vijand:heavy':['Lijf_Vijand','Staalhelm','Patroongordels','Laarzen_V']};
const LOOK_COLOR={eigen:'5a6a36','speler:jungle':'4b5a2c','speler:bloot':'4b5a2c','speler:mouwloos':'4b5a2c','speler:uniform':'4b5a2c','speler:vest':'4b5a2c','vijand:knife':'4c5056','vijand:rifle':'8c7b52','vijand:rocket':'5a4a3a','vijand:heavy':'3e4a2b'};
const ALL_PARTS=new Set(Object.values(LOOKS).flat());
// zelfde formule als SoldierModel.uniform_tint()
function uniformTint(hex){const c=[0,2,4].map(i=>parseInt(hex.slice(i,i+2),16)/255);const mx=Math.max(...c,1e-3);const lum=.3*c[0]+.59*c[1]+.11*c[2];const k=.42*Math.min(Math.max(mx/.35,.45),1);return c.map(v=>(lum/mx+(v/mx-lum/mx)*.85)*k);}
function glbPath(asset,v){const f=FILES[asset];return f?`../../assets/${f[v]}`:`../../assets/${v==='v1'?'vq2_baseline/':''}${asset}.glb`;}
function applyLook(){
 if($('asset').value!=='soldaat')return;const look=$('look').value,keep=new Set(LOOKS[look]);
 for(const [v,slot] of Object.entries(slots))slot.root.traverse(o=>{
  if(o.name==='Icosphere')o.visible=false;
  if(v==='v2'&&ALL_PARTS.has(o.name))o.visible=keep.has(o.name);
  if(!o.isMesh)return;
  for(const m of [].concat(o.userData.original)){
   if(m.name?.endsWith('_Kleding')){const t=uniformTint(LOOK_COLOR[look]);m.color.setRGB(t[0],t[1],t[2],THREE.SRGBColorSpace);}
   if(m.name==='Hoofdband')m.color.setRGB(.75,.08,.06,THREE.SRGBColorSpace);
   if(v==='v1'&&m.name==='M_Main'){const t=LOOK_COLOR[look];m.color.setRGB(parseInt(t.slice(0,2),16)/255,parseInt(t.slice(2,4),16)/255,parseInt(t.slice(4,6),16)/255,THREE.SRGBColorSpace);}
  }});
 shading();stats();dirty=true;
}
// per model: onderdelen die bij schadefases veranderen, waar het vuur begint en wat er bij de ontploffing wegvliegt
const CFG={
 auto:{parts:['Voorruit','Achterruit','DeurLV','DeurRV','DeurLA','DeurRA','Motorkap','Kofferklep','Wiel_LV','Wiel_RV','Wiel_LA','Wiel_RA'],
  phases:[[],[['Voorruit','Achterruit'],['Wiel_LV'],0,.55,0],[['DeurRV','DeurLA'],['Wiel_RA'],.6,.85,0],[[],['Wiel_RV'],0,1,0],[['DeurLV','DeurRA'],[],0,1,0]],hood:'Motorkap',hoodSign:1,rim:.335,flatK:.84,
  anchor:[0,1,-1.4],cabin:[0,.35,-.15],flames:[46,14],smoke:[30,20],boom:{n:46,s:34,ring:16,flash:160,fl:16,debris:[['DeurLV',[-6,6,1.2],[2,5,3]],['DeurRA',[5,7,-2],[-3,2,6]],['DeurRV',[6,5,2.5],[4,-3,2]],['DeurLA',[-5,5.5,-3],[-2,6,-4]],['Motorkap',[.5,10,-1],[7,1,2]],['Kofferklep',[-.5,8,2],[-5,1,1]],['Wiel_RV',[3,7,-5],[9,0,0]],['Wiel_LA',[-2,6,5],[-8,0,0]]],burnFlat:['Wiel_LV','Wiel_RA'],glass:['Voorruit','Achterruit']}},
 bus:{parts:['Voorruit','Achterruit','RuitenL','RuitenR','DeurVA','DeurVB','DeurMA','DeurMB','Motorluik','DakluikV','DakluikA','Airco','Wiel_LV','Wiel_RV','Wiel_LA','Wiel_RA'],
  phases:[[],[['Voorruit','RuitenL','DakluikV'],['Wiel_LV'],0,.5,0],[['Achterruit','RuitenR','DeurVB'],['Wiel_RA'],0,.8,0],[['DeurMA','DakluikA'],['Wiel_RV'],1,1,0],[['DeurVA','DeurMB'],[],0,1,0]],hood:'Motorluik',hoodSign:-1,rim:.5,flatK:.88,
  anchor:[0,1.4,-5.3],cabin:[0,1.6,1.6],flames:[70,18],smoke:[36,24],boom:{n:110,s:70,ring:24,flash:420,fl:34,debris:[['DeurVA',[7,8,5],[2,5,3]],['DeurVB',[6,7,4],[-3,2,6]],['DeurMA',[8,6,-1],[4,-3,2]],['DeurMB',[7,7,-3],[-2,6,-4]],['Motorluik',[.5,11,-5],[7,1,2]],['Airco',[-1,13,1],[3,2,5]],['DakluikV',[2,12,6],[6,1,2]],['DakluikA',[-3,12,-3],[-5,3,1]],['Wiel_RV',[5,9,-6],[9,0,0]],['Wiel_LA',[-5,8,6],[-8,0,0]],['Wiel_RA',[6,10,2],[7,0,1]]],burnFlat:['Wiel_LV'],glass:['Voorruit','Achterruit','RuitenL','RuitenR']}}
};
const loader=new GLTFLoader();
let renderer;
try {renderer=new THREE.WebGLRenderer({canvas,antialias:true,alpha:false,powerPreference:'low-power'});}
catch(error){$('loading').textContent='WebGL is niet beschikbaar. Open deze pagina rechtstreeks in Safari en controleer of WebGL is ingeschakeld.';throw error;}
renderer.setPixelRatio(Math.min(devicePixelRatio,1.75));
renderer.outputColorSpace=THREE.SRGBColorSpace;
renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1;
renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
const pmrem=new THREE.PMREMGenerator(renderer);
const room=new RoomEnvironment();const env=pmrem.fromScene(room,.04).texture;room.dispose();pmrem.dispose();
const camera=new THREE.PerspectiveCamera(45,1,.05,250);
const controls=new OrbitControls(camera,canvas);controls.enableDamping=true;controls.dampingFactor=.09;
controls.minDistance=1;controls.maxDistance=65;controls.maxPolarAngle=Math.PI*.49;
let slots={},bounds=new THREE.Box3(),dirty=true,playing=false,rotating=false,request=0,report=null,materials=[];
let clipName='',clipDuration=0;
controls.addEventListener('change',()=>dirty=true);
const clock=new THREE.Clock();

function makeSlot(gltf){
 let wrakMaterial=null;gltf.scene.traverse(o=>{if(o.isMesh&&o.name.startsWith('WrakRef')){wrakMaterial=o.material;o.visible=false;}});
 const scene=new THREE.Scene();scene.background=new THREE.Color('#374138');scene.environment=env;
 const hemi=new THREE.HemisphereLight(0xdce5f1,0x444b2b,2);scene.add(hemi);
 const sun=new THREE.DirectionalLight(0xffedcb,3.2);sun.position.set(-5,10,6);sun.castShadow=true;
 sun.shadow.mapSize.set(1024,1024);sun.shadow.camera.left=-10;sun.shadow.camera.right=10;sun.shadow.camera.top=10;sun.shadow.camera.bottom=-10;sun.shadow.normalBias=.02;scene.add(sun);
 const floor=new THREE.Mesh(new THREE.PlaneGeometry(200,200),new THREE.MeshStandardMaterial({color:0x414b39,roughness:1}));
 floor.rotation.x=-Math.PI/2;floor.position.y=GRASS.includes($('asset').value)?-.004:-.16;floor.receiveShadow=true;scene.add(floor);
 if(GRASS.includes($('asset').value)){hemi.intensity=1.1;sun.intensity=2.2;sun.shadow.normalBias=.004;floor.material.color.set(0x453d27);}
 gltf.scene.traverse(o=>{if(o.isMesh){o.castShadow=true;o.receiveShadow=true;o.userData.original=o.material;}});
 scene.add(gltf.scene);
 return {scene,root:gltf.scene,mixer:new THREE.AnimationMixer(gltf.scene),clips:gltf.animations,action:null,wrakMaterial};
}

function disposeSlots(old){
 for(const slot of Object.values(old)){
  slot.mixer.stopAllAction();slot.mixer.uncacheRoot(slot.root);
  slot.scene.traverse(o=>{if(!o.isMesh)return;o.geometry.dispose();if(o.userData.inspection)for(const m of [].concat(o.material))m.dispose();for(const m of [].concat(o.userData.original||o.material)){for(const v of Object.values(m))if(v?.isTexture&&v!==env)v.dispose();m.dispose();}});
 }
}

async function load(){
 const current=++request,asset=$('asset').value;
 playing=false;$('play').textContent='Afspelen';$('loading').hidden=false;$('loading').textContent='Echte GLB-materialen laden…';
 $('version').disabled=NEW_ONLY.includes(asset);
 if(NEW_ONLY.includes(asset))$('version').value='v2';
 $('phase-row').hidden=!DAMAGED.includes(asset);
 $('grass-row').hidden=!GRASS.includes(asset);
 const versions=NEW_ONLY.includes(asset)?['v2']:['v1','v2'];
 try{
  $('look-row').hidden=asset!=='soldaat';$('gun-row').hidden=asset!=='wapens';$('plant-row').hidden=asset!=='jungle';$('prop-row').hidden=asset!=='props';$('post-row').hidden=asset!=='wachtpost';$('gen-row').hidden=asset!=='generator';
  const grassPath=v=>`../../assets/grass/${v==='v1'?'grass_baseline':asset+'_lod'+$('grass-lod').value}.glb`;
  const loaded=await Promise.all(versions.map(async v=>[v,makeSlot(await loader.loadAsync(GRASS.includes(asset)?grassPath(v):glbPath(asset,v)))]));
  // extra clips met hetzelfde skelet (klimmen, zitten, rollen, sprinten, herladen, explosie- en branddood), zoals SoldierModel.setup()
  for(const file of EXTRA_CLIPS[asset]||[]){const g=await loader.loadAsync(`../../assets/${file}`);for(const [,slot] of loaded){for(const c of g.animations){slot.clips=slot.clips.filter(x=>x.name!==c.name);slot.clips.push(c);}}}
  const next=Object.fromEntries(loaded);
  if(current!==request){disposeSlots(next);return;}
  disposeSlots(slots);slots=next;
  bounds.makeEmpty();for(const s of Object.values(slots))bounds.union(new THREE.Box3().setFromObject(s.root));
  if(asset==='wapens')applyGun();if(asset==='jungle')applyJungle();if(asset==='props')applyProp();if(asset==='wachtpost')applyWachtpost();if(asset==='generator')applyGenerator();setCamera(false);setupClips();setupMaterials();shading();if(DAMAGED.includes(asset))applyPhase(0);applyLook();if(GRASS.includes(asset))grassVariant();stats();$('loading').hidden=true;status();dirty=true;
 }catch(error){if(current!==request)return;$('loading').hidden=false;$('loading').textContent='Het GLB-model kon niet geladen worden. Controleer de verbinding en open de viewer via HTTP(S). '+error.message;}
}

function setCamera(game){
 const center=bounds.getCenter(new THREE.Vector3());
 const size=bounds.getSize(new THREE.Vector3());
 camera.fov=45;
 if(game){controls.target.set(0,0,0);const a=THREE.MathUtils.degToRad(58);camera.position.set(0,Math.sin(a)*28,Math.cos(a)*28);}
 else{controls.target.copy(center);const radius=size.length()*.5;camera.position.copy(center).add(new THREE.Vector3(1,.75,1.3).normalize().multiplyScalar(radius*3.5));}
 controls.update();camera.updateProjectionMatrix();dirty=true;
}

function status(){const asset=$('asset').value,version=$('version').value;$('status').textContent=`${names[asset]} · ${GRASS.includes(asset)?'Blender 3D-sprieten, 2K PBR; V1 = oorspronkelijke 75 cm graskaarten':asset==='jeep'?'ongewijzigde speelbare jeep':asset==='auto'?'nieuwe auto (geen V1)':asset==='bus'?'nieuwe bus (geen V1)':asset==='straaljager'?'nieuwe straaljager voor de napalm-luchtsteun (geen V1)':asset==='wapens'?'alle wapens uit bron/wapens, bewegende delen met echte clips (geen V1)':asset==='wachtpost'?'slagboom (echte clip Open: arm 82° omhoog) en wachthuisje uit bron/wachtpost, VQ2-PBR en eigen rood-wit verf (geen V1)':asset==='generator'?'dieselgenerator (echte clip Draaien: koelventilator) en gebrand wrak uit bron/generator, VQ2-PBR (geen V1)':asset==='props'?'zandzakken (3 vormen) en houten en munitiekist uit bron/props, echte VQ2-PBR-texturen (geen V1)':asset==='jungle'?'palmen, jungleboom (plankwortels, lianen), verre varianten, rotsen en de stronken van omgevallen bomen uit bron/jungle; schors- en bladtextuur en wind zitten in Godot (geen V1)':asset==='soldaat'&&version==='split'?'V1 oude pop links / VQ2 realistisch rechts, zelfde skelet, clip en camera':version==='split'?'V1 links / VQ2 rechts, identieke camera en belichting':version==='v1'?'origineel op vaste baseline':'VQ2 export'} · 360° draaien en zoomen actief.`;}
const PHASES=['Heel','Beschadigd (ruiten, deuk, band)','Zwaar (deur eraf, kap open)','Brandend (vlammen en rook)','Wrak (verkoold, smeulend)','Ontploffing (speelt af)'];
function phaseNodes(slot){const o={};slot.root.traverse(n=>{if(n.name)o[n.name]=n;});return o;}
function applyPhase(p){
 const slot=slots.v2;if(!slot||!DAMAGED.includes($('asset').value))return;const cfg=CFG[$('asset').value];slot.cfg=cfg;
 const n=phaseNodes(slot);slot.phaseRest=slot.phaseRest||{};
 const rest=(k)=>{const x=n[k];if(!x)return null;if(!slot.phaseRest[k])slot.phaseRest[k]={p:x.position.clone(),q:x.quaternion.clone(),s:x.scale.clone()};return slot.phaseRest[k];};
 const parts=cfg.parts;
 for(const k of parts){const r=rest(k);if(!r)continue;const x=n[k];x.visible=true;x.position.copy(r.p);x.quaternion.copy(r.q);x.scale.copy(r.s);}
 fx.rest=rest;const hide=[];const flat=[];let deuk=0,hood=0;const q=p===5?0:p;
 for(let i=1;i<=q;i++){const [h,f,hd,dk]=cfg.phases[i];hide.push(...h);flat.push(...f);if(hd)hood=hd;deuk=dk;}
 for(const k of hide)if(n[k])n[k].visible=false;
 for(const k of flat){const x=n[k],r=rest(k);if(!x)continue;x.scale.set(r.s.x,r.s.y*cfg.flatK,r.s.z*cfg.flatK);x.position.y=r.p.y-cfg.rim*(1-cfg.flatK);}
 if(n[cfg.hood]&&hood)n[cfg.hood].rotateX(cfg.hoodSign*(cfg.hood==='Motorkap'?hood:1));
 slot.root.traverse(o=>{if(!o.isMesh)return;if(o.morphTargetInfluences&&o.morphTargetInfluences.length)o.morphTargetInfluences[0]=deuk;
  if(!o.userData.lakOriginal&&o.userData.original&&!Array.isArray(o.userData.original)&&o.userData.original.name==='Lak')o.userData.lakOriginal=o.userData.original;
  if(o.userData.lakOriginal){const wr=slot.wrakMaterial;if(wr)o.userData.original=q>=3?wr:o.userData.lakOriginal;}});
 startFx(slot,p,n,rest);
 shading();dirty=true;
}

// ---------- vuur, rook en ontploffing (alleen viewer-effecten; de echte VFX zitten in Godot: Fx.flame/burning/explosion)
const fx={list:[],phase:0,acc:{f:0,s:0,c:0},boom:null,light:null,slot:null,anchor:new THREE.Vector3(),cabin:new THREE.Vector3(),rest:null,nodes:null};
function blobTexture(stops){const c=document.createElement('canvas');c.width=c.height=64;const g=c.getContext('2d');const gr=g.createRadialGradient(32,32,0,32,32,32);for(const [o,col] of stops)gr.addColorStop(o,col);g.fillStyle=gr;g.fillRect(0,0,64,64);const t=new THREE.CanvasTexture(c);t.colorSpace=THREE.SRGBColorSpace;return t;}
const flameTex=blobTexture([[0,'rgba(255,245,200,1)'],[.25,'rgba(255,170,40,.95)'],[.6,'rgba(220,60,10,.5)'],[1,'rgba(120,20,0,0)']]);
const smokeTex=blobTexture([[0,'rgba(60,58,55,.85)'],[.55,'rgba(40,38,36,.5)'],[1,'rgba(30,30,30,0)']]);
function puff(kind,pos,vel,life,s0,s1,extra={}){
 const mat=new THREE.SpriteMaterial({map:kind==='f'?flameTex:smokeTex,transparent:true,depthWrite:false,blending:kind==='f'?THREE.AdditiveBlending:THREE.NormalBlending,rotation:Math.random()*6.28});
 const sp=new THREE.Sprite(mat);sp.position.copy(pos);sp.scale.setScalar(s0);fx.slot.scene.add(sp);
 fx.list.push({sp,kind,vel,life,age:0,s0,s1,up:extra.up??(kind==='f'?1.6:.7),op:extra.op??(kind==='f'?1:.9)});
}
function clearFx(){
 for(const e of fx.list){fx.slot?.scene.remove(e.sp);e.sp.material.dispose();}
 fx.list=[];
 if(fx.light){fx.slot?.scene.remove(fx.light);fx.light=null;}
 if(fx.boom){for(const m of fx.boom.extra)fx.slot?.scene.remove(m);fx.boom=null;}
}
function worldOf(node,fallback){if(!node)return fallback.clone();const v=new THREE.Vector3();node.updateWorldMatrix(true,false);return node.getWorldPosition(v);}
function startFx(slot,p,n,rest){
 clearFx();fx.slot=slot;fx.phase=p;fx.nodes=n;fx.rest=rest;
 slot.root.updateMatrixWorld(true);
 const cfg=slot.cfg;fx.cfg=cfg;const big=cfg===CFG.bus;
 const hood=worldOf(n[cfg.hood],new THREE.Vector3(...cfg.anchor));
 fx.anchor.copy(hood);fx.anchor.y=hood.y-(big?.1:.05);
 fx.cabin.set(cfg.cabin[0],big?cfg.cabin[1]:hood.y+cfg.cabin[1],big?cfg.cabin[2]:hood.z*cfg.cabin[2]);
 if(p===3||p===4){fx.light=new THREE.PointLight(0xff7a22,p===3?(big?22:14):(big?8:5),big?11:7);fx.light.position.copy(fx.anchor).add(new THREE.Vector3(0,.6,0));slot.scene.add(fx.light);}
 if(p===5)startBoom(slot,n,rest);
 shading();dirty=true;
}
function startBoom(slot,n,rest){
 const base=fx.anchor.clone();base.y=.5;base.z=0;
 const bc=fx.cfg.boom,big=fx.cfg===CFG.bus;const flash=new THREE.PointLight(0xffc070,bc.flash,bc.fl);flash.position.set(0,big?2.6:1.4,0);slot.scene.add(flash);fx.light=flash;
 const ringMat=new THREE.MeshBasicMaterial({color:0xffcf9a,transparent:true,opacity:.8,blending:THREE.AdditiveBlending,depthWrite:false,side:THREE.DoubleSide});
 const ring=new THREE.Mesh(new THREE.RingGeometry(.88,1,64),ringMat);ring.rotation.x=-Math.PI/2;ring.position.y=-.1;slot.scene.add(ring);
 const debris=[];
 const fly=(k,v,spin)=>{const x=n[k];if(!x||!rest(k))return;debris.push({x,r:rest(k),v:new THREE.Vector3(...v),w:new THREE.Vector3(...spin),off:new THREE.Vector3()});};
 for(const [k,v,sp] of bc.debris)fly(k,v,sp);
 fx.boom={t:0,ring,ringMat,flash,debris,extra:[ring],burnt:false,burst:false,bc};
 // vuurbal: veel grote vlammen die uit elkaar vliegen
 for(let i=0;i<bc.n;i++){const d=new THREE.Vector3(Math.random()-.5,Math.random()*.9,Math.random()-.5).normalize().multiplyScalar((big?3:2.5)+Math.random()*(big?8:5));puff('f',new THREE.Vector3((Math.random()-.5)*(big?2:1.2),(big?.8:.5)+Math.random()*(big?1.8:.8),(Math.random()-.5)*(big?10:2)),d,.7+Math.random()*(big?.9:.7),big?2:1.2,(big?7:4.5)+Math.random()*(big?3.5:2),{up:big?3:2.5});}
 for(let i=0;i<bc.s;i++){const d=new THREE.Vector3(Math.random()-.5,.4+Math.random()*.9,Math.random()-.5).multiplyScalar(big?5:4);puff('s',new THREE.Vector3((Math.random()-.5)*(big?2:1.4),(big?1:.6)+Math.random()*(big?1.5:1),(Math.random()-.5)*(big?9:2.2)),d,(big?2.6:2.2)+Math.random()*(big?2.4:1.8),big?2.5:1.4,(big?8:4.2)+Math.random()*(big?3:2),{up:big?2:1.6});}
}
function stepBoom(dt){
 const b=fx.boom;b.t+=dt;const t=b.t;
 b.flash.intensity=Math.max(0,b.bc.flash*Math.exp(-t*(b.bc.flash>200?2.6:3.2)));
 const rs=1+t*b.bc.ring;b.ring.scale.setScalar(rs);b.ringMat.opacity=Math.max(0,.8-t*.9);
 if(!b.burnt&&t>.35){b.burnt=true;const slot=fx.slot;slot.root.traverse(o=>{if(!o.isMesh)return;if(o.morphTargetInfluences&&o.morphTargetInfluences.length)o.morphTargetInfluences[0]=1;if(o.userData.lakOriginal&&slot.wrakMaterial)o.userData.original=slot.wrakMaterial;});
  const c=fx.cfg;for(const k of c.boom.burnFlat){const x=fx.nodes[k],r=fx.rest(k);if(x){x.scale.set(r.s.x,r.s.y*c.flatK,r.s.z*c.flatK);x.position.y=r.p.y-c.rim*(1-c.flatK);}}
  for(const k of c.boom.glass)if(fx.nodes[k])fx.nodes[k].visible=false;shading();}
 for(const d of b.debris){d.v.y-=14*dt;d.off.addScaledVector(d.v,dt);const y=d.r.p.y+d.off.y;if(y<-.1&&d.v.y<0){d.off.y=-.1-d.r.p.y;d.v.multiplyScalar(.35);d.v.y=Math.abs(d.v.y)*.3;d.w.multiplyScalar(.5);}
  d.x.position.copy(d.r.p).add(d.off);d.x.rotateX(d.w.x*dt);d.x.rotateY(d.w.y*dt);d.x.rotateZ(d.w.z*dt);}
 if(t>1.6&&!b.burst){b.burst=true;fx.phase=4;fx.light.color.set(0xff7a22);}
 if(fx.phase===4&&t>1.6){fx.light.intensity=fx.cfg===CFG.bus?8:5;}
}
function stepFx(dt){
 if(!fx.slot||!slots.v2||fx.slot!==slots.v2)return false;
 const p=fx.phase;let any=fx.list.length>0;
 if(fx.boom){stepBoom(dt);any=true;}
 if(p===3||p===4){
  any=true;const big=fx.cfg===CFG.bus,flames=fx.cfg.flames[p===3?0:1],smoke=fx.cfg.smoke[p===3?0:1];
  fx.acc.f+=dt*flames;while(fx.acc.f>1){fx.acc.f--;
   const at=Math.random()<.7?fx.anchor:fx.cabin;const j=at===fx.anchor?.45:.35;
   puff('f',new THREE.Vector3(at.x+(Math.random()-.5)*j*2,at.y+Math.random()*.2,at.z+(Math.random()-.5)*j*1.5),new THREE.Vector3((Math.random()-.5)*.3,0,(Math.random()-.5)*.3),.55+Math.random()*.4,.5,p===3?1.9:1.1,{up:1.7});}
  fx.acc.s+=dt*smoke;while(fx.acc.s>1){fx.acc.s--;
   puff('s',new THREE.Vector3(fx.anchor.x+(Math.random()-.5)*.8,fx.anchor.y+.7,fx.anchor.z+(Math.random()-.5)*.8),new THREE.Vector3((Math.random()-.5)*.5+.35,0,(Math.random()-.5)*.5),3.4+Math.random()*1.4,.9,p===3?3.4:2.6,{up:1.1});}
  if(fx.light)fx.light.intensity=(fx.cfg===CFG.bus?(p===3?22:8):(p===3?14:5))*(.8+.2*Math.sin(performance.now()*.03)+.15*Math.random());
 }
 if(fx.boom&&fx.boom.t>1.6){ // na de klap smeult het wrak door
  fx.acc.f+=dt*10;while(fx.acc.f>1){fx.acc.f--;puff('f',new THREE.Vector3(fx.anchor.x+(Math.random()-.5)*.8,fx.anchor.y,fx.anchor.z+(Math.random()-.5)*.8),new THREE.Vector3(0,0,0),.5+Math.random()*.4,.5,1.2,{up:1.6});}
  fx.acc.s+=dt*16;while(fx.acc.s>1){fx.acc.s--;puff('s',new THREE.Vector3(fx.anchor.x+(Math.random()-.5)*.8,fx.anchor.y+.7,fx.anchor.z+(Math.random()-.5)*.8),new THREE.Vector3(.3,0,0),3.6,.9,2.8,{up:1.1});}
 }
 for(let i=fx.list.length-1;i>=0;i--){const e=fx.list[i];e.age+=dt;const k=e.age/e.life;
  if(k>=1){fx.slot.scene.remove(e.sp);e.sp.material.dispose();fx.list.splice(i,1);continue;}
  e.sp.position.addScaledVector(e.vel,dt);e.sp.position.y+=e.up*dt;e.vel.multiplyScalar(1-Math.min(1,dt*1.4));
  e.sp.scale.setScalar(e.s0+(e.s1-e.s0)*Math.sqrt(k));
  e.sp.material.opacity=e.op*(e.kind==='f'?(1-k)*(k<.1?k*10:1):(k<.12?k/.12:1-k)*.8);
  if(e.kind==='s'){const g=.22+.2*k;e.sp.material.color.setRGB(g,g,g*.97);}}
 return any;
}
function setupClips(){
 const clips=$('asset').value==='wapens'?slots.v2.clips.filter(c=>c.name.startsWith($('gun').value+'_')):slots.v2.clips;$('clips').replaceChildren();
 const enabled=clips.length>0;for(const id of ['clips','play','restart','scrub','speed'])$(id).disabled=!enabled;
 if(!enabled){$('clips').add(new Option('Geen animaties in dit model',''));$('animation-status').textContent=GRASS.includes($('asset').value)?'Geen GLB-clips. Wind en lokaal buigen zijn Godot-shaderbewegingen: open scenes/grass_showcase.tscn in Xogot.':$('asset').value==='wapens'?'Dit wapen heeft geen bewegende delen en dus geen clips.':'Geen animaties in dit model.';$('time').textContent='—';clipName='';return;}
 for(const c of clips)$('clips').add(new Option($('asset').value==='wapens'?c.name.replace(/^[^_]+_/,''):c.name.replace(/-loop$/,''),c.name));
 $('animation-status').textContent=GRASS.includes($('asset').value)?'Geen GLB-clips. Wind en lokaal buigen zijn Godot-shaderbewegingen: open scenes/grass_showcase.tscn in Xogot.':$('asset').value==='wapens'?'Echte GLB-clips uit Blender (60 beelden per seconde): slede, repeerknop, sluiting, pomp of repeergreep schuift bij een schot. In het spel start Godot dezelfde clip bij elk schot; "leeg" houdt de pistoolslede open.':$('asset').value==='soldaat'?`Echte GLB-clips op het DEF-skelet (${clips.length}): de tien uit soldaat.glb plus klimmen, zitten en de acties (rollen, sprinten, herladen, explosie- en branddood) uit hun eigen glb, net als in Godot. Beide modellen spelen dezelfde clip. Wapen, terugslag en de schiet-/trefferhouding op het bovenlijf zijn Godot (SoldierModel).`:$('asset').value==='straaljager'?'Echte GLB-clips uit Blender: Vliegen (loop), Bocht en Aanval (neus omlaag, rolroeren, naverbranders). De napalm-vlam en het loslaten van de bommen zijn Godot-effecten; zie de Godot-demo.':DAMAGED.includes($('asset').value)?'Echte GLB-clips uit Blender'+($('asset').value==='bus'?': voordeur, middendeur, motorluik, knielen, lichten, ruitenwissers, knipperlichten en alarm':': deuren, motorkap, kofferklep, ruitenwissers, knipperlichten en alarm')+'. Vuur, rook, ontploffing en vliegende onderdelen zijn Godot-effecten; zie de Godot-demo.':'Originele GLB-clips: wielrotatie, sturen, vering, MG-terugslag en bemanning worden echt geanimeerd. Kies een clip en speel af; gebruik de tijdlijn voor details.';
 selectClip(clips[0].name);
}
function selectClip(name){
 clipName=name;playing=false;$('play').textContent='Afspelen';
 for(const s of Object.values(slots)){s.mixer.stopAllAction();const clip=s.clips.find(c=>c.name===name);if(!clip)continue;s.action=s.mixer.clipAction(clip);s.action.reset().play();s.mixer.update(0);clipDuration=clip.duration;}
 $('scrub').max=clipDuration;$('scrub').value=0;timeLabel(0);dirty=true;
}
function scrub(value){for(const s of Object.values(slots)){if(s.action){s.action.time=value;s.mixer.update(0);}}$('scrub').value=value;timeLabel(value);dirty=true;}
function timeLabel(t){$('time').textContent=`${t.toFixed(2)} / ${clipDuration.toFixed(2)} s`;}
function setupMaterials(){
 materials=[];const seen=new Set();const slot=$('version').value==='v1'?slots.v1:slots.v2;slot.root.traverse(o=>{if(o.isMesh)for(const m of [].concat(o.userData.original)){if(!seen.has(m.uuid)){seen.add(m.uuid);materials.push(m);}}});
 $('materials').replaceChildren(...materials.map((m,i)=>new Option(m.name||`Materiaal ${i+1}`,i)));materialInfo();
}
function materialInfo(){
 const m=materials[Number($('materials').value)||0];if(!m)return;
 const texture=t=>t?.image?`${t.image.width}×${t.image.height}`:'niet aanwezig';
 $('material-info').textContent=`${m.name}\nRuwheid ${m.roughness} · metallic ${m.metalness}\nAlbedo: ${texture(m.map)}\nNormal map: ${texture(m.normalMap)}\nRuwheid: ${texture(m.roughnessMap)}\nMetallic: ${texture(m.metalnessMap)}`;
}
function shading(){
 const mode=$('shading').value;
 for(const s of Object.values(slots))s.root.traverse(o=>{if(!o.isMesh)return;
  if(o.userData.inspection){for(const m of [].concat(o.material))m.dispose();o.userData.inspection=false;}
  const originals=[].concat(o.userData.original);
  const override=originals.map(m=>{
   if(mode==='pbr')return m;
   if(mode==='albedo')return new THREE.MeshBasicMaterial({map:m.map,color:m.color,side:m.side,transparent:m.transparent,opacity:m.opacity});
   if(mode==='normal')return new THREE.MeshBasicMaterial({map:m.normalMap,color:m.normalMap?0xffffff:0x8080ff,side:THREE.DoubleSide});
   if(mode==='roughness')return new THREE.ShaderMaterial({uniforms:{tex:{value:m.roughnessMap||null},hasMap:{value:!!m.roughnessMap},rough:{value:m.roughness}},vertexShader:'varying vec2 vUv;void main(){vUv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);}',fragmentShader:'uniform sampler2D tex;uniform bool hasMap;uniform float rough;varying vec2 vUv;void main(){float r=rough*(hasMap?texture2D(tex,vUv).g:1.0);gl_FragColor=vec4(vec3(r),1.0);}',side:THREE.DoubleSide});
   return new THREE.MeshBasicMaterial({color:0xd2d5ae,wireframe:true});
  });
  o.material=Array.isArray(o.userData.original)?override:override[0];o.userData.inspection=mode!=='pbr';
 });dirty=true;
}
function stats(){
 const name=$('asset').value;
 if(GRASS.includes(name)&&slots.v2){const data=grassInfo();$('stats').textContent=`${data.triangles.toLocaleString('nl')} driehoeken · vier varianten per hoogte · LOD ${$('grass-lod').value} · native procedureel opgebouwde 2048×2048 albedo/normal/ORM. Wind in Godot; geen iPhone-FPS gemeten.`;return;}
 if((DAMAGED.includes(name)||name==='straaljager')&&slots.v2){let tri=0,meshes=0;const mats=new Set(),imgs=new Set();slots.v2.root.traverse(o=>{if(!o.isMesh)return;meshes++;const g=o.geometry;tri+=(g.index?g.index.count:g.attributes.position.count)/3;for(const m of [].concat(o.userData.original||o.material)){mats.add(m.uuid);for(const v of Object.values(m))if(v?.isTexture&&v.image)imgs.add(v.image.width+'×'+v.image.height);}});$('stats').textContent=`${Math.round(tri).toLocaleString('nl')} driehoeken · ${meshes} meshes · ${mats.size} materialen · texturen ${[...imgs].join(', ')} · schade via shape key Deuk en verkoold materiaal. Geen iPhone-FPS gemeten.`;return;}
 if(name==='wachtpost'&&slots.v2){let tri=0,meshes=0;const mats=new Set(),texs=new Set(),g=$('post').value;slots.v2.root.traverse(o=>{if(!o.isMesh||!shown(o))return;meshes++;const gm=o.geometry;tri+=(gm.index?gm.index.count:gm.attributes.position.count)/3;for(const m of [].concat(o.userData.original||o.material)){mats.add(m.uuid);for(const k of ['map','normalMap','roughnessMap','metalnessMap'])if(m[k])texs.add(m[k].uuid);}});$('stats').textContent=`${g==='beide'?'Slagboom en wachthuis':g}: ${Math.round(tri).toLocaleString('nl')} driehoeken · ${meshes} meshes · ${mats.size} materialen · ${texs.size} texturen (1K-VQ2-sets en eigen slagboomverf). Geen iPhone-FPS gemeten.`;return;}
 if(name==='generator'&&slots.v2){let tri=0,meshes=0;const mats=new Set(),texs=new Set(),g=$('gen').value;slots.v2.root.traverse(o=>{if(!o.isMesh||!shown(o))return;meshes++;const gm=o.geometry;tri+=(gm.index?gm.index.count:gm.attributes.position.count)/3;for(const m of [].concat(o.userData.original||o.material)){mats.add(m.uuid);for(const k of ['map','normalMap','roughnessMap','metalnessMap'])if(m[k])texs.add(m[k].uuid);}});$('stats').textContent=`${g==='beide'?'Generator en wrak':g}: ${Math.round(tri).toLocaleString('nl')} driehoeken · ${meshes} meshes · ${mats.size} materialen · ${texs.size} texturen (1K-VQ2-sets). Geen iPhone-FPS gemeten.`;return;}
 if(name==='props'&&slots.v2){let tri=0,meshes=0;const mats=new Set(),texs=new Set();slots.v2.root.traverse(o=>{if(!o.isMesh||!o.visible||!isUnder(o,$('prop').value))return;meshes++;const g=o.geometry;tri+=(g.index?g.index.count:g.attributes.position.count)/3;for(const m of [].concat(o.userData.original||o.material)){mats.add(m.uuid);for(const k of ['map','normalMap','roughnessMap','metalnessMap'])if(m[k])texs.add(m[k].uuid);}});$('stats').textContent=`${$('prop').value}: ${Math.round(tri).toLocaleString('nl')} driehoeken · ${meshes} meshes · ${mats.size} materialen · ${texs.size} texturen (gedeelde 1K-VQ2-sets). Geen iPhone-FPS gemeten.`;return;}
 if(name==='jungle'&&slots.v2){let tri=0,meshes=0;const mats=new Set();slots.v2.root.traverse(o=>{if(!o.isMesh||!o.visible||!isUnder(o,$('plant').value))return;meshes++;const g=o.geometry;tri+=(g.index?g.index.count:g.attributes.position.count)/3;for(const m of [].concat(o.userData.original||o.material))mats.add(m.uuid);});$('stats').textContent=`${$('plant').value}: ${Math.round(tri).toLocaleString('nl')} driehoeken · ${meshes} mesh · ${mats.size} materialen · vertexkleuren, UV's voor schors en blad (textuur in Godot). Geen iPhone-FPS gemeten.`;return;}
 if(name==='wapens'&&slots.v2){let tri=0,meshes=0;const mats=new Set();slots.v2.root.traverse(o=>{if(!o.isMesh)return;let p=o,vis=true;while(p){if(!p.visible)vis=false;p=p.parent;}if(!vis)return;meshes++;const g=o.geometry;tri+=(g.index?g.index.count:g.attributes.position.count)/3;for(const m of [].concat(o.userData.original||o.material))mats.add(m.uuid);});$('stats').textContent=`${$('gun').value}: ${Math.round(tri).toLocaleString('nl')} driehoeken · ${meshes} meshes · ${mats.size} materialen · geen texturen (vlakke PBR-waarden, kleine prop). Geen iPhone-FPS gemeten.`;return;}
 if(name==='soldaat'){const count=slot=>{let tri=0;const mats=new Set(),imgs=new Set();slot.root.traverse(o=>{if(!o.isMesh)return;let p=o,vis=true;while(p){if(!p.visible)vis=false;p=p.parent;}if(!vis)return;const g=o.geometry;tri+=(g.index?g.index.count:g.attributes.position.count)/3;for(const m of [].concat(o.userData.original)){mats.add(m.uuid);for(const v of Object.values(m))if(v?.isTexture&&v.image)imgs.add(v.image.width+'×'+v.image.height);}});return `${Math.round(tri).toLocaleString('nl')} driehoeken · ${mats.size} materialen · texturen ${[...imgs].join(', ')||'geen'}`;};$('stats').textContent=(slots.v1?`V1 (pop zonder uitrusting): ${count(slots.v1)}. `:'')+(slots.v2?`VQ2 (deze look): ${count(slots.v2)}. `:'')+'Geen iPhone-FPS gemeten.';return;}
 if(!report)return;
 const entry=report.assets[name==='jeep'?'playable_jeep':name];
 const text=e=>`${e.triangles.toLocaleString('nl')} driehoeken · ${e.material_surfaces} materiaalsurfaces · ${e.images.length} texturebeelden`;
 $('stats').textContent=name==='jeep'?text(entry):`V1: ${text(entry.v1)}. VQ2: ${text(entry.v2)}. Texturen op bronresolutie 1024×1024; geen fysieke iPhone-FPS gemeten.`;
}
function resize(){const w=stage.clientWidth,h=stage.clientHeight;renderer.setSize(w,h,false);dirty=true;}
new ResizeObserver(resize).observe(stage);
function render(){
 const w=stage.clientWidth,h=stage.clientHeight;const split=$('version').value==='split'&&slots.v1;
 $('divider').hidden=!split;$('left-tag').hidden=!split;$('right-tag').textContent=$('asset').value==='jeep'?'Speelbare jeep':split||$('version').value==='v2'?'VQ2 · nieuw':'V1 · origineel';
 renderer.setScissorTest(!!split);
 const draw=(slot,x,width)=>{if(!slot)return;camera.aspect=width/h;camera.updateProjectionMatrix();renderer.setViewport(x,0,width,h);renderer.setScissor(x,0,width,h);renderer.render(slot.scene,camera);};
 if(split){const half=Math.floor(w/2);draw(slots.v1,0,half);draw(slots.v2,half,w-half);}else draw(slots[$('version').value]||slots.v2,0,w);
 renderer.setScissorTest(false);
}
function loop(){
 requestAnimationFrame(loop);const dt=Math.min(clock.getDelta(),.05);
 controls.autoRotate=rotating;controls.autoRotateSpeed=.8;controls.update(dt);
 if(playing){for(const s of Object.values(slots))s.mixer.update(dt*Number($('speed').value));const t=slots.v2?.action?.time||0;$('scrub').value=t;timeLabel(t);dirty=true;}
 if(stepFx(dt))dirty=true;
 if(dirty&&slots.v2){render();dirty=false;}
}
$('boom').onclick=()=>{$('phase').value='5';applyPhase(5);};
$('phase').addEventListener('change',()=>applyPhase(Number($('phase').value)));$('look').addEventListener('change',applyLook);$('gun').addEventListener('change',applyGun);$('post').addEventListener('change',applyWachtpost);$('gen').addEventListener('change',applyGenerator);$('plant').addEventListener('change',applyJungle);$('prop').addEventListener('change',applyProp);$('asset').addEventListener('change',load);$('version').addEventListener('change',()=>{setupMaterials();status();dirty=true;});$('shading').addEventListener('change',shading);
$('iso').onclick=()=>setCamera(false);$('top').onclick=()=>setCamera(true);
$('rotate').onclick=()=>{rotating=!rotating;$('rotate').setAttribute('aria-pressed',String(rotating));dirty=true;};
$('full').onclick=async()=>{const fallback=()=>{stage.scrollIntoView({behavior:'smooth'});$('status').textContent='Safari ondersteunt hier geen fullscreen. Draai je iPhone naar liggend voor een grotere weergave.';};if(stage.requestFullscreen){try{await stage.requestFullscreen();}catch{fallback();}}else fallback();};
$('clips').onchange=()=>selectClip($('clips').value);$('play').onclick=()=>{playing=!playing;$('play').textContent=playing?'Pauze':'Afspelen';dirty=true;};
$('restart').onclick=()=>{scrub(0);playing=true;$('play').textContent='Pauze';};$('scrub').oninput=()=>{playing=false;$('play').textContent='Afspelen';scrub(Number($('scrub').value));};$('materials').onchange=materialInfo;
canvas.addEventListener('webglcontextlost',e=>{e.preventDefault();$('loading').hidden=false;$('loading').textContent='De browser heeft de 3D-context vrijgegeven. Herlaad deze pagina om de modellen opnieuw te openen.';});
fetch('../../docs/vq2/results/asset-report.json').then(r=>r.json()).then(r=>{report=r;stats();}).catch(()=>{});
window.__VQ2_READY__=true;
// Bounded read-only browser verification hook; never changes model files.
window.__VQ2_TEST__={node:n=>{let r=null;slots.v2?.root.traverse(o=>{if(o.name===n)r=o;});return r;},deuk:()=>{let v=null;slots.v2?.root.traverse(o=>{if(o.isMesh&&o.morphTargetInfluences?.length&&v===null)v=o.morphTargetInfluences[0];});return v;},ready:()=>!!slots.v2&&$('loading').hidden,clips:()=>slots.v2?.clips.map(c=>c.name)||[],
 sample:()=>{const out={};slots.v2?.root.traverse(o=>{if(/WielLV|StuurLV|MG$|Body$|Geschut$/.test(o.name)){out[o.name]={position:o.position.toArray(),quaternion:o.quaternion.toArray(),scale:o.scale.toArray()};}});return out;},
 visible:()=>{const o=[];slots.v2?.root.traverse(x=>{if(ALL_PARTS.has(x.name)&&x.visible)o.push(x.name);});return o.sort();},
 bone:n=>{let r=null;slots.v2?.root.traverse(o=>{if(o.isBone&&o.name===n)r=o.quaternion.toArray();});return r;},
 loaded:()=>({asset:$('asset').value,look:$('look').value,version:$('version').value,materials:materials.map(m=>m.name),camera:camera.position.toArray(),target:controls.target.toArray(),playing})};
const requestedAsset=new URLSearchParams(location.search).get('asset');
if(requestedAsset&&names[requestedAsset])$('asset').value=requestedAsset;
resize();loop();load();

function grassVariant(){
 const variant=Number($('grass-variant').value);bounds.makeEmpty();
 for(const slot of Object.values(slots)){slot.root.updateMatrixWorld(true);slot.root.traverse(o=>{if(!o.isMesh)return;const match=o.name.match(/(?:Grass_.+_|LegacyGrass_)(\d{2})(?:_LOD\d)?$/);o.visible=!variant||Number(match?.[1])===variant;if(o.visible){o.geometry.computeBoundingBox();bounds.union(o.geometry.boundingBox.clone().applyMatrix4(o.matrixWorld));}});}
 if(!bounds.isEmpty())setCamera(false);dirty=true;
}
function grassInfo(){let triangles=0;const meshes=[];slots.v2?.root.traverse(o=>{if(!o.isMesh)return;const g=o.geometry;triangles+=(g.index?g.index.count:g.attributes.position.count)/3;const m=[].concat(o.userData.original)[0];meshes.push({name:o.name,visible:o.visible,maps:[m.map,m.normalMap,m.roughnessMap].map(t=>t?.image?[t.image.width,t.image.height]:null)});});return{triangles,meshes};}
window.__VQ2_TEST__.grassInfo=grassInfo;
$('grass-variant').onchange=grassVariant;
$('grass-lod').onchange=load;
