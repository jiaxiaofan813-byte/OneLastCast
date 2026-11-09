extends SceneTree
const Music = preload("res://scripts/arcade/music_controller.gd")
var failures := 0
func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var music = Music.new()
	root.add_child(music)
	check(music.setup(), "setup")
	var initial: Dictionary = music.get_status()
	check(initial.durations.size() == 2, "both loaded")
	check(absf(initial.durations[0] - 94.96) < 0.1, "track 1 duration")
	check(absf(initial.durations[1] - 111.20) < 0.1, "track 2 duration")
	await create_timer(0.3).timeout
	check(music.get_status().positions[0] > 0.1, "first advances")
	# Exercise actual audio players near their ends without waiting full songs.
	for outgoing in [0, 1]:
		music._players[outgoing].seek(music._streams[outgoing].get_length() - 2.05)
		await create_timer(0.2).timeout
		check(music.get_status().crossfading, "crossfade started")
		await create_timer(0.8).timeout
		var middle: Dictionary = music.get_status()
		check(middle.playing[0] and middle.playing[1], "both play during overlap")
		check(middle.positions[1 - outgoing] > 0.5, "incoming advances")
		check(absf(middle.gains[0] + middle.gains[1] - 0.4) < 0.001, "linear gain sum")
		check(middle.fade_elapsed > 0.7 and middle.fade_elapsed < 1.3, "measured fade progress")
		await create_timer(1.2).timeout
		check(music.get_status().active_track == 1 - outgoing, "alternating changeover")
		check(not music.get_status().crossfading, "2 second crossfade completes")
	check(music.get_status().changeovers == 2, "two changes")
	music.set_enabled(false)
	check(music.get_status().gains[0] < 0.001, "mute")
	music.set_enabled(true)
	music.set_volume(2.0)
	check(music.music_volume == 1.0, "volume clamp")
	music.set_volume(0.4)
	music.set_duck(0.75)
	check(absf(music.get_status().gains[0] - 0.1) < 0.001, "duck amount")
	music.stop_all()
	check(music.get_status().durations.is_empty(), "released streams")
	check(music.get_status().playing.is_empty(), "released players")
	check(music.setup(), "restart after stop")
	music.stop_all()
	music.queue_free()
	await process_frame
	# Audio server releases stopped playback on subsequent mix cycles.
	await create_timer(0.3).timeout
	print("MUSIC TEST failures=", failures)
	quit(0 if failures == 0 else 1)
