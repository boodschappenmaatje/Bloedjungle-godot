// Controle van de poortwachtpost (slagboom + wachthuis) in de VQ2-viewer: echte GLB, keuze per onderdeel, echte clip Open (arm draait zichtbaar), 360° en gamecamera.
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
const results={stats:{},browser:'Chromium headless, software WebGL; geen fysieke Safari/iPhone-test',clips:{},errors:[]};
function assert(ok,msg){if(!ok)throw Error(msg);}
async function scrub(page,time){await page.locator('#scrub').evaluate((e,t)=>{e.value=t;e.dispatchEvent(new Event('input',{bubbles:true}));},String(time));await page.waitForTimeout(150);}
const rot=(page,n)=>page.evaluate(n=>{const x=window.__VQ2_TEST__.node(n);return x?x.quaternion.toArray():null;},n);
try{
 const page=await browser.newPage({viewport:{width:1280,height:1050}});
 page.on('pageerror',e=>results.errors.push(e.message));
 await page.goto(url);
 await page.waitForFunction(()=>window.__VQ2_TEST__?.ready());
 await page.selectOption('#asset','wachtpost');
 await page.waitForFunction(()=>window.__VQ2_TEST__.ready()&&window.__VQ2_TEST__.loaded().asset==='wachtpost');await page.waitForTimeout(400);
 const clips=await page.evaluate(()=>window.__VQ2_TEST__.clips());
 assert(clips.length===1&&clips[0].name==='Open'||clips.length===1&&clips[0]==='Open','één echte clip Open verwacht, kreeg '+JSON.stringify(clips));
 for(const p of ['beide','Slagboom','Wachthuis']){
  await page.selectOption('#post',p);await page.waitForTimeout(300);
  const st=await page.evaluate(()=>document.getElementById('stats').textContent);
  assert(!/ 0 texturen/.test(st),`${p}: geen texturen geladen (${st})`);
  results.stats[p]=st;
  await page.click('#iso');await page.waitForTimeout(150);await page.locator('#stage').screenshot({path:path.join(out,`wachtpost-viewer-${p}.png`)});
 }
 await page.selectOption('#post','Slagboom');await page.waitForTimeout(200);
 await page.selectOption('#clips','Open');await page.waitForTimeout(200);
 await scrub(page,0);const q0=await rot(page,'Boom');
 await page.locator('#scrub').evaluate(e=>{e.value=e.max;e.dispatchEvent(new Event('input',{bubbles:true}));});await page.waitForTimeout(200);const q1=await rot(page,'Boom');
 assert(q0&&q1,'knoop Boom niet gevonden');
 const d=Math.hypot(...q0.map((v,i)=>v-q1[i]));assert(d>0.5,`arm beweegt niet (verschil ${d.toFixed(2)})`);
 results.clips.Open={start:q0,eind:q1,verschil:d};
 await page.click('#play');await page.waitForTimeout(300);await page.click('#play');
 await page.selectOption('#post','beide');await page.click('#top');await page.waitForTimeout(150);await page.locator('#stage').screenshot({path:path.join(out,'wachtpost-viewer-gamecamera.png')});
 const cam0=await page.evaluate(()=>window.__VQ2_TEST__.loaded().camera);
 const box=await page.locator('#canvas').boundingBox();await page.mouse.move(box.x+box.width*.5,box.y+box.height*.5);await page.mouse.down();await page.mouse.move(box.x+box.width*.8,box.y+box.height*.55,{steps:10});await page.mouse.up();await page.waitForTimeout(300);
 assert(JSON.stringify(cam0)!==JSON.stringify(await page.evaluate(()=>window.__VQ2_TEST__.loaded().camera)),'orbit werkt niet');
 results.ok=true;
}catch(e){results.ok=false;results.error=e.message;}
await fs.writeFile(path.join(root,'docs/vq2/results/wachtpost-viewer-test.json'),JSON.stringify(results,null,1));
console.log(JSON.stringify(results,null,1));
await browser.close();server.close();process.exit(results.ok?0:1);
