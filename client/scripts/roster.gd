extends Node

const SAVE_PATH := "user://roster.json"
const CATALOG := {
	"temp_a": {"name": "Мечник", "model": "swordsman", "role": "tank", "rarity": "обычный", "hp": 120, "atk": 20, "def": 6},
	"temp_b": {"name": "Жрец", "model": "priest", "role": "ranger", "rarity": "обычный", "hp": 90, "atk": 16, "def": 3},
	"temp_c": {"name": "Жрец-целитель", "model": "priest", "role": "healer", "rarity": "необычный", "hp": 100, "atk": 12, "def": 4},
}
const OWNED_ORDER := ["temp_a", "temp_b", "temp_c"]

var slots: Array = ["temp_a", "temp_a", "temp_b", "temp_b", "temp_b"]
var heroes := {"temp_a": {"level": 1, "copies": 1}, "temp_b": {"level": 1, "copies": 1}}
var stage := 1
var vip := 0


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
	vip = maxi(0, int(parsed.get("vip", 0)))
	var stored = parsed.get("heroes", {})
	if typeof(stored) != TYPE_DICTIONARY:
		return
	for hero_id in stored.keys():
		if not CATALOG.has(hero_id):
			continue
		var row = stored[hero_id]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		heroes[hero_id] = {
			"level": maxi(1, int(row.get("level", 1))),
			"copies": maxi(1, int(row.get("copies", 1))),
		}


func _read_slots(parsed: Array) -> void:
	if parsed.size() != 5:
		return
	for i in 5:
		var hero_id := _canon(str(parsed[i]))
		if hero_id != "":
			slots[i] = hero_id


func _canon(raw: String) -> String:
	if raw == "swordsman":
		return "temp_a"
	if raw == "priest":
		return "temp_b"
	if CATALOG.has(raw):
		return raw
	return ""


func owned_ids() -> Array:
	var ids: Array = []
	for hero_id in OWNED_ORDER:
		if heroes.has(hero_id):
			ids.append(hero_id)
	return ids


func cycle_slot(index: int) -> void:
	var ids := owned_ids()
	if ids.is_empty():
		return
	var at := ids.find(slots[index])
	slots[index] = ids[(at + 1) % ids.size()] if at >= 0 else ids[0]
	_save()


func advance_stage() -> void:
	stage += 1
	_save()


func levels() -> Dictionary:
	var out := {}
	for hero_id in heroes.keys():
		out[hero_id] = int(heroes[hero_id]["level"])
	return out


func combat(hero_id: String) -> Dictionary:
	var canon := _canon(hero_id)
	if canon == "":
		canon = "temp_a"
	var base: Dictionary = CATALOG[canon]
	var level := 1
	if heroes.has(canon):
		level = int(heroes[canon]["level"])
	return {
		"id": canon,
		"name": str(base["name"]),
		"model": str(base["model"]),
		"role": str(base["role"]),
		"rarity": str(base["rarity"]),
		"level": level,
		"copies": int(heroes[canon]["copies"]) if heroes.has(canon) else 0,
		"hp": int(base["hp"]) + (level - 1) * 20,
		"atk": int(base["atk"]) + (level - 1) * 4,
		"def": int(base["def"]),
	}


func allows_rate(rate: int) -> bool:
	if rate <= 1:
		return true
	if rate == 2:
		return vip >= 1
	if rate == 4:
		return vip >= 4
	return false


func allows_sim() -> bool:
	return vip >= 7


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"slots": slots, "stage": stage, "heroes": heroes, "vip": vip}))
