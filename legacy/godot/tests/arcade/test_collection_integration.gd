extends SceneTree
const Main = preload("res://scripts/arcade/arcade_main.gd")
const DT := 1.0 / 60.0
var game
var checks := 0
var failures := 0
var temporary_dir := "res://runtime/tests-collection-%d" % Time.get_ticks_usec()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)
func _init() -> void:
	call_deferred("run")
func step() -> void:
	game._physics_process(DT)
	game._process(DT)
func run() -> void:
	game = Main.new()
	game.test_mode = true
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.muted = true
	game.haptics.enabled = false
	check(game.data_dir == ("res://runtime" if OS.has_feature("editor") else "user://"), "Archive uses portable project or user save location")
	game.data_dir = temporary_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temporary_dir))
	await process_frame
	game.rules.setup(20261109)
	game._consume_events()
	# Find a real visible fish contact and finish an actual catch.
	var reached := false
	for i in 120:
		var candidate: Dictionary = game.rules.predict_slam_contact()
		if not candidate.is_empty() and candidate.get("category", "fish") == "fish":
			game._press(Vector2(180,620))
			game._release()
			reached = true
			break
		step()
	check(reached, "visible real fish opportunity")
	for i in 180:
		if game.rules.state == "bite_window": break
		step()
	check(game.rules.state == "bite_window" and game.rules.catch_category == "fish", "actual fish reached ring")
	var ring_before: float = game.rules.ring_elapsed
	var time_before: float = game.rules.time
	game._toggle_catalog()
	check(game.catalog_open and game.catalog_panel.visible, "catalog opens")
	for i in 30: step()
	check(game.rules.time == time_before and game.rules.ring_elapsed == ring_before, "catalog freezes gameplay and ring")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not game.paused and not game.pause_panel.visible, "focus out while catalog avoids hidden pause")
	game._toggle_catalog()
	check(not game.catalog_open and not game.catalog_panel.visible and not game.paused, "catalog closes without stuck overlay")
	step()
	check(game.rules.time > time_before and game.rules.ring_elapsed > ring_before, "same ring resumes")
	for i in 120:
		if game.rules.ring_elapsed >= game.rules.ring_duration: break
		step()
	game._press(Vector2(180,620)); game._release()
	# Collect actual basket event before main consumes it, then replay exact event.
	var basket: Dictionary = {}
	for i in 180:
		game.rules.tick(DT)
		for event in game.rules.events:
			if event.type == "basket": basket = event.duplicate(true)
		game._consume_events()
		if not basket.is_empty(): break
	check(not basket.is_empty() and game.ledger.total_catches() == 1, "actual basket increments once")
	if not basket.is_empty():
		check(game.ledger.count_for(basket.species_id) == 1, "authoritative species ID reaches ledger")
		game.rules.events.append(basket)
		game._consume_events()
	check(game.ledger.total_catches() == 1, "replayed same basket does not count twice")
	game.rules._fail("hook_late"); game._consume_events()
	game._press(Vector2(180,620)); game._release()
	check(game.ledger.total_catches() == 1 and game.rules.state == "casting", "actual retry retains lifetime catch")
	for category in ["snail", "weed"]:
		game.rules.events.append({"type":"junk_basket", "category":category})
		game._consume_events()
	check(game.ledger.total_catches() == 1, "snail and weed events never increment fish")
	# Enable disk I/O only after redirecting to this test's unique SSD directory.
	game.test_mode = false
	for version in [1,2]:
		var file := FileAccess.open(game._settings_path(), FileAccess.WRITE)
		file.store_string(JSON.stringify({"version":version,"best_score":8765,"best_combo":23,"muted":true,"haptics":false,"tune":{"hook_window_ms":450}}))
		file.close()
		game._load_settings()
		check(game.ledger.total_catches() == 0 and game.best_score == 8765 and game.best_combo == 23, "legacy v%d preserves scores without fabricating catches" % version)
		check(game.rules.tune.hook_window_ms == (180.0 if version == 1 else 250.0), "legacy tune migration v%d" % version)
	game.ledger.record_catch("bluegill", "integration:a")
	game.ledger.record_catch("bluegill", "integration:b")
	game.ledger.record_catch("walleye", "integration:c")
	game._save_settings()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game._settings_path()))
	check(saved.version == 4 and saved.best_score == 8765 and saved.catch_ledger.counts.bluegill == 2, "version 4 JSON contains preserved scores and real counts")
	game.ledger.setup(); game.best_score = 0
	game._load_settings()
	check(game.ledger.total_catches() == 3 and game.ledger.count_for("bluegill") == 2 and game.best_score == 8765, "disk roundtrip preserves statistics")
	check(not game.ledger.record_catch("bluegill", "integration:a"), "disk roundtrip retains duplicate protection")
	game.test_mode = true
	check(game.language == "en", "legacy settings without language migrate to English")
	game._apply_setting("language", "zh")
	game.catalog_descending = true; game._refresh_catalog()
	check(game.catalog_rows.get_child_count() == 20 and game.catalog_title.text.contains("当前可钓 20 种"), "20 UI rows and twenty available label")
	check(game.catalog_rows.get_child(0).get_child(1).text == "蓝鳃太阳鱼", "most sort places bluegill first")
	var unavailable := 0
	for row in game.catalog_rows.get_children():
		if row.get_child(3).text == "尚未入场": unavailable += 1
	for row in game.catalog_rows.get_children():
		check(row.get_child(0) is TextureRect and row.get_child(0).texture != null, "catalog row has actual species texture")
	check(unavailable == 0, "all twenty visible species genuinely available")
	game.catalog_descending = false; game._refresh_catalog()
	check(game.catalog_rows.get_child(0).get_child(3).text == "× 0", "least sort places zero catchable count first")
	check(game.catalog_rows.get_child(19).get_child(1).text == "蓝鳃太阳鱼", "least sort puts highest count last")
	# Old running prototypes may overwrite only the legacy settings filename.
	game.test_mode = false
	game._save_settings()
	var progress_path: String = temporary_dir.path_join("catch-progress-v2.json")
	var progress_text := FileAccess.get_file_as_string(progress_path)
	var progress: Dictionary = JSON.parse_string(progress_text)
	check(progress.version == 1 and progress.ledger.version == 2 and progress.ledger.counts.bluegill == 2, "separate progress wrapper persisted atomically")
	check(not FileAccess.file_exists(progress_path + ".tmp"), "successful progress save leaves no temporary file")
	var legacy := FileAccess.open(game._settings_path(), FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"version":2,"best_score":100,"best_combo":1,"muted":true,"haptics":false}))
	legacy.close()
	# A genuinely fresh Main instance, never added to tree: no default user save access.
	var fresh = Main.new()
	fresh.data_dir = temporary_dir
	fresh.test_mode = false
	fresh._load_settings()
	check(fresh.ledger.total_catches() == 0 and fresh.best_score == 100, "fresh instance loads overwritten legacy settings")
	fresh._load_progress()
	check(fresh.ledger.total_catches() == 3 and fresh.ledger.count_for("bluegill") == 2 and fresh.best_score == 8765 and fresh.best_combo == 23, "separate progress restores catches and bests after legacy overwrite")
	var stable: Dictionary = fresh.ledger.save_to_dictionary()
	for corrupt in ["not JSON", JSON.stringify({"version":99,"ledger":stable}), JSON.stringify({"version":1,"ledger":{}}), JSON.stringify({"version":1,"ledger":{"version":999,"counts":{},"recent_tokens":[]}})]:
		var damaged := FileAccess.open(progress_path, FileAccess.WRITE)
		damaged.store_string(corrupt); damaged.close()
		fresh._load_progress()
		check(fresh.ledger.save_to_dictionary() == stable and fresh.best_score == 8765 and fresh.best_combo == 23, "corrupt progress cannot mutate valid state")
	var restore_file := FileAccess.open(progress_path, FileAccess.WRITE)
	restore_file.store_string(progress_text); restore_file.close()
	fresh.test_mode = true
	fresh.ledger.setup(); fresh.best_score = 0; fresh.best_combo = 0
	fresh._load_progress()
	check(fresh.ledger.total_catches() == 0 and fresh.best_score == 0, "test mode progress load is no-op")
	fresh._save_progress()
	check(FileAccess.get_file_as_string(progress_path) == progress_text, "test mode progress save is no-op")
	fresh.free()
	game.test_mode = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game._settings_path()))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_dir.path_join("ui-preferences-v1.json")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_dir))
	game.queue_free()
	await process_frame
	print("Collection integration: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
