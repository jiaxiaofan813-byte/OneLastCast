extends SceneTree
const Rules = preload("res://scripts/arcade/arcade_rules.gd")
const Geometry = preload("res://scripts/arcade/fish_geometry.gd")
const DT := 1.0/60.0
func _init() -> void:
	var checks := 0
	var failures := 0
	var stages: Dictionary = {}
	for stage in [0,3,7,12,18,25]:
		var lake = Rules.new()
		lake.setup(20261109)
		lake.catches = stage
		lake.state = "idle"
		lake.tick(20)
		var found := false
		for moment in 12:
			var cast = Rules.new()
			cast.restore(lake.snapshot())
			cast._start_cast(1)
			for frame in 75:
				if cast.state != "casting": break
				var option: Dictionary = cast.predict_slam_contact()
				if not option.is_empty() and option.category == "fish":
					for fish in cast.fish_school:
						if fish.id == option.id and fish.row == cast.row_positions.size()-1:
							found = true
							stages[cast.row_positions.size()] = option.species_id
				if found: break
				cast.tick(DT)
			if found: break
			lake.tick(0.75)
		checks += 1
		if not found:
			failures += 1
			printerr("FAIL: deepest row inaccessible at stage ",stage)
	for species_id in Rules.ACTIVE_SPECIES:
		var lake = Rules.new()
		lake.setup(19)
		lake.fish_school.clear()
		lake.bottom_items.clear()
		var radius := Geometry.radius_for(species_id)
		lake.fish_school.append({"id":1,"kind":0,"tier":Geometry.tier_for(species_id),"species_id":species_id,"row":0,"pos":Vector2(200,340),"previous_pos":Vector2(200,340),"velocity":Vector2.ZERO,"radius":radius,"weight":1.0,"multiplier":1})
		var hit: Dictionary = lake._first_contact(Vector2(200,310),Vector2(200,370),DT)
		var miss: Dictionary = lake._first_contact(Vector2(200+radius.x+0.1,310),Vector2(200+radius.x+0.1,370),DT)
		checks += 1
		if hit.is_empty() or not miss.is_empty():
			failures += 1
			printerr("FAIL: canonical ellipse hit/miss ",species_id)
	print("GEOMETRY ACCESS: ",checks," checks, ",failures," failures; deepest stages=",stages)
	quit(1 if failures else 0)
