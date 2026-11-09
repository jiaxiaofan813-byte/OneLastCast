extends SceneTree
const Rules = preload("res://scripts/arcade/arcade_rules.gd")
const DT := 1.0 / 60.0
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)
func make_fish(id: int, center: Vector2, velocity := Vector2.ZERO, kind := 0) -> Dictionary:
	return {"id": id, "kind": kind, "tier": kind / 2, "species_id": ["bluegill", "pumpkinseed", "black_crappie", "yellow_perch", "largemouth_bass", "walleye", "striped_bass", "northern_pike"][kind], "row": 0 if center.y < 370 else 1, "pos": center, "velocity": velocity, "radius": Vector2(19,14), "weight": 1.7, "multiplier": 4 if kind >= 4 else 1}
func plunge(r, x := 200.0, y := 300.0, speed := 1000.0) -> void:
	r.state = "diving"
	r.held = false
	r._water_entered = true
	r.lure_pos = Vector2(x,y)
	r.lure_velocity = Vector2(0,speed)
func school(r, fish: Array) -> void:
	r.fish_school.clear()
	for f in fish: r.fish_school.append(f)
func finish(r) -> void:
	for i in 240:
		if r.state in ["recast_window", "game_over"]: return
		if r.state == "bite_window" and r.ring_elapsed >= r.ring_duration:
			r.press()
			r.release()
		r.tick(DT)
func _init() -> void:
	var r = Rules.new()
	r.setup(17)
	check(r.state == "casting" and r.fish_school.size() == 9 and r.floor_y == 425, "automatic cast and two dense shallow rows")
	var original: Array = r.fish_school.duplicate(true)
	r.tick(0.1)
	for fish in original:
		for moved in r.fish_school:
			if moved.id == fish.id:
				check(moved.kind == fish.kind and moved.velocity == fish.velocity and moved.pos.is_equal_approx(fish.pos + fish.velocity * 0.1), "predictable stable fish motion")
	r.catches = 7
	r.state = "idle"
	r.tick(4.0)
	check(r.row_positions.size() == 4 and r.floor_y <= 539, "fourth row at seven actual catches")
	for fish in r.fish_school:
		check(fish.kind < 2 if fish.id <= 9 else (fish.row >= 2 and fish.pos.y <= 535.0), "old fish unchanged; new row enters edge")
	r.setup(18)
	school(r,[make_fish(101,Vector2(200,397)),make_fish(102,Vector2(200,340),Vector2.ZERO,5)])
	plunge(r,200,300,10000)
	r.tick(DT)
	check(r.state == "bite_window" and r._contact_id == 102, "swept first contact beats list order and back row")
	check(r.fish_kind == 5 and r.fish_weight == 1.7 and r.duel_total == 0, "actual contacted species retained; no third counter input")
	check(r.combo == 1 and r.ring_duration == 0.68 and is_equal_approx(r.ring_window,0.12), "contact combo and heavy timing")
	check(r.lure_pos.y < 340 and r.fish_pos.y == 340, "contact freezes exact positions")
	var hooked_pos: Vector2 = r.fish_pos
	r.release()
	r.flick()
	r.tick(0.05)
	check(r.fish_pos == hooked_pos and r.state == "bite_window", "release and flick cannot hook or fail")
	for fish in r.fish_school: check(fish.id != 102, "contact fish removed from school")
	finish(r)
	check(r.state == "recast_window" and r.catches == 1 and r.score == 420, "heavy fish completes with exactly second tap")
	var points: int = r.score
	r._basket()
	check(r.score == points, "duplicate basket cannot rescore")
	r.tick(0.2)
	check(r.state == "casting" and r.cast_boost == 1.0, "automatic recast without third input")
	r.press()
	check(r.state == "diving" and r.lure_velocity.y >= 900 and r.lure_velocity.x == 0, "first press immediately rapid vertical dive")
	r.press()
	r.release()
	check(r.state == "diving", "duplicate press and release cannot early-fail")
	r.setup(19)
	school(r,[make_fish(301,Vector2(170,340),Vector2(3600,0))])
	plunge(r,200,340,0)
	r.tick(DT)
	check(r.state == "bite_window" and r._contact_id == 301, "relative sweep catches lateral crossing")
	r.setup(20)
	r.fish_school.clear()
	r.score = 1234
	r.combo = 4
	r.best_run_combo = 8
	plunge(r,200,420,1000)
	r.held = true
	r.tick(DT)
	check(r.state == "game_over" and r.final_reason == "empty_dive", "empty dive ends at shallow floor")
	check(r.score == 1234 and r.best_run_combo == 8, "final score and max combo retained")
	var frozen: Dictionary = r.snapshot()
	r.tick(10)
	check(r.snapshot() == frozen, "entire game over state freezes")
	r.press()
	check(r.state == "game_over", "old held touch cannot restart")
	r.release()
	r.tune.dive_gravity = 4.0
	r.press()
	check(r.state == "casting" and r.score == 0 and r.combo == 0 and r.held, "fresh tap restarts cast, not dive")
	check(r.tune.dive_gravity == 4.0 and r.final_reason.is_empty(), "restart preserves tuning not failure")
	check(r.events.any(func(e): return e.type == "restarted"), "restart visual reset event")
	for timing in [0.0, 2.0]:
		r.setup(22)
		school(r,[make_fish(401,Vector2(200,340))])
		plunge(r)
		for i in 10:
			if r.state == "bite_window": break
			r.tick(DT)
		r.tick(timing)
		if r.state != "game_over": r.press()
		check(r.state == "game_over", "early or timed-out ring ends run")
		check(r.catches == 0 and r.score == 0, "failed timing cannot score")
	# Prediction clones exact rules without giving actual gameplay magnetic assistance.
	r.setup(20261109)
	for cycle in 10:
		var prediction: Dictionary = {}
		for i in 150:
			if r.state == "casting":
				var before: Dictionary = r.snapshot()
				prediction = r.predict_slam_contact()
				check(r.snapshot() == before, "prediction read only")
				if not prediction.is_empty() and prediction.category == "fish":
					r.press()
					r.release()
					break
			r.tick(DT)
		check(not prediction.is_empty(), "demo finds contact opportunity")
		if prediction.is_empty(): break
		for i in 120:
			if r.state != "diving": break
			r.tick(DT)
		check(r._contact_id == prediction.id, "prediction matches real first fish")
		finish(r)
		check(r.catches == cycle + 1 and r.state == "recast_window", "consecutive two-tap catch")
	# Predictable species patterns: visible warning, then lock during a dive.
	var moving = Rules.new()
	moving.setup(50)
	school(moving,[make_fish(501,Vector2(200,340),Vector2(50,0),4)])
	moving.fish_school[0]["turn_left"] = 0.15
	moving._advance_school(0.05)
	check(moving.fish_school[0].turn_warning, "heavy fish warns before turn")
	moving.press()
	moving._advance_school(0.3)
	check(moving.fish_school[0].velocity.x == 50, "dive locks imminent turnaround")
	moving.state = "casting"
	moving._advance_school(0.11)
	check(moving.fish_school[0].velocity.x == -50, "predictable turn resumes after dive")
	school(moving,[make_fish(502,Vector2(200,397),Vector2.ZERO,7)])
	var min_y := 397.0
	var max_y := 397.0
	for i in 400:
		moving._advance_school(DT)
		min_y = minf(min_y,moving.fish_school[0].pos.y)
		max_y = maxf(max_y,moving.fish_school[0].pos.y)
	check(max_y - min_y > 20 and min_y >= 379 and max_y <= 411, "pike swims vertically within row and floor")
	# Mature ecology, advanced only by ordinary school motion: sample actual input times.
	var accessible_small := 0
	var accessible_deep_big := 0
	var proven_ids: Dictionary = {}
	for sample_seed in [11, 29, 47]:
		var ecosystem = Rules.new()
		ecosystem.setup(sample_seed)
		ecosystem.combo = 12
		ecosystem.catches = 25
		ecosystem.state = "idle"
		for i in 1200: ecosystem.tick(DT)
		var small_present := false
		var big_present := false
		for f in ecosystem.fish_school:
			if f.row == 0 and f.kind < 2: small_present = true
			if f.row == 6 and f.kind >= 4: big_present = true
		check(small_present and big_present, "mature school preserves low-risk and high-reward choices")
		for moment in 8:
			var cast = Rules.new()
			cast.restore(ecosystem.snapshot())
			cast._start_cast(1.0)
			for frame in 72:
				if cast.state != "casting": break
				var option: Dictionary = cast.predict_slam_contact()
				if not option.is_empty() and option.category == "fish":
					var target_row := -1
					for f in cast.fish_school:
						if f.id == option.id: target_row = f.row
					if option.kind < 2: accessible_small += 1
					if target_row == 6 and option.kind >= 4: accessible_deep_big += 1
					var category := "small" if option.kind < 2 else ("deep_big" if target_row == 6 and option.kind >= 4 else "medium")
					if not proven_ids.has(category):
						var actual = Rules.new()
						actual.restore(cast.snapshot())
						actual.press()
						actual.release()
						for i in 120:
							if actual.state != "diving": break
							actual.tick(DT)
						check(actual.state == "bite_window" and actual._contact_id == option.id, "sampled " + category + " is actual first contact, not penetration")
						finish(actual)
						check(actual.catches == ecosystem.catches + 1, "sampled " + category + " can finish scoring")
						proven_ids[category] = option.id
				cast.tick(DT)
			ecosystem.tick(0.75)
	check(accessible_small > 0 and accessible_deep_big > 0, "both shallow small and deep big first-contact windows exist")
	print("ACCESSIBILITY: ",accessible_small," small-fish frames, ",accessible_deep_big," deep big-fish frames across 24 deterministic cast samples; verified categories=",proven_ids.keys())
	# Sparse bottom objects are real contacts, not automatic empty-cast rescue.
	var salvage = Rules.new()
	for category in ["snail", "weed"]:
		salvage.setup(71)
		check(salvage.lure_velocity.is_equal_approx(Vector2(235,-330) * 0.95), "all casts use 0.95 initial velocity")
		salvage.fish_school.clear()
		salvage.bottom_items.clear()
		salvage.bottom_items.append(salvage._make_item(category,200.0))
		salvage.combo = 4
		salvage.best_run_combo = 4
		plunge(salvage,200,385,1000)
		for i in 5:
			if salvage.state != "diving": break
			salvage.tick(DT)
		check(salvage.state == "bite_window" and salvage.catch_category == category, "real " + category + " contact enters ring")
		finish(salvage)
		check(salvage.state == "recast_window" and salvage.score == 0 and salvage.catches == 0 and salvage.combo == 4, "salvage continues without fish score or combo inflation")
		check(salvage.events.any(func(e): return e.type == "junk_basket" and e.category == category) and not salvage.events.any(func(e): return e.type == "basket"), "salvage event separated from fish statistics")
		salvage.tick(0.2)
		check(salvage.state == "casting", "salvage auto recasts")
	salvage.setup(72)
	salvage.fish_school.clear()
	plunge(salvage,80,413,1000)
	salvage.tick(DT)
	check(salvage.state == "game_over", "missing sparse bottom items still ends run")
	salvage.setup(73)
	school(salvage,[make_fish(909,Vector2(200,397))])
	salvage.bottom_items.clear()
	salvage.bottom_items.append(salvage._make_item("snail",200.0))
	plunge(salvage,200,370,10000)
	salvage.tick(DT)
	check(salvage.catch_category == "fish" and salvage._contact_id == 909, "fish above debris wins real earliest collision")
	var restored = Rules.new()
	check(restored.restore(r.snapshot()), "v2 snapshot restored")
	r.tick(0.5)
	restored.tick(0.5)
	check(restored.snapshot() == r.snapshot(), "fish and RNG replay exactly")
	print("SHALLOW RULES: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
