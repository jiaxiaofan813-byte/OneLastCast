extends SceneTree
## Headless-only frontdoor language, live routing and actual font/target geometry.
## Creates the standalone menu, never the main game or the player's save files.
const Frontdoor = preload("res://scripts/arcade/frontdoor_ui.gd")
var failures := 0
var checks := 0
var changes: Array = []
var starts := 0
var resumes := 0
var ui

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	ui = Frontdoor.new()
	root.add_child(ui)
	var font: Font = SystemFont.new()
	if "--qa-bundled-font" in OS.get_cmdline_user_args():
		font = load("res://assets/fonts/NotoSansSC-Regular.ttf") as FontFile
		font.allow_system_fallback = false
	else:
		font.font_names = PackedStringArray(["PingFang SC", "Hiragino Sans GB", "Arial"])
	ui.setup(font)
	ui.settings_changed.connect(func(key, value): changes.append([key, value]))
	ui.start_requested.connect(func(): starts += 1)
	ui.resume_requested.connect(func(): resumes += 1)
	check(ui.settings.language == "en", "new build defaults to English")
	check(ui.page == "closed" and not ui.blocking, "setup remains closed")
	ui.set_language(" ZH ")
	check(ui.settings.language == "zh" and ui.page == "closed", "normalize saved Chinese without opening a menu")
	ui.set_language("unsupported")
	check(ui.settings.language == "en", "invalid language falls back to English")
	check(changes.is_empty(), "programmatic language changes do not emit setting changes")
	var saved_ui = Frontdoor.new()
	root.add_child(saved_ui)
	saved_ui.setup(font, {"language": " ZH ", "music_volume": 4.0, "sfx_volume": -1.0})
	check(saved_ui.settings.language == "zh", "setup restores and normalizes saved Chinese")
	check(saved_ui.settings.music_volume == 1.0 and saved_ui.settings.sfx_volume == 0.0, "language setting does not affect volume clamping")
	saved_ui.queue_free()

	for language in ["en", "zh"]:
		ui.set_language(language)
		for menu in ["title", "resume_title", "pause", "settings", "credits", "confirm_new", "opening"]:
			show_page(menu)
			await process_frame
			verify_layout(ui._content)
			verify_language(ui._content, language)
			if menu == "title":
				var all_text := collect_text(ui._content)
				check(all_text.contains("ONE LAST CAST"), "brand retained in " + language)
				if language == "en":
					check(all_text.contains("Tap to dive. Tap again when rings meet."), "English tutorial has exactly the two tap actions")
					check(all_text.contains("Automatic recast."), "English tutorial describes automatic recast")
					check(not all_text.to_lower().contains("hold") and not all_text.to_lower().contains("release"), "no obsolete hold/release instructions")
			if menu == "credits":
				var credits := collect_text(ui._content)
				check(credits.contains("Godot 4.7.2") and credits.contains("MIT"), "factual engine/license credit")
				check(credits.contains("LakesideArcade-2"), "both supplied tracks credited")
				check(credits.contains("Commercial release rights have not been verified.") if language == "en" else credits.contains("商业发行授权尚未核实"), "music rights caveat remains explicit")

	ui.close()
	check(starts == 0 and resumes == 0, "viewing and translating every menu never starts or resumes a run")
	for origin in ["title", "pause"]:
		ui.show_title(true)
		ui.show_settings(origin)
		var saved_preferences: Dictionary = ui.settings.duplicate()
		for language in ["zh", "en", "zh", "en"]:
			var before := changes.size()
			var target := find_button(ui._content, "中文" if language == "zh" else "English")
			check(target != null, "both language choices are always readable")
			if target: target.pressed.emit()
			await process_frame
			check(changes.size() == before + 1 and changes.back() == ["language", language], "language button emits exactly one normalized setting")
			check(ui.page == "settings" and ui.blocking, "language button stays in Settings")
			check(ui.get_return_page() == origin and ui._can_resume, "language switch preserves navigation and resumable day")
			for key in saved_preferences:
				if key != "language": check(ui.settings[key] == saved_preferences[key], "language preserves preference: " + key)
			verify_layout(ui._content)
			verify_language(ui._content, language)
		var old_value: bool = ui.settings.music_enabled
		find_button(ui._content, "Background Music: On" if old_value else "Background Music: Off").pressed.emit()
		check(ui.settings.music_enabled != old_value, "toggle still works after repeated language rebuilds")
		var slider := find_slider(ui._content)
		slider.value = 0.25
		check(is_equal_approx(ui.settings.music_volume, 0.25), "volume still works after repeated rebuilds")
		check(slider.accessibility_name.contains("25%"), "screen reader volume stays in sync")
		find_button(ui._content, "Done").pressed.emit()
		check(ui.page == origin and ui.blocking, "Done returns to saved " + origin)
		check(ui._can_resume, "return preserves existing day")
		ui.show_credits(origin)
		ui.set_language("zh")
		ui.set_language("en")
		find_button(ui._content, "Back").pressed.emit()
		check(ui.page == origin, "translated credits return to " + origin)

	ui.show_title(true)
	ui._confirm_new_day()
	ui.set_language("zh")
	ui.set_language("en")
	check(ui.page == "confirm_new" and ui._can_resume, "new-day confirmation survives language rebuild")
	find_button(ui._content, "Keep Fishing").pressed.emit()
	check(ui.page == "title" and ui._can_resume and starts == 0, "cancel keeps current day without starting")
	ui._start()
	ui.set_process(false)
	ui._opening_time = 0.32
	ui.set_language("zh")
	ui.set_process(false)
	check(ui.page == "opening" and is_equal_approx(ui._opening_time, 0.32), "language rebuild preserves opening progress")
	ui.set_language("en")
	ui.set_process(false)
	ui._finish_opening()
	ui._finish_opening()
	check(starts == 1 and ui.page == "closed", "translated opening starts once only")
	ui.show_pause()
	find_button(ui._content, "Keep Fishing").pressed.emit()
	check(resumes == 1 and not ui.blocking, "English resume route still works")
	ui.queue_free()
	await process_frame
	print("FRONTDOOR LOCALIZATION: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

func show_page(menu: String) -> void:
	match menu:
		"resume_title": ui.show_title(true)
		"confirm_new": ui._confirm_new_day()
		"opening":
			ui._start()
			ui.set_process(false)
		_: ui.call("show_" + menu)

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found := find_button(child, text)
		if found: return found
	return null

func find_slider(node: Node) -> HSlider:
	if node is HSlider: return node
	for child in node.get_children():
		var found := find_slider(child)
		if found: return found
	return null

func collect_text(node: Node) -> String:
	var value := str(node.text) + "\n" if node is Label or node is Button else ""
	for child in node.get_children(): value += collect_text(child)
	return value

func has_chinese(value: String) -> bool:
	for i in value.length():
		if value.unicode_at(i) >= 0x3400 and value.unicode_at(i) <= 0x9fff: return true
	return false

func verify_language(node: Node, language: String) -> void:
	# Chinese keeps its own name and speech label in the language selector.
	if language == "en" and (node is Label or node is Button):
		check(not has_chinese(node.text) or node.text == "中文", "English page has no untranslated text: " + node.text)
	if language == "en" and node is Control and not (node is Button and node.text == "中文"):
		check(not has_chinese(node.accessibility_name), "English accessibility name: " + node.accessibility_name)
		check(not has_chinese(node.accessibility_description), "English accessibility description: " + node.accessibility_description)
	for child in node.get_children(): verify_language(child, language)

func verify_layout(node: Node) -> void:
	if node is Label and node.has_meta("cover_tutorial"):
		var card: Control = node.get_parent()
		var bottom_padding: float = card.size.y - (node.position.y + node.size.y)
		check(bottom_padding >= 15.9, "tutorial keeps 16 points below final text line: " + str(bottom_padding))
		check(card.get_global_rect().end.y <= 640, "padded cover card remains inside viewport")
	if node is Label or node is Button:
		var font: Font = node.get_theme_font("font")
		var font_size: int = node.get_theme_font_size("font_size")
		# The credits body is intentionally wrapped and scrollable. All other
		# labels, including the explicit two-line tutorial, must fit without wrap.
		if not node.get_parent() is ScrollContainer:
			var widest := 0.0
			for line in node.text.split("\n"):
				widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
			check(widest <= node.size.x - (12 if node is Button else 0) + 1, "actual font width fits: " + node.text)
			check(font.get_height(font_size) * node.text.split("\n").size() <= node.size.y + 1, "actual font height fits: " + node.text)
			var rect: Rect2 = node.get_global_rect()
			check(rect.position.x >= 0 and rect.end.x <= 360.1 and rect.position.y >= 0 and rect.end.y <= 640.1, "text inside 360×640: " + node.text)
	if node is BaseButton or node is Slider:
		check(node.size.x >= 44 and node.size.y >= 44, "44-point interaction target")
		var rect: Rect2 = node.get_global_rect()
		check(rect.position.x >= 0 and rect.end.x <= 360.1 and rect.position.y >= 0 and rect.end.y <= 640.1, "control inside 360×640")
		check(not node.accessibility_name.is_empty(), "control has an accessible name")
		for sibling in node.get_parent().get_children():
			if sibling == node or not sibling is Control: continue
			if sibling is Label or sibling is BaseButton or sibling is Slider:
				check(not rect.intersects(sibling.get_global_rect()), "interaction target does not overlap sibling content: " + node.accessibility_name)
	for child in node.get_children(): verify_layout(child)
