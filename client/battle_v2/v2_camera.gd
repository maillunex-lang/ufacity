extends Camera3D
## Камера комментатора Battle V2: ортографическая, сбоку и немного сверху.
## Во время боя не двигается. Все параметры меняются в инспекторе или из кода.

## Наклон сверху в градусах. 0 — строго сбоку.
@export_range(0.0, 60.0, 0.5) var angle := 18.0:
	set(value):
		angle = value
		apply()
## Поворот вокруг арены. 0 — строго вдоль оси x. Небольшой поворот разводит героев
## одной линии, иначе они стоят друг за другом на экране. Игроки всегда слева.
@export_range(-60.0, 60.0, 0.5) var yaw := 25.0:
	set(value):
		yaw = value
		apply()
## Расстояние от точки взгляда до камеры. В ортографии размер не меняет, но
## влияет на отсечение по глубине.
@export_range(5.0, 60.0, 0.5) var distance := 19.0:
	set(value):
		distance = value
		apply()
## Высота точки взгляда над полом.
@export_range(-5.0, 10.0, 0.1) var height := 1.0:
	set(value):
		height = value
		apply()
## Сдвиг точки взгляда в мире. Y поднимает или опускает бой на экране.
@export var offset := Vector3.ZERO:
	set(value):
		offset = value
		apply()
## Ширина кадра в метрах. Меньше значение — герои крупнее («приближение»).
@export_range(4.0, 60.0, 0.5) var zoom_width := 21.0:
	set(value):
		zoom_width = value
		apply()


func _ready() -> void:
	apply()


func apply() -> void:
	if not is_inside_tree():
		return
	projection = Camera3D.PROJECTION_ORTHOGONAL
	keep_aspect = Camera3D.KEEP_WIDTH
	size = zoom_width
	near = 0.1
	far = 120.0
	var target := Vector3(0.0, height, 0.0) + offset
	var pitch := deg_to_rad(angle)
	var turn := deg_to_rad(yaw)
	# Камера на -x: ось +z идёт вправо по экрану, значит игроки (z < 0) слева.
	var back := Vector3(-cos(pitch) * cos(turn), sin(pitch), -cos(pitch) * sin(turn))
	position = target + back * distance
	look_at(target, Vector3.UP)
