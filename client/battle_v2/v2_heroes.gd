extends RefCounted
## Справочник героев Battle V2: файл модели, высота в кадре, клипы.
## Модели те же GLB из res://assets/heroes/, сами файлы не меняются.

const FILE := {
	"swordsman": "swordsman",
	"priest": "priest",
	"uraldar": "uraldar",
	"TEMP_A": "swordsman",
	"TEMP_B": "priest",
}

## Высота исходной сетки (из mesh AABB) и высота героя на экране в метрах.
const MESH_HEIGHT := {"swordsman": 1.7, "priest": 1.1, "uraldar": 1.8}
const SCREEN_HEIGHT := 3.4

## Клипы, найденные в GLB. Пустая строка значит: такого клипа в файле нет.
## Распределение под действия будет уточнено на этапе C.
const CLIPS := {
	"swordsman": {"idle": "Idle_9", "run": "Running", "attack": "Thrust_Slash", "skill": "Jump_and_Slam_Back_Down", "hit": "Hit_Reaction", "death": "Dead"},
	"priest": {"idle": "Idle_11", "run": "Running", "attack": "Attack", "skill": "Charged_Spell_Cast", "hit": "Hit_Reaction", "death": "Dead"},
	"uraldar": {"idle": "Combat_Stance", "run": "Running", "attack": "Thrust_Slash", "skill": "Skill_01", "hit": "Hit_Reaction", "death": "Dead"},
}


static func file_id(model: String) -> String:
	return str(FILE.get(model, model))


static func scale_for(file: String) -> float:
	return SCREEN_HEIGHT / float(MESH_HEIGHT.get(file, 1.7))


## Клипы, которых нет в GLB модели. Берутся из другой модели с тем же скелетом Mixamo
## (24 кости, пути треков совпадают). Позиционные треки масштабируются по высоте таза.
## Исходные GLB не меняются, копия живёт только в памяти.
const RETARGET := {
	"swordsman": {"Hit_Reaction": {"from": "uraldar"}},
}
