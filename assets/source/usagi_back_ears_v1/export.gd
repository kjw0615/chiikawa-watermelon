extends SceneTree
## Mechanical resizing only. Artwork edits were made with built-in image_gen.
func _initialize() -> void:
	var root_path := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var jobs := [
		["assets/source/cave_items_v1/masters/item01_usagi_shake.png", "godot/assets/icons/items_v1/item01_usagi_shake.png", Vector2i(128, 128)],
		["assets/source/item_effects_v1/masters/usagi_shake.png", "godot/assets/effects/spritesheets/usagi_shake.png", Vector2i(768, 512)]
	]
	for job in jobs:
		var picture := Image.load_from_file(root_path.path_join(job[0]))
		if picture == null or picture.is_empty():
			push_error("Missing edited master: " + job[0])
			quit(1)
			return
		picture.convert(Image.FORMAT_RGBA8)
		var target: Vector2i = job[2]
		if absf(float(picture.get_width()) / picture.get_height() - float(target.x) / target.y) > 0.001:
			push_error("Unexpected aspect ratio: " + job[0])
			quit(1)
			return
		picture.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS)
		if picture.save_png(root_path.path_join(job[1])) != OK:
			quit(1)
			return
		print(job[1], " ", picture.get_size())
	var preview := Image.create(800, 680, false, Image.FORMAT_RGBA8)
	preview.fill(Color("fff8eb"))
	var icon := Image.load_from_file(root_path.path_join(jobs[0][1]))
	var sheet := Image.load_from_file(root_path.path_join(jobs[1][1]))
	icon.convert(Image.FORMAT_RGBA8)
	sheet.convert(Image.FORMAT_RGBA8)
	preview.blend_rect(icon, Rect2i(0, 0, 128, 128), Vector2i(336, 8))
	preview.blend_rect(sheet, Rect2i(0, 0, 768, 512), Vector2i(16, 152))
	preview.save_png(root_path.path_join("assets/source/usagi_back_ears_v1/review.png"))
	quit()
