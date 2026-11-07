extends Node3D
## Тестовая сцена боя 5 на 5: камера комментатора и скорости анимаций.
## Бой берётся готовым из battle_sim.gd (Sim.fight), здесь только показ.
## Основная сцена battle.tscn и её скрипт не затронуты.

const View = preload("res://scripts/battle_view.gd")
const Sim = preload("res://scripts/battle_sim.gd")

@export_group("Бой")
@export var squad: Array[String] = ["temp_a", "uraldar", "temp_b", "temp_a", "temp_b"]
@export_range(1, 20) var stage := 3
@export_range(0.25, 4.0, 0.05) var playback_rate := 1.0
@export var loop_battle := true
@export var show_hud_zones := true

@export_group("Камера")
## Наклон сверху в градусах. 0 — строго сбоку.
@export_range(0.0, 60.0, 0.5) var angle := 18.0:
	set(value):
		angle = value
		_apply_camera()
## Поворот вокруг арены. 0 — строго сбоку вдоль оси x, но тогда герои одной линии
## закрывают друг друга. 25 разводит всех десятерых. Игроки всегда слева.
@export_range(-60.0, 60.0, 0.5) var yaw := 25.0:
	set(value):
		yaw = value
		_apply_camera()
## Расстояние от точки взгляда до камеры.
@export_range(5.0, 60.0, 0.5) var distance := 19.0:
	set(value):
		distance = value
		_apply_camera()
## Высота точки взгляда над полом.
@export_range(-5.0, 10.0, 0.1) var height := 1.0:
	set(value):
		height = value
		_apply_camera()
## Сдвиг точки взгляда. Y поднимает или опускает бой на экране.
@export var offset := Vector3.ZERO:
	set(value):
		offset = value
		_apply_camera()
## Ширина кадра в метрах (Camera3D.size при keep_aspect = width).
@export_range(4.0, 60.0, 0.5) var orthographic_size := 21.0:
	set(value):
		orthographic_size = value
		_apply_camera()

@export_group("Анимации")
@export var anim: CombatAnimConfig

var _camera: Camera3D
var _units := {}
var _timeline: Array = []
var _cursor := 0
var _time := 0.0
var _end_time := 0.0
var _winner := "draw"
var _planted := {}
var _numbers: Array = []
var _info: Label
var _shot_path := ""
var _shot_at := 0.0
var _shot_taken := false
var _finish_wait := 0.0
var _log_lines: Array = []
var _pairs: Array = []
var _expected: Dictionary = {}
var _check := false
var _measured: Array = []


func _ready() -> void:
	if anim == null:
		anim = CombatAnimConfig.new()
	_camera = $Camera3D
	_parse_args()
	_build_stage()
	_load_battle()
	_apply_camera()
	get_viewport().size_changed.connect(_apply_camera)
	_build_hud()
	if _check:
		_self_check()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.substr(7)
		elif arg.begins_with("--at="):
			_shot_at = float(arg.substr(5))
		elif arg.begins_with("--stage="):
			stage = int(arg.substr(8))
		elif arg.begins_with("--yaw="):
			yaw = float(arg.substr(6))
		elif arg.begins_with("--size="):
			orthographic_size = float(arg.substr(7))
		elif arg == "--check":
			_check = true
		elif arg == "--noloop":
			loop_battle = false
		elif arg == "--nohud":
			show_hud_zones = false


# ---------------------------------------------------------------- камера

func _apply_camera() -> void:
	if _camera == null:
		return
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.size = orthographic_size
	_camera.near = 0.1
	_camera.far = 120.0
	var target := Vector3(0.0, height, 0.0) + offset
	var pitch := deg_to_rad(angle)
	var turn := deg_to_rad(yaw)
	# Камера на -x: ось z идёт вправо по экрану, значит левая команда (z < 0) слева.
	var back := Vector3(-cos(pitch) * cos(turn), sin(pitch), -cos(pitch) * sin(turn))
	_camera.position = target + back * distance
	_camera.look_at(target, Vector3.UP)


# ---------------------------------------------------------------- сцена

func _build_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1b2326")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a9b6bd")
	env.ambient_light_energy = 0.8
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.2
	add_child(sun)
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
	for slot in 5:
		_mark("L%d" % slot, slot < 2)
		_mark("R%d" % slot, slot < 2)


func _mark(id: String, front: bool) -> void:
	var disc := MeshInstance3D.new()
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


func _home(id: String) -> Vector3:
	var spot := Sim.slot_vector(int(id.substr(1)))
	var z := spot.y
	if id.begins_with("L"):
		z = -z
	return Vector3(spot.x, 0.0, z)


# ---------------------------------------------------------------- бой

func _load_battle() -> void:
	var slots: Array = []
	for hero in squad:
		slots.append(hero)
	var parsed: Dictionary = Sim.fight(slots, stage, {})
	_winner = str(parsed.get("winner", "draw"))
	for unit in parsed.get("units", []):
		_expected[str(unit["id"])] = int(unit["hp"])
	for unit in parsed.get("units", []):
		_spawn(str(unit["id"]), str(unit.get("model", "priest")), int(unit.get("max_hp", 1)))
	_build_timeline(parsed.get("events", []))


func _spawn(id: String, model: String, max_hp: int) -> void:
	var file_id := str(View.MODEL_FILE.get(model, model))
	var root := Node3D.new()
	root.name = id
	root.position = _home(id)
	add_child(root)
	var path := "res://assets/heroes/%s.glb" % file_id
	var packed := load(path) as PackedScene
	var visual: Node3D = null
	if packed != null:
		visual = packed.instantiate() as Node3D
		root.add_child(visual)
		var model_height := 1.7 if (file_id == "swordsman" or file_id == "uraldar") else 1.1
		var fitted := 3.4 / model_height
		visual.scale = Vector3(fitted, fitted, fitted)
		if id.begins_with("R"):
			visual.rotation.y = PI
			_tint_enemy(visual)
		_plant_feet(visual, file_id)
	var player := _find_player(root)
	var unit := {
		"id": id,
		"root": root,
		"visual": visual,
		"player": player,
		"model": file_id,
		"pose": "",
		"down": false,
		"goal": root.position,
		"hp": max_hp,
		"max_hp": max_hp,
		"flash": 0.0,
		"swings": 0,
		"bar": null,
	}
	_add_bar(root, id.begins_with("L"), unit)
	_units[id] = unit
	if player != null:
		player.animation_finished.connect(_on_anim_finished.bind(id))
	_set_pose(unit, "idle")


func _build_timeline(events: Array) -> void:
	var seq := 0
	var entries: Array = []
	for event in events:
		var kind := str(event.get("type", ""))
		var t := float(event.get("t", 0.0))
		if kind == "move" or kind == "down":
			entries.append({"t": t, "seq": seq, "do": kind, "event": event})
			seq += 1
		elif kind == "attack" or kind == "heal" or kind == "skill":
			var src: Dictionary = _units.get(str(event.get("src", "")), {})
			if src.is_empty():
				continue
			var swing := _pick_swing(src, event)
			var lead := anim.lead_for(swing["clip"], swing["kind"])
			entries.append({"t": t - lead, "seq": seq, "do": "swing", "event": event, "swing": swing})
			seq += 1
			entries.append({"t": t, "seq": seq, "do": "impact", "event": event, "swing": swing})
			seq += 1
			_pairs.append({"swing_t": t - lead, "impact_t": t, "clip": swing["clip"], "kind": swing["kind"]})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(float(a["t"]), float(b["t"])):
			return int(a["seq"]) < int(b["seq"])
		return float(a["t"]) < float(b["t"])
	)
	_timeline = entries
	_cursor = 0
	if entries.is_empty():
		_time = 0.0
		_end_time = 1.0
	else:
		_time = minf(0.0, float(entries[0]["t"])) - 0.05
		_end_time = float(entries[entries.size() - 1]["t"]) + 1.5


## Какой клип играть на событии боя. Названия клипов берём из battle_view.gd,
## чтобы в тестовой сцене они совпадали с основной.
func _pick_swing(src: Dictionary, event: Dictionary) -> Dictionary:
	var kind_event := str(event.get("type", ""))
	var skill_name := str(event.get("name", ""))
	var model := str(src["model"])
	var table: Dictionary = View.CLIP_ALIAS.get(model, {})
	var cat := "attack" if kind_event == "attack" else "skill"
	var clip := str(table.get(cat, ""))
	if kind_event == "skill" and skill_name == "cleave":
		clip = "Skill_01"
	elif kind_event == "skill" and (skill_name == "oath" or skill_name == "spirit"):
		clip = "Sword_Shout"
	elif kind_event == "attack" and model == "uraldar":
		src["swings"] = int(src["swings"]) + 1
		clip = "Left_Slash" if int(src["swings"]) % 2 == 0 else "Thrust_Slash"
	return {"clip": clip, "kind": cat}


func _process(delta: float) -> void:
	_time += delta * playback_rate
	while _cursor < _timeline.size() and float(_timeline[_cursor]["t"]) <= _time:
		_run(_timeline[_cursor])
		_cursor += 1
	_slide(delta * playback_rate)
	_fx(delta)
	_update_info()
	if _shot_path != "" and not _shot_taken and _time >= _shot_at:
		_shot_taken = true
		_take_shot()
		return
	if _time > _end_time and _shot_path == "" and not _check:
		_finish_wait += delta
		if _finish_wait > 1.5 and loop_battle:
			get_tree().reload_current_scene()


func _run(entry: Dictionary) -> void:
	var event: Dictionary = entry["event"]
	match str(entry["do"]):
		"move":
			var unit: Dictionary = _units.get(str(event.get("unit", "")), {})
			if unit.is_empty():
				return
			var to: Array = event.get("to", [0, 0, 0])
			unit["goal"] = Vector3(float(to[0]), float(to[1]), float(to[2]))
			unit["walk_until"] = _time + 0.28
			if not bool(unit["down"]) and not (str(unit["pose"]) in ["attack", "skill", "hit"]):
				_set_pose(unit, "move")
		"swing":
			var src: Dictionary = _units.get(str(event.get("src", "")), {})
			if src.is_empty() or bool(src["down"]):
				return
			var swing: Dictionary = entry["swing"]
			_set_pose(src, str(swing["kind"]), str(swing["clip"]))
		"impact":
			if _check:
				_measure(entry)
			var dst: Dictionary = _units.get(str(event.get("dst", "")), {})
			if dst.is_empty():
				return
			if event.has("hp"):
				dst["hp"] = int(event["hp"])
			elif str(event.get("type", "")) == "heal":
				# В логе лечения нет поля hp, только amount.
				dst["hp"] = mini(int(dst["max_hp"]), int(dst["hp"]) + int(event.get("amount", 0)))
			else:
				return
			_refresh_bar(dst)
			var amount := int(event.get("amount", 0))
			if amount > 0:
				dst["flash"] = 0.14
				_float_number(dst, amount, str(event.get("type", "")) == "heal")
				if str(event.get("type", "")) != "heal":
					_set_pose(dst, "hit")
		"down":
			var unit2: Dictionary = _units.get(str(event.get("unit", "")), {})
			if unit2.is_empty():
				return
			unit2["down"] = true
			_set_pose(unit2, "death")


func _slide(delta: float) -> void:
	for id in _units.keys():
		var unit: Dictionary = _units[id]
		var root: Node3D = unit["root"]
		var goal: Vector3 = unit["goal"]
		var pace := 2.03 if str(unit["model"]) == "uraldar" else 1.4
		root.position = root.position.move_toward(goal, delta * pace)
		var flat := goal - root.position
		flat.y = 0.0
		var stepping := flat.length() > 0.05
		if stepping and unit["visual"] != null:
			var visual: Node3D = unit["visual"]
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(flat.x, flat.z), minf(1.0, delta * 6.0))
		var walking := stepping or float(unit.get("walk_until", 0.0)) > _time
		if not bool(unit["down"]) and str(unit["pose"]) == "move" and not walking:
			_set_pose(unit, "idle")


# ---------------------------------------------------------------- анимации

func _set_pose(unit: Dictionary, pose: String, clip: String = "") -> void:
	if bool(unit["down"]) and pose != "death":
		return
	if str(unit["pose"]) == pose and pose != "attack" and pose != "skill" and pose != "hit":
		return
	unit["pose"] = pose
	var player: AnimationPlayer = unit["player"]
	if player == null:
		return
	var table: Dictionary = View.CLIP_ALIAS.get(str(unit["model"]), {})
	var key := pose
	var actual := clip
	if actual == "" or not player.has_animation(actual):
		actual = str(table.get(key, ""))
	if actual == "" or not player.has_animation(actual):
		if pose == "hit" or pose == "death":
			return  # у модели нет такого клипа: остаётся прежняя поза
		actual = str(table.get("idle", ""))
	if not player.has_animation(actual):
		return
	var looped := pose == "idle" or pose == "move"
	player.get_animation(actual).loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
	var speed := anim.speed_for(pose) * playback_rate
	player.play(actual, anim.blend_for(pose))
	player.speed_scale = speed
	unit["clip"] = actual
	_log_lines.append("%.2f %s %s %s x%.2f" % [_time, unit["id"], pose, actual, speed])


func _on_anim_finished(_name: StringName, id: String) -> void:
	var unit: Dictionary = _units.get(id, {})
	if unit.is_empty() or bool(unit["down"]):
		return
	var pose := str(unit["pose"])
	if pose == "attack" or pose == "skill" or pose == "hit":
		_set_pose(unit, "idle")


## Те же правки таза, что в battle_view.gd: корень остаётся на месте, высота
## выравнивается. Анимации делятся между экземплярами, поэтому один раз на модель.
func _plant_feet(node: Node, file_id: String) -> void:
	if _planted.has(file_id):
		return
	_planted[file_id] = true
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
			var source := library.get_animation(anim_name)
			var copy := source.duplicate() as Animation
			var changed := false
			for track in copy.get_track_count():
				if not str(copy.track_get_path(track)).contains("Hips") or copy.track_get_type(track) != Animation.TYPE_POSITION_3D:
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


# ---------------------------------------------------------------- эффекты и HUD

func _tint_enemy(node: Node) -> void:
	if node is MeshInstance3D:
		var tint := StandardMaterial3D.new()
		tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tint.albedo_color = Color(0.9, 0.22, 0.16, 0.32)
		(node as MeshInstance3D).material_overlay = tint
	for child in node.get_children():
		_tint_enemy(child)


func _set_overlay(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_overlay = material
	for child in node.get_children():
		_set_overlay(child, material)


func _add_bar(root: Node3D, friendly: bool, unit: Dictionary) -> void:
	var bar := Node3D.new()
	bar.position = Vector3(0, 3.6, 0)
	bar.add_child(_quad(Vector2(1.5, 0.16), Color("1a1e18")))
	var fill := _quad(Vector2(1.42, 0.1), Color("3f9d55") if friendly else Color("c4523a"), 1)
	fill.position = Vector3(0, 0, 0.02)
	bar.add_child(fill)
	root.add_child(bar)
	unit["bar"] = fill


func _quad(size: Vector2, color: Color, priority: int = 0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	node.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.render_priority = priority
	node.material_override = material
	return node


func _refresh_bar(unit: Dictionary) -> void:
	var fill := unit["bar"] as MeshInstance3D
	if fill == null:
		return
	var ratio := clampf(float(unit["hp"]) / float(maxi(1, int(unit["max_hp"]))), 0.0, 1.0)
	fill.scale.x = maxf(ratio, 0.001)
	fill.position.x = (ratio - 1.0) * 0.71


func _float_number(unit: Dictionary, amount: int, heal: bool) -> void:
	var root: Node3D = unit["root"]
	var label := Label3D.new()
	label.text = ("+%d" if heal else "-%d") % amount
	label.font_size = 64
	label.pixel_size = 0.014
	label.no_depth_test = true
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("d6f07a") if heal else Color("ffd0c4")
	label.outline_size = 10
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.position = root.position + Vector3(0, 2.6, 0)
	add_child(label)
	_numbers.append({"node": label, "age": 0.0, "base": label.position})


func _fx(delta: float) -> void:
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	white.albedo_color = Color(1, 1, 1, 0.45)
	for id in _units.keys():
		var unit: Dictionary = _units[id]
		var left := float(unit["flash"])
		if left <= 0.0 or unit["visual"] == null:
			continue
		left = maxf(0.0, left - delta)
		unit["flash"] = left
		var base: Material = null
		if str(id).begins_with("R"):
			base = StandardMaterial3D.new()
			(base as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			(base as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			(base as StandardMaterial3D).albedo_color = Color(0.9, 0.22, 0.16, 0.32)
		_set_overlay(unit["visual"], white if left > 0.0 else base)
	var kept: Array = []
	for number in _numbers:
		number["age"] = float(number["age"]) + delta
		var age := float(number["age"])
		var label: Label3D = number["node"]
		label.position = (number["base"] as Vector3) + Vector3(0, age * 1.1, 0)
		label.modulate.a = clampf(1.0 - age / 0.85, 0.0, 1.0)
		if age >= 0.85:
			label.queue_free()
		else:
			kept.append(number)
	_numbers = kept


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	if show_hud_zones:
		var top := ColorRect.new()
		top.color = Color(0.1, 0.3, 0.6, 0.28)
		top.set_anchors_preset(Control.PRESET_TOP_WIDE)
		top.anchor_bottom = 0.12
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(top)
		var bottom := ColorRect.new()
		bottom.color = Color(0.1, 0.3, 0.6, 0.28)
		bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		bottom.anchor_top = 0.80
		bottom.anchor_bottom = 1.0
		bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(bottom)
	_info = Label.new()
	_info.position = Vector2(12, 12)
	_info.add_theme_font_size_override("font_size", 22)
	layer.add_child(_info)


func _update_info() -> void:
	if _info == null:
		return
	var view := get_viewport().get_visible_rect().size
	_info.text = "%dx%d  t=%.2f  angle %.1f  yaw %.1f  dist %.1f  size %.1f  победа: %s" % [
		int(view.x), int(view.y), _time, angle, yaw, distance, orthographic_size, _winner]


func _take_shot() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(_shot_path)
	print("SHOT ", _shot_path, " err=", err, " size=", image.get_size())
	var log_path := _shot_path.get_basename() + ".log"
	var file := FileAccess.open(log_path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log_lines))
	get_tree().quit()


## Что реально играет у атакующего в момент попадания (для --check).
func _measure(entry: Dictionary) -> void:
	var src: Dictionary = _units.get(str(entry["event"].get("src", "")), {})
	if src.is_empty() or src["player"] == null:
		return
	var swing: Dictionary = entry["swing"]
	var player: AnimationPlayer = src["player"]
	var want := float(anim.hit_time.get(swing["clip"], anim.default_hit_time))
	if player.current_animation == str(swing["clip"]):
		_measured.append(player.current_animation_position - want)
	else:
		_measured.append(INF)  # клип уже перебит следующим действием


## Режим --check: без картинки проигрывает весь бой и сверяет с симуляцией.
func _self_check() -> void:
	var worst := 0.0
	for pair in _pairs:
		var landed := float(pair["swing_t"]) + anim.lead_for(str(pair["clip"]), str(pair["kind"]))
		worst = maxf(worst, absf(landed - float(pair["impact_t"])))
	var steps := 0
	while _time < _end_time and steps < 20000:
		_process(1.0 / 60.0)
		for id in _units.keys():
			var player: AnimationPlayer = _units[id]["player"]
			if player != null:
				player.advance(1.0 / 60.0)
		steps += 1
	var bad := 0
	var dead := 0
	var dead_pose_ok := 0
	for id in _units.keys():
		var unit: Dictionary = _units[id]
		if int(unit["hp"]) != int(_expected.get(id, -1)):
			bad += 1
			print("CHECK hp mismatch ", id, " view=", unit["hp"], " sim=", _expected.get(id))
		if int(_expected.get(id, 1)) <= 0:
			dead += 1
			var player: AnimationPlayer = unit["player"]
			if bool(unit["down"]) and player != null and player.current_animation == "Dead":
				dead_pose_ok += 1
	var on_clip := 0
	var sum_dev := 0.0
	var max_dev := 0.0
	for dev in _measured:
		if is_finite(dev):
			on_clip += 1
			sum_dev += absf(dev)
			max_dev = maxf(max_dev, absf(dev))
	print("CHECK impacts_on_own_clip=", on_clip, "/", _measured.size(),
		" mean_dev_clip_s=", snappedf(sum_dev / maxf(on_clip, 1), 0.001),
		" max_dev_clip_s=", snappedf(max_dev, 0.001))
	print("CHECK swings=", _pairs.size(), " max_hit_offset_s=", snappedf(worst, 0.001),
		" hp_mismatch=", bad, " dead=", dead, " dead_in_Dead_clip=", dead_pose_ok,
		" winner=", _winner, " steps=", steps)
	get_tree().quit(0 if (bad == 0 and dead == dead_pose_ok) else 1)
