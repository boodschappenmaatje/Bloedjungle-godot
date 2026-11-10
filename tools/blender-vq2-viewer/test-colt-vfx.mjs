import {chromium} from 'playwright-core';
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const mime={'.html':'text/html','.js':'text/javascript','.css':'text/css','.glb':'model/gltf-binary','.png':'image/png'};
const server=http.createServer(async(req,res)=>{
 try{let rel=decodeURIComponent(new URL(req.url,'http://local').pathname);if(rel.endsWith('/'))rel+='index.html';
  const file=path.resolve(root,'.'+rel);if(!file.startsWith(root+path.sep))throw Error('path');
  const data=await fs.readFile(file);res.writeHead(200,{'Content-Type':mime[path.extname(file)]||'application/octet-stream'});res.end(data);
 }catch{res.writeHead(404);res.end('not found');}
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const browser=await chromium.launch({executablePath:process.env.CHROMIUM||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const output=path.join(root,'docs/vfx/m1911_cinematic_power_1_0/viewer');await fs.mkdir(output,{recursive:true});
let ok=false;
try{
 const page=await browser.newPage({viewport:{width:1280,height:900}});const errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 await page.goto(`http://127.0.0.1:${server.address().port}/tools/blender-vq2-viewer/colt-vfx.html`);
 await page.waitForFunction(()=>window.__COLT_VIEWER_TEST__?.ready(),{timeout:30000});
 const check=(condition,message)=>{if(!condition)throw Error(message)};
 check(await page.evaluate(()=>window.__COLT_VIEWER_TEST__.clip())==='M1911_schot','echte M1911_schot-clip ontbreekt');
 await page.click('#play'); // pause for deterministic sampling
 const sample=async t=>page.evaluate(t=>{window.__COLT_VIEWER_TEST__.setTime(t);return {state:window.__COLT_VIEWER_TEST__.state(),slide:window.__COLT_VIEWER_TEST__.slide()};},t);
 const at0=await sample(0),atFlash=await sample(.055),atFlight=await sample(.14),atHit=await sample(.3);
 check(atFlash.state.flash,'flits ontbreekt');check(atFlight.state.streak,'kogelbaan ontbreekt');
 check(atHit.state.chips>0&&atHit.state.marks>=3,'muurinslag of blijvend spoor ontbreekt');
 check(JSON.stringify(at0.slide)!==JSON.stringify(atFlash.slide),'echte pistoolslede beweegt niet');
 await page.locator('#colt-stage').screenshot({path:path.join(output,'colt-muur-3d.png')});
 await page.selectOption('#target','tree');await sample(.3);
 check((await page.evaluate(()=>window.__COLT_VIEWER_TEST__.state())).target==='tree','boomselectie werkt niet');
 await page.locator('#colt-stage').screenshot({path:path.join(output,'colt-boom-3d.png')});
 await page.locator('#timeline').fill('0.1');
 check((await page.evaluate(()=>window.__COLT_VIEWER_TEST__.state())).time===.1,'tijdlijn scrubt niet');
 check(errors.length===0,'browserfouten: '+errors.join('; '));
 console.log(JSON.stringify({ok:true,clip:'M1911_schot',flash:true,streak:true,impact:true,marks:true,scrub:true,errors}));ok=true;
}catch(e){console.error('COLT VIEWER TEST FAIL:',e.message);}
await browser.close();server.close();process.exit(ok?0:1);
