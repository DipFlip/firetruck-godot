async page => {
 const errors=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 const checks=[];
 const check=(ok,label)=>{if(!ok)throw Error(label);checks.push(label);};
 const state=()=>page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry));
 const command=async(action,args={})=>{await page.evaluate(({action,args})=>{Object.assign(window.firetruckQA,args,{action});window.firetruckQA.sequence++;},{action,args});await page.waitForTimeout(260);};
 await page.setViewportSize({width:1280,height:800});
 await page.goto('http://localhost:8064/?qa=travel&review=scene-details');
 await page.getByRole('button',{name:'Start',exact:true}).click();
 await page.waitForFunction(()=>window.firetruckTouch?.telemetry && !JSON.parse(window.firetruckTouch.telemetry).loading,{},{timeout:60000});
 await page.screenshot({path:'output/playwright/browser-details-rolled.png'});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).intro_clock>2.6);
 await page.screenshot({path:'output/playwright/browser-details-unfolding.png'});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).intro_clock>4.8);
 await page.screenshot({path:'output/playwright/browser-details-empty-maple.png'});
 await page.waitForFunction(()=>!JSON.parse(window.firetruckTouch.telemetry).intro,{},{timeout:28000});
 await page.screenshot({path:'output/playwright/browser-details-intersection.png'});
 await command('pose',{x:0,z:-64});
 await command('start_train');
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).north_exit_open,{},{timeout:10000});
 await page.screenshot({path:'output/playwright/browser-details-crossing.png'});
 await command('pose',{x:0,z:-74});
 await command('pose',{x:0,z:-83});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).transition);
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).transition_clock>6.8,{},{timeout:10000});
 await page.screenshot({path:'output/playwright/browser-details-empty-race.png'});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).transition_clock>21.7,{},{timeout:22000});
 await page.screenshot({path:'output/playwright/browser-details-race-intro.png'});
 await page.waitForFunction(()=>{const t=JSON.parse(window.firetruckTouch.telemetry);return t.world==='race_track'&&!t.transition;},{},{timeout:10000});
 check((await state()).world==='race_track','The rebuilt race mat loads and restores driving control');
 // Actual steering impacts the blue parked racer beside the pit garage.
 // Align on the open straight first; a south-facing arrival would turn
 // around the car instead of hitting it.
 await command('pose',{x:-40,z:-54});
 await page.evaluate(()=>{window.firetruckTouch.driveX=.876;window.firetruckTouch.driveY=.483;});
 await page.waitForTimeout(1300);
 await command('pose',{x:-28,z:-63});
 await page.evaluate(()=>{window.firetruckTouch.driveX=.876;window.firetruckTouch.driveY=.483;});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).loose_race_props>0,{},{timeout:6000});
 await page.evaluate(()=>{window.firetruckTouch.driveX=0;window.firetruckTouch.driveY=0;});
 check((await state()).loose_race_props>0,'Driving into a paddock toy releases its real rigid body');
 await page.screenshot({path:'output/playwright/browser-details-racer-impact.png'});
 const gates=(await state()).race_gates;
 for(const index of [0,1,2,3,0]) {
  const g=gates[index];
  await command('pose',{x:g.x-g.dx*3,z:g.z-g.dz*3,value:g.y});
  await command('pose',{x:g.x+g.dx*3,z:g.z+g.dz*3,value:g.y});
 }
 check((await state()).best_lap>0,'The arches validate a complete lap on the smoothed course');
 await command('pose',{x:2,z:3,value:8.1});
 await page.waitForTimeout(2200);
 await page.screenshot({path:'output/playwright/browser-details-bridge.png'});
 await command('pose',{x:0,z:-74});
 await command('pose',{x:0,z:-83});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).transition);
 await page.waitForFunction(()=>{const t=JSON.parse(window.firetruckTouch.telemetry);return t.world==='maple_bay'&&!t.transition;},{},{timeout:35000});
 check((await state()).world==='maple_bay','Returning restores Maple Bay and suspends the race scene');
 check(errors.length===0,'No browser or game console errors: '+errors.join(' | '));
 return {checks,errors};
}
