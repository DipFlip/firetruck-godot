// Diagnostic only: inspect mixed PCM, including starts/stops during deliberate
// rendering stalls. Quiet output rules out clipping from simultaneous sounds;
// sample discontinuities matter even when graphics FPS stays high.
async page => {
 const errors=[],phases=[];
 const baseline=page.url().includes('audio-baseline');
 if(baseline)await page.route('**/index.pck',route=>route.fulfill({path:'output/playwright/audio-baseline.pck',contentType:'application/octet-stream'}));
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.addInitScript(()=>{
  if(window.audioProbe)return;
  window.audioProbe={buffers:[],roots:[]};
  const connect=AudioNode.prototype.connect;
  AudioNode.prototype.connect=function(destination,...args){
   if(destination===this.context.destination)audioProbe.roots.push(this);
   return connect.call(this,destination,...args);
  };
  const Base=window.AudioWorkletNode;
  window.AudioWorkletNode=class extends Base {
   constructor(context,name,options){
    super(context,name,options);
    if(name!=='godot-processor')return;
    const post=this.port.postMessage.bind(this.port);
    this.port.postMessage=(message,...args)=>{
     if(message.cmd==='start_nothreads')audioProbe.buffers.push({samples:message.data[0].length,channels:options.outputChannelCount[0],sampleRate:context.sampleRate});
     return post(message,...args);
    };
   }
  };
 });
 await page.bringToFront();
 await page.setViewportSize({width:1280,height:800});
 await page.goto('http://localhost:8064/?qa=travel&review=audio-buffer');
 await page.waitForFunction(()=>document.body.classList.contains('intro')&&document.querySelector('#progress').getAttribute('aria-valuenow')==='100',{},{timeout:60000});
 await page.getByRole('button',{name:'Start',exact:true}).click();
 await page.waitForFunction(()=>!JSON.parse(window.firetruckTouch.telemetry).loading);
 const command=async(action,args={})=>{await page.evaluate(({action,args})=>{Object.assign(window.firetruckQA,{value:.82,...args,action});window.firetruckQA.sequence++;},{action,args});await page.waitForTimeout(250);};
 await command('pose',{x:0,z:12});
 await page.waitForTimeout(1000);
 await page.evaluate(async()=>{
  const roots=[...new Set(audioProbe.roots)],context=roots[0].context;
  const code=`class PCMProbe extends AudioWorkletProcessor {
   constructor(){super();this.blocks=0;this.zero=0;this.peak=0;this.step=0;this.last=[0,0];this.port.onmessage=()=>{this.port.postMessage({blocks:this.blocks,silentBlocks:this.zero,peak:this.peak,maxStep:this.step});this.blocks=this.zero=this.peak=this.step=0;};}
   process(inputs){let silent=true;const input=inputs[0]||[];for(let ch=0;ch<input.length;ch++){for(const sample of input[ch]){if(Math.abs(sample)>1e-9)silent=false;this.peak=Math.max(this.peak,Math.abs(sample));this.step=Math.max(this.step,Math.abs(sample-(this.last[ch]||0)));this.last[ch]=sample;}}this.blocks++;if(silent)this.zero++;return true;}
  }registerProcessor('pcm-probe',PCMProbe);`;
  const url=URL.createObjectURL(new Blob([code],{type:'application/javascript'}));
  await context.audioWorklet.addModule(url);URL.revokeObjectURL(url);
  const tap=new AudioWorkletNode(context,'pcm-probe',{numberOfInputs:1,numberOfOutputs:1,outputChannelCount:[2]});
  const mute=context.createGain();mute.gain.value=0;tap.connect(mute).connect(context.destination);
  for(const root of roots)root.connect(tap);
  audioProbe.tap=tap;
 });
 const stats=()=>page.evaluate(()=>new Promise(resolve=>{audioProbe.tap.port.onmessage=e=>resolve(e.data);audioProbe.tap.port.postMessage('stats');}));
 const sample=async(label,delay=0)=>{
  await stats();
  await page.evaluate(delay=>new Promise(resolve=>{
   const until=performance.now()+8000;
   function next(){if(performance.now()>=until){resolve();return;}if(delay){const busy=performance.now()+delay;while(performance.now()<busy){}}setTimeout(next,400);}
   next();
  }),delay);
  const pcm=await stats();
  const t=await page.evaluate(()=>JSON.parse(window.firetruckTouch.telemetry));
  phases.push({label,injectedBusyMs:delay,pcm,fps:t.fps});
 };
 await sample('station and phone');
 await command('pose',{x:42,z:18});await command('fill_pool',{value:.35});
 await page.keyboard.down('Shift');await page.keyboard.down('ArrowUp');
 await sample('pool and water');
 await sample('pool with 75ms main-thread stalls',75);
 await page.keyboard.up('ArrowUp');await page.keyboard.up('Shift');
 await command('pose',{x:-42,z:-22});
 await page.keyboard.down('Shift');await page.keyboard.down('ArrowUp');
 await sample('barbecue and water');
 await page.keyboard.up('ArrowUp');await page.keyboard.up('Shift');
 const buffers=await page.evaluate(()=>audioProbe.buffers.map(b=>({...b,bufferMs:b.samples/b.channels/b.sampleRate*1000})));
 if(!buffers.length)throw Error('No Godot audio buffer captured');
 if(phases.some(p=>p.pcm.peak>=1||p.pcm.blocks<2000))throw Error('Clipped or missing audio capture');
 if(errors.length)throw Error(errors.join('\n'));
 return {build:baseline?'before':'after',buffers,phases,errors};
}
