extends RefCounted

const TICK := 0.1
const LIMIT := 20.0
const MELEE_RANGE := 1.6
const RANGED_RANGE := 6.0
const STEP := 1.4
const URALDAR_REACH := 9.0
static var _slot_rows: Array = []


static func slot_vector(slot: int) -> Vector2:
	if _slot_rows.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/formation.json"))
		_slot_rows = parsed["slots"]
		if _slot_rows.size() != 5:
			push_error("formation.json must list 5 slots")
	var row: Array = _slot_rows[slot]
	return Vector2(float(row[0]), float(row[1]))

static func fight(slots: Array, stage: int = 1, levels: Dictionary = {}) -> Dictionary:
	var left: Array = []
	var right: Array = []
	var safe_stage := maxi(1, stage)
	for slot in range(5):
		var hero_id := str(slots[slot]) if slot < slots.size() else "temp_a"
		var level := int(levels.get(hero_id, levels.get(_canon(hero_id), 1)))
		left.append(_player(slot, hero_id, level))
		right.append(_enemy(slot, safe_stage))
	return _simulate(left, right, 1)


static func _canon(raw: String) -> String:
	if raw == "swordsman" or raw == "temp_a":
		return "temp_a"
	if raw == "priest" or raw == "temp_b":
		return "temp_b"
	if raw == "temp_c":
		return "temp_c"
	if raw == "uraldar":
		return "uraldar"
	return "temp_a"


static func _player(slot: int, hero_id: String, level: int) -> Dictionary:
	var canon := _canon(hero_id)
	var safe_level := maxi(1, level)
	if canon == "temp_b":
		return {"slot": slot, "role": "ranger", "model": "priest", "hp": 90 + (safe_level - 1) * 20, "atk": 16 + (safe_level - 1) * 4, "def": 3, "speed": 1}
	if canon == "temp_c":
		return {"slot": slot, "role": "healer", "model": "priest", "hp": 100 + (safe_level - 1) * 20, "atk": 12 + (safe_level - 1) * 4, "def": 4, "speed": 1}
	if canon == "uraldar":
		return {"slot": slot, "role": "warrior", "model": "uraldar", "hp": 110 + (safe_level - 1) * 20, "atk": 22 + (safe_level - 1) * 4, "def": 5, "speed": 1.45}
	return {"slot": slot, "role": "tank", "model": "swordsman", "hp": 120 + (safe_level - 1) * 20, "atk": 20 + (safe_level - 1) * 4, "def": 6, "speed": 1}


static func _enemy(slot: int, stage: int) -> Dictionary:
	var roles := ["tank", "warrior", "ranger", "mage", "healer"]
	return {
		"slot": slot,
		"role": roles[slot],
		"model": "priest",
		"hp": 40 * stage,
		"atk": 6 * stage,
		"def": 1,
		"speed": 1,
	}


static func _simulate(left: Array, right: Array, seed: int) -> Dictionary:
	var units: Array = []
	for raw in left:
		units.append(_make("left", raw))
	for raw in right:
		units.append(_make("right", raw))
	var events: Array = []
	var t_cent := 0
	while t_cent < int(LIMIT * 100):
		var alive_left := _alive(units, "left")
		var alive_right := _alive(units, "right")
		if alive_left.is_empty() or alive_right.is_empty():
			break
		var t := t_cent / 100.0
		var order: Array = units.duplicate()
		order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["id"]) < str(b["id"]))
		for actor in order:
			if int(actor["hp"]) <= 0:
				continue
			actor["cooldown"] = maxf(0.0, float(actor["cooldown"]) - TICK)
			var foes: Array = alive_right if str(actor["side"]) == "left" else alive_left
			var allies: Array = alive_left if str(actor["side"]) == "left" else alive_right
			var melee := false
			var target: Dictionary = {}
			if str(actor["role"]) == "healer":
				target = _heal_target(allies)
			else:
				target = _pick_target(actor, foes)
				melee = str(actor["role"]) == "tank" or str(actor["role"]) == "warrior"
			if target.is_empty() or target == actor:
				continue
			var reach := MELEE_RANGE if melee else RANGED_RANGE
			var pos: Vector2 = actor["pos"]
			var dst: Vector2 = target["pos"]
			var gap := _dist(pos, dst)
			var lunging := str(actor.get("model", "")) == "uraldar" and float(actor["cooldown"]) <= 0.0 and t >= 0.45 and gap <= URALDAR_REACH
			if melee and gap > reach and not lunging:
				actor["pos"] = _toward(pos, dst, STEP * TICK * float(actor["speed"]))
				var moved: Vector2 = actor["pos"]
				events.append({
					"t": t,
					"type": "move",
					"unit": actor["id"],
					"to": [snappedf(moved.x, 0.001), 0, snappedf(moved.y, 0.001)],
				})
				continue
			if float(actor["cooldown"]) > 0.0:
				continue
			if str(actor["role"]) == "healer":
				var healed_amount := maxi(1, int(actor["atk"]) - int(int(target["def"]) / 2))
				var healed := mini(healed_amount, int(target["max_hp"]) - int(target["hp"]))
				target["hp"] = int(target["hp"]) + healed
				events.append({
					"t": t,
					"type": "heal",
					"src": actor["id"],
					"dst": target["id"],
					"amount": healed,
				})
				actor["cooldown"] = 1.0 / maxf(float(actor["speed"]), 0.1)
				continue
			if t >= float(actor["might_until"]):
				actor["might"] = 1.0
			var kind := _uraldar_action(actor)
			_perform(actor, target, allies, events, t, kind)
		t_cent += 10
	var left_hp := 0
	var right_hp := 0
	for unit in units:
		if str(unit["side"]) == "left":
			left_hp += int(unit["hp"])
		else:
			right_hp += int(unit["hp"])
	var winner := "draw"
	if left_hp <= 0:
		winner = "right"
	elif right_hp <= 0:
		winner = "left"
	var dumped: Array = []
	for unit in units:
		dumped.append({
			"id": unit["id"],
			"model": unit["model"],
			"hp": int(unit["hp"]),
			"max_hp": int(unit["max_hp"]),
			"role": unit["role"],
		})
	return {
		"seed": seed,
		"winner": winner,
		"duration": minf(t_cent / 100.0, LIMIT),
		"reward_granted": false,
		"events": events,
		"units": dumped,
	}


static func _make(side: String, raw: Dictionary) -> Dictionary:
	var slot := int(raw["slot"])
	var spot: Vector2 = slot_vector(slot)
	if side == "left":
		spot.y = -spot.y
	var max_hp := int(raw["hp"])
	var letter := "L" if side == "left" else "R"
	return {
		"id": "%s%d" % [letter, slot],
		"side": side,
		"slot": slot,
		"role": str(raw["role"]),
		"model": str(raw["model"]),
		"hp": max_hp,
		"max_hp": max_hp,
		"atk": int(raw["atk"]),
		"def": int(raw["def"]),
		"speed": float(raw.get("speed", 1)),
		"pos": spot,
		"cooldown": 0.0,
		"swing": 0,
		"guard_until": 0.0,
		"might": 1.0,
		"might_until": 0.0,
		"did_cleave": false,
		"did_oath": false,
		"did_spirit": false,
	}


static func _perform(actor: Dictionary, target: Dictionary, allies: Array, events: Array, now: float, kind: String) -> void:
	if now >= float(actor["might_until"]):
		actor["might"] = 1.0
	if kind == "oath":
		actor["guard_until"] = snappedf(now + 1.5, 0.01)
		actor["cooldown"] = 1.0 / maxf(float(actor["speed"]), 0.1)
		events.append({"t": now, "type": "skill", "name": "oath", "src": actor["id"], "amount": 0})
		return
	if kind == "spirit":
		var until := snappedf(now + 1.5, 0.01)
		for ally in allies:
			if int(ally["hp"]) > 0:
				ally["might"] = 1.25
				ally["might_until"] = until
	var amount := _strike(actor, target, now)
	if kind == "cleave":
		amount += 6
	target["hp"] = maxi(0, int(target["hp"]) - amount)
	if kind == "attack":
		events.append({
			"t": now,
			"type": "attack",
			"src": actor["id"],
			"dst": target["id"],
			"amount": amount,
			"hp": int(target["hp"]),
		})
	else:
		events.append({
			"t": now,
			"type": "skill",
			"name": kind,
			"src": actor["id"],
			"dst": target["id"],
			"amount": amount,
			"hp": int(target["hp"]),
		})
	if int(target["hp"]) == 0:
		events.append({"t": now, "type": "down", "unit": target["id"]})
	actor["cooldown"] = 1.0 / maxf(float(actor["speed"]), 0.1)


static func _uraldar_action(actor: Dictionary) -> String:
	if str(actor.get("model", "")) != "uraldar":
		return "attack"
	actor["swing"] = int(actor.get("swing", 0)) + 1
	var spot := (int(actor["swing"]) - 1) % 4
	if spot == 1:
		return "cleave"
	if spot == 2:
		return "oath"
	if spot == 3:
		return "spirit"
	return "attack"


static func _strike(actor: Dictionary, target: Dictionary, now: float) -> int:
	var power := float(actor["atk"]) * float(actor.get("might", 1.0))
	var amount := maxi(1, int(power) - int(int(target["def"]) / 2))
	if now < float(target.get("guard_until", 0.0)):
		amount = maxi(1, int(float(amount) * 0.65))
	return amount


static func _alive(units: Array, side: String) -> Array:
	var found: Array = []
	for unit in units:
		if str(unit["side"]) == side and int(unit["hp"]) > 0:
			found.append(unit)
	return found


static func _pick_target(actor: Dictionary, foes: Array) -> Dictionary:
	var alive: Array = []
	for unit in foes:
		if int(unit["hp"]) > 0:
			alive.append(unit)
	if alive.is_empty() or str(actor["role"]) == "healer":
		return {}
	var front: Array = []
	for unit in alive:
		if int(unit["slot"]) == 0 or int(unit["slot"]) == 1:
			front.append(unit)
	var pool: Array = front if not front.is_empty() else alive
	var best: Dictionary = pool[0]
	for unit in pool:
		if int(unit["slot"]) < int(best["slot"]) or (int(unit["slot"]) == int(best["slot"]) and str(unit["id"]) < str(best["id"])):
			best = unit
	return best


static func _heal_target(allies: Array) -> Dictionary:
	var alive: Array = []
	for unit in allies:
		if int(unit["hp"]) > 0:
			alive.append(unit)
	if alive.is_empty():
		return {}
	var best: Dictionary = alive[0]
	for unit in alive:
		var ratio := float(unit["hp"]) / float(unit["max_hp"])
		var best_ratio := float(best["hp"]) / float(best["max_hp"])
		if ratio < best_ratio or (is_equal_approx(ratio, best_ratio) and int(unit["slot"]) < int(best["slot"])):
			best = unit
	return best


static func _dist(a: Vector2, b: Vector2) -> float:
	return a.distance_to(b)


static func _toward(src: Vector2, dst: Vector2, step: float) -> Vector2:
	var d := _dist(src, dst)
	if d <= step or d == 0.0:
		return dst
	return src + (dst - src) * (step / d)
