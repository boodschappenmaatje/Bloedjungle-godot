// Controle van de P-47 (luchtaanval) en de parachute (parachutisten) in de VQ2-viewer: echte GLB-clips met zichtbare beweging, 360° en gamecamera.
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
const results={browser:'Chromium headless, software WebGL; geen fysieke Safari/iPhone-test',clips:{},phases:[],errors:[]};
function assert(ok,msg){if(!ok)throw Error(msg);}
async function scrub(page,time){await page.locator('#scrub').evaluate((e,t)=>{e.value=t;e.dispatchEvent(new Event('input',{bubbles:true}));},String(time));await page.waitForTimeout(100);}
const sample=page=>page.evaluate(()=>{const o={};for(const n of ['Propeller','ElevatorR','AileronR','Roer','GearR','GearStaart','Body','Parachute']){const x=window.__VQ2_TEST__.node(n);if(x)o[n]={q:x.quaternion.toArray(),p:x.position.toArray()};}
 const z=window.__VQ2_TEST__.node('Zeil');if(z){const m=[];z.traverse(c=>{if(c.morphTargetInfluences)m.push(...c.morphTargetInfluences);});o.Zeil={m};}return o;});
const diff=(a,b)=>Object.keys(a).filter(k=>JSON.stringify(a[k])!==JSON.stringify(b[k]));
async function pick(page,asset){await page.selectOption('#asset',asset);await page.waitForFunction(a=>window.__VQ2_TEST__.ready()&&window.__VQ2_TEST__.loaded().asset===a,asset);await page.waitForTimeout(300);}
try{
 const page=await browser.newPage({viewport:{width:1280,height:1050}});
 page.on('pageerror',e=>results.errors.push(e.message));
 await page.goto(url);
 await page.waitForFunction(()=>window.__VQ2_TEST__?.ready());
 const jobs={
  p47:{n:6,expect:{Stationair:['Propeller'],Vliegen:['Propeller','ElevatorR'],Bocht:['Body','AileronR'],Aanval:['Body','ElevatorR'],Rol:['Body','AileronR'],Landingsgestel:['GearR','GearStaart']}},
  parachute:{n:3,expect:{Openen:['Zeil','Parachute'],Zweven:['Zeil','Parachute'],Inzakken:['Zeil','Parachute']}}};
 for(const [asset,job] of Object.entries(jobs)){
  await pick(page,asset);
  const clips=await page.evaluate(()=>window.__VQ2_TEST__.clips());
  assert(clips.length===job.n,`${asset}: verwacht ${job.n} clips, kreeg ${clips.length} (${clips})`);
  results.clips[asset]={};
  for(const [name,nodes] of Object.entries(job.expect)){
   const clip=clips.find(c=>c.startsWith(name));assert(clip,`${asset}: clip ontbreekt: ${name}`);
   await page.selectOption('#clips',clip);await scrub(page,0);const a=await sample(page);
   const dur=await page.evaluate(()=>Number(document.getElementById('scrub').max));await scrub(page,dur*.45);const b=await sample(page);
   const moved=diff(a,b);for(const n of nodes)assert(moved.includes(n),`${asset}/${name}: ${n} beweegt niet (${moved})`);
   results.clips[asset][name]={duration:dur,moved};
  }
  await page.click('#top');
  await page.screenshot({path:path.join(out,`${asset}-viewer-heel.png`)});
  await page.click('#iso');await page.waitForTimeout(150);await page.locator('#stage').screenshot({path:path.join(out,`${asset}-viewer-gamecamera.png`)});
  const cam0=await page.evaluate(()=>window.__VQ2_TEST__.loaded().camera);
  const box=await page.locator('#canvas').boundingBox();await page.mouse.move(box.x+box.width*.5,box.y+box.height*.5);await page.mouse.down();await page.mouse.move(box.x+box.width*.8,box.y+box.height*.55,{steps:10});await page.mouse.up();await page.waitForTimeout(150);
  assert(JSON.stringify(cam0)!==JSON.stringify(await page.evaluate(()=>window.__VQ2_TEST__.loaded().camera)),`${asset}: orbit werkt niet`);
  results.stats=results.stats||{};results.stats[asset]=await page.evaluate(()=>document.getElementById('stats').textContent);
 }
 results.ok=true;
}catch(e){results.ok=false;results.error=e.message;try{results.loading=await (await browser.contexts()[0].pages())[0].locator('#loading').textContent();}catch{}}
await fs.writeFile(path.join(root,'docs/vq2/results/luchtaanval-viewer-test.json'),JSON.stringify(results,null,1));
console.log(JSON.stringify(results,null,1));
await browser.close();server.close();process.exit(results.ok?0:1);
