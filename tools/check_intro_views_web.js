async page => {
 const errors=[],captures=[],checks=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 const state=()=>page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry));
 const check=(ok,label)=>{if(!ok)throw Error(label);checks.push(label);};
 const command=async(action,args={})=>{
  await page.evaluate(({action,args})=>{Object.assign(window.firetruckQA,args,{action});window.firetruckQA.sequence++;},{action,args});
  await page.waitForTimeout(250);
 };
 const capture=async(phase,time)=>{
  const field=phase==='maple'?'intro_clock':'transition_clock';
  await page.waitForFunction(({field,time})=>JSON.parse(window.firetruckTouch.telemetry)[field]>=time,{field,time},{timeout:15000});
  const path=`output/playwright/view-assembly-web-${phase}-${String(time).replace('.','-')}.png`;
  await page.screenshot({path});
  const s=await state();
  captures.push({phase,time:s[field],path,fps:s.fps,drawCalls:s.draw_calls});
 };
 await page.setViewportSize({width:1280,height:800});
 await page.goto('http://localhost:8064/?qa=travel&review=camera-timed-toys');
 await page.waitForFunction(()=>document.querySelector('#progress').getAttribute('aria-valuenow')==='100',{},{timeout:60000});
 await page.waitForTimeout(750);
 check((await state()).intro_clock===0,'The camera-timed assembly still waits for Start');
 await page.getByRole('button',{name:'Start',exact:true}).click();
 await page.waitForFunction(()=>!JSON.parse(window.firetruckTouch.telemetry).loading);
 for(const time of [5.4,6.1,11.2,12.0])await capture('maple',time);
 await command('pose',{x:0,z:12});
 await command('start_train');
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).north_exit_open,{},{timeout:10000});
 await command('pose',{x:0,z:-74});
 await command('pose',{x:0,z:-83});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).transition);
 for(const time of [6.7,10.8,13.4,20.4])await capture('motorway',time);
 await page.waitForFunction(()=>{const s=JSON.parse(window.firetruckTouch.telemetry);return s.world==='race_track'&&!s.transition;},{},{timeout:10000});
 await page.keyboard.down('s');await page.waitForTimeout(300);await page.keyboard.up('s');
 check((await state()).speed>.5,'The revised tour hands back responsive truck control');
 await command('pose',{x:-2,z:-54});await command('pose',{x:2,z:-54});
 check((await state()).lap_running,'The assembled start gate still starts a lap');
 await command('pose',{x:-39,z:25});
 check((await state()).lap_running,'Driving past the new audience and camera keeps the lap running');
 await page.waitForTimeout(1000);
 await page.screenshot({path:'output/playwright/view-assembly-web-camera-racing.png'});
 check(errors.length===0,'Both browser intros complete without engine or console errors');
 return {checks,captures,errors};
}
