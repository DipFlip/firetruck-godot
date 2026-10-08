async page => {
 const errors=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.setViewportSize({width:1280,height:800});
 await page.goto('http://localhost:8064/?qa=travel&review=intro-performance');
 await page.waitForFunction(()=>window.firetruckTouch?.telemetry && document.querySelector('#progress').getAttribute('aria-valuenow')==='100',{},{timeout:60000});
 const waiting=JSON.parse(await page.evaluate(()=>window.firetruckTouch.telemetry));
 const c=await page.context().newCDPSession(page);
 await c.send('Performance.enable');
 const a=await c.send('Performance.getMetrics');
 await page.getByRole('button',{name:'Start',exact:true}).click();
 await page.waitForFunction(()=>{const t=JSON.parse(window.firetruckTouch.telemetry);return t.intro&&!t.loading;});
 const samples=await page.evaluate(()=>new Promise(resolve=>{
  const frames=[],states=[];let last=performance.now(),lastState=-1;
  function tick(now) {
   const t=JSON.parse(window.firetruckTouch.telemetry);
   frames.push({clock:t.intro_clock,ms:now-last});last=now;
   if(t.intro_clock-lastState>=.2) {states.push(t);lastState=t.intro_clock;}
   if(t.intro)requestAnimationFrame(tick);else resolve({frames,states});
  }
  requestAnimationFrame(tick);
 }));
 const b=await c.send('Performance.getMetrics');
 const metric=(o,n)=>o.metrics.find(m=>m.name===n).value;
 const percentile=(v,q)=>v.sort((a,b)=>a-b)[Math.min(v.length-1,Math.floor(v.length*q))];
 const phases=[];
 for(let start=0;start<24;start+=4) {
  const times=samples.frames.filter(f=>f.clock>=start&&f.clock<start+4).map(f=>f.ms);
  const states=samples.states.filter(t=>t.intro_clock>=start&&t.intro_clock<start+4);
  phases.push({start,end:start+4,frames:times.length,medianMs:percentile(times,.5),p95Ms:percentile(times,.95),over50ms:times.filter(t=>t>50).length,drawCalls:percentile(states.map(t=>t.draw_calls),.5)});
 }
 return {waitingClock:waiting.intro_clock,phases,taskSeconds:metric(b,'TaskDuration')-metric(a,'TaskDuration'),scriptSeconds:metric(b,'ScriptDuration')-metric(a,'ScriptDuration'),states:samples.states.map(t=>({clock:t.intro_clock,lens:t.camera_size,fps:t.fps,drawCalls:t.draw_calls})),errors};
}
