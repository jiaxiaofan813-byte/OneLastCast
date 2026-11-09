extends SceneTree
const Main = preload("res://scripts/arcade/arcade_main.gd")
const Music = preload("res://scripts/arcade/music_controller.gd")
var game
var failures := 0
var checks := 0
var temporary_dir := "res://runtime/tests-music-%d" % Time.get_ticks_usec()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)
func near(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) < 0.002, label)
func gain() -> float:
	return game.music_controller.get_status().gains[0]
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	game = Main.new()
	game.test_mode = true
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.haptics.enabled = false
	# _ready is intentionally unable to touch saves; redirect before any disk I/O.
	game.data_dir = temporary_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temporary_dir))
	check(not FileAccess.file_exists(game._settings_path()), "isolated settings start empty")
	game._build_frontdoor()
	# Normal test mode suppresses music initialization: attach the same production module.
	game.music_controller = Music.new()
	game.add_child(game.music_controller)
	game.music_controller.set_enabled(game.music_enabled)
	game.music_controller.set_volume(game.music_volume)
	check(game.music_controller.setup(), "production controller loads")
	game.app_has_focus = true
	game.paused = false
	game._update_music_duck()
	near(gain(), 0.3, "title ducks by .25")
	await create_timer(0.6).timeout
	var before: float = game.music_controller.get_status().positions[0]
	check(before > 0.1, "audio clock advances")
	game.frontdoor.settings_changed.emit("music_volume", 0.6)
	near(gain(), 0.45, "settings signal changes actual gain")
	game.frontdoor.settings_changed.emit("music_enabled", false)
	check(gain() < 0.001, "settings signal mutes actual player")
	await create_timer(0.2).timeout
	check(game.music_controller.get_status().positions[0] > before, "muted playhead retained and advances")
	game.frontdoor.settings_changed.emit("music_enabled", true)
	near(gain(), 0.45, "unmute retains configured gain")
	game.frontdoor.start_requested.emit()
	game._update_music_duck()
	near(gain(), 0.6, "start signal restores gameplay gain")
	game.paused = true
	game._update_music_duck()
	near(gain(), 0.21, "pause ducks by .65")
	game.frontdoor.resume_requested.emit()
	game._update_music_duck()
	near(gain(), 0.6, "resume restores gain")
	game.catalog_open = true
	game._update_music_duck()
	near(gain(), 0.21, "catalog duck")
	game.catalog_open = false
	game.debug_open = true
	game._update_music_duck()
	near(gain(), 0.21, "debug menu duck")
	game.debug_open = false
	game.rules.state = "game_over"
	game._update_music_duck()
	near(gain(), 0.39, "game-over duck")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game._update_music_duck()
	check(gain() < 0.001, "focus loss silences music")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game._update_music_duck()
	near(gain(), 0.21, "focus restoration retains pause menu duck")
	game.frontdoor.resume_requested.emit()
	game._update_music_duck()
	near(gain(), 0.39, "resume restores end-state duck")
	# Save/load only after redirecting into the unique test directory.
	game.test_mode = false
	game.frontdoor.settings_changed.emit("music_volume", 0.37)
	game.frontdoor.settings_changed.emit("sfx_volume", 0.82)
	game.frontdoor.settings_changed.emit("music_enabled", false)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game._settings_path()))
	check(data.version == 4, "settings version 4")
	check(not data.music_enabled, "mute persisted")
	near(data.music_volume, 0.37, "music volume persisted")
	near(data.sfx_volume, 0.82, "independent effects volume persisted")
	check(not FileAccess.file_exists(game._settings_path() + ".tmp"), "atomic save completed")
	var fresh = Main.new()
	fresh.data_dir = temporary_dir
	fresh.test_mode = false
	fresh._load_settings()
	near(fresh.music_volume, 0.37, "fresh instance restores music volume")
	near(fresh.sfx_volume, 0.82, "fresh instance restores effects volume")
	check(not fresh.music_enabled, "fresh instance restores music mute")
	for values in [[2.0, -1.0, 1.0, 0.0], [-1.0, 2.0, 0.0, 1.0]]:
		var file := FileAccess.open(game._settings_path(), FileAccess.WRITE)
		file.store_string(JSON.stringify({"version":4,"music_enabled":true,"music_volume":values[0],"sfx_volume":values[1]}))
		file.close()
		fresh._load_settings()
		near(fresh.music_volume, values[2], "loaded music volume clamped")
		near(fresh.sfx_volume, values[3], "loaded effects volume clamped")
		check(fresh.muted == (fresh.sfx_volume <= 0), "effects mute agrees with volume")
	game.frontdoor.settings_changed.emit("music_volume", 5.0)
	near(game.music_volume, 1.0, "UI signal volume clamp")
	game.test_mode = true
	fresh.test_mode = true
	fresh.free()
	game.music_controller.stop_all()
	check(game.music_controller.get_status().positions.is_empty(), "shutdown releases audio references")
	for filename in ["arcade-settings.json", "catch-progress-v2.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_dir.path_join(filename)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_dir))
	game.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	print("Music integration: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
