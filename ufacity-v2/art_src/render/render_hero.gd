extends Node
## GLB hero -> transparent PNG frames from ONE fixed camera -> trimmed, shelf-packed atlas pages + JSON.
## Run (from repo root): ufacity-v2/tools/render_hero.sh uraldar [--fps=30] [--yaw=25] [--pitch=18]
##
## Conventions (all baked into the JSON so the game never guesses):
##  * orthographic camera, PPM pixels per metre -> identical scale for every hero
##  * pivot = projection of the model origin (point between the feet) -> stays fixed in the cell
##  * hero faces screen-RIGHT, turned `yaw` degrees toward the camera (3/4 view). Team B is mirrored with flip_h in game.
##  * frame times t = i / fps; duration = frames / fps equals the source clip length

const ROLES := ["idle", "run", "attack", "hit", "skill", "death"]
const LOOPED := ["idle", "run"]
const KEEP_ROOT := ["death"]          # death keeps hips travel (body falls); everything else is rooted in place
const PAGE := 2048
const PAD := 2

var ppm := 128.0
var cell := 512
var pivot := Vector2(256, 400)
var fps := 30
var yaw := 25.0
var pitch := 18.0
var hero := ""
var out_dir := ""
var frames_dir := ""

func _ready() -> void:
	print("render_hero: start")
	var a := _args()
	hero = a.get("hero", "uraldar")
	fps = int(a.get("fps", 30)); yaw = float(a.get("yaw", 25)); pitch = float(a.get("pitch", 18))
	ppm = float(a.get("ppm", 128)); cell = int(a.get("cell", 512))
	pivot = Vector2(cell / 2.0, cell * 0.78)
	out_dir = a.get("out", "/tmp/v2_sprites/" + hero)
	frames_dir = a.get("frames", "/tmp/v2_frames/" + hero)
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.make_dir_recursive_absolute(frames_dir)
	var ok: bool = await _run()
	get_tree().quit(0 if ok else 1)

func _run() -> bool:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://hero_assets.json"))
	var m: Dictionary = manifest[hero]
	var vp := SubViewport.new()
	vp.size = Vector2i(cell, cell); vp.transparent_bg = true; vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X; vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 0.97, 0.92); env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new(); we.environment = env; vp.add_child(we)
	# three-point light: key (upper left-front, warm), fill (right, cool), rim (behind, separates the silhouette)
	for L in [[Vector3(-42, 38, 0), 1.05, Color(1, 0.96, 0.9)], [Vector3(-15, -70, 0), 0.35, Color(0.8, 0.9, 1.0)], [Vector3(-25, 165, 0), 0.6, Color(1, 1, 1)]]:
		var d := DirectionalLight3D.new()
		d.rotation_degrees = L[0]; d.light_energy = L[1]; d.light_color = L[2]
		vp.add_child(d)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = cell / ppm                                   # vertical extent in metres
	cam.near = 0.1; cam.far = 50.0
	vp.add_child(cam)
	var p := deg_to_rad(pitch)
	cam.position = Vector3(0, sin(p), cos(p)) * 10.0
	cam.look_at(Vector3.ZERO, Vector3.UP)
	cam.v_offset = (pivot.y - cell / 2.0) / ppm              # move origin down to the pivot row
	cam.h_offset = (pivot.x - cell / 2.0) / ppm
	var model: Node3D = (load(m["glb"]) as PackedScene).instantiate()
	model.rotation_degrees.y = 90.0 - yaw                    # +Z (GLB forward) -> screen right, 3/4 to camera
	vp.add_child(model)
	var ap := _find_player(model)
	ap.speed_scale = 0.0
	await RenderingServer.frame_post_draw
	var pv := cam.unproject_position(Vector3.ZERO)
	print("pivot check: unproject(origin)=", pv, " expected ", pivot)

	var all := []     # {role, idx, img, ox, oy}
	var clips := {}
	var clipped := 0
	var missing := []
	for role in ROLES:
		var clip: String = m[role]
		if clip == "" or not ap.has_animation(clip):
			push_warning("role %s has no clip, NOT substituted" % role); missing.append(role); continue
		var anim := ap.get_animation(clip).duplicate(true) as Animation
		if role not in KEEP_ROOT: _root_in_place(anim)
		var lib: AnimationLibrary = ap.get_animation_library("")
		var nm: String = "r_" + role
		if lib.has_animation(nm): lib.remove_animation(nm)
		lib.add_animation(nm, anim)
		var looped: bool = role in LOOPED
		var n := int(round(anim.length * fps)) + (0 if looped else 1)
		var denom := float(n) if looped else float(n - 1)   # loop: last==first so skip endpoint
		# effective fps makes frames/fps == source length exactly (duration preserved)
		clips[role] = {"src_clip": clip, "length": anim.length, "loop": looped, "fps": float(n) / anim.length, "frames": []}
		ap.play(nm); ap.speed_scale = 0.0
		for i in n:
			ap.seek(float(i) * anim.length / denom, true)
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.save_png("%s/%s_%03d.png" % [frames_dir, role, i])
			var r := img.get_used_rect()
			if r.size == Vector2i.ZERO: r = Rect2i(0, 0, 1, 1)
			if r.position.x <= 0 or r.position.y <= 0 or r.end.x >= cell or r.end.y >= cell: clipped += 1
			all.append({"role": role, "idx": i, "img": img.get_region(r), "ox": r.position.x, "oy": r.position.y})
		print("rendered ", role, " (", clip, ") ", n, " frames, len=", snappedf(anim.length, 0.01))
	if clipped > 0:
		push_error("%d frames touch the cell border: enlarge --cell or lower --ppm" % clipped)
	_pack(all, clips, m, missing)
	return clipped == 0

func _pack(all: Array, clips: Dictionary, m: Dictionary, missing: Array) -> void:
	# shelf packing, tallest first
	var order := all.duplicate()
	order.sort_custom(func(a, b): return a["img"].get_height() > b["img"].get_height())
	var pages: Array[Image] = []
	var page := Image.create(PAGE, PAGE, false, Image.FORMAT_RGBA8); pages.append(page)
	var x := PAD; var y := PAD; var shelf_h := 0
	var used_h := 0; var used_hs: Array[int] = []
	for f in order:
		var w: int = f["img"].get_width(); var h: int = f["img"].get_height()
		if x + w + PAD > PAGE:
			x = PAD; y += shelf_h + PAD; shelf_h = 0
		if y + h + PAD > PAGE:
			used_hs.append(y + shelf_h + PAD)
			page = Image.create(PAGE, PAGE, false, Image.FORMAT_RGBA8); pages.append(page)
			x = PAD; y = PAD; shelf_h = 0
		page.blit_rect(f["img"], Rect2i(0, 0, w, h), Vector2i(x, y))
		f["page"] = pages.size() - 1; f["rect"] = [x, y, w, h]
		x += w + PAD; shelf_h = maxi(shelf_h, h)
	used_hs.append(y + shelf_h + PAD)
	var files := []
	for i in pages.size():
		# crop page height to what is used, rounded to a multiple of 4 (texture compression blocks)
		var hh := (used_hs[i] + 3) / 4 * 4
		var pg := pages[i].get_region(Rect2i(0, 0, PAGE, mini(hh, PAGE)))
		var fn := "%s_%d.png" % [hero, i]
		pg.save_png(out_dir + "/" + fn)
		files.append({"file": fn, "size": [pg.get_width(), pg.get_height()]})
	for f in all:
		clips[f["role"]]["frames"].append({"i": f["idx"], "page": f["page"], "rect": f["rect"], "margin": [f["ox"], f["oy"]]})
	for role in clips: clips[role]["frames"].sort_custom(func(a, b): return a["i"] < b["i"])
	var meta := {"hero": hero, "fps": fps, "ppm": ppm, "cell": [cell, cell], "pivot": [pivot.x, pivot.y],
		"height_m": m["height"], "facing": "right", "yaw_deg": yaw, "pitch_deg": pitch, "pages": files, "missing_roles": missing, "clips": clips}
	var jf := FileAccess.open(out_dir + "/" + hero + ".json", FileAccess.WRITE)
	jf.store_string(JSON.stringify(meta, "\t")); jf.close()
	print("packed ", all.size(), " frames into ", pages.size(), " page(s) -> ", out_dir)

## Hips X/Z held at frame 0 so the character stays on its pivot; Y keeps the bob.
func _root_in_place(anim: Animation) -> void:
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and str(anim.track_get_path(t)).ends_with("Hips"):
			var k0: Vector3 = anim.track_get_key_value(t, 0)
			for k in anim.track_get_key_count(t):
				var v: Vector3 = anim.track_get_key_value(t, k)
				anim.track_set_key_value(t, k, Vector3(k0.x, v.y, k0.z))

func _find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer: return n
	for c in n.get_children():
		var r := _find_player(c)
		if r: return r
	return null

func _args() -> Dictionary:
	var d := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		d[kv[0]] = kv[1] if kv.size() > 1 else true
	return d
