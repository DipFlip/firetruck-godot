/* Godot's final framebuffer blit reads SCISSOR_TEST every frame. WebGL
 * getParameter synchronizes with the graphics driver even though enable/
 * disable already tell us this boolean. Track that one state on this game's
 * context; every other query still uses the browser's original implementation.
 */
(function () {
 'use strict';
 const installed=new WeakSet();
 let paced=false;
 function createFramePacer(request,cancel,reportError) {
  const callbacks=new Map(),periods=Array(15).fill(1000/120);
  let sequence=0,nativeId=null,lastTimestamp=null,framesSinceDraw=0;
  function schedule() {if(nativeId===null)nativeId=request(tick);}
  function tick(timestamp) {
   nativeId=null;
   const delta=lastTimestamp===null?null:timestamp-lastTimestamp;
   lastTimestamp=timestamp;
   if(delta!==null&&delta>=3&&delta<=45){periods.shift();periods.push(delta);}
   const median=periods.slice().sort((a,b)=>a-b)[7];
   // Align to whole browser refreshes instead of a drifting 16.667ms clock.
   // 120/240Hz use every second/fourth tick; 90/144Hz retain 90/72fps.
   // Allow a little timestamp jitter around 120/240Hz: a measured 119Hz
   // must not suddenly select every tick. Count missed native ticks too,
   // so a change from 120Hz to 60Hz keeps drawing on every new refresh.
   const divisor=Math.max(1,Math.floor(1000/(median*60)+.05));
   framesSinceDraw+=delta===null||delta>45?divisor:Math.max(1,Math.round(delta/median));
   if(framesSinceDraw>=divisor) {
    framesSinceDraw%=divisor;
    const ready=[...callbacks.keys()];
    for(const id of ready) {
     const callback=callbacks.get(id);
     if(!callback)continue; // Earlier callbacks may cancel a later one.
     callbacks.delete(id);
     try {callback.call(window,timestamp);} catch(error) {reportError(error);}
    }
   }
   if(callbacks.size)schedule();
  }
  return {
   request(callback) {
    if(typeof callback!=='function')throw new TypeError('Animation frame callback must be a function');
    const id=++sequence;callbacks.set(id,callback);schedule();return id;
   },
   cancel(id) {
    callbacks.delete(id);
    if(!callbacks.size&&nativeId!==null){cancel(nativeId);nativeId=null;}
   }
  };
 }
 function paceFrames() {
  if(paced)return;
  paced=true;
  // In the single-threaded web export Engine.max_fps spent the entire spare
  // frame budget waiting inside WASM. Let the browser schedule those gaps.
  const pacing=createFramePacer(window.requestAnimationFrame.bind(window),window.cancelAnimationFrame.bind(window),error=>{
   if(window.reportError)window.reportError(error);
   else setTimeout(()=>{throw error;});
  });
  window.requestAnimationFrame=pacing.request;
  window.cancelAnimationFrame=pacing.cancel;
 }
 function cacheScissorState(gl) {
  if(installed.has(gl)) return gl;
  installed.add(gl);
  const get=gl.getParameter.bind(gl),enable=gl.enable.bind(gl),disable=gl.disable.bind(gl);
  let scissor=get(gl.SCISSOR_TEST);
  gl.getParameter=function(parameter) {
   if(parameter===gl.SCISSOR_TEST&&!gl.isContextLost()) return scissor;
   return get(parameter);
  };
  gl.enable=function(capability) {
   enable(capability);
   if(capability===gl.SCISSOR_TEST) scissor=true;
  };
  gl.disable=function(capability) {
   disable(capability);
   if(capability===gl.SCISSOR_TEST) scissor=false;
  };
  // Restored WebGL contexts return to their default (disabled) scissor state.
  gl.canvas.addEventListener('webglcontextrestored',()=>{scissor=false;});
  return gl;
 }
 function install(canvas) {
  paceFrames();
  const getContext=canvas.getContext;
  canvas.getContext=function(type,...args) {
   const context=getContext.call(this,type,...args);
   if(this===canvas&&type==='webgl2'&&context) cacheScissorState(context);
   return context;
  };
 }
 window.firetruckRenderBudget={install,cacheScissorState,createFramePacer};
})();
