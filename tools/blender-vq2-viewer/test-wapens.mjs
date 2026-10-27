// Controle van de wapens in de VQ2-viewer: echte GLB, zes echte clips (slede, repeerknop, sluiting, pomp, repeergreep), wapenkeuze, 360° en gamecamera.
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
const results={browser:'Chromium headless, software WebGL; geen fysieke Safari/iPhone-test',clips:{},errors:[]};
function assert(ok,msg){if(!ok)throw Error(msg);}
async function scrub(page,time){await page.locator('#scrub').evaluate((e,t)=>{e.value=t;e.dispatchEvent(new Event('input',{bubbles:true}));},String(time));await page.waitForTimeout(100);}
const pos=(page,n)=>page.evaluate(n=>{const x=window.__VQ2_TEST__.node(n);return x?x.position.toArray():null;},n);
// wapen -> [clip, bewegend deel, verwachte verschuiving in m]
const CASES={M1911:['schot','M1911_Slede',.034],Thompson:['schot','Thompson_Repeerknop',.022],Garand:['schot','Garand_Sluiting',.045],Trench:['schot','Trench_Pomp',.07],MG42:['schot','MG42_Repeergreep',.03]};
try{
 const page=await browser.newPage({viewport:{width:1280,height:1050}});
 page.on('pageerror',e=>results.errors.push(e.message));
 await page.goto(url);
 await page.waitForFunction(()=>window.__VQ2_TEST__?.ready());
 await page.selectOption('#asset','wapens');
 await page.waitForFunction(()=>window.__VQ2_TEST__.ready()&&window.__VQ2_TEST__.loaded().asset==='wapens');await page.waitForTimeout(300);
 const all=await page.evaluate(()=>window.__VQ2_TEST__.clips());
 assert(all.length===6,'verwacht 6 clips, kreeg '+all.join());
 for(const [gun,[clip,node,dist]] of Object.entries(CASES)){
  await page.selectOption('#gun',gun);await page.waitForTimeout(250);
  const list=await page.evaluate(()=>[...document.querySelectorAll('#clips option')].map(o=>o.value));
  assert(list.includes(gun+'_'+clip),`${gun}: clip ${clip} ontbreekt in de lijst (${list})`);
  await page.selectOption('#clips',gun+'_'+clip);
  await scrub(page,0);const a=await pos(page,node);
  const dur=await page.evaluate(()=>Number(document.getElementById('scrub').max));
  let best=0;for(let k=1;k<=12;k++){await scrub(page,dur*k/12);const b=await pos(page,node);best=Math.max(best,Math.abs(b[2]-a[2])+Math.abs(b[1]-a[1])+Math.abs(b[0]-a[0]));}
  assert(Math.abs(best-dist)<.004,`${gun}: ${node} schuift ${best.toFixed(3)} m (verwacht ${dist})`);
  results.clips[gun+'_'+clip]={duration:dur,moved_m:Number(best.toFixed(4))};
  await scrub(page,dur*.3);
  await page.locator('#stage').screenshot({path:path.join(out,`wapens-viewer-${gun}.png`)});
 }
 // pistool met open slede (clip "leeg") en een wapen zonder clips
 await page.selectOption('#gun','M1911');await page.waitForTimeout(250);
 assert((await page.evaluate(()=>[...document.querySelectorAll('#clips option')].map(o=>o.value))).includes('M1911_leeg'),'M1911_leeg ontbreekt');
 await page.selectOption('#gun','Bazooka');await page.waitForTimeout(250);
 assert(await page.locator('#play').isDisabled(),'bazooka toont een Play-knop zonder clip');
 results.bazooka='geen clips, Play uitgeschakeld';
 await page.selectOption('#gun','Garand');await page.waitForTimeout(250);
 await page.click('#iso');await page.waitForTimeout(150);await page.screenshot({path:path.join(out,'wapens-viewer-heel.png')});
 await page.click('#top');await page.waitForTimeout(150);await page.locator('#stage').screenshot({path:path.join(out,'wapens-viewer-gamecamera.png')});
 const cam0=await page.evaluate(()=>window.__VQ2_TEST__.loaded().camera);
 const box=await page.locator('#canvas').boundingBox();await page.mouse.move(box.x+box.width*.5,box.y+box.height*.5);await page.mouse.down();await page.mouse.move(box.x+box.width*.8,box.y+box.height*.55,{steps:10});await page.mouse.up();await page.waitForTimeout(300);
 assert(JSON.stringify(cam0)!==JSON.stringify(await page.evaluate(()=>window.__VQ2_TEST__.loaded().camera)),'orbit werkt niet');
 results.stats=await page.evaluate(()=>document.getElementById('stats').textContent);
 results.ok=true;
}catch(e){results.ok=false;results.error=e.message;try{results.loading=await (await browser.contexts()[0].pages())[0].locator('#loading').textContent();}catch{}}
await fs.writeFile(path.join(root,'docs/vq2/results/wapens-viewer-test.json'),JSON.stringify(results,null,1));
console.log(JSON.stringify(results,null,1));
await browser.close();server.close();process.exit(results.ok?0:1);
