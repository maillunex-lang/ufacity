extends RefCounted
## Расстановка Battle V2. Точки берутся из client/data/formation.json через battle_sim.gd,
## так что клиент и сервер видят одни и те же координаты. Здесь только перевод в мир.
## Игроки (L) стоят в минусе по z и в кадре слева, враги (R) справа.

const Sim = preload("res://scripts/battle_sim.gd")


static func home(unit_id: String) -> Vector3:
	var spot := Sim.slot_vector(int(unit_id.substr(1)))
	var z := spot.y
	if unit_id.begins_with("L"):
		z = -z
	return Vector3(spot.x, 0.0, z)


static func is_front(unit_id: String) -> bool:
	return int(unit_id.substr(1)) < 2


## Куда смотрит герой: игроки в +z, враги в -z.
static func facing(unit_id: String) -> Vector3:
	return Vector3(0, 0, 1) if unit_id.begins_with("L") else Vector3(0, 0, -1)
