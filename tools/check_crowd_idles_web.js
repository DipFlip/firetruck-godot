async page => {
 const errors=[],captures=[];
 page.on('pageerror',error=>errors.push(String(error)));
 page.on('console',message=>{if(message.type()==='error')errors.push(message.text());});
 const state=()=>page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry));
 const command=async(action,args={})=>{
  await page.evaluate(({action,args})=>{Object.assign(window.firetruckQA,args,{action});window.firetruckQA.sequence++;},{action,args});
  await page.waitForTimeout(250);
 };
 await page.setViewportSize({width:1280,height:800});
 await page.goto('http://localhost:8064/?qa=travel&review=crowd-idles');
 await page.waitForFunction(()=>document.querySelector('#progress').getAttribute('aria-valuenow')==='100',{},{timeout:60000});
 await page.getByRole('button',{name:'Start',exact:true}).click();
 await page.waitForFunction(()=>!JSON.parse(window.firetruckTouch.telemetry).loading);
 await command('pose',{x:0,z:12});
 await command('start_train');
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).north_exit_open,{},{timeout:10000});
 await command('pose',{x:0,z:-74});
 await command('pose',{x:0,z:-83});
 await page.waitForFunction(()=>{const s=JSON.parse(window.firetruckTouch.telemetry);return s.world==='race_track'&&!s.transition;},{},{timeout:35000});
 await command('pose',{x:-52,z:23});
 const before=await state();
 for(let i=0;i<4;i++){
  await page.waitForTimeout(2000);
  const path=`output/playwright/crowd-idles-web-${i}.png`;
  await page.screenshot({path});
  const s=await state();captures.push({path,fps:s.fps,drawCalls:s.draw_calls});
 }
 const after=await state();
 await page.keyboard.down('s');await page.waitForTimeout(300);await page.keyboard.up('s');
 if((await state()).speed<.5)throw Error('Truck control failed after the updated intro');
 if(errors.length)throw Error(errors.join('\n'));
 return {captures,renderFrames:after.render_histogram.map((n,i)=>n-before.render_histogram[i]),fps:after.fps,errors};
}
