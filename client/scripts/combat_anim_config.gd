class_name CombatAnimConfig
extends Resource
## Скорости и смешивание анимаций боя. Все значения можно менять в инспекторе.
## Это только показ: расчёт боя, урон и частота атак живут в battle_sim.gd.

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

@export_group("Момент попадания")
## Секунды внутри клипа (при скорости 1.0), когда оружие или заклинание бьёт.
## Взято по пику скорости правой руки в самом клипе. Клип стартует раньше
## события боя ровно настолько, чтобы попадание пришлось на время события.
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
@export_range(0.0, 3.0, 0.05) var default_hit_time := 0.5


func speed_for(kind: String) -> float:
	match kind:
		"idle":
			return idle_speed
		"move":
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


func blend_for(kind: String) -> float:
	match kind:
		"idle":
			return idle_blend
		"move":
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


func lead_for(clip: String, kind: String) -> float:
	## За сколько секунд боя до события надо запускать клип.
	var at := float(hit_time.get(clip, default_hit_time))
	return at / maxf(speed_for(kind), 0.05)
