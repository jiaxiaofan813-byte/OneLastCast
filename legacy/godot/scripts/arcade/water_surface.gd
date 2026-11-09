extends RefCounted
## A damped, nearest-neighbour 1D spring lattice in logical screen points.
## Positive displacement and splash impulse point DOWN into the water.

var stiffness: float = 48.0
var damping: float = 3.8
var spread: float = 110.0 # Neighbour coupling, not splash radius.
var max_displacement: float = 20.0
var width: float = 360.0
var baseline: float = 288.0
var _heights := PackedFloat64Array()
var _velocities := PackedFloat64Array()
var _accelerations := PackedFloat64Array()

func setup(p_width: float = 360.0, p_baseline: float = 288.0, count: int = 64) -> void:
	width = maxf(1.0, p_width)
	baseline = p_baseline
	_heights.resize(maxi(2, count))
	_velocities.resize(_heights.size())
	_accelerations.resize(_heights.size())
	_heights.fill(0.0)
	_velocities.fill(0.0)

func tick(dt: float) -> void:
	if _heights.is_empty():
		setup()
	if not is_finite(dt) or dt <= 0.0:
		return
	# Bound work after a suspended frame. 120 Hz substeps also support 33 ms ticks.
	var elapsed: float = minf(dt, 0.25)
	var steps: int = maxi(1, ceili(elapsed * 120.0))
	var h: float = elapsed / float(steps)
	var k: float = clampf(stiffness, 0.0, 1000.0)
	var coupling: float = clampf(spread, 0.0, 1000.0)
	var decay: float = exp(-clampf(damping, 0.0, 100.0) * h)
	var limit: float = clampf(max_displacement, 0.1, 21.0)
	for step in range(steps):
		for i in range(_heights.size()):
			# Free reflecting boundaries: edge points have only one neighbour.
			var left: float = _heights[maxi(0, i - 1)]
			var right: float = _heights[mini(_heights.size() - 1, i + 1)]
			_accelerations[i] = -k * _heights[i] + coupling * (left + right - 2.0 * _heights[i])
		for i in range(_heights.size()):
			_velocities[i] = (_velocities[i] + _accelerations[i] * h) * decay
			_heights[i] += _velocities[i] * h
			if absf(_heights[i]) > limit:
				_heights[i] = clampf(_heights[i], -limit, limit)
				_velocities[i] *= -0.15

func splash(x: float, strength: float, radius: float = 14.0) -> void:
	if _heights.is_empty():
		setup()
	if not is_finite(x) or not is_finite(strength) or not is_finite(radius):
		return
	var sigma: float = maxf(width / float(_heights.size() - 1), absf(radius))
	for i in range(_heights.size()):
		var distance: float = (float(i) * width / float(_heights.size() - 1) - x) / sigma
		_velocities[i] = clampf(_velocities[i] + clampf(strength, -600.0, 600.0) * exp(-0.5 * distance * distance), -600.0, 600.0)

func get_surface_points() -> PackedVector2Array:
	if _heights.is_empty():
		setup()
	var points := PackedVector2Array()
	points.resize(_heights.size())
	for i in range(_heights.size()):
		points[i] = Vector2(float(i) * width / float(_heights.size() - 1), baseline + _heights[i])
	return points

func get_y(x: float) -> float:
	if _heights.is_empty():
		setup()
	var index: float = clampf(x / width, 0.0, 1.0) * float(_heights.size() - 1)
	var a: int = floori(index)
	return baseline + lerpf(_heights[a], _heights[mini(a + 1, _heights.size() - 1)], index - float(a))
