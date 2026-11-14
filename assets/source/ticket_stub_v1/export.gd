extends SceneTree
## Mechanical resize only; ticket redraw was made using built-in image_gen.
func _initialize() -> void:
	var root_path := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var picture := Image.load_from_file(root_path.path_join("assets/source/item_effects_v1/masters/bazaar_ticket.png"))
	if picture == null or picture.is_empty() or absf(float(picture.get_width()) / picture.get_height() - 1.5) > 0.001:
		push_error("Missing or invalid 3:2 ticket master")
		quit(1)
		return
	picture.convert(Image.FORMAT_RGBA8)
	picture.resize(768, 512, Image.INTERPOLATE_LANCZOS)
	if picture.save_png(root_path.path_join("godot/assets/effects/spritesheets/bazaar_ticket.png")) != OK:
		quit(1)
		return
	var preview := Image.create(768, 512, false, Image.FORMAT_RGBA8)
	preview.fill(Color("fff8eb"))
	preview.blend_rect(picture, Rect2i(0, 0, 768, 512), Vector2i.ZERO)
	preview.save_png(root_path.path_join("assets/source/ticket_stub_v1/review.png"))
	print("Ticket atlas: 768x512, 3x2 cells, six 256x256 frames")
	quit()
