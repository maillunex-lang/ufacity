extends Node3D
## Один герой Battle V2: модель, AnimationPlayer, состояния и перемещение.
## Состояния: idle, run, attack, skill, hit, death. Скорости и смешивание берутся
## из v2_anim_config.gd. Бой здесь не считается: герою говорят, что делать.

const Heroes = preload("res://battle_v2/v2_heroes.gd")

## Приоритеты: более слабое состояние не прерывает более сильное.
## hit не рвёт замах атаки или навыка, иначе постоянные попадания не давали бы бить.
const PRIORITY := {"idle": 0, "run": 0, "hit": 1, "attack": 2, "skill": 2, "death": 3}
const ONE_SHOT := ["attack", "skill", "hit"]
## После остановки герой ещё столько секунд считается бегущим: сервер двигает
## героев тиками по 0.1 с, без этого бег моргал бы в idle между тиками.
const STOP_GRACE := 0.25

signal arrived
signal state_changed(state: String, clip: String)

static var _planted := {}
static var _retargeted := {}

var unit_id := ""
var model := ""
var config: Resource
var state := "idle"
var clip := ""
var goal := Vector3.ZERO
var moving := false
var time_scale := 1.0
## Скорость перемещения, м/с. Для боя её задаёт симуляция (по расстоянию между тиками).
var pace := 1.4
## Коэффициент к скорости клипа сверх настройки (когда замах надо уложить в перезарядку).
var boost := 1.0
## Сколько раз реально вызван AnimationPlayer.play() по клипам (для проверки перезапусков).
var play_counts := {}
## Клипы, которых нет в модели и которые не удалось заменить.
var missing := {}
## Клипы, взятые из другой модели: ключ действия -> откуда.
var retargeted := {}
var player: AnimationPlayer
var visual: Node3D
var _home_facing := 0.0
var _aim := 0.0
var _grace := 0.0
var _recoil: Tween


func setup(id: String, model_name: String, cfg: Resource) -> bool:
	unit_id = id
	model = Heroes.file_id(model_name)
	config = cfg
	pace = float(cfg.move_speed)
	name = id
	var packed := load("res://assets/heroes/%s.glb" % model) as PackedScene
	if packed == null:
		push_error("Нет модели %s для %s" % [model, id])
		return false
	visual = packed.instantiate() as Node3D
	add_child(visual)
	var fit := Heroes.scale_for(model)
	visual.scale = Vector3(fit, fit, fit)
	_home_facing = 0.0 if id.begins_with("L") else PI
	_aim = _home_facing
	visual.rotation.y = _home_facing
	player = _find_player(visual)
	_retarget()
	_plant_feet()
	_prepare_loops()
	for key in ["hit", "death", "attack", "skill", "run", "idle"]:
		if clip_for(key) == "":
			missing[key] = "нет клипа в %s.glb" % model
	goal = position
	_enter("idle", clip_for("idle"))
	return player != null


func clip_for(key: String) -> String:
	var name_in_file := str(Heroes.CLIPS[model].get(key, ""))
	if name_in_file != "" and player != null and player.has_animation(name_in_file):
		return name_in_file
	return ""


func has_clip(key: String) -> bool:
	return clip_for(key) != ""


## Бежать к точке. speed — м/с, 0 значит скорость из настройки.
func run_to(target: Vector3, speed: float = 0.0) -> void:
	goal = Vector3(target.x, position.y, target.z)
	moving = true
	_grace = 0.0
	pace = speed if speed > 0.0 else float(config.move_speed)
	if PRIORITY[state] <= PRIORITY["run"]:
		_enter("run", clip_for("run"))


func stop_moving() -> void:
	goal = position
	moving = false


## Повернуться лицом к точке (на время боя вместо исходного направления).
func aim_at(point: Vector3) -> void:
	var flat := point - position
	if flat.length() > 0.05:
		_aim = atan2(flat.x, flat.z)


## Обычная атака. clip_name выбирает вариант удара, пусто — клип по умолчанию.
## speed_boost > 1 ускоряет клип сверх настройки.
func attack(clip_name: String = "", speed_boost: float = 1.0) -> String:
	return _action("attack", clip_name, speed_boost)


func skill(clip_name: String = "", speed_boost: float = 1.0) -> String:
	return _action("skill", clip_name, speed_boost)


## Реакция на урон. Если клипа нет совсем, играет отдача и вспышка кодом (эффект).
func hit() -> String:
	if state == "death":
		return ""
	if has_clip("hit"):
		if PRIORITY["hit"] < PRIORITY[state]:
			return ""  # идёт замах: не прерываем
		boost = 1.0
		_enter("hit", clip_for("hit"))
		return clip
	_recoil_fx()
	return ""


func die() -> void:
	if state == "death":
		return
	moving = false
	goal = position
	boost = 1.0
	if has_clip("death"):
		_enter("death", clip_for("death"))
	else:
		state = "death"


func set_time_scale(value: float) -> void:
	time_scale = value
	if player != null:
		player.speed_scale = config.speed_for(state) * boost * time_scale


func _action(kind: String, clip_name: String, speed_boost: float) -> String:
	if state == "death":
		return ""
	var chosen := clip_name
	if chosen == "" or not player.has_animation(chosen):
		chosen = clip_for(kind)
	if chosen == "":
		return ""
	boost = maxf(speed_boost, 0.1)
	_enter(kind, chosen)
	return chosen


func _enter(new_state: String, new_clip: String) -> void:
	if player == null or new_clip == "":
		state = new_state
		return
	var looped := new_state == "idle" or new_state == "run"
	# Тот же зацикленный клип уже играет: не перезапускаем.
	if looped and new_state == state and new_clip == clip and player.is_playing():
		return
	if looped:
		boost = 1.0
	state = new_state
	clip = new_clip
	player.play(clip, config.blend_for(state))
	player.speed_scale = config.speed_for(state) * boost * time_scale
	play_counts[clip] = int(play_counts.get(clip, 0)) + 1
	state_changed.emit(state, clip)


func _prepare_loops() -> void:
	if player == null:
		return
	for key in ["idle", "run"]:
		var clip_name := clip_for(key)
		if clip_name != "":
			player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
	for key in ["attack", "skill", "hit", "death"]:
		var clip_name := clip_for(key)
		if clip_name != "":
			player.get_animation(clip_name).loop_mode = Animation.LOOP_NONE
	for extra in ["Left_Slash", "Charged_Slash", "Sword_Shout", "Skill_01"]:
		if player.has_animation(extra):
			player.get_animation(extra).loop_mode = Animation.LOOP_NONE
	if not player.animation_finished.is_connected(_on_finished):
		player.animation_finished.connect(_on_finished)


func _on_finished(_anim_name: StringName) -> void:
	if state == "death":
		return
	if state in ONE_SHOT:
		if moving or _grace > 0.0:
			_enter("run", clip_for("run"))
		else:
			_enter("idle", clip_for("idle"))


func _process(delta: float) -> void:
	if state == "death":
		return
	var step := delta * time_scale
	if moving:
		var flat := goal - position
		flat.y = 0.0
		if flat.length() <= 0.05:
			position = Vector3(goal.x, position.y, goal.z)
			moving = false
			_grace = STOP_GRACE
			arrived.emit()
		else:
			# Скольжение к точке идёт и во время замаха, анимацию бега включает только run.
			if state != "hit":
				position = position.move_toward(goal, step * pace)
			if flat.length() > 0.1:
				var heading := atan2(flat.x, flat.z)
				_aim = heading
				visual.rotation.y = lerp_angle(visual.rotation.y, heading, minf(1.0, step * config.turn_rate))
			return
	if _grace > 0.0:
		_grace -= step
		if _grace <= 0.0 and state == "run":
			_enter("idle", clip_for("idle"))
	visual.rotation.y = lerp_angle(visual.rotation.y, _aim, minf(1.0, step * config.turn_rate))


func _recoil_fx() -> void:
	if _recoil != null and _recoil.is_valid():
		_recoil.kill()
	var back := -Vector3(sin(_home_facing), 0, cos(_home_facing)) * 0.3
	_recoil = create_tween()
	_recoil.tween_property(visual, "position", back, 0.06)
	_recoil.tween_property(visual, "position", Vector3.ZERO, 0.14)


## Копирует недостающие клипы из другой модели (см. Heroes.RETARGET). Один раз на модель.
func _retarget() -> void:
	if not Heroes.RETARGET.has(model) or player == null:
		return
	for clip_name in Heroes.RETARGET[model]:
		var source_id: String = Heroes.RETARGET[model][clip_name]["from"]
		var key := "%s:%s" % [model, clip_name]
		if player.has_animation(clip_name):
			# Клип уже добавлен первым экземпляром этой модели: библиотека общая.
			if _retargeted.has(key):
				retargeted[clip_name] = "из %s.glb" % source_id
			continue
		if not _retargeted.has(key):
			var packed := load("res://assets/heroes/%s.glb" % source_id) as PackedScene
			if packed == null:
				continue
			var source := packed.instantiate() as Node3D
			var source_player := _find_player(source)
			var source_skeleton := source.find_child("Skeleton3D", true, false) as Skeleton3D
			var own_skeleton := visual.find_child("Skeleton3D", true, false) as Skeleton3D
			if source_player == null or not source_player.has_animation(clip_name) or source_skeleton == null or own_skeleton == null:
				source.free()
				continue
			var ratio := _hips_height(own_skeleton) / maxf(_hips_height(source_skeleton), 0.001)
			var copy := source_player.get_animation(clip_name).duplicate() as Animation
			for track in copy.get_track_count():
				if copy.track_get_type(track) != Animation.TYPE_POSITION_3D:
					continue
				for index in copy.track_get_key_count(track):
					var value: Vector3 = copy.track_get_key_value(track, index)
					copy.track_set_key_value(track, index, value * ratio)
			_retargeted[key] = copy
			source.free()
		if _retargeted.has(key):
			var library := player.get_animation_library(player.get_animation_library_list()[0])
			library.add_animation(clip_name, _retargeted[key].duplicate())
			retargeted[clip_name] = "из %s.glb" % source_id


func _hips_height(skeleton: Skeleton3D) -> float:
	for index in skeleton.get_bone_count():
		if str(skeleton.get_bone_name(index)).contains("Hips"):
			return skeleton.get_bone_rest(index).origin.y
	return 1.0


## Правка таза: в GLB скелет в сантиметрах, у клипов сдвиг корня и высоты.
## Анимации общие для экземпляров модели, поэтому один раз на модель.
func _plant_feet() -> void:
	if _planted.has(model) or player == null:
		return
	_planted[model] = true
	var skeleton := visual.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	var hips := -1
	for index in skeleton.get_bone_count():
		if str(skeleton.get_bone_name(index)).contains("Hips"):
			hips = index
	if hips < 0:
		return
	var rest: Vector3 = skeleton.get_bone_rest(hips).origin
	for lib_name in player.get_animation_library_list():
		var library := player.get_animation_library(lib_name)
		for anim_name in library.get_animation_list():
			var copy := library.get_animation(anim_name).duplicate() as Animation
			var changed := false
			for track in copy.get_track_count():
				if not str(copy.track_get_path(track)).contains("Hips") or copy.track_get_type(track) != Animation.TYPE_POSITION_3D:
					continue
				var keep_drop := str(anim_name) == "Dead"
				for key in copy.track_get_key_count(track):
					var value: Vector3 = copy.track_get_key_value(track, key)
					value.x = rest.x
					value.z = rest.z
					if not keep_drop:
						value.y = rest.y
					copy.track_set_key_value(track, key, value)
				changed = true
			if changed:
				library.remove_animation(anim_name)
				library.add_animation(anim_name, copy)


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null
