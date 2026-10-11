async page => {
 const errors=[],checks=[],results=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 const state=()=>page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry));
 const check=(ok,label)=>{if(!ok)throw Error(label);checks.push(label);};
 const command=async(action,args={})=>{
  await page.evaluate(({action,args})=>{Object.assign(window.firetruckQA,args,{action});window.firetruckQA.sequence++;},{action,args});
  await page.waitForTimeout(250);
 };
 const knock=async(isRace)=>{
  const s=await state(),target=s.hydrants[0];
  check(target.respawn===5,'The '+s.world+' hydrant has the shared five-second return');
  const start={x:target.x,z:target.z+(isRace?-8:8)};
  await command('pose',start);await command('pose',start);
  // Screen-space joystick values resolve to world north/south. The
  // keyboard W key points diagonally toward the isometric camera instead.
  await page.evaluate(isRace=>{window.firetruckTouch.driveX=isRace?-.483:.483;window.firetruckTouch.driveY=isRace?.876:-.876;},isRace);
  try{
   await page.waitForFunction(()=>{const s=JSON.parse(window.firetruckTouch.telemetry);return s.hydrants[0].loose&&s.hydrants[0].jet_visible;},{},{timeout:5000});
  }finally{await page.evaluate(()=>{window.firetruckTouch.driveX=0;window.firetruckTouch.driveY=0;});}
  const broken=await state(),began=Date.now();
  check(broken.hydrants[0].jet_time>0,'A real browser collision starts the '+s.world+' water jet');
  await page.waitForTimeout(250);
  check((await state()).hydrants[0].jet_time>broken.hydrants[0].jet_time,'The broken-pipe water continues animating');
  await command('pose',{x:target.x+8,z:target.z+(isRace?8:12)});
  await page.screenshot({path:`output/playwright/shared-hydrant-${s.world}-spray.png`});
  await page.waitForFunction(()=>!JSON.parse(window.firetruckTouch.telemetry).hydrants[0].loose,{},{timeout:6000});
  const returned=await state(),remainingMs=Date.now()-began;
  check(!returned.hydrants[0].jet_visible&&remainingMs<5400,'The '+s.world+' hydrant returns and switches off its jet at five seconds');
  await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).hydrants[0].opacity>.999,{},{timeout:1500});
  await page.screenshot({path:`output/playwright/shared-hydrant-${s.world}-restored.png`});
  results.push({world:s.world,remainingMs,broken:broken.hydrants[0],returned:returned.hydrants[0],fps:returned.fps});
 };
 await page.setViewportSize({width:1280,height:800});
 await page.goto('http://localhost:8064/?qa=travel&review=shared-hydrants');
 await page.waitForFunction(()=>document.querySelector('#progress').getAttribute('aria-valuenow')==='100',{},{timeout:60000});
 await page.getByRole('button',{name:'Start',exact:true}).click();
 await page.waitForFunction(()=>!JSON.parse(window.firetruckTouch.telemetry).loading);
 await command('pose',{x:0,z:12});
 await knock(false);
 await command('pose',{x:0,z:12});await command('start_train');
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).north_exit_open,{},{timeout:10000});
 await command('pose',{x:0,z:-74});await command('pose',{x:0,z:-83});
 await page.waitForFunction(()=>{const s=JSON.parse(window.firetruckTouch.telemetry);return s.world==='race_track'&&!s.transition;},{},{timeout:35000});
 await knock(true);
 check(errors.length===0,'Both shared fixtures work without browser/engine errors');
 return {checks,results,errors};
}
