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
 const hood=worldOf(n.Motorkap,new THREE.Vector3(0,1,-1.4));
 fx.anchor.copy(hood);fx.anchor.y=hood.y-.05;
 fx.cabin.set(0,hood.y+.35,hood.z*-.15);
 if(p===3||p===4){fx.light=new THREE.PointLight(0xff7a22,p===3?14:5,7);fx.light.position.copy(fx.anchor).add(new THREE.Vector3(0,.6,0));slot.scene.add(fx.light);}
 if(p===5)startBoom(slot,n,rest);
 dirty=true;
}
function startBoom(slot,n,rest){
 const base=fx.anchor.clone();base.y=.5;base.z=0;
 const flash=new THREE.PointLight(0xffc070,160,16);flash.position.set(0,1.4,0);slot.scene.add(flash);fx.light=flash;
 const ringMat=new THREE.MeshBasicMaterial({color:0xffcf9a,transparent:true,opacity:.8,blending:THREE.AdditiveBlending,depthWrite:false,side:THREE.DoubleSide});
 const ring=new THREE.Mesh(new THREE.RingGeometry(.85,1,48),ringMat);ring.rotation.x=-Math.PI/2;ring.position.y=-.1;slot.scene.add(ring);
 const debris=[];
 const fly=(k,v,spin)=>{const x=n[k];if(!x||!rest(k))return;debris.push({x,r:rest(k),v:new THREE.Vector3(...v),w:new THREE.Vector3(...spin),off:new THREE.Vector3()});};
 fly('DeurLV',[-6,6,1.2],[2,5,3]);fly('DeurRA',[5,7,-2],[-3,2,6]);fly('DeurRV',[6,5,2.5],[4,-3,2]);fly('DeurLA',[-5,5.5,-3],[-2,6,-4]);
 fly('Motorkap',[.5,10,-1],[7,1,2]);fly('Kofferklep',[-.5,8,2],[-5,1,1]);fly('Wiel_RV',[3,7,-5],[9,0,0]);fly('Wiel_LA',[-2,6,5],[-8,0,0]);
 fx.boom={t:0,ring,ringMat,flash,debris,extra:[ring],burnt:false,burst:false};
 // vuurbal: veel grote vlammen die uit elkaar vliegen
 for(let i=0;i<46;i++){const d=new THREE.Vector3(Math.random()-.5,Math.random()*.9,Math.random()-.5).normalize().multiplyScalar(2.5+Math.random()*5);puff('f',new THREE.Vector3((Math.random()-.5)*1.2,.5+Math.random()*.8,(Math.random()-.5)*2),d,.7+Math.random()*.7,1.2,4.5+Math.random()*2,{up:2.5});}
 for(let i=0;i<34;i++){const d=new THREE.Vector3(Math.random()-.5,.4+Math.random()*.9,Math.random()-.5).multiplyScalar(4);puff('s',new THREE.Vector3((Math.random()-.5)*1.4,.6+Math.random(),(Math.random()-.5)*2.2),d,2.2+Math.random()*1.8,1.4,4.2+Math.random()*2,{up:1.6});}
}
function stepBoom(dt){
 const b=fx.boom;b.t+=dt;const t=b.t;
 b.flash.intensity=Math.max(0,160*Math.exp(-t*3.2));
 const rs=1+t*16;b.ring.scale.setScalar(rs);b.ringMat.opacity=Math.max(0,.8-t*.9);
 if(!b.burnt&&t>.35){b.burnt=true;setDeuk(1);setWreck(true);
  for(const k of ['Wiel_LV','Wiel_RA']){const x=fx.nodes[k],r=fx.rest(k);if(x){x.scale.set(r.s.x,r.s.y*.84,r.s.z*.84);x.position.y=r.p.y-.335*.16;}}
  if(fx.nodes.Voorruit)fx.nodes.Voorruit.visible=false;if(fx.nodes.Achterruit)fx.nodes.Achterruit.visible=false;}
 for(const d of b.debris){d.v.y-=14*dt;d.off.addScaledVector(d.v,dt);const y=d.r.p.y+d.off.y;if(y<-.1&&d.v.y<0){d.off.y=-.1-d.r.p.y;d.v.multiplyScalar(.35);d.v.y=Math.abs(d.v.y)*.3;d.w.multiplyScalar(.5);}
  d.x.position.copy(d.r.p).add(d.off);d.x.rotateX(d.w.x*dt);d.x.rotateY(d.w.y*dt);d.x.rotateZ(d.w.z*dt);}
 if(t>1.6&&!b.burst){b.burst=true;fx.phase=4;fx.light.color.set(0xff7a22);}
 if(fx.phase===4&&t>1.6){fx.light.intensity=5;}
}
function stepFx(dt){
 if(!fx.slot||!slots.v2||fx.slot!==slots.v2)return false;
 const p=fx.phase;let any=fx.list.length>0;
 if(fx.boom){stepBoom(dt);any=true;}
 if(p===3||p===4){
  any=true;const flames=p===3?46:14,smoke=p===3?30:20;
  fx.acc.f+=dt*flames;while(fx.acc.f>1){fx.acc.f--;
   const at=Math.random()<.7?fx.anchor:fx.cabin;const j=at===fx.anchor?.45:.35;
   puff('f',new THREE.Vector3(at.x+(Math.random()-.5)*j*2,at.y+Math.random()*.2,at.z+(Math.random()-.5)*j*1.5),new THREE.Vector3((Math.random()-.5)*.3,0,(Math.random()-.5)*.3),.55+Math.random()*.4,.5,p===3?1.9:1.1,{up:1.7});}
  fx.acc.s+=dt*smoke;while(fx.acc.s>1){fx.acc.s--;
   puff('s',new THREE.Vector3(fx.anchor.x+(Math.random()-.5)*.8,fx.anchor.y+.7,fx.anchor.z+(Math.random()-.5)*.8),new THREE.Vector3((Math.random()-.5)*.5+.35,0,(Math.random()-.5)*.5),3.4+Math.random()*1.4,.9,p===3?3.4:2.6,{up:1.1});}
  if(fx.light)fx.light.intensity=(p===3?14:5)*(.8+.2*Math.sin(performance.now()*.03)+.15*Math.random());
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
