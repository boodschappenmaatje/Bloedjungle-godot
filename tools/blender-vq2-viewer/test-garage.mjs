// Controle van de nieuwe garage (Meshy-motorpool) in de VQ2-viewer: echte GLB, oud/nieuw, gamecamera, LOD-keuze en de echte
// deurclips Open, Dicht en Show-loop. Alleen Chromium met software-WebGL; geen fysieke Safari/iPhone-test.
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
 await page.selectOption('#asset','garage');
 await page.waitForFunction(()=>window.__VQ2_TEST__.ready()&&window.__VQ2_TEST__.loaded().asset==='garage',null,{timeout:120000});await page.waitForTimeout(500);
 const clips=await page.evaluate(()=>window.__VQ2_TEST__.clips());results.clips=clips;
 for(const c of ['Open','Dicht','Show-loop'])assert(clips.includes(c),'clip ontbreekt: '+c);
 assert(!(await page.locator('#play').isDisabled()),'Play-knop niet actief');
 assert(await page.locator('#garage-row').isVisible(),'LOD-keuze niet zichtbaar');
 for(const v of ['v2','v1','split']){
  await page.selectOption('#version',v);await page.waitForTimeout(700);await page.waitForFunction(()=>window.__VQ2_TEST__.ready());
  results.stats[v]=await page.evaluate(()=>document.getElementById('stats').textContent);
  await page.click('#iso');await page.waitForTimeout(250);await page.locator('#stage').screenshot({path:path.join(out,`garage-viewer-${v}.png`)});
 }
 await page.selectOption('#version','v2');await page.waitForTimeout(500);
 assert(/Motorpool \d/.test(results.stats.v2),'statistiek garage ontbreekt: '+results.stats.v2);
 await page.click('#top');await page.waitForTimeout(250);await page.locator('#stage').screenshot({path:path.join(out,'garage-viewer-gamecamera.png')});
 // LOD: precies één romp zichtbaar
 const vis=()=>page.evaluate(()=>[window.__VQ2_TEST__.node('Romp').visible,window.__VQ2_TEST__.node('Romp_LOD1').visible]);
 const l0=await vis();await page.selectOption('#garage-lod','lod1');await page.waitForTimeout(200);const l1=await vis();
 assert(l0[0]&&!l0[1]&&!l1[0]&&l1[1],'LOD-keuze wisselt de romp niet '+JSON.stringify([l0,l1]));
 results.lod1=await page.evaluate(()=>document.getElementById('stats').textContent);
 await page.selectOption('#garage-lod','lod0');
 // clip Open: beide deuren draaien naar buiten
 const rot=()=>page.evaluate(()=>[window.__VQ2_TEST__.node('DeurL').rotation.y,window.__VQ2_TEST__.node('DeurR').rotation.y]);
 await page.selectOption('#clips','Open');await page.waitForTimeout(200);
 await page.click('#restart');await page.waitForTimeout(600);results.openHalf=await rot();
 await page.locator('#scrub').fill('2');await page.waitForTimeout(200);
 const o=await rot();results.open=o;
 assert(Math.abs(Math.abs(o[0])-88*Math.PI/180)<0.05&&Math.abs(Math.abs(o[1])-88*Math.PI/180)<0.05&&Math.sign(o[0])!==Math.sign(o[1]),'deuren niet 88° open '+JSON.stringify(o));
 await page.click('#iso');await page.waitForTimeout(250);await page.locator('#stage').screenshot({path:path.join(out,'garage-viewer-open.png')});
 await page.selectOption('#clips','Dicht');await page.waitForTimeout(100);await page.locator('#scrub').fill('2');await page.waitForTimeout(200);
 const d=await rot();results.dicht=d;assert(Math.abs(d[0])<0.05&&Math.abs(d[1])<0.05,'deuren niet dicht na Dicht '+JSON.stringify(d));
 assert(results.errors.length===0,'paginafouten: '+results.errors.join('; '));
 results.ok=true;
}catch(e){results.ok=false;results.error=e.message;}
await fs.mkdir(path.join(root,'docs/vq2/results'),{recursive:true});
await fs.writeFile(path.join(root,'docs/vq2/results/garage-viewer-test.json'),JSON.stringify(results,null,1));
console.log(JSON.stringify(results,null,1));
await browser.close();server.close();process.exit(results.ok?0:1);
