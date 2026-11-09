class_name FishingRules
extends RefCounted
## Pure deterministic simulation. Coordinates and hit ellipses are body-only.
const SURFACE: float = 160.0
const START_Y: float = 172.0
const MAX_Y: float = 520.0
const X: float = 180.0
const STEP: float = 1.0 / 60.0
const SINK: float = 88.0
const RISE: float = 320.0
const WINDOW: float = 0.45
const HOOK_RADIUS: float = 9.0
const SNAPSHOT_VERSION: int = 1
const MAX_STEPS: int = 240
const MAX_BACKLOG: float = 10.0
const VALUES = [10, 25, 40]
const WEIGHTS = [1.0, 2.4, 1.4]
var mode: String = "B"
var state: String = "ready"
var time: float = 0.0
var hook_y: float = START_Y
var fish: Array[Dictionary] = []
var caught: Array[Dictionary] = []
var score: int = 0
var total_weight: float = 0.0
var round_id: int = 0
var round_seed: int = 0
var cast_time: float = -1.0
var result_summary: Dictionary = {}
var _accumulator: float = 0.0
var click_time: float = -1.0
var capture_left: float = 0.0
var events: Array[Dictionary] = []
var closed: bool = true
var _elapsed: float = 0.0
var _splash_left: float = 0.0

func setup(seed_value: int, selected_mode: String = "B") -> void:
	round_id += 1
	round_seed = seed_value
	mode = selected_mode
	state = "ready"
	time = 0.0
	hook_y = START_Y
	fish.clear()
	caught.clear()
	events.clear()
	score = 0
	total_weight = 0.0
	cast_time = -1.0
	result_summary = {}
	_accumulator = 0.0
	click_time = -1.0
	capture_left = 0.0
	closed = true
	_elapsed = 0.0
	_splash_left = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var kinds: Array[int] = [0, 0, 0, 0, 0, 1, 1, 1, 2]
	for j in range(kinds.size() - 1, 0, -1):
		var k: int = rng.randi_range(0, j)
		var old: int = kinds[j]
		kinds[j] = kinds[k]
		kinds[k] = old
	var lane_offsets: Array[float] = [rng.randf_range(-70, 70), rng.randf_range(-70, 70), rng.randf_range(-70, 70)]
	for i in range(9):
		var lane: int = i / 3
		var kind: int = kinds[i]
		var px: float = 65.0 + float(i % 3) * 100.0 + lane_offsets[lane] + rng.randf_range(-12.0, 12.0)
		var py: float = [264.0, 350.0, 444.0][lane] + rng.randf_range(-18.0, 18.0)
		var speed: float = [32.0, -25.0, 42.0][lane] * rng.randf_range(0.92, 1.08)
		fish.append({"id": i, "kind": kind, "x": px, "y": py, "prev_x": px, "prev_y": py,
			"vx": speed, "width": [32.0, 47.0, 36.0][kind], "height": [21.0, 37.0, 26.0][kind],
			"caught": false, "base_y": py, "phase": rng.randf_range(0.0, TAU)})

func act() -> void:
	if state == "result":
		prepare_next_round() # Reveal next school; a separate input casts it.
	elif state == "ready":
		cast_time = time
		state = "aiming" if mode == "A" else "sinking"
		hook_y = 330.0 if mode == "A" else START_Y
		events.append({"type": "cast", "round_id": round_id, "time": time, "seed": round_seed})
	elif state == "sinking" or state == "aiming":
		var aimed: bool = state == "aiming"
		state = "reeling"
		click_time = time
		_elapsed = 0.0
		capture_left = WINDOW
		closed = false
		events.append({"type": "reel", "y": hook_y, "time": time})
		if aimed:
			for f in fish:
				if not f.caught and _contact(Vector2(X - f.x, hook_y - f.y), Vector2.ZERO, f.width * 0.5 + HOOK_RADIUS, f.height * 0.5 + HOOK_RADIUS) == 0.0:
					_catch(f)
					break
			_close()

## Caller pauses by withholding tick. Inputs apply at the current simulation tick.
## At most 240 steps/call; at most 10s backlog. Invalid/zero deltas do nothing.
func tick(dt: float) -> void:
	if not is_finite(dt) or dt <= 0.0:
		return
	_accumulator = minf(MAX_BACKLOG, _accumulator + dt)
	var steps: int = mini(MAX_STEPS, int((_accumulator + 0.000000001) / STEP))
	for i in range(steps):
		_tick(STEP)
		_accumulator -= STEP
	_accumulator = maxf(0.0, _accumulator)

func prepare_next_round() -> bool:
	if state != "result":
		return false
	var summary: Dictionary = {"score": score, "weight": total_weight, "count": caught.size(),
		"fish": caught.duplicate(true), "round_id": round_id, "seed": round_seed,
		"cast_time": cast_time, "click_time": click_time}
	setup((round_seed + 104729) % 2147483647, mode)
	result_summary = summary
	return true

func export_snapshot() -> Dictionary:
	var ids: Array = []
	for f in caught: ids.append(f.id)
	return {"version": SNAPSHOT_VERSION, "mode": mode, "state": state, "time": time,
		"hook_y": hook_y, "fish": fish.duplicate(true), "caught_ids": ids,
		"score": score, "total_weight": total_weight, "round_id": round_id,
		"round_seed": round_seed, "cast_time": cast_time, "click_time": click_time,
		"capture_left": capture_left, "closed": closed, "elapsed": _elapsed,
		"splash_left": _splash_left, "accumulator": _accumulator,
		"events": events.duplicate(true), "result_summary": result_summary.duplicate(true)}

## Validate before changing live state. JSON round-trips convert integers to floats.
func restore_snapshot(data: Dictionary) -> bool:
	var template: Dictionary = export_snapshot()
	for key in template:
		if not data.has(key): return false
		var expected: int = typeof(template[key])
		var actual: int = typeof(data[key])
		if expected in [TYPE_INT, TYPE_FLOAT]:
			if actual not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data[key])): return false
		elif actual != expected: return false
	if data.version != SNAPSHOT_VERSION or data.mode not in ["A", "B"]: return false
	if data.state not in ["ready", "aiming", "sinking", "reeling", "splash", "result"]: return false
	if data.time < 0 or data.hook_y < SURFACE or data.hook_y > MAX_Y: return false
	if data.round_id < 1 or data.round_id != floor(data.round_id) or data.round_seed != floor(data.round_seed): return false
	if data.fish.size() > 64 or data.caught_ids.size() > 3 or data.events.size() > 128: return false
	if data.accumulator < 0 or data.accumulator > MAX_BACKLOG or data.elapsed < 0 or data.elapsed > WINDOW + STEP + 0.000001 or data.splash_left < -STEP or data.splash_left > 0.65: return false
	if data.capture_left < 0 or data.capture_left > WINDOW: return false
	if data.cast_time < -1 or data.cast_time > data.time or data.click_time < -1 or data.click_time > data.time: return false
	var by_id: Dictionary = {}
	var sum_score: int = 0
	var sum_weight: float = 0.0
	var captured_count: int = 0
	for f in data.fish:
		if not f is Dictionary: return false
		for key in ["id", "kind", "x", "y", "prev_x", "prev_y", "vx", "width", "height"]:
			if not f.has(key) or typeof(f[key]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(f[key])): return false
		if not f.has("caught") or typeof(f.caught) != TYPE_BOOL: return false
		if f.id != floor(f.id) or f.id < 0 or by_id.has(int(f.id)): return false
		if f.kind != floor(f.kind) or f.kind < 0 or f.kind > 2 or f.width <= 0 or f.height <= 0: return false
		for key in ["base_y", "phase"]:
			if f.has(key) and (typeof(f[key]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(f[key]))): return false
		if f.has("base_y") != f.has("phase"): return false
		by_id[int(f.id)] = f
		if f.caught:
			captured_count += 1
			sum_score += VALUES[int(f.kind)]
			sum_weight += WEIGHTS[int(f.kind)]
	var seen: Dictionary = {}
	for id in data.caught_ids:
		if typeof(id) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(id)) or id != floor(id): return false
		if seen.has(int(id)) or not by_id.has(int(id)) or not by_id[int(id)].caught: return false
		seen[int(id)] = true
	if captured_count != seen.size() or data.score != sum_score or not is_equal_approx(data.total_weight, sum_weight): return false
	var result_count: int = 0
	var event_fields: Dictionary = {"cast": ["round_id", "time", "seed"], "reel": ["y", "time"],
		"catch": ["fish_id", "kind", "x", "y", "value", "score"], "closed": ["count"],
		"splash": ["count", "score"], "result": ["score", "count", "weight"]}
	for event in data.events:
		if not event is Dictionary or not event.has("type") or not event.type is String: return false
		if not event_fields.has(event.type): return false
		for key in event_fields[event.type]:
			if not event.has(key) or typeof(event[key]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(event[key])): return false
		if event.type == "catch" and (event.kind < 0 or event.kind > 2 or event.kind != floor(event.kind)): return false
		if event.type == "result":
			result_count += 1
			if data.state != "result" or event.score != data.score or event.count != captured_count: return false
	if result_count > 1: return false
	if not data.result_summary.is_empty():
		for key in ["score", "weight", "count", "round_id", "seed", "cast_time", "click_time"]:
			if not data.result_summary.has(key) or typeof(data.result_summary[key]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data.result_summary[key])): return false
		if not data.result_summary.has("fish") or not data.result_summary.fish is Array: return false
		if data.result_summary.count != data.result_summary.fish.size() or data.result_summary.count > 3: return false
		var summary_score: int = 0
		var summary_weight: float = 0.0
		for f in data.result_summary.fish:
			if not f is Dictionary or not f.has("kind") or typeof(f.kind) not in [TYPE_INT, TYPE_FLOAT]: return false
			if not is_finite(float(f.kind)) or f.kind < 0 or f.kind > 2 or f.kind != floor(f.kind): return false
			summary_score += VALUES[int(f.kind)]
			summary_weight += WEIGHTS[int(f.kind)]
		if data.result_summary.score != summary_score or not is_equal_approx(data.result_summary.weight, summary_weight): return false
	if data.closed and data.capture_left != 0: return false
	if not data.closed and data.state != "reeling": return false
	if data.state in ["ready", "sinking", "aiming"] and captured_count != 0: return false
	mode = data.mode
	state = data.state
	time = data.time
	hook_y = data.hook_y
	fish.clear()
	caught.clear()
	for f in data.fish:
		var copy: Dictionary = f.duplicate(true)
		copy.id = int(copy.id)
		copy.kind = int(copy.kind)
		fish.append(copy)
	for id in data.caught_ids:
		for f in fish:
			if f.id == int(id): caught.append(f)
	score = int(data.score)
	total_weight = data.total_weight
	round_id = int(data.round_id)
	round_seed = int(data.round_seed)
	cast_time = data.cast_time
	click_time = data.click_time
	capture_left = data.capture_left
	closed = data.closed
	_elapsed = data.elapsed
	_splash_left = data.splash_left
	_accumulator = data.accumulator
	events.clear()
	for event in data.events: events.append(event.duplicate(true))
	result_summary = data.result_summary.duplicate(true)
	return true

func _tick(dt: float) -> void:
	time += dt
	for f in fish:
		f.prev_x = f.x
		f.prev_y = f.y
		if f.caught:
			continue
		f.x += f.vx * dt
		if f.x > 420.0:
			f.x -= 480.0
			f.prev_x = f.x
		elif f.x < -60.0:
			f.x += 480.0
			f.prev_x = f.x
		if f.has("base_y"):
			f.y = f.base_y + sin(time * 1.35 + f.phase) * 4.0
	if state == "sinking":
		hook_y = minf(MAX_Y, hook_y + SINK * dt)
		if hook_y >= MAX_Y:
			act()
	elif state == "reeling":
		var old_y: float = hook_y
		hook_y = maxf(SURFACE, hook_y - RISE * dt)
		if not closed:
			var available: float = minf(dt, maxf(0.0, WINDOW - _elapsed))
			var portion: float = available / dt
			var hits: Array[Dictionary] = []
			for f in fish:
				if f.caught:
					continue
				var relative := Vector2(X - f.prev_x, old_y - f.prev_y)
				var delta := Vector2(-(f.x - f.prev_x), hook_y - old_y - (f.y - f.prev_y)) * portion
				var hit: float = _contact(relative, delta, f.width * 0.5 + HOOK_RADIUS, f.height * 0.5 + HOOK_RADIUS)
				# End of capture window is excluded; ordinary step endpoints are included.
				if hit >= 0.0 and available > 0.0 and _elapsed + hit * available < WINDOW - 0.0000001:
					hits.append({"t": hit * available, "fish": f})
			hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				if absf(a.t - b.t) > 0.000000001:
					return a.t < b.t
				return a.fish.id < b.fish.id)
			for hit in hits:
				_catch(hit.fish)
				if caught.size() == 3:
					_close()
					break
			_elapsed += dt
			capture_left = maxf(0.0, WINDOW - _elapsed) if not closed else 0.0
			if _elapsed >= WINDOW - 0.000000001:
				_close()
		if hook_y <= SURFACE:
			_close()
			state = "splash"
			_splash_left = 0.35 if caught.is_empty() else 0.65
			events.append({"type": "splash", "count": caught.size(), "score": score})
	elif state == "splash":
		_splash_left -= dt
		if _splash_left <= 0.000000001:
			state = "result"
			events.append({"type": "result", "score": score, "count": caught.size(), "weight": total_weight})

func _catch(f: Dictionary) -> void:
	if f.caught:
		return
	f.caught = true
	caught.append(f)
	score += VALUES[f.kind]
	total_weight += WEIGHTS[f.kind]
	events.append({"type": "catch", "fish_id": f.id, "kind": f.kind, "x": f.x, "y": f.y, "value": VALUES[f.kind], "score": score})

func _close() -> void:
	if not closed:
		closed = true
		capture_left = 0.0
		events.append({"type": "closed", "count": caught.size()})

## First contact parameter on segment [0,1], or -1. Relative swept ellipse.
func _contact(p: Vector2, d: Vector2, rx: float, ry: float) -> float:
	var q := Vector2(p.x / rx, p.y / ry)
	var v := Vector2(d.x / rx, d.y / ry)
	var c: float = q.dot(q) - 1.0
	if c <= 0.0:
		return 0.0
	var a: float = v.dot(v)
	if a <= 0.000000000001:
		return -1.0
	var b: float = 2.0 * q.dot(v)
	var discriminant: float = b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0
	var t: float = (-b - sqrt(discriminant)) / (2.0 * a)
	return t if t >= 0.0 and t <= 1.0 else -1.0
