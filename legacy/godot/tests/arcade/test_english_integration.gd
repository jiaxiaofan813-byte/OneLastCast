extends SceneTree
## Focused localization regression. Headless only; never loads the player's saves.
const Main = preload("res://scripts/arcade/arcade_main.gd")
const Catalog = preload("res://scripts/arcade/fish_catalog.gd")
const DT := 1.0 / 60.0
var game
var checks := 0
var failures := 0
var temporary_dir := "res://runtime/tests-english-%d" % Time.get_ticks_usec()
var seen_text: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func step(frames: int = 1) -> void:
	for frame in frames:
		game._physics_process(DT)
		game._process(DT)

func click() -> void:
	game._press(Vector2(180, 600))
	game._release()

func has_cjk(value: String) -> bool:
	for index in value.length():
		var code := value.unicode_at(index)
		if (code >= 0x3400 and code <= 0x9fff) or (code >= 0xf900 and code <= 0xfaff):
			return true
	return false

func language_choice(value: String) -> bool:
	# Chinese is appropriate only in the self-identifying language picker.
	return value.contains("中文") and (value.contains("English") or value.contains("Language") or value in ["中文", "简体中文"])

func audit_text(value: String, context: String, allow_cjk: bool = false) -> void:
	if value.is_empty(): return
	check(not has_cjk(value) or language_choice(value) or allow_cjk, context + " has no untranslated Chinese: " + value)
	seen_text[value] = true

func in_scroll(node: Node) -> bool:
	var parent := node.get_parent()
	while parent != null:
		if parent is ScrollContainer: return true
		parent = parent.get_parent()
	return false

func audit_tree(node: Node) -> void:
	if node is CanvasItem and not node.is_visible_in_tree(): return
	if node is Control:
		var own_language: bool = node is Button and node.text == "中文"
		audit_text(node.accessibility_name, "accessibility", own_language)
		audit_text(node.accessibility_description, "accessibility description", own_language)
		audit_text(node.tooltip_text, "tooltip")
	if node is Label or node is Button:
		audit_text(node.text, "visible text")
		var ui_font: Font = node.get_theme_font("font")
		var font_size: int = node.get_theme_font_size("font_size")
		if node is Button or node.autowrap_mode == TextServer.AUTOWRAP_OFF:
			for line in node.text.split("\n"):
				var text_width := ui_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				var available: float = node.size.x
				if node is Button:
					var style: StyleBox = node.get_theme_stylebox("normal")
					available -= style.get_content_margin(SIDE_LEFT) + style.get_content_margin(SIDE_RIGHT)
				check(text_width <= available + 1.0, "text fits width %.1f/%.1f: %s" % [text_width, available, line])
		if not in_scroll(node):
			var text_rect: Rect2 = node.get_global_rect()
			check(text_rect.position.x >= -0.1 and text_rect.end.x <= 360.1, "text within viewport: " + node.text)
	if node is BaseButton or node is Slider:
		check(node.size.x >= 44 and node.size.y >= 44, "44-point control: " + str(node))
		var rect: Rect2 = node.get_global_rect()
		check(rect.position.x >= -0.1 and rect.end.x <= 360.1, "control within horizontal viewport")
		if not in_scroll(node):
			check(rect.position.y >= -0.1 and rect.end.y <= 640.1, "control within vertical viewport")
	for child in node.get_children(): audit_tree(child)

func find_button(node: Node, phrase: String) -> Button:
	if node is Button and node.is_visible_in_tree() and node.text.contains(phrase): return node
	for child in node.get_children():
		var result := find_button(child, phrase)
		if result != null: return result
	return null

func press_button(node: Node, phrase: String) -> bool:
	var button := find_button(node, phrase)
	check(button != null and not button.disabled, "usable button: " + phrase)
	if button == null or button.disabled: return false
	button.pressed.emit()
	return true

func stats() -> Dictionary:
	return {"ledger": game.ledger.save_to_dictionary().duplicate(true), "best_score": game.best_score,
		"best_combo": game.best_combo, "session": game.ledger_session, "run": game.ledger_run,
		"rounds_finished": game.rounds_finished, "basket": game.basket_fish.duplicate(true)}

func audit_frontdoor() -> void:
	for view in ["title", "pause", "settings", "credits"]:
		game.frontdoor.call("show_" + view)
		await process_frame
		audit_tree(game.frontdoor)
	game.frontdoor.show_title(true)
	game.frontdoor._confirm_new_day()
	await process_frame
	audit_tree(game.frontdoor)
	game.frontdoor._start()
	game.frontdoor.set_process(false)
	await process_frame
	audit_tree(game.frontdoor)
	game.frontdoor._finish_opening()
	check(game.has_started and not game.frontdoor.blocking, "opening starts English gameplay")

func audit_catalog() -> void:
	game._toggle_catalog()
	await process_frame
	check(game.catalog_open and game.catalog_rows.get_child_count() == 20, "Fish Log has exactly 20 rows")
	check(game.catalog_title.text.contains("/ 20"), "Fish Log uses correct species denominator")
	var names: Array[String] = []
	for row in game.catalog_rows.get_children(): names.append(row.get_child(1).text)
	for species_id in Catalog.ACTIVE_IDS:
		var entry: Dictionary = Catalog.get_species(species_id)
		check(entry.name_en in names, "English fish name: " + entry.name_en)
	for descending in [true, false]:
		game.catalog_descending = descending
		game._refresh_catalog()
		await process_frame
		audit_tree(game.catalog_panel)
	var before := stats()
	for species_id in Catalog.ACTIVE_IDS:
		game._show_species(species_id)
		await process_frame
		audit_tree(game.catalog_panel)
		var entry: Dictionary = Catalog.get_species(species_id)
		check(game.catalog_detail.get_child(0).text == entry.name_en, "English detail heading: " + species_id)
		check(game.catalog_detail.get_child(2).texture != null, "original fish image: " + species_id)
		var back = game.catalog_detail.get_child(game.catalog_detail.get_child_count() - 1)
		check(back is Button and back.text.contains("Fish Log"), "English detail Back: " + species_id)
		back.pressed.emit()
		check(not game.catalog_detail.visible and game.catalog_scroll.visible, "detail Back works: " + species_id)
	check(stats() == before, "browsing and sorting do not change catches or scores")
	game._toggle_catalog()
	check(not game.catalog_open and not game.paused, "Fish Log close returns to play")

func audit_language_state() -> void:
	game.rules.setup(20261109)
	game._consume_events()
	var reached := false
	for frame in 180:
		if game.rules.predict_slam_contact().get("category", "") == "fish":
			click(); reached = true; break
		step()
	check(reached, "first click has a real fish collision opportunity")
	audit_tree(game.ui)
	for frame in 180:
		if game.rules.state == "bite_window": break
		step()
	check(game.rules.state == "bite_window", "first click reaches real bite window")
	audit_tree(game.ui)
	game._toggle_pause()
	game.frontdoor.show_settings("pause")
	press_button(game.frontdoor, "中文")
	await process_frame
	var original: Dictionary = game.rules.snapshot()
	var original_stats := stats()
	var original_visual_time: float = game.visual_time
	var original_ring: float = game.rules.ring_elapsed
	for language in ["en", "zh", "en"]:
		press_button(game.frontdoor, "English" if language == "en" else "中文")
		await process_frame
		step(12)
		check(game.language == language and game.frontdoor.settings.language == language, "language reaches main and shell: " + language)
		check(game.frontdoor.page == "settings" and game.paused, "switch stays in paused settings: " + language)
		check(game.rules.snapshot() == original, "exact rules/RNG/events preserved: " + language)
		check(stats() == original_stats, "scores and ledger preserved: " + language)
		check(game.visual_time == original_visual_time and game.rules.ring_elapsed == original_ring, "visual and bite clocks frozen: " + language)
		if language == "en": audit_tree(game.frontdoor)
	# Real visible controls still respond after rebuilding the settings UI.
	var music: bool = game.music_enabled
	check(press_button(game.frontdoor, "Music"), "rebuilt music control exists")
	check(game.music_enabled != music, "rebuilt music control changes setting")
	press_button(game.frontdoor, "Done")
	check(game.frontdoor.page == "pause" and game.paused, "Done returns to pause after language switch")
	press_button(game.frontdoor, "Keep Fishing")
	check(not game.paused and not game.frontdoor.blocking, "Resume works after language switch")
	check(game.rules.snapshot() == original and stats() == original_stats, "resume preserves exact day and all stats")
	for frame in 180:
		if game.rules.ring_elapsed >= game.rules.ring_duration: break
		step()
	audit_tree(game.ui)
	click()
	var audited_states: Array[String] = []
	for frame in 180:
		if game.rules.state not in audited_states:
			audited_states.append(game.rules.state)
			audit_tree(game.ui)
		if game.rules.state == "recast_window": break
		step()
	check(game.rules.catches == 1 and game.ledger.total_catches() == 1, "second click after switch lands one real fish")
	for toast in game.toasts: audit_text(toast.text, "catch toast")
	step(30)
	check(game.rules.state == "casting", "successful catch still auto-recasts")

func audit_failures() -> void:
	var previous_titles: Array[String] = []
	for reason in ["hook_early", "hook_late", "empty_dive"]:
		var before := stats()
		game.rules._fail(reason)
		game._consume_events()
		step(90)
		check(game.result_panel.visible, "result visible: " + reason)
		audit_tree(game.ui)
		var title: String = game.result_title.text.to_lower()
		check(title not in previous_titles, "distinct explanation: " + reason)
		previous_titles.append(title)
		if reason == "hook_early": check(title.contains("early") and (title.contains("fish") or title.contains("away")), "early click explains fish escape")
		if reason == "hook_late": check(title.contains("late") and title.contains("line"), "late click explains line failure")
		if reason == "empty_dive": check(title.contains("empty") or title.contains("miss") or title.contains("no fish"), "empty dive explains no fish")
		press_button(game.result_panel, "Come Back Tomorrow")
		check(game.rules.state == "casting" and not game.result_panel.visible, "Come Back Tomorrow retries immediately: " + reason)
		check(game.ledger.save_to_dictionary() == before.ledger, "retry preserves lifetime ledger: " + reason)

func audit_navigation_after_switch() -> void:
	var before: Dictionary = game.rules.snapshot()
	game._toggle_pause()
	press_button(game.frontdoor, "Settings")
	press_button(game.frontdoor, "中文")
	press_button(game.frontdoor, "English")
	press_button(game.frontdoor, "Done")
	press_button(game.frontdoor, "Fish Log")
	check(game.catalog_open and game.catalog_return_page == "pause", "rebuilt Fish Log button keeps pause return route")
	game._toggle_catalog()
	check(game.frontdoor.page == "pause" and game.paused, "Fish Log close returns to rebuilt pause")
	press_button(game.frontdoor, "Back to Title")
	check(game.frontdoor.page == "title" and game.frontdoor._can_resume, "Back to Title preserves resumable day")
	press_button(game.frontdoor, "Credits")
	check(game.frontdoor.page == "credits", "Credits button works after language switch")
	press_button(game.frontdoor, "Back")
	check(game.frontdoor.page == "title", "Credits Back returns to title")
	press_button(game.frontdoor, "Start a New Day")
	check(game.frontdoor.page == "confirm_new", "new day still requires confirmation")
	press_button(game.frontdoor, "Keep Fishing")
	check(game.frontdoor.page == "title", "new-day cancel returns to title")
	press_button(game.frontdoor, "Keep Fishing")
	check(not game.paused and not game.frontdoor.blocking, "title resume still works")
	check(game.rules.snapshot() == before, "all rebuilt menu navigation preserves exact live day")

func audit_preferences() -> void:
	# _ready ran with test_mode=true. Only now redirect and enable disk I/O.
	game.data_dir = temporary_dir
	var absolute := ProjectSettings.globalize_path(temporary_dir)
	check(DirAccess.make_dir_recursive_absolute(absolute) == OK, "isolated SSD test save directory")
	game.test_mode = false
	var legacy := FileAccess.open(game._settings_path(), FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"version": 4, "best_score": 1234, "best_combo": 9, "muted": true, "haptics": false}))
	legacy.close()
	var fresh = Main.new()
	fresh.data_dir = temporary_dir
	fresh._load_settings()
	check(fresh.language == "en", "old settings without language default to English")
	check(fresh.best_score == 1234 and fresh.best_combo == 9, "language migration keeps old scores")
	fresh.free()
	for language in ["zh", "en"]:
		game._apply_setting("language", language)
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game._settings_path()))
		check(saved.get("language", "") == language, "chosen language persisted: " + language)
		var restored = Main.new()
		restored.data_dir = temporary_dir
		restored._load_settings()
		restored._load_language_preferences()
		check(restored.language == language, "chosen language loads in fresh instance: " + language)
		check(restored.ledger.save_to_dictionary() == game.ledger.save_to_dictionary(), "language save preserves ledger: " + language)
		restored.free()
	# A still-running old build may overwrite its settings file, not the separate UI preference.
	game._apply_setting("language", "zh")
	var overwritten := FileAccess.open(game._settings_path(), FileAccess.WRITE)
	overwritten.store_string(JSON.stringify({"version": 4, "best_score": 1234, "best_combo": 9}))
	overwritten.close()
	var protected = Main.new()
	protected.data_dir = temporary_dir
	protected._load_settings()
	check(protected.language == "en", "legacy overwrite alone has English migration default")
	protected._load_language_preferences()
	check(protected.language == "zh", "separate language preference survives old build overwrite")
	protected.free()
	game._apply_setting("language", "en")
	game.test_mode = true
	for filename in ["ui-preferences-v1.json", "ui-preferences-v1.json.tmp", "arcade-settings.json", "arcade-settings.json.tmp", "catch-progress-v2.json", "catch-progress-v2.json.tmp"]:
		var path := absolute.path_join(filename)
		if FileAccess.file_exists(path): check(DirAccess.remove_absolute(path) == OK, "remove test-owned save: " + filename)
	check(DirAccess.remove_absolute(absolute) == OK, "remove isolated test directory")

func run() -> void:
	game = Main.new()
	check(game.language == "en", "normal new game defaults to English")
	game.test_mode = true
	game.force_language = "en"
	game.force_frontdoor = true
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.muted = true
	game.haptics.enabled = false
	await process_frame
	check(game.test_mode and game.language == "en", "explicit English test mode isolates player saves")
	await audit_frontdoor()
	audit_tree(game.ui)
	game.intro_active = true
	game._update_ui()
	game.intro_panel.show()
	audit_tree(game.ui)
	click()
	check(not game.intro_active, "English two-click tutorial dismisses without casting early")
	await audit_catalog()
	await audit_language_state()
	audit_navigation_after_switch()
	game._toggle_debug()
	await process_frame
	audit_tree(game.ui)
	game._toggle_debug()
	audit_failures()
	audit_preferences()
	game.queue_free()
	await process_frame
	print("ENGLISH INTEGRATION: %d checks, %d failures, %d distinct text strings" % [checks, failures, seen_text.size()])
	quit(1 if failures else 0)
