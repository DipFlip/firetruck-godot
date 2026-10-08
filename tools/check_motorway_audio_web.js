async page => {
 const errors=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 const state=()=>page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry));
 const command=async(action,args={})=>{
  await page.evaluate(({action,args})=>{Object.assign(window.firetruckQA,{value:.85,...args,action});window.firetruckQA.sequence++;},{action,args});
  await page.waitForTimeout(250);
 };
 await command('pose',{x:-30,z:-36});
 for(const key of ['d','s','a']){
  await page.keyboard.down(key);await page.waitForTimeout(1200);await page.keyboard.up(key);
 }
 if(!((await state()).audio_counts.tire_scrub>0))throw Error('Tire squeal never started during slipping');
 await command('start_train');
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).north_exit_open,{},{timeout:6000});
 await command('pose',{x:0,z:-74});await command('pose',{x:0,z:-83});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).transition);
 const start=await state();
 const stats=()=>page.evaluate(()=>new Promise(resolve=>{toyAudioProbe.tap.port.onmessage=e=>resolve(e.data);toyAudioProbe.tap.port.postMessage('stats');}));
 await stats();
 await page.waitForFunction(()=>{const t=JSON.parse(window.firetruckTouch.telemetry);return t.world==='race_track'&&!t.transition;},{},{timeout:30000});
 const end=await state(),pcm=await stats();
 const sounds={};for(const kind of ['block_land','house_grow','plastic'])sounds[kind]=(end.audio_counts[kind]||0)-(start.audio_counts[kind]||0);
 if(sounds.block_land<10||sounds.house_grow<2)throw Error('Motorway landing/growth cues were missing');
 if(pcm.frames<10000||pcm.peak>=.95||pcm.rms===0)throw Error('Missing or clipped spatial audio');
 if(errors.length)throw Error(errors.join('\n'));
 return {world:'Motorway',sounds,pcm,renderFrames:end.render_histogram.map((n,i)=>n-start.render_histogram[i]),fps:end.fps,errors};
}
