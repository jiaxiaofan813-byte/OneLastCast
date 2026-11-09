extends SceneTree
## Independent alternate-strategy continuous-play audit. No gameplay edits.
const Rules = preload("res://scripts/arcade/arcade_rules.gd")
const DT := 1.0 / 60.0
const SEEDS := [92011, 103013, 118021]
var goal := 60
var failures := 0
var runtime_errors := 0
var source_script: GDScript

func _init() -> void:
	goal = 100 if "--long" in OS.get_cmdline_user_args() else 60
	source_script = Rules
	if "--baseline" in OS.get_cmdline_user_args():
		source_script = GDScript.new()
		source_script.source_code = FileAccess.get_file_as_string("res://Legacy/v0.6-before-difficulty/arcade_rules.gd.txt").replace("class_name ArcadeRules\n", "")
		if source_script.reload() != OK:
			quit(2)
			return
	for case in [[118021,"late"],[92011,"random"],[92011,"deep"],[103013,"deep"],[118021,"deep"],[92011,"late"],[103013,"late"],[103013,"random"],[118021,"random"]]:
		journey(int(case[0]), str(case[1]))
	print("INDEPENDENT_DIFFICULTY failures=", failures, " runtime_errors=", runtime_errors)
	quit(1 if failures or runtime_errors else 0)

func visible_option(r, option: Dictionary) -> Dictionary:
	if option.is_empty(): return {}
	for f in r.fish_school + r.bottom_items:
		if f.id == option.id and f.pos.x >= 0.0 and f.pos.x <= 360.0:
			return {"id": f.id, "category": option.category, "row": int(f.get("row", -1)), "tier": int(f.get("tier", -1))}
	return {}

func scan(r) -> Dictionary:
	var cast = source_script.new()
	cast.restore(r.snapshot())
	var segments: Array[Dictionary] = []
	var frame := 0
	var all_contacts := 0
	var hidden_contacts := 0
	var fish_frames := 0
	var prior_id := -999999
	while cast.state == "casting":
		var predicted: Dictionary = cast.predict_slam_contact()
		if not predicted.is_empty(): all_contacts += 1
		var option := visible_option(cast, predicted)
		if not predicted.is_empty() and option.is_empty(): hidden_contacts += 1
		if option.is_empty():
			prior_id = -999999
		else:
			if option.category == "fish": fish_frames += 1
			if option.id == prior_id:
				segments[-1].end = frame
			else:
				option.start = frame
				option.end = frame
				segments.append(option)
				prior_id = option.id
		cast.tick(DT)
		cast.events.clear()
		frame += 1
	return {"segments": segments, "frames":frame,"all_contacts": all_contacts, "hidden_contacts": hidden_contacts, "fish_frames":fish_frames}

func choose(segments: Array, mode: String, random: RandomNumberGenerator) -> Dictionary:
	var eligible: Array = []
	for s in segments:
		if s.end - s.start >= 6: eligible.append(s)
	if eligible.is_empty(): eligible = segments
	var selected: Dictionary = eligible[0]
	if mode == "random": return eligible[random.randi_range(0, eligible.size()-1)]
	for s in eligible:
		if mode == "deep" and (s.row > selected.row or (s.row == selected.row and s.end-s.start > selected.end-selected.start)):
			selected = s
		elif mode == "late" and s.end > selected.end:
			selected = s
	return selected

func journey(seed_value: int, mode: String) -> void:
	var r = source_script.new()
	r.setup(seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 1921
	var min_window := 1000
	var narrow_casts := 0
	var fishless_casts := 0
	var salvage := 0
	var cycles := 0
	var stages: Dictionary = {}
	for cycle in goal * 3:
		if r.catches >= goal: break
		while r.state == "recast_window": r.tick(DT)
		if r.state != "casting":
			runtime_errors += 1
			printerr("INDEPENDENT_BAD_STATE ", seed_value, " ", mode, " ", r.state)
			return
		var measured := scan(r)
		if measured.segments.is_empty():
			failures += 1
			printerr("INDEPENDENT_NO_VISIBLE_WINDOW ", JSON.stringify({"seed":seed_value, "mode":mode, "catches":r.catches, "cycle":cycle, "time":r.time, "all_contacts":measured.all_contacts, "hidden_contacts":measured.hidden_contacts, "fish":r.fish_school, "items":r.bottom_items}))
			break
		var stage := "60+" if r.catches >= 60 else ("45-59" if r.catches >= 45 else ("32-44" if r.catches >= 32 else ("25-31" if r.catches >= 25 else ("18-24" if r.catches >= 18 else ("12-17" if r.catches >= 12 else "0-11")))))
		if not stages.has(stage): stages[stage] = {"casts":0,"frames":0,"empty_frames":0,"visible_fish_frames":0,"hidden_frames":0}
		stages[stage].casts += 1
		stages[stage].frames += measured.frames
		stages[stage].empty_frames += measured.frames - measured.all_contacts
		stages[stage].visible_fish_frames += measured.fish_frames
		stages[stage].hidden_frames += measured.hidden_contacts
		if measured.fish_frames == 0: fishless_casts += 1
		var widest := 0
		for segment in measured.segments: widest = maxi(widest, segment.end-segment.start)
		min_window = mini(min_window, widest)
		if widest < 6:
			narrow_casts += 1
			printerr("INDEPENDENT_NARROW seed=", seed_value, " mode=", mode, " catches=", r.catches, " frame_window=", widest)
		var selected := choose(measured.segments, mode, rng)
		var at_frame := int((selected.start + selected.end) / 2)
		for frame in at_frame: r.tick(DT)
		r.press()
		r.release()
		while r.state not in ["game_over", "recast_window"]:
			if r.state == "bite_window" and r.ring_elapsed >= r.ring_duration:
				if r._contact_id != selected.id:
					runtime_errors += 1
					printerr("INDEPENDENT_CONTACT_MISMATCH expected=", selected.id, " actual=", r._contact_id)
				r.press()
				r.release()
			r.tick(DT)
		if r.state == "game_over":
			failures += 1
			printerr("INDEPENDENT_EXECUTION_FAIL seed=",seed_value," mode=",mode," catches=",r.catches," reason=",r.final_reason)
			break
		if r.catch_category != "fish": salvage += 1
		cycles += 1
		r.events.clear()
	if r.catches < goal: failures += 1
	for stage in stages:
		stages[stage].empty_fraction = float(stages[stage].empty_frames) / stages[stage].frames
		stages[stage].visible_fish_fraction = float(stages[stage].visible_fish_frames) / stages[stage].frames
	print("INDEPENDENT_JOURNEY ", JSON.stringify({"seed":seed_value,"mode":mode,"reached":r.catches,"goal":goal,"cycles":cycles,"minimum_window_lower_bound_ms":min_window*1000.0/60.0,"stages":stages,"narrow_casts":narrow_casts,"fishless_casts":fishless_casts,"salvage":salvage}))
