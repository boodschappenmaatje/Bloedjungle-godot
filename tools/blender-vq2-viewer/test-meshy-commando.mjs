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
 const page=await browser.newPage({viewport:{width:900,height:900}});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(`http://127.0.0.1:${server.address().port}/tools/blender-vq2-viewer/index.html?asset=meshy_commando`);
 await page.waitForFunction(()=>window.__VQ2_TEST__?.ready()&&window.__VQ2_TEST__.loaded().asset==='meshy_commando',null,{timeout:45000});
 await page.selectOption('#version','split');
 const result=await page.evaluate(()=>({clips:window.__VQ2_TEST__.clips(),version:window.__VQ2_TEST__.loaded().version,materials:window.__VQ2_TEST__.loaded().materials,helmet:!!window.__VQ2_TEST__.node('High-cut olive helmet shell')}));
 if(result.version!=='split'||!result.helmet||result.materials.length<6||!result.clips.some(c=>c.includes('Running'))||errors.length)throw Error(JSON.stringify({result,errors}));
 await fs.mkdir(path.join(root,'previews/meshy_commando'),{recursive:true});
 await page.locator('#stage').screenshot({path:path.join(root,'previews/meshy_commando/viewer_before_after.png')});
 await page.selectOption('#clips','Running');
 const before=await page.evaluate(()=>window.__VQ2_TEST__.node('mixamorig:LeftUpLeg')?.quaternion.toArray());
 await page.locator('#scrub').evaluate(e=>{e.value='0.22';e.dispatchEvent(new Event('input',{bubbles:true}));});await page.waitForTimeout(100);
 const after=await page.evaluate(()=>window.__VQ2_TEST__.node('mixamorig:LeftUpLeg')?.quaternion.toArray());
 if(!before||!after||Math.hypot(...before.map((v,i)=>v-after[i]))<.02)throw Error('Running clip does not move left leg');
 console.log('MESHY COMMANDO VIEWER: PASS',JSON.stringify({clips:result.clips,materials:result.materials.length,legAnimated:true}));
}finally{await browser.close();server.close();}
