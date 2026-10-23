"""Bouwt de 3D-viewer van de straatset (één html met het model erin), in de stijl van de gebouw-viewers.
Twee standen: een proefwijk met alle wegdelen (gedraaid zoals de editor ze neerlegt) en de losse delen naast elkaar.
Gebruik: python3 maak_viewer.py <straat.glb> <uit.html>"""
import sys, base64

glb = base64.b64encode(open(sys.argv[1], "rb").read()).decode()
html = r'''<!doctype html>
<html lang="nl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>Bloedjungle Straatset</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Oswald:wght@500;700&family=Inter+Tight:wght@400;500&display=swap">
<style>
:root{--bg:#1b1f16;--paneel:rgba(20,24,16,.78);--tekst:#e8ead9;--zacht:#a9ae94;--accent:#c8352b;--rand:rgba(232,234,217,.16);
--kop:"Oswald",Impact,"Arial Narrow",sans-serif;--body:"Inter Tight",system-ui,sans-serif;color-scheme:dark}
html,body{height:100%;margin:0}
body{background:var(--bg);color:var(--tekst);font-family:var(--body);overflow:hidden}
.wrap{position:relative;height:100%;background:radial-gradient(ellipse at 50% 70%,#4a4630 0%,var(--bg) 70%)}
canvas{display:block;width:100%;height:100%;touch-action:none}
header{position:absolute;top:0;left:0;right:0;padding:14px max(16px,env(safe-area-inset-right,0px)) 0 max(16px,env(safe-area-inset-left,0px));pointer-events:none}
h1{font-family:var(--kop);font-weight:700;font-size:clamp(26px,7vw,40px);letter-spacing:.02em;margin:0;line-height:1;text-transform:uppercase}
h1 span{color:var(--accent)}
.sub{color:var(--zacht);font-size:13px;margin-top:6px;letter-spacing:.04em;text-transform:uppercase;font-family:var(--kop);font-weight:500}
.teller{margin-top:8px;font-size:13px;color:var(--zacht);font-variant-numeric:tabular-nums}
.teller b{color:var(--tekst);font-weight:500}
.balk{position:absolute;left:0;right:0;bottom:calc(14px + env(safe-area-inset-bottom,0px));display:flex;flex-direction:column;gap:8px;align-items:center;padding:0 16px}
.rij{display:flex;flex-wrap:wrap;justify-content:center;gap:8px}
button{background:var(--paneel);border:1px solid var(--rand);color:var(--tekst);border-radius:999px;padding:8px 14px;font:500 14px var(--kop);letter-spacing:.06em;text-transform:uppercase;cursor:pointer;backdrop-filter:blur(6px)}
button[aria-pressed="true"]{background:var(--accent);border-color:var(--accent)}
button.klein{font-size:12px;padding:6px 12px}
button:focus-visible{outline:2px solid var(--tekst);outline-offset:2px}
.hint{background:var(--paneel);border:1px solid var(--rand);border-radius:999px;padding:7px 14px;font-size:13px;color:var(--zacht);backdrop-filter:blur(6px);text-align:center}
.knop{position:absolute;right:max(16px,env(safe-area-inset-right,0px));top:14px}
#fout{position:absolute;inset:0;display:grid;place-items:center;padding:24px;text-align:center;color:var(--zacht)}
#fout[hidden]{display:none}
</style></head><body>
<div class="wrap">
  <canvas id="c" aria-label="3D-model van de straatset"></canvas>
  <header>
    <h1>Bloed<span>jungle</span> straatset</h1>
    <div class="sub">recht · bocht · T · kruispunt · steeg · zebrapad · stoep · plein met fontein</div>
    <div class="teller" id="teller"></div>
  </header>
  <button class="knop klein" id="draai" type="button" aria-pressed="true">Draaien</button>
  <div class="balk">
    <div class="hint">Sleep om te draaien · knijp om te zoomen</div>
    <div class="rij">
      <button type="button" id="bWijk" aria-pressed="true">Proefwijk</button>
      <button type="button" id="bLos" aria-pressed="false">Losse delen</button>
      <button type="button" id="bNacht" aria-pressed="false">Avond</button>
    </div>
  </div>
  <div id="fout" hidden>Het 3D-model kon niet laden. Open de pagina opnieuw.</div>
</div>
<script type="importmap">{"imports":{"three":"https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js","three/addons/":"https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/"}}</script>
<script>window.GLB_B64="@@GLB@@";</script>
<script type="module">
import * as THREE from "three";
import {GLTFLoader} from "three/addons/loaders/GLTFLoader.js";
import {OrbitControls} from "three/addons/controls/OrbitControls.js";

const canvas = document.getElementById("c");
const renderer = new THREE.WebGLRenderer({canvas, antialias: true, alpha: true});
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.05;
const scene = new THREE.Scene();
scene.fog = new THREE.Fog(0x2a2c1f, 50, 110);
const cam = new THREE.PerspectiveCamera(40, 1, 0.1, 300);
cam.position.set(22, 30, 34);
const ctl = new OrbitControls(cam, canvas);
ctl.target.set(4, 0, -6);
ctl.enableDamping = true;
ctl.maxPolarAngle = 1.45;
ctl.minDistance = 5; ctl.maxDistance = 90;
ctl.autoRotate = true; ctl.autoRotateSpeed = 0.5;
const hemi = new THREE.HemisphereLight(0xdfe8ff, 0x5a4a30, 1.1);
scene.add(hemi);
const zon = new THREE.DirectionalLight(0xfff1d6, 2.6);
zon.position.set(-14, 26, 16);
zon.castShadow = true;
zon.shadow.mapSize.set(2048, 2048);
Object.assign(zon.shadow.camera, {left: -30, right: 30, top: 30, bottom: -30, near: 1, far: 90});
zon.shadow.bias = -0.0008;
scene.add(zon);
const grond = new THREE.Mesh(new THREE.CircleGeometry(60, 48), new THREE.MeshStandardMaterial({color: 0x4f5a2c, roughness: 1}));
grond.rotation.x = -Math.PI / 2;
grond.position.y = -0.01;
grond.receiveShadow = true;
scene.add(grond);

// proefwijk: [deel, x, z, kwartslagen, gespiegeld], zoals Stad.KINDS en de editor (noord = -z)
const WIJK = [
  ["Recht", 0, 12, 0], ["Zebra", 0, 6, 0], ["Kruis", 0, 0, 0], ["Recht", 0, -6, 0], ["Plein", 0, -15, 0],
  ["Recht", 6, 0, 1], ["TStuk", 12, 0, 3], ["Recht", 18, 0, 1], ["Bocht", 24, 0, 2], ["Recht", 24, 6, 0],
  ["Steeg", 12, -6, 0], ["Bocht", 12, -12, 1, 1],
  ["Recht", -6, 0, 1], ["Bocht", -12, 0, 3], ["Recht", -12, 6, 0],
  ["Stoep", 6, 6, 0], ["Stoep", -6, 6, 0], ["Stoep", 6, -6, 0],
];
const WORLD = {Asfalt: 12, Stoep: 1.2, Keien: 1, Steen: 2};
let delen = {}, wijk = new THREE.Group(), los = new THREE.Group(), lampen = [];
scene.add(wijk, los);

function plaats(naam, x, z, r, m) {
  const src = delen[naam];
  const g = src.clone(true);
  g.position.set(x, 0, z);
  g.rotation.y = r * Math.PI / 2;
  if (m) g.scale.x = -1;
  g.traverse(o => {
    if (!o.isMesh) return;
    o.receiveShadow = true;
    o.castShadow = naam === "Fontein";
    // wereld-UV op bovenvlakken, zoals het spel doet: de texturen lopen naadloos door
    const s = WORLD[o.material.name];
    if (!s) return;
    o.updateWorldMatrix(true, false);
    const geo = o.geometry.clone();
    const p = geo.attributes.position, n = geo.attributes.normal, uv = geo.attributes.uv;
    const v = new THREE.Vector3(), nn = new THREE.Vector3(), nm = new THREE.Matrix3().getNormalMatrix(o.matrixWorld);
    for (let i = 0; i < p.count; i++) {
      nn.fromBufferAttribute(n, i).applyMatrix3(nm);
      if (nn.y < 0.7) continue;
      v.fromBufferAttribute(p, i).applyMatrix4(o.matrixWorld);
      uv.setXY(i, v.x / s, v.z / s);
    }
    o.geometry = geo;
  });
  return g;
}

new GLTFLoader().parse(Uint8Array.from(atob(window.GLB_B64), c => c.charCodeAt(0)).buffer, "", g => {
  let tris = 0;
  g.scene.traverse(o => {
    if (o.isMesh) {
      tris += (o.geometry.index ? o.geometry.index.count : o.geometry.attributes.position.count) / 3;
      for (const t of ["map", "normalMap"]) if (o.material[t]) { o.material[t].anisotropy = 8; }
    }
  });
  for (const c of [...g.scene.children]) {
    delen[c.name] = c;
    const kopie = c.clone(true);
    kopie.traverse(o => { if (o.isMesh) { o.receiveShadow = true; o.castShadow = c.name === "Fontein"; } });
    los.add(kopie);
  }
  los.position.set(-12, 0, -4);
  for (const [n, x, z, r, m] of WIJK) wijk.add(plaats(n, x, z, r, m || 0));
  wijk.add(plaats("Fontein", 0, -15, 0, 0));
  // een paar lantaarns voor de avondstand
  for (const [x, z] of [[3.6, 9], [-3.6, -3], [9, 3.6], [21, -3.6], [-9, -3.6]]) {
    const l = new THREE.PointLight(0xffc477, 0, 14, 1.6);
    l.position.set(x, 4, z);
    const paal = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.09, 4, 8), new THREE.MeshStandardMaterial({color: 0x2a2d2a, roughness: .6}));
    paal.position.set(x, 2, z); paal.castShadow = true;
    const kap = new THREE.Mesh(new THREE.BoxGeometry(.3, .16, .45), new THREE.MeshStandardMaterial({color: 0xe8d9a0, emissive: 0xffc477, emissiveIntensity: 0}));
    kap.position.set(x, 3.95, z);
    wijk.add(l, paal, kap);
    lampen.push(l, kap);
  }
  zetStand(true);
  document.getElementById("teller").innerHTML = `<b>9</b> delen · <b>${Math.round(tris)}</b> driehoeken samen · 9 texturen`;
}, () => { document.getElementById("fout").hidden = false; });

function zetStand(w) {
  wijk.visible = w; los.visible = !w;
  document.getElementById("bWijk").setAttribute("aria-pressed", w);
  document.getElementById("bLos").setAttribute("aria-pressed", !w);
}
document.getElementById("bWijk").onclick = () => zetStand(true);
document.getElementById("bLos").onclick = () => zetStand(false);
let nacht = false;
document.getElementById("bNacht").onclick = e => {
  nacht = !nacht;
  e.target.setAttribute("aria-pressed", nacht);
  hemi.intensity = nacht ? 0.25 : 1.1;
  zon.intensity = nacht ? 0.15 : 2.6;
  for (const l of lampen) { if (l.isLight) l.intensity = nacht ? 40 : 0; else l.material.emissiveIntensity = nacht ? 2 : 0; }
};
document.getElementById("draai").onclick = e => {
  ctl.autoRotate = !ctl.autoRotate;
  e.target.setAttribute("aria-pressed", ctl.autoRotate);
};
canvas.addEventListener("pointerdown", () => { ctl.autoRotate = false; document.getElementById("draai").setAttribute("aria-pressed", false); });

function maat() {
  const w = canvas.clientWidth, h = canvas.clientHeight;
  renderer.setSize(w, h, false);
  cam.aspect = w / h;
  cam.updateProjectionMatrix();
}
addEventListener("resize", maat);
maat();
renderer.setAnimationLoop(() => { ctl.update(); renderer.render(scene, cam); });
</script>
</body></html>
'''
open(sys.argv[2], "w").write(html.replace("@@GLB@@", glb))
