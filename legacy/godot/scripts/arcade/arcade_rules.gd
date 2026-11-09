class_name ArcadeRules
extends RefCounted
const FishGeometry = preload("res://scripts/arcade/fish_geometry.gd")
## Deterministic, renderer-free one-thumb arcade simulation. Coordinates are points.
const WATER_Y := 288.0
const LURE_START := Vector2(105, 214)
const BASKET := Vector2(37, 246)
const SPECIES := ["BLUEGILL", "SUNFISH", "BLACK CRAPPIE", "YELLOW PERCH", "LARGEMOUTH BASS", "WALLEYE", "TROPHY BASS", "NORTHERN PIKE"]
const GRAVITY := 640.0
const SNAPSHOT_VERSION := 4
const ROW_Y := [340.0, 397.0, 454.0, 511.0] # Legacy only; renderer uses row_positions.
const ACTIVE_SPECIES := ["bluegill", "pumpkinseed", "black_crappie", "yellow_perch", "largemouth_bass", "walleye", "northern_pike", "smallmouth_bass", "spotted_bass", "white_bass", "striped_bass", "rock_bass", "white_crappie", "green_sunfish", "redear_sunfish", "longear_sunfish", "channel_catfish", "blue_catfish", "brook_trout", "rainbow_trout"]
const SPECIES_KINDS := [0, 1, 2, 3, 4, 5, 7, 4, 4, 3, 6, 2, 2, 1, 1, 1, 5, 7, 3, 5]
const ROW_POOLS := [[0, 1, 13, 14, 15], [11, 2, 12, 3, 9], [18, 19, 7], [4, 8, 5], [16, 6], [10, 17], [6, 17, 10]]
var row_positions: Array[float] = [340.0, 397.0]
var journey_thresholds: Array[int] = [0, 3, 7, 12, 18, 25]
var depth_meters := 2.0
var boat_distance := 0.0
var fish_species_id := "bluegill"
var _row_spawns: Dictionary = {}
var fish_school: Array[Dictionary] = []
var floor_y := 425.0
var bottom_items: Array[Dictionary] = []
var catch_category := "fish"
var salvage_combo_policy := "preserve"
var _next_item_id := -1
var best_run_combo := 0
var final_reason := ""
var _next_fish_id := 1
var _school_rows := 2
var _water_entered := false
var _seed_value := 1
var _contact_id := -1
var ring_duration := 0.75
var ring_elapsed := 0.0
var ring_progress := 0.0
var ring_target_radius := 20.0
var ring_timing_grade := ""
var ring_window_before := 0.15
var ring_window_after := 0.15
var ring_failure_policy := "game_over"
var ring_window := 0.18
var _ring_expired := false
var _ring_decided := false
var _ring_aligned := false
var state := "idle"
var time := 0.0
var state_time := 0.0
var held := false
var slam_armed := false
var lure_pos := LURE_START
var lure_velocity := Vector2.ZERO
var target_x := 210.0
var landing_grade := ""
var combo := 0
var fever := false
var score := 0
var catches := 0
var fish_kind := 0
var fish_tier := 0
var fish_weight := 0.5
var fish_pos := Vector2.ZERO
var fish_velocity := Vector2.ZERO
var fish_scale := Vector2.ONE
var hitstop_left := 0.0
var duel_remaining := 0
var duel_total := 0
var duel_done := 0
var duel_flash := false
var cast_boost := 1.0
var bite_active := false
var bite_elapsed := 0.0
var last_cycle_seconds := 0.0
var events: Array[Dictionary] = []
var tune: Dictionary = {"dive_gravity": 3.2, "hook_window_ms": 180.0, "hitstop_frames": 3.0, "rod_stiffness": 18.0}
var _rng := RandomNumberGenerator.new()
var _cycle_start := 0.0
var _bite_delay := 0.6
var _bite_origin := Vector2.ZERO
var _flight_origin := Vector2.ZERO
var _flight_velocity := Vector2.ZERO
var _flight_gravity := 0.0
var _flight_duration := 0.9
var _recast_duration := 0.35
var _fish_multiplier := 1
var _basket_scored := false
var _next_flash := 0.15
var _flash_end := 0.0
var _hook_ready := false
var _failed := false

func setup(seed_value: int = 1) -> void:
	_seed_value = seed_value
	_rng.seed = seed_value
	state = "idle"
	best_run_combo = 0
	final_reason = ""
	ring_duration = 0.95
	ring_window = 0.18
	ring_window_before = ring_window
	ring_window_after = ring_window
	ring_target_radius = 20.0
	floor_y = 425.0
	row_positions = [340.0, 397.0]
	depth_meters = 2.0
	boat_distance = 0.0
	fish_species_id = "bluegill"
	_row_spawns.clear()
	combo = 0
	catches = 0
	_next_fish_id = 1
	_school_rows = 2
	_water_entered = false
	_contact_id = -1
	ring_elapsed = 0.0
	ring_progress = 0.0
	ring_timing_grade = ""
	_ring_expired = false
	_ring_decided = false
	_ring_aligned = false
	_cycle_start = 0.0
	_bite_delay = 0.12
	_bite_origin = Vector2.ZERO
	_flight_origin = Vector2.ZERO
	_flight_velocity = Vector2.ZERO
	_flight_gravity = 0.0
	_flight_duration = 0.9
	_recast_duration = 0.18
	_fish_multiplier = 1
	_next_flash = 0.15
	_flash_end = 0.0
	fish_school.clear()
	bottom_items.clear()
	_next_item_id = -1
	catch_category = "fish"
	bottom_items.append(_make_item("snail", 157.0))
	bottom_items.append(_make_item("weed", 285.0))
	for row in 2:
		for column in (5 if row == 0 else 4):
			fish_school.append(_make_fish(row, 80.0 + column * 59.0 + row * 21.0))
	time = 0.0
	state_time = 0.0
	held = false
	slam_armed = false
	combo = 0
	fever = false
	score = 0
	catches = 0
	lure_pos = LURE_START
	lure_velocity = Vector2.ZERO
	fish_pos = Vector2.ZERO
	fish_velocity = Vector2.ZERO
	fish_scale = Vector2.ONE
	hitstop_left = 0.0
	duel_remaining = 0
	duel_total = 0
	duel_done = 0
	duel_flash = false
	bite_active = false
	bite_elapsed = 0.0
	landing_grade = ""
	last_cycle_seconds = 0.0
	cast_boost = 1.0
	fish_kind = 0
	fish_tier = 0
	fish_weight = 0.5
	_basket_scored = false
	_failed = false
	_hook_ready = false
	events.clear()
	target_x = _rng.randf_range(126.0, 306.0)
	_emit("ready")
	_start_cast(1.0)

func _emit(kind: String, extra: Dictionary = {}) -> void:
	var event := {"type": kind, "time": time, "state": state, "pos": lure_pos, "combo": combo, "fever": fever, "category": catch_category, "species_id": fish_species_id if catch_category == "fish" else "", "species": fish_species_id.replace("_", " ").to_upper() if catch_category == "fish" else catch_category, "fish_kind": fish_kind, "fish_tier": fish_tier}
	event.merge(extra, true)
	events.append(event)

func _transition(next: String) -> void:
	var previous := state
	state = next
	state_time = 0.0
	_emit("transition", {"from": previous, "to": next})

func press() -> void:
	_emit("press", {"duplicate": held})
	if held:
		return
	held = true
	match state:
		"game_over":
			setup(_seed_value + 1)
			held = true
			_emit("restarted")
		"idle":
			_start_cast(1.0)
		"recast_window":
			pass # Automatic next cast; no queued input or third rhythm beat.
		"casting":
			lure_velocity.x = 0.0
			lure_velocity.y = maxf(900.0, lure_velocity.y)
			_transition("diving")
			_emit("slam")
		"bite_window":
			_try_hook()

func release() -> void:
	_emit("release", {"duplicate": not held})
	held = false

func flick() -> void:
	# Two-click mode has no release/flick hook action.
	_emit("flick", {"ignored": true})

func _start_cast(boost: float) -> void:
	boost = 1.0
	cast_boost = boost
	catch_category = "fish"
	_cycle_start = time
	lure_pos = LURE_START
	lure_velocity = Vector2(235.0 * 0.95 * boost, -330.0 * 0.95 * boost)
	slam_armed = not held
	bite_active = false
	bite_elapsed = 0.0
	landing_grade = ""
	fish_scale = Vector2.ONE
	fish_velocity = Vector2.ZERO
	duel_total = 0
	duel_done = 0
	duel_remaining = 0
	duel_flash = false
	_basket_scored = false
	_hook_ready = false
	_failed = false
	_water_entered = false
	_contact_id = -1
	target_x = _rng.randf_range(126.0, 306.0)
	_transition("casting")
	_emit("cast", {"boost": boost, "target_x": target_x, "slam_armed": slam_armed})


func tick(dt: float) -> void:
	if not is_finite(dt) or dt <= 0.0:
		return
	var remaining := dt
	while remaining > 0.0000001:
		var step := minf(remaining, 1.0 / 60.0)
		_step(step)
		remaining -= step

func _step(dt: float) -> void:
	if state == "game_over":
		return
	time += dt
	if hitstop_left > 0.0:
		hitstop_left = maxf(0.0, hitstop_left - dt)
		if hitstop_left <= 0.000001:
			hitstop_left = 0.0
			_emit("hitstop_release")
		return
	state_time += dt
	_advance_school(dt)
	_advance_bottom_items(dt)
	match state:
		"casting", "diving":
			var acceleration := GRAVITY * (clampf(float(tune.get("dive_gravity", 3.2)), 0.5, 8.0) if state == "diving" else 1.0)
			var previous := lure_pos
			lure_pos += lure_velocity * dt + Vector2(0, 0.5 * acceleration * dt * dt)
			lure_velocity.y += acceleration * dt
			if not _water_entered and lure_pos.y >= WATER_Y and lure_velocity.y > 0:
				_water_entered = true
				_emit("splash", {"pos": Vector2(lure_pos.x, WATER_Y), "grade": "normal"})
				if state == "casting":
					_fail("empty_dive")
					return
			if state == "diving" and _water_entered:
				var contact := _first_contact(previous, lure_pos, dt)
				if not contact.is_empty():
					if contact.get("is_item", false):
						_contact_item(contact)
					else:
						_contact_fish(contact)
				elif lure_pos.y >= floor_y:
					_fail("empty_dive")
		"bite_window":
			ring_elapsed += dt
			ring_progress = clampf(ring_elapsed / maxf(ring_duration, 0.01), 0.0, 1.0)
			bite_elapsed = ring_elapsed
			if not _ring_aligned and ring_elapsed >= ring_duration:
				_ring_aligned = true
				_emit("ring_aligned", {"pos": fish_pos})
			if not _ring_expired and ring_elapsed > ring_duration + ring_window_after:
				_ring_expired = true
				_resolve_ring("late")
		"hookset":
			if not _hook_ready:
				_hook_ready = true
				if duel_remaining > 0:
					_transition("tug_of_war")
					_next_flash = 0.15
					_emit("duel_start", {"total": duel_total})
					return
			fish_pos += fish_velocity * dt
			lure_pos = fish_pos
			if fish_pos.y <= WATER_Y:
				_breach()
		"tug_of_war":
			fish_pos = lure_pos + Vector2(sin(state_time * 16.0) * 12.0, 10 + state_time * 18.0)
			if not duel_flash and state_time >= _next_flash:
				duel_flash = true
				_flash_end = state_time + 0.32
				_emit("duel_flash", {"beat": duel_done + 1, "deadline": _flash_end})
			if (duel_flash and state_time > _flash_end) or state_time > 1.5:
				_fail("missed_counter")
		"launch":
			var t := minf(state_time, _flight_duration)
			fish_pos = _flight_origin + _flight_velocity * t + Vector2(0, 0.5 * _flight_gravity * t * t)
			fish_velocity = _flight_velocity + Vector2(0, _flight_gravity * t)
			fish_scale = Vector2.ONE + Vector2(0.4, -0.3) * exp(-t * 7.0) * cos(t * 18.0)
			if state_time >= _flight_duration:
				_basket()
		"recast_window":
			if state_time >= _recast_duration:
				_start_cast(1.0)

func _make_fish(row: int, x: float) -> Dictionary:
	var pool: Array = ROW_POOLS[row]
	if row == 1 and catches < 3:
		pool = [0, 1, 13, 14, 15]
	var serial := int(_row_spawns.get(row, 0))
	var species_index: int = pool[serial % pool.size()]
	_row_spawns[row] = serial + 1
	var kind: int = SPECIES_KINDS[species_index]
	var tier: int = FishGeometry.tier_for(ACTIVE_SPECIES[species_index])
	var direction := 1.0 if row % 2 == 0 else -1.0
	var fish := {"id": _next_fish_id, "kind": kind, "species_id": ACTIVE_SPECIES[species_index], "tier": tier, "row": row,
		"pos": Vector2(x, row_positions[row]), "velocity": Vector2(direction * _rng.randf_range([17.0, 28.0, 44.0, 65.0][tier], [27.0, 42.0, 64.0, 88.0][tier]), 0),
		"radius": FishGeometry.radius_for(ACTIVE_SPECIES[species_index]),
		"weight": snappedf(_rng.randf_range([0.3, 1.0, 3.0, 8.0][tier], [0.9, 2.5, 7.0, 18.0][tier]), 0.1),
		"multiplier": [1, 2, 4, 8][tier]}
	fish["previous_pos"] = fish.pos
	fish["motion_clock"] = _rng.randf_range(0.0, TAU)
	fish["turn_left"] = _rng.randf_range(1.2, 2.2)
	fish["turn_warning"] = false
	_next_fish_id += 1
	return fish

## Progress is based on banked fish, not combo, elapsed time or salvage.
func difficulty_progress() -> float:
	return clampf(float(catches - 12) / 33.0, 0.0, 1.0)

func _target_row_count(row: int) -> int:
	# Reduce one row at a time. Existing fish retire only by catch/normal edge exit.
	# These are population caps, including fish approaching from beyond the edge.
	if _school_rows == 2:
		return 5 if row == 0 else 4
	if row == 0:
		return 4 if catches < 12 else (3 if catches < 25 else 2)
	if row == 1:
		return 4 if catches < 7 else (3 if catches < 18 else (2 if catches < 25 else 1))
	if row == 2:
		return 2 if catches < 25 else 1
	if row == 3:
		return 2 if catches < 18 else 1
	return 1

func _entry_spacing(row: int) -> float:
	if _school_rows == 2:
		return 75.0
	# A continuous ramp makes the spaces open up between the population milestones.
	return lerpf(115.0, 155.0, difficulty_progress()) if row < 2 else lerpf(170.0, 210.0, difficulty_progress())

func _population_cap() -> int:
	if catches < 18: return 9999 # Early rows keep their per-row introductory population.
	if catches < 25: return 9
	if catches < 32: return 8
	if catches < 45: return 7
	return 6 # Mature floor: fewer fish caused invisible-only opportunities in QA.

func _refill_school() -> void:
	# Reserve two slow surface fish and one medium fish in the late game. Remaining
	# slots rotate through unlocked deep rows; empty rows are intentional open water.
	# This runs after natural exits/captures, never in response to aiming or misses.
	for row in mini(2, _school_rows):
		for attempt in _target_row_count(row):
			_spawn_at_edge(row)
	while fish_school.size() < _population_cap():
		var chosen := -1
		var fewest_spawns := 2147483647
		for row in range(2, _school_rows):
			var present := 0
			for fish in fish_school:
				if fish.row == row: present += 1
			if present < _target_row_count(row) and int(_row_spawns.get(row, 0)) < fewest_spawns:
				chosen = row
				fewest_spawns = int(_row_spawns.get(row, 0))
		if chosen < 0: break
		_spawn_at_edge(chosen)

func _spawn_at_edge(row: int) -> void:
	if fish_school.size() >= _population_cap(): return
	var present := 0
	for fish in fish_school:
		if fish.row == row: present += 1
	if present >= _target_row_count(row): return
	var x := -38.0 if row % 2 == 0 else 398.0
	# Queue fish behind earlier entrants rather than stacking three on one spot.
	for fish in fish_school:
		if fish.row == row:
			x = minf(x, fish.pos.x - _entry_spacing(row)) if row % 2 == 0 else maxf(x, fish.pos.x + _entry_spacing(row))
	fish_school.append(_make_fish(row, x))

func _layout_for(rows: int) -> Array:
	match rows:
		2: return [340.0, 397.0]
		3: return [334.0, 390.0, 446.0]
		4: return [324.0, 378.0, 432.0, 486.0]
		5: return [318.0, 361.0, 404.0, 447.0, 490.0]
		6: return [315.0, 353.0, 391.0, 429.0, 467.0, 505.0]
		_: return [313.0, 345.0, 377.0, 409.0, 441.0, 473.0, 505.0]

func _update_journey(dt: float) -> void:
	boat_distance += dt * 5.0
	depth_meters = move_toward(depth_meters, 2.0 + minf(catches * 0.35, 25.0), dt * 0.3)
	if state in ["diving", "bite_window"]: return
	var desired := 2
	for i in journey_thresholds.size():
		if catches >= journey_thresholds[i]: desired = mini(7, i + 2)
	while _school_rows < desired:
		_school_rows += 1
		var layout := _layout_for(_school_rows)
		row_positions.append(float(layout[-1]))
		for i in _target_row_count(_school_rows - 1): _spawn_at_edge(_school_rows - 1)
	var target := _layout_for(_school_rows)
	for row in row_positions.size():
		row_positions[row] = move_toward(row_positions[row], target[row], dt * 12.0)
	floor_y = move_toward(floor_y, minf(539.0, float(target[-1]) + (34.0 if _school_rows >= 6 else 28.0)), dt * 24.0)

func _vertical_amplitude(fish: Dictionary) -> float:
	var gap := 57.0
	if row_positions.size() > 2: gap = absf(row_positions[1] - row_positions[0])
	return minf(18.0 if int(fish.get("tier", 0)) == 3 else 12.0, maxf(3.0, (gap - 22.0) * 0.5))

func _advance_school(dt: float) -> void:
	var old_rows := row_positions.duplicate()
	_update_journey(dt)
	for fish in fish_school:
		fish["previous_pos"] = fish.pos
		if fish.row < old_rows.size(): fish.pos.y += row_positions[fish.row] - old_rows[fish.row]
		# Once a dive begins, preserve the visible velocity until contact/floor.
		# No surprise turn or phase change can evade an already aimed hook.
		if state != "diving":
			if fish.get("species_id", "") in ["largemouth_bass", "smallmouth_bass", "spotted_bass", "striped_bass"] and fish.pos.x >= 0.0 and fish.pos.x <= 360.0:
				fish["turn_left"] = float(fish.get("turn_left", 1.8)) - dt
				fish["turn_warning"] = fish.turn_left <= 0.2
				if fish.turn_left <= 0.0:
					fish.velocity.x *= -1.0
					fish.turn_left += 1.8
					fish.turn_warning = false
			elif fish.get("species_id", "") in ["walleye", "northern_pike", "blue_catfish", "rainbow_trout"]:
				var phase: float = fish.get("motion_clock", 0.0)
				var amplitude := _vertical_amplitude(fish)
				var next_phase := phase + dt * 2.0
				var next_y := clampf(fish.pos.y + (sin(next_phase) - sin(phase)) * amplitude, row_positions[fish.row] - amplitude, minf(row_positions[fish.row] + amplitude, floor_y - fish.radius.y))
				fish.velocity.y = (next_y - fish.pos.y) / dt
				fish.motion_clock = next_phase
		fish.pos += fish.velocity * dt
		# Keep even locked vertical trajectories within their visible row.
		if fish.get("species_id", "") in ["walleye", "northern_pike", "blue_catfish", "rainbow_trout"]:
			var amplitude := _vertical_amplitude(fish)
			fish.pos.y = clampf(fish.pos.y, row_positions[fish.row] - amplitude, minf(row_positions[fish.row] + amplitude, floor_y - fish.radius.y))
	var exited: Array[Dictionary] = []
	for fish in fish_school:
		if (fish.velocity.x > 0 and fish.pos.x > 410.0) or (fish.velocity.x < 0 and fish.pos.x < -50.0):
			exited.append(fish)
	for fish in exited:
		fish_school.erase(fish)
		if catches < 18: _spawn_at_edge(fish.row)
	if not exited.is_empty() and catches >= 18:
		_refill_school()

func _make_item(kind: String, x: float) -> Dictionary:
	var item := {"id": _next_item_id, "kind": kind, "category": kind,
		"pos": Vector2(x, floor_y - 9.0), "previous_pos": Vector2(x, floor_y - 9.0),
		"velocity": Vector2(4.0 if kind == "snail" else -5.0, 0),
		"radius": Vector2(12, 9) if kind == "snail" else Vector2(10, 13)}
	_next_item_id -= 1
	return item

func _advance_bottom_items(dt: float) -> void:
	var exited: Array[Dictionary] = []
	for item in bottom_items:
		item.previous_pos = item.pos
		item.pos += item.velocity * dt
		# If the lake deepens, visible debris settles rather than teleporting.
		if state not in ["diving", "bite_window"]:
			item.pos.y = move_toward(item.pos.y, floor_y - 9.0, dt * 18.0)
		if item.pos.x < -30.0 or item.pos.x > 390.0:
			exited.append(item)
	for item in exited:
		bottom_items.erase(item)
		bottom_items.append(_make_item(item.kind, -20.0 if item.velocity.x > 0 else 380.0))

func _contact_item(contact: Dictionary) -> void:
	var item: Dictionary = contact.fish
	catch_category = item.category
	fish_species_id = ""
	_contact_id = item.id
	fish_kind = 0
	fish_tier = 0 # Compatibility only; category is authoritative for rendering/statistics.
	fish_weight = 0.0
	_fish_multiplier = 0
	fish_pos = contact.center
	fish_velocity = Vector2.ZERO
	lure_pos = contact.pos
	lure_velocity = Vector2.ZERO
	bottom_items.erase(item)
	bottom_items.append(_make_item(item.kind, -20.0 if item.velocity.x > 0 else 380.0))
	if salvage_combo_policy == "reset":
		combo = 0
		fever = false
	landing_grade = "salvage"
	bite_active = true
	ring_elapsed = 0.0
	ring_progress = 0.0
	ring_timing_grade = ""
	ring_target_radius = maxf(item.radius.x, item.radius.y)
	ring_duration = 0.95
	ring_window = clampf(float(tune.get("hook_window_ms", 180.0)), 80.0, 250.0) / 1000.0
	ring_window_before = ring_window
	ring_window_after = ring_window
	_ring_expired = false
	_ring_decided = false
	_ring_aligned = false
	duel_total = 0
	duel_remaining = 0
	_transition("bite_window")
	_emit("item_contact", {"id": _contact_id, "category": catch_category, "fish_pos": fish_pos})
	_emit("bite", {"category": catch_category, "ring_duration": ring_duration})

## Swept relative segment versus ellipse, earliest entry across all fish.
func _first_contact(start: Vector2, finish: Vector2, dt: float) -> Dictionary:
	var earliest := 2.0
	var found: Dictionary = {}
	for fish in fish_school + bottom_items:
		var old_center: Vector2 = fish.get("previous_pos", fish.pos - fish.velocity * dt)
		var actual_delta: Vector2 = fish.pos - old_center
		var offset: Vector2 = (start - old_center) / fish.radius
		var delta: Vector2 = ((finish - start) - actual_delta) / fish.radius
		var a := delta.dot(delta)
		var b := 2.0 * offset.dot(delta)
		var c := offset.dot(offset) - 1.0
		var fraction := 2.0
		if c <= 0.0:
			fraction = 0.0
		elif a > 0.0000001:
			var discriminant := b * b - 4.0 * a * c
			if discriminant >= 0.0:
				fraction = (-b - sqrt(discriminant)) / (2.0 * a)
		if fraction >= 0.0 and fraction <= 1.0 and fraction < earliest:
			earliest = fraction
			found = {"fish": fish, "is_item": fish.has("category"), "fraction": fraction, "pos": start.lerp(finish, fraction), "center": old_center + actual_delta * fraction}
	return found

func _contact_fish(contact: Dictionary) -> void:
	catch_category = "fish"
	var fish: Dictionary = contact.fish
	_contact_id = fish.id
	fish_kind = fish.kind
	fish_species_id = fish.get("species_id", ACTIVE_SPECIES[0])
	fish_tier = int(fish.get("tier", FishGeometry.tier_for(fish_species_id)))
	fish_weight = fish.weight
	_fish_multiplier = fish.multiplier
	fish_pos = contact.center
	fish_velocity = Vector2.ZERO
	lure_pos = contact.pos
	lure_velocity = Vector2.ZERO
	fish_school.erase(fish)
	combo += 1
	best_run_combo = maxi(best_run_combo, combo)
	fever = combo >= 10
	# Replacement starts beyond the visible edge, never at the hook.
	if catches < 18: _spawn_at_edge(fish.row)
	else: _refill_school()
	landing_grade = "contact"
	_bite_delay = 0.0
	_bite_origin = lure_pos
	bite_active = true
	ring_elapsed = 0.0
	ring_progress = 0.0
	ring_timing_grade = ""
	ring_target_radius = maxf(fish.radius.x, fish.radius.y)
	var tier: int = fish_tier
	ring_duration = [0.95, 0.82, 0.68, 0.55][tier]
	# Only the highest-value deep fish (x8, canonical tier 3) gain a faster ring.
	# Small/medium/heavy fish and the forgiving salvage timing stay unchanged.
	if tier == 3 and int(fish.row) >= 4:
		ring_duration = lerpf(0.55, 0.40, difficulty_progress())
	ring_window = [0.18, 0.15, 0.12, 0.10][tier] * clampf(float(tune.get("hook_window_ms", 180.0)), 80.0, 250.0) / 180.0
	ring_window_before = ring_window
	ring_window_after = ring_window
	_ring_expired = false
	_ring_decided = false
	_ring_aligned = false
	duel_total = 0
	duel_remaining = duel_total
	duel_done = 0
	_transition("bite_window")
	_emit("fish_contact", {"id": _contact_id, "weight": fish_weight, "fish_pos": fish_pos})
	_emit("bite", {"ring_duration": ring_duration})

## QA-only forward simulation: no mutation, no aiming assistance in actual gameplay.
func predict_slam_contact() -> Dictionary:
	if state != "casting" or held:
		return {}
	var future = get_script().new()
	if not future.restore(snapshot()):
		return {}
	future.events.clear()
	future.press()
	var started: float = future.time
	for i in 240:
		future.tick(1.0 / 60.0)
		if future.state == "bite_window":
			return {"id": future._contact_id, "category": future.catch_category, "species_id": future.fish_species_id, "kind": future.fish_kind, "pos": future.lure_pos, "seconds": future.time - started}
		if future.state == "game_over":
			return {}
		future.events.clear()
	return {}

func _grace_end() -> float:
	return maxf(clampf(float(tune.get("hook_window_ms", 450)), 150.0, 1000.0) / 1000.0 + 0.05, 0.5)

func _try_hook() -> void:
	var offset := ring_elapsed - ring_duration
	var grade := "perfect" if offset >= -ring_window_before and offset <= ring_window_after else ("early" if offset < 0 else "late")
	_resolve_ring(grade)

func _resolve_ring(grade: String) -> void:
	if _ring_decided:
		return
	_ring_decided = true
	ring_timing_grade = grade
	_emit("ring_judgement", {"grade": grade, "offset": ring_elapsed - ring_duration})
	if grade != "perfect":
		if ring_failure_policy == "game_over":
			_fail("hook_early" if grade == "early" else "hook_late")
		elif ring_failure_policy == "retry":
			_transition("recast_window")
			_recast_duration = 0.18
		# Pending leaves judgment visible without inventing the user's penalty.
		return
	if catch_category == "fish":
		combo += 1
	best_run_combo = maxi(best_run_combo, combo)
	fever = combo >= 10
	hitstop_left = clampf(float(tune.get("hitstop_frames", 3)), 0.0, 12.0) / 60.0
	fish_velocity = Vector2(0, -1400)
	_hook_ready = false
	_transition("hookset")
	_emit("hookset", {"grade": grade, "timing": ring_elapsed, "hitstop": hitstop_left})

func _begin_impulse() -> void:
	duel_flash = false
	fish_velocity = Vector2(0, -1400)
	_hook_ready = true
	_transition("hookset")
	_emit("impulse", {"velocity": fish_velocity})

func _breach() -> void:
	fish_pos.y = WATER_Y
	_flight_origin = fish_pos
	_flight_duration = 0.9
	_flight_velocity = Vector2((BASKET.x - fish_pos.x) / _flight_duration, -580.0)
	_flight_gravity = 2.0 * (BASKET.y - fish_pos.y - _flight_velocity.y * _flight_duration) / (_flight_duration * _flight_duration)
	fish_velocity = _flight_velocity
	fish_scale = Vector2(1.4, 0.7)
	_transition("launch")
	_emit("breach", {"pos": fish_pos, "velocity": fish_velocity})

func _basket() -> void:
	if _basket_scored or state == "game_over":
		return
	_basket_scored = true
	fish_pos = BASKET
	fish_scale = Vector2.ONE
	fish_velocity = Vector2.ZERO
	if catch_category == "fish":
		catches += 1
	var points := (100 * _fish_multiplier + combo * 10) if catch_category == "fish" else 0
	score += points
	last_cycle_seconds = time - _cycle_start
	_recast_duration = 0.18
	_failed = false
	_transition("recast_window")
	_emit("basket" if catch_category == "fish" else "junk_basket", {"category": catch_category,"pos": BASKET, "weight": fish_weight, "points": points, "score": score, "catches": catches, "cycle_seconds": last_cycle_seconds})
	_emit("recast", {"window": _recast_duration})

func _fail(reason: String) -> void:
	if state == "game_over":
		return
	best_run_combo = maxi(best_run_combo, combo)
	final_reason = reason
	hitstop_left = 0.0
	duel_flash = false
	duel_remaining = 0
	_failed = true
	_transition("game_over")
	_emit("fail", {"reason": reason, "max_combo": best_run_combo, "score": score, "catches": catches})

## Exact in-memory snapshot, including RNG and pending events. Vector2s are intentional.
func snapshot() -> Dictionary:
	var data := {"version": SNAPSHOT_VERSION, "rng_state": _rng.state, "rng_seed": _rng.seed}
	for property in get_property_list():
		var key: String = property.name
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and key != "_rng":
			var value: Variant = get(key)
			data[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return data

func restore(data: Dictionary) -> bool:
	if data.get("version", 0) != SNAPSHOT_VERSION or not data.has("rng_state"):
		return false
	# Require the full schema before changing anything. Never restore arbitrary properties.
	var current := snapshot()
	for key in current:
		if not data.has(key) or typeof(data[key]) != typeof(current[key]):
			return false
	if data.state not in ["idle", "casting", "diving", "bite_window", "hookset", "tug_of_war", "launch", "recast_window", "game_over"]:
		return false
	if data.combo < 0 or data.score < 0 or data.fish_kind < 0 or data.fish_kind > 7:
		return false
	for key in current:
		if key in ["version", "rng_state", "rng_seed"]:
			continue
		var value: Variant = data[key]
		set(key, value.duplicate(true) if value is Dictionary or value is Array else value)
	_rng.seed = data.rng_seed
	_rng.state = data.rng_state
	return true
