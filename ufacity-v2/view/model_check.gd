extends Node3D
## Stage B model check: lines up all heroes and plays every mapped role clip.
## Headless: godot --headless --path . scenes/model_check.tscn -- --quit-after
const ROLES := ["idle", "run", "attack", "hit", "skill", "death"]
const GAP := 1.6

var report: Array[String] = []
var failures := 0

func _ready() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/hero_assets.json"))
	var players := {}
	var x := 0.0
	for id in manifest:
		if id.begins_with("_"): continue
		var m: Dictionary = manifest[id]
		var inst: Node3D = (load(m["glb"]) as PackedScene).instantiate()
		inst.name = id
		inst.position = Vector3(x, 0, 0)
		x += GAP
		add_child(inst)
		players[id] = _find(inst, "AnimationPlayer")
	for id in players:
		var ap: AnimationPlayer = players[id]
		var m: Dictionary = manifest[id]
		var line := "%s:" % id
		for role in ROLES:
			var clip: String = m[role]
			var src: AnimationPlayer = ap
			if clip == "" and m.has("borrow") and m["borrow"].has(role):
				var parts: PackedStringArray = String(m["borrow"][role]).split("/")
				src = players[parts[0]]; clip = parts[1]
				var anim: Animation = _borrow(src.get_animation(clip))
				var lib: AnimationLibrary = ap.get_animation_library("")
				var nm: String = "borrowed_" + role
				if not lib.has_animation(nm): lib.add_animation(nm, anim)
				clip = nm
			if not ap.has_animation(clip):
				failures += 1; line += " [%s MISSING]" % role; continue
			ap.play(clip)
			ap.advance(0.2)
			line += " %s=%s(%.2fs)" % [role, clip, ap.get_animation(clip).length]
		report.append(line)
	for l in report: print(l)
	print("MODEL_CHECK failures=", failures)
	for id in players:
		(players[id] as AnimationPlayer).play(manifest[id]["idle"])
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if failures > 0 else 0)
	elif "--shot" in OS.get_cmdline_user_args():
		for i in 20: await get_tree().process_frame
		for id in players:
			var a: AnimationPlayer = players[id]
			var sk: Skeleton3D = _find(get_node(NodePath(id)), "Skeleton3D")
			var b := sk.find_bone("mixamorig_LeftArm")
			print(id, " playing=", a.is_playing(), " cur=", a.current_animation, " pos=", snappedf(a.current_animation_position, 0.01), " armrot=", sk.get_bone_pose_rotation(b), " rest=", sk.get_bone_rest(b).basis.get_rotation_quaternion())
		get_viewport().get_texture().get_image().save_png("user://model_check.png")
		get_tree().quit(1 if failures > 0 else 0)

## Copy an animation without Hips position tracks (no root motion, safe across body sizes).
func _borrow(a: Animation) -> Animation:
	var c := a.duplicate(true) as Animation
	for i in range(c.get_track_count() - 1, -1, -1):
		if c.track_get_type(i) == Animation.TYPE_POSITION_3D:
			c.remove_track(i)
	return c

func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls): return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r: return r
	return null
