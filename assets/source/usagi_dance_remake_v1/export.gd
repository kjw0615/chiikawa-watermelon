extends SceneTree
## Mechanical rescale and preview composition only.
func _initialize() -> void:
	var root_path := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var master := Image.load_from_file(root_path.path_join("assets/source/item_effects_v1/masters/usagi_shake.png"))
	if master == null or master.is_empty() or absf(float(master.get_width()) / master.get_height() - 1.5) > 0.001:
		push_error("Expected 3:2 six-cell master")
		quit(1)
		return
	master.convert(Image.FORMAT_RGBA8)
	master.resize(768, 512, Image.INTERPOLATE_LANCZOS)
	if master.save_png(root_path.path_join("godot/assets/effects/spritesheets/usagi_shake.png")) != OK:
		quit(1)
		return
	var review := Image.create(768, 512, false, Image.FORMAT_RGBA8)
	review.fill(Color("fff8eb"))
	review.blend_rect(master, Rect2i(0, 0, 768, 512), Vector2i.ZERO)
	review.save_png(root_path.path_join("assets/source/usagi_dance_remake_v1/review.png"))
	print("Usagi remake exported: 768x512 RGBA, 6 frames, 256x256 cells")
	quit()
