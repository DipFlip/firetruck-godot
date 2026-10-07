async page => {
 const errors=[];
 page.on('pageerror',error=>errors.push(String(error)));
 page.on('console',msg=>{if(msg.type()==='error')errors.push(msg.text());});
 const checks=[];
 const check=(ok,label)=>{if(!ok)throw Error(label);checks.push(label);};
 const telemetry=()=>page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry));
 await page.goto('http://localhost:8064/?qa=travel&check=start-gate');
 await page.waitForFunction(()=>document.querySelector('#progress').getAttribute('aria-valuenow')==='100' && window.firetruckTouch?.telemetry && JSON.parse(window.firetruckTouch.telemetry).intro_clock===0,{},{timeout:60000});
 const before=await telemetry();
 // Wait longer than the complete intro, reproducing a user who loads the
 // page and returns later. No automation command resets the intro clock.
 await page.waitForTimeout(27000);
 const held=await telemetry();
 check(await page.getByRole('button',{name:'Start',exact:true}).isVisible(),'Start screen remains visible after loading and a long wait');
 check(held.loading && held.intro && held.intro_clock===0 && held.game_clock===0 && before.truck_position.toString()===held.truck_position.toString(),'Intro, missions and truck stay at their initial state until Start');
 check(await page.evaluate(()=>window.firetruckStarted===false),'The shell has not started gameplay automatically');
 await page.screenshot({path:'output/playwright/browser-start-waiting.png'});
 await page.getByRole('button',{name:'Start',exact:true}).click();
 await page.waitForFunction(()=>window.firetruckStarted && !JSON.parse(window.firetruckTouch.telemetry).loading);
 const begun=await telemetry();
 check(begun.intro && begun.intro_clock<.75,'A delayed Start begins from the rolled-carpet opening');
 await page.screenshot({path:'output/playwright/browser-start-rolled.png'});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).intro_clock>=1);
 check((await telemetry()).intro_clock<2,'The intro clock advances only after Start');
 await page.goto('http://localhost:8064/?qa=travel&check=start-gate&early=1');
 await page.getByRole('button',{name:'Start',exact:true}).click();
 await page.waitForFunction(()=>window.firetruckTouch?.telemetry && window.firetruckStarted && !JSON.parse(window.firetruckTouch.telemetry).loading,{},{timeout:60000});
 const early=await telemetry();
 check(early.intro && early.intro_clock<.75,'Pressing Start before loading completes also begins at the opening');
 await page.screenshot({path:'output/playwright/browser-early-start-rolled.png'});
 check(errors.length===0,'No game or browser console errors: '+errors.join('; '));
 return {checks,delayedStart:begun.intro_clock,earlyStart:early.intro_clock,heldSeconds:27,errors};
}
