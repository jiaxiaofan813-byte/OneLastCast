extends SceneTree
## Headless UI/state regression, not a claim of human play or rendered QA.
const Main = preload("res://scripts/arcade/arcade_main.gd")
const Catalog = preload("res://scripts/arcade/fish_catalog.gd")
const DT := 1.0 / 60.0
var game
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _init() -> void:
	call_deferred("run")

func step(frames: int = 1) -> void:
	for frame in frames:
		game._physics_process(DT)
		game._process(DT)

func click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(180, 600)
	event.pressed = true
	game._unhandled_input(event)
	event.pressed = false
	game._unhandled_input(event)

func run() -> void:
	game = Main.new()
	game.test_mode = true
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.muted = true
	game.haptics.enabled = false
	await process_frame
	check(game.test_mode, "test mode prevents player save changes")
	check(game.catalog_rows != null, "catalog built")
	game.intro_active = true
	game._update_ui()
	game._toggle_pause(); game._toggle_catalog(); game._toggle_debug()
	check(not game.paused and not game.catalog_open and not game.debug_open, "intro rejects modal entry")
	check(game.pause_button.disabled and game.catalog_button.disabled, "intro disables header controls")
	click()
	check(not game.intro_active and not game.pause_button.disabled and not game.catalog_button.disabled, "intro click starts with enabled controls")
	game._toggle_catalog()
	check(game.catalog_rows.get_child_count() == 20, "twenty visible species")
	check(game.catalog_title.text.contains("/ 20"), "twenty-species denominator")
	var ledger_before_cards: int = game.ledger.total_catches()
	for species_id in Catalog.ACTIVE_IDS:
		game._show_species(species_id)
		check(game.catalog_detail.visible and not game.catalog_scroll.visible, "detail opens " + species_id)
		var card_time: float = game.rules.time
		game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		step(2)
		check(game.rules.time == card_time and not game.paused, "detail focus keeps simulation frozen " + species_id)
		var back = game.catalog_detail.get_child(game.catalog_detail.get_child_count() - 1)
		check(back is Button and back.text.contains("返回鱼获本"), "detail explicit back button " + species_id)
		back.pressed.emit()
		check(not game.catalog_detail.visible and game.catalog_scroll.visible, "detail back restores list " + species_id)
	game._show_species("channel_catfish")
	game._toggle_catalog()
	check(not game.catalog_open and not game.catalog_panel.visible, "detail close dismisses whole catalog")
	game._toggle_catalog()
	check(not game.catalog_detail.visible and game.catalog_scroll.visible, "reopen starts in list")
	check(game.ledger.total_catches() == ledger_before_cards, "card viewing never modifies ledger")
	var frozen_time: float = game.rules.time
	step(30)
	check(game.rules.time == frozen_time, "catalog freezes simulation")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not game.paused, "catalog focus loss avoids hidden pause")
	game._toggle_catalog()
	game._toggle_pause()
	step(30)
	check(game.rules.time == frozen_time, "pause freezes simulation")
	game._toggle_catalog()
	check(game.catalog_open and not game.paused and not game.pause_panel.visible, "catalog replaces pause")
	game._toggle_debug()
	check(game.debug_open and not game.catalog_open and not game.catalog_panel.visible, "debug replaces catalog")
	game._toggle_pause()
	game._toggle_debug()
	check(game.debug_open and not game.paused and not game.pause_panel.visible, "debug replaces pause")
	game._toggle_pause()
	check(game.paused and not game.debug_open and not game.debug_panel.visible, "pause replaces debug")
	# Reset overlays to make following checks independent after any failure.
	if game.debug_open: game._toggle_debug()
	if game.catalog_open: game._toggle_catalog()
	if game.paused: game._toggle_pause()
	game.rules.setup(20261109)
	game._consume_events()
	var found := false
	for frame in 180:
		var target: Dictionary = game.rules.predict_slam_contact()
		if target.get("category", "") == "fish":
			click()
			found = true
			break
		step()
	check(found, "real first-collision opportunity")
	for frame in 180:
		if game.rules.state == "bite_window": break
		step()
	check(game.rules.state == "bite_window", "first input reaches shrinking ring")
	var ring_time: float = game.rules.ring_elapsed
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	step(30)
	check(game.paused and game.rules.ring_elapsed == ring_time, "focus loss freezes live ring")
	game._toggle_pause()
	for frame in 120:
		if game.rules.ring_elapsed >= game.rules.ring_duration: break
		step()
	click()
	for frame in 180:
		if game.rules.state == "recast_window": break
		step()
	check(game.rules.catches == 1 and game.ledger.total_catches() == 1, "second input yields one real basket catch")
	step(30)
	check(game.rules.state == "casting", "basket automatically recasts")
	for reason in ["hook_early", "hook_late"]:
		game.rules._fail(reason)
		game._consume_events()
		step(120)
		check(game.result_panel.visible and game.night_amount > .9, reason + " shows night results")
		check(game.result_title.text.contains("点早了" if reason == "hook_early" else "点晚了"), reason + " explains timing")
		click()
		check(game.rules.state == "casting" and not game.result_panel.visible, "immediate next-day retry")
		check(game.ledger.total_catches() == 1, "retry preserves lifetime ledger")
	for category in ["snail", "weed"]:
		game.rules.events.append({"type": "junk_basket", "category": category})
		game._consume_events()
	check(game.ledger.total_catches() == 1, "salvage does not count as fish")
	game.ledger.load_from_dictionary({"version": 1, "counts": {"bluegill": 4, "muskellunge": 7}, "recent_tokens": []})
	check(game.ledger.count_for("bluegill") == 4 and game.ledger.count_for("muskellunge") == 7, "historical inactive species survives migration")
	game._refresh_catalog()
	check(game.catalog_rows.get_child_count() == 20, "historical counts do not expand active list")
	check(Catalog.available_count() == 20, "twenty catchable species")
	game.rules._fail("hook_early")
	game._consume_events()
	click()
	check(game.rules.state == "casting" and game.home_clock == 0, "failure animation can be skipped immediately")
	game.rules._fail("hook_late")
	game._consume_events()
	step(120)
	var retry_found := false
	for child in game.result_panel.get_children():
		if child is Button and child.text.contains("第二天再来"): retry_found = true
	check(retry_found, "visible next-day retry button")
	var key := InputEventKey.new()
	key.keycode = KEY_N
	key.pressed = true
	game._unhandled_input(key)
	check(game.rules.state == "casting" and not game.result_panel.visible, "N retries immediately")
	check(game.ledger.count_for("bluegill") == 4 and game.ledger.count_for("muskellunge") == 7, "N retry retains all legacy counts")
	game.queue_free()
	await process_frame
	print("UI_ACCEPTANCE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
