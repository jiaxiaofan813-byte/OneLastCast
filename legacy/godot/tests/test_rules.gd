extends SceneTree
const Rules = preload("res://scripts/fishing_rules.gd")
var failures: int = 0
var checks: int = 0

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func fixture(id: int, x: float, y: float, width: float = 40.0, height: float = 20.0) -> Dictionary:
	return {"id": id, "kind": 0, "x": x, "y": y, "prev_x": x, "prev_y": y, "vx": 0.0, "width": width, "height": height, "caught": false}

func _initialize() -> void:
	var a := Rules.new()
	var b := Rules.new()
	a.setup(713)
	b.setup(713)
	a.act()
	b.act()
	for i in range(300):
		if i == 121:
			a.act()
			b.act()
		a.tick(Rules.STEP)
		b.tick(Rules.STEP)
	expect(a.fish == b.fish and a.events == b.events and a.score == b.score, "seeded simulation and events reproduce")
	a.setup(1)
	a.fish = [fixture(0, 180, 250)]
	a.act()
	a.tick(2.0)
	expect(a.caught.is_empty() and a.score == 0, "sinking cannot catch")
	# Identical dense bodies: same contact time is ordered by ID, capped at three.
	a.setup(1)
	a.fish = [fixture(8, 180, 350), fixture(3, 180, 350), fixture(1, 180, 350), fixture(2, 180, 350)]
	a.act()
	a.hook_y = 350
	a.act()
	a.tick(Rules.STEP)
	expect(a.caught.size() == 3 and a.closed, "capacity three and immediate closure")
	expect(a.caught[0].id == 1 and a.caught[1].id == 2 and a.caught[2].id == 3, "simultaneous contacts use stable ID order")
	var before: float = a.click_time
	for i in range(100):
		a.act()
	expect(a.state == "reeling" and a.click_time == before, "dense repeated input ignored in flight")
	a.tick(1.5)
	expect(a.caught.size() == 3 and a.score == 30, "no duplicate catches")
	# Window begins y=500. At .45s y=356; inflated body's lower edge=356.
	a.setup(1)
	a.fish = [fixture(0, 180, 337)]
	a.act()
	a.hook_y = 500
	a.act()
	a.tick(0.6)
	expect(a.caught.is_empty() and a.closed, "window endpoint excluded")
	a.setup(1)
	a.fish = [fixture(0, 180, 337.1)]
	a.act()
	a.hook_y = 500
	a.act()
	a.tick(0.6)
	expect(a.caught.size() == 1, "contact just before endpoint included")
	a.setup(1)
	a.fish = [fixture(0, 180, 500)]
	a.act()
	a.hook_y = 500
	a.act()
	a.tick(Rules.STEP)
	expect(a.caught.size() == 1, "window start overlap included")
	# Early fish ID 9 wins chronological order over late ID 0.
	a.setup(1)
	a.fish = [fixture(0, 180, 478, 40, 2), fixture(9, 180, 488, 40, 2)]
	a.act()
	a.hook_y = 500
	a.act()
	a.tick(0.06)
	expect(a.caught.size() == 2 and a.caught[0].id == 9, "swept contacts sorted by actual contact time")
	var snapshot: String = JSON.stringify([a.time, a.hook_y, a.fish, a.events])
	# Pause means owner does not call tick; no wall-clock dependency exists.
	OS.delay_msec(30)
	expect(snapshot == JSON.stringify([a.time, a.hook_y, a.fish, a.events]), "pause by withholding tick is exact")
	expect(is_equal_approx(a._contact(Vector2(-100, 0), Vector2(200, 0), 20, 10), 0.4), "sweep prevents horizontal tunneling")
	expect(a._contact(Vector2(0, 20), Vector2(200, 0), 20, 10) < 0, "body ellipse rejects outside path")
	a.setup(1, "A")
	a.fish = [fixture(0, 180, 330), fixture(1, 180, 330)]
	a.act()
	expect(a.state == "aiming" and a.hook_y == 330, "A uses fixed aim depth")
	a.act()
	a.tick(2)
	expect(a.caught.size() == 1 and a.state == "result", "A instant catch max one and completes")
	var seed_before: int = a.round_seed
	a.act()
	expect(a.state == "ready" and a.round_seed != seed_before and not a.result_summary.is_empty(), "result input reveals next school without casting")
	a.setup(817)
	a.act()
	a.tick(4.0)
	expect(a.state == "reeling" and a.click_time > 0 and a.capture_left > 0, "bottom automatically reels using capture window")
	var counts: Array[int] = [0, 0, 0]
	var rare_lanes: Dictionary = {}
	for seed_value in range(50):
		a.setup(seed_value)
		counts = [0, 0, 0]
		for f in a.fish:
			counts[f.kind] += 1
			if f.kind == 2:
				rare_lanes[int(f.id / 3)] = true
		expect(counts == [5, 3, 1], "seed %d species composition" % seed_value)
	expect(rare_lanes.size() == 3, "rare fish appear across all depth layers")
	hardening_tests()
	benchmark()
	print("RULE TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func benchmark() -> void:
	for policy in ["deepest", "mid", "random", "visible"]:
		var sum_score: int = 0
		var empty: int = 0
		var count: int = 0
		var seconds: float = 0.0
		for seed_value in range(200):
			var r := Rules.new()
			r.setup(seed_value)
			r.act()
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value + 981
			var target: float = rng.randf_range(230, 520)
			for frame in range(600):
				if r.state == "sinking":
					var should_reel: bool = false
					match policy:
						"deepest": should_reel = false # Rules auto-reel at bottom.
						"mid": should_reel = r.hook_y >= 365
						"random": should_reel = r.hook_y >= target
						"visible":
							for f in r.fish:
								# Visible-only heuristic: reel beneath a body near hook column.
								if absf(f.x - 180) < f.width * 0.4 and r.hook_y >= f.y and r.hook_y - f.y < 80:
									should_reel = true
							should_reel = should_reel or r.hook_y >= 520
					if should_reel:
						r.act()
				r.tick(Rules.STEP)
				if r.state == "result":
					break
			seconds += r.time
			sum_score += r.score
			count += r.caught.size()
			if r.caught.is_empty(): empty += 1
		print("POLICY %s n=200 mean_score=%.2f mean_catch=%.2f empty=%.1f%% pts_per_min=%.2f mean_seconds=%.2f" % [policy, sum_score / 200.0, count / 200.0, empty / 2.0, sum_score * 60.0 / seconds, seconds / 200.0])

func hardening_tests() -> void:
	var reference := Rules.new()
	reference.setup(981)
	reference.tick(1.0)
	reference.act()
	reference.tick(2.0)
	reference.act()
	reference.tick(2.0)
	for hz in [15, 30, 60, 120]:
		var r := Rules.new()
		r.setup(981)
		for i in range(hz): r.tick(1.0 / hz)
		r.act()
		for i in range(hz * 2): r.tick(1.0 / hz)
		r.act()
		for i in range(hz * 2): r.tick(1.0 / hz)
		expect(r.fish == reference.fish and r.events == reference.events and r.time == reference.time, "identical exact-tick inputs at %d Hz" % hz)
	for checkpoint in [0, 33, 121, 125, 150, 190, 260]:
		var original := Rules.new()
		original.setup(93)
		original.act()
		for frame in range(checkpoint):
			if frame == 121: original.act()
			original.tick(Rules.STEP)
		var saved: Dictionary = JSON.parse_string(JSON.stringify(original.export_snapshot()))
		var restored := Rules.new()
		expect(restored.restore_snapshot(saved), "JSON snapshot restores checkpoint %d" % checkpoint)
		original.events.clear()
		restored.events.clear()
		for frame in range(checkpoint, 360):
			if frame == 121:
				original.act()
				restored.act()
			original.tick(Rules.STEP)
			restored.tick(Rules.STEP)
		expect(original.score == restored.score and original.caught.size() == restored.caught.size() and is_equal_approx(original.hook_y, restored.hook_y), "restore continuation matches %d" % checkpoint)
		var result_events: int = 0
		for event in restored.events:
			if event.type == "result": result_events += 1
		expect(result_events == (0 if saved.state == "result" else 1), "result emitted exactly once after restore %d" % checkpoint)
		if restored.state == "result":
			var previous_score: int = restored.score
			var previous_seed: int = restored.round_seed
			expect(restored.prepare_next_round(), "prepare succeeds once")
			var school: Array = restored.fish.duplicate(true)
			expect(not restored.prepare_next_round(), "prepare is idempotently refused when ready")
			expect(restored.result_summary.score == previous_score and restored.result_summary.seed == previous_seed, "result retained during next preview")
			var clone := Rules.new()
			expect(clone.restore_snapshot(JSON.parse_string(JSON.stringify(restored.export_snapshot()))), "preview and prior result restore")
			restored.act()
			expect(school == restored.fish, "cast never reshuffles visible fish")
	var safe := Rules.new()
	safe.setup(11)
	var baseline: Dictionary = safe.export_snapshot()
	for field in ["version", "state", "score", "fish", "caught_ids", "time", "closed", "elapsed"]:
		var corrupt: Dictionary = baseline.duplicate(true)
		corrupt[field] = "invalid"
		expect(not safe.restore_snapshot(corrupt) and safe.export_snapshot() == baseline, "atomic rejection of corrupt " + field)
	var corrupt: Dictionary = baseline.duplicate(true)
	corrupt.fish[1].id = corrupt.fish[0].id
	expect(not safe.restore_snapshot(corrupt), "duplicate fish IDs rejected")
	corrupt = baseline.duplicate(true)
	corrupt.fish[0].caught = true
	expect(not safe.restore_snapshot(corrupt), "inconsistent captured score rejected")
	corrupt = baseline.duplicate(true)
	corrupt.erase("elapsed")
	expect(not safe.restore_snapshot(corrupt), "missing timer rejected")
	safe.tick(-1)
	safe.tick(NAN)
	safe.tick(INF)
	safe.tick(0)
	expect(safe.export_snapshot() == baseline, "invalid or paused deltas leave state unchanged")
	safe.tick(100000)
	expect(safe.time <= Rules.STEP * Rules.MAX_STEPS + 0.000001 and safe._accumulator <= Rules.MAX_BACKLOG, "huge delta bounded work and backlog")
	var noise := RandomNumberGenerator.new()
	noise.seed = 99117
	for run in range(300):
		var r := Rules.new()
		r.setup(run)
		r.act()
		for frame in range(390):
			if noise.randf() < 0.09 and r.state not in ["result", "ready"]: r.act()
			r.tick(Rules.STEP)
		expect(r.state == "result" and r.caught.size() <= 3 and r.score >= 0, "noisy input round %d terminates" % run)
	var reusable := Rules.new()
	var start_memory: int = OS.get_static_memory_usage()
	for run in range(10000):
		reusable.setup(run)
		reusable.act()
		reusable.tick(4.0)
		reusable.tick(2.0)
		if reusable.state != "result" or reusable.fish.size() != 9 or reusable.events.size() > 10:
			expect(false, "10k round bounded lifecycle at %d" % run)
			break
	var memory_growth: int = OS.get_static_memory_usage() - start_memory
	expect(reusable.round_id == 10000 and memory_growth < 1048576, "10k rounds no retained growth over 1 MiB")
	print("STRESS rounds=10000 retained_memory_delta_bytes=%d" % memory_growth)
