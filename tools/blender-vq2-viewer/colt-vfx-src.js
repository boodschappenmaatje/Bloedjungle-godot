import * as THREE from 'three';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';

const $=id=>document.getElementById(id);
const canvas=$('colt-canvas'),stage=$('colt-stage');
const scene=new THREE.Scene();scene.background=new THREE.Color(0x18251d);
scene.fog=new THREE.Fog(0x18251d,6,14);
const camera=new THREE.PerspectiveCamera(49,1,.05,40);
camera.position.set(2.0,2.45,-3.2);
const renderer=new THREE.WebGLRenderer({canvas,antialias:true,powerPreference:'high-performance'});
renderer.setPixelRatio(Math.min(window.devicePixelRatio||1,2));
renderer.outputColorSpace=THREE.SRGBColorSpace;
renderer.toneMapping=THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure=1.45;
renderer.shadowMap.enabled=true;
renderer.shadowMap.type=THREE.PCFSoftShadowMap;
const controls=new OrbitControls(camera,canvas);
controls.target.set(0,.75,.15);controls.minDistance=1.5;controls.maxDistance=7;
controls.maxPolarAngle=Math.PI*.48;controls.update();
scene.add(new THREE.HemisphereLight(0xc7d3bd,0x2d2b1e,2.4));
const sun=new THREE.DirectionalLight(0xffdfad,3.4);sun.position.set(-2,5,-2);
sun.castShadow=true;sun.shadow.mapSize.set(1024,1024);scene.add(sun);
const floor=new THREE.Mesh(new THREE.PlaneGeometry(20,20),new THREE.MeshStandardMaterial({color:0x333a29,roughness:1}));
floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;scene.add(floor);

// The review target is scaled to the actual M1911 model; this is a visual
// approximation of the material response, not the Godot renderer.
const concrete=new THREE.Mesh(new THREE.BoxGeometry(1.35,1.7,.19),new THREE.MeshStandardMaterial({color:0x77756b,roughness:1}));
concrete.position.set(0,.86,1.35);concrete.castShadow=true;concrete.receiveShadow=true;scene.add(concrete);
const bark=new THREE.Mesh(new THREE.CylinderGeometry(.34,.43,2.55,16),new THREE.MeshStandardMaterial({color:0x4b3525,roughness:1}));
bark.position.set(0,1.28,1.35);bark.castShadow=true;bark.receiveShadow=true;scene.add(bark);
const roots=new THREE.Group();roots.position.set(0,.04,1.35);scene.add(roots);
for(let i=0;i<5;i++){
 const root=new THREE.Mesh(new THREE.CylinderGeometry(.075,.17,.8,7),bark.material);
 root.rotation.z=(i-2)*.26;root.position.set((i-2)*.15,.13,0);roots.add(root);
}
const gunAnchor=new THREE.Group();gunAnchor.position.set(0,.84,-.86);gunAnchor.rotation.y=Math.PI/2;gunAnchor.scale.setScalar(2.5);scene.add(gunAnchor);
const muzzle=new THREE.Vector3(0,.86,-.43),hit=new THREE.Vector3(0,.86,1.2);
const light=new THREE.PointLight(0xff9d31,0,1.5);light.position.copy(muzzle);scene.add(light);
const flashMaterial=new THREE.SpriteMaterial({color:0xffc97b,transparent:true,depthWrite:false,blending:THREE.AdditiveBlending});
const flash=new THREE.Sprite(flashMaterial);flash.position.copy(muzzle);flash.scale.set(.82,.53,1);flash.visible=false;scene.add(flash);
const streak=new THREE.Mesh(new THREE.CylinderGeometry(.007,.016,1,7),new THREE.MeshBasicMaterial({color:0xffb847,transparent:true,opacity:.9,depthWrite:false,blending:THREE.AdditiveBlending}));
streak.visible=false;scene.add(streak);
const streakCore=new THREE.Mesh(new THREE.SphereGeometry(.025,8,6),new THREE.MeshBasicMaterial({color:0xfff5c2,transparent:true,depthWrite:false,blending:THREE.AdditiveBlending}));
streakCore.visible=false;scene.add(streakCore);
const impactLight=new THREE.PointLight(0xffba55,0,1);impactLight.position.copy(hit);scene.add(impactLight);
const dust=[];const chips=[];const marks=[];
const dustGeo=new THREE.SphereGeometry(.09,8,6);
for(let i=0;i<6;i++){
 const puff=new THREE.Mesh(dustGeo,new THREE.MeshBasicMaterial({color:0x8c8471,transparent:true,opacity:0,depthWrite:false}));
 scene.add(puff);dust.push(puff);
 const chip=new THREE.Mesh(new THREE.BoxGeometry(.028,.075,.025),new THREE.MeshStandardMaterial({color:0x8a8174,roughness:1}));
 chip.visible=false;scene.add(chip);chips.push(chip);
}
let model,mixer,shot,playing=true,t=0,oldT=0,ready=false;
const duration=1.6;
const atlasLoader=new THREE.TextureLoader();
const atlas=await atlasLoader.loadAsync('../../assets/vfx/m1911/m1911_muzzle_flash_4x4.png').catch(e=>{throw Error('Flitsatlas: '+e.message)});
atlas.colorSpace=THREE.SRGBColorSpace;
const frames=Array.from({length:16},(_,i)=>{
 const texture=atlas.clone();texture.needsUpdate=true;texture.repeat.set(.25,.25);
 texture.offset.set((i%4)*.25,1-(Math.floor(i/4)+1)*.25);
 texture.colorSpace=THREE.SRGBColorSpace;return texture;
});
try{
 const gltf=await new GLTFLoader().loadAsync('../../assets/meshy_m1911.glb');
 model=gltf.scene;gunAnchor.add(model);
 model.traverse(o=>{if(o.isMesh){o.castShadow=true;o.receiveShadow=true;}});
 shot=gltf.animations.find(c=>c.name==='M1911_schot');
 if(!shot)throw Error('De echte M1911_schot-clip ontbreekt in het GLB.');
 mixer=new THREE.AnimationMixer(model);const action=mixer.clipAction(shot);action.setLoop(THREE.LoopOnce,1);action.clampWhenFinished=true;action.play();
 ready=true;$('colt-loading').hidden=true;
 $('colt-status').textContent=`Echte M1911-clip (${shot.duration.toFixed(2)} s) · atlasflits · materiaalinslag. Sleep de tijdlijn of draai de camera.`;
}catch(e){$('colt-loading').textContent='Viewer kon niet laden: '+e.message;throw e;}

function clearMarks(){for(const m of marks)scene.remove(m);marks.length=0;}
function addMark(x=0,y=0){
 const tree=$('target').value==='tree';
 const mark=new THREE.Mesh(new THREE.CircleGeometry(tree?.035:.029,12),new THREE.MeshBasicMaterial({color:tree?0x25170d:0x161613,depthWrite:false,side:THREE.DoubleSide}));
 mark.position.set(x,.86+y,tree?1.35-.352:1.35-.103);
 scene.add(mark);marks.push(mark);
 while(marks.length>12){const oldest=marks.shift();scene.remove(oldest);oldest.geometry.dispose();oldest.material.dispose();}
}
function seedMarks(){clearMarks();addMark(-.28,.17);addMark(.26,-.15);}
function chooseTarget(){const tree=$('target').value==='tree';bark.visible=tree;roots.visible=tree;concrete.visible=!tree;
 const c=tree?0x735032:0x8a8174;for(const p of chips)p.material.color.setHex(c);
 seedMarks();setTime(0);
}
function setTime(value){
 oldT=t;t=Math.max(0,Math.min(duration,value));
 $('timeline').value=String(t);$('time').textContent=t.toFixed(2).replace('.',',')+' s';
 mixer.setTime(Math.min(t,shot.duration));
 const flashLife=.115, flightStart=.027, flightEnd=.20, impactStart=.20;
 flash.visible=t<flashLife;
 if(flash.visible){const frame=Math.min(15,Math.floor(t/flashLife*16));flashMaterial.map=frames[frame];flashMaterial.needsUpdate=true;
  const phase=t/flashLife;flash.scale.set(.72+phase*.18,.47+phase*.12,1);flashMaterial.opacity=1-phase*.6;}
 light.intensity=t<flashLife?9*(1-t/flashLife):0;
 const flight=(t-flightStart)/(flightEnd-flightStart);
 streak.visible=flight>0&&flight<1;
 streakCore.visible=streak.visible;
 if(streak.visible){const head=muzzle.clone().lerp(hit,Math.min(1,flight));const tail=muzzle.clone().lerp(hit,Math.max(0,flight-.43));
  const mid=tail.clone().add(head).multiplyScalar(.5),len=Math.max(.01,tail.distanceTo(head));
  streak.position.copy(mid);streak.scale.set(1,len,1);streak.quaternion.setFromUnitVectors(new THREE.Vector3(0,1,0),head.clone().sub(tail).normalize());
  streakCore.position.copy(head);streak.material.opacity=.82*Math.min(1,(1-flight)*7);}
 const age=t-impactStart,active=age>=0&&age<.62;
 impactLight.intensity=age>=0&&age<.06?5*(1-age/.06):0;
 if(oldT<impactStart&&t>=impactStart)addMark(.02,.01);
 for(let i=0;i<6;i++){
  const a=(i/6)*Math.PI*2,spread=.26+(i%3)*.09;
  const p=dust[i],ch=chips[i];p.visible=active;
  ch.visible=age>=0&&age<.43;
  if(active){p.position.copy(hit).add(new THREE.Vector3(Math.cos(a)*spread*age,Math.sin(a)*spread*age,-.06-age*.12));
   p.scale.setScalar(.55+age*2.8);p.material.opacity=(1-age/.62)*.23;}
  if(ch.visible){ch.position.copy(hit).add(new THREE.Vector3(Math.cos(a)*.65*age,Math.sin(a)*.45*age-1.1*age*age,-.04-age*.5));ch.rotation.set(age*6+i,age*4,age*7);}
 }
}
chooseTarget();
function resize(){const w=stage.clientWidth,h=stage.clientHeight;renderer.setSize(w,h,false);camera.aspect=w/h;camera.updateProjectionMatrix();}
new ResizeObserver(resize).observe(stage);resize();
const clock=new THREE.Clock();
function loop(){requestAnimationFrame(loop);const dt=Math.min(clock.getDelta(),.05);
 if(playing&&ready){const next=t+dt;if(next>duration)setTime(0);else setTime(next);}
 controls.update();renderer.render(scene,camera);
}
loop();
$('target').onchange=chooseTarget;
$('play').onclick=()=>{playing=!playing;$('play').textContent=playing?'Pauze':'Afspelen';};
$('restart').onclick=()=>{setTime(0);playing=true;$('play').textContent='Pauze';};
$('camera').onclick=()=>{camera.position.set(2,2.45,-3.2);controls.target.set(0,.75,.15);controls.update();};
$('timeline').oninput=()=>{playing=false;$('play').textContent='Afspelen';setTime(Number($('timeline').value));};
window.__COLT_VIEWER_TEST__={ready:()=>ready,clip:()=>shot?.name,slide:()=>{let found=null;model?.traverse(o=>{if(o.name==='M1911_Slede')found=o;});return found?.position.toArray();},setTime, state:()=>({time:t,target:$('target').value,flash:flash.visible,streak:streak.visible,chips:chips.filter(c=>c.visible).length,marks:marks.length})};
