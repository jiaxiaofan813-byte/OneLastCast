extends SceneTree
## Headless parameter, first-contact opportunity, and consecutive-journey regression.
## Sampling is 60 Hz on the actual trajectory. It is not proof for all possible seeds.
const Rules = preload("res://scripts/arcade/arcade_rules.gd")
const DT := 1.0 / 60.0
const STAGES := [0, 3, 7, 12, 18, 25, 32, 45, 60]
var checks := 0
var failures := 0
var quick := false
var stages: Array = STAGES.duplicate()
var baseline_script: GDScript

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _init() -> void:
	quick = "--quick" in OS.get_cmdline_user_args()
	if "--late-only" in OS.get_cmdline_user_args(): stages = [45,60]
	var source := FileAccess.get_file_as_string("res://Legacy/v0.6-before-difficulty/arcade_rules.gd.txt")
	baseline_script = GDScript.new()
	baseline_script.source_code = source.replace("class_name ArcadeRules\n", "")
	check(not source.is_empty() and baseline_script.reload() == OK, "original v0.6 comparison loads")
	if failures:
		quit(1)
		return
	parameter_checks()
	if "--opening-only" in OS.get_cmdline_user_args():
		sample_opening()
		quit(1 if failures else 0)
		return
	if "--journey-only" in OS.get_cmdline_user_args():
		journey_checks(32,75)
		print("DIFFICULTY_VISIBLE_JOURNEY: ",checks," checks, ",failures," failures")
		quit(1 if failures else 0)
		return
	var seed_count := 4 if quick else 32
	var moment_count := 2 if quick else 4
	var current := sample_curve(Rules, seed_count, moment_count, "current")
	var original := sample_curve(baseline_script, seed_count, moment_count, "baseline")
	for stage in stages:
		var now: Dictionary = current[str(stage)]
		check(now.impossible_casts == 0, "sampled cast has real fish or salvage at catch " + str(stage))
		check(now.fish_frames > 0, "sampled visible first-contact fish at catch " + str(stage))
		check(now.under_100ms_casts == 0, "every sampled scene offers a 100ms visible same-fish window at " + str(stage))
		if stage >= 18:
			check(now.empty_fraction > original[str(stage)].empty_fraction + 0.05, "late click timing has more real empty water at catch " + str(stage))
	if current.has("0"): check(current["0"] == original["0"], "opening ecology and actual contact timing unchanged")
	journey_checks(4 if quick else 32, 75)
	print("DIFFICULTY_RESULT ", JSON.stringify({"seed_count": seed_count, "moments_per_stage": moment_count, "sample_hz":60, "current":current,"baseline":original,"checks":checks,"failures":failures}))
	print("DIFFICULTY: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

func parameter_checks() -> void:
	var r = Rules.new()
	r.setup(51)
	var opening = baseline_script.new()
	opening.setup(51)
	check(r.snapshot() == opening.snapshot(), "opening state exactly matches original v0.6")
	check(r.fish_school.size() == 9 and r.bottom_items.size() == 2, "opening fish and salvage retained")
	for f in r.fish_school:
		check(f.tier == 0 and absf(f.velocity.x) >= 17.0 and absf(f.velocity.x) <= 27.0, "opening remains slow small fish")
	var counts := []
	for stage in STAGES:
		r.catches = stage
		r.state = "idle"
		r._update_journey(DT)
		var total := 0
		for row in r.row_positions.size():
			total += r._target_row_count(row)
			check(r._target_row_count(row) >= 1, "each unlocked row retains a real entrant")
		counts.append(mini(total,r._population_cap()))
	check(counts == [9,10,11,11,9,8,7,6,6], "density target table")
	check(is_zero_approx(r.difficulty_progress()-1.0), "progress clamps to mature ceiling")
	r.catches = 100000
	check(r.difficulty_progress() == 1.0, "endless play does not accelerate beyond cap")
	# Existing fish are not culled or teleported when the cap drops.
	r.setup(12)
	r.catches = 24
	r.state = "idle"
	r.tick(0.5)
	var before: Array = r.fish_school.duplicate(true)
	r.catches = 25
	r._advance_school(DT)
	for f in before:
		var matches: Array = r.fish_school.filter(func(now): return now.id == f.id)
		check(matches.size() == 1, "population milestone does not vanish an existing fish")
		if matches.size() == 1:
			check(matches[0].pos.distance_to(f.pos) < 3.0, "population milestone does not move fish to make gaps")
	# Spawn only at edges and do not refill above the current cap.
	r.setup(19)
	r.catches = 45
	r.state = "idle"
	r._update_journey(DT)
	r.fish_school.clear()
	for row in r.row_positions.size():
		for attempt in 8:
			r._spawn_at_edge(row)
		var present := 0
		for f in r.fish_school:
			if f.row == row:
				present += 1
				check(f.pos.x <= -38 or f.pos.x >= 398, "all replacements start outside view")
		check(present <= r._target_row_count(row), "edge refill respects row cap")
	check(r.fish_school.size() == r._population_cap(), "late global population cap permits empty rows")
	var entered_rows: Dictionary = {}
	var entered_species: Dictionary = {}
	for cycle in 180:
		var removed: Dictionary = {}
		for f in r.fish_school:
			if f.row >= 2:
				entered_rows[f.row] = true
				entered_species[f.species_id] = true
				removed = f
				break
		if not removed.is_empty(): r.fish_school.erase(removed)
		r._refill_school()
	check(entered_rows.size() == 5 and entered_species.size() == 10, "limited deep slots rotate every deep row and species")
	# Ring checks for every tier and endpoint, including exact accepted boundaries.
	for stage in [0,12,18,25,45,10000]:
		for tier in 4:
			var fish: Dictionary = {"id":999,"kind":tier*2,"species_id":["bluegill","yellow_perch","walleye","northern_pike"][tier],"tier":tier,"row":4,"pos":Vector2(220,490),"velocity":Vector2.ZERO,"radius":Vector2(24,12),"weight":12.0,"multiplier":[1,2,4,8][tier]}
			r.setup(29)
			r.catches = stage
			r.state = "idle"
			r._update_journey(DT)
			# Fixture needs row 4 even at early progress to isolate progression math.
			while r.row_positions.size() <= 4: r.row_positions.append(490.0)
			r.fish_school.clear()
			r.fish_school.append(fish)
			r._contact_fish({"fish":fish,"pos":fish.pos,"center":fish.pos})
			var expected: float = [0.95,0.82,0.68,0.55][tier]
			if tier == 3: expected = lerpf(.55,.40,clampf(float(stage-12)/33.0,0.0,1.0))
			check(is_equal_approx(r.ring_duration,expected), "only elite ring accelerates at " + str(stage))
			check(is_equal_approx(r.ring_window,[.18,.15,.12,.10][tier]), "all existing timing windows preserved")
			var saved: Dictionary = r.snapshot()
			for offset in [-r.ring_window + 0.000001, r.ring_window - 0.000001]:
				r.restore(saved)
				r.ring_elapsed = r.ring_duration + offset
				r.press()
				check(r.state == "hookset", "ring timing boundary within 1 microsecond")
	# The scanner must detect a deliberately impossible empty configuration.
	r.setup(17)
	r.fish_school.clear()
	r.bottom_items.clear()
	var impossible := scan_cast(r)
	check(impossible.fish_frames == 0 and impossible.salvage_frames == 0, "scanner detects no-contact cast")

func scan_cast(cast) -> Dictionary:
	var result := {"frames":0,"fish_frames":0,"salvage_frames":0,"empty_frames":0,"small_frames":0,"deep_frames":0,"hidden_frames":0,"longest_fish_window_frames":0,"visible_fish":0}
	for f in cast.fish_school:
		if f.pos.x >= 0.0 and f.pos.x <= 360.0: result.visible_fish += 1
	var streak := 0
	var prior_id := -999999
	while cast.state == "casting":
		result.frames += 1
		var option: Dictionary = cast.predict_slam_contact()
		if option.is_empty():
			result.empty_frames += 1
			streak = 0
			prior_id = -999999
		elif option.category != "fish":
			result.salvage_frames += 1
			streak = 0
			prior_id = -999999
		else:
			var found := false
			for f in cast.fish_school:
				if f.id == option.id:
					found = f.pos.x >= 0.0 and f.pos.x <= 360.0
					if found:
						result.fish_frames += 1
						if f.tier == 0: result.small_frames += 1
						if f.row == cast.row_positions.size()-1: result.deep_frames += 1
					break
			if found:
				streak = streak + 1 if prior_id == option.id else 1
				prior_id = option.id
				result.longest_fish_window_frames = maxi(result.longest_fish_window_frames, streak)
			else:
				result.hidden_frames += 1
				streak = 0
				prior_id = -999999
		cast.tick(DT)
		cast.events.clear()
	return result

func sample_curve(script, seed_count: int, moment_count: int, label: String) -> Dictionary:
	var result: Dictionary = {}
	for stage in stages:
		var summary := {"casts":0,"frames":0,"fish_frames":0,"salvage_frames":0,"empty_frames":0,"small_frames":0,"deep_frames":0,"hidden_frames":0,"visible_fish_sum":0,"impossible_casts":0,"fishless_casts":0,"under_100ms_casts":0}
		var windows: Array[int] = []
		for index in seed_count:
			var seed_value := 20261109 + index * 7919
			var lake = script.new()
			lake.setup(seed_value)
			lake.catches = stage
			lake.state = "idle"
			lake.tick(32.0 + float(index%5) * .37)
			lake.events.clear()
			for moment in moment_count:
				var cast = script.new()
				cast.restore(lake.snapshot())
				cast._start_cast(1.0)
				var measured := scan_cast(cast)
				summary.casts += 1
				for key in ["frames","fish_frames","salvage_frames","empty_frames","small_frames","deep_frames","hidden_frames"]:
					summary[key] += measured[key]
				summary.visible_fish_sum += measured.visible_fish
				if measured.fish_frames == 0:
					summary.fishless_casts += 1
					if measured.salvage_frames == 0:
						summary.impossible_casts += 1
						printerr("IMPOSSIBLE_SAMPLE ",label," seed=",seed_value," catches=",stage," moment=",moment," time=",lake.time)
				if measured.longest_fish_window_frames < 7: summary.under_100ms_casts += 1
				windows.append(measured.longest_fish_window_frames)
				lake.tick(2.73)
				lake.events.clear()
		windows.sort()
		summary.empty_fraction = float(summary.empty_frames) / summary.frames
		summary.fish_fraction = float(summary.fish_frames) / summary.frames
		summary.mean_visible_fish = float(summary.visible_fish_sum) / summary.casts
		summary.min_window_ms = float(maxi(0,windows[0]-1))*1000.0/60.0
		summary.p10_window_ms = float(maxi(0,windows[int(windows.size()*.1)]-1))*1000.0/60.0
		summary.median_window_ms = float(maxi(0,windows[windows.size()/2]-1))*1000.0/60.0
		result[str(stage)] = summary
		print("DENSITY_STAGE ",label," catch=",stage," ",JSON.stringify(summary))
	return result

func journey_checks(seed_count: int, catch_goal: int) -> void:
	var impossible := 0
	var reached := 0
	var observed: Dictionary = {}
	for index in seed_count:
		var r = Rules.new()
		r.setup(81001 + index * 1543)
		for cycle in catch_goal * 3:
			if r.catches >= catch_goal: break
			while r.state == "recast_window": r.tick(DT)
			var choice: Dictionary = {}
			while r.state == "casting":
				choice = r.predict_slam_contact()
				var visible := false
				if not choice.is_empty():
					for target in r.fish_school + r.bottom_items:
						if target.id == choice.id and target.pos.x >= 0.0 and target.pos.x <= 360.0:
							visible = true
							break
				if visible: break
				choice = {}
				r.tick(DT)
			if choice.is_empty():
				impossible += 1
				printerr("IMPOSSIBLE_JOURNEY seed=",81001+index*1543," catches=",r.catches," time=",r.time)
				break
			r.press()
			r.release()
			while r.state not in ["game_over","recast_window"]:
				if r.state == "bite_window" and r.ring_elapsed >= r.ring_duration:
					r.press()
					r.release()
				r.tick(DT)
			if r.state == "game_over":
				check(false,"predicted actual journey contact and ring complete")
				break
			if r.catch_category == "fish": observed[r.fish_species_id] = true
			r.events.clear()
		if r.catches >= catch_goal: reached += 1
	check(impossible == 0, "no impossible casts in sampled continuous journeys")
	check(reached == seed_count, "all sampled continuous journeys reach target")
	print("DIFFICULTY_JOURNEYS ",JSON.stringify({"seeds":seed_count,"goal":catch_goal,"reached":reached,"impossible":impossible,"species_seen":observed.size()}))

func sample_opening() -> void:
	var summary := {"casts":0,"frames":0,"empty_frames":0,"fish_frames":0,"salvage_frames":0,"hidden_frames":0}
	for index in 32:
		var live = Rules.new()
		var original = baseline_script.new()
		live.setup(20261109 + index*7919)
		original.setup(20261109 + index*7919)
		var now := scan_cast(live)
		check(now == scan_cast(original), "first cast unchanged for seed " + str(index))
		summary.casts += 1
		for key in ["frames","empty_frames","fish_frames","salvage_frames","hidden_frames"]: summary[key] += now[key]
	summary.empty_fraction = float(summary.empty_frames)/summary.frames
	print("DIFFICULTY_FIRST_CAST ",JSON.stringify(summary))
	print("DIFFICULTY_OPENING: ",checks," checks, ",failures," failures")
