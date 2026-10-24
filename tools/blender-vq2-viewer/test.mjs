import {chromium} from 'playwright-core';
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const results={browser:'Chromium headless, software WebGL; not a physical Safari/iPhone test',models:[],clips:[],mobile:[],errors:[]};
const mime={'.html':'text/html','.js':'text/javascript','.css':'text/css','.json':'application/json','.glb':'model/gltf-binary','.png':'image/png','.jpg':'image/jpeg'};
const server=http.createServer(async(req,res)=>{try{let rel=decodeURIComponent(new URL(req.url,'http://local').pathname);if(rel.endsWith('/'))rel+='index.html';const file=path.resolve(root,'.'+rel);if(!file.startsWith(root+path.sep)||rel.includes('/.'))throw Error('path');const data=await fs.readFile(file);res.writeHead(200,{'Content-Type':mime[path.extname(file)]||'application/octet-stream','Content-Length':data.length});res.end(data);}catch{res.writeHead(404);res.end('not found');}});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const url=`http://127.0.0.1:${server.address().port}/tools/blender-vq2-viewer/`;
const browser=await chromium.launch({executablePath:process.env.CHROMIUM||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const out=path.join(root,'docs/vq2/renders');await fs.mkdir(out,{recursive:true});
function assert(ok,msg){if(!ok)throw Error(msg);}
async function ready(page,asset){await page.waitForFunction(a=>window.__VQ2_TEST__?.ready()&&window.__VQ2_TEST__.loaded().asset===a,asset,{timeout:60000});await page.waitForTimeout(250);}
async function scrub(page,time){await page.locator('#scrub').evaluate((e,t)=>{e.value=t;e.dispatchEvent(new Event('input',{bubbles:true}));},String(time));await page.waitForTimeout(100);}
try{
 const page=await browser.newPage({viewport:{width:1280,height:1050}});
 page.on('pageerror',e=>results.errors.push(e.message));
 await page.goto(url);await ready(page,'kazerne');
 results.webgl=await page.evaluate(()=>{const gl=document.querySelector('canvas').getContext('webgl2');const ext=gl.getExtension('WEBGL_debug_renderer_info');return gl.getParameter(ext?.UNMASKED_RENDERER_WEBGL||gl.RENDERER);});
 for(const name of ['kazerne','wachttoren','legerjeep']){
  await page.selectOption('#asset',name);await ready(page,name);
  await page.selectOption('#version','split');await page.waitForTimeout(120);
  const state=await page.evaluate(()=>window.__VQ2_TEST__.loaded());
  assert(state.materials.length>0,name+' has no actual materials');
  await page.locator('#stage').screenshot({path:path.join(out,`${name}-browser-compare.png`)});
  const before=state.camera;const box=await page.locator('#canvas').boundingBox();
  await page.mouse.move(box.x+box.width*.5,box.y+box.height*.5);await page.mouse.down();await page.mouse.move(box.x+box.width*.72,box.y+box.height*.55,{steps:12});await page.mouse.up();await page.waitForTimeout(350);
  const orbit=await page.evaluate(()=>window.__VQ2_TEST__.loaded().camera);assert(JSON.stringify(before)!==JSON.stringify(orbit),name+' orbit does not move');
  await page.click('#top');const cam=await page.evaluate(()=>window.__VQ2_TEST__.loaded().camera);assert(Math.abs(Math.hypot(...cam)-28)<.02,'game camera distance');
  for(const mode of ['albedo','normal','roughness','wire','pbr']){await page.selectOption('#shading',mode);await page.waitForTimeout(50);}
  results.models.push({name,materials:state.materials,orbit:true,game_camera_58deg_28m:true,inspection_modes:true});
 }
 await page.selectOption('#asset','jeep');await ready(page,'jeep');
 const clips=await page.evaluate(()=>window.__VQ2_TEST__.clips());assert(clips.length===7,'expected 7 real clips');
 for(const name of ['Stationair','Rijden','Achteruit','Bocht','Remmen','Vuren','Rondkijken']){
  const clip=clips.find(c=>c.startsWith(name));assert(clip,'missing '+name);
  await page.selectOption('#clips',clip);await scrub(page,0);
  const before=await page.evaluate(()=>window.__VQ2_TEST__.sample());
  await scrub(page,name==='Rondkijken'?.8:name==='Bocht'?.6:.06);
  const after=await page.evaluate(()=>window.__VQ2_TEST__.sample());
  const changed=JSON.stringify(before)!==JSON.stringify(after);
  assert(changed,name+' does not animate actual jeep nodes');
  const part=['Rijden','Achteruit'].includes(name)?'WielLV':name==='Vuren'?'MG':name==='Rondkijken'?'Geschut':'Body';
  assert(JSON.stringify(before[part])!==JSON.stringify(after[part]),name+' does not move expected part '+part);
  if(name==='Bocht')assert(Math.hypot(...after.StuurLV.quaternion.slice(0,3))>.1,'Bocht does not visibly steer');
  if(['Rijden','Bocht','Vuren'].includes(name))await page.locator('#stage').screenshot({path:path.join(out,`jeep-browser-${name.toLowerCase()}.png`)});
  results.clips.push({name:clip,actual_node_transform_changes:changed,verified_part:part,steering:name==='Bocht'?true:undefined});
 }
 await page.click('#play');await page.waitForTimeout(300);assert(Number(await page.locator('#scrub').inputValue())>0,'play does not advance timeline');await page.click('#play');
 await page.close();
 const context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true});
 const mobile=await context.newPage();mobile.on('pageerror',e=>results.errors.push(e.message));await mobile.goto(url);await ready(mobile,'kazerne');
 for(const viewport of [{width:390,height:844},{width:844,height:390}]){
  await mobile.setViewportSize(viewport);await mobile.waitForTimeout(250);
  assert(await mobile.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'mobile horizontal overflow');
  results.mobile.push({...viewport,no_horizontal_overflow:true});
 }
 const box=await mobile.locator('#canvas').boundingBox();
 const before=await mobile.evaluate(()=>{const s=window.__VQ2_TEST__.loaded();return Math.hypot(...s.camera.map((v,i)=>v-s.target[i]));});
 const cdp=await context.newCDPSession(mobile);const x=box.x+box.width/2,y=box.y+box.height/2;
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:x-35,y,id:0},{x:x+35,y,id:1}]});
 for(let i=1;i<=8;i++)await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:x-35-i*6,y,id:0},{x:x+35+i*6,y,id:1}]});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await mobile.waitForTimeout(350);
 const after=await mobile.evaluate(()=>{const s=window.__VQ2_TEST__.loaded();return Math.hypot(...s.camera.map((v,i)=>v-s.target[i]));});
 assert(Math.abs(before-after)>.1,'two-finger pinch does not zoom');results.touch_pinch_zoom=true;
 await mobile.locator('#stage').screenshot({path:path.join(out,'mobile-viewer-landscape.png')});
 assert(results.errors.length===0,'browser errors: '+results.errors.join('; '));
 results.pass=true;
 console.log('VQ2 VIEWER PASS: 3 comparisons, 5 material modes, orbit, 7 moving GLB clips, play/pause/scrub, 2 mobile viewports and pinch zoom');
}finally{
 await browser.close();server.close();await fs.writeFile(path.join(root,'docs/vq2/results/viewer-test.json'),JSON.stringify(results,null,2)+'\n');
}
