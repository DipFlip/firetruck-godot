async page => {
 const errors=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 const checks=[];
 const check=(ok,label)=>{if(!ok)throw Error(label);checks.push(label);};
 const telemetry=()=>page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry));
 const command=async(action,args={})=>{
  await page.evaluate(({action,args})=>{Object.assign(window.firetruckQA,args,{action});window.firetruckQA.sequence++;},{action,args});
  await page.waitForTimeout(250);
 };
 await page.setViewportSize({width:1280,height:800});
 await page.goto('http://localhost:8064/?qa=travel&review=layered-carpet');
 await page.waitForFunction(()=>window.firetruckTouch?.telemetry && document.querySelector('#progress').getAttribute('aria-valuenow')==='100',{},{timeout:60000});
 await page.waitForTimeout(1200);
 check((await telemetry()).intro_clock===0,'The rollout is held at its opening frame until Start');
 await page.getByRole('button',{name:'Start',exact:true}).click();
 await page.waitForFunction(()=>!JSON.parse(window.firetruckTouch.telemetry).loading);
 const begun=await telemetry();
 check(begun.intro_clock<.75,'Start begins with the fully rolled mat');
 const captures=[];
 for(const time of [.25,1.1,2.4,3.5,5.1,6.7,8.2,9.4,11.3,12.3,13.4,14.3,15.2,16.4,17.4,18.4,19.4,20.5,21.8,22.8,23.6]) {
  await page.waitForFunction(time=>JSON.parse(window.firetruckTouch.telemetry).intro_clock>=time,time,{timeout:10000});
  await page.screenshot({path:`output/playwright/layered-browser-maple-${String(time).replace('.','-')}.png`});
  captures.push({world:'maple',clock:(await telemetry()).intro_clock});
 }
 await page.waitForFunction(()=>!JSON.parse(window.firetruckTouch.telemetry).intro);
 await page.keyboard.down('w');
 await page.waitForTimeout(500);
 await page.keyboard.up('w');
 check((await telemetry()).speed>.5,'The camera handoff returns responsive truck control');
 await command('start_train');
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).north_exit_open,{},{timeout:10000});
 await command('pose',{x:0,z:-74,value:0});
 await command('pose',{x:0,z:-83,value:0});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).transition);
 for(const time of [.5,1.2,2.25,3.3,4.4,5.5,7,8.7,10.2,13.3,14.3,15.4,16.3,17.2,18.4,19.4,20.4,21.4,22.5,23.8,24.8,25.6]) {
  await page.waitForFunction(time=>JSON.parse(window.firetruckTouch.telemetry).transition_clock>=time,time,{timeout:10000});
  await page.screenshot({path:`output/playwright/layered-browser-race-${String(time).replace('.','-')}.png`});
  captures.push({world:'race',clock:(await telemetry()).transition_clock});
 }
 await page.waitForFunction(()=>!JSON.parse(window.firetruckTouch.telemetry).transition);
 await page.keyboard.down('s');
 await page.waitForTimeout(500);
 await page.keyboard.up('s');
 check((await telemetry()).world==='race_track' && (await telemetry()).speed>.5,'The first race rollout and full camera tour restore responsive control');
 await command('pose',{x:0,z:-74,value:0});
 await command('pose',{x:0,z:-83,value:0});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).transition);
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).transition_clock>=1.1);
 await page.screenshot({path:'output/playwright/layered-browser-return-roll.png'});
 await page.waitForFunction(()=>!JSON.parse(window.firetruckTouch.telemetry).transition);
 check((await telemetry()).world==='maple_bay','The short return rolls up and swaps the complete carpet');
 check(errors.length===0,'Both introductions and the short return have no browser/game console errors');
 return {checks,captures,errors};
}
