extends SceneTree
## Two-tap regression using actual viewport input dispatch.
const Main = preload("res://scripts/arcade/arcade_main.gd")
const DT := 1.0 / 60.0
var game
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)
func _init() -> void: call_deferred("run")
func button(down: bool, pos := Vector2(180,620)) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = pos
	e.pressed = down
	root.push_input(e,true)
func tap(pos := Vector2(180,620)) -> void:
	button(true,pos)
	button(false,pos)
func key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	root.push_input(e,true)
func step(count := 1) -> void:
	for i in count:
		game._physics_process(DT)
		game._process(DT)
func reset(seed_value := 20261109) -> void:
	game.paused = false
	game.debug_open = false
	game.rearm_hold = false
	game.intro_active = false
	game.pause_panel.hide()
	game.debug_panel.hide()
	game.intro_panel.hide()
	game.pointer_held = false
	game.rules.setup(seed_value)
	game._consume_events()
	game._update_ui()
func reach_ring(keep_held := false) -> void:
	var found := false
	for i in 100:
		if not game.rules.predict_slam_contact().is_empty():
			button(true)
			if not keep_held: button(false)
			found = true
			break
		step()
	check(found,"visible fish opportunity")
	for i in 100:
		if game.rules.state != "diving": break
		step()
	check(game.rules.state == "bite_window","real first tap reaches ring")
func align_ring() -> void:
	for i in 100:
		if game.rules.ring_elapsed >= game.rules.ring_duration: return
		step()
func finish_flight() -> void:
	for i in 120:
		if game.rules.state == "recast_window": return
		step()
	check(false,"flight completed before timeout")
func run() -> void:
	root.size = Vector2i(360,640)
	game = Main.new()
	game.test_mode = true
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	check(not game.intro_active and game.rules.state == "casting","tests skip intro and auto cast")
	# Intro's one opening tap starts time, never serves as the gameplay dive.
	game.intro_active = true
	game.intro_panel.show()
	var frozen: Dictionary = game.rules.snapshot()
	step(60)
	check(game.rules.snapshot() == frozen,"intro freezes cast")
	tap()
	check(not game.intro_active and game.rules.state == "casting","opening tap does not dive")
	reset()
	reach_ring()
	button(false)
	check(game.rules.state == "bite_window","release never hooks or fails")
	key(KEY_UP)
	check(game.rules.state == "bite_window","old flick key cannot hook")
	align_ring()
	tap()
	check(game.rules.state == "hookset","second tap at alignment hooks")
	finish_flight()
	check(game.rules.catches == 1 and game.rules.score > 0,"exactly one basket score")
	step(12)
	check(game.rules.state == "casting","next cast automatic without input")
	reset()
	reach_ring(true)
	button(true)
	check(game.rules.state == "bite_window","held repeated down cannot count as second tap")
	step(100)
	check(game.rules.state == "game_over" and game.rules.final_reason == "hook_late","held input times out rather than auto hooks")
	frozen = game.rules.snapshot()
	step(200)
	check(game.rules.snapshot() == frozen,"game over freezes score physics fish and time")
	button(true)
	check(game.rules.state == "game_over","held failure cannot restart")
	button(false)
	tap(Vector2(180,420))
	check(game.rules.state == "casting" and game.rules.score == 0,"result card click passes through and restarts once")
	reset()
	reach_ring()
	tap()
	check(game.rules.state == "game_over" and game.rules.final_reason == "hook_early","early ring tap ends run")
	reset()
	reach_ring()
	key(KEY_ESCAPE)
	frozen = game.rules.snapshot()
	step(100)
	tap()
	key(KEY_UP)
	check(game.rules.snapshot() == frozen,"pause blocks physics and gameplay input")
	key(KEY_ESCAPE)
	align_ring()
	tap()
	check(game.rules.state == "hookset","pause resume retains normal second tap")
	finish_flight()
	check(game.rules.catches == 1,"post pause catch completes")
	reset()
	reach_ring()
	key(KEY_F1)
	frozen = game.rules.snapshot()
	step(100)
	tap()
	check(game.rules.snapshot() == frozen,"debug freezes gameplay and input")
	key(KEY_F1)
	align_ring()
	tap()
	finish_flight()
	check(game.rules.catches == 1,"debug close keeps second tap working")
	# An unrelated flight click must not be carried into the next cast.
	reset()
	reach_ring()
	align_ring()
	tap()
	for i in 60:
		if game.rules.state == "launch": break
		step()
	button(true)
	finish_flight()
	step(12)
	button(true)
	check(game.rules.state == "casting","flight hold does not auto-dive next cast")
	button(false)
	button(true)
	check(game.rules.state == "diving","fresh edge after flight hold dives")
	button(false)
	check(game.rules.state == "diving","release during dive never fails")
	# Slider's ±ms must be the actual small-fish timing half-window.
	reset()
	game.sliders.hook_window_ms.value = 180.0
	reach_ring()
	check(game.rules.fish_kind < 2 and is_equal_approx(game.rules.ring_window,0.18),"small fish UI ±180ms equals rules half-window")
	check(game.tune_labels.hook_window_ms.text.contains("180"),"tuning label displays actual value")
	game.queue_free()
	game = null
	await process_frame
	print("ARCADE TWO-TAP INTEGRATION: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
