extends Node3D

const LOG_PATH := "res://data/sample_log.json"

var _units := {}
var _events: Array = []
var _cursor := 0
var _time := 0.0


func _ready() -> void:
	var camera := $Camera3D
	camera.position = Vector3(0, 8, 11)
	camera.look_at(Vector3(0, 0.5, 0))
	_load_log()


func _process(delta: float) -> void:
	_time += delta
	while _cursor < _events.size() and float(_events[_cursor].get("t", 0.0)) <= _time:
		_apply(_events[_cursor])
		_cursor += 1


func _load_log() -> void:
	if not FileAccess.file_exists(LOG_PATH):
		push_warning("No sample log. Drop a GLB later; this scene only plays a log.")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LOG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Sample log is not JSON")
		return
	for unit in parsed.get("units", []):
		_spawn(str(unit["id"]), str(unit.get("model", "TEMP")))
	_events = parsed.get("events", [])


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


func _spawn(id: String, model: String) -> void:
	var root := Node3D.new()
	root.position = _home(id)
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
	label.text = "TEMP " + model
	label.position = Vector3(0, 1.9, 0)
	label.font_size = 48
	label.modulate = Color(1, 1, 1)
	root.add_child(label)
	add_child(root)
	_units[id] = root


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
			src.scale = Vector3(1.15, 1.15, 1.15)
	elif kind == "down":
		var unit = _units.get(str(event.get("unit", "")))
		if unit != null:
			unit.rotation.z = 1.4
