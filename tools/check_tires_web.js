// Exercise the real driving controls and warmed browser trail shader.
async page => {
 const errors=[],samples=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.bringToFront();
 await page.setViewportSize({width:1280,height:800});
 await page.goto('http://localhost:8064/?qa=travel&review=tire-marks');
 await page.waitForFunction(()=>document.querySelector('#progress').getAttribute('aria-valuenow')==='100',{},{timeout:60000});
 await page.getByRole('button',{name:'Start',exact:true}).click();
 await page.waitForFunction(()=>window.firetruckTouch.telemetry&&!JSON.parse(window.firetruckTouch.telemetry).loading);
 await page.evaluate(()=>{Object.assign(window.firetruckQA,{action:'pose',x:-30,z:-36,value:.85});window.firetruckQA.sequence++;});
 await page.waitForTimeout(1500);
 const before=await page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry));
 const turn=async(key,duration)=>{
  await page.keyboard.down(key);
  for(let i=0;i<duration/200;i++){
   await page.waitForTimeout(200);
   samples.push(await page.evaluate(()=>{const t=JSON.parse(window.firetruckTouch.telemetry);return {fps:t.fps,speed:t.speed,tireStarts:t.audio_counts.tire_scrub||0,position:t.truck_position};}));
  }
  await page.keyboard.up(key);
 };
 await turn('d',1600);
 await turn('s',1200);
 await turn('a',1200);
 await page.screenshot({path:'output/playwright/tire-tracks-browser.png'});
 await turn('w',1200);
 await page.waitForTimeout(800);
 const after=await page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry));
 if(!(after.audio_counts.tire_scrub>0))throw Error('No tire sound activated under hard turning');
 if(errors.length)throw Error(errors.join('\n'));
 return {samples,tireStarts:after.audio_counts.tire_scrub,renderFrames:after.render_histogram.map((n,i)=>n-before.render_histogram[i]),drawCalls:after.draw_calls,errors};
}
