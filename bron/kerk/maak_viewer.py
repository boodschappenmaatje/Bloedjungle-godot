"""Bouwt de 3D-viewer van de kerk (één html met het model erin) uit het sjabloon van de winkel-viewer.
Gebruik: python3 maak_viewer.py <winkel-viewer.html> <kerk.glb> <uit.html>"""
import re, sys, base64
src = open(sys.argv[1]).read()
glb = base64.b64encode(open(sys.argv[2], "rb").read()).decode()
tpl = re.sub(r'window.GLB_B64="[A-Za-z0-9+/=]+"', 'window.GLB_B64="@@GLB@@"', src)


def rep(old, new):
    global tpl
    assert old in tpl, old
    tpl = tpl.replace(old, new, 1)


rep('.sub{color:var(--zacht)', 'header{padding-right:110px!important}.sub{color:var(--zacht)')
rep('<title>Bloedjungle Winkel</title>', '<title>Bloedjungle Kerk</title>')
rep('aria-label="3D-model van de winkel met flat"', 'aria-label="3D-model van de oude kerk met toren"')
rep('<h1>Bloed<span>jungle</span> winkel</h1>', '<h1>Bloed<span>jungle</span> kerk</h1>')
rep('toko + 2 flats · trappen · plat dak · kan helemaal instorten', 'oud kerkje · klokkentoren met trappen tot boven · alles kan kapot')
rep('''      <button type="button" id="bDak" aria-pressed="true">Dak</button>
      <button type="button" id="bVer2" aria-pressed="true">Flat 2</button>
      <button type="button" id="bVer" aria-pressed="true">Flat 1</button>''', '''      <button type="button" id="bDak" aria-pressed="true">Kerkdak</button>
      <button type="button" id="bVer3" aria-pressed="true">Torendak</button>
      <button type="button" id="bVer2" aria-pressed="true">Klokkenkamer</button>
      <button type="button" id="bVer" aria-pressed="true">Uurwerk</button>''')
rep('<button type="button" id="bInzak" class="klein">Flat 2 inzakken</button>', '<button type="button" id="bInzak" class="klein">Toren afbreken</button>')
rep('cam.position.set(17, 15, 22);', 'cam.position.set(24, 20, 30);')
rep('ctl.target.set(0, 4.0, 0);', 'ctl.target.set(0, 4.5, -0.5);')
rep('ctl.minDistance = 5; ctl.maxDistance = 60;', 'ctl.minDistance = 6; ctl.maxDistance = 70;')
rep('new THREE.CircleGeometry(40, 48)', 'new THREE.CircleGeometry(48, 48)')
rep('Object.assign(zon.shadow.camera, {left: -18, right: 18, top: 18, bottom: -18, near: 1, far: 70});', 'Object.assign(zon.shadow.camera, {left: -22, right: 22, top: 22, bottom: -22, near: 1, far: 90});')
rep('const st = {dak: true, ver: true, ver2: true, deur: false, nacht: false, sloop: false};', 'const st = {dak: true, ver: true, ver2: true, ver3: true, deur: false, nacht: false, sloop: false};')
rep('knoop("Ruine").visible = false;\n  for (const n of ["DeurVoor", "DeurAchter", "DeurBinnen0", "DeurBinnen1", "DeurBinnen2"])', 'knoop("RuineToren").visible = false; knoop("RuineSchip").visible = false;\n  for (const n of ["DeurVoorL", "DeurVoorR", "DeurZij"])')
rep('const muren = segs.filter(s => /^(M|P)/.test(s.node.name));', 'const muren = segs.filter(s => /^(M|P|S)/.test(s.node.name));')
a = tpl.index('  // vijf muurstukken van de winkel weg')
b = tpl.index('let ingezakt = false, ingestort = false;')
tpl = tpl[:a] + '''  // drie schipmuren weg = het dak valt; twee muren van een torenlaag weg = alles erboven breekt af;
  // twee torenmuren beneden weg = de toren stort in; vijf schipmuren weg = het schip stort in
  const weg = p => segs.filter(x => x.node.name.startsWith(p) && x.staat === 2).length;
  if (weg("S0") >= 3) dakWeg();
  if (weg("M0") >= 2) ruineDeel("Toren"); else if (weg("M2") >= 2) afbreken(3); else if (weg("M1") >= 2) afbreken(2);
  if (weg("S0") >= 5) ruineDeel("Schip");
}
''' + tpl[b:]
a = tpl.index('let ingezakt = false, ingestort = false;')
b = tpl.index('function allesKapot()')
tpl = tpl[:a] + '''let ingestort = false, val = 99, daken = false;
const ruines = {};
function dakWeg() {
  if (daken) return;
  daken = true;
  const d = seg("Dak"); if (d) zet(d, 2);
  hoop("PuinGroot", new THREE.Vector3(0, 0.3, -2), 0.3, 1.0);
  stof(new THREE.Vector3(0, 6, -2), 24, 8);
}
function afbreken(k) {
  if (k >= val || ruines.Toren) return;
  val = k;
  for (const j of k === 2 ? [2, 3] : [3]) {
    const v = seg("Vloer" + j); if (v) zet(v, 1);
    const g = knoop("Toren" + j);
    g.children.forEach(c => { if (/^(Inrichting|DeurBinnen)/.test(c.name)) c.visible = false; });
  }
  const laag = k === 2 ? "[23]" : "3";
  for (const s of segs) if (new RegExp("^M" + laag).test(s.node.name) && s.staat < 2) zet(s, Math.random() < .6 ? 2 : 1);
  hoop("PuinGroot", new THREE.Vector3(0.3, k === 2 ? 3.9 : 7.5, 6.6), 0.3, 0.85);
  hoop("PuinGroot", new THREE.Vector3(3.4, 0, 10.4), 1.0, 0.9);
  stof(new THREE.Vector3(0, k === 2 ? 8 : 11, 7), 30, 5);
  teller();
}
function ruineDeel(naam) {
  if (ruines[naam]) return;
  ruines[naam] = true;
  const del = naam === "Toren" ? ["TorenVoet", "Toren1", "Toren2", "Toren3"] : ["Schip", "Dak"];
  const pre = naam === "Toren" ? /^(M|P)/ : /^S/;
  for (const n of del) knoop(n).visible = false;
  for (const s of segs) if (pre.test(s.node.name)) s.staat = 2;
  knoop("Ruine" + naam).visible = true;
  for (let k = 0; k < 4; k++) stof(new THREE.Vector3(0, 1 + k * 2.2, naam === "Toren" ? 7 : -2), 18, 7);
  ingestort = ruines.Toren && ruines.Schip;
  teller();
}
function instorten() { ruineDeel("Toren"); ruineDeel("Schip"); }
function herstel() {
  for (const s of segs) zet(s, 0);
  for (const m of losse) scene.remove(m);
  losse = [];
  val = 99; daken = false; ingestort = false;
  for (const k of Object.keys(ruines)) { delete ruines[k]; knoop("Ruine" + k).visible = false; }
  for (const n of ["Begane", "TorenVoet", "Schip"]) knoop(n).visible = true;
  for (const n of ["Toren1", "Toren2", "Toren3"]) {
    const g = knoop(n); g.visible = true;
    g.children.forEach(c => { if (/^(Inrichting|DeurBinnen)/.test(c.name)) c.visible = true; });
  }
  pasZicht(); teller();
}
''' + tpl[b:]
a = tpl.index('function pasZicht() {')
b = tpl.index('// --- tikken ---')
tpl = tpl[:a] + '''function pasZicht() {
  const dak = knoop("Dak"), t1 = knoop("Toren1"), t2 = knoop("Toren2"), t3 = knoop("Toren3");
  if (dak && !ruines.Schip) dak.visible = st.dak;
  if (!ruines.Toren) {
    if (t3) t3.visible = st.ver3;
    if (t2) t2.visible = st.ver2;
    if (t1) t1.visible = st.ver;
  }
}

''' + tpl[b:]
rep('''knop("bVer2", b => { toggle(b, "ver2"); if (!st.ver2) uit("dak", "bDak"); else aan("ver", "bVer"); pasZicht(); });
knop("bVer", b => { toggle(b, "ver"); if (!st.ver) { uit("dak", "bDak"); uit("ver2", "bVer2"); } pasZicht(); });''', '''knop("bVer3", b => { toggle(b, "ver3"); pasZicht(); });
knop("bVer2", b => { toggle(b, "ver2"); if (!st.ver2) uit("ver3", "bVer3"); else aan("ver", "bVer"); pasZicht(); });
knop("bVer", b => { toggle(b, "ver"); if (!st.ver) { uit("ver2", "bVer2"); uit("ver3", "bVer3"); } pasZicht(); });''')
rep('knop("bInzak", () => inzakken());', 'knop("bInzak", () => afbreken(2));')
rep('if (ingestort) return;\n  for (const s of segs) if (s.staat === 0 && !s.node.name.startsWith("Vloer"))', 'if (ingestort) return;\n  for (const s of segs) if (s.staat === 0 && !s.node.name.startsWith("Vloer") && s.node.visible && s.node.parent.visible)')
rep('hoop(s.node.name.startsWith("T_") || s.node.name.startsWith("P") ? "PuinKlein" : "PuinGroot", voet, Math.random() * 6, s.node.name.startsWith("T_") ? 0.7 : 0.8);', 'hoop(s.node.name.startsWith("P") ? "PuinKlein" : "PuinGroot", voet, Math.random() * 6, 0.8);')
open(sys.argv[3], "w").write(tpl.replace("@@GLB@@", glb))
