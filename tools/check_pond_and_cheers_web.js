async page => {
 const errors=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.bringToFront();
 const state=()=>page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry));
 const command=async(action,args={})=>{
  await page.evaluate(({action,args})=>{Object.assign(window.firetruckQA,{value:.85,...args,action});window.firetruckQA.sequence++;},{action,args});
  await page.waitForTimeout(250);
 };
 await command('pose',{x:-29,z:40,value:-.5});
 // The pose command accepts positive heights; natural physics descends to the bowl.
 const before=await state();
 await page.waitForTimeout(3500);
 const pond=await state();
 await page.screenshot({path:'output/playwright/reactions-swimming-ducks.png'});
 if(pond.water<=before.water||!pond.audio_counts.quack||!pond.audio_counts.splash)throw Error('Pond refill or duck/splash audio missing');
 await command('pose',{x:-4,z:-54});
 await command('drive_race');
 const lapStart=await state();
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).last_lap>0,null,{timeout:55000});
 const lapEnd=await state();
 await command('stop_race_drive');
 if(!lapEnd.audio_counts.cheer)throw Error('Spectators never cheered during the lap');
 if(lapEnd.surface_error>.12||lapEnd.flat_height_step>.01)throw Error('Race surface is unstable');
 if(errors.length)throw Error(errors.join('\n'));
 return {pond:{waterBefore:before.water,waterAfter:pond.water,height:pond.height,sounds:pond.audio_counts},lap:{seconds:lapEnd.last_lap,fps:lapEnd.fps,frames:lapEnd.render_frames-lapStart.render_frames,histogram:lapEnd.render_histogram.map((n,i)=>n-lapStart.render_histogram[i]),scale:lapEnd.render_scale,surfaceError:lapEnd.surface_error,flatStep:lapEnd.flat_height_step,sounds:lapEnd.audio_counts},errors};
}
