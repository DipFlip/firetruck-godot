async page => {
 const errors=[],approach=[];
 page.on('pageerror',error=>errors.push(String(error)));
 page.on('console',message=>{if(message.type()==='error')errors.push(message.text());});
 const state=()=>page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry));
 const framing=()=>page.evaluate(()=>JSON.parse(window.firetruckTouch.framing));
 const command=async(action,args={})=>{
  await page.evaluate(({action,args})=>{Object.assign(window.firetruckQA,args,{action});window.firetruckQA.sequence++;},{action,args});
  await page.waitForTimeout(250);
 };
 const clearSpeech=async()=>{
  for(let i=0;i<8&&(await state()).talking;i++){
   await page.keyboard.press('Space');await page.waitForTimeout(100);
  }
 };
 const inView=(s,f)=>{
  const [w,h]=s.logical_view,[x,y,rw,rh]=f.truck;
  const pool=f.interests.find(p=>p.name==='PoolCameraInterest');
  if(!pool||pool.weight<.98)throw Error('The pool framing point is not fully engaged');
  if(x<12||y<76||x+rw>w-12||y+rh>h-12)throw Error('The truck is outside the safe view');
  if(pool.bounds.some(([px,py])=>px<12||py<76||px>w-12||py>h-12))throw Error('The pool is outside the safe view');
 };
 await page.setViewportSize({width:1280,height:800});
 await page.waitForFunction(()=>document.querySelector('#progress').getAttribute('aria-valuenow')==='100',{},{timeout:60000});
 await page.getByRole('button',{name:'Start',exact:true}).click();
 await page.waitForFunction(()=>window.firetruckTouch.telemetry&&!JSON.parse(window.firetruckTouch.telemetry).loading);
 await command('pose',{x:0,z:12});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).speaker==='DISPATCH',{},{timeout:10000});
 await clearSpeech();
 for(const z of [24,19,14,9,4,1]){
  await command('pose',{x:7,z});await page.waitForTimeout(1700);
  const s=await state();approach.push({z,blend:s.conversation_blend,lens:s.camera_size,talking:s.talking});
 }
 if(approach.some((s,i)=>s.talking||(i&&s.blend<=approach[i-1].blend)))throw Error('Attention did not increase continuously before greeting: '+JSON.stringify(approach));
 await page.screenshot({path:'output/playwright/framing-approach-web.png'});
 await command('pose',{x:10,z:64});
 await command('fill_pool',{value:0});
 await page.waitForTimeout(3000);
 const before=await state(),start=await framing();inView(before,start);
 await page.screenshot({path:'output/playwright/framing-pool-bubble-web.png'});
 await clearSpeech();
 const pool=(await framing()).interests.find(p=>p.name==='PoolCameraInterest');
 const centre=pool.bounds.reduce((sum,p)=>[sum[0]+p[0]/pool.bounds.length,sum[1]+p[1]/pool.bounds.length],[0,0]);
 const [vw,vh]=(await state()).logical_view;
 await page.mouse.move(centre[0]*1280/vw,centre[1]*800/vh);
 await page.keyboard.down('Shift');await page.mouse.down();
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.framing).pool_progress>.025,{},{timeout:12000});
 const filling=await state(),filled=await framing();inView(filling,filled);
 await page.screenshot({path:'output/playwright/framing-pool-filling-web.png'});
 await page.mouse.up();await page.keyboard.up('Shift');
 await page.setViewportSize({width:390,height:564});
 await command('pose',{x:10,z:64});await page.waitForTimeout(3500);
 const portrait=await state(),portraitFrame=await framing();inView(portrait,portraitFrame);
 await page.screenshot({path:'output/playwright/framing-pool-portrait-web.png'});
 if(errors.length)throw Error(errors.join('\n'));
 return {approach,pool:{before:start.pool_progress,after:filled.pool_progress,lens:filling.camera_size,fps:filling.fps},portrait:{view:portrait.logical_view,lens:portrait.camera_size,fps:portrait.fps},errors};
}
