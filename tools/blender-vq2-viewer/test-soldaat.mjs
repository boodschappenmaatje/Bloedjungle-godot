// Controle van de soldaat in de VQ2-viewer: V1 en VQ2 laden, alle 17 echte clips (ook klimmen, zitten en acties) bewegen
// het skelet, elke rol toont precies zijn lichaam en uitrusting, naast-elkaar-weergave, gamecamera en 360°.
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
const results={browser:'Chromium headless, software WebGL; geen fysieke Safari/iPhone-test',clips:{},looks:{},errors:[]};
function assert(ok,msg){if(!ok)throw Error(msg);}
async function scrub(page,time){await page.locator('#scrub').evaluate((e,t)=>{e.value=t;e.dispatchEvent(new Event('input',{bubbles:true}));},String(time));await page.waitForTimeout(80);}
const LOOKS={eigen:['Helm','Koppel','Laarzen','Lijf_Uniform','Rugzak','Vest'],'speler:bloot':['Hoofdband','Koppel','Laarzen','Lijf_Bloot'],'vijand:knife':['Bandana','Laarzen_V','Lijf_Vijand'],'vijand:rifle':['Boonie','Borsttuig','Laarzen_V','Lijf_Vijand'],'vijand:rocket':['Laarzen_V','Lijf_Vijand','Pet','Raketzak'],'vijand:heavy':['Laarzen_V','Lijf_Vijand','Patroongordels','Staalhelm']};
try{
 const page=await browser.newPage({viewport:{width:1280,height:1050}});
 page.on('pageerror',e=>results.errors.push(e.message));
 await page.goto(url);
 await page.waitForFunction(()=>window.__VQ2_TEST__?.ready());
 await page.selectOption('#asset','soldaat');
 await page.waitForFunction(()=>window.__VQ2_TEST__.ready()&&window.__VQ2_TEST__.loaded().asset==='soldaat',null,{timeout:60000});await page.waitForTimeout(300);
 const clips=await page.evaluate(()=>window.__VQ2_TEST__.clips());
 for(const c of ['stil','lopen','rennen','achteruit','schieten','geraakt','dood1','dood2','steken','herladen','klimmen','zitten','rollen','sprinten','explosie_dood','brand_rennen','brand_val'])assert(clips.includes(c),'clip ontbreekt: '+c);
 const B=()=>page.evaluate(()=>[window.__VQ2_TEST__.bone('DEF-thighL'),window.__VQ2_TEST__.bone('DEF-upper_armR'),window.__VQ2_TEST__.bone('DEF-spine002')]);
 const ang=(a,b)=>Math.max(...a.map((q,i)=>Math.acos(Math.min(1,Math.abs(q.reduce((s,v,k)=>s+v*b[i][k],0))))*2));
 await page.selectOption('#clips','stil');await scrub(page,0);const ref=await B();
 for(const c of clips){
  await page.selectOption('#clips',c);await scrub(page,0);
  const a=await page.evaluate(()=>[window.__VQ2_TEST__.bone('DEF-thighL'),window.__VQ2_TEST__.bone('DEF-upper_armR'),window.__VQ2_TEST__.bone('DEF-spine002')]);
  const dur=await page.evaluate(()=>Number(document.getElementById('scrub').max));await scrub(page,dur*.5);
  const b=await page.evaluate(()=>[window.__VQ2_TEST__.bone('DEF-thighL'),window.__VQ2_TEST__.bone('DEF-upper_armR'),window.__VQ2_TEST__.bone('DEF-spine002')]);
  const moved=ang(a,b),pose=ang(b,ref);
  // een clip beweegt in de tijd, of is een eigen houding (zitten) die duidelijk anders is dan stil
  assert(moved>0.02||(c!=='stil'&&pose>0.2),`${c}: skelet beweegt niet`);results.clips[c]={duration:+dur.toFixed(3),rotation_in_clip_rad:+moved.toFixed(3),pose_vs_stil_rad:+pose.toFixed(3)};
 }
 for(const [look,want] of Object.entries(LOOKS)){
  await page.selectOption('#look',look);await page.waitForTimeout(100);
  const got=await page.evaluate(()=>window.__VQ2_TEST__.visible());
  assert(JSON.stringify(got)===JSON.stringify(want),`${look}: zichtbaar ${got}, verwacht ${want}`);results.looks[look]=got;
 }
 await page.selectOption('#look','eigen');await page.selectOption('#clips','stil');await scrub(page,.1);
 await page.selectOption('#version','split');await page.waitForTimeout(200);
 await page.locator('#stage').screenshot({path:path.join(out,'soldaat-viewer-v1-vq2.png')});
 for(const look of ['speler:bloot','vijand:rifle','vijand:heavy']){await page.selectOption('#look',look);await page.waitForTimeout(150);await page.locator('#stage').screenshot({path:path.join(out,`soldaat-viewer-${look.replace(':','-')}.png`)});}
 await page.click('#top');await page.waitForTimeout(150);await page.locator('#stage').screenshot({path:path.join(out,'soldaat-viewer-gamecamera.png')});
 const cam0=await page.evaluate(()=>window.__VQ2_TEST__.loaded().camera);
 const box=await page.locator('#canvas').boundingBox();await page.mouse.move(box.x+box.width*.5,box.y+box.height*.5);await page.mouse.down();await page.mouse.move(box.x+box.width*.8,box.y+box.height*.55,{steps:10});await page.mouse.up();await page.waitForTimeout(300);
 assert(JSON.stringify(cam0)!==JSON.stringify(await page.evaluate(()=>window.__VQ2_TEST__.loaded().camera)),'orbit werkt niet');
 results.stats=await page.evaluate(()=>document.getElementById('stats').textContent);
 assert(results.errors.length===0,'paginafouten: '+results.errors.join('; '));
 results.ok=true;
}catch(e){results.ok=false;results.error=e.message;}
await fs.writeFile(path.join(root,'docs/vq2/results/soldaat-viewer-test.json'),JSON.stringify(results,null,1));
console.log(JSON.stringify({ok:results.ok,error:results.error,clips:Object.keys(results.clips).length,looks:Object.keys(results.looks).length,stats:results.stats,errors:results.errors},null,1));
await browser.close();server.close();process.exit(results.ok?0:1);
