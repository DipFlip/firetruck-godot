async page => {
 const command=async(action,args={})=>page.evaluate(({action,args})=>{Object.assign(window.firetruckQA,args,{action});window.firetruckQA.sequence++;},{action,args});
 await page.keyboard.press('Space');
 await command('pose',{x:14,z:61});
 await page.waitForTimeout(1800);
 for(let i=0;i<3;i++) if(await page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry).talking)) await page.keyboard.press('Space');
 const results=[];
 for(let pass=0;pass<3;pass++){
  await command('fill_pool',{value:0});await page.waitForTimeout(400);
  const sample=await page.evaluate(()=>new Promise(resolve=>{
   const frames=[];let previous=performance.now();const start=previous;
   Object.assign(window.firetruckQA,{action:'fill_pool',value:.04});window.firetruckQA.sequence++;
   function frame(now){frames.push(now-previous);previous=now;if(now-start<1000)requestAnimationFrame(frame);else resolve(frames);}requestAnimationFrame(frame);
  }));
  const sorted=sample.slice().sort((a,b)=>a-b);
  results.push({pass,frames:sample.length,medianMs:sorted[Math.floor(sorted.length*.5)],p95Ms:sorted[Math.floor(sorted.length*.95)],maxMs:Math.max(...sample),firstTenMs:sample.slice(0,10)});
 }
 return {results,telemetry:await page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry))};
}
