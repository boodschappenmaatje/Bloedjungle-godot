// Controle van de vijandelijke tank in de VQ2-viewer: echte GLB, clips Rijden-loop, Draaien-loop en Vuren met zichtbare beweging, koepel- en kanonschuif, rupsen die lopen, 360° en gamecamera.
import {chromium} from 'playwright-core';
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const mime={'.html':'text/html','.js':'text/javascript','.css':'text/css','.json':'application/json','.glb':'model/gltf-binary','.png':'image/png','.jpg':'image/jpeg'};
const server=http.createServer(async(req,res)=>{try{let rel=decodeURIComponent(new URL(req.url,'http://local').pathname);if(rel.endsWith('/'))rel+='index.html';const file=path.resolve(root,'.'+rel);if(!file.startsWith(root+path.sep))throw Error('path');const data=await fs.readFile(file);res.writeHead(200,{'Content-Type':mime[path.extname(file)]||'application/octet-stream','Content-Length':data.length});res.end(data);}catch{res.writeHead(404);res.end('not found');}});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const url=`http://127.0.0.1:${server.address().port}/tools/blender-vq2-viewer/`;
const browser=await chromium.launch({executablePath:process.env.CHROMIUM||'/opt/pw-browsers/chromium-1243/chrome-linux64/chrome',headless:true,args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const out=path.join(root,'docs/vq2/renders');await fs.mkdir(out,{recursive:true});

const results={browser:'Chromium headless, software WebGL; geen fysieke Safari/iPhone-test',assets:{},errors:[]};
function assert(ok,msg){if(!ok)throw Error(msg);}
async function scrub(page,time){await page.locator('#scrub').evaluate((e,t)=>{e.value=t;e.dispatchEvent(new Event('input',{bubbles:true}));},String(time));await page.waitForTimeout(120);}
const sample=(page,names)=>page.evaluate(ns=>{const o={};for(const n of ns){const x=window.__VQ2_TEST__.node(n);if(x)o[n]={p:x.position.toArray().map(v=>+v.toFixed(3)),q:x.quaternion.toArray().map(v=>+v.toFixed(3)),s:x.scale.toArray().map(v=>+v.toFixed(3))};}return o;},names);
const diff=(a,b)=>Object.keys(a).filter(k=>JSON.stringify(a[k])!==JSON.stringify(b[k]));
async function open(page,asset){await page.selectOption('#asset',asset);await page.waitForFunction(a=>window.__VQ2_TEST__.ready()&&window.__VQ2_TEST__.loaded().asset===a,asset);await page.waitForTimeout(500);}
const WIELEN=['WielL_aandrijf','WielL_w1','WielL_w5','WielL_w9','WielL_spanwiel','WielR_aandrijf','WielR_w1','WielR_w5','WielR_w9','WielR_spanwiel'];
const PLAN={
 vijand_tank:{clips:{'Rijden-loop':WIELEN,'Draaien-loop':WIELEN,Vuren:['KanonMesh']},nodes:['Body','RompMesh','RupsL','RupsR','Toren','TorenMesh','Kanon','KanonMesh','Monding',...WIELEN]},
};
try{
 const page=await browser.newPage({viewport:{width:1280,height:1050}});page.setDefaultTimeout(150000);
 page.on('pageerror',e=>results.errors.push(e.message));
 await page.goto(url+'?asset=vijand_tank');
 await page.waitForFunction(()=>window.__VQ2_TEST__?.ready());
 for(const [asset,plan] of Object.entries(PLAN)){
  await open(page,asset);
  const r={clips:{},nodes:{}};
  const clips=await page.evaluate(()=>window.__VQ2_TEST__.clips());
  assert(clips.length===Object.keys(plan.clips).length,`${asset}: verwacht ${Object.keys(plan.clips).length} clips, kreeg ${clips}`);
  for(const n of plan.nodes){const present=await page.evaluate(x=>!!window.__VQ2_TEST__.node(x),n);assert(present,`${asset}: onderdeel ${n} ontbreekt`);r.nodes[n]=true;}
  for(const [name,nodes] of Object.entries(plan.clips)){
   const clip=clips.find(c=>c===name);assert(clip,`${asset}: clip ${name} ontbreekt (${clips})`);
   await page.selectOption('#clips',clip);await scrub(page,0);const a=await sample(page,nodes);
   const dur=await page.evaluate(()=>Number(document.getElementById('scrub').max));
   // meerdere tijdstippen: niet elk onderdeel beweegt in elk deel van de clip (de giek helt pas in de tweede helft)
   const moved=new Set();
   for(const f of [.2,.45,.7,.85,.97]){await scrub(page,dur*f);for(const k of diff(a,await sample(page,nodes)))moved.add(k);}
   for(const n of nodes)assert(moved.has(n),`${asset}/${name}: ${n} beweegt niet (${[...moved]})`);
   await page.locator('#stage').screenshot({path:path.join(out,`${asset}-viewer-${name.toLowerCase()}.png`)});
   await scrub(page,0);
   r.clips[name]={duration:dur,moved:[...moved]};
  }
  // koepel en kanon: de twee schuiven draaien Toren (Y) en Kanon (X); de rupsen lopen zolang een rijdende clip speelt
  const toren0=await page.evaluate(()=>window.__VQ2_TEST__.node('Toren').rotation.y);
  await page.locator('#tank-toren').evaluate(e=>{e.value='90';e.dispatchEvent(new Event('input',{bubbles:true}));});
  assert(Math.abs(await page.evaluate(()=>window.__VQ2_TEST__.node('Toren').rotation.y)-toren0-Math.PI/2)<.01,`${asset}: de koepelschuif draait Toren niet`);
  await page.locator('#tank-toren').evaluate(e=>{e.value='0';e.dispatchEvent(new Event('input',{bubbles:true}));});
  await page.locator('#tank-loop').evaluate(e=>{e.value='10';e.dispatchEvent(new Event('input',{bubbles:true}));});
  assert(Math.abs(await page.evaluate(()=>window.__VQ2_TEST__.node('Kanon').rotation.x)-10*Math.PI/180)<.01,`${asset}: de kanonschuif kantelt Kanon niet`);
  await page.locator('#tank-loop').evaluate(e=>{e.value='0';e.dispatchEvent(new Event('input',{bubbles:true}));});
  await page.selectOption('#clips','Rijden-loop');await scrub(page,0);
  const rups=()=>page.evaluate(()=>{const n=window.__VQ2_TEST__.node('RupsL');const m=[].concat(n.userData.original)[0];return m.map?m.map.offset.x:null;});
  const off0=await rups();await page.click('#play');await page.waitForTimeout(1200);const off1=await rups();await page.click('#play');
  assert(off0!==null&&off1!==null&&Math.abs(off1-off0)>.001,`${asset}: de rupsen lopen niet (${off0} -> ${off1})`);
  r.rups={voor:off0,na:off1};
  await page.click('#iso');await page.waitForTimeout(200);
  await page.locator('#stage').screenshot({path:path.join(out,`${asset}-viewer-iso.png`)});
  await page.click('#top');await page.waitForTimeout(200);
  await page.locator('#stage').screenshot({path:path.join(out,`${asset}-viewer-gamecamera.png`)});
  const cam0=await page.evaluate(()=>window.__VQ2_TEST__.loaded().camera);
  const box=await page.locator('#canvas').boundingBox();await page.mouse.move(box.x+box.width*.5,box.y+box.height*.5);await page.mouse.down();await page.mouse.move(box.x+box.width*.8,box.y+box.height*.55,{steps:10});await page.mouse.up();await page.waitForTimeout(300);
  assert(JSON.stringify(cam0)!==JSON.stringify(await page.evaluate(()=>window.__VQ2_TEST__.loaded().camera)),`${asset}: 360-orbit werkt niet`);
  r.stats=await page.evaluate(()=>document.getElementById('stats').textContent);
  r.status=await page.evaluate(()=>document.getElementById('status').textContent);
  results.assets[asset]=r;
 }
 results.ok=true;
}catch(e){results.ok=false;results.error=e.message;}
await fs.mkdir(path.join(root,'docs/vq2/results'),{recursive:true});
await fs.writeFile(path.join(root,'docs/vq2/results/vijand-tank-viewer-test.json'),JSON.stringify(results,null,1));
console.log(JSON.stringify(results,null,1));
await browser.close();server.close();process.exit(results.ok?0:1);
