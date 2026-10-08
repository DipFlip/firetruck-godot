// Real browser audio and cadence, including the newly spatial toy cues.
async page => {
 const errors=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.addInitScript(()=>{
  window.toyAudioProbe={roots:[]};
  const connect=AudioNode.prototype.connect;
  AudioNode.prototype.connect=function(destination,...args){
   if(destination===this.context.destination)toyAudioProbe.roots.push(this);
   return connect.call(this,destination,...args);
  };
 });
 await page.setViewportSize({width:1280,height:800});
 await page.goto('http://localhost:8064/?qa=travel&review=spatial-toys');
 await page.waitForFunction(()=>document.querySelector('#progress').getAttribute('aria-valuenow')==='100',{},{timeout:60000});
 await page.getByRole('button',{name:'Start',exact:true}).click();
 await page.waitForFunction(()=>window.firetruckTouch.telemetry&&!JSON.parse(window.firetruckTouch.telemetry).loading);
 await page.evaluate(async()=>{
  const roots=[...new Set(toyAudioProbe.roots)],context=roots[0].context;
  const source=`class ToyProbe extends AudioWorkletProcessor {
   constructor(){super();this.frames=0;this.peak=0;this.step=0;this.sum=0;this.last=[0,0];this.port.onmessage=()=>{this.port.postMessage({frames:this.frames,peak:this.peak,maxStep:this.step,rms:Math.sqrt(this.sum/Math.max(1,this.frames))});this.frames=this.peak=this.step=this.sum=0;};}
   process(inputs){for(let ch=0;ch<(inputs[0]||[]).length;ch++){for(const sample of inputs[0][ch]){this.frames++;this.sum+=sample*sample;this.peak=Math.max(this.peak,Math.abs(sample));this.step=Math.max(this.step,Math.abs(sample-this.last[ch]));this.last[ch]=sample;}}return true;}
  }registerProcessor('toy-probe',ToyProbe);`;
  const url=URL.createObjectURL(new Blob([source],{type:'application/javascript'}));
  await context.audioWorklet.addModule(url);URL.revokeObjectURL(url);
  const tap=new AudioWorkletNode(context,'toy-probe',{numberOfInputs:1,numberOfOutputs:1,outputChannelCount:[2]});
  const mute=context.createGain();mute.gain.value=0;tap.connect(mute).connect(context.destination);
  for(const root of roots)root.connect(tap);
  toyAudioProbe.tap=tap;
 });
 const state=()=>page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry));
 const before=await state();
 await page.waitForFunction(()=>!JSON.parse(window.firetruckTouch.telemetry).intro,{},{timeout:30000});
 const after=await state();
 const pcm=await page.evaluate(()=>new Promise(resolve=>{toyAudioProbe.tap.port.onmessage=e=>resolve(e.data);toyAudioProbe.tap.port.postMessage('stats');}));
 if(!(after.audio_counts.block_land>=15&&after.audio_counts.house_grow>=4))throw Error('Too few audible landing/growth cues');
 if(pcm.frames<10000||pcm.peak>=.95||pcm.rms===0)throw Error('Missing or clipped scene audio');
 if(errors.length)throw Error(errors.join('\n'));
 return {world:'Maple Bay',sounds:after.audio_counts,pcm,renderFrames:after.render_histogram.map((n,i)=>n-before.render_histogram[i]),fps:after.fps,errors};
}
