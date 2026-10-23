"""Bouwt de 3D-viewer van het hotel (één html met het model erin) uit het sjabloon van de winkel-viewer.
Tik in sloopstand op een muur of het dak: eerst kapot, dan weg. Vijf muren van een verdieping weg: alles erboven zakt in; zes van de lobby: alles stort in.
Gebruik: python3 maak_viewer.py <winkel-viewer.html> <hotel.glb> <uit.html>"""
import re, sys, base64
src = open(sys.argv[1]).read()
glb = base64.b64encode(open(sys.argv[2], "rb").read()).decode()
tpl = re.sub(r'window.GLB_B64="[A-Za-z0-9+/=]+"', 'window.GLB_B64="@@GLB@@"', src)


def rep(old, new):
    global tpl
    assert old in tpl, old
    tpl = tpl.replace(old, new, 1)


rep('<title>Bloedjungle Winkel</title>', '<title>Bloedjungle Hotel</title>')
rep('aria-label="3D-model van de winkel met flat"', 'aria-label="3D-model van het hotel"')
rep('<h1>Bloed<span>jungle</span> winkel</h1>', '<h1>Bloed<span>jungle</span> hotel</h1>')
rep('toko + 2 flats · trappen · plat dak · kan helemaal instorten', 'lobby + 3 verdiepingen met kamers · trappen · dakreclame · kan helemaal instorten')
rep('''      <button type="button" id="bVer2" aria-pressed="true">Flat 2</button>
      <button type="button" id="bVer" aria-pressed="true">Flat 1</button>''', '''      <button type="button" id="bVer3" aria-pressed="true">Verdieping 3</button>
      <button type="button" id="bVer2" aria-pressed="true">Verdieping 2</button>
      <button type="button" id="bVer" aria-pressed="true">Verdieping 1</button>''')
rep('<button type="button" id="bInzak" class="klein">Flat 2 inzakken</button>', '<button type="button" id="bInzak" class="klein">Verdieping 3 inzakken</button>')
rep('cam.position.set(17, 15, 22);', 'cam.position.set(22, 19, 29);')
rep('ctl.target.set(0, 4.0, 0);', 'ctl.target.set(0, 5.5, 0);')
rep('ctl.minDistance = 5; ctl.maxDistance = 60;', 'ctl.minDistance = 6; ctl.maxDistance = 70;')
rep('new THREE.CircleGeometry(40, 48)', 'new THREE.CircleGeometry(48, 48)')
rep('Object.assign(zon.shadow.camera, {left: -18, right: 18, top: 18, bottom: -18, near: 1, far: 70});', 'Object.assign(zon.shadow.camera, {left: -22, right: 22, top: 22, bottom: -22, near: 1, far: 90});')
rep('const st = {dak: true, ver: true, ver2: true, deur: false, nacht: false, sloop: false};', 'const st = {dak: true, ver: true, ver2: true, ver3: true, deur: false, nacht: false, sloop: false};')
rep('knoop("Ruine").visible = false;\n  for (const n of ["DeurVoor", "DeurAchter", "DeurBinnen0", "DeurBinnen1", "DeurBinnen2"])',
    'knoop("Ruine").visible = false;\n  for (const n of ["DeurVoor", "DeurAchter", "DeurBinnen0", ..."123".split("").flatMap(v => "abcd".split("").map(l => "DeurBinnen" + v + l))])')
rep('''  // vijf muurstukken van de winkel weg: alles stort in; vijf van flat 1 weg: flat 2 en het dak zakken in
  const weg0 = segs.filter(x => /^M0/.test(x.node.name) && x.staat === 2).length;
  const weg1 = segs.filter(x => /^M1/.test(x.node.name) && x.staat === 2).length;
  if (weg0 >= 5) instorten(); else if (weg1 >= 5) inzakken();''', '''  // zes muurstukken van de lobby weg: alles stort in; vijf van een verdieping weg: alles erboven zakt in
  const weg = v => segs.filter(x => new RegExp("^M" + v).test(x.node.name) && x.staat === 2).length;
  if (weg(0) >= 6) instorten(); else if (weg(2) >= 5) inzakken(3); else if (weg(1) >= 5) inzakken(2);''')
a = tpl.index('let ingezakt = false, ingestort = false;')
b = tpl.index('function allesKapot()')
tpl = tpl[:a] + '''let val = 99, ingestort = false;
function inzakken(k) {
  if (ingestort || k >= val) return;
  val = k;
  for (let j = k; j <= 3; j++) {
    const v = seg("Vloer" + j); if (v) zet(v, 1);
    const g = knoop(j === 1 ? "Verdieping" : "Verdieping" + j);
    g.children.forEach(c => { if (/^(Inrichting|DeurBinnen)/.test(c.name)) c.visible = false; });
    for (const s of segs) if (new RegExp("^(M|P)" + j).test(s.node.name) && s.staat < 2) zet(s, Math.random() < .55 ? 2 : 1);
  }
  zet(seg("Dak"), 2);
  hoop("PuinGroot", new THREE.Vector3(2.4, k === 2 ? 6.8 : 9.8, 0.4), 0.3, 1.0);
  hoop("PuinGroot", new THREE.Vector3(-2.6, 0, 6.2), 2.0, 1.0);
  hoop("PuinKlein", new THREE.Vector3(6.2, 0, 1.5), 1.0, 1.0);
  stof(new THREE.Vector3(0, k === 2 ? 9 : 12, 0), 30, 8);
  teller();
}
function instorten() {
  if (ingestort) return;
  ingestort = true;
  for (const n of ["Begane", "Verdieping", "Verdieping2", "Verdieping3", "Dak"]) knoop(n).visible = false;
  for (const m of losse) scene.remove(m);
  losse = [];
  knoop("Ruine").visible = true;
  for (let k = 0; k < 5; k++) stof(new THREE.Vector3(0, 1 + k * 2.4, 0), 18, 9);
  document.getElementById("teller").innerHTML = "Het hele gebouw is <b>ingestort</b>";
}
function herstel() {
  for (const s of segs) zet(s, 0);
  for (const m of losse) scene.remove(m);
  losse = [];
  val = 99; ingestort = false;
  knoop("Ruine").visible = false;
  for (const n of ["Begane", "Dak", "Verdieping", "Verdieping2", "Verdieping3"]) {
    const g = knoop(n); g.visible = true;
    g.children.forEach(c => { if (/^(Inrichting|DeurBinnen)/.test(c.name)) c.visible = true; });
  }
  pasZicht(); teller();
}
''' + tpl[b:]
a = tpl.index('function pasZicht() {')
b = tpl.index('// --- tikken ---')
tpl = tpl[:a] + '''function pasZicht() {
  if (ingestort) return;
  const dak = knoop("Dak"), ver = knoop("Verdieping"), ver2 = knoop("Verdieping2"), ver3 = knoop("Verdieping3");
  if (dak) dak.visible = st.dak;
  if (ver3) ver3.visible = st.ver3;
  if (ver2) ver2.visible = st.ver2;
  if (ver) ver.visible = st.ver;
}

''' + tpl[b:]
rep('''knop("bVer2", b => { toggle(b, "ver2"); if (!st.ver2) uit("dak", "bDak"); else aan("ver", "bVer"); pasZicht(); });
knop("bVer", b => { toggle(b, "ver"); if (!st.ver) { uit("dak", "bDak"); uit("ver2", "bVer2"); } pasZicht(); });''', '''knop("bVer3", b => { toggle(b, "ver3"); if (!st.ver3) uit("dak", "bDak"); else { aan("ver2", "bVer2"); aan("ver", "bVer"); } pasZicht(); });
knop("bVer2", b => { toggle(b, "ver2"); if (!st.ver2) { uit("dak", "bDak"); uit("ver3", "bVer3"); } else aan("ver", "bVer"); pasZicht(); });
knop("bVer", b => { toggle(b, "ver"); if (!st.ver) { uit("dak", "bDak"); uit("ver2", "bVer2"); uit("ver3", "bVer3"); } pasZicht(); });''')
rep('knop("bInzak", () => inzakken());', 'knop("bInzak", () => inzakken(3));')
rep('hoop(s.node.name.startsWith("T_") || s.node.name.startsWith("P") ? "PuinKlein" : "PuinGroot", voet, Math.random() * 6, s.node.name.startsWith("T_") ? 0.7 : 0.8);', 'hoop(s.node.name.startsWith("P") ? "PuinKlein" : "PuinGroot", voet, Math.random() * 6, 0.8);')
open(sys.argv[3], "w").write(tpl.replace("@@GLB@@", glb))
