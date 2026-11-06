extends Node3D

const MODEL_FILE := {
	"TEMP_A": "swordsman",
	"TEMP_B": "priest",
	"temp_a": "swordsman",
	"temp_b": "priest",
	"swordsman": "swordsman",
	"priest": "priest",
}

const CLIP_ALIAS := {
	"swordsman": {
		"idle": "Idle_9",
		"attack": "Thrust_Slash",
		"skill": "Jump_and_Slam_Back_Down",
		"death": "Dead",
	},
	"priest": {
		"idle": "Idle_11",
		"attack": "Attack",
		"skill": "Charged_Spell_Cast",
		"hit": "Hit_Reaction",
		"death": "Dead",
	},
}

const Sim = preload("res://scripts/battle_sim.gd")

var _units := {}
var _events: Array = []
var _cursor := 0
var _time := 0.0
var _result: Label
var _winner := "draw"
var _fought_stage := 1
var _left_hp := 0
var _right_hp := 0
var _stage_written := false


func _ready() -> void:
	var camera := $Camera3D
	camera.position = Vector3(0, 12, 16)
	camera.look_at(Vector3(0, 1, 0))
	_build_hud()
	_load_log()


func _process(delta: float) -> void:
	_time += delta
	while _cursor < _events.size() and float(_events[_cursor].get("t", 0.0)) <= _time:
		_apply(_events[_cursor])
		_cursor += 1
	if _cursor >= _events.size() and _events.size() > 0 and _result.visible == false:
		_result.visible = true
		_commit_stage()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var back := Button.new()
	back.text = "В город"
	back.custom_minimum_size = Vector2(180, 64)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)
	column.add_child(back)
	_result = Label.new()
	_result.visible = false
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.custom_minimum_size = Vector2(0, 80)
	column.add_child(_result)
	var apply := func() -> void:
		var screen := DisplayServer.screen_get_size()
		var safe := DisplayServer.get_display_safe_area()
		var view := get_viewport().get_visible_rect().size
		var top := 16
		var left := 16
		var right := 16
		if screen.x > 0 and screen.y > 0 and view.x > 0.0 and view.y > 0.0:
			var sx := view.x / float(screen.x)
			var sy := view.y / float(screen.y)
			left = int(safe.position.x * sx)
			top = int(safe.position.y * sy)
			right = int((screen.x - safe.position.x - safe.size.x) * sx)
		margin.add_theme_constant_override("margin_left", maxi(left, 16))
		margin.add_theme_constant_override("margin_top", maxi(top, 16))
		margin.add_theme_constant_override("margin_right", maxi(right, 16))
	apply.call()
	get_viewport().size_changed.connect(apply)


func _load_log() -> void:
	_fought_stage = maxi(1, Roster.stage)
	var parsed: Dictionary = Sim.fight(Roster.slots, _fought_stage, Roster.levels())
	for unit in parsed.get("units", []):
		_spawn(str(unit["id"]), str(unit.get("model", "TEMP")), int(unit.get("max_hp", unit.get("hp", 1))))
	_events = parsed.get("events", [])
	_winner = str(parsed.get("winner", "draw"))
	_left_hp = 0
	_right_hp = 0
	for unit in parsed.get("units", []):
		if str(unit["id"]).begins_with("L"):
			_left_hp += int(unit["hp"])
		else:
			_right_hp += int(unit["hp"])
	_result.text = "Стадия %d" % _fought_stage


func _commit_stage() -> void:
	if _stage_written:
		return
	_stage_written = true
	var title := "Ничья"
	var note := "Стадия %d не изменилась." % _fought_stage
	if _winner == "left":
		Roster.advance_stage()
		title = "Победа"
		note = "Стадия %d пройдена. Дальше %d." % [_fought_stage, Roster.stage]
	elif _winner == "right":
		title = "Поражение"
	_result.text = "%s\n%s\nСлева %d HP, справа %d HP. Золото не выдано." % [title, note, _left_hp, _right_hp]


func _home(id: String) -> Vector3:
	var side := id.substr(0, 1)
	var slot := int(id.substr(1))
	var x := 0.0
	var z := 0.0
	match slot:
		0:
			x = -1.6
			z = 1.2
		1:
			x = 1.6
			z = 1.2
		2:
			x = -2.4
			z = 3.2
		3:
			x = 0.0
			z = 3.2
		4:
			x = 2.4
			z = 3.2
	if side == "L":
		z = -z
	return Vector3(x, 0, z)


func _spawn(id: String, model: String, max_hp: int) -> void:
	var root := Node3D.new()
	root.position = _home(id)
	root.set_meta("model_id", _file_id(model))
	root.set_meta("hp", max_hp)
	root.set_meta("max_hp", max_hp)
	var used_glb := _attach_glb(root, model)
	root.set_meta("has_glb", used_glb)
	if used_glb:
		var visual := root.get_child(0) as Node3D
		var file_id := _file_id(model)
		var model_height := 1.7 if file_id == "swordsman" else 1.1
		var fitted := 3.4 / model_height
		visual.scale = Vector3(fitted, fitted, fitted)
		if id.begins_with("R"):
			visual.rotation.y = PI
		_plant_feet(visual)
	else:
		var mesh := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.32
		capsule.height = 1.5
		mesh.mesh = capsule
		mesh.position.y = 0.75
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("e25b45") if model.contains("A") else Color("3d7ea6")
		mesh.set_surface_override_material(0, material)
		root.add_child(mesh)
	var label := Label3D.new()
	label.name = "Hp"
	label.text = "%s\n%d/%d" % [_file_id(model), max_hp, max_hp]
	if not used_glb:
		label.text = "TEMP %s\n%d/%d" % [model, max_hp, max_hp]
	label.position = Vector3(0, 3.8, 0)
	label.font_size = 42
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)
	add_child(root)
	_units[id] = root
	_play(root, "idle")


func _file_id(model: String) -> String:
	return str(MODEL_FILE.get(model, model))


func _attach_glb(root: Node3D, model: String) -> bool:
	var path := "res://assets/heroes/%s.glb" % _file_id(model)
	if not ResourceLoader.exists(path):
		return false
	var packed = load(path)
	if packed == null:
		return false
	var node = packed.instantiate()
	root.add_child(node)
	return true


func _apply(event: Dictionary) -> void:
	var kind := str(event.get("type", ""))
	if kind == "move":
		var unit = _units.get(str(event.get("unit", "")))
		if unit == null:
			return
		var to: Array = event.get("to", [0, 0, 0])
		unit.position = Vector3(float(to[0]), float(to[1]), float(to[2]))
	elif kind == "attack" or kind == "heal":
		var src = _units.get(str(event.get("src", "")))
		if src != null:
			_play(src, "attack" if kind == "attack" else "skill")
		var dst = _units.get(str(event.get("dst", "")))
		if dst != null and event.has("hp"):
			dst.set_meta("hp", int(event["hp"]))
			_refresh_hp(dst)
			if kind == "attack":
				_play(dst, "hit")
	elif kind == "down":
		var unit = _units.get(str(event.get("unit", "")))
		if unit != null:
			if not bool(unit.get_meta("has_glb")):
				unit.rotation.z = 1.4
			_play(unit, "death")


func _refresh_hp(unit: Node3D) -> void:
	var label := unit.get_node_or_null("Hp")
	if label == null:
		return
	var hp := int(unit.get_meta("hp"))
	var max_hp := int(unit.get_meta("max_hp"))
	var lines := str(label.text).split("\n")
	label.text = lines[0] + "\n%d/%d" % [hp, max_hp]


func _play(root: Node, clip: String) -> void:
	var player: AnimationPlayer = _find_player(root)
	if player == null:
		return
	var model := str(root.get_meta("model_id", ""))
	var table: Dictionary = CLIP_ALIAS.get(model, {})
	var actual := str(table.get(clip, ""))
	if actual == "":
		actual = str(table.get("idle", clip))
	if player.has_animation(actual):
		player.play(actual)
	elif player.has_animation("idle"):
		player.play("idle")


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = _find_player(child)
		if found != null:
			return found
	return null


func _plant_feet(node: Node) -> void:
	var player := _find_player(node)
	var skeleton := node.find_child("Skeleton3D", true, false) as Skeleton3D
	if player == null or skeleton == null:
		return
	var hips := -1
	for index in skeleton.get_bone_count():
		if str(skeleton.get_bone_name(index)).contains("Hips"):
			hips = index
	if hips < 0:
		return
	var rest: Vector3 = skeleton.get_bone_rest(hips).origin
	for lib_name in player.get_animation_library_list():
		var library := player.get_animation_library(lib_name)
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
