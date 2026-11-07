extends SceneTree
## godot --headless --path . -s tests/test_sprite_atlas.gd -- [hero ...]
## Checks every atlas: same cell/pivot for all frames, rects inside pages, no overlaps,
## duration == source length (<= 1 frame), loop flags, missing roles reported, SpriteFrames builds.
const ROLES := ["idle", "run", "attack", "hit", "skill", "death"]

func _init() -> void:
	var heroes: Array = Array(OS.get_cmdline_user_args())
	if heroes.is_empty(): heroes = ["swordsman"]
	var fails := 0
	for h in heroes:
		fails += _check(h)
	print("ATLAS_TEST failures=", fails)
	quit(1 if fails > 0 else 0)

func _check(hero: String) -> int:
	var f := 0
	var meta := HeroSprite.load_meta(hero)
	if meta.is_empty(): print("FAIL ", hero, ": no json"); return 1
	var cell: Array = meta["cell"]
	var pages: Array = meta["pages"]
	var boxes := []
	for r in ROLES:
		if not meta["clips"].has(r):
			if r in meta["missing_roles"]: print("  ", hero, " role '", r, "' missing in source (reported, not substituted)")
			else: print("FAIL ", hero, " role ", r, " absent and not reported"); f += 1
			continue
		var c: Dictionary = meta["clips"][r]
		var n: int = c["frames"].size()
		var dur: float = float(n) / float(c["fps"])
		if absf(dur - float(c["length"])) > 1.0 / float(meta["fps"]):
			print("FAIL ", hero, " ", r, " duration ", dur, " vs ", c["length"]); f += 1
		if r in ["idle", "run"] and not c["loop"]: print("FAIL ", r, " must loop"); f += 1
		if r in ["attack", "hit", "skill", "death"] and c["loop"]: print("FAIL ", r, " must not loop"); f += 1
		for fr in c["frames"]:
			var rc: Array = fr["rect"]; var mg: Array = fr["margin"]
			var psz: Array = pages[int(fr["page"])]["size"]
			if rc[0] < 0 or rc[1] < 0 or rc[0] + rc[2] > psz[0] or rc[1] + rc[3] > psz[1]: print("FAIL rect outside page"); f += 1
			if mg[0] + rc[2] > cell[0] or mg[1] + rc[3] > cell[1] or mg[0] < 1 or mg[1] < 1: print("FAIL ", r, " frame touches/exceeds cell"); f += 1
			boxes.append([int(fr["page"]), Rect2i(rc[0], rc[1], rc[2], rc[3])])
		print("  ", hero, " ", r, ": ", n, " frames, ", snappedf(dur, 0.01), " s (src ", snappedf(float(c["length"]), 0.01), ") fps ", snappedf(float(c["fps"]), 0.01))
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			if boxes[i][0] == boxes[j][0] and boxes[i][1].intersects(boxes[j][1]): f += 1
	var hs := HeroSprite.new()
	if not hs.load_hero(hero): print("FAIL build SpriteFrames"); f += 1
	else:
		for r in meta["clips"]:
			if hs.sprite_frames.get_frame_count(r) != meta["clips"][r]["frames"].size(): f += 1; print("FAIL frame count ", r)
		var t: Texture2D = hs.sprite_frames.get_frame_texture("idle", 0)
		if t.get_size() != Vector2(cell[0], cell[1]): print("FAIL frame texture size ", t.get_size()); f += 1
	print(hero, ": ", "OK" if f == 0 else "%d failure(s)" % f)
	return f
