"""Bouwt de 3D-viewer van het benzinestation (één html met het model erin) uit het sjabloon van de winkel-viewer.
Tik op een pomp of olievat en hij ontploft, met een kettingreactie naar de pompen, vaten, kolommen en muren in de buurt.
Gebruik: python3 maak_viewer.py <winkel-viewer.html> <benzine.glb> <uit.html>"""
import re, sys, base64
src = open(sys.argv[1]).read()
glb = base64.b64encode(open(sys.argv[2], "rb").read()).decode()
tpl = re.sub(r'window.GLB_B64="[A-Za-z0-9+/=]+"', 'window.GLB_B64="@@GLB@@"', src)


def rep(old, new):
    global tpl
    assert old in tpl, old
    tpl = tpl.replace(old, new, 1)


def cut(a, b, new):
    global tpl
    i, j = tpl.index(a), tpl.index(b)
    tpl = tpl[:i] + new + tpl[j:]


rep('.sub{color:var(--zacht)', 'header{padding-right:110px!important}.sub{color:var(--zacht)')
rep('<title>Bloedjungle Winkel</title>', '<title>Bloedjungle Benzinestation</title>')
rep('aria-label="3D-model van de winkel met flat"', 'aria-label="3D-model van het benzinestation"')
rep('<h1>Bloed<span>jungle</span> winkel</h1>', '<h1>Bloed<span>jungle</span> benzine</h1>')
rep('toko + 2 flats · trappen · plat dak · kan helemaal instorten', 'toko met kassa · luifel · vier pompen · alles kan ontploffen')
rep('''      <button type="button" id="bDak" aria-pressed="true">Dak</button>
      <button type="button" id="bVer2" aria-pressed="true">Flat 2</button>
      <button type="button" id="bVer" aria-pressed="true">Flat 1</button>''', '''      <button type="button" id="bDak" aria-pressed="true">Dak</button>
      <button type="button" id="bVer" aria-pressed="true">Luifel</button>''')
rep('<button type="button" id="bInzak" class="klein">Flat 2 inzakken</button>', '<button type="button" id="bInzak" class="klein">Pomp opblazen</button>')
rep('cam.position.set(17, 15, 22);', 'cam.position.set(15, 12, 19);')
rep('ctl.target.set(0, 4.0, 0);', 'ctl.target.set(0, 1.8, 0.5);')
rep('const st = {dak: true, ver: true, ver2: true, deur: false, nacht: false, sloop: false};', 'const st = {dak: true, ver: true, deur: false, nacht: false, sloop: false};')
rep('knoop("Ruine").visible = false;\n  for (const n of ["DeurVoor", "DeurAchter", "DeurBinnen0", "DeurBinnen1", "DeurBinnen2"])',
    'knoop("RuineWinkel").visible = false; knoop("RuineLuifel").visible = false;\n  for (const n of ["DeurVoor", "DeurAchter", "DeurBinnen0"])')
rep('const muren = segs.filter(s => /^(M|P)/.test(s.node.name));', 'const muren = segs.filter(s => /^(M|P|K)/.test(s.node.name));')
rep('document.getElementById("teller").innerHTML = `Muurstukken: <b>${n[0]}</b> heel · <b>${n[1]}</b> kapot · <b>${n[2]}</b> weg`;',
    'const pp = segs.filter(s => s.node.name.startsWith("X") && s.staat > 0).length;\n'
    '  document.getElementById("teller").innerHTML = `Muren en kolommen: <b>${n[0]}</b> heel · <b>${n[1]}</b> kapot · <b>${n[2]}</b> weg · <b>${pp}</b> ontploft`;')
rep('''  if (s.staat === 0) {
    zet(s, 1); stof(c, 6); brokken(c, uit, 4);''', '''  if (s.node.name.startsWith("X")) { boem(s); return; }
  if (s.staat === 0) {
    zet(s, 1); stof(c, 6); brokken(c, uit, 4);''')
rep('hoop(s.node.name.startsWith("T_") || s.node.name.startsWith("P") ? "PuinKlein" : "PuinGroot", voet, Math.random() * 6, s.node.name.startsWith("T_") ? 0.7 : 0.8);',
    'hoop(/^(P|K)/.test(s.node.name) ? "PuinKlein" : "PuinGroot", voet, Math.random() * 6, 0.8);')
cut('  // vijf muurstukken van de winkel weg', 'let ingezakt = false, ingestort = false;', '''  regels();
}
// twee kolommen weg = de luifel klapt in; vier muren weg = het dak valt; vijf muren weg = het winkeltje stort in
function regels() {
  const weg = p => segs.filter(x => x.node.name.startsWith(p) && x.staat === 2).length;
  if (weg("M0") >= 4 && !ruines.Winkel) { const d = seg("Dak"); if (d && d.staat < 2) { zet(d, 2); hoop("PuinGroot", new THREE.Vector3(0.5, 0.2, 2.4), 0.3, 1.0); } }
  if (weg("K") >= 2) ruineDeel("Luifel");
  if (weg("M0") >= 5) ruineDeel("Winkel");
}
''')
cut('let ingezakt = false, ingestort = false;', 'function allesKapot()', '''let ingestort = false;
const ruines = {};
// --- ontploffen: vuurbal, rook, het uitgebrande wrak, en alles in de buurt krijgt een klap ---
const vuurMat = new THREE.MeshBasicMaterial({color: 0xffa040, transparent: true, opacity: 0.95, depthWrite: false});
const rookMat = new THREE.MeshBasicMaterial({color: 0x2a2622, transparent: true, opacity: 0.6, depthWrite: false});
const vuren = [];
function vuurbal(p, s) {
  const licht = new THREE.PointLight(0xff8a3a, 60, 18 * s);
  licht.position.copy(p).add(new THREE.Vector3(0, 1.2, 0));
  scene.add(licht);
  vuren.push({m: licht, t: 0, d: 0.9, licht: true});
  for (let i = 0; i < 9; i++) {
    const m = new THREE.Mesh(stofGeo, (i < 6 ? vuurMat : rookMat).clone());
    m.position.copy(p).add(new THREE.Vector3((Math.random() - .5) * 1.5 * s, 0.4 + Math.random() * 1.6 * s, (Math.random() - .5) * 1.5 * s));
    m.scale.setScalar(0.4);
    scene.add(m);
    vuren.push({m, t: 0, d: i < 6 ? 0.7 + Math.random() * 0.4 : 2.2, groei: i < 6 ? 3.6 * s : 4.5 * s, v: new THREE.Vector3(0, i < 6 ? 1.5 : 1.0, 0)});
  }
}
function boem(s) {
  if (s.staat > 0) return;
  zet(s, 1);
  const c = new THREE.Box3().setFromObject(s.heel.visible ? s.heel : s.kapot).getCenter(new THREE.Vector3());
  const p = s.node.getWorldPosition(new THREE.Vector3());
  const pomp = s.node.name.startsWith("XPomp"), r = pomp ? 7.5 : 5.5;
  vuurbal(p, pomp ? 1.3 : 0.9);
  brokken(c, new THREE.Vector3(Math.random() - .5, 0, Math.random() - .5).normalize(), 6);
  for (const o of segs) {
    if (o === s || o.staat >= 2 || o.node.name.startsWith("Vloer") || !o.node.parent.visible) continue;
    const box = new THREE.Box3().setFromObject(o.staat === 0 ? o.heel : o.kapot);
    const d = box.distanceToPoint(p);
    if (d > r) continue;
    if (o.node.name.startsWith("X")) { setTimeout(() => boem(o), 200 + Math.random() * 400); continue; }   // kettingreactie
    const klap = 2.2 * (pomp ? 300 : 220) * (1 - d / r), hp = o.node.name.startsWith("K") ? 260 : o.node.name.startsWith("Dak") ? 9999 : 300;
    if (klap > hp) { o.staat = 0; raak(o); raak(o); } else if (klap > hp * 0.45 && o.staat === 0) raak(o);
  }
  teller(); regels();
}
function ruineDeel(naam) {
  if (ruines[naam]) return;
  ruines[naam] = true;
  const del = naam === "Luifel" ? ["Luifel"] : ["Begane", "Dak"];
  const pre = naam === "Luifel" ? /^K/ : /^(M|P)/;
  for (const n of del) knoop(n).visible = false;
  for (const s of segs) if (pre.test(s.node.name)) s.staat = 2;
  knoop("Ruine" + naam).visible = true;
  for (let k = 0; k < 4; k++) stof(new THREE.Vector3(0, 1 + k * 1.2, naam === "Luifel" ? -3 : 2.6), 18, 7);
  ingestort = ruines.Luifel && ruines.Winkel;
  teller();
}
function instorten() {
  for (const s of segs) if (s.node.name.startsWith("X") && s.staat === 0) { zet(s, 1); }
  ruineDeel("Luifel"); ruineDeel("Winkel");
}
function inzakken() {
  const heel = segs.filter(s => s.node.name.startsWith("XPomp") && s.staat === 0);
  if (heel.length) boem(heel[Math.floor(Math.random() * heel.length)]);
}
function herstel() {
  for (const s of segs) zet(s, 0);
  for (const m of losse) scene.remove(m);
  losse = [];
  ingestort = false;
  for (const k of Object.keys(ruines)) { delete ruines[k]; knoop("Ruine" + k).visible = false; }
  for (const n of ["Begane", "Dak", "Luifel"]) knoop(n).visible = true;
  pasZicht(); teller();
}
''')
rep('for (const s of segs) if (s.staat === 0 && !s.node.name.startsWith("Vloer"))', 'for (const s of segs) if (s.staat === 0 && !s.node.name.startsWith("Vloer") && s.node.parent.visible)')
cut('function pasZicht() {', '// --- tikken ---', '''function pasZicht() {
  const dak = knoop("Dak"), lu = knoop("LuifelDak");
  if (dak && !ruines.Winkel) dak.visible = st.dak;
  if (lu) lu.visible = st.ver;
}

''')
rep('''knop("bVer2", b => { toggle(b, "ver2"); if (!st.ver2) uit("dak", "bDak"); else aan("ver", "bVer"); pasZicht(); });
knop("bVer", b => { toggle(b, "ver"); if (!st.ver) { uit("dak", "bDak"); uit("ver2", "bVer2"); } pasZicht(); });''',
    'knop("bVer", b => { toggle(b, "ver"); pasZicht(); });')
rep('"Tik op een muur of het dak: eerst kapot, dan weg"', '"Tik op een muur of kolom (kapot, dan weg) of op een pomp: boem"')
rep('''  ctl.update();
  renderer.render(scene, cam);''', '''  for (let i = vuren.length - 1; i >= 0; i--) {
    const f = vuren[i];
    f.t += dt;
    const k = Math.min(1, f.t / f.d);
    if (f.licht) f.m.intensity = 60 * (1 - k);
    else {
      f.m.position.addScaledVector(f.v, dt);
      f.m.scale.setScalar(0.4 + f.groei * Math.sqrt(k));
      f.m.material.opacity = (f.m.material.color.r > 0.5 ? 0.95 : 0.6) * (1 - k);
    }
    if (f.t >= f.d) { scene.remove(f.m); vuren.splice(i, 1); }
  }
  ctl.update();
  renderer.render(scene, cam);''')
open(sys.argv[3], "w").write(tpl.replace("@@GLB@@", glb))
