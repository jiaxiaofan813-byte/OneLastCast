extends SceneTree
const Rules = preload("res://scripts/arcade/arcade_rules.gd")
const Geometry = preload("res://scripts/arcade/fish_geometry.gd")
const DT := 1.0 / 60.0
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _init() -> void:
	var r = Rules.new()
	r.setup(20261109)
	check(r.fish_school.size() == 9 and r.row_positions.size() == 2,"initial two dense rows")
	var all_ids: Dictionary = {}
	var row_counts: Array[int] = []
	for threshold in [0,3,7,12,18,25]:
		r.catches = threshold
		r.state = "idle"
		r.tick(4.0)
		row_counts.append(r.row_positions.size())
		check(r.floor_y <= 539 and r.row_positions[-1] <= 505,"all rows fit screen")
		for row in r.row_positions.size():
			for i in 8:
				var fish: Dictionary = r._make_fish(row,200)
				all_ids[fish.species_id] = true
	check(row_counts == [2,3,4,5,6,7],"progressive row prefix")
	check(all_ids.size() == 20,"all twenty real species in unlocked pools")
	check(Geometry.DATA.size() == 20,"canonical geometry contains exactly twenty IDs")
	for species_id in Rules.ACTIVE_SPECIES:
		check(Geometry.DATA.has(species_id),"species has canonical art geometry")
	for row in r.row_positions.size():
		for i in 8:
			var fish: Dictionary = r._make_fish(row,200)
			check(fish.radius.is_equal_approx(Geometry.radius_for(fish.species_id)) and fish.tier == Geometry.tier_for(fish.species_id),"sprite collider and tier share canonical geometry")
			check(fish.pos.y + fish.radius.y + 5.0 <= 535.0,"deep sprite body plus movement fits playfield")
	r.state = "casting"
	r.press()
	var layout: Array = r.row_positions.duplicate()
	var bottom: float = r.floor_y
	r._advance_school(0.1)
	check(r.row_positions == layout and r.floor_y == bottom,"layout frozen while diving")
	r.state = "bite_window"
	r._advance_school(0.1)
	check(r.row_positions == layout,"layout frozen during ring")
	# Consecutive generated gameplay, no injected schools or instant fish replacement.
	var run = Rules.new()
	run.setup(20261109)
	var caught: Dictionary = {}
	var deep_access: Dictionary = {}
	var empty_casts := 0
	var fast_scan := "--fast-scan" in OS.get_cmdline_user_args()
	for cycle in 300:
		if run.catches >= 250: break
		for wait_frame in 30:
			if run.state != "recast_window": break
			run.tick(DT)
		if cycle % 25 == 0: print("JOURNEY_PROGRESS cycle=",cycle," catches=",run.catches," state=",run.state)
		var probe = Rules.new()
		probe.restore(run.snapshot())
		var choice: Dictionary = {}
		var delay := 0.0
		for frame in 85:
			if probe.state != "casting": break
			var option: Dictionary = probe.predict_slam_contact()
			if not option.is_empty():
				var row := -1
				for f in probe.fish_school:
					if f.id == option.id: row = f.row
				if row == probe.row_positions.size()-1 and option.category == "fish": deep_access[probe.row_positions.size()] = true
				if choice.is_empty() or (option.category == "fish" and not caught.has(option.species_id)):
					choice = option
					delay = frame * DT
					if fast_scan or (option.category == "fish" and not caught.has(option.species_id)): break
			probe.tick(DT)
		if choice.is_empty():
			empty_casts += 1
			printerr("NO TARGET at catch ",run.catches," rows ",run.row_positions.size()," time ",run.time)
			break
		run.tick(delay)
		run.press()
		run.release()
		for frame in 240:
			if run.state in ["game_over","recast_window"]: break
			if run.state == "bite_window" and run.ring_elapsed >= run.ring_duration:
				run.press()
				run.release()
			run.tick(DT)
		check(run.state == "recast_window","generated cast completes " + str(cycle))
		if run.state == "game_over": break
		if run.catch_category == "fish": caught[run.fish_species_id] = int(caught.get(run.fish_species_id,0))+1
	check(empty_casts == 0,"no unavoidable empty casts in consecutive journey")
	check(run.catches >= 250,"250 actual fish caught in one continuous journey")
	if not fast_scan: check(caught.size() == 20,"all twenty species actually caught through normal gameplay")
	print("JOURNEY: ",checks," checks, ",failures," failures; catches=",run.catches," unique_species=",caught.size()," rows=",run.row_positions.size()," empty_casts=",empty_casts," deepest_access_stages=",deep_access.keys()," species_counts=",caught)
	quit(1 if failures else 0)
