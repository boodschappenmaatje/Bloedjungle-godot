// Controle van de Tiger-tank in de VQ2-viewer: echte GLB, V1 (oude tank) naast de Tiger, 360°, gamecamera, vijf echte clips,
// koepel- en loopschuiven en lopende rupsen. Alleen Chromium met software-WebGL; geen fysieke Safari/iPhone-test.
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
const results={stats:{},browser:'Chromium headless, software WebGL; geen fysieke Safari/iPhone-test',errors:[]};
function assert(ok,msg){if(!ok)throw Error(msg);}
try{
 const page=await browser.newPage({viewport:{width:1280,height:1050}});
 page.on('pageerror',e=>results.errors.push(e.message));
 await page.goto(url);
 await page.waitForFunction(()=>window.__VQ2_TEST__?.ready());
 await page.selectOption('#asset','tank');
 await page.waitForFunction(()=>window.__VQ2_TEST__.ready()&&window.__VQ2_TEST__.loaded().asset==='tank',null,{timeout:120000});await page.waitForTimeout(500);
 const clips=await page.evaluate(()=>window.__VQ2_TEST__.clips());
 results.clips=clips;
 for(const c of ['Stationair-loop','Rijden-loop','Achteruit-loop','Draaien-loop','Schieten'])assert(clips.includes(c),'clip ontbreekt: '+c);
 assert(!(await page.locator('#play').isDisabled()),'Play-knop niet actief');
 assert(await page.locator('#tank-row').isVisible(),'schuiven voor koepel en loop niet zichtbaar');
 for(const v of ['v2','v1','split']){
  await page.selectOption('#version',v);await page.waitForTimeout(700);
  await page.waitForFunction(()=>window.__VQ2_TEST__.ready());
  results.stats[v]=await page.evaluate(()=>document.getElementById('stats').textContent);
  await page.click('#iso');await page.waitForTimeout(250);await page.locator('#stage').screenshot({path:path.join(out,`tiger-viewer-${v}.png`)});
 }
 await page.selectOption('#version','v2');await page.waitForTimeout(500);
 assert(/Tiger \d/.test(results.stats.v2),'statistiek Tiger ontbreekt: '+results.stats.v2);
 await page.click('#top');await page.waitForTimeout(250);await page.locator('#stage').screenshot({path:path.join(out,'tiger-viewer-gamecamera.png')});
 // koepel en loop
 const rot0=await page.evaluate(()=>{const t=window.__VQ2_TEST__.node('Toren'),l=window.__VQ2_TEST__.node('Loop');return[t.rotation.y,l.rotation.x];});
 await page.locator('#tank-toren').fill('90');await page.locator('#tank-loop').fill('12');await page.waitForTimeout(200);
 const rot1=await page.evaluate(()=>{const t=window.__VQ2_TEST__.node('Toren'),l=window.__VQ2_TEST__.node('Loop');return[t.rotation.y,l.rotation.x];});
 assert(Math.abs(rot1[0]-Math.PI/2)<0.01&&Math.abs(rot1[1]-12*Math.PI/180)<0.01&&rot0[0]===0,'schuiven bewegen koepel/loop niet '+JSON.stringify([rot0,rot1]));
 await page.click('#iso');await page.waitForTimeout(250);await page.locator('#stage').screenshot({path:path.join(out,'tiger-viewer-koepel-loop.png')});
 // clip Rijden: wielen draaien en rupsen lopen
 await page.selectOption('#clips','Rijden-loop');await page.waitForTimeout(200);
 const sample=()=>page.evaluate(()=>{const w=window.__VQ2_TEST__.node('WielL_w3'),l=window.__VQ2_TEST__.node('RupsL'),r=window.__VQ2_TEST__.node('RupsR');return{wiel:w.quaternion.toArray(),rl:l.userData.original.map.offset.x,rr:r.userData.original.map.offset.x};});
 const a=await sample();
 await page.click('#play');await page.waitForTimeout(900);
 const b=await sample();
 assert(JSON.stringify(a.wiel)!==JSON.stringify(b.wiel),'wiel draait niet in clip Rijden');
 assert(Math.abs(b.rl-a.rl)>0.002&&Math.abs(b.rr-a.rr)>0.002,'rupsen lopen niet in clip Rijden');
 assert(Math.sign(b.rl-a.rl)===Math.sign(b.rr-a.rr)||Math.abs(b.rl-a.rl)>0.5,'rupsen lopen links en rechts verschillend in Rijden');
 await page.selectOption('#clips','Draaien-loop');await page.waitForTimeout(100);
 const c=await sample();await page.click('#restart');await page.waitForTimeout(900);const d=await sample();
 assert(Math.sign(d.rl-c.rl)!==Math.sign(d.rr-c.rr),'rupsen in Draaien lopen niet tegengesteld');
 results.rupsen={rijden:[a,b],draaien:[c,d]};
 const cam0=await page.evaluate(()=>window.__VQ2_TEST__.loaded().camera);
 const box=await page.locator('#canvas').boundingBox();await page.mouse.move(box.x+box.width*.5,box.y+box.height*.5);await page.mouse.down();await page.mouse.move(box.x+box.width*.8,box.y+box.height*.55,{steps:10});await page.mouse.up();await page.waitForTimeout(300);
 assert(JSON.stringify(cam0)!==JSON.stringify(await page.evaluate(()=>window.__VQ2_TEST__.loaded().camera)),'orbit werkt niet');
 assert(results.errors.length===0,'paginafouten: '+results.errors.join('; '));
 results.ok=true;
}catch(e){results.ok=false;results.error=e.message;}
await fs.writeFile(path.join(root,'docs/vq2/results/tank-viewer-test.json'),JSON.stringify(results,null,1));
console.log(JSON.stringify(results,null,1));
await browser.close();server.close();process.exit(results.ok?0:1);
