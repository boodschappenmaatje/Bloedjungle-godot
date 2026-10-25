import * as THREE from 'three';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {RoomEnvironment} from 'three/addons/environments/RoomEnvironment.js';

const $=id=>document.getElementById(id), stage=$('stage'), canvas=$('canvas');
const names={kazerne:'Kazerne',wachttoren:'Wachttoren',legerjeep:'Legerjeep',jeep:'Speelbare jeep',auto:'Personenauto'};
const NEW_ONLY=['jeep','auto'];
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
 floor.rotation.x=-Math.PI/2;floor.position.y=-.16;floor.receiveShadow=true;scene.add(floor);
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
 $('phase-row').hidden=asset!=='auto';
 const versions=NEW_ONLY.includes(asset)?['v2']:['v1','v2'];
 try{
  const loaded=await Promise.all(versions.map(async v=>[v,makeSlot(await loader.loadAsync(`../../assets/${v==='v1'?'vq2_baseline/':''}${asset}.glb`))]));
  const next=Object.fromEntries(loaded);
  if(current!==request){disposeSlots(next);return;}
  disposeSlots(slots);slots=next;
  bounds.makeEmpty();for(const s of Object.values(slots))bounds.union(new THREE.Box3().setFromObject(s.root));
  setCamera(false);setupClips();setupMaterials();shading();if(asset==='auto')applyPhase(0);stats();$('loading').hidden=true;status();dirty=true;
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

function status(){const asset=$('asset').value,version=$('version').value;$('status').textContent=`${names[asset]} · ${asset==='jeep'?'ongewijzigde speelbare jeep':asset==='auto'?'nieuwe auto (geen V1)':version==='split'?'V1 links / VQ2 rechts, identieke camera en belichting':version==='v1'?'origineel op vaste baseline':'VQ2 export'} · 360° draaien en zoomen actief.`;}
const PHASES=['Heel','Beschadigd (ruiten, deuk, band)','Zwaar (deur eraf, kap open)','Brandend (oranje gloed)','Wrak (verkoold)'];
function phaseNodes(slot){const o={};slot.root.traverse(n=>{if(n.name)o[n.name]=n;});return o;}
function applyPhase(p){
 const slot=slots.v2;if(!slot||$('asset').value!=='auto')return;
 const n=phaseNodes(slot);slot.phaseRest=slot.phaseRest||{};
 const rest=(k)=>{const x=n[k];if(!x)return null;if(!slot.phaseRest[k])slot.phaseRest[k]={p:x.position.clone(),q:x.quaternion.clone(),s:x.scale.clone()};return slot.phaseRest[k];};
 const parts=['Voorruit','Achterruit','DeurLV','DeurRV','DeurLA','DeurRA','Motorkap','Kofferklep','Wiel_LV','Wiel_RV','Wiel_LA','Wiel_RA'];
 for(const k of parts){const r=rest(k);if(!r)continue;const x=n[k];x.visible=true;x.position.copy(r.p);x.quaternion.copy(r.q);x.scale.copy(r.s);}
 const hide=[];const flat=[];let deuk=0,hood=0;
 if(p>=1){hide.push('Voorruit','Achterruit');flat.push('Wiel_LV');deuk=.55;}
 if(p>=2){hide.push('DeurRV','DeurLA');flat.push('Wiel_RA');hood=.6;deuk=.85;}
 if(p>=3){flat.push('Wiel_RV');deuk=1;}
 if(p>=4){hide.push('DeurLV','DeurRA');deuk=1;}
 for(const k of hide)if(n[k])n[k].visible=false;
 for(const k of flat){const x=n[k],r=rest(k);if(!x)continue;x.scale.set(r.s.x,r.s.y*.84,r.s.z*.84);x.position.y=r.p.y-.335*.16;}
 if(n.Motorkap&&hood)n.Motorkap.rotateX(hood);
 slot.root.traverse(o=>{if(!o.isMesh)return;if(o.morphTargetInfluences&&o.morphTargetInfluences.length)o.morphTargetInfluences[0]=deuk;
  if(!o.userData.lakOriginal&&o.userData.original&&!Array.isArray(o.userData.original)&&o.userData.original.name==='Lak')o.userData.lakOriginal=o.userData.original;
  if(o.userData.lakOriginal){const wr=slot.wrakMaterial;if(wr)o.userData.original=p>=4?wr:o.userData.lakOriginal;}});
 if(slot.fireLight)slot.scene.remove(slot.fireLight);
 if(p===3){slot.fireLight=new THREE.PointLight(0xff7a22,12,6);slot.fireLight.position.set(0,1.1,1.3);slot.scene.add(slot.fireLight);}else slot.fireLight=null;
 shading();dirty=true;
}
function setupClips(){
 const clips=slots.v2.clips;$('clips').replaceChildren();
 const enabled=clips.length>0;for(const id of ['clips','play','restart','scrub','speed'])$(id).disabled=!enabled;
 if(!enabled){$('clips').add(new Option('Geen animaties in dit model',''));$('animation-status').textContent='Geen animaties in dit model.';$('time').textContent='—';clipName='';return;}
 for(const c of clips)$('clips').add(new Option(c.name.replace(/-loop$/,''),c.name));
 $('animation-status').textContent=$('asset').value==='auto'?'Echte GLB-clips uit Blender: deuren, motorkap, kofferklep, ruitenwissers, knipperlichten en alarm. Vuur, rook, ontploffing en vliegende onderdelen zijn Godot-effecten; zie de Godot-demo.':'Originele GLB-clips: wielrotatie, sturen, vering, MG-terugslag en bemanning worden echt geanimeerd. Kies een clip en speel af; gebruik de tijdlijn voor details.';
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
 if(name==='auto'&&slots.v2){let tri=0,meshes=0;const mats=new Set(),imgs=new Set();slots.v2.root.traverse(o=>{if(!o.isMesh)return;meshes++;const g=o.geometry;tri+=(g.index?g.index.count:g.attributes.position.count)/3;for(const m of [].concat(o.userData.original||o.material)){mats.add(m.uuid);for(const v of Object.values(m))if(v?.isTexture&&v.image)imgs.add(v.image.width+'×'+v.image.height);}});$('stats').textContent=`${Math.round(tri).toLocaleString('nl')} driehoeken · ${meshes} meshes · ${mats.size} materialen · texturen ${[...imgs].join(', ')} · schade via shape key Deuk en verkoold materiaal. Geen iPhone-FPS gemeten.`;return;}
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
 if(dirty&&slots.v2){render();dirty=false;}
}
$('phase').addEventListener('change',()=>applyPhase(Number($('phase').value)));$('asset').addEventListener('change',load);$('version').addEventListener('change',()=>{setupMaterials();status();dirty=true;});$('shading').addEventListener('change',shading);
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
 loaded:()=>({asset:$('asset').value,version:$('version').value,materials:materials.map(m=>m.name),camera:camera.position.toArray(),target:controls.target.toArray(),playing})};
resize();loop();load();
