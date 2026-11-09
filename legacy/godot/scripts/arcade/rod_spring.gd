extends RefCounted
## Six coupled angular spring segments with cubic Bezier rendering.
## Logical points; positive rotation bends the rod toward the water.

const SEGMENTS: int = 6
const MAX_BEND: float = PI * 75.0 / 180.0
const BACKWARD_BEND: float = PI * 45.0 / 180.0
var natural_frequency: float = 18.0 # radians / second
var damping_ratio: float = 0.35
var tip := Vector2(153.0, 188.0)
var angle: float = 0.0 # Tip tangent deflection relative to resting rod, radians.
var energy: float = 0.0 # Relative spring energy in normalized angular units.
var base := Vector2(83.0, 238.0)
var _rest_tip := Vector2(153.0, 188.0)
var _load: float = 0.0
var _angles := PackedFloat64Array()
var _velocities := PackedFloat64Array()
var _accelerations := PackedFloat64Array()
var _nodes := PackedVector2Array()

func setup(p_base: Vector2 = Vector2(83.0, 238.0), p_rest_tip: Vector2 = Vector2(153.0, 188.0)) -> void:
	base = p_base
	_rest_tip = p_rest_tip
	_load = 0.0
	_angles.resize(SEGMENTS)
	_velocities.resize(SEGMENTS)
	_accelerations.resize(SEGMENTS)
	_angles.fill(0.0)
	_velocities.fill(0.0)
	_nodes.resize(SEGMENTS + 1)
	_rebuild()

func set_load(amount: float) -> void:
	if is_finite(amount):
		_load = clampf(amount, -1.0, 1.0)

func set_stiffness(value: float) -> void:
	# Slider value is omega_n in rad/s (default 18), not omega squared.
	if is_finite(value):
		natural_frequency = clampf(value, 4.0, 40.0)

func kick(impulse: float) -> void:
	if _angles.is_empty():
		setup()
	if not is_finite(impulse):
		return
	for i in range(SEGMENTS):
		_velocities[i] = clampf(_velocities[i] + clampf(impulse, -45.0, 45.0) * _weight(i), -60.0, 60.0)
	_rebuild()

func tick(dt: float) -> void:
	if _angles.is_empty():
		setup()
	if not is_finite(dt) or dt <= 0.0:
		return
	var elapsed: float = minf(dt, 0.25)
	var steps: int = maxi(1, ceili(elapsed * 240.0))
	var h: float = elapsed / float(steps)
	var omega: float = clampf(natural_frequency, 4.0, 40.0)
	var k: float = omega * omega
	var coupling: float = k * 0.18
	var decay: float = exp(-2.0 * clampf(damping_ratio, 0.0, 2.0) * omega * h)
	for step in range(steps):
		for i in range(SEGMENTS):
			var error: float = _angles[i] - _target(i)
			var left: float = _angles[maxi(0, i - 1)] - _target(maxi(0, i - 1))
			var right: float = _angles[mini(SEGMENTS - 1, i + 1)] - _target(mini(SEGMENTS - 1, i + 1))
			_accelerations[i] = -k * error + coupling * (left + right - 2.0 * error)
		for i in range(SEGMENTS):
			_velocities[i] = (_velocities[i] + _accelerations[i] * h) * decay
			_angles[i] += _velocities[i] * h
			if absf(_angles[i]) > MAX_BEND:
				_angles[i] = clampf(_angles[i], -MAX_BEND, MAX_BEND)
				_velocities[i] *= -0.12
	_rebuild()

func _weight(i: int) -> float:
	return pow(float(i + 1) / float(SEGMENTS), 1.35)

func _target(i: int) -> float:
	return _load * (MAX_BEND if _load >= 0.0 else BACKWARD_BEND) * _weight(i)

func _rebuild() -> void:
	var rest: Vector2 = _rest_tip - base
	var segment_length: float = rest.length() / float(SEGMENTS)
	_nodes[0] = base
	energy = 0.0
	var k: float = pow(clampf(natural_frequency, 4.0, 40.0), 2.0)
	for i in range(SEGMENTS):
		_nodes[i + 1] = _nodes[i] + Vector2.from_angle(rest.angle() + _angles[i]) * segment_length
		var error: float = _angles[i] - _target(i)
		energy += 0.5 * (_velocities[i] * _velocities[i] + k * error * error)
		if i > 0:
			var difference: float = error - (_angles[i - 1] - _target(i - 1))
			energy += 0.5 * k * 0.18 * difference * difference
	tip = _nodes[SEGMENTS]
	angle = _angles[SEGMENTS - 1]

func get_points() -> PackedVector2Array:
	if _angles.is_empty():
		setup()
	var points := PackedVector2Array()
	points.append(_nodes[0])
	# Cubic spans interpolate all seven physical nodes with shared tangents.
	for i in range(SEGMENTS):
		var start: Vector2 = _nodes[i]
		var end: Vector2 = _nodes[i + 1]
		var tangent_a: Vector2 = (_nodes[i + 1] - _nodes[maxi(0, i - 1)]) * 0.5
		var tangent_b: Vector2 = (_nodes[mini(SEGMENTS, i + 2)] - _nodes[i]) * 0.5
		for sample_index in range(1, 5):
			points.append(start.bezier_interpolate(start + tangent_a / 3.0, end - tangent_b / 3.0, end, float(sample_index) / 4.0))
	return points
