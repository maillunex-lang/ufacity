class_name HeroSprite
extends AnimatedSprite2D
## 2.5D hero played from a pre-rendered atlas (see tools/render_hero.sh).
## Node origin == the hero's feet (pivot baked in JSON). Team B: set `mirrored = true` (flip_h, pivot mirrored).

var meta: Dictionary = {}
var mirrored := false: set = _set_mirrored
var missing_roles: Array = []

static func load_meta(hero: String, dir := "res://assets/sprites") -> Dictionary:
	var txt := FileAccess.get_file_as_string("%s/%s/%s.json" % [dir, hero, hero])
	return JSON.parse_string(txt) if txt != "" else {}

func load_hero(hero: String, dir := "res://assets/sprites") -> bool:
	meta = load_meta(hero, dir)
	if meta.is_empty(): return false
	var pages: Array[Texture2D] = []
	for p in meta["pages"]:
		pages.append(load("%s/%s/%s" % [dir, hero, p["file"]]) as Texture2D)
	var cell := Vector2(meta["cell"][0], meta["cell"][1])
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for role in meta["clips"]:
		var c: Dictionary = meta["clips"][role]
		sf.add_animation(role)
		sf.set_animation_speed(role, float(c.get("fps", meta["fps"])))
		sf.set_animation_loop(role, bool(c["loop"]))
		for f in c["frames"]:
			var at := AtlasTexture.new()
			at.atlas = pages[int(f["page"])]
			var r: Array = f["rect"]; var mg: Array = f["margin"]
			at.region = Rect2(r[0], r[1], r[2], r[3])
			at.margin = Rect2(mg[0], mg[1], cell.x - r[2], cell.y - r[3])
			sf.add_frame(role, at)
	sprite_frames = sf
	missing_roles = meta.get("missing_roles", [])
	centered = false
	_apply_offset()
	return true

func has_role(role: String) -> bool:
	return sprite_frames != null and sprite_frames.has_animation(role)

## Real playback length of a clip in seconds (frames / fps) at speed 1.
func clip_seconds(role: String) -> float:
	return float(sprite_frames.get_frame_count(role)) / float(meta["clips"][role].get("fps", meta["fps"]))

func _set_mirrored(v: bool) -> void:
	mirrored = v; flip_h = v; _apply_offset()

func _apply_offset() -> void:
	if meta.is_empty(): return
	var piv := Vector2(meta["pivot"][0], meta["pivot"][1])
	var cellw: float = meta["cell"][0]
	offset = Vector2(-(cellw - piv.x) if mirrored else -piv.x, -piv.y)
