async page => {
 const errors=[],checks=[],captures=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 const state=()=>page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry));
 const check=(ok,label)=>{if(!ok)throw Error(label);checks.push(label);};
 const command=async(action,args={})=>{
  await page.evaluate(({action,args})=>{Object.assign(window.firetruckQA,args,{action});window.firetruckQA.sequence++;},{action,args});
  await page.waitForTimeout(240);
 };
 const capture=async(phase,time)=>{
  const field=phase==='maple'?'intro_clock':'transition_clock';
  await page.waitForFunction(({field,time})=>JSON.parse(window.firetruckTouch.telemetry)[field]>=time,{field,time},{timeout:35000});
  const t=await state();
  const path=`output/playwright/intro-pacing-${phase}-${String(time).replace('.','-')}.png`;
  await page.screenshot({path});
  captures.push({phase,clock:t[field],lens:t.camera_size,path});
  return t;
 };
 await page.setViewportSize({width:1280,height:800});
 await page.goto('http://localhost:8064/?qa=travel&review=intro-pacing');
 await page.waitForFunction(()=>document.body.classList.contains('intro')&&document.querySelector('#progress').getAttribute('aria-valuenow')==='100',{},{timeout:60000});
 await page.waitForTimeout(1000);
 check((await state()).intro_clock===0&&!await page.evaluate(()=>window.firetruckStarted),'Warmup finishes with the opening animation still paused until Start');
 await page.getByRole('button',{name:'Start',exact:true}).click();
 await page.waitForFunction(()=>{const t=JSON.parse(window.firetruckTouch.telemetry);return t.intro&&!t.loading;});
 const overlapping=await capture('maple',1.95);
 check(overlapping.camera_size<179,'Maple fly-in has started while the carpet is still unfolding');
 for(const time of [3.4,4.4,5.9,8.3,13.5]) await capture('maple',time);
 await page.waitForFunction(()=>!JSON.parse(window.firetruckTouch.telemetry).intro,{},{timeout:25000});
 await command('start_train');
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).north_exit_open,{},{timeout:5000});
 await command('pose',{x:0,z:-74});
 await command('pose',{x:0,z:-83});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).transition);
 const raceOverlap=await capture('race',4.3);
 check(raceOverlap.camera_size<165,'The incoming race mat also begins its close fly-in before unfolding ends');
 for(const time of [5.2,13.4,19.5,25.7]) await capture('race',time);
 await page.waitForFunction(()=>{const t=JSON.parse(window.firetruckTouch.telemetry);return t.world==='race_track'&&!t.transition;},{},{timeout:5000});
 check((await state()).world==='race_track','The complete club tour hands control back in the destination');
 check(errors.length===0,'Both warmed tours complete without browser/game console errors');
 return {checks,captures,errors};
}
