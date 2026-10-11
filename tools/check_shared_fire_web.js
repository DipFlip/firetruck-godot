async page => {
 const errors=[],samples=[];
 page.on('pageerror',error=>errors.push(String(error)));
 page.on('console',message=>{if(message.type()==='error')errors.push(message.text());});
 const state=()=>page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry));
 const effects=()=>page.evaluate(()=>JSON.parse(window.firetruckTouch.fire_effects));
 const command=async(action,args={})=>{
  await page.evaluate(({action,args})=>{Object.assign(window.firetruckQA,args,{action});window.firetruckQA.sequence++;},{action,args});
  await page.waitForTimeout(250);
 };
 const cool=async(name,action)=>{
  await page.keyboard.down('Shift');
  await command(action);
  await page.waitForFunction(name=>{
   const f=JSON.parse(window.firetruckTouch.fire_effects);
   const fire=f.fires.find(fire=>fire.name===name);
   return fire.progress>.04&&fire.steam>0&&f.sizzle;
  },name,{timeout:10000});
  const active=await effects(),s=await state();
  const fire=active.fires.find(f=>f.name===name);
  if(Math.hypot(active.sound_position[0]-fire.position[0],active.sound_position[2]-fire.position[2])>.1)throw Error('Hiss is playing at the wrong fire');
  await page.screenshot({path:`output/playwright/${name}-cooling-web.png`});
  await command('stop_spray');await page.keyboard.up('Shift');
  await page.waitForTimeout(2100);
  const after=await effects();
  if(after.sizzle||after.fires.find(f=>f.name===name).steam>0)throw Error('Steam or hiss persisted after water stopped');
  samples.push({fire:name,progress:fire.progress,steam:fire.steam,waterRequired:fire.water_required,sizzleAt:active.sound_position,fps:s.fps,drawCalls:s.draw_calls});
 };
 await page.setViewportSize({width:1280,height:800});
 await page.waitForFunction(()=>document.querySelector('#progress').getAttribute('aria-valuenow')==='100',{},{timeout:60000});
 await page.getByRole('button',{name:'Start',exact:true}).click();
 await page.waitForFunction(()=>window.firetruckTouch.telemetry&&!JSON.parse(window.firetruckTouch.telemetry).loading);
 await command('pose',{x:49,z:-11});
 await cool('BarbecueFire','spray_fire');
 await command('start_train');
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).north_exit_open,{},{timeout:10000});
 await command('pose',{x:0,z:-74});await command('pose',{x:0,z:-83});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).transition);
 const hidden=await effects();
 if(hidden.fires.some(f=>f.visible))throw Error('Fire appeared during the carpet transition');
 await page.waitForFunction(()=>{const s=JSON.parse(window.firetruckTouch.telemetry);return s.world==='race_track'&&!s.transition;},{},{timeout:35000});
 await command('pose',{x:62,z:8});
 await cool('FoodCourtFire','spray_race_fire');
 await command('pose',{x:65,z:34});
 await page.waitForTimeout(1700);
 await page.screenshot({path:'output/playwright/bunting-and-cones-web.png'});
 if(errors.length)throw Error(errors.join('\n'));
 return {samples,allFiresHiddenDuringTransition:true,errors};
}
