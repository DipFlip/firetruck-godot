async page => {
 const t=await page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry));
 if(t.intro) await page.keyboard.press('Space');
 await page.waitForTimeout(1500);
 for(let i=0;i<3;i++) { if(await page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry).talking)) await page.keyboard.press('Space'); }
 const c=await page.context().newCDPSession(page);
 await c.send('Performance.enable');
 await c.send('Emulation.setCPUThrottlingRate',{rate:4});
 const measure=async label=>{
  const a=await c.send('Performance.getMetrics');
  const samples=await page.evaluate(()=>new Promise(resolve=>{
   const times=[],calls=[]; const start=performance.now();let last=start;
   function tick(now){times.push(now-last);last=now;calls.push(JSON.parse(window.firetruckTouch.telemetry).draw_calls);if(now-start<5000)requestAnimationFrame(tick);else resolve({times,calls});}requestAnimationFrame(tick);
  }));
  const b=await c.send('Performance.getMetrics');
  const metric=(o,n)=>o.metrics.find(m=>m.name===n).value;
  const median=v=>v.sort((a,b)=>a-b)[Math.floor(v.length*.5)];
  return {label,frames:samples.times.length,frameMsMedian:median(samples.times),drawCallsMedian:median(samples.calls),elapsed:metric(b,'Timestamp')-metric(a,'Timestamp'),taskSeconds:metric(b,'TaskDuration')-metric(a,'TaskDuration'),scriptSeconds:metric(b,'ScriptDuration')-metric(a,'ScriptDuration'),telemetry:await page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry))};
 };
 const idle=await measure('idle');
 await page.keyboard.down('Shift');await page.keyboard.down('ArrowUp');await page.waitForTimeout(1500);
 const spray=await measure('spray');
 await page.keyboard.up('ArrowUp');await page.keyboard.up('Shift');
 await c.send('Emulation.setCPUThrottlingRate',{rate:1});
 return {idle,spray};
}
