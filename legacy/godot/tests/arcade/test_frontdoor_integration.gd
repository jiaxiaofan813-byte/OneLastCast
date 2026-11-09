extends SceneTree
## Headless only. Never reads or writes the player's actual progress.
const Main = preload("res://scripts/arcade/arcade_main.gd")
const DT := 1.0 / 60.0
var game
var checks := 0
var failures := 0
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
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(180, 600)
	event.pressed = true
	game._unhandled_input(event)
	event.pressed = false
	game._unhandled_input(event)
func snapshot() -> Array:
	return [game.rules.time, game.rules.state, game.rules.held, game.rules.ring_elapsed, game.rules.score, game.rules.combo, game.rules.boat_distance]
func frozen(label: String) -> void:
	var before := snapshot()
	click()
	step(40)
	check(snapshot() == before, label)
func run() -> void:
	game = Main.new()
	game.test_mode = true
	game.force_frontdoor = true
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.muted = true
	game.haptics.enabled = false
	await process_frame
	check(game.test_mode and game.frontdoor != null, "test-mode frontdoor created")
	check(game.frontdoor.blocking and game.frontdoor.page == "title" and not game.has_started, "boot enters title")
	frozen("title blocks gameplay input and ticks")
	game.frontdoor.show_settings("title")
	frozen("title settings freeze gameplay")
	game.frontdoor._set_setting("music_enabled", false)
	game.frontdoor._set_setting("music_volume", 0.25)
	game.frontdoor._set_setting("sfx_volume", 0.55)
	game.frontdoor._set_setting("reduced_motion", true)
	check(not game.music_enabled and is_equal_approx(game.music_volume, 0.25), "music settings reach main")
	check(is_equal_approx(game.sfx_volume, 0.55) and game.reduced_motion, "sound and motion settings reach main")
	game.frontdoor._back()
	check(game.frontdoor.page == "title" and not game.has_started, "settings return to unstarted title")
	game.frontdoor.show_credits("title")
	frozen("credits freeze gameplay")
	game.frontdoor._back()
	game.frontdoor.catalog_requested.emit()
	check(game.catalog_open, "title catalog opens")
	frozen("title catalog freezes gameplay")
	game._toggle_catalog()
	check(not game.catalog_open and game.frontdoor.page == "title" and game.frontdoor.blocking, "catalog returns to title")
	game.frontdoor._set_setting("reduced_motion", false)
	game.frontdoor._start()
	game.frontdoor.set_process(false)
	check(game.frontdoor.page == "opening" and not game.has_started, "opening precedes run")
	frozen("opening blocks input and physics")
	game.frontdoor._finish_opening()
	check(game.has_started and not game.frontdoor.blocking and not game.paused, "opening starts gameplay")
	var before_time: float = game.rules.time
	step(8)
	check(game.rules.time > before_time, "gameplay ticks after opening")
	game._toggle_pause()
	check(game.paused and game.frontdoor.page == "pause", "pause enters new menu")
	frozen("pause blocks gameplay")
	game.frontdoor.show_settings("pause")
	frozen("pause settings freeze gameplay")
	game.frontdoor._back()
	check(game.frontdoor.page == "pause" and game.paused, "settings restore pause")
	game.frontdoor.catalog_requested.emit()
	check(game.catalog_open, "pause catalog opens")
	frozen("pause catalog freezes gameplay")
	game._toggle_catalog()
	check(not game.catalog_open and game.frontdoor.page == "pause" and game.frontdoor.blocking, "catalog returns to pause")
	var paused_state := snapshot()
	game.frontdoor._resume()
	check(not game.paused and not game.frontdoor.blocking and snapshot() == paused_state, "resume preserves current day")
	step(4)
	check(game.rules.time > float(paused_state[0]), "resumed day advances")
	game._toggle_pause()
	var before_title := snapshot()
	game._title_from_frontdoor()
	check(game.frontdoor.page == "title" and game.frontdoor.blocking, "return title shows resumable menu")
	frozen("resumable title freezes current day")
	game.frontdoor._resume()
	check(snapshot() == before_title and not game.paused, "title resume preserves day")
	game._toggle_catalog()
	check(game.catalog_open, "gameplay catalog opens")
	frozen("gameplay catalog freezes")
	game._toggle_catalog()
	check(not game.catalog_open and not game.frontdoor.blocking and not game.paused, "gameplay catalog returns to gameplay")
	check(game.test_mode, "test mode remained enabled throughout")
	game.queue_free()
	await process_frame
	print("FRONTDOOR INTEGRATION: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
