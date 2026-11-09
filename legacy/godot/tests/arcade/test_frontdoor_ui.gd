extends SceneTree
const Frontdoor = preload("res://scripts/arcade/frontdoor_ui.gd")
var failures := 0
var starts := 0
var resumes := 0
var changes := 0
func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var ui = Frontdoor.new()
	root.add_child(ui)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC", "Arial Unicode MS"])
	ui.setup(font, {"music_volume": 4.0, "sfx_volume": -2.0})
	ui.start_requested.connect(func(): starts += 1)
	ui.resume_requested.connect(func(): resumes += 1)
	ui.settings_changed.connect(func(_key, _value): changes += 1)
	check(not ui.blocking and ui.page == "closed", "closed after setup")
	check(ui.settings.music_volume == 1.0 and ui.settings.sfx_volume == 0.0, "setup volume clamp")
	ui.show_title()
	await process_frame
	check(ui.blocking and ui.page == "title", "title modal")
	check(ui._cover != null, "real original cover loaded")
	var source := FileAccess.get_file_as_string("res://scripts/arcade/frontdoor_ui.gd")
	check(not source.contains("拖动蓄力") and not source.contains("松手抛竿"), "current tap-only game instructions")
	check(ui._first_focus.has_focus(), "initial keyboard focus")
	for origin in ["title", "pause"]:
		ui.show_settings(origin)
		check(ui.page == "settings", "settings entry")
		ui._back()
		check(ui.page == origin, "settings return " + origin)
		ui.show_credits(origin)
		ui._back()
		check(ui.page == origin, "credits return " + origin)
	ui._set_setting("music_volume", -5)
	ui._set_setting("sfx_volume", 5)
	ui._set_setting("unknown", true)
	check(changes == 2 and ui.settings.music_volume == 0 and ui.settings.sfx_volume == 1, "change signals clamp only known keys")
	ui._resume()
	check(resumes == 1 and not ui.blocking, "resume closes")
	ui.show_title(true)
	ui._confirm_new_day()
	check(ui.page == "confirm_new", "new day protects run")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	ui._input(escape)
	check(ui.page == "title" and ui._can_resume, "cancel new day")
	ui._start()
	check(ui.page == "opening" and ui.blocking, "opening blocks")
	check(ui._opening_art.size.is_equal_approx(Vector2(360, 640)), "opening art stays logical 360x640 despite 1080x1920 texture")
	check(ui._opening_art.get_combined_minimum_size().is_zero_approx(), "opening art has no texture-imposed minimum size")
	check(ui._opening_art.stretch_mode == TextureRect.STRETCH_SCALE, "opening scales whole cover instead of clipping its sky")
	ui.show_settings("title")
	await create_timer(0.8).timeout
	check(starts == 0, "interrupted opening cannot start game")
	ui._start()
	ui._finish_opening()
	ui._finish_opening()
	check(starts == 1 and not ui.blocking, "skip exactly once")
	ui._start()
	await create_timer(0.85).timeout
	check(starts == 2 and ui.page == "closed", "timed opening ends")
	ui._set_setting("reduced_motion", true)
	ui._start()
	await process_frame
	check(starts == 3 and not ui.blocking, "reduced motion skips")
	ui.show_pause()
	ui._input(escape)
	check(resumes == 2 and not ui.blocking, "pause escape resumes")
	# All actionable targets meet the 44-point minimum; content is in logical bounds.
	for view in ["title", "pause", "settings", "credits"]:
		ui.call("show_" + view)
		await process_frame
		check_targets(ui._content)
	ui.close()
	ui.queue_free()
	await process_frame
	print("FRONTDOOR TEST failures=", failures)
	quit(0 if failures == 0 else 1)
func check_targets(node: Node) -> void:
	if node is Label and node.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var font: Font = node.get_theme_font("font")
		var fs: int = node.get_theme_font_size("font_size")
		check(font.get_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= node.size.x + 1, "label fits: " + node.text)
	if node is BaseButton or node is Slider:
		check(node.size.x >= 44 and node.size.y >= 44, "44-point target " + str(node))
		var rect: Rect2 = node.get_global_rect()
		check(rect.position.x >= 0 and rect.end.x <= 360.1 and rect.position.y >= 0 and rect.end.y <= 640.1, "target inside 360x640")
	for child in node.get_children(): check_targets(child)
