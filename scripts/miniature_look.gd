class_name MiniatureLook
extends CanvasLayer

var game: Node3D
var lens: ColorRect
var finish: ShaderMaterial
var focus_top:=.27
var focus_bottom:=.73
var strength:=1.0

func _ready() -> void:
	# Render after the world, before portraits, text, gauges and intro lettering.
	layer=0
	lens=ColorRect.new()
	lens.mouse_filter=Control.MOUSE_FILTER_IGNORE
	lens.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	finish=ShaderMaterial.new()
	finish.shader=preload("res://shaders/miniature.gdshader")
	lens.material=finish
	add_child(lens)

func _process(dt: float) -> void:
	if not game.camera or not game.truck: return
	var height:=maxf(1,game.camera.get_viewport().get_visible_rect().size.y)
	var centre: float=game.camera.unproject_position(game.truck.get_global_transform_interpolated().origin+Vector3.UP).y/height
	var top:=clampf(centre-.23,.12,.4)
	var bottom:=clampf(centre+.23,.6,.9)
	if (game.intro and game.intro.active) or (game.travel and game.travel.active):
		top=.25
		bottom=.74
	elif is_instance_valid(game.camera_subject) and game.conversation_blend>.01:
		var subject: float=game.camera.unproject_position(game.camera_subject.global_position+Vector3.UP*2).y/height
		# NPCs and the treetop cat remain crisp even during conversation panning.
		if game.camera_subject==game.town.people[0] and not game.cat_rescued:
			subject=minf(subject,game.camera.unproject_position(game.town.cat.global_position).y/height)
		top=minf(top,subject-.13)
		bottom=maxf(bottom,subject+.13)
	var blend:=1-exp(-5*dt)
	focus_top=lerpf(focus_top,top,blend)
	focus_bottom=lerpf(focus_bottom,bottom,blend)
	# Depth of field deepens roughly with the square of subject distance. The
	# orthographic size stands in for distance: gameplay framing (~26) keeps the
	# full effect, close conversations a touch more, the town overview very little.
	var reference:=25.8/maxf(1,game.camera.size)
	var target_strength:=clampf(reference*reference,.08,1.15)
	# Intro cuts change lens instantly; gameplay zooms ease with the camera.
	strength=target_strength if game.intro and game.intro.active else lerpf(strength,target_strength,1-exp(-8*dt))
	finish.set_shader_parameter("strength",strength)
	finish.set_shader_parameter("focus_top",focus_top)
	finish.set_shader_parameter("focus_bottom",focus_bottom)
