// Controle van het hoofdkwartier in de VQ2-viewer: echte GLB, zandzakwal op elk niveau, dikke wal alleen bij niveau 3, vlag met 1/2/3 sterren.
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
async function setNiv(page,n){await page.selectOption('#hk-niv',String(n));await page.waitForTimeout(700);}
const info=(page,name)=>page.evaluate(n=>{const o=window.__VQ2_TEST__.node(n);if(!o)return null;let vis=true,p=o;while(p){if(p.visible===false)vis=false;p=p.parent;}return {vis,src:o.material?.map?.image?.src||null};},name);
try{
 const page=await browser.newPage({viewport:{width:1280,height:1050}});
 page.on('pageerror',e=>results.errors.push(e.message));
 await page.goto(url);
 await page.waitForFunction(()=>window.__VQ2_TEST__?.ready());
 await page.selectOption('#asset','hoofdkwartier');
 await page.waitForFunction(()=>window.__VQ2_TEST__.ready()&&window.__VQ2_TEST__.loaded().asset==='hoofdkwartier');await page.waitForTimeout(600);
 for(const n of [1,2,3]){
  await setNiv(page,n);
  const wal=await info(page,'Zandzakwal'),dik=await info(page,'Niveau3_wal_buiten'),vlag=await info(page,'Doek');
  assert(wal&&wal.vis,`niveau ${n}: zandzakwal moet zichtbaar zijn (sluit de dakrand)`);
  assert(dik&&dik.vis===(n>=3),`niveau ${n}: dikke wal alleen bij niveau 3`);
  await page.waitForFunction(k=>{const o=window.__VQ2_TEST__.node('Doek');const s=o?.material?.map?.image?.src||'';return k===1?!/vlag_s/.test(s):s.includes('vlag_s'+k);},n,{timeout:8000});
  results.stats['niveau'+n]={zandzakwal:wal.vis,dikkeWal:dik.vis,vlag:(await info(page,'Doek')).src};
  await page.locator('#stage').screenshot({path:path.join(out,`hoofdkwartier-viewer-niveau${n}.png`)});
 }
 results.ok=true;
}catch(e){results.ok=false;results.error=e.message;}
await fs.writeFile(path.join(root,'docs/vq2/results/hoofdkwartier-viewer-test.json'),JSON.stringify(results,null,1));
console.log(JSON.stringify(results,null,1));
await browser.close();server.close();process.exit(results.ok?0:1);
