extends RefCounted

const TICK := 0.1
const LIMIT := 20.0
const MELEE_RANGE := 1.6
const RANGED_RANGE := 6.0
const STEP := 1.4
const SLOTS := {
	0: Vector2(-1.6, 1.2),
	1: Vector2(1.6, 1.2),
	2: Vector2(-2.4, 3.2),
	3: Vector2(0.0, 3.2),
	4: Vector2(2.4, 3.2),
}

static func fight(slots: Array, stage: int = 1) -> Dictionary:
	var left: Array = []
	var right: Array = []
	var safe_stage := maxi(1, stage)
	for slot in range(5):
		var model := str(slots[slot]) if slot < slots.size() else "swordsman"
		if model != "priest":
			model = "swordsman"
		left.append(_player(slot, model))
		right.append(_enemy(slot, safe_stage))
	return _simulate(left, right, 1)


static func _player(slot: int, model: String) -> Dictionary:
	if model == "priest":
		return {"slot": slot, "role": "ranger", "model": model, "hp": 90, "atk": 16, "def": 3, "speed": 1}
	return {"slot": slot, "role": "tank", "model": "swordsman", "hp": 120, "atk": 20, "def": 6, "speed": 1}


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
			if melee and _dist(pos, dst) > reach:
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
			var amount := maxi(1, int(actor["atk"]) - int(int(target["def"]) / 2))
			if str(actor["role"]) == "healer":
				var healed := mini(amount, int(target["max_hp"]) - int(target["hp"]))
				target["hp"] = int(target["hp"]) + healed
				events.append({
					"t": t,
					"type": "heal",
					"src": actor["id"],
					"dst": target["id"],
					"amount": healed,
				})
			else:
				target["hp"] = maxi(0, int(target["hp"]) - amount)
				events.append({
					"t": t,
					"type": "attack",
					"src": actor["id"],
					"dst": target["id"],
					"amount": amount,
					"hp": int(target["hp"]),
				})
				if int(target["hp"]) == 0:
					events.append({"t": t, "type": "down", "unit": target["id"]})
			actor["cooldown"] = 1.0 / maxf(float(actor["speed"]), 0.1)
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
	var spot: Vector2 = SLOTS[slot]
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
		"speed": float(raw["speed"]),
		"pos": spot,
		"cooldown": 0.0,
	}


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
