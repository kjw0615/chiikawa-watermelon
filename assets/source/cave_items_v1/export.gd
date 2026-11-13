extends SceneTree
## Offline PNG export only; not part of the game scene or runtime.

func _initialize() -> void:
	var root_path := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var jobs := [
		["cave_background", "godot/assets/maps/cave_v1/background.png", false],
		["cave_foreground", "godot/assets/maps/cave_v1/foreground.png", false],
		["item01_usagi_shake", "godot/assets/icons/items_v1/item01_usagi_shake.png", true],
		["item02_bazaar_ticket", "godot/assets/icons/items_v1/item02_bazaar_ticket.png", true],
		["item03_rakko_sword", "godot/assets/icons/items_v1/item03_rakko_sword.png", true],
		["item05_food_fountain", "godot/assets/icons/items_v1/item05_food_fountain.png", true]
	]
	for job in jobs:
		var source := root_path.path_join("assets/source/cave_items_v1/masters/%s.png" % job[0])
		var picture := Image.load_from_file(source)
		if picture == null or picture.is_empty():
			push_error("Missing source: " + source)
			quit(1)
			return
		picture.convert(Image.FORMAT_RGBA8)
		if job[2]:
			var factor := minf(128.0 / picture.get_width(), 128.0 / picture.get_height())
			var fit := Vector2i(maxi(1, roundi(picture.get_width() * factor)), maxi(1, roundi(picture.get_height() * factor)))
			picture.resize(fit.x, fit.y, Image.INTERPOLATE_LANCZOS)
			var square := Image.create(128, 128, false, Image.FORMAT_RGBA8)
			square.fill(Color.TRANSPARENT)
			square.blit_rect(picture, Rect2i(Vector2i.ZERO, fit), Vector2i((128 - fit.x) / 2, (128 - fit.y) / 2))
			picture = square
		elif picture.get_size() != Vector2i(1024, 1536):
			push_error("Map canvas must stay aligned at 1024x1536: " + source)
			quit(1)
			return
		var destination := root_path.path_join(job[1])
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		var error := picture.save_png(destination)
		if error != OK:
			push_error("PNG export failed: " + destination)
			quit(1)
			return
		print(job[0], " => ", picture.get_size(), " ", destination)
	var background := Image.load_from_file(root_path.path_join("godot/assets/maps/cave_v1/background.png"))
	var foreground := Image.load_from_file(root_path.path_join("godot/assets/maps/cave_v1/foreground.png"))
	background.convert(Image.FORMAT_RGBA8)
	foreground.convert(Image.FORMAT_RGBA8)
	background.blend_rect(foreground, Rect2i(Vector2i.ZERO, foreground.get_size()), Vector2i.ZERO)
	background.save_png(root_path.path_join("assets/source/cave_items_v1/composite_preview.png"))
	quit()
