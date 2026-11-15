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
const out=path.join(root,'docs/dambreuk/captures');await fs.mkdir(out,{recursive:true});
const results={stats:{},browser:'Chromium headless, software WebGL; geen fysieke Safari/iPhone-test',errors:[]};
function assert(ok,msg){if(!ok)throw Error(msg);}
try{
 const page=await browser.newPage({viewport:{width:1280,height:1050}});
 page.on('pageerror',e=>results.errors.push(e.message));
 await page.goto(url);
 await page.waitForFunction(()=>window.__VQ2_TEST__?.ready());
 await page.selectOption('#asset','dam');
 await page.waitForFunction(()=>window.__VQ2_TEST__.ready()&&window.__VQ2_TEST__.loaded().asset==='dam',null,{timeout:180000});await page.waitForTimeout(4000);
 const clips=await page.evaluate(()=>window.__VQ2_TEST__.clips());results.clips=clips;
 for(const c of ['Kraken','Breken'])assert(clips.includes(c),'clip ontbreekt: '+c);
 assert(!(await page.locator('#play').isDisabled()),'Play-knop niet actief');
 results.stats.dam=await page.evaluate(()=>document.getElementById('stats').textContent);
 await page.click('#iso');await page.waitForTimeout(600);await page.locator('#stage').screenshot({path:path.join(out,'dam-viewer-rust.png')});
 // Breken: na 6 s liggen de blokken weg van hun plek
 const pos=()=>page.evaluate(()=>{const n=window.__VQ2_TEST__.node('Blok_4_3');return [n.position.x,n.position.y,n.position.z];});
 const p0=await pos();
 await page.selectOption('#clips','Breken');await page.waitForTimeout(200);await page.locator('#scrub').fill('5.9');await page.waitForTimeout(400);
 const p1=await pos();results.blok={rust:p0,gebroken:p1};
 assert(Math.hypot(p1[0]-p0[0],p1[1]-p0[1],p1[2]-p0[2])>3,'blok valt niet weg in Breken '+JSON.stringify([p0,p1]));
 await page.waitForTimeout(300);await page.locator('#stage').screenshot({path:path.join(out,'dam-viewer-gebroken.png')});
 await page.selectOption('#clips','Kraken');await page.waitForTimeout(200);await page.locator('#scrub').fill('4.9');await page.waitForTimeout(400);
 const sc=await page.evaluate(()=>window.__VQ2_TEST__.node('Kraak_1').scale.x);results.kraak=sc;assert(sc>0.9,'scheur groeit niet '+sc);
 await page.waitForTimeout(300);await page.locator('#stage').screenshot({path:path.join(out,'dam-viewer-kraken.png')});
 assert(results.errors.length===0,'paginafouten: '+results.errors.join('; '));
 results.ok=true;
}catch(e){results.ok=false;results.error=e.message;}
await fs.mkdir(path.join(root,'docs/vq2/results'),{recursive:true});
await fs.writeFile(path.join(root,'docs/vq2/results/dam-viewer-test.json'),JSON.stringify(results,null,1));
console.log(JSON.stringify(results,null,1));
await browser.close();server.close();process.exit(results.ok?0:1);
