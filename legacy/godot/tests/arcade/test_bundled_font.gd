extends SceneTree
## Self-contained font/coverage proof. No game saves, Mac app, or system fonts are changed.
const FONT_PATH := "res://assets/fonts/NotoSansSC-Regular.ttf"
const Catalog = preload("res://scripts/arcade/fish_catalog.gd")
const Frontdoor = preload("res://scripts/arcade/frontdoor_ui.gd")
var checks := 0
var failures := 0
var required: Dictionary = {}
var missing: Array[String] = []
var layout_warnings: Array[String] = []
var font: FontFile

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func add_text(text: String) -> void:
	for i in text.length():
		var code := text.unicode_at(i)
		if code >= 32: required[code] = true

func collect_sources(path: String) -> void:
	for file in DirAccess.get_files_at(path):
		if file.ends_with(".gd") or file.ends_with(".tscn"):
			add_text(FileAccess.get_file_as_string(path.path_join(file)))
	for directory in DirAccess.get_directories_at(path):
		collect_sources(path.path_join(directory))

func run() -> void:
	font = load(FONT_PATH) as FontFile
	check(font != null, "Godot imports the bundled TrueType as a FontFile")
	if not font:
		quit(1)
		return
	check(not font.allow_system_fallback, "import settings disable system fallback")
	font.allow_system_fallback = false
	font.fallbacks = []
	check(font.data.size() > 1000000, "font contains actual bytes")
	check(font.get_font_name().contains("Noto"), "font family is Noto")
	collect_sources("res://scripts")
	collect_sources("res://scenes")
	for code in range(32, 127): required[code] = true
	for code in required:
		if not font.has_char(code) or font.get_glyph_index(18, code, 0) == 0:
			missing.append("U+%04X %s" % [code, String.chr(code)])
	check(missing.is_empty(), "all source/scene text and printable ASCII map to real bundled glyphs: " + ", ".join(missing))
	check(Catalog.active_species().size() == 20, "catalog still contains 20 active species")
	for fish in Catalog.active_species():
		for name_key in ["name_en", "name_zh", "scientific_name"]:
			var value: String = fish[name_key]
			for i in value.length():
				check(font.get_glyph_index(18, value.unicode_at(i), 0) != 0, "fish glyph exists: " + value.substr(i, 1))
			check(font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x > 0, "fish name shapes: " + value)
	var metrics: Array = []
	for size in [10, 12, 14, 16, 18, 20, 24, 28]:
		metrics.append({"size": size, "ascent": font.get_ascent(size), "descent": font.get_descent(size), "height": font.get_height(size), "chinese_cell_width": font.get_string_size("鱼", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x})
	var ui = Frontdoor.new()
	root.add_child(ui)
	ui.setup(font)
	for language in ["en", "zh"]:
		ui.set_language(language)
		for page in ["title", "pause", "settings", "credits", "confirm_new", "opening"]:
			match page:
				"confirm_new": ui._confirm_new_day()
				"opening":
					ui._start()
					ui.set_process(false)
				_: ui.call("show_" + page)
			await process_frame
			audit_labels(ui._content, language + "/" + page)
	ui.queue_free()
	await process_frame
	make_raster_proof()
	var report := {"font": FONT_PATH, "family": font.get_font_name(), "style": font.get_font_style_name(), "bytes": font.data.size(), "system_fallback": font.allow_system_fallback, "supported_character_count": font.get_supported_chars().length(), "required_character_count": required.size(), "missing": missing, "active_fish_species": 20, "metrics": metrics, "layout_warnings": layout_warnings, "checks": checks, "failures": failures}
	var report_file := FileAccess.open("res://assets/fonts/source/godot-validation.json", FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "\t") + "\n")
	print(JSON.stringify(report))
	print("BUNDLED FONT: ", checks, " checks, ", failures, " failures; ", required.size(), " required characters, ", missing.size(), " missing; ", layout_warnings.size(), " layout warnings")
	quit(1 if failures else 0)

func audit_labels(node: Node, context: String) -> void:
	if node is Label or node is Button:
		for i in node.text.length():
			if node.text.unicode_at(i) >= 32:
				check(font.get_glyph_index(18, node.text.unicode_at(i), 0) != 0, context + " live text glyph: " + node.text.substr(i, 1))
		var size: int = node.get_theme_font_size("font_size")
		if node is Button or node.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var available: float = node.size.x
			if node is Button:
				var style: StyleBox = node.get_theme_stylebox("normal")
				available -= style.get_content_margin(SIDE_LEFT) + style.get_content_margin(SIDE_RIGHT)
			for line in node.text.split("\n"):
				var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				if width > available + 1:
					layout_warnings.append("%s width %.1f/%.1f: %s" % [context, width, available, line])
		if not node.get_parent() is ScrollContainer:
			var height: float = font.get_height(size) * node.text.split("\n").size()
			if height > node.size.y + 1:
				layout_warnings.append("%s height %.1f/%.1f: %s" % [context, height, node.size.y, node.text])
	for child in node.get_children(): audit_labels(child, context)

func make_raster_proof() -> void:
	# FontFile uses Godot's FreeType rasterizer even with the headless display.
	# Composite those actual glyph bitmaps into an audit image, not a game screenshot.
	var proof := Image.create(900, 1050, false, Image.FORMAT_RGBA8)
	proof.fill(Color("fff3d8"))
	raster_line(proof, "ONE LAST CAST / 最后一竿", Vector2i(25, 48), 30)
	raster_line(proof, "English / 中文 · 鱼册 · 设置 · 音乐", Vector2i(25, 90), 22)
	raster_line(proof, "Tap to dive. Tap again when rings meet.", Vector2i(25, 128), 22)
	raster_line(proof, "看鱼的位置点一下，大圆合上再点一下。", Vector2i(25, 165), 22)
	var row := 0
	for fish in Catalog.active_species():
		var baseline := 210 + row * 37
		raster_line(proof, fish.name_en, Vector2i(25, baseline), 21)
		raster_line(proof, fish.name_zh, Vector2i(420, baseline), 21)
		row += 1
	raster_line(proof, "0123456789  + - / %  × ± … ‘ ’ “ ” ① ② ③", Vector2i(25, 985), 22)
	var result := proof.save_png("res://assets/fonts/source/godot-font-raster-proof.png")
	check(result == OK, "actual Godot FreeType raster proof saved")

func raster_line(image: Image, text: String, baseline: Vector2i, size: int) -> void:
	var pen := Vector2(baseline)
	for i in text.length():
		var glyph := font.get_glyph_index(size, text.unicode_at(i), 0)
		font.render_glyph(0, Vector2i(size, 0), glyph)
		var texture_index := font.get_glyph_texture_idx(0, Vector2i(size, 0), glyph)
		if texture_index >= 0:
			var atlas := font.get_texture_image(0, Vector2i(size, 0), texture_index)
			var uv := Rect2i(font.get_glyph_uv_rect(0, Vector2i(size, 0), glyph))
			if atlas and uv.has_area():
				var ink := atlas.get_region(uv)
				ink.convert(Image.FORMAT_RGBA8)
				for y in ink.get_height():
					for x in ink.get_width():
						var color := Color("173f4a")
						color.a = ink.get_pixel(x, y).a
						ink.set_pixel(x, y, color)
				image.blend_rect(ink, Rect2i(Vector2i.ZERO, ink.get_size()), Vector2i(pen + font.get_glyph_offset(0, Vector2i(size, 0), glyph)))
		pen.x += font.get_glyph_advance(0, size, glyph).x
