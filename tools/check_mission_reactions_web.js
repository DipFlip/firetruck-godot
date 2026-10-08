async page => {
 const errors=[],captures=[],phases=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.bringToFront();
 await page.setViewportSize({width:1280,height:800});
 await page.goto('http://localhost:8064/?qa=travel&review=mission-reactions');
 await page.waitForFunction(()=>window.firetruckTouch?.telemetry&&document.querySelector('#progress').getAttribute('aria-valuenow')==='100',null,{timeout:60000});
 const state=()=>page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry));
 const command=async(action,args={})=>{
  await page.evaluate(({action,args})=>{Object.assign(window.firetruckQA,{value:.85,...args,action});window.firetruckQA.sequence++;},{action,args});
  await page.waitForTimeout(250);
 };
 const capture=async(label)=>{const path=`output/playwright/reactions-${label}.png`;await page.screenshot({path});captures.push(path);};
 const sample=async(label,seconds)=>{
  const start=await state();
  await page.waitForTimeout(seconds*1000);
  const end=await state();
  phases.push({label,seconds,fps:end.fps,renderFrames:end.render_frames-start.render_frames,renderHistogram:end.render_histogram.map((n,i)=>n-start.render_histogram[i]),physicsMs:end.physics_ms,processMs:end.process_ms,drawCalls:end.draw_calls,renderScale:end.render_scale,fireStart:start.fire_progress,fireEnd:end.fire_progress,sounds:end.audio_counts,cameraBlend:end.conversation_blend});
 };
 if((await state()).intro_clock!==0)throw Error('Intro advanced before Start');
 await page.getByRole('button',{name:'Start',exact:true}).click();
 await page.waitForFunction(()=>!JSON.parse(window.firetruckTouch.telemetry).loading);
 await page.waitForTimeout(4500);
 await capture('maple-first-house');
 await command('pose',{x:49,z:-10});
 await page.keyboard.down('Shift');
 await command('spray_fire');
 await sample('real barbecue hose contact',3);
 await capture('barbecue-wet');
 await sample('barbecue completion and steam',3);
 await command('stop_spray');
 await page.keyboard.up('Shift');
 if((await state()).fire_progress<.5)throw Error('The hose never hit the barbecue');
 await command('start_train');
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).north_exit_open,null,{timeout:5000});
 await command('pose',{x:0,z:-74});await command('pose',{x:0,z:-83});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).transition);
 for(const [time,label] of [[5.3,'race-start-assembly'],[13.4,'food-court-assembly'],[20,'audience-assembly'],[24,'truck-touchdown']]){
  await page.waitForFunction(time=>JSON.parse(window.firetruckTouch.telemetry).transition_clock>=time,time,{timeout:30000});
  await capture(label);
 }
 await page.waitForFunction(()=>!JSON.parse(window.firetruckTouch.telemetry).transition,null,{timeout:5000});
 await command('pose',{x:45,z:76});
 await capture('southern-edge');
 await sample('motorway southern edge',3);
 if(errors.length)throw Error(errors.join('\n'));
 return {phases,captures,errors,final:await state()};
}
