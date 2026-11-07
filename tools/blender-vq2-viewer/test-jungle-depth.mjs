// Real GLB review: the three new foliage silhouettes, their exported maps and all LODs.
import {chromium} from 'playwright-core';
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const mime={'.html':'text/html','.js':'text/javascript','.css':'text/css','.json':'application/json','.glb':'model/gltf-binary','.png':'image/png','.jpg':'image/jpeg'};
const server=http.createServer(async(req,res)=>{try{let rel=decodeURIComponent(new URL(req.url,'http://local').pathname);if(rel.endsWith('/'))rel+='index.html';const file=path.resolve(root,'.'+rel);if(!file.startsWith(root+path.sep))throw Error('path');const data=await fs.readFile(file);res.writeHead(200,{'Content-Type':mime[path.extname(file)]||'application/octet-stream','Content-Length':data.length});res.end(data);}catch{res.writeHead(404);res.end('not found');}});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const url=`http://127.0.0.1:${server.address().port}/tools/blender-vq2-viewer/?asset=jungle_depth_foliage`;
const browser=await chromium.launch({executablePath:process.env.CHROMIUM||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const results={browser:'Chromium software WebGL; not an iPhone/Safari or game-camera test',species:{},errors:[]};
const assert=(ok,msg)=>{if(!ok)throw Error(msg);};
try{
 const page=await browser.newPage({viewport:{width:1280,height:900}});
 page.on('pageerror',e=>results.errors.push(e.message));
 page.on('console',m=>{if(m.type()==='error'&&!m.text().includes('docs/vq2/results/asset-report.json')&&!m.text().includes('responded with a status of 404'))results.errors.push(m.text());});
 page.on('requestfailed',r=>results.errors.push(`${r.url()} ${r.failure()?.errorText}`));
 await page.goto(url);await page.waitForTimeout(8000);
 results.loading=await page.locator('#loading').textContent();results.status=await page.locator('#status').textContent();
 assert(await page.evaluate(()=>window.__VQ2_TEST__?.ready()&&window.__VQ2_TEST__.loaded().asset==='jungle_depth_foliage'),'Game asset did not load: '+results.loading+' / '+results.status);
 assert(await page.locator('#jungle-depth-row').isVisible(),'LOD/species controls are visible');
 assert((await page.evaluate(()=>window.__VQ2_TEST__.clips())).length===0,'static foliage should not invent animation clips');
 const expected={rosette:[648,56,10],arch_fern:[864,392,200],red_bloom:[1108,366,102]};
 for(const species of Object.keys(expected)){
  await page.selectOption('#jungle-depth-species',species);results.species[species]={lods:{}};
  for(let lod=0;lod<3;lod++){
   await page.selectOption('#jungle-depth-lod',String(lod));await page.waitForTimeout(180);
   const nodeName=`HQ_${species}_LOD${lod}`;
   const info=await page.evaluate(name=>{const n=window.__VQ2_TEST__.node(name);if(!n?.isMesh)return null;const m=Array.isArray(n.material)?n.material[0]:n.material;const g=n.geometry;return{name:n.name,visible:n.visible,triangles:(g.index?g.index.count:g.attributes.position.count)/3,maps:{base:!!m.map,normal:!!m.normalMap,roughness:!!m.roughnessMap,baseSize:m.map?.image?[m.map.image.width,m.map.image.height]:null}};},nodeName);
   assert(info&&info.visible,`Missing visible mesh ${nodeName}`);assert(info.triangles===expected[species][lod],`${nodeName} triangle budget ${info.triangles}`);
   assert(info.maps.base&&info.maps.normal&&info.maps.roughness&&info.maps.baseSize[0]===1024&&info.maps.baseSize[1]===1024,`${nodeName} must carry the shared 1K color/normal/roughness set`);
   results.species[species].lods[lod]=info;
   if(lod===0)await page.waitForTimeout(220);
  }
 }
 results.ok=true;
}catch(e){results.ok=false;results.error=e.message;}
await fs.writeFile(path.join(root,'docs/visual_upgrade_b_1_0/results/foliage-viewer-test.json'),JSON.stringify(results,null,2)+'\n');
console.log(JSON.stringify(results,null,2));await browser.close();server.close();process.exit(results.ok?0:1);
