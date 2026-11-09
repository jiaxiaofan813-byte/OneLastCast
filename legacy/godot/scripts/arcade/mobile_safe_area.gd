extends Node
## Fits the existing 360x640 canvas inside the current iOS safe area.
## Owns only the root global canvas transform. It never recreates gameplay,
## changes the camera, forwards input, or changes the rules/save state.
## The root viewport still uses canvas_items + keep and 360x640 logical units.

signal layout_changed(previous: Dictionary, current: Dictionary)

const LOGICAL_SIZE := Vector2(360, 640)
const LOGICAL_RECT := Rect2(Vector2.ZERO, LOGICAL_SIZE)
const POLL_INTERVAL := 0.25

var _window: Window
var _original_global := Transform2D.IDENTITY
var _layout: Dictionary = {}
var _poll_elapsed := 0.0
var _refresh_queued := false
var _test_override := false
var _test_safe_rect := Rect2()
var _test_native_scale := 1.0
var _border_layer: CanvasLayer
var _border_masks: Array[ColorRect] = []

func _ready() -> void:
	_window = get_window()
	_original_global = _window.global_canvas_transform
	_window.size_changed.connect(request_refresh)
	set_process(is_active())
	request_refresh()

func _exit_tree() -> void:
	if is_instance_valid(_window):
		_window.global_canvas_transform = _original_global

func is_active() -> bool:
	return _test_override or OS.get_name() == "iOS"

## For deterministic probes only. The caller owns the test window dimensions.
## This is a window-local pixel rectangle, not a claimed device safe inset.
func set_test_safe_area(safe_rect_pixels: Rect2, native_pixel_scale: float = 1.0) -> void:
	_test_override = true
	_test_safe_rect = safe_rect_pixels
	_test_native_scale = maxf(native_pixel_scale, 0.01)
	set_process(true)
	request_refresh()

func clear_test_override() -> void:
	_test_override = false
	set_process(is_active())
	request_refresh()

func request_refresh() -> void:
	if not is_inside_tree() or _refresh_queued:
		return
	_refresh_queued = true
	_refresh_deferred.call_deferred()

func _refresh_deferred() -> void:
	_refresh_queued = false
	refresh_now()

func _process(delta: float) -> void:
	# Insets can change without a pixel-size change (system overlays/folding).
	_poll_elapsed += delta
	if _poll_elapsed >= POLL_INTERVAL:
		_poll_elapsed = 0.0
		refresh_now()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		request_refresh()

func get_layout() -> Dictionary:
	return _layout.duplicate(true)

func contains_logical_point(point: Vector2) -> bool:
	return LOGICAL_RECT.has_point(point)

## UI owners can enlarge hit targets when a short safe height scales down.
## This helper does not change control sizes or promise physical-device QA.
func minimum_logical_target_size(minimum_points: float = 44.0) -> float:
	var point_scale: float = _layout.get("points_per_logical_unit", 1.0)
	return ceilf(maxf(0.0, minimum_points) / maxf(point_scale, 0.001))

func refresh_now() -> Dictionary:
	if not is_instance_valid(_window):
		return {}
	if not is_active():
		_window.global_canvas_transform = _original_global
		_layout = {}
		if is_instance_valid(_border_layer): _border_layer.hide()
		return {}
	var window_size := Vector2(_window.size)
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return get_layout()
	var safe := _test_safe_rect
	var native_scale := _test_native_scale
	if not _test_override:
		safe = Rect2(DisplayServer.get_display_safe_area())
		# Godot's Apple backend returns physical pixels with screen origin.
		# Its window origin is currently zero, but keep the conversion explicit.
		safe.position -= Vector2(DisplayServer.window_get_position(_window.get_window_id()))
		native_scale = DisplayServer.screen_get_scale(_window.current_screen)
	safe = safe.intersection(Rect2(Vector2.ZERO, window_size))
	# Ignore transient invalid geometry instead of collapsing the canvas.
	if not safe.has_area() or not is_finite(native_scale) or native_scale <= 0.0:
		return get_layout()
	var current := _window.global_canvas_transform
	if is_zero_approx(current.determinant()):
		return get_layout()
	# Remove our current fit before recomputing. Never compound the scale.
	var baseline := _window.get_final_transform() * current.affine_inverse() * _original_global
	if is_zero_approx(baseline.determinant()):
		return get_layout()
	var logical_safe := (baseline.affine_inverse() * safe).intersection(LOGICAL_RECT)
	if not logical_safe.has_area():
		return get_layout()
	var fit := minf(logical_safe.size.x / LOGICAL_SIZE.x, logical_safe.size.y / LOGICAL_SIZE.y)
	var offset := logical_safe.position + (logical_safe.size - LOGICAL_SIZE * fit) * 0.5
	var fitting := Transform2D(Vector2(fit, 0), Vector2(0, fit), offset)
	var applied := _original_global * fitting
	_window.global_canvas_transform = applied
	# Godot applies this transform to world and CanvasLayer render canvases,
	# and its root push_input path applies the inverse before GUI hit testing.
	var final_transform := _window.get_final_transform()
	_update_border_masks(final_transform, window_size)
	var pixel_scale := minf(final_transform.x.length(), final_transform.y.length())
	var next := {
		"window_pixels": window_size,
		"safe_rect_pixels": safe,
		"content_rect_pixels": final_transform * LOGICAL_RECT,
		"logical_safe_rect": logical_safe,
		"applied_transform": applied,
		"pixels_per_logical_unit": pixel_scale,
		"native_pixel_scale": native_scale,
		"points_per_logical_unit": pixel_scale / native_scale,
	}
	var changed := not _layout.is_empty() and (
		not (_layout.window_pixels as Vector2).is_equal_approx(window_size)
		or not (_layout.safe_rect_pixels as Rect2).is_equal_approx(safe)
		or not (_layout.applied_transform as Transform2D).is_equal_approx(applied)
		or not is_equal_approx(float(_layout.native_pixel_scale), native_scale)
	)
	var previous := _layout
	_layout = next
	if (previous.is_empty() or changed) and OS.get_name() == "iOS" and OS.is_debug_build():
		# Geometry only, never player data. Native diagnostics are distinct from
		# synthetic desktop tests and are emitted only on a real layout change.
		var content: Rect2 = next.content_rect_pixels
		print("OLC_MOBILE_LAYOUT ", JSON.stringify({
			"window_pixels": [window_size.x, window_size.y],
			"safe_rect_pixels": [safe.position.x, safe.position.y, safe.size.x, safe.size.y],
			"content_rect_pixels": [content.position.x, content.position.y, content.size.x, content.size.y],
			"native_pixel_scale": native_scale,
			"points_per_logical_unit": next.points_per_logical_unit,
			"minimum_44pt_logical_target": minimum_logical_target_size(44),
		}))
	if changed:
		# The owner decides whether to pause a timed ring during a transition.
		# No signal on the initial layout, and no game state is changed here.
		layout_changed.emit(previous.duplicate(true), next.duplicate(true))
	return get_layout()

## The world intentionally draws beyond the gameplay frame for camera motion.
## After a safe-area fit that art must not leak into the newly exposed margins.
## These masks share the root canvas transform but ignore both camera and input.
func _update_border_masks(final_transform: Transform2D, window_size: Vector2) -> void:
	if not is_instance_valid(_border_layer):
		_border_layer = CanvasLayer.new()
		_border_layer.name = "MobileLetterbox"
		_border_layer.layer = 128
		add_child(_border_layer)
		for index in range(4):
			var mask := ColorRect.new()
			mask.name = "Border%d" % index
			mask.color = Color.BLACK
			mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mask.focus_mode = Control.FOCUS_NONE
			_border_layer.add_child(mask)
			_border_masks.append(mask)
	_border_layer.show()
	var visible := final_transform.affine_inverse() * Rect2(Vector2.ZERO, window_size)
	var left := minf(visible.position.x, 0.0)
	var top := minf(visible.position.y, 0.0)
	var right := maxf(visible.end.x, LOGICAL_SIZE.x)
	var bottom := maxf(visible.end.y, LOGICAL_SIZE.y)
	var borders: Array[Rect2] = [
		Rect2(left, top, right - left, -top),
		Rect2(left, LOGICAL_SIZE.y, right - left, bottom - LOGICAL_SIZE.y),
		Rect2(left, 0, -left, LOGICAL_SIZE.y),
		Rect2(LOGICAL_SIZE.x, 0, right - LOGICAL_SIZE.x, LOGICAL_SIZE.y),
	]
	for index in range(borders.size()):
		_border_masks[index].position = borders[index].position
		_border_masks[index].size = borders[index].size
		_border_masks[index].visible = borders[index].has_area()
