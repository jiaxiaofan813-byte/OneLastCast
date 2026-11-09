extends SceneTree

const Water = preload("res://scripts/arcade/water_surface.gd")
const Rod = preload("res://scripts/arcade/rod_spring.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	for dt in [1.0 / 60.0, 0.033]:
		_test_water(dt)
		_test_rod(dt)
	print("VISUAL_PHYSICS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _test_water(dt: float) -> void:
	var water = Water.new()
	water.setup()
	_check(water.get_surface_points().size() == 64, "water has 64 physical nodes")
	_check(is_equal_approx(water.get_y(180.0), 288.0), "calm water baseline")
	water.splash(180.0, 120.0, 8.0)
	water.tick(dt)
	_check(water.get_y(180.0) > 288.0, "positive impulse goes down")
	for frame in range(ceili(60.0 / dt)):
		if frame % 31 == 0:
			water.splash(float((frame * 17) % 360), 1000000.0 if frame % 2 == 0 else -1000000.0, 12.0)
		water.tick(dt)
		for point in water.get_surface_points():
			_check(point.is_finite() and absf(point.y - 288.0) < 22.0, "water finite and bounded under repeated impulses")
	for frame in range(ceili(10.0 / dt)):
		water.tick(dt)
	_check(absf(water.get_y(180.0) - 288.0) < 0.01, "water settles after impulses")
	_check(is_equal_approx(water.get_y(-20.0), water.get_y(0.0)), "water left sampling clamps")
	_check(is_equal_approx(water.get_y(400.0), water.get_y(360.0)), "water right sampling clamps")
	# Coupling transports motion to nodes outside the initial narrow splash.
	water.setup()
	water.splash(180.0, 120.0, 1.0)
	for frame in range(ceili(0.4 / dt)):
		water.tick(dt)
	_check(absf(water.get_y(210.0) - 288.0) > 0.01, "water neighbours propagate ripple")

func _test_rod(dt: float) -> void:
	var rod = Rod.new()
	rod.setup()
	_check(rod.get_points().size() == 25, "six Bezier spans with 25 render samples")
	_check(rod.tip.distance_to(Vector2(153.0, 188.0)) < 0.001, "rod starts at resting tip")
	rod.kick(20.0)
	var initial_energy: float = rod.energy
	var maximum_angle: float = 0.0
	for frame in range(ceili(5.0 / dt)):
		rod.tick(dt)
		maximum_angle = maxf(maximum_angle, absf(rod.angle))
		_check(rod.tip.is_finite() and is_finite(rod.energy), "rod remains finite")
	_check(maximum_angle > 0.1 and maximum_angle <= Rod.MAX_BEND + 0.001, "rod impulse causes bounded visible bend")
	_check(rod.energy < initial_energy * 0.0001, "rod spring energy decays")
	rod.set_load(1.0)
	for frame in range(ceili(2.0 / dt)):
		rod.tick(dt)
	_check(absf(rod.angle - Rod.MAX_BEND) < 0.01, "full load reaches 75 degrees")
	_check(rod.tip.y > 238.0, "loaded rod bends toward water")
	rod.set_load(0.0)
	var overshot: bool = false
	for frame in range(ceili(2.0 / dt)):
		rod.tick(dt)
		overshot = overshot or rod.angle < -0.05
	_check(overshot, "released rod whips past resting angle")
	_check(rod.tip.distance_to(Vector2(153.0, 188.0)) < 0.1, "rod returns to rest")
	rod.set_load(-1.0)
	for frame in range(ceili(2.0 / dt)):
		rod.tick(dt)
	_check(absf(rod.angle + Rod.BACKWARD_BEND) < 0.01, "backward catapult load reaches minus 45 degrees")
	_check(rod.tip.x < 153.0 and rod.tip.y < 188.0, "backward load retracts rod tip upward")
	rod.set_load(0.0)
	rod.set_stiffness(40.0)
	for frame in range(ceili(60.0 / dt)):
		if frame % 23 == 0:
			rod.kick(100000.0 if frame % 2 == 0 else -100000.0)
		rod.tick(dt)
		_check(rod.tip.is_finite() and absf(rod.angle) <= Rod.MAX_BEND + 0.001, "rod long run bounded")
		for point in rod.get_points():
			_check(point.is_finite(), "Bezier points finite")
