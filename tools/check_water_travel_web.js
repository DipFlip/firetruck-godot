// Hold the actual hose key across both mat exits, including the full intro.
async page => {
 const errors=[],checks=[],samples=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.bringToFront();
 await page.waitForFunction(()=>document.querySelector('#progress').getAttribute('aria-valuenow')==='100',{},{timeout:60000});
 await page.getByRole('button',{name:'Start',exact:true}).click();
 await page.waitForFunction(()=>window.firetruckTouch.telemetry&&!JSON.parse(window.firetruckTouch.telemetry).loading);
 const read=()=>page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry));
 const command=async(action,args={})=>{
  await page.evaluate(({action,args})=>{Object.assign(window.firetruckQA,{value:.85,...args,action});window.firetruckQA.sequence++;},{action,args});
  await page.waitForTimeout(250);
 };
 const check=(ok,label)=>{if(!ok)throw Error(label);checks.push(label);};
 await command('pose',{x:0,z:-74});
 await command('start_train');
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).north_exit_open,{},{timeout:10000});
 await page.keyboard.down('ArrowRight');
 await page.waitForFunction(()=>{const t=JSON.parse(window.firetruckTouch.telemetry);return t.cannon_spraying&&t.hose_gain>.9;});
 check((await read()).hose_gain>.9,'The water loop is audible before departure');
 await command('pose',{x:0,z:-83});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).transition);
 for(const clock of [1.2,8,20,24.5]){
  await page.waitForFunction(clock=>{const t=JSON.parse(window.firetruckTouch.telemetry);return t.transition&&t.transition_clock>=clock;},clock,{timeout:30000});
  const t=await read();
  samples.push({world:t.world,clock:t.transition_clock,gain:t.hose_gain,spraying:t.cannon_spraying,water:t.water});
  check(!t.cannon_spraying&&t.hose_gain<.001,'Cannon stays silent at intro '+clock+' seconds while the hose key is held');
 }
 check(samples.every(s=>Math.abs(s.water-samples[0].water)<.001),'The intro consumes no water while input is held');
 await page.keyboard.up('ArrowRight');
 await page.waitForFunction(()=>{const t=JSON.parse(window.firetruckTouch.telemetry);return !t.transition&&t.world==='race_track';},{},{timeout:10000});
 await page.waitForTimeout(500);
 check((await read()).hose_gain<.001,'Released input leaves the arriving truck silent');
 await command('pose',{x:0,z:-74});
 await page.keyboard.down('ArrowRight');
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).hose_gain>.9);
 await command('pose',{x:0,z:-83});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).transition);
 await page.waitForTimeout(1200);
 const returning=await read();
 check(returning.transition&&!returning.cannon_spraying&&returning.hose_gain<.001,'The short return transition also silences held cannon input');
 await page.waitForFunction(()=>{const t=JSON.parse(window.firetruckTouch.telemetry);return !t.transition&&t.world==='maple_bay';},{},{timeout:10000});
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).hose_gain>.9);
 check((await read()).cannon_spraying,'Cannon input works again when gameplay control returns');
 await page.keyboard.up('ArrowRight');
 await page.waitForFunction(()=>JSON.parse(window.firetruckTouch.telemetry).hose_gain<.001);
 if(errors.length)throw Error(errors.join('\n'));
 return {checks,samples,errors};
}
