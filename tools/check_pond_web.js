async page => {
 const errors=[],checks=[],captures=[],pond=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 const state=()=>page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry));
 const check=(ok,label)=>{if(!ok)throw Error(label);checks.push(label);};
 const command=async(action,args={})=>{
  await page.evaluate(({action,args})=>{Object.assign(window.firetruckQA,args,{action});window.firetruckQA.sequence++;},{action,args});
  await page.waitForTimeout(240);
 };
 const capture=async(phase,time)=>{
  const field=phase==='intro'?'intro_clock':'transition_clock';
  await page.waitForFunction(({field,time})=>JSON.parse(window.firetruckTouch.telemetry)[field]>=time,{field,time},{timeout:35000});
  const path=`output/playwright/pond-browser-${phase}-${String(time).replace('.','-')}.png`;
  await page.screenshot({path});
  captures.push({phase,time:(await state())[field],path});
 };
 await page.setViewportSize({width:1280,height:800});
 await page.goto('http://localhost:8064/?qa=travel&review=pond-and-timing');
 await page.waitForFunction(()=>window.firetruckTouch?.telemetry && document.querySelector('#progress').getAttribute('aria-valuenow')==='100',{},{timeout:60000});
 check((await state()).intro_clock===0,'The intro still waits for Start');
 await page.getByRole('button',{name:'Start',exact:true}).click();
 await page.waitForFunction(()=>!JSON.parse(window.firetruckTouch.telemetry).loading);
 for(const time of [2.2,5.6,7.2]) await capture('intro',time);
 check((await state()).camera_size<55,'Maple Bay finishes the faster close fly-in');
 await page.waitForFunction(()=>!JSON.parse(window.firetruckTouch.telemetry).intro,{},{timeout:25000});
 await command('start_train');
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).north_exit_open,{},{timeout:5000});
 await command('pose',{x:0,z:-74});
 await command('pose',{x:0,z:-83});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).transition);
 for(const time of [.7,1.3,2.4,4.7,6.2]) await capture('race',time);
 check((await state()).camera_size<55,'Motorway reaches the start-gate close view about one second after its fly-in starts');
 for(const time of [13.4,19.5,25.7]) await capture('race',time);
 await page.waitForFunction(()=>{const t=JSON.parse(window.firetruckTouch.telemetry);return t.world==='race_track'&&!t.transition;},{},{timeout:5000});
 await command('pose',{x:-14,z:40});
 await page.evaluate(()=>{window.firetruckTouch.driveX=-29/Math.hypot(16,29);window.firetruckTouch.driveY=-16/Math.hypot(16,29);});
 for(let i=0;i<38;i++) {
  await page.waitForTimeout(100);
  pond.push(await state());
  if(i===20) await page.screenshot({path:'output/playwright/pond-browser-submerged.png'});
 }
 await page.evaluate(()=>{window.firetruckTouch.driveX=0;window.firetruckTouch.driveY=0;});
 const lowest=Math.min(...pond.map(t=>t.height));
 check(lowest<-.9,'Normal browser steering drives down into the recessed pond');
 check(pond.some(t=>t.truck_position[0]<400-43 && t.height>.6),'The truck climbs back out of the opposite beach');
 await command('pose',{x:0,z:-74});
 await command('pose',{x:0,z:-83});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).transition);
 for(const time of [.7,1.65,2.4,3.3,4.05]) await capture('return',time);
 await page.waitForFunction(()=>{const t=JSON.parse(window.firetruckTouch.telemetry);return t.world==='maple_bay'&&!t.transition;},{},{timeout:5000});
 check((await state()).transition_clock>=4.2 && (await state()).transition_clock<4.5,'The eased return swap takes fifty percent longer');
 await page.screenshot({path:'output/playwright/pond-browser-return-control.png'});
 await command('pose',{x:0,z:-74});
 await command('pose',{x:0,z:-83});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).transition);
 await capture('revisit',2.4);
 await page.waitForFunction(()=>{const t=JSON.parse(window.firetruckTouch.telemetry);return t.world==='race_track'&&!t.transition;},{},{timeout:5000});
 check((await state()).transition_clock>=4.2 && (await state()).transition_clock<4.5,'Repeat Motorway visits use the same slower continuous swap');
 check(errors.length===0,'The pond, shader sprouts and mat transitions have no browser/game console errors');
 return {checks,captures,lowest,pond:pond.map(t=>({x:t.truck_position[0],z:t.truck_position[1],height:t.height,fps:t.fps,draw_calls:t.draw_calls})),errors};
}
