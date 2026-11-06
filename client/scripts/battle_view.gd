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
var _shots: Array = []
var _numbers: Array = []
var _quiet := false
var _end_wait := -1.0
var _result_panel: PanelContainer
var _result_title: Label
var _result_body: Label


func _ready() -> void:
	_make_arena()
	_lay_marks()
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
	circle.top_radius = 12.2
	circle.bottom_radius = 12.2
	circle.height = 0.28
	circle.radial_segments = 64
	disc.mesh = circle
	disc.position = Vector3(0, -0.14, 0)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("6e675c")
	disc.material_override = stone
	add_child(disc)
	var rim := MeshInstance3D.new()
	var edge := CylinderMesh.new()
	edge.top_radius = 13.15
	edge.bottom_radius = 13.15
	edge.height = 0.08
	edge.radial_segments = 64
	rim.mesh = edge
	rim.position = Vector3(0, -0.05, 0)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("1a1e1c")
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim.material_override = dark
	add_child(rim)
	var ground := CSGBox3D.new()
	ground.size = Vector3(80, 0.2, 80)
	ground.position = Vector3(0, -0.5, 0)
	var field := StandardMaterial3D.new()
	field.albedo_color = Color("171c19")
	ground.material = field
	add_child(ground)
	var wall := MeshInstance3D.new()
	var curtain := CylinderMesh.new()
	curtain.top_radius = 26.0
	curtain.bottom_radius = 26.0
	curtain.height = 10.0
	curtain.radial_segments = 48
	curtain.flip_faces = true
	wall.mesh = curtain
	wall.position = Vector3(0, 3.2, 0)
	var dusk := StandardMaterial3D.new()
	dusk.albedo_color = Color("242a28")
	dusk.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wall.material_override = dusk
	add_child(wall)


func _frame_camera() -> void:
	var camera := $Camera3D
	var view := get_viewport().get_visible_rect().size
	var aspect := 0.56
	if view.y > 1.0:
		aspect = clampf(view.x / view.y, 0.4, 2.2)
	var half_h := deg_to_rad(36.0)
	var half_v := atan(tan(half_h) / aspect)
	camera.fov = rad_to_deg(half_v * 2.0)
	camera.position = Vector3(-18, 24, 0)
	camera.look_at(Vector3(0, 0, 0))


func _process(delta: float) -> void:
	if _paused:
		return
	var scaled := delta * float(_rate)
	_quiet = scaled > 0.4 or _end_wait >= 0.0
	if _end_wait < 0.0:
		_time += scaled
		while _cursor < _events.size() and float(_events[_cursor].get("t", 0.0)) <= _time:
			_apply(_events[_cursor])
			_cursor += 1
		if _cursor >= _events.size() and _events.size() > 0 and _result_panel.visible == false and not _stage_written:
			_end_wait = 0.5
	else:
		_end_wait -= delta
		if _end_wait <= 0.0:
			_clear_fx()
			_commit_stage()
	_slide(scaled)
	_fx(delta)


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
	_build_result(margin)
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
	if Roster.replay_stage > 0:
		_fought_stage = Roster.replay_stage
		Roster.replay_stage = 0
	else:
		_fought_stage = maxi(1, Roster.stage)
	var parsed: Dictionary = Sim.fight(Roster.slots, _fought_stage, Roster.levels())
	for unit in parsed.get("units", []):
		_spawn(str(unit["id"]), str(unit.get("model", "TEMP")), int(unit.get("max_hp", unit.get("hp", 1))), str(unit.get("role", "")))
	_events = parsed.get("events", [])
	_winner = str(parsed.get("winner", "draw"))
	_left_hp = 0
	_right_hp = 0
	for unit in parsed.get("units", []):
		if str(unit["id"]).begins_with("L"):
			_left_hp += int(unit["hp"])
		else:
			_right_hp += int(unit["hp"])
	_lay_roles()


func _commit_stage() -> void:
	if _stage_written:
		return
	_stage_written = true
	var title := "Ничья"
	var note := "Стадия %d не изменилась." % _fought_stage
	if _winner == "left" and _fought_stage == Roster.stage:
		Roster.advance_stage()
		title = "Победа"
		note = "Стадия %d пройдена. Дальше %d." % [_fought_stage, Roster.stage]
	elif _winner == "left":
		title = "Победа"
		note = "Повтор стадии %d. Кампания остаётся на %d." % [_fought_stage, Roster.stage]
	elif _winner == "right":
		title = "Поражение"
	_result_title.text = title
	_result_body.text = "%s\nСлева %d HP, справа %d HP.\nЗолото не выдано." % [note, _left_hp, _right_hp]
	_result_panel.visible = true


func _home(id: String) -> Vector3:
	var side := id.substr(0, 1)
	var slot := int(id.substr(1))
	var spot := Sim.slot_vector(slot)
	var z := spot.y
	if side == "L":
		z = -z
	return Vector3(spot.x, 0.0, z)


func _build_result(margin: MarginContainer) -> void:
	var overlay := CenterContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(overlay)
	_result_panel = PanelContainer.new()
	_result_panel.visible = false
	_result_panel.custom_minimum_size = Vector2(420, 220)
	overlay.add_child(_result_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_result_panel.add_child(box)
	_result_title = Label.new()
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.add_theme_font_size_override("font_size", 32)
	box.add_child(_result_title)
	_result_body = Label.new()
	_result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var back := Button.new()
	back.text = "В город"
	back.custom_minimum_size = Vector2(160, 56)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)
	row.add_child(back)
	var again := Button.new()
	again.text = "Ещё раз"
	again.custom_minimum_size = Vector2(160, 56)
	again.pressed.connect(func() -> void:
		Roster.replay_stage = _fought_stage
		get_tree().change_scene_to_file("res://scenes/battle.tscn")
	)
	row.add_child(again)


func _lay_marks() -> void:
	for slot in 5:
		_mark("L%d" % slot, slot < 2)
		_mark("R%d" % slot, slot < 2)


func _mark(id: String, front: bool) -> void:
	var disc := MeshInstance3D.new()
	disc.name = "Mark" + id
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.72 if front else 0.55
	mesh.bottom_radius = mesh.top_radius
	mesh.height = 0.05
	mesh.radial_segments = 24
	disc.mesh = mesh
	disc.position = _home(id) + Vector3(0, 0.04, 0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if id.begins_with("L"):
		material.albedo_color = Color("2f6b45") if front else Color("1d4034")
	else:
		material.albedo_color = Color("8a4036") if front else Color("5a302c")
	disc.material_override = material
	add_child(disc)


func _lay_roles() -> void:
	for unit_id in _units.keys():
		var unit: Node3D = _units[unit_id]
		var role := str(unit.get_meta("role", ""))
		var kind := "sword"
		if role == "ranger" or role == "mage":
			kind = "bow"
		elif role == "healer":
			kind = "cross"
		_glyph(unit.position, kind, str(unit_id))


func _glyph(at: Vector3, kind: String, unit_id: String) -> void:
	var root := Node3D.new()
	root.name = "Role" + unit_id
	root.position = at + Vector3(0, 0.1, 0)
	if kind == "sword":
		root.add_child(_sliver(Vector3(0.08, 0.04, 0.52), Vector3(0, 0, 0.06)))
		root.add_child(_sliver(Vector3(0.3, 0.04, 0.08), Vector3(0, 0, -0.16)))
	elif kind == "bow":
		var left := _sliver(Vector3(0.06, 0.04, 0.46), Vector3(-0.1, 0, 0))
		var right := _sliver(Vector3(0.06, 0.04, 0.46), Vector3(0.1, 0, 0))
		left.rotation.y = 0.45
		right.rotation.y = -0.45
		root.add_child(left)
		root.add_child(right)
		root.add_child(_sliver(Vector3(0.025, 0.04, 0.34), Vector3(0, 0, 0)))
	else:
		root.add_child(_sliver(Vector3(0.08, 0.04, 0.4), Vector3.ZERO))
		root.add_child(_sliver(Vector3(0.4, 0.04, 0.08), Vector3.ZERO))
	add_child(root)


func _sliver(size: Vector3, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.position = at
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("f4efe4")
	node.material_override = material
	return node


func _flash(unit: Node3D) -> void:
	unit.set_meta("flash", 0.16)


func _tint_enemy(node: Node) -> void:
	if node is MeshInstance3D:
		var tint := StandardMaterial3D.new()
		tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tint.albedo_color = Color(0.9, 0.22, 0.16, 0.32)
		(node as MeshInstance3D).material_overlay = tint
	for child in node.get_children():
		_tint_enemy(child)


func _add_flash(root: Node3D) -> void:
	var flash := _quad(Vector2(1.3, 2.0), Color(1, 1, 1, 0))
	flash.name = "Flash"
	flash.position = Vector3(0, 1.6, 0)
	flash.visible = false
	root.add_child(flash)


func _bolt(src: Node3D, dst: Node3D, kind: String) -> void:
	var role := str(src.get_meta("role", ""))
	if kind == "attack" and (role == "tank" or role == "warrior"):
		return
	var bolt := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.16, 0.16, 0.7)
	bolt.mesh = box
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("d6f07a") if kind == "heal" else Color("8fd0ff")
	bolt.material_override = material
	add_child(bolt)
	_shots.append({
		"node": bolt,
		"from": src.position + Vector3(0, 1.5, 0),
		"to": dst.position + Vector3(0, 1.5, 0),
		"age": 0.0,
	})


func _float_number(unit: Node3D, amount: int, kind: String) -> void:
	if amount == 0:
		return
	var label := Label3D.new()
	label.text = "+%d" % amount if kind == "heal" else "-%d" % amount
	label.font_size = 64
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("d6f07a") if kind == "heal" else Color("ffd0c4")
	label.outline_size = 10
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.position = unit.position + Vector3(0, 2.5, 0)
	add_child(label)
	_numbers.append({"node": label, "age": 0.0, "base": label.position})


func _clear_fx() -> void:
	for shot in _shots:
		var bolt: Node = shot["node"]
		if is_instance_valid(bolt):
			bolt.queue_free()
	_shots.clear()
	for number in _numbers:
		var label: Node = number["node"]
		if is_instance_valid(label):
			label.queue_free()
	_numbers.clear()
	for unit_id in _units.keys():
		var unit: Node3D = _units[unit_id]
		unit.set_meta("flash", 0.0)
		var flash := unit.get_node_or_null("Flash") as MeshInstance3D
		if flash != null:
			flash.visible = false


func _fx(delta: float) -> void:
	var kept: Array = []
	for shot in _shots:
		shot["age"] = float(shot["age"]) + delta
		var amount := clampf(float(shot["age"]) / 0.16, 0.0, 1.0)
		var bolt: MeshInstance3D = shot["node"]
		var origin: Vector3 = shot["from"]
		var target: Vector3 = shot["to"]
		bolt.position = origin.lerp(target, amount)
		if amount < 0.95 and origin.distance_to(target) > 0.2:
			bolt.look_at(target, Vector3.UP)
		if amount >= 1.0:
			bolt.queue_free()
		else:
			kept.append(shot)
	_shots = kept
	for unit_id in _units.keys():
		var unit: Node3D = _units[unit_id]
		var left := float(unit.get_meta("flash", 0.0))
		var flash := unit.get_node_or_null("Flash") as MeshInstance3D
		if flash == null:
			continue
		if left <= 0.0:
			flash.visible = false
			continue
		left = maxf(0.0, left - delta)
		unit.set_meta("flash", left)
		flash.visible = left > 0.0
		var material := flash.material_override as StandardMaterial3D
		if material != null:
			material.albedo_color = Color(1, 0.9, 0.75, left / 0.16)
	var kept_numbers: Array = []
	for number in _numbers:
		number["age"] = float(number["age"]) + delta
		var age := float(number["age"])
		var label: Label3D = number["node"]
		var base: Vector3 = number["base"]
		label.position = base + Vector3(0, age * 1.1, 0)
		label.modulate.a = clampf(1.0 - age / 0.85, 0.0, 1.0)
		if age >= 0.85:
			label.queue_free()
		else:
			kept_numbers.append(number)
	_numbers = kept_numbers


func _spawn(id: String, model: String, max_hp: int, role: String) -> void:
	var root := Node3D.new()
	root.position = _home(id)
	root.set_meta("model_id", _file_id(model))
	root.set_meta("role", role)
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
			_tint_enemy(visual)
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
	_add_flash(root)
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
		unit.set_meta("walk_until", _time + 0.28)
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
			if not _quiet and src != null:
				_bolt(src, dst, kind)
				_flash(dst)
				_float_number(dst, int(event.get("amount", 0)), kind)
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
			player.speed_scale = _pose_scale(_units[unit_id])


func _pose_scale(unit: Node) -> float:
	var slow := 0.75 if str(unit.get_meta("pose", "")) == "move" else 1.0
	return slow * float(_rate)


func _toggle_pause() -> void:
	_paused = not _paused
	_pause_button.text = "Дальше" if _paused else "Пауза"
	for unit_id in _units.keys():
		var player := _find_player(_units[unit_id])
		if player == null:
			continue
		player.speed_scale = 0.0 if _paused else _pose_scale(_units[unit_id])


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


func _face(unit: Node3D, flat: Vector3, delta: float) -> void:
	if unit.get_child_count() == 0:
		return
	var visual := unit.get_child(0) as Node3D
	if visual == null or visual.name == "Hp":
		return
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(flat.x, flat.z), minf(1.0, delta * 6.0))


func _slide(delta: float) -> void:
	for unit_id in _units.keys():
		var unit: Node3D = _units[unit_id]
		if not _goals.has(unit_id):
			continue
		var goal: Vector3 = _goals[unit_id]
		unit.position = unit.position.move_toward(goal, delta * 1.4)
		var flat := goal - unit.position
		flat.y = 0.0
		var stepping := flat.length() > 0.05
		var walking := stepping or float(unit.get_meta("walk_until", 0.0)) > _time
		if stepping:
			_face(unit, flat, delta)
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
		player.speed_scale = 0.75 * float(_rate) if clip == "move" else float(_rate)
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
