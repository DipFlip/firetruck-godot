async page => {
 const errors=[],captures=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 const state=()=>page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry));
 const command=async(action,args={})=>{
  await page.evaluate(({action,args})=>{Object.assign(window.firetruckQA,args,{action});window.firetruckQA.sequence++;},{action,args});
  await page.waitForTimeout(250);
 };
 await page.setViewportSize({width:1280,height:800});
 await page.goto('http://localhost:8064/?qa=travel&review=motorway-crowd');
 await page.waitForFunction(()=>document.querySelector('#progress').getAttribute('aria-valuenow')==='100',{},{timeout:60000});
 await page.getByRole('button',{name:'Start',exact:true}).click();
 await page.waitForFunction(()=>window.firetruckTouch?.telemetry&&!JSON.parse(window.firetruckTouch.telemetry).loading);
 await command('pose',{x:0,z:12});
 await command('start_train');
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).north_exit_open,{},{timeout:10000});
 await command('pose',{x:0,z:-74});
 await command('pose',{x:0,z:-83});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).transition);
 const before=await state();
 for(const time of [9.5,10.4,10.8,11.3,12.6,13.4,14.2,19.4,21.2,25.4]){
  await page.waitForFunction(time=>JSON.parse(window.firetruckTouch.telemetry).transition_clock>=time,time,{timeout:12000});
  const path=`output/playwright/motorway-crowd-${String(time).replace('.','-')}.png`;
  await page.screenshot({path});
  const s=await state();
  captures.push({time:s.transition_clock,path,fps:s.fps,drawCalls:s.draw_calls});
 }
 await page.waitForFunction(()=>{const s=JSON.parse(window.firetruckTouch.telemetry);return s.world==='race_track'&&!s.transition;},{},{timeout:5000});
 const after=await state();
 await command('pose',{x:52,z:43});
 await page.waitForTimeout(750);
 await page.screenshot({path:'output/playwright/motorway-crowd-walking-a.png'});
 await page.waitForTimeout(300);
 await page.screenshot({path:'output/playwright/motorway-crowd-walking-b.png'});
 await page.keyboard.down('s');await page.waitForTimeout(300);await page.keyboard.up('s');
 if((await state()).speed<.5)throw Error('Truck control failed after the revised intro');
 if(errors.length)throw Error(errors.join('\n'));
 return {captures,renderFrames:after.render_histogram.map((n,i)=>n-before.render_histogram[i]),fps:after.fps,errors};
}
