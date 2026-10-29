// Controle van de straaljager in de VQ2-viewer: echte GLB, F-16: vijf echte clips met zichtbare beweging, V1 (oude jet) naast V2, 360° en gamecamera.
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
const sample=page=>page.evaluate(()=>{const o={};for(const n of ['FlaperonL','FlaperonR','StabilisatorL','Naverbrander','Body','GearNeus','GearL']){const x=window.__VQ2_TEST__.node(n);if(x)o[n]={q:x.quaternion.toArray(),s:x.scale.toArray()};}return o;});
const diff=(a,b)=>Object.keys(a).filter(k=>JSON.stringify(a[k])!==JSON.stringify(b[k]));
try{
 const page=await browser.newPage({viewport:{width:1280,height:1050}});
 page.on('pageerror',e=>results.errors.push(e.message));
 await page.goto(url);
 await page.waitForFunction(()=>window.__VQ2_TEST__?.ready());
 await page.selectOption('#asset','straaljager');
 await page.waitForFunction(()=>window.__VQ2_TEST__.ready()&&window.__VQ2_TEST__.loaded().asset==='straaljager');await page.waitForTimeout(300);
 const clips=await page.evaluate(()=>window.__VQ2_TEST__.clips());
 assert(clips.length===5,'verwacht 5 clips, kreeg '+clips.length);
 const expect={Vliegen:['FlaperonL','Naverbrander'],Bocht:['Body','FlaperonL'],Aanval:['Body','FlaperonL'],Rol:['Body','FlaperonR'],Landingsgestel:['GearNeus','GearL']};
 for(const [name,nodes] of Object.entries(expect)){
  const clip=clips.find(c=>c.startsWith(name));assert(clip,'clip ontbreekt: '+name);
  await page.selectOption('#clips',clip);await scrub(page,0);const a=await sample(page);
  const dur=await page.evaluate(()=>Number(document.getElementById('scrub').max));await scrub(page,dur*.45);const b=await sample(page);
  const moved=diff(a,b);for(const n of nodes)assert(moved.includes(n),`${name}: ${n} beweegt niet (${moved})`);
  results.clips[name]={duration:dur,moved};
 }
 assert(await page.evaluate(()=>!document.getElementById('version').disabled),'V1 (oude straaljager) moet kiesbaar zijn');
 await page.click('#top');
 await page.screenshot({path:path.join(out,'straaljager-viewer-heel.png')});
 await page.click('#iso');await page.waitForTimeout(150);await page.locator('#stage').screenshot({path:path.join(out,'straaljager-viewer-gamecamera.png')});
 const cam0=await page.evaluate(()=>window.__VQ2_TEST__.loaded().camera);
 const box=await page.locator('#canvas').boundingBox();await page.mouse.move(box.x+box.width*.5,box.y+box.height*.5);await page.mouse.down();await page.mouse.move(box.x+box.width*.8,box.y+box.height*.55,{steps:10});await page.mouse.up();await page.waitForTimeout(300);
 assert(JSON.stringify(cam0)!==JSON.stringify(await page.evaluate(()=>window.__VQ2_TEST__.loaded().camera)),'orbit werkt niet');
 results.stats=await page.evaluate(()=>document.getElementById('stats').textContent);
 results.ok=true;
}catch(e){results.ok=false;results.error=e.message;try{results.loading=await (await browser.contexts()[0].pages())[0].locator('#loading').textContent();}catch{}}
await fs.writeFile(path.join(root,'docs/vq2/results/straaljager-viewer-test.json'),JSON.stringify(results,null,1));
console.log(JSON.stringify(results,null,1));
await browser.close();server.close();process.exit(results.ok?0:1);
