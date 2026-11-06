extends Node3D

const LOG_PATH := "res://data/sample_log.json"

var _units := {}
var _events: Array = []
var _cursor := 0
var _time := 0.0
var _result: Label


func _ready() -> void:
	var camera := $Camera3D
	camera.position = Vector3(0, 8, 11)
	camera.look_at(Vector3(0, 0.5, 0))
	_build_hud()
	_load_log()


func _process(delta: float) -> void:
	_time += delta
	while _cursor < _events.size() and float(_events[_cursor].get("t", 0.0)) <= _time:
		_apply(_events[_cursor])
		_cursor += 1
	if _cursor >= _events.size() and _events.size() > 0 and _result.visible == false:
		_result.visible = true


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var back := Button.new()
	back.text = "В город"
	back.position = Vector2(24, 24)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)
	layer.add_child(back)
	_result = Label.new()
	_result.visible = false
	_result.position = Vector2(24, 90)
	_result.size = Vector2(670, 160)
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(_result)


func _load_log() -> void:
	if not FileAccess.file_exists(LOG_PATH):
		push_warning("No sample log. Drop a GLB later; this scene only plays a log.")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LOG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Sample log is not JSON")
		return
	for unit in parsed.get("units", []):
		_spawn(str(unit["id"]), str(unit.get("model", "TEMP")), int(unit.get("max_hp", unit.get("hp", 1))))
	_events = parsed.get("events", [])
	var winner := str(parsed.get("winner", "draw"))
	var title := "Ничья"
	if winner == "left":
		title = "Победа"
	elif winner == "right":
		title = "Поражение"
	_result.text = title + "\nНаграда не выдана. Это просмотр лога, не серверное сохранение."


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
	root.set_meta("hp", max_hp)
	root.set_meta("max_hp", max_hp)
	var used_glb := _attach_glb(root, model)
	if not used_glb:
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
	label.text = "TEMP %s\n%d/%d" % [model if not used_glb else model, max_hp, max_hp]
	if used_glb:
		label.text = "%s\n%d/%d" % [model, max_hp, max_hp]
	label.position = Vector3(0, 2.1, 0)
	label.font_size = 42
	root.add_child(label)
	add_child(root)
	_units[id] = root
	_play(root, "idle")


func _attach_glb(root: Node3D, model: String) -> bool:
	var path := "res://assets/heroes/%s.glb" % model
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
		_play(unit, "move")
	elif kind == "attack" or kind == "heal":
		var src = _units.get(str(event.get("src", "")))
		if src != null:
			src.scale = Vector3(1.12, 1.12, 1.12)
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
	var player := _find_player(root)
	if player == null:
		return
	if player.has_animation(clip):
		player.play(clip)
	elif player.has_animation("idle"):
		player.play("idle")


func _find_player(node: Node):
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = _find_player(child)
		if found != null:
			return found
	return null
