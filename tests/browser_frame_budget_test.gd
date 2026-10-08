extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+words)
	if not ok: failures+=1
func feed(budget: BrowserFrameBudget, fps: float, seconds: float, focused: bool=true) -> int:
	var changes:=0
	for frame in int(seconds*fps):
		if budget.sample(1.0/fps,focused): changes+=1
	return changes
func run() -> void:
	var budget:=BrowserFrameBudget.new()
	check(feed(budget,60,20)==0 and budget.scale==1,"A steady 60 fps keeps the full-resolution 3D image")
	check(feed(budget,30,20,false)==0 and budget.scale==1,"Background browser throttling does not lower picture quality")
	budget.sample(.8,true)
	check(budget.scale==1,"A single long loading/return-to-focus frame does not trigger a downgrade")
	check(feed(budget,40,2.1)==1 and budget.scale>.89 and budget.scale<.91,"Sustained missed frames reduce only one resolution step")
	check(feed(budget,40,2)==0,"The cooldown prevents repeated framebuffer changes during a busy shot")
	feed(budget,40,30)
	check(is_equal_approx(budget.scale,.75),"Persistent overload reaches a bounded render scale")
	check(feed(budget,60,6)==0,"Brief recovery does not immediately resize the scene again")
	feed(budget,60,70)
	check(is_equal_approx(budget.scale,1),"Long sustained recovery restores full resolution")
	quit(0 if failures==0 else 1)
