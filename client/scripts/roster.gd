extends Node

const SAVE_PATH := "user://roster.json"
var slots := ["swordsman", "swordsman", "priest", "priest", "priest"]
var stage := 1


func _ready() -> void:
	_load()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) == TYPE_ARRAY:
		_read_slots(parsed)
		return
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_read_slots(parsed.get("slots", []))
	stage = maxi(1, int(parsed.get("stage", 1)))


func _read_slots(parsed: Array) -> void:
	if parsed.size() != 5:
		return
	for i in 5:
		var model := str(parsed[i])
		if model == "swordsman" or model == "priest":
			slots[i] = model


func set_slot(index: int, model: String) -> void:
	slots[index] = model
	_save()


func advance_stage() -> void:
	stage += 1
	_save()


func model_for(unit_id: String) -> String:
	if not unit_id.begins_with("L"):
		return ""
	var slot := unit_id.substr(1).to_int()
	if slot < 0 or slot >= slots.size():
		return ""
	return str(slots[slot])


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"slots": slots, "stage": stage}))
