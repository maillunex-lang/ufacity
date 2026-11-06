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
		"move": "Walking",
		"attack": "Thrust_Slash",
		"skill": "Jump_and_Slam_Back_Down",
		"death": "Dead",
	},
	"priest": {
		"idle": "Idle_11",
		"move": "Walking",
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
var _goals := {}
var _rate := 1
var _speed_note: Label
var _paused := false
var _pause_button: Button
var _cards: Array = []


func _ready() -> void:
	_make_arena()
	_frame_camera()
	get_viewport().size_changed.connect(_frame_camera)
	_build_hud()
	_load_log()


func _make_arena() -> void:
	var old := get_node_or_null("Floor")
	if old != null:
		old.free()
	var disc := MeshInstance3D.new()
	var circle := CylinderMesh.new()
	circle.top_radius = 10.5
	circle.bottom_radius = 10.5
	circle.height = 0.28
	circle.radial_segments = 64
	disc.mesh = circle
	disc.position = Vector3(0, -0.14, 0)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("6e675c")
	disc.material_override = stone
	add_child(disc)
	var ground := CSGBox3D.new()
	ground.size = Vector3(60, 0.2, 60)
	ground.position = Vector3(0, -0.42, 0)
	var field := StandardMaterial3D.new()
	field.albedo_color = Color("343a34")
	ground.material = field
	add_child(ground)


func _frame_camera() -> void:
	var camera := $Camera3D
	var view := get_viewport().get_visible_rect().size
	var aspect := 0.56
	if view.y > 1.0:
		aspect = clampf(view.x / view.y, 0.4, 2.2)
	var half_h := deg_to_rad(31.0)
	var half_v := atan(tan(half_h) / aspect)
	camera.fov = rad_to_deg(half_v * 2.0)
	camera.position = Vector3(-22, 12.5, 0)
	camera.look_at(Vector3(0, 0.4, 0))


func _process(delta: float) -> void:
	if _paused:
		return
	var scaled := delta * float(_rate)
	_time += scaled
	while _cursor < _events.size() and float(_events[_cursor].get("t", 0.0)) <= _time:
		_apply(_events[_cursor])
		_cursor += 1
	if _cursor >= _events.size() and _events.size() > 0 and _result.visible == false:
		_result.visible = true
		_commit_stage()
	_slide(scaled)


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
	var speeds := HBoxContainer.new()
	speeds.add_theme_constant_override("separation", 8)
	column.add_child(speeds)
	for rate in [1, 2, 4]:
		var button := Button.new()
		button.text = "x%d" % rate
		button.custom_minimum_size = Vector2(72, 56)
		var chosen := int(rate)
		button.pressed.connect(func() -> void: _try_rate(chosen))
		speeds.add_child(button)
	var sim := Button.new()
	sim.text = "Симуляция"
	sim.custom_minimum_size = Vector2(150, 56)
	sim.pressed.connect(_try_sim)
	speeds.add_child(sim)
	_pause_button = Button.new()
	_pause_button.text = "Пауза"
	_pause_button.custom_minimum_size = Vector2(120, 56)
	_pause_button.pressed.connect(_toggle_pause)
	speeds.add_child(_pause_button)
	_speed_note = Label.new()
	_speed_note.text = "Скорость x1"
	_speed_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_speed_note)
	_result = Label.new()
	_result.visible = false
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.custom_minimum_size = Vector2(0, 80)
	column.add_child(_result)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 6)
	column.add_child(cards)
	for _slot in 5:
		cards.add_child(_make_card())
	var apply := func() -> void:
		var screen := DisplayServer.screen_get_size()
		var safe := DisplayServer.get_display_safe_area()
		var view := get_viewport().get_visible_rect().size
		var top := 16
		var left := 16
		var right := 16
		var bottom := 16
		if screen.x > 0 and screen.y > 0 and view.x > 0.0 and view.y > 0.0:
			var sx := view.x / float(screen.x)
			var sy := view.y / float(screen.y)
			left = int(safe.position.x * sx)
			top = int(safe.position.y * sy)
			right = int((screen.x - safe.position.x - safe.size.x) * sx)
			bottom = int((screen.y - safe.position.y - safe.size.y) * sy)
		margin.add_theme_constant_override("margin_left", maxi(left, 16))
		margin.add_theme_constant_override("margin_top", maxi(top, 16))
		margin.add_theme_constant_override("margin_right", maxi(right, 16))
		margin.add_theme_constant_override("margin_bottom", maxi(bottom, 12))
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
			x = -3.2
			z = 3.0
		1:
			x = 3.2
			z = 3.0
		2:
			x = -4.6
			z = 6.4
		3:
			x = 0.0
			z = 6.8
		4:
			x = 4.6
			z = 6.4
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
	root.set_meta("side", id.substr(0, 1))
	_add_bar(root, id.begins_with("L"))
	add_child(root)
	_units[id] = root
	_goals[id] = root.position
	_hook_anim(root)
	_set_pose(root, "idle")
	var player := _find_player(root)
	if player != null:
		player.speed_scale = float(_rate)
	if id.begins_with("L"):
		_fill_card(int(id.substr(1)), max_hp)


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
		_goals[str(event.get("unit", ""))] = Vector3(float(to[0]), float(to[1]), float(to[2]))
		if not bool(unit.get_meta("down", false)) and str(unit.get_meta("pose", "")) != "attack" and str(unit.get_meta("pose", "")) != "skill":
			_set_pose(unit, "move")
	elif kind == "attack" or kind == "heal":
		var src = _units.get(str(event.get("src", "")))
		if src != null:
			_set_pose(src, "attack" if kind == "attack" else "skill")
		var dst = _units.get(str(event.get("dst", "")))
		if dst != null and event.has("hp"):
			dst.set_meta("hp", int(event["hp"]))
			_refresh_hp(dst)
			if kind == "attack":
				_set_pose(dst, "hit")
	elif kind == "down":
		var unit = _units.get(str(event.get("unit", "")))
		if unit != null:
			unit.set_meta("down", true)
			if not bool(unit.get_meta("has_glb")):
				unit.rotation.z = 1.4
			_set_pose(unit, "death")


func _refresh_hp(unit: Node3D) -> void:
	var hp := int(unit.get_meta("hp"))
	var max_hp := maxi(1, int(unit.get_meta("max_hp")))
	var fill := unit.get_node_or_null("Hp/Fill") as MeshInstance3D
	if fill != null:
		var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
		fill.scale.x = maxf(ratio, 0.001)
		fill.position.x = (ratio - 1.0) * 0.71
	var slot := int(unit.get_meta("card", -1))
	if slot >= 0 and slot < _cards.size():
		var bar: ProgressBar = _cards[slot]["bar"]
		bar.max_value = max_hp
		bar.value = hp


func _try_rate(rate: int) -> void:
	if not Roster.allows_rate(rate):
		var need := 1 if rate == 2 else 4
		_speed_note.text = "x%d открывается с VIP %d. Сейчас VIP %d, остаётся x%d." % [rate, need, Roster.vip, _rate]
		return
	_rate = rate
	_apply_rate()
	_speed_note.text = "Скорость x%d" % _rate


func _try_sim() -> void:
	if not Roster.allows_sim():
		_speed_note.text = "Симуляция открывается с VIP 7. Сейчас VIP %d." % Roster.vip
		return
	_time = 100000.0
	_speed_note.text = "Бой просчитан сразу."


func _apply_rate() -> void:
	for unit_id in _units.keys():
		var player := _find_player(_units[unit_id])
		if player != null:
			player.speed_scale = float(_rate)


func _toggle_pause() -> void:
	_paused = not _paused
	_pause_button.text = "Дальше" if _paused else "Пауза"
	for unit_id in _units.keys():
		var player := _find_player(_units[unit_id])
		if player == null:
			continue
		player.speed_scale = 0.0 if _paused else float(_rate)


func _make_card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "—"
	title.clip_text = true
	box.add_child(title)
	var level := Label.new()
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level.text = "Ур. 1"
	box.add_child(level)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 1
	bar.value = 1
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	box.add_child(bar)
	_cards.append({"title": title, "level": level, "bar": bar})
	return panel


func _fill_card(slot: int, max_hp: int) -> void:
	if slot < 0 or slot >= _cards.size() or slot >= Roster.slots.size():
		return
	var row: Dictionary = Roster.combat(str(Roster.slots[slot]))
	var card: Dictionary = _cards[slot]
	card["title"].text = str(row["name"])
	card["level"].text = "Ур. %d" % int(row["level"])
	var bar: ProgressBar = card["bar"]
	bar.max_value = max_hp
	bar.value = max_hp
	var unit = _units.get("L%d" % slot)
	if unit != null:
		unit.set_meta("card", slot)


func _add_bar(root: Node3D, friendly: bool) -> void:
	var bar := Node3D.new()
	bar.name = "Hp"
	bar.position = Vector3(0, 3.5, 0)
	bar.add_child(_quad(Vector2(1.5, 0.16), Color("1a1e18")))
	var fill := _quad(Vector2(1.42, 0.1), Color("3f9d55") if friendly else Color("c4523a"))
	fill.name = "Fill"
	fill.position = Vector3(0, 0, 0.02)
	bar.add_child(fill)
	root.add_child(bar)


func _quad(size: Vector2, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	node.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	node.material_override = material
	return node


func _face(unit: Node3D, flat: Vector3) -> void:
	if unit.get_child_count() == 0:
		return
	var visual := unit.get_child(0) as Node3D
	if visual == null or visual.name == "Hp":
		return
	visual.rotation.y = atan2(flat.x, flat.z)


func _slide(delta: float) -> void:
	for unit_id in _units.keys():
		var unit: Node3D = _units[unit_id]
		if not _goals.has(unit_id):
			continue
		var goal: Vector3 = _goals[unit_id]
		unit.position = unit.position.move_toward(goal, delta * 1.6)
		var flat := goal - unit.position
		flat.y = 0.0
		var walking := flat.length() > 0.04
		if walking:
			_face(unit, flat)
		var pose := str(unit.get_meta("pose", ""))
		if bool(unit.get_meta("down", false)):
			continue
		if not walking and pose == "move":
			_set_pose(unit, "idle")


func _set_pose(unit: Node, pose: String) -> void:
	if bool(unit.get_meta("down", false)) and pose != "death":
		return
	if str(unit.get_meta("pose", "")) == pose and pose != "attack" and pose != "skill" and pose != "hit":
		return
	unit.set_meta("pose", pose)
	_play(unit, pose)


func _hook_anim(unit: Node) -> void:
	var player := _find_player(unit)
	if player == null or player.animation_finished.is_connected(_on_anim_finished):
		return
	player.animation_finished.connect(_on_anim_finished.bind(unit))


func _on_anim_finished(anim_name: StringName, unit: Node) -> void:
	if bool(unit.get_meta("down", false)):
		return
	var pose := str(unit.get_meta("pose", ""))
	if pose == "attack" or pose == "skill" or pose == "hit":
		_set_pose(unit, "idle")


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
		var anim := player.get_animation(actual)
		if anim != null and (clip == "idle" or clip == "move"):
			anim.loop_mode = Animation.LOOP_LINEAR
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
