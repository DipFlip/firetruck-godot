async page => {
 const errors=[];page.on('pageerror',error=>errors.push(String(error)));
 await page.setViewportSize({width:1280,height:800});
 await page.goto('http://localhost:8064/?qa=travel&review=oct6');
 await page.getByRole('button',{name:'Start',exact:true}).click();
 await page.waitForFunction(()=>window.firetruckTouch?.telemetry && !JSON.parse(window.firetruckTouch.telemetry).loading,{},{timeout:60000});
 for(const [phase,delay,name] of [[1,950,'border-cascade'],[2,300,'turn-inward'],[3,400,'station'],[4,1100,'east']]) {
  await page.waitForFunction(phase=>JSON.parse(window.firetruckTouch.telemetry).intro_shot>=phase,phase,{timeout:15000});
  await page.waitForTimeout(delay);
  await page.screenshot({path:`output/playwright/browser-continuous-${name}.png`});
 }
 await page.waitForFunction(()=>!JSON.parse(window.firetruckTouch.telemetry).intro,{},{timeout:8000});

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
 for(const [time,name] of [[6.2,'race-border'],[8.5,'race-turn'],[10.0,'race-bridge']]) {
  await page.waitForFunction(time=>JSON.parse(window.firetruckTouch.telemetry).transition_clock>=time,time,{timeout:15000});
  await page.screenshot({path:`output/playwright/browser-continuous-${name}.png`});
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
 const gates=[{x:46,z:-13,dx:-.9635,dz:.2676,y:.85},{x:-60,z:53,dx:.6347,dz:.7727,y:.85},{x:0,z:4,dx:-.7682,dz:-.6402,y:7.85},{x:0,z:-54,dx:1,dz:0,y:.85}];
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
 check(errors.length===0,'No browser page errors during the intro, racing and round trip');
 return {checks,telemetry:t,errors};
}
