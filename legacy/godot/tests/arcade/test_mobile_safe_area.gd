extends SceneTree
const Adapter = preload("res://scripts/arcade/mobile_safe_area.gd")
var failures := 0
var checks := 0
var hits := 0
var changes := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func click_physical(position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		root.push_input(event, false)
func _run() -> void:
	root.content_scale_size = Vector2i(360,640)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(504,896)
	var world := Node2D.new()
	root.add_child(world)
	var camera := Camera2D.new()
	camera.position = Vector2(180,320)
	world.add_child(camera)
	var marker := Node2D.new()
	marker.position = Vector2(320,40)
	world.add_child(marker)
	var world_id := world.get_instance_id()
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var button := Button.new()
	button.position = Vector2(298,18)
	button.size = Vector2(44,44)
	button.pressed.connect(func(): hits += 1)
	layer.add_child(button)
	var adapter := Adapter.new()
	root.add_child(adapter)
	adapter.layout_changed.connect(func(_old: Dictionary, _new: Dictionary): changes += 1)
	await process_frame
	check(adapter.get_layout().is_empty(), "Desktop is unchanged without explicit test override")
	check(root.global_canvas_transform.is_equal_approx(Transform2D.IDENTITY), "Desktop transform preserved")
	var cases := [
		{"name":"baseline", "window":Vector2i(504,896), "safe":Rect2(0,0,504,896), "scale":1.0},
		{"name":"phone_tall_synthetic", "window":Vector2i(1206,2622), "safe":Rect2(0,186,1206,2334), "scale":3.0},
		{"name":"duo_outer_profile_synthetic", "window":Vector2i(1398,2034), "safe":Rect2(0,180,1398,1752), "scale":3.0},
		{"name":"duo_inner_landscape_profile_synthetic", "window":Vector2i(2853,2007), "safe":Rect2(72,72,2709,1833), "scale":3.0},
		{"name":"duo_inner_portrait_profile_synthetic", "window":Vector2i(2007,2853), "safe":Rect2(0,72,2007,2679), "scale":3.0},
		{"name":"native_duo_measured_portrait", "window":Vector2i(1398,2034), "safe":Rect2(0,0,1146,1932), "scale":3.0},
		{"name":"outer_return", "window":Vector2i(1398,2034), "safe":Rect2(0,180,1398,1752), "scale":3.0},
	]
	for c in cases:
		root.size = c.window
		adapter.set_test_safe_area(c.safe, c.scale)
		await process_frame
		await process_frame
		var layout: Dictionary = adapter.refresh_now()
		check(not layout.is_empty(), c.name+": layout exists")
		check(c.safe.grow(0.1).encloses(layout.content_rect_pixels), c.name+": content within safe area")
		check(root.get_visible_rect().size.is_equal_approx(Vector2(360,640)), c.name+": logical viewport preserved")
		check(world.get_instance_id()==world_id, c.name+": world instance preserved")
		check(camera.position==Vector2(180,320), c.name+": camera state preserved")
		var transform := root.global_canvas_transform
		var signal_count := changes
		for i in range(100): adapter.refresh_now()
		check(root.global_canvas_transform.is_equal_approx(transform), c.name+": fit is not cumulative")
		check(changes==signal_count, c.name+": no repeated layout notification")
		var before := hits
		var screen_center := root.get_final_transform()*Vector2(320,40)
		click_physical(screen_center)
		check(hits==before+1, c.name+": CanvasLayer button consumes exactly one click")
		var world_screen := marker.get_screen_transform()*Vector2.ZERO
		var ui_screen := button.get_screen_transform()*Vector2(22,22)
		print("TRANSFORM_PROBE ",c.name," world=",world_screen," UI=",ui_screen," target=",screen_center," camera=",root.canvas_transform," window_position=",root.position)
		check(world_screen.is_equal_approx(ui_screen), c.name+": world and UI share fit")
		var border_layer: CanvasLayer = adapter.get_node("MobileLetterbox")
		check(border_layer.layer > layer.layer, c.name+": borders overlay world and UI")
		var masks_safe := true
		for mask: ColorRect in border_layer.get_children():
			masks_safe = masks_safe and mask.mouse_filter == Control.MOUSE_FILTER_IGNORE and mask.focus_mode == Control.FOCUS_NONE
			masks_safe = masks_safe and not mask.get_rect().intersects(Rect2(0.01,0.01,359.98,639.98))
		check(masks_safe, c.name+": borders cannot cover or intercept logical controls")
		var all_margin_points_masked := true
		var inverse := root.get_final_transform().affine_inverse()
		for x in [0.5, float(c.window.x)*0.5, float(c.window.x)-0.5]:
			for y in [0.5, float(c.window.y)*0.5, float(c.window.y)-0.5]:
				var logical: Vector2 = inverse * Vector2(x,y)
				if Rect2(0,0,360,640).has_point(logical): continue
				var covered := false
				for mask: ColorRect in border_layer.get_children():
					covered = covered or (mask.visible and mask.get_rect().grow(0.001).has_point(logical))
				all_margin_points_masked = all_margin_points_masked and covered
		check(all_margin_points_masked, c.name+": all sampled outer margins are masked")
		check(adapter.minimum_logical_target_size()*float(layout.points_per_logical_unit)>=43.999, c.name+": minimum point target helper")
		print("SAFE_AREA_CASE ",c.name," content=",layout.content_rect_pixels," logical44_points=",44.0*float(layout.points_per_logical_unit)," min44pt_logical=",adapter.minimum_logical_target_size())
	check(changes>=5,"Each changed device geometry notifies owner")
	check(adapter.contains_logical_point(Vector2(180,320)),"Content point accepted")
	check(not adapter.contains_logical_point(Vector2(-1,320)),"Left letterbox point rejected")
	check(not adapter.contains_logical_point(Vector2(361,320)),"Right letterbox point rejected")
	var last := root.global_canvas_transform
	adapter.set_test_safe_area(Rect2(),3.0)
	adapter.refresh_now()
	check(root.global_canvas_transform.is_equal_approx(last),"Transient zero safe area preserves last valid layout")
	adapter.set_test_safe_area(Rect2(0,180,1398,1752),3.0)
	adapter.refresh_now()
	var before_insets := changes
	adapter.set_test_safe_area(Rect2(0,120,1398,1812),3.0)
	adapter.refresh_now()
	check(changes==before_insets+1,"Safe inset change without resize notifies owner")
	adapter.clear_test_override()
	adapter.refresh_now()
	check(root.global_canvas_transform.is_equal_approx(Transform2D.IDENTITY),"Disable restores original transform")
	check(adapter.get_layout().is_empty(),"Disable clears stale diagnostics")
	check(not adapter.get_node("MobileLetterbox").visible,"Disable hides all border masks")
	print("MOBILE_SAFE_AREA_TEST ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures," hits=",hits," layout_changes=",changes)
	quit(0 if failures==0 else 1)
