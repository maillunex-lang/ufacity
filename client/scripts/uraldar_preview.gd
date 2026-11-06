extends Node3D

const CLIPS := [
	"Running", "Walking", "Charged_Slash", "Combat_Stance", "Dead",
	"Hit_Reaction", "Left_Slash", "Skill_01", "Sword_Shout", "Thrust_Slash",
]
const LOOPED := ["Running", "Walking", "Combat_Stance"]
const MODEL := "res://assets/heroes/uraldar.glb"
const MAP := "res://data/uraldar_clips.json"

var _player: AnimationPlayer
var _hero: Node3D
var _fx: Node3D
var _speed := 1.0
var _paused := false
var _repeat := false
var _effects := true
var _aura := false
var _dead := false
var _clip := ""
var _title: Label
var _state: Label
var _clock: Label


func _ready() -> void:
	_stage()
	_hero = _load_hero()
	_ui()
	_play_clip("Combat_Stance")


func _stage() -> void:
	var floor_mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 3.2
	disc.bottom_radius = 3.2
	disc.height = 0.16
	disc.radial_segments = 40
	floor_mesh.mesh = disc
	floor_mesh.position.y = -0.08
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("3c4650")
	floor_mesh.material_override = stone
	add_child(floor_mesh)
	var body := StaticBody3D.new()
	body.position.y = -0.08
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 3.2
	cylinder.height = 0.16
	shape.shape = cylinder
	body.add_child(shape)
	add_child(body)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1a2430")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8ea2b8")
	env.ambient_light_energy = 0.7
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -36, 0)
	sun.light_energy = 1.3
	add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1.5, 2.2, 2.0)
	fill.light_energy = 0.6
	fill.omni_range = 8.0
	add_child(fill)
	_dummy()
	var camera := Camera3D.new()
	camera.name = "PreviewCamera"
	camera.fov = 38.0
	camera.position = Vector3(-2.7, 1.65, 2.8)
	add_child(camera)
	camera.look_at(Vector3(0, 0.9, 0.35))
	camera.current = true


func _dummy() -> void:
	var target := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.28
	capsule.height = 1.5
	target.mesh = capsule
	target.position = Vector3(0, 0.75, 2.15)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("8d4a3a")
	target.material_override = paint
	add_child(target)
	var label := Label3D.new()
	label.text = "Цель"
	label.font_size = 42
	label.position = Vector3(0, 1.7, 2.15)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func _load_hero() -> Node3D:
	var packed := load(MODEL) as PackedScene
	if packed == null:
		_warn("Модель не загрузилась")
		return null
	var node := packed.instantiate() as Node3D
	add_child(node)
	_player = _find_player(node)
	_fx = Node3D.new()
	_fx.name = "Effects"
	add_child(_fx)
	if _player == null:
		_warn("AnimationPlayer не найден")
		return node
	_plant(node)
	_apply_loops()
	_player.animation_finished.connect(_on_finished)
	return node


func _apply_loops() -> void:
	for clip in CLIPS:
		var anim := _animation(clip)
		if anim == null:
			continue
		anim.loop_mode = Animation.LOOP_LINEAR if clip in LOOPED else Animation.LOOP_NONE


func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 168
	top.add_theme_stylebox_override("panel", _panel())
	root.add_child(top)
	var top_box := VBoxContainer.new()
	top.add_child(top_box)
	var back := Button.new()
	back.text = "В город"
	back.custom_minimum_size = Vector2(0, 48)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)
	top_box.add_child(back)
	_title = Label.new()
	_title.text = "Уралдар · Наследники Урала"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top_box.add_child(_title)
	_state = Label.new()
	_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top_box.add_child(_state)
	_clock = Label.new()
	top_box.add_child(_clock)
	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -430
	bottom.add_theme_stylebox_override("panel", _panel())
	root.add_child(bottom)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 410)
	bottom.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(grid)
	for clip in CLIPS:
		grid.add_child(_clip_button(clip))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	row.add_child(_action_button("Пауза", _toggle_pause))
	row.add_child(_action_button("Стойка", func() -> void:
		_aura = false
		_dead = false
		_paused = false
		_play_clip("Combat_Stance")
	))
	var repeat_box := CheckButton.new()
	repeat_box.text = "Повтор"
	repeat_box.toggled.connect(func(on: bool) -> void:
		_repeat = on
		_apply_loops()
		if on and _clip != "" and _clip != "Dead":
			var anim := _animation(_clip)
			if anim != null:
				anim.loop_mode = Animation.LOOP_LINEAR
	)
	column.add_child(repeat_box)
	var effects := CheckButton.new()
	effects.text = "Эффекты"
	effects.button_pressed = true
	effects.toggled.connect(func(on: bool) -> void:
		_effects = on
		if not on:
			_clear_fx()
	)
	column.add_child(effects)
	column.add_child(_action_button("Дух Урала: та же Sword_Shout, другая аура", func() -> void:
		_aura = true
		_dead = false
		_paused = false
		_play_clip("Sword_Shout")
	))
	var speed := HSlider.new()
	speed.min_value = 0.25
	speed.max_value = 2.0
	speed.step = 0.05
	speed.value = 1.0
	speed.custom_minimum_size = Vector2(0, 48)
	speed.value_changed.connect(func(value: float) -> void:
		_speed = value
		_apply_speed()
	)
	column.add_child(speed)
	var speed_label := Label.new()
	speed_label.text = "Скорость 1.00x"
	column.add_child(speed_label)
	speed.value_changed.connect(func(value: float) -> void:
		speed_label.text = "Скорость %.2fx" % value
	)


func _clip_button(clip: String) -> Button:
	var button := Button.new()
	button.text = clip
	button.custom_minimum_size = Vector2(0, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void:
		_aura = false
		_dead = false
		_paused = false
		_play_clip(clip)
	)
	return button


func _action_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	return button


func _panel() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.07, 0.1, 0.88)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


func _play_clip(clip: String) -> void:
	_clip = clip
	if _player == null:
		_set_status(clip, "Нет проигрывателя")
		return
	if not _player.has_animation(clip):
		_set_status(clip, "Клип не найден")
		_clock.text = "Длительность: нет"
		return
	var anim := _animation(clip)
	if anim != null:
		var loop := clip in LOOPED or (_repeat and clip != "Dead")
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var blend := 0.16
	if clip in ["Left_Slash", "Charged_Slash", "Thrust_Slash", "Skill_01"]:
		blend = 0.04
	_player.play(clip, blend)
	_apply_speed()
	_set_status(clip, "Смерть" if clip == "Dead" else "Играет")
	if anim != null:
		_clock.text = "Длительность %.2f с" % anim.length
	_show_effect(clip)


func _toggle_pause() -> void:
	_paused = not _paused
	_apply_speed()
	_set_status(_clip, "Пауза" if _paused else "Играет")


func _apply_speed() -> void:
	if _player == null:
		return
	_player.speed_scale = 0.0 if _paused else _speed


func _on_finished(anim_name: StringName) -> void:
	if str(anim_name) != _clip:
		return
	if _clip == "Dead":
		_dead = true
		_set_status(_clip, "Смерть, поза сохранена")
		return
	if _repeat or _clip in LOOPED:
		return
	_play_clip("Combat_Stance")


func _process(_delta: float) -> void:
	if _player == null or _clip == "":
		return
	var anim := _animation(_clip)
	if anim == null:
		return
	_clock.text = "Длительность %.2f с, сейчас %.2f" % [anim.length, _player.current_animation_position]
	_fade_fx(_delta)


func _set_status(clip: String, state: String) -> void:
	if _state != null:
		_state.text = "%s · %s" % [clip, state]


func _show_effect(clip: String) -> void:
	_clear_fx()
	if not _effects:
		return
	if clip == "Left_Slash":
		_add_box(Vector3(0.12, 0.08, 0.9), Vector3(0, 1.15, 0.7), Color(0.4, 0.9, 0.85, 0.85))
	elif clip == "Charged_Slash":
		for index in 6:
			var box := _add_box(Vector3(0.5, 0.05, 0.12), Vector3(0, 1.2, 0.9), Color(0.45, 0.85, 1.0, 0.7))
			box.rotation.y = deg_to_rad(-50 + index * 18)
	elif clip == "Skill_01":
		var ring := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.35
		cylinder.bottom_radius = 0.35
		cylinder.height = 0.06
		ring.mesh = cylinder
		ring.position = Vector3(0, 0.08, 1.1)
		ring.material_override = _glow(Color(0.2, 0.85, 0.8, 0.55))
		_fx.add_child(ring)
	elif clip == "Sword_Shout":
		var sphere := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 1.15 if not _aura else 1.35
		ball.height = ball.radius * 2.0
		sphere.mesh = ball
		sphere.position = Vector3(0, 1.0, 0)
		var color := Color(0.95, 0.78, 0.35, 0.28) if _aura else Color(0.35, 0.7, 0.95, 0.28)
		sphere.material_override = _glow(color)
		_fx.add_child(sphere)


func _add_box(size: Vector3, where: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = where
	mesh.material_override = _glow(color)
	_fx.add_child(mesh)
	return mesh


func _glow(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _clear_fx() -> void:
	if _fx == null:
		return
	for child in _fx.get_children():
		_fx.remove_child(child)
		child.free()


func _fade_fx(delta: float) -> void:
	for child in _fx.get_children():
		if not child is MeshInstance3D:
			continue
		var material := (child as MeshInstance3D).material_override as StandardMaterial3D
		if material == null:
			continue
		var color := material.albedo_color
		color.a = maxf(color.a - delta * 0.35, 0.0)
		material.albedo_color = color


func _animation(clip: String) -> Animation:
	if _player == null or not _player.has_animation(clip):
		return null
	return _player.get_animation(clip)


func _plant(node: Node) -> void:
	var skeleton := node.find_child("Skeleton3D", true, false) as Skeleton3D
	if _player == null or skeleton == null:
		return
	var hips := -1
	for index in skeleton.get_bone_count():
		if str(skeleton.get_bone_name(index)).contains("Hips"):
			hips = index
	if hips < 0:
		return
	var rest: Vector3 = skeleton.get_bone_rest(hips).origin
	for lib_name in _player.get_animation_library_list():
		var library := _player.get_animation_library(lib_name)
		for anim_name in library.get_animation_list():
			var anim := library.get_animation(anim_name)
			var copy := anim.duplicate()
			var changed := false
			for track in copy.get_track_count():
				var path := str(copy.track_get_path(track))
				if not path.contains("Hips") or copy.track_get_type(track) != Animation.TYPE_POSITION_3D:
					continue
				var keep_drop := str(anim_name) == "Dead"
				for key in copy.track_get_key_count(track):
					var value: Vector3 = copy.track_get_key_value(track, key)
					value.x = rest.x
					value.z = rest.z
					if not keep_drop:
						value.y = rest.y
					copy.track_set_key_value(track, key, value)
				changed = true
			if changed:
				library.remove_animation(anim_name)
				library.add_animation(anim_name, copy)


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null


func _warn(text: String) -> void:
	push_warning(text)
