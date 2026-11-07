extends Resource
## Скорости и смешивание анимаций Battle V2. Всё меняется в инспекторе.
## Это только показ: расчёт и частота атак живут в battle_sim.gd.

@export_group("Скорость клипа (множитель)")
@export_range(0.1, 4.0, 0.05) var idle_speed := 1.0
@export_range(0.1, 4.0, 0.05) var run_speed := 1.2
@export_range(0.1, 4.0, 0.05) var attack_speed := 1.4
@export_range(0.1, 4.0, 0.05) var skill_speed := 1.15
@export_range(0.1, 4.0, 0.05) var hit_speed := 1.3
@export_range(0.1, 4.0, 0.05) var death_speed := 1.0

@export_group("Смешивание при входе в клип, с")
@export_range(0.0, 1.0, 0.01) var idle_blend := 0.2
@export_range(0.0, 1.0, 0.01) var run_blend := 0.15
@export_range(0.0, 1.0, 0.01) var attack_blend := 0.08
@export_range(0.0, 1.0, 0.01) var skill_blend := 0.08
@export_range(0.0, 1.0, 0.01) var hit_blend := 0.05
@export_range(0.0, 1.0, 0.01) var death_blend := 0.1

@export_group("Перемещение")
## Метры в секунду. Сервер двигает героя на STEP*speed, значение должно совпадать.
@export_range(0.5, 6.0, 0.05) var move_speed := 1.4
@export_range(1.0, 20.0, 0.5) var turn_rate := 8.0

@export_group("Момент попадания")
## Секунды внутри клипа при скорости 1.0, когда удар доходит до цели. Оценка по пику
## скорости правой руки, не размеченные кадры. Нужно для этапа D.
@export var hit_time := {
	"Thrust_Slash": 1.52,
	"Left_Slash": 1.32,
	"Charged_Slash": 1.2,
	"Skill_01": 0.42,
	"Sword_Shout": 1.16,
	"Jump_and_Slam_Back_Down": 1.16,
	"Attack": 1.02,
	"Charged_Spell_Cast": 0.66,
}


func speed_for(state: String) -> float:
	match state:
		"idle":
			return idle_speed
		"run":
			return run_speed
		"attack":
			return attack_speed
		"skill":
			return skill_speed
		"hit":
			return hit_speed
		"death":
			return death_speed
	return 1.0


func blend_for(state: String) -> float:
	match state:
		"idle":
			return idle_blend
		"run":
			return run_blend
		"attack":
			return attack_blend
		"skill":
			return skill_blend
		"hit":
			return hit_blend
		"death":
			return death_blend
	return 0.1


## За сколько секунд боя до события надо запустить клип, чтобы попадание пришлось на событие.
func lead_for(clip: String, state: String) -> float:
	return float(hit_time.get(clip, 0.5)) / maxf(speed_for(state), 0.05)
