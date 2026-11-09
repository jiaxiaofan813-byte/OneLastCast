class_name ArcadeMusicController
extends Node
## Two retained user tracks; linear crossfade avoids summed gain above unity.
const TRACK_PATHS := ["res://assets/music/Lakeside Arcade.ogg", "res://assets/music/Lakeside Arcade-2.ogg"]
const CROSSFADE_SECONDS := 2.0
var enabled := true
var music_volume := 0.4
## 0 = normal, 1 = fully ducked. Muting never resets playback.
var duck_amount := 0.0
var _players: Array[AudioStreamPlayer] = []
var _streams: Array[AudioStream] = []
var _active := 0
var _fading := false
var _fade_elapsed := 0.0
var _changeovers := 0
var _running := false

func setup() -> bool:
	if _running:
		return true
	stop_all()
	for path in TRACK_PATHS:
		# Optional local music is deliberately excluded from the public archive.
		if not ResourceLoader.exists(path):
			stop_all()
			return false
		var stream := load(path) as AudioStream
		if stream == null or stream.get_length() <= CROSSFADE_SECONDS:
			push_error("Music unavailable or too short: " + path)
			stop_all()
			return false
		if stream is AudioStreamOggVorbis:
			stream.loop = false
		_streams.append(stream)
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = -80.0
		add_child(player)
		_players.append(player)
	_active = 0
	_fading = false
	_fade_elapsed = 0.0
	_changeovers = 0
	_running = true
	_apply_gains()
	_players[_active].play()
	set_process(true)
	return true

func set_enabled(value: bool) -> void:
	enabled = value
	_apply_gains()

func set_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_gains()

func set_duck(value: float) -> void:
	duck_amount = clampf(value, 0.0, 1.0)
	_apply_gains()

func _process(delta: float) -> void:
	if not _running:
		return
	if _fading:
		_fade_elapsed = minf(_fade_elapsed + delta, CROSSFADE_SECONDS)
		if _fade_elapsed >= CROSSFADE_SECONDS:
			_players[_active].stop()
			_active = 1 - _active
			_fading = false
			_fade_elapsed = 0.0
			_changeovers += 1
	else:
		var player := _players[_active]
		var remaining := _streams[_active].get_length() - player.get_playback_position()
		if remaining <= CROSSFADE_SECONDS or not player.playing:
			_fading = true
			_fade_elapsed = 0.0
			_players[1 - _active].play()
	_apply_gains()

func _apply_gains() -> void:
	var base := music_volume * (1.0 - duck_amount) if enabled else 0.0
	for i in range(_players.size()):
		var weight := 1.0 if i == _active else 0.0
		if _fading:
			var progress := clampf(_fade_elapsed / CROSSFADE_SECONDS, 0.0, 1.0)
			weight = 1.0 - progress if i == _active else progress
		var gain := base * weight
		_players[i].volume_db = linear_to_db(gain) if gain > 0.00001 else -80.0

func stop_all() -> void:
	_running = false
	set_process(false)
	for player in _players:
		player.stop()
		player.stream = null
		player.queue_free()
	_players.clear()
	_streams.clear()
	_fading = false
	_fade_elapsed = 0.0

func _exit_tree() -> void:
	stop_all()

func get_status() -> Dictionary:
	var positions: Array[float] = []
	var durations: Array[float] = []
	var playing: Array[bool] = []
	var gains: Array[float] = []
	for player in _players:
		positions.append(player.get_playback_position())
		playing.append(player.playing)
		gains.append(db_to_linear(player.volume_db))
	for stream in _streams:
		durations.append(stream.get_length())
	return {"running": _running, "enabled": enabled, "volume": music_volume,
		"duck_amount": duck_amount, "active_track": _active, "crossfading": _fading,
		"crossfade_seconds": CROSSFADE_SECONDS, "fade_elapsed": _fade_elapsed,
		"changeovers": _changeovers, "positions": positions, "durations": durations,
		"playing": playing, "gains": gains, "track_paths": TRACK_PATHS.duplicate()}
