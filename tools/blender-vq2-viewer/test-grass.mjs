import {chromium} from 'playwright-core';
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const mime={'.html':'text/html','.js':'text/javascript','.css':'text/css','.json':'application/json','.glb':'model/gltf-binary'};
const server=http.createServer(async(req,res)=>{try{let rel=new URL(req.url,'http://local').pathname;if(rel.endsWith('/'))rel+='index.html';const file=path.resolve(root,'.'+rel);if(!file.startsWith(root+path.sep)||rel.includes('/.'))throw Error('path');const b=await fs.readFile(file);res.writeHead(200,{'Content-Type':mime[path.extname(file)]||'application/octet-stream'});res.end(b);}catch{res.writeHead(404);res.end();}});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const report={browser:'Chromium SwiftShader WebGL, emulated touch; not physical Safari',families:[],errors:[]};
const url=`http://127.0.0.1:${server.address().port}/tools/blender-vq2-viewer/`;
const assert=(v,m)=>{if(!v)throw Error(m);};
try{
 const page=await browser.newPage({viewport:{width:1280,height:1050}});page.setDefaultTimeout(90000);page.on('pageerror',e=>report.errors.push(e.message));
 await page.goto(url,{waitUntil:'domcontentloaded'});await page.waitForFunction(()=>window.__VQ2_TEST__?.ready());
 for(const family of ['short','medium','tall']){
  const asset='grass_'+family;await page.selectOption('#asset',asset);
  await page.waitForFunction(a=>window.__VQ2_TEST__.ready()&&window.__VQ2_TEST__.loaded().asset===a,asset);
  let previous=Infinity;const lods=[];
  for(let lod=0;lod<3;lod++){
   await page.selectOption('#grass-lod',String(lod));await page.waitForFunction(()=>window.__VQ2_TEST__.ready());
   const info=await page.evaluate(()=>window.__VQ2_TEST__.grassInfo());
   assert(info.meshes.length===4,family+' four meshes missing');
   assert(info.triangles<previous,family+' LOD does not reduce actual geometry');previous=info.triangles;
   for(const mesh of info.meshes)for(const size of mesh.maps)assert(size?.[0]===2048&&size?.[1]===2048,family+' non-2K material');
   assert(await page.locator('#play').isDisabled(),'Fake animation control');
   assert((await page.locator('#animation-status').innerText()).includes('Godot-shader'), 'Shader wind not explained');
   lods.push({lod,triangles:info.triangles,actual_2k_pbr:true});
  }
  await page.selectOption('#grass-lod','0');await page.waitForFunction(()=>window.__VQ2_TEST__.ready());
  for(let i=1;i<=4;i++){
   await page.selectOption('#grass-variant',String(i));const info=await page.evaluate(()=>window.__VQ2_TEST__.grassInfo());
   assert(info.meshes.filter(m=>m.visible).length===1,'Variant filter does not isolate a real tuft');
  }
  await page.selectOption('#grass-variant','0');await page.selectOption('#version','split');await page.waitForTimeout(200);
  await page.locator('#stage').screenshot({path:root+`/docs/grass/renders/browser-${family}-compare.png`});
  await page.selectOption('#version','v2');
  const before=await page.evaluate(()=>window.__VQ2_TEST__.loaded().camera);
  const box=await page.locator('#canvas').boundingBox();await page.mouse.move(box.x+box.width*.4,box.y+box.height*.5);await page.mouse.down();await page.mouse.move(box.x+box.width*.65,box.y+box.height*.6,{steps:12});await page.mouse.up();await page.waitForTimeout(300);
  const after=await page.evaluate(()=>window.__VQ2_TEST__.loaded().camera);assert(JSON.stringify(before)!==JSON.stringify(after),'360 orbit does not work');
  report.families.push({family,lods,four_variants:true,old_new_comparison:true,orbit:true});
 }
 await page.close();
 const mobile=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true,deviceScaleFactor:2});
 const page2=await mobile.newPage();page2.setDefaultTimeout(90000);page2.on('pageerror',e=>report.errors.push(e.message));await page2.goto(url,{waitUntil:'domcontentloaded'});await page2.waitForFunction(()=>window.__VQ2_TEST__?.ready());
 await page2.selectOption('#asset','grass_tall');await page2.waitForFunction(()=>window.__VQ2_TEST__.ready()&&window.__VQ2_TEST__.loaded().asset==='grass_tall');
 for(const size of [{width:390,height:844},{width:844,height:390}]){await page2.setViewportSize(size);await page2.waitForTimeout(150);assert(await page2.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'Mobile overflow');}
 await page2.locator('#canvas').scrollIntoViewIfNeeded();await page2.waitForTimeout(150);
 const b=await page2.locator('#canvas').boundingBox(),x=b.x+b.width/2,y=b.y+b.height/2;
 const distance=()=>page2.evaluate(()=>{const s=window.__VQ2_TEST__.loaded();return Math.hypot(...s.camera.map((v,i)=>v-s.target[i]));});
 const d0=await distance(),cdp=await mobile.newCDPSession(page2);
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:x-30,y,id:0},{x:x+30,y,id:1}]});
 for(let i=1;i<=7;i++)await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:x-30-i*6,y,id:0},{x:x+30+i*6,y,id:1}]});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await page2.waitForTimeout(250);assert(Math.abs(await distance()-d0)>.1,'Pinch zoom');
 await page2.locator('#stage').screenshot({path:root+'/docs/grass/renders/browser-mobile.png'});
 report.mobile_viewports=['390x844','844x390'];report.touch_pinch=true;
 assert(report.errors.length===0,report.errors.join('; '));report.pass=true;
 console.log('GRASS VIEWER PASS: 3 heights, 12 variants, 9 LOD libraries, real 2K maps, comparisons, orbit and mobile pinch');
}finally{await browser.close();server.close();await fs.writeFile(root+'/docs/grass/viewer-test.json',JSON.stringify(report,null,2)+'\n');}
