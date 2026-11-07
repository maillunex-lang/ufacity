extends Node3D
## Battle V2. Этап C: камера, расстановка, герои с анимациями и перемещением.
## Бой пока не проигрывается (этап D). Для проверки есть сценарий --demo:
## все бегут к центру, бьют, применяют навыки, получают урон и умирают.

const Hero = preload("res://battle_v2/v2_hero.gd")
const Heroes = preload("res://battle_v2/v2_heroes.gd")
const Layout = preload("res://battle_v2/v2_layout.gd")
const Adapter = preload("res://battle_v2/v2_sim_adapter.gd")
const AnimConfig = preload("res://battle_v2/v2_anim_config.gd")
const Playback = preload("res://battle_v2/v2_playback.gd")

## Доли высоты экрана, которые займёт будущий HUD (таймер сверху, карточки снизу).
const HUD_TOP := 0.12
const HUD_BOTTOM := 0.20
## Ширина тела героя для проверки перекрытий, метры. Грубая оценка, не AABB T-позы.
const BODY_WIDTH := 1.4

@export var squad: Array[String] = ["temp_a", "uraldar", "temp_b", "temp_a", "temp_b"]
@export_range(1, 20) var stage := 3
@export var show_hud_zones := true
@export var anim_config: Resource

var _camera: Camera3D
var _heroes := {}
var _shot_path := ""
var _shot_at := -1.0
var _check := false
var _demo := false
var _battle := false
var _fight: Dictionary = {}
var _playback: Node
var _impacts: Array = []
var _result := {}
var _speed := 1.0
var _frames := 0
var _elapsed := 0.0
var _shot_taken := false
var _events: Array = []
var _problems := 0


func _ready() -> void:
	if anim_config == null:
		anim_config = AnimConfig.new()
	_camera = $Camera3D
	_parse_args()
	_build_stage()
	var fight := Adapter.fight(squad, stage)
	_fight = fight
	for unit in fight["units"]:
		_spawn(str(unit["id"]), str(unit.get("model", "priest")))
	_build_hud()
	if _demo:
		_run_demo()
	elif _battle:
		_start_battle()
	elif _check:
		await get_tree().process_frame
		_check_layout()
		_finish()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.substr(7)
		elif arg.begins_with("--at="):
			_shot_at = float(arg.substr(5))
		elif arg.begins_with("--pitch="):
			_camera.angle = float(arg.substr(8))
		elif arg.begins_with("--yaw="):
			_camera.yaw = float(arg.substr(6))
		elif arg.begins_with("--zoom="):
			_camera.zoom_width = float(arg.substr(7))
		elif arg.begins_with("--stage="):
			stage = int(arg.substr(8))
		elif arg == "--check":
			_check = true
		elif arg == "--demo":
			_demo = true
		elif arg == "--battle":
			_battle = true
		elif arg.begins_with("--speed="):
			_speed = float(arg.substr(8))
		elif arg == "--nohud":
			show_hud_zones = false


func _process(delta: float) -> void:
	_frames += 1
	_elapsed += delta
	if _shot_path == "" or _shot_taken:
		return
	var due := _frames >= 4 if _shot_at < 0.0 else _elapsed >= _shot_at
	if due:
		_shot_taken = true
		_take_shot()


func _build_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1b2326")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a9b6bd")
	env.ambient_light_energy = 0.8
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var disc := MeshInstance3D.new()
	var circle := CylinderMesh.new()
	circle.top_radius = 12.2
	circle.bottom_radius = 12.2
	circle.height = 0.28
	circle.radial_segments = 64
	disc.mesh = circle
	disc.position = Vector3(0, -0.14, 0)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("6e675c")
	disc.material_override = stone
	add_child(disc)
	for slot in 5:
		_mark("L%d" % slot)
		_mark("R%d" % slot)


func _mark(unit_id: String) -> void:
	var front := Layout.is_front(unit_id)
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.72 if front else 0.55
	mesh.bottom_radius = mesh.top_radius
	mesh.height = 0.05
	mesh.radial_segments = 24
	disc.mesh = mesh
	disc.position = Layout.home(unit_id) + Vector3(0, 0.04, 0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if unit_id.begins_with("L"):
		material.albedo_color = Color("2f6b45") if front else Color("1d4034")
	else:
		material.albedo_color = Color("8a4036") if front else Color("5a302c")
	disc.material_override = material
	add_child(disc)


func _spawn(unit_id: String, model: String) -> void:
	var hero := Hero.new()
	hero.position = Layout.home(unit_id)
	add_child(hero)
	if not hero.setup(unit_id, model, anim_config):
		push_error("Герой %s не собран" % unit_id)
	hero.state_changed.connect(_on_state.bind(hero))
	_heroes[unit_id] = hero


func _on_state(state: String, clip: String, hero: Node3D) -> void:
	var speed := 0.0
	if hero.player != null:
		speed = hero.player.speed_scale
	_events.append({"t": _elapsed, "id": hero.unit_id, "state": state, "clip": clip, "speed": speed})


func _build_hud() -> void:
	if not show_hud_zones:
		return
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := ColorRect.new()
	top.color = Color(0.1, 0.3, 0.6, 0.28)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.anchor_bottom = HUD_TOP
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(top)
	var bottom := ColorRect.new()
	bottom.color = Color(0.1, 0.3, 0.6, 0.28)
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.anchor_top = 1.0 - HUD_BOTTOM
	bottom.anchor_bottom = 1.0
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bottom)
	var label := Label.new()
	label.text = "pitch %.0f°  yaw %.0f°  zoom %.0f" % [_camera.angle, _camera.yaw, _camera.zoom_width]
	label.position = Vector2(12, 12)
	label.add_theme_font_size_override("font_size", 22)
	layer.add_child(label)


# ---------------------------------------------------------------- сценарий проверки

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _run_demo() -> void:
	await _wait(0.4)
	# 1. Бег к центру: каждый на 3 м вперёд по своему направлению.
	var pending := {"n": _heroes.size()}
	var goals := {}
	for id in _heroes:
		var hero: Node3D = _heroes[id]
		var target: Vector3 = Layout.home(id) + Layout.facing(id) * 3.0
		goals[id] = target
		hero.arrived.connect(func() -> void: pending["n"] -= 1, CONNECT_ONE_SHOT)
		hero.run_to(target)
	var waited := 0.0
	while int(pending["n"]) > 0 and waited < 8.0:
		await _wait(0.1)
		waited += 0.1
	var arrived_at := _elapsed
	await _wait(0.4)
	# 2. Атаки игроков, у Уралдара другой вариант удара.
	for id in _heroes:
		if str(id).begins_with("L"):
			var hero2: Node3D = _heroes[id]
			hero2.attack("Left_Slash" if hero2.model == "uraldar" else "")
	await _wait(0.8)
	# 3. Реакции на урон: у врагов и у swordsman (клипа hit нет, отдача кодом).
	for id in _heroes:
		var hero3: Node3D = _heroes[id]
		if str(id).begins_with("R") or hero3.model == "swordsman":
			hero3.hit()
	await _wait(1.6)
	# 4. Навыки.
	_heroes["L1"].skill("Skill_01")
	_heroes["R2"].skill()
	await _wait(1.4)
	# 5. Смерть трёх героев.
	for id in ["R0", "R1", "L3"]:
		_heroes[id].die()
	await _wait(3.4)
	if _check:
		_check_demo(goals, arrived_at, waited)
		_finish()


func _check_demo(goals: Dictionary, arrived_at: float, waited: float) -> void:
	print("CHECK demo arrived_after=%.1fs (ждали %.1f)" % [arrived_at, waited])
	var dead := ["R0", "R1", "L3"]
	for id in _heroes:
		var hero: Node3D = _heroes[id]
		var errors: Array = []
		var goal: Vector3 = goals[id]
		var flat := Vector2(hero.position.x - goal.x, hero.position.z - goal.z).length()
		if flat > 0.1:
			errors.append("не дошёл, %.2f м" % flat)
		var run_clip: String = hero.clip_for("run")
		if int(hero.play_counts.get(run_clip, 0)) != 1:
			errors.append("бег перезапускался: %d раз" % int(hero.play_counts.get(run_clip, 0)))
		if id in dead:
			if hero.state != "death" or hero.player.assigned_animation != "Dead" or hero.player.is_playing():
				errors.append("смерть не удержана: state=%s anim=%s playing=%s" % [hero.state, hero.player.assigned_animation, hero.player.is_playing()])
		elif hero.state != "idle" or hero.clip != hero.clip_for("idle"):
			errors.append("не вернулся в idle: state=%s clip=%s" % [hero.state, hero.clip])
		print("CHECK %s %s plays=%s missing=%s %s" % [id, hero.model, hero.play_counts, hero.missing.keys(), "OK" if errors.is_empty() else str(errors)])
		_problems += errors.size()
	# Скорости: в момент входа в клип speed_scale должен быть равен настройке.
	var wrong := 0
	for event in _events:
		var want: float = anim_config.speed_for(event["state"])
		if absf(float(event["speed"]) - want) > 0.001:
			wrong += 1
			print("CHECK скорость %s %s: %.2f ожидалось %.2f" % [event["id"], event["state"], event["speed"], want])
	print("CHECK speed_events=%d wrong=%d" % [_events.size(), wrong])
	_problems += wrong
	var seen := {}
	for event in _events:
		seen[event["state"]] = true
	print("CHECK states_seen=", seen.keys())
	for need in ["idle", "run", "attack", "skill", "hit", "death"]:
		if not seen.has(need):
			print("CHECK состояние не встретилось: ", need)
			_problems += 1


# ---------------------------------------------------------------- бой

func _start_battle() -> void:
	if _check and _speed > 1.0:
		Engine.time_scale = _speed
	_playback = Playback.new()
	add_child(_playback)
	_playback.setup(_heroes, _fight, anim_config)
	_playback.impact.connect(_on_impact)
	_playback.finished.connect(_on_finished)


func _on_impact(src_id: String, dst_id: String, amount: int, hp: int, kind: String) -> void:
	var src: Node3D = _heroes.get(src_id)
	var dev := INF
	var clip := ""
	if src != null and src.player != null and src.state in ["attack", "skill"] and src.config.hit_time.has(src.clip):
		clip = src.clip
		var want := float(src.config.hit_time[clip])
		var speed := float(src.config.speed_for(src.state)) * float(src.boost)
		dev = (src.player.current_animation_position - want) / speed
	_impacts.append({"src": src_id, "dst": dst_id, "amount": amount, "kind": kind, "dev": dev, "clip": clip})


func _on_finished(winner: String, reason: String) -> void:
	_result = {"winner": winner, "reason": reason}
	if _check:
		await _wait(1.0)
		Engine.time_scale = 1.0
		_check_battle()
		_finish()


func _check_battle() -> void:
	var sim_winner := str(_fight["winner"])
	var errors := 0
	print("CHECK battle stage=%d speed=x%.0f winner_view=%s winner_sim=%s reason=%s sim_duration=%.1f" % [stage, _speed, _result.get("winner"), sim_winner, _result.get("reason"), float(_fight["duration"])])
	if str(_result.get("winner")) != sim_winner:
		errors += 1
	# HP и смерти совпадают с расчётом боя.
	var hp_bad := 0
	var dead_bad := 0
	var dead := 0
	for unit in _fight["units"]:
		var id := str(unit["id"])
		if int(_playback.hp[id]) != int(unit["hp"]):
			hp_bad += 1
			print("CHECK hp %s view=%d sim=%d" % [id, _playback.hp[id], unit["hp"]])
		if int(unit["hp"]) <= 0:
			dead += 1
			var hero: Node3D = _heroes[id]
			if hero.state != "death" or hero.player.assigned_animation != "Dead":
				dead_bad += 1
		else:
			var alive: Node3D = _heroes[id]
			if alive.state == "death":
				dead_bad += 1
	print("CHECK hp_mismatch=%d dead=%d dead_wrong=%d" % [hp_bad, dead, dead_bad])
	errors += hp_bad + dead_bad
	# Удар совпадает с событием: клип стоит в кадре попадания.
	var measured := 0
	var worst := 0.0
	var sum := 0.0
	var off_clip := 0
	var out_of_tol := 0
	for impact in _impacts:
		if impact["kind"] == "heal" and impact["clip"] == "":
			continue
		if not is_finite(impact["dev"]):
			off_clip += 1
			continue
		measured += 1
		worst = maxf(worst, absf(impact["dev"]))
		sum += absf(impact["dev"])
		if absf(impact["dev"]) > 0.12:
			out_of_tol += 1
	print("CHECK impacts=%d on_own_clip=%d off_clip=%d mean_dev=%.3fs max_dev=%.3fs out_of_0.12s=%d" % [_impacts.size(), measured, off_clip, sum / maxf(measured, 1), worst, out_of_tol])
	print("CHECK schedule ", _playback.stats)
	for late in _playback.late_list.slice(0, 5):
		print("CHECK late ", late)
	# Перемещения: герои у своих последних целей, бег не моргает.
	var flicker := 0
	var last := {}
	for event in _events:
		if event["state"] != "idle" and event["state"] != "run":
			continue
		var key := str(event["id"])
		if last.has(key) and float(event["t"]) - float(last[key]["t"]) < 0.15 and event["state"] != last[key]["state"]:
			flicker += 1
		last[key] = event
	print("CHECK run_idle_flicker=%d state_events=%d" % [flicker, _events.size()])
	var hits_clip := {}
	for id in _heroes:
		var hero2: Node3D = _heroes[id]
		print("CHECK %s %s plays=%s retargeted=%s missing=%s" % [id, hero2.model, hero2.play_counts, hero2.retargeted, hero2.missing.keys()])
	errors += out_of_tol + flicker
	_problems += errors


# ---------------------------------------------------------------- проверка расстановки

## Прямоугольник героя на экране: от ног до макушки, ширина BODY_WIDTH.
func _screen_rect(unit_id: String) -> Rect2:
	var hero: Node3D = _heroes[unit_id]
	var half := _camera.global_transform.basis.x * (BODY_WIDTH * 0.5)
	var feet := hero.global_position
	var head := feet + Vector3(0, Heroes.SCREEN_HEIGHT, 0)
	var points := [feet - half, feet + half, head - half, head + half]
	var rect := Rect2(_camera.unproject_position(points[0]), Vector2.ZERO)
	for point in points:
		rect = rect.expand(_camera.unproject_position(point))
	return rect


func _check_layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var top := view.y * HUD_TOP
	var bottom := view.y * (1.0 - HUD_BOTTOM)
	var ids: Array = _heroes.keys()
	ids.sort()
	print("CHECK viewport=%dx%d pitch=%.1f yaw=%.1f heroes=%d" % [view.x, view.y, _camera.angle, _camera.yaw, ids.size()])
	for id in ids:
		var hero: Node3D = _heroes[id]
		var rect := _screen_rect(id)
		var inside := rect.position.x >= 0.0 and rect.end.x <= view.x and rect.position.y >= top and rect.end.y <= bottom
		var visual: Node3D = hero.visual
		var forward: Vector3 = visual.global_transform.basis.z
		var faces: bool = forward.z > 0.5 if str(id).begins_with("L") else forward.z < -0.5
		var playing: bool = hero.player != null and hero.player.is_playing()
		print("CHECK %s %s in_frame=%s faces_enemy=%s idle_playing=%s" % [id, hero.model, inside, faces, playing])
		if not inside or not faces or not playing:
			_problems += 1
	var worst := 0.0
	var worst_pair := ""
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a := _screen_rect(ids[i])
			var b := _screen_rect(ids[j])
			var overlap := a.intersection(b)
			if overlap.size.x <= 0.0 or overlap.size.y <= 0.0:
				continue
			var share := overlap.get_area() / minf(a.get_area(), b.get_area())
			if share > worst:
				worst = share
				worst_pair = "%s/%s" % [ids[i], ids[j]]
	print("CHECK worst_overlap=%.0f%% pair=%s" % [worst * 100.0, worst_pair])


func _finish() -> void:
	print("CHECK problems=", _problems)
	get_tree().quit(1 if _problems > 0 else 0)


func _take_shot() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(_shot_path)
	print("SHOT ", _shot_path, " err=", err, " size=", image.get_size())
	get_tree().quit()
