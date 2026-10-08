async page => {
 const errors=[],phases=[],checks=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.bringToFront();
 await page.setViewportSize({width:1280,height:800});
 await page.goto('http://localhost:8064/?qa=travel&review=sixty-fps-validation');
 await page.waitForFunction(()=>document.body.classList.contains('intro')&&document.querySelector('#progress').getAttribute('aria-valuenow')==='100',{},{timeout:60000});
 const state=()=>page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry));
 const command=async(action,args={})=>{
  await page.evaluate(({action,args})=>{Object.assign(window.firetruckQA,{value:.82,...args,action});window.firetruckQA.sequence++;},{action,args});
  await page.waitForTimeout(250);
 };
 const c=await page.context().newCDPSession(page);
 await c.send('Performance.enable');
 const metric=(o,n)=>o.metrics.find(m=>m.name===n).value;
 const result=(label,start,end,a,b)=>({label,seconds:metric(b,'Timestamp')-metric(a,'Timestamp'),renderFrames:end.render_frames-start.render_frames,renderFps:end.fps,renderHistogram:end.render_histogram.map((n,i)=>n-start.render_histogram[i]),maxRenderMs:end.max_render_ms,taskSeconds:metric(b,'TaskDuration')-metric(a,'TaskDuration'),scriptSeconds:metric(b,'ScriptDuration')-metric(a,'ScriptDuration'),scale:end.render_scale,drawCalls:end.draw_calls,physicsMs:end.physics_ms,processMs:end.process_ms});
 const tour=async(label,field)=>{
  const start=await state(),a=await c.send('Performance.getMetrics');
  const values=await page.evaluate(field=>new Promise(resolve=>{
   const states=[];let previous=-1;
   function tick(){const t=JSON.parse(window.firetruckTouch.telemetry);if(t[field]-previous>=.2){states.push(t);previous=t[field];}if(t[field.replace('_clock','')])requestAnimationFrame(tick);else resolve(states);}
   requestAnimationFrame(tick);
  }),field);
  const end=await state(),b=await c.send('Performance.getMetrics');
  const r=result(label,start,end,a,b);
  r.fpsMin=Math.min(...values.filter(t=>t[field]>1).map(t=>t.fps));
  r.scales=[...new Set(values.map(t=>t.render_scale))];
  r.samples=values.map(t=>({clock:t[field],fps:t.fps,calls:t.draw_calls,scale:t.render_scale,processMs:t.process_ms,frameHistogram:t.render_histogram}));
  phases.push(r);
 };
 const sample=async label=>{
  const start=await state(),a=await c.send('Performance.getMetrics');
  await page.waitForTimeout(4000);
  const end=await state(),b=await c.send('Performance.getMetrics');
  phases.push(result(label,start,end,a,b));
 };
 const scissor=await page.evaluate(()=>{
  const offscreen=document.createElement('canvas'),gl=offscreen.getContext('webgl2');
  if(!gl) throw Error('WebGL2 unavailable');
  const get=gl.getParameter.bind(gl);
  window.firetruckRenderBudget.cacheScissorState(gl);
  for(let i=0;i<12;i++){
   gl.enable(gl.SCISSOR_TEST);if(gl.getParameter(gl.SCISSOR_TEST)!==get(gl.SCISSOR_TEST))throw Error('Enabled scissor state mismatch');
   gl.disable(gl.SCISSOR_TEST);if(gl.getParameter(gl.SCISSOR_TEST)!==get(gl.SCISSOR_TEST))throw Error('Disabled scissor state mismatch');
  }
  if(gl.getParameter(gl.MAX_TEXTURE_SIZE)!==get(gl.MAX_TEXTURE_SIZE))throw Error('Unrelated parameter mismatch');
  return true;
 });
 checks.push('Cached state matches a real WebGL2 context after enable/disable; unrelated queries retain native values');
 if((await state()).intro_clock!==0)throw Error('Intro advanced before Start');
 await page.getByRole('button',{name:'Start',exact:true}).click();
 await page.waitForFunction(()=>{const t=JSON.parse(window.firetruckTouch.telemetry);return t.intro&&!t.loading;});
 await tour('maple intro','intro_clock');
 await command('pose',{x:0,z:12});
 await sample('station');
 await command('pose',{x:-36,z:25});
 await page.keyboard.down('w');await sample('maple driving');await page.keyboard.up('w');
 await command('pose',{x:42,z:18});
 await command('fill_pool',{value:.35});
 await page.keyboard.down('Shift');await page.keyboard.down('ArrowUp');
 await sample('pool spray');
 await page.keyboard.up('ArrowUp');await page.keyboard.up('Shift');
 await command('pose',{x:-42,z:-22});
 await page.keyboard.down('Shift');await page.keyboard.down('ArrowUp');
 await sample('barbecue spray');
 await page.keyboard.up('ArrowUp');await page.keyboard.up('Shift');
 await command('start_train');
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).north_exit_open,{},{timeout:5000});
 await command('pose',{x:0,z:-74});await command('pose',{x:0,z:-83});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).transition);
 await tour('motorway intro','transition_clock');
 await command('pose',{x:0,z:-54});
 await command('drive_race');await sample('race driving');await command('stop_race_drive');
 await command('pose',{x:0,z:-74});await command('pose',{x:0,z:-83});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).transition);
 await tour('return swap','transition_clock');
 await page.screenshot({path:'output/playwright/sixty-full-resolution.png'});
 if(errors.length)throw Error(errors.join('\n'));
 checks.push('Both full introductions, driving, spraying and the return swap complete without console errors');
 return {resolution:[1280,800],histogramBucketsMs:['<=18','18–25','25–35','35–50','>50'],scissor,checks,phases,errors};
}
