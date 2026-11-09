extends SceneTree
const Rules = preload("res://scripts/arcade/arcade_rules.gd")
const DT := 1.0 / 60.0
var checks := 0
var failures := 0
var durations: Array[float] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)
func wait_for(r, desired: String, limit := 300) -> void:
	for i in limit:
		if r.state == desired:
			return
		r.tick(DT)
	check(false, "state timeout: " + desired + " actual " + r.state)
func start(r) -> void:
	if r.held:
		r.release()
	r.press()
	check(r.state == "casting" and not r.slam_armed, "cast consumes press")
	r.release()
	check(r.slam_armed, "release arms slam")
func land(r, offset := 0.0) -> void:
	for i in 120:
		if r.lure_pos.x >= r.target_x + offset:
			r.press()
			break
		r.tick(DT)
	wait_for(r, "bite_window")
func bite(r) -> void:
	for i in 160:
		if r.bite_active:
			return
		r.tick(DT)
	check(false, "bite timeout")
func catch_one(r) -> void:
	start(r)
	land(r)
	check(r.landing_grade == "perfect", "perfect landing")
	bite(r)
	r.tick(0.2)
	r.release()
	check(r.state == "hookset", "perfect hookset")
	var frozen: Vector2 = r.fish_pos
	r.tick(DT)
	check(r.fish_pos == frozen, "hitstop freezes physics")
	for i in 240:
		if r.state == "recast_window":
			break
		if r.state == "tug_of_war" and r.duel_flash:
			r.press()
			r.release()
		r.tick(DT)
	check(r.state == "recast_window" and r._basket_scored, "basket scored")
	durations.append(r.last_cycle_seconds)
func _init() -> void:
	var r = Rules.new()
	r.setup(41)
	for i in 9:
		catch_one(r)
		check(r.catches == i + 1, "exact catch count")
	check(r.fever and r.combo >= 10 and r.duel_total == 2, "fever and boss duel")
	var old_score: int = r.score
	r._basket()
	check(r.score == old_score, "basket idempotent")
	r.press()
	check(r.cast_boost == 1.25 and r.state == "casting", "boosted recast")
	r.press()
	r.tick(DT)
	check(r.state == "casting" and not r.slam_armed, "held recast does not slam")
	r.release()
	r.press()
	check(r.state == "diving" and r.lure_velocity.x == 0, "fresh press slams vertically")
	r.release()
	check(r.state == "recast_window" and r.combo == 9 and not r.fever, "early fail halves fever")
	r.tick(0.21)
	check(r.state == "casting" and r.cast_boost == 1, "fast retry automatic")
	for timing in [0.05, 0.2, 0.48]:
		r.setup(21)
		start(r)
		land(r, 30)
		check(r.landing_grade == "normal", "normal landing")
		bite(r)
		r.tick(timing)
		r.release()
		check(r.state == "hookset", "valid early/golden/grace hook")
		check(r.combo == (1 if timing == 0.2 else 0), "only golden adds combo")
	r.setup(21)
	start(r)
	land(r, 70)
	check(r.landing_grade == "miss" and r.fish_kind < 2 and r._bite_delay == 1.2, "miss base fish delay")
	bite(r)
	r.tick(0.52)
	check(r.state == "recast_window", "late hook fails")
	r.setup(21)
	start(r)
	land(r)
	r.release()
	check(r.state == "recast_window", "pre-cue release fails")
	r.setup(53)
	r.combo = 6
	start(r)
	land(r)
	bite(r)
	r.tick(0.2)
	r.release()
	wait_for(r, "tug_of_war")
	r.press()
	r.release()
	check(r.duel_remaining == 1, "early counter does not break poise")
	r.tick(0.5)
	check(r.state == "recast_window" and r.combo == 0, "missed counter fails and decays")
	r.setup(37)
	r.tune.hook_window_ms = 600.0
	start(r)
	land(r)
	bite(r)
	r.tick(0.55)
	r.release()
	check(r.state == "hookset" and r.combo == 2, "configured golden window honored")
	# Restore the default tune: setup intentionally retains user tuning.
	r.tune.hook_window_ms = 450.0
	# Identical seeds, fixed input stream and exact mid-flight restoration.
	var a = Rules.new()
	var b = Rules.new()
	a.setup(9182)
	b.setup(9182)
	for i in 1200:
		if i % 37 == 0:
			a.press()
			b.press()
		if i % 37 == 17:
			a.release()
			b.release()
		a.tick(DT)
		b.tick(DT)
		check(a.snapshot() == b.snapshot(), "deterministic stream " + str(i))
		check(a.state_time < 3.0 and a.lure_pos.is_finite() and a.fish_pos.is_finite(), "bounded state " + str(i))
	var saved: Dictionary = a.snapshot()
	var c = Rules.new()
	check(c.restore(saved), "snapshot restore succeeds")
	for i in 100:
		a.tick(DT)
		c.tick(DT)
	check(a.snapshot() == c.snapshot(), "restored future identical")
	var bad := saved.duplicate(true)
	bad.state = "broken"
	check(not c.restore(bad), "invalid snapshot rejected")
	print("ARCADE RULES: ", checks, " checks, ", failures, " failures; honest catch seconds: ", durations)
	quit(1 if failures else 0)
