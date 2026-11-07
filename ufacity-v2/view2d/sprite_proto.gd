extends Node2D
## Prototype: one hero, every role, two facing copies. Not the battle.
## godot --path . scenes/sprite_proto.tscn -- --hero=swordsman [--bg=arena|checker|magenta] [--shots=DIR]
const ORDER := ["idle", "run", "attack", "hit", "skill", "death"]
var a: HeroSprite
var b: HeroSprite
var label: Label
var args := {}

func _ready() -> void:
	args = _args()
	var hero: String = args.get("hero", "swordsman")
	var bg: String = args.get("bg", "arena")
	_build_bg(bg)
	a = HeroSprite.new(); b = HeroSprite.new()
	add_child(a); add_child(b)
	if not a.load_hero(hero) or not b.load_hero(hero):
		push_error("no atlas for " + hero); get_tree().quit(1); return
	a.position = Vector2(190, 760); b.position = Vector2(530, 760)
	b.mirrored = true                      # team B: same sprites, mirrored -> they face each other
	label = Label.new(); label.position = Vector2(20, 40); label.add_theme_font_size_override("font_size", 28)
	add_child(label)
	_play_all()

func _play_all() -> void:
	var shots: String = args.get("shots", "")
	if shots != "": DirAccess.make_dir_recursive_absolute(shots)
	var report: Array[String] = []
	for role in ORDER:
		if not a.has_role(role):
			label.text = "%s: MISSING (not substituted)" % role
			report.append("%s MISSING" % role)
			await get_tree().create_timer(0.8).timeout
			continue
		var secs := a.clip_seconds(role)
		a.play(role); b.play(role)
		label.text = "%s  %d frames @ %.2f fps = %.2f s (src %.2f s)" % [role, a.sprite_frames.get_frame_count(role), a.sprite_frames.get_animation_speed(role), secs, a.meta["clips"][role]["length"]]
		report.append(label.text)
		var shot_at := secs * 0.45
		if shots != "" and DisplayServer.get_name() != "headless":
			await get_tree().create_timer(shot_at).timeout
			get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, role])
			await get_tree().create_timer(maxf(secs - shot_at, 0.0) + 0.2).timeout
		else:
			await get_tree().create_timer(minf(secs, 2.0) + 0.2).timeout
	for l in report: print(l)
	get_tree().quit()

func _build_bg(kind: String) -> void:
	var cr := ColorRect.new(); cr.size = Vector2(720, 1280); add_child(cr)
	match kind:
		"magenta": cr.color = Color(1, 0, 1)
		"checker":
			cr.color = Color(0.8, 0.8, 0.8)
			for y in range(0, 1280, 40):
				for x in range(0, 720, 40):
					if ((x + y) / 40) % 2 == 0:
						var s := ColorRect.new(); s.color = Color(0.55, 0.55, 0.55); s.position = Vector2(x, y); s.size = Vector2(40, 40); add_child(s)
		_:
			cr.color = Color(0.55, 0.75, 0.95)
			var ground := ColorRect.new(); ground.color = Color(0.36, 0.6, 0.4); ground.position = Vector2(0, 690); ground.size = Vector2(720, 590); add_child(ground)

func _args() -> Dictionary:
	var d := {}
	for s in OS.get_cmdline_user_args():
		var kv := s.trim_prefix("--").split("=", true, 1)
		d[kv[0]] = kv[1] if kv.size() > 1 else true
	return d
