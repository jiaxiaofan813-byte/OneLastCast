extends SceneTree
const Rules = preload("res://scripts/fishing_rules.gd")
func _initialize() -> void:
	benchmark()
	quit()

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

