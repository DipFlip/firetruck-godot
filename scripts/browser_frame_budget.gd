class_name BrowserFrameBudget
extends RefCounted

# Lower only the 3D buffer, keeping text, portraits and meters at full size.
# Long windows and hysteresis prevent transient hitches or background-browser
# throttling from continually reallocating buffers or softening the scene.
const MIN_SCALE:=.75
const WINDOW_SECONDS:=2.0
var scale:=1.0
var window_seconds:=0.0
var frames:=0
var late_frames:=0
var steady_seconds:=0.0
var cooldown:=0.0

func sample(delta: float, foreground: bool) -> bool:
	if not foreground or delta<=0 or delta>.25:
		window_seconds=0
		frames=0
		late_frames=0
		steady_seconds=0
		return false
	cooldown=maxf(0,cooldown-delta)
	window_seconds+=delta
	frames+=1
	if delta>1.0/48: late_frames+=1
	if window_seconds<WINDOW_SECONDS: return false
	var fps:=frames/window_seconds
	var late_fraction:=float(late_frames)/frames
	steady_seconds=steady_seconds+window_seconds if fps>=59 and late_fraction<.02 else 0.0
	window_seconds=0
	frames=0
	late_frames=0
	if cooldown>0: return false
	var next:=scale
	if fps<55 and late_fraction>.10: next=maxf(MIN_SCALE,scale-.10)
	elif steady_seconds>=12: next=minf(1,scale+.05)
	if is_equal_approx(next,scale): return false
	scale=next
	steady_seconds=0
	cooldown=4
	return true
