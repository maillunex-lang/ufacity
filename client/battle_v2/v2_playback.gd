extends Node
## Проигрывает готовый лог боя на героях. Урон, цели, смерти и победа берутся только
## из лога (battle_sim.gd); здесь нет ни одного расчёта боя.
##
## Попадание привязано к событию лога: клип стартует раньше события на время подготовки
## удара (hit_time клипа, делённое на скорость), и удар доходит ровно в момент события.
## Если перезарядка короче подготовки (у Уралдара 0.69 с), клип ускоряется сверх
## настройки, но не больше max_boost. Остаток неточности пишется в `late`.

const Layout = preload("res://battle_v2/v2_layout.gd")

## Ускорение клипа удара сверх настройки, максимум.
const MAX_BOOST := 2.0
## Пауза после последнего события перед итогом, с.
const HOLD := 1.5

signal impact(src_id: String, dst_id: String, amount: int, hp: int, kind: String)
signal unit_down(unit_id: String)
signal finished(winner: String, reason: String)

var heroes: Dictionary = {}
var config: Resource
var winner := "draw"
var reason := ""
var duration := 0.0
var limit := 90.0
var time_scale := 1.0
## Время боя в секундах симуляции, не меньше нуля.
var battle_time := 0.0
var hp: Dictionary = {}
var max_hp: Dictionary = {}
## Статистика построения расписания.
var stats := {"swings": 0, "boosted": 0, "late": 0, "max_late": 0.0, "max_boost": 1.0}
var late_list: Array = []

var _timeline: Array = []
var _cursor := 0
var _clock := 0.0
var _end_clock := 0.0
var _done := false
var _swings := {}


func setup(hero_nodes: Dictionary, fight: Dictionary, cfg: Resource) -> void:
	heroes = hero_nodes
	config = cfg
	winner = str(fight["winner"])
	duration = float(fight["duration"])
	limit = float(fight["limit"])
	for unit in fight["units"]:
		max_hp[str(unit["id"])] = int(unit["max_hp"])
		hp[str(unit["id"])] = int(unit["max_hp"])
	_build(fight["events"])


func set_time_scale(value: float) -> void:
	time_scale = value
	for id in heroes:
		heroes[id].set_time_scale(value)


func _build(events: Array) -> void:
	var entries: Array = []
	var seq := 0
	var last_pos := {}
	var last_move := {}
	var last_impact := {}
	var alternate := {}
	for id in heroes:
		last_pos[id] = Layout.home(id)
		last_move[id] = -100.0
		last_impact[id] = -100.0
		alternate[id] = 0
	for event in events:
		var kind := str(event.get("type", ""))
		var t := float(event.get("t", 0.0))
		if kind == "move":
			var unit := str(event["unit"])
			var to: Array = event["to"]
			var target := Vector3(float(to[0]), 0.0, float(to[2]))
			var pace := (target - last_pos[unit]).length() / 0.1
			last_pos[unit] = target
			last_move[unit] = t
			entries.append({"t": t, "seq": seq, "do": "move", "unit": unit, "to": target, "pace": pace})
			seq += 1
		elif kind == "down":
			entries.append({"t": t, "seq": seq, "do": "down", "unit": str(event["unit"])})
			seq += 1
		elif kind == "attack" or kind == "heal" or kind == "skill":
			var src := str(event["src"])
			var hero: Node3D = heroes[src]
			var action := "attack" if kind == "attack" else "skill"
			var clip := _clip(hero, event, kind, alternate, src)
			var hit_at := float(config.hit_time.get(clip, 0.5))
			var base_speed := float(config.speed_for(action))
			var lead := hit_at / base_speed
			var window_min := hit_at / (base_speed * MAX_BOOST)
			var start := maxf(float(last_impact[src]) + 0.02, minf(maxf(t - lead, float(last_move[src])), t - window_min))
			var window := maxf(t - start, 0.001)
			var needed := hit_at / window
			var boost := clampf(needed / base_speed, 1.0, MAX_BOOST)
			var late := 0.0
			if needed > base_speed * MAX_BOOST + 0.001:
				late = hit_at / (base_speed * MAX_BOOST) - window
			stats["swings"] += 1
			if boost > 1.001:
				stats["boosted"] += 1
			stats["max_boost"] = maxf(float(stats["max_boost"]), boost)
			if late > 0.001:
				stats["late"] += 1
				stats["max_late"] = maxf(float(stats["max_late"]), late)
				late_list.append({"unit": src, "t": t, "late": late, "clip": clip})
			last_impact[src] = t
			var swing := {"clip": clip, "action": action, "boost": boost, "hit_at": hit_at}
			entries.append({"t": start, "seq": seq, "do": "swing", "event": event, "swing": swing})
			seq += 1
			entries.append({"t": t, "seq": seq, "do": "impact", "event": event, "swing": swing})
			seq += 1
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(float(a["t"]), float(b["t"])):
			return int(a["seq"]) < int(b["seq"])
		return float(a["t"]) < float(b["t"])
	)
	_timeline = entries
	_cursor = 0
	if entries.is_empty():
		_clock = 0.0
		_end_clock = HOLD
	else:
		_clock = minf(0.0, float(entries[0]["t"])) - 0.05
		_end_clock = float(entries[entries.size() - 1]["t"]) + HOLD


func _clip(hero: Node3D, event: Dictionary, kind: String, alternate: Dictionary, src: String) -> String:
	var skill_name := str(event.get("name", ""))
	if kind == "skill" and skill_name == "cleave":
		return "Skill_01"
	if kind == "skill" and (skill_name == "oath" or skill_name == "spirit"):
		return "Sword_Shout"
	if kind == "attack" and hero.model == "uraldar":
		alternate[src] = int(alternate[src]) + 1
		return "Left_Slash" if int(alternate[src]) % 2 == 0 else "Thrust_Slash"
	return hero.clip_for("attack" if kind == "attack" else "skill")


func _process(delta: float) -> void:
	if _done:
		return
	_clock += delta * time_scale
	battle_time = clampf(_clock, 0.0, limit)
	while _cursor < _timeline.size() and float(_timeline[_cursor]["t"]) <= _clock:
		_run(_timeline[_cursor])
		_cursor += 1
	if _clock >= _end_clock:
		_done = true
		reason = "timeout" if duration >= limit - 0.001 else ("draw" if winner == "draw" else "ko")
		finished.emit(winner, reason)


func _run(entry: Dictionary) -> void:
	var event: Dictionary = entry.get("event", {})
	match str(entry["do"]):
		"move":
			var hero: Node3D = heroes.get(str(entry["unit"]))
			if hero != null:
				hero.run_to(entry["to"], float(entry["pace"]))
		"swing":
			var src: Node3D = heroes.get(str(event.get("src", "")))
			if src == null:
				return
			var dst: Node3D = heroes.get(str(event.get("dst", "")))
			if dst != null:
				src.aim_at(dst.position)
			var swing: Dictionary = entry["swing"]
			if str(swing["action"]) == "attack":
				src.attack(str(swing["clip"]), float(swing["boost"]))
			else:
				src.skill(str(swing["clip"]), float(swing["boost"]))
		"impact":
			var kind := str(event.get("type", ""))
			var dst_id := str(event.get("dst", ""))
			var amount := int(event.get("amount", 0))
			if dst_id != "" and heroes.has(dst_id):
				if event.has("hp"):
					hp[dst_id] = int(event["hp"])
				elif kind == "heal":
					hp[dst_id] = mini(int(max_hp[dst_id]), int(hp[dst_id]) + amount)
				if kind != "heal" and amount > 0:
					heroes[dst_id].hit()
			impact.emit(str(event.get("src", "")), dst_id, amount, int(hp.get(dst_id, 0)), kind)
		"down":
			var dead: Node3D = heroes.get(str(entry["unit"]))
			if dead != null:
				dead.die()
			unit_down.emit(str(entry["unit"]))
