extends SceneTree
# Headless audit of hero GLBs: godot --headless --path . -s tests/audit_assets.gd
const HEROES := ["priest", "swordsman", "uraldar"]

func _init() -> void:
	var failed := false
	for id in HEROES:
		var ps: PackedScene = load("res://heroes/%s.glb" % id)
		if ps == null:
			print("FAIL load ", id); failed = true; continue
		var root: Node3D = ps.instantiate()
		get_root().add_child(root)
		var sk: Skeleton3D = _find(root, "Skeleton3D")
		var ap: AnimationPlayer = _find(root, "AnimationPlayer")
		var mi: MeshInstance3D = _find(root, "MeshInstance3D")
		print("== ", id, " root_scale=", root.scale, " bones=", sk.get_bone_count())
		var aabb: AABB = mi.get_aabb()
		print("  world AABB pos=", aabb.position, " size=", aabb.size, " height=", snappedf(aabb.size.y, 0.01))
		var names := []
		for i in sk.get_bone_count(): names.append(sk.get_bone_name(i))
		print("  bones: ", names)
		var hips := _bone(sk, "Hips")
		var rest := sk.get_bone_global_rest(hips).origin
		print("  hips rest origin=", rest)
		# forward: mesh +Z or -Z? compare nose-side proxy using Head vs Hips is useless; use hand/foot symmetry via LeftToeBase vs LeftFoot
		var foot := _bone(sk, "LeftFoot"); var toe := _bone(sk, "LeftToeBase")
		if foot >= 0 and toe >= 0:
			var d := sk.get_bone_global_rest(toe).origin - sk.get_bone_global_rest(foot).origin
			print("  foot->toe dir (skeleton space) = ", d.normalized(), " (toes point to forward)")
		for a in ap.get_animation_list():
			var anim := ap.get_animation(a)
			var tr := -1
			for i in anim.get_track_count():
				if anim.track_get_type(i) == Animation.TYPE_POSITION_3D and str(anim.track_get_path(i)).ends_with("Hips"):
					tr = i
			var drift := Vector3.ZERO
			var yrange := Vector2(1e9, -1e9)
			if tr >= 0:
				var n := anim.track_get_key_count(tr)
				var p0: Vector3 = anim.track_get_key_value(tr, 0)
				var p1: Vector3 = anim.track_get_key_value(tr, n - 1)
				drift = p1 - p0
				for k in n:
					var v: Vector3 = anim.track_get_key_value(tr, k)
					yrange.x = minf(yrange.x, v.y); yrange.y = maxf(yrange.y, v.y)
			print("  clip %-26s len=%.2f loop=%d tracks=%d hips_drift=%s hips_y=[%.2f..%.2f]" % [a, anim.length, anim.loop_mode, anim.get_track_count(), drift, yrange.x, yrange.y])
		root.queue_free()
	quit(1 if failed else 0)

func _bone(sk: Skeleton3D, suffix: String) -> int:
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).ends_with(suffix): return i
	return -1

func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls): return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r: return r
	return null
