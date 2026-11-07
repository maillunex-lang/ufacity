extends RefCounted
## Адаптер между расчётом боя и показом. Расчёт остаётся в battle_sim.gd
## (клиентская копия server/app/battle.py), Battle V2 только читает готовый лог.
## Сцена не считает урон и не принимает решений о победе.

const Sim = preload("res://scripts/battle_sim.gd")


## Возвращает {units, events, winner, duration, limit}. Формат событий пока как у Sim.
static func fight(squad: Array, stage: int, levels: Dictionary = {}) -> Dictionary:
	var slots: Array = []
	for hero in squad:
		slots.append(str(hero))
	var raw: Dictionary = Sim.fight(slots, stage, levels)
	return {
		"units": raw.get("units", []),
		"events": raw.get("events", []),
		"winner": str(raw.get("winner", "draw")),
		"duration": float(raw.get("duration", 0.0)),
		"limit": Sim.LIMIT,
	}
