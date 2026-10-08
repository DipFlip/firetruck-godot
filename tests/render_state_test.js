// State tracking must match real WebGL semantics without caching unrelated
// values. The browser QA also checks it against an actual WebGL 2 context.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const window={};
vm.runInNewContext(fs.readFileSync('web/render_budget.js','utf8'),{window,WeakSet});
let scissor=false,lost=false,queries=0;
const listeners={};
const gl={SCISSOR_TEST:3089,canvas:{addEventListener:(event,callback)=>{listeners[event]=callback;}},
 getParameter(p){queries++;return lost?null:p===3089?scissor:'other state';},
 enable(p){if(p===3089&&!lost)scissor=true;},disable(p){if(p===3089&&!lost)scissor=false;},isContextLost(){return lost;}};
const native=gl.getParameter.bind(gl);
window.firetruckRenderBudget.cacheScissorState(gl);
assert.equal(queries,1);
for(let i=0;i<100;i++){
 gl.enable(gl.SCISSOR_TEST);
 assert.equal(gl.getParameter(gl.SCISSOR_TEST),scissor);
 gl.disable(gl.SCISSOR_TEST);
 assert.equal(gl.getParameter(gl.SCISSOR_TEST),scissor);
}
assert.equal(queries,1,'Hot scissor reads must not synchronize with the driver');
assert.equal(gl.getParameter(1234),native(1234));
const before=queries;
window.firetruckRenderBudget.cacheScissorState(gl);
assert.equal(queries,before,'Installation must be idempotent');
lost=true;
gl.enable(gl.SCISSOR_TEST);
assert.equal(gl.getParameter(gl.SCISSOR_TEST),null,'Lost contexts retain native query behaviour');
lost=false;scissor=false;
listeners.webglcontextrestored();
assert.equal(gl.getParameter(gl.SCISSOR_TEST),false);
gl.enable(gl.SCISSOR_TEST);
assert.equal(gl.getParameter(gl.SCISSOR_TEST),true);
console.log('PASS: Cached WebGL state follows enable/disable, delegates unrelated queries, and resets on context restoration');
let nativeSequence=0;
const frames=new Map(),errors=[];
const pacer=window.firetruckRenderBudget.createFramePacer(cb=>{const id=++nativeSequence;frames.set(id,cb);return id;},id=>frames.delete(id),error=>errors.push(error));
function tick(timestamp) {const ready=[...frames.values()];frames.clear();for(const cb of ready)cb(timestamp);}
const delivered=[];
function animate(timestamp) {delivered.push(timestamp);pacer.request(animate);}
pacer.request(animate);
for(let i=0;i<120;i++)tick(i*1000/120);
assert.equal(delivered.length,60,'A 120Hz display must render only 60 frames without a busy loop');
const start=delivered.length;
for(let i=0;i<60;i++)tick(1000+i*1000/60);
assert.equal(delivered.length-start,60,'Switching to a 60Hz display must not halve the frame rate');
tick(10000);
assert.equal(delivered.at(-1),10000,'A background/resume gap must resume without a catch-up burst');
let canceledRan=false;
const canceled=pacer.request(()=>{canceledRan=true;});pacer.cancel(canceled);
tick(10017);
assert.equal(canceledRan,false);
let sameFrameCanceled=false,second;
pacer.request(()=>pacer.cancel(second));second=pacer.request(()=>{sameFrameCanceled=true;});tick(10034);
assert.equal(sameFrameCanceled,false);
let survived=false;
pacer.request(()=>{throw Error('test error');});pacer.request(()=>{survived=true;});tick(10051);
assert.equal(survived,true);assert.equal(errors.length,1);
assert.throws(()=>pacer.request(null),{name:'TypeError'});
function sampleDisplay(hz,jitter=0) {
 let pending=null,count=0;
 const display=window.firetruckRenderBudget.createFramePacer(cb=>{pending=cb;return 1;},()=>{pending=null;},error=>{throw error;});
 const draw=()=>{count++;display.request(draw);};
 display.request(draw);
 for(let i=0;i<hz*2;i++) {
  if(i===hz)count=0; // Let the measured native refresh settle first.
  const cb=pending;pending=null;cb(i*1000/hz+Math.sin(i)*jitter);
 }
 return count;
}
for(const [hz,expected] of [[60,60],[90,90],[120,60],[144,72],[240,60]])
 assert.equal(sampleDisplay(hz),expected,`${hz}Hz must align frames to the display without dropping below 60fps`);
assert.equal(sampleDisplay(120,.12),60,'Small timestamp jitter must not switch a 120Hz display to 120fps');
assert.ok([59,60].includes(sampleDisplay(119)),'Refresh measurement near 120Hz must retain every second tick');
console.log('PASS: Browser scheduling aligns 60/90/120/144/240Hz displays, tolerates jitter, resumes cleanly, supports cancellation and isolates callback errors');
