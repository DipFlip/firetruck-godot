async page => {
 const errors=[];page.on('pageerror',error=>errors.push(String(error)));page.on('console',msg=>{if(msg.type()==='error')errors.push(msg.text());});
 await page.setViewportSize({width:1280,height:800});
 await page.goto('http://localhost:8064/?qa=travel&review=paced-intro');
 await page.getByRole('button',{name:'Start',exact:true}).click();
 await page.waitForFunction(()=>window.firetruckTouch?.telemetry && !JSON.parse(window.firetruckTouch.telemetry).loading,{},{timeout:60000});
 await page.waitForTimeout(200);
 await page.screenshot({path:'output/playwright/browser-paced-rolled.png'});
 await page.waitForTimeout(4500);
 await page.screenshot({path:'output/playwright/browser-paced-empty-mat.png'});
 for(const [phase,delay,name] of [[1,1100,'first-house'],[1,1900,'trees-neighbour'],[2,1900,'border-cascade'],[3,2500,'town'],[4,2000,'finished-title']]) {
  await page.waitForFunction(phase=>JSON.parse(window.firetruckTouch.telemetry).intro_shot>=phase,phase,{timeout:18000});
  await page.waitForTimeout(delay);
  await page.screenshot({path:`output/playwright/browser-paced-${name}.png`});
 }
 await page.waitForFunction(()=>!JSON.parse(window.firetruckTouch.telemetry).intro,{},{timeout:12000});
 await page.screenshot({path:'output/playwright/browser-paced-control.png'});

 const telemetry=()=>page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry));
 const command=async(action,args={})=>{await page.evaluate(({action,args})=>{Object.assign(window.firetruckQA,args,{action});window.firetruckQA.sequence++;},{action,args});await page.waitForTimeout(260);};
 if((await telemetry()).intro) await page.keyboard.press("Space");
 const checks=[];
 const check=(ok,label)=>{if(!ok)throw Error(label);checks.push(label);};
 await command('start_train');
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).north_exit_open,{},{timeout:10000});
 await command('pose',{x:0,z:-74,value:0});
 await command('pose',{x:0,z:-83,value:0});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).transition);
 await page.waitForTimeout(700);
 await page.screenshot({path:'output/playwright/browser-town-roll.png'});
 for(const [time,name] of [[6.8,'race-empty'],[9.6,'race-first-house'],[14.4,'race-border'],[19.0,'race-bridge']]) {
  await page.waitForFunction(time=>JSON.parse(window.firetruckTouch.telemetry).transition_clock>=time,time,{timeout:15000});
  await page.screenshot({path:`output/playwright/browser-paced-${name}.png`});
 }
 await page.waitForFunction(()=>{const t=JSON.parse(window.firetruckTouch.telemetry);return t.world==='race_track'&&!t.transition;},{},{timeout:35000});
 let t=await telemetry();
 check(t.truck_position[0]>390&&t.truck_position[1]<-70,'Arrival from the north restores race-track control');
 await page.screenshot({path:'output/playwright/browser-race-arrival.png'});
 await command('pose',{x:-15,z:-54});
 // Actual drive input crosses the start line; no race state is injected.
 await page.evaluate(()=>{window.firetruckTouch.driveX=.876;window.firetruckTouch.driveY=.483;});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).lap_running,{},{timeout:5000});
 await page.evaluate(()=>{window.firetruckTouch.driveX=0;window.firetruckTouch.driveY=0;});
 check((await telemetry()).race_checkpoint===1,'Driving east through START begins a timed lap');
 // Swept gate crossings follow each arch's actual road tangent and elevation.
 const positions=(await telemetry()).race_gates;
 const gates=[...positions.slice(1),positions[0]];
 for(const g of gates) {
  await command('pose',{x:g.x-g.dx*3,z:g.z-g.dz*3,value:g.y});
  await command('pose',{x:g.x+g.dx*3,z:g.z+g.dz*3,value:g.y});
 }

 t=await telemetry();
 check(t.best_lap>0&&t.race_checkpoint===1,'Ordered checkpoints finish a lap, update the record and start the next attempt');
 await page.screenshot({path:'output/playwright/browser-race-record.png'});
 await command('pose',{x:0,z:-74,value:0});
 await command('pose',{x:0,z:-83,value:0});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).transition);
 await page.waitForTimeout(700);
 await page.screenshot({path:'output/playwright/browser-race-roll.png'});
 await page.waitForFunction(()=>{const t=JSON.parse(window.firetruckTouch.telemetry);return t.world==='maple_bay'&&!t.transition;},{},{timeout:35000});
 t=await telemetry();
 check(t.truck_position[0]<10&&t.truck_position[1]<-70,'The same north street returns to Maple Bay with control restored');
 await page.screenshot({path:'output/playwright/browser-maple-return.png'});
 check(errors.length===0,'No browser or game console errors during the intro, racing and round trip');
 return {checks,telemetry:t,errors};
}
