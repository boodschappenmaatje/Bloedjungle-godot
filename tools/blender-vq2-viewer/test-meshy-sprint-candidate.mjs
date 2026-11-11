import {chromium} from 'playwright-core';
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const mime={'.html':'text/html','.js':'text/javascript','.css':'text/css','.glb':'model/gltf-binary','.png':'image/png','.jpg':'image/jpeg'};
const server=http.createServer(async(req,res)=>{try{const rel=decodeURIComponent(new URL(req.url,'http://local').pathname);const file=path.resolve(root,'.'+rel);if(!file.startsWith(root+path.sep))throw Error('path');const data=await fs.readFile(file);res.writeHead(200,{'Content-Type':mime[path.extname(file)]||'application/octet-stream'});res.end(data);}catch{res.writeHead(404);res.end('not found');}});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const browser=await chromium.launch({executablePath:process.env.CHROMIUM||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
try{
 const page=await browser.newPage({viewport:{width:900,height:900}});const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(`http://127.0.0.1:${server.address().port}/tools/blender-vq2-viewer/index.html?asset=meshy_sprint_candidate`);
 await page.waitForFunction(()=>window.__VQ2_TEST__?.ready()&&window.__VQ2_TEST__.loaded().asset==='meshy_sprint_candidate',null,{timeout:45000});
 await page.selectOption('#version','split');
 const data=await page.evaluate(()=>({clips:window.__VQ2_TEST__.clips(),materials:window.__VQ2_TEST__.loaded().materials.length,hip:window.__VQ2_TEST__.node('Hips')?.quaternion.toArray()}));
 if(!data.clips.includes('retarget_clip')||data.materials<1||!data.hip)throw Error('Candidate GLB or real clip missing: '+JSON.stringify(data));
 await page.selectOption('#clips','retarget_clip');
 const before=await page.evaluate(()=>window.__VQ2_TEST__.node('Hips')?.quaternion.toArray());
 await page.locator('#scrub').evaluate(e=>{e.value='1.0';e.dispatchEvent(new Event('input',{bubbles:true}));});
 const after=await page.evaluate(()=>window.__VQ2_TEST__.node('Hips')?.quaternion.toArray());
 if(!before||!after||Math.hypot(...before.map((v,i)=>v-after[i]))<.02)throw Error('retarget_clip does not move Hips');
 await fs.mkdir(path.join(root,'previews/meshy_commando'),{recursive:true});
 await page.locator('#stage').screenshot({path:path.join(root,'previews/meshy_commando/prime_sprint_candidate.png')});
 if(errors.length)throw Error(errors.join('; '));
 console.log('MESHY PRIME CANDIDATE VIEWER: PASS',JSON.stringify({clips:data.clips,hipMoves:true}));
}finally{await browser.close();server.close();}
