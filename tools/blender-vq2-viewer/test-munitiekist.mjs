// Controle van de Meshy-munitiekist in de VQ2-viewer: echte GLB, V1 (Kist_Munitie uit props.glb) naast Meshy, 360°, gamecamera. Geen clips.
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
 await page.selectOption('#asset','munitiekist');
 await page.waitForFunction(()=>window.__VQ2_TEST__.ready()&&window.__VQ2_TEST__.loaded().asset==='munitiekist');await page.waitForTimeout(400);
 assert((await page.evaluate(()=>window.__VQ2_TEST__.clips())).length===0,'munitiekist mag geen clips hebben');
 assert(await page.locator('#play').isDisabled(),'Play-knop actief zonder clip');
 for(const v of ['v2','v1','split']){
  await page.selectOption('#version',v);await page.waitForTimeout(600);
  await page.waitForFunction(()=>window.__VQ2_TEST__.ready());
  const st=await page.evaluate(()=>document.getElementById('stats').textContent);results.stats[v]=st;
  assert(/Meshy 2\.499 driehoeken/.test(st),`statistiek Meshy klopt niet (${st})`);
  assert(/texturen 1024px/.test(st),`Meshy-texturen niet 1K (${st})`);
  await page.click('#iso');await page.waitForTimeout(200);await page.locator('#stage').screenshot({path:path.join(out,`munitiekist-viewer-${v}.png`)});
 }
 await page.click('#top');await page.waitForTimeout(200);await page.locator('#stage').screenshot({path:path.join(out,'munitiekist-viewer-gamecamera.png')});
 const cam0=await page.evaluate(()=>window.__VQ2_TEST__.loaded().camera);
 const box=await page.locator('#canvas').boundingBox();await page.mouse.move(box.x+box.width*.5,box.y+box.height*.5);await page.mouse.down();await page.mouse.move(box.x+box.width*.8,box.y+box.height*.55,{steps:10});await page.mouse.up();await page.waitForTimeout(300);
 assert(JSON.stringify(cam0)!==JSON.stringify(await page.evaluate(()=>window.__VQ2_TEST__.loaded().camera)),'orbit werkt niet');
 assert(results.errors.length===0,'paginafouten: '+results.errors.join('; '));
 results.ok=true;
}catch(e){results.ok=false;results.error=e.message;}
await fs.writeFile(path.join(root,'docs/vq2/results/munitiekist-viewer-test.json'),JSON.stringify(results,null,1));
console.log(JSON.stringify(results,null,1));
await browser.close();server.close();process.exit(results.ok?0:1);
