extends SceneTree
## Actual game+GUI integration with synthetic safe insets. Not a native device run.
## test_mode remains true: the player's settings, language and progress are not read/written.
const Main = preload("res://scripts/arcade/arcade_main.gd")
const DT := 1.0 / 60.0
var game
var checks := 0
var failures := 0
var gui_clicks := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func step(frames: int = 1) -> void:
	for i in frames:
		game._physics_process(DT)
		game._process(DT)
func event_logical(point: Vector2, pressed: bool) -> void:
	var physical := root.get_final_transform()*point
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=pressed
	event.position=physical
	event.global_position=physical
	root.push_input(event,false)
func click_logical(point: Vector2) -> void:
	event_logical(point,true)
	event_logical(point,false)
func find_button(node: Node, text: String) -> Button:
	if node is Button and node.is_visible_in_tree() and node.text==text: return node
	for child in node.get_children():
		var found := find_button(child,text)
		if found != null: return found
	return null
func click_button(text: String) -> void:
	var button := find_button(game.frontdoor,text)
	check(button != null and not button.disabled,"Visible transformed GUI button: "+text)
	if button==null or button.disabled: return
	var point := button.get_global_transform_with_canvas()*(button.size*0.5)
	click_logical(point)
	gui_clicks += 1
func snapshot() -> Dictionary:
	return {"rules":game.rules.snapshot(),"visual_time":game.visual_time,"fx_rng":game.rng.state,
		"ledger":game.ledger.save_to_dictionary().duplicate(true),"ledger_run":game.ledger_run,
		"ledger_session":game.ledger_session,"best_score":game.best_score,"best_combo":game.best_combo,
		"game_id":game.get_instance_id(),"rules_id":game.rules.get_instance_id(),"world_id":game.world.get_instance_id()}
func fit(window_size: Vector2i, safe: Rect2) -> void:
	root.size=window_size
	game.mobile_safe_area.set_test_safe_area(safe,3.0)
	game.mobile_safe_area.refresh_now()
func _run() -> void:
	root.content_scale_size=Vector2i(360,640)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
	root.size=Vector2i(1398,2034)
	game=Main.new()
	game.test_mode=true
	game.force_frontdoor=true
	game.force_language="en"
	game.force_mobile_safe_area=true
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.muted=true
	game.haptics.enabled=false
	check(game.mobile_safe_area!=null,"Actual main installs forced mobile adapter")
	fit(Vector2i(1398,2034),Rect2(0,180,1398,1752))
	await process_frame
	await process_frame
	check(game.frontdoor.page=="title" and game.language=="en","Forced English frontdoor starts normally")
	check(not game.paused and not game.has_started,"Initial safe fit does not create a hidden pause")
	check(game.ledger.total_catches()==0 and game.best_score==0,"Test startup did not load player progress")
	click_button("One Last Cast")
	check(game.frontdoor.page=="opening","Actual scaled title click starts opening")
	game.frontdoor.set_process(false)
	game.frontdoor._finish_opening()
	check(game.has_started and not game.paused and not game.frontdoor.blocking,"Opening enters playable same game")
	var opportunity := false
	for i in range(180):
		if game.rules.predict_slam_contact().get("category", "")=="fish":
			click_logical(Vector2(180,620))
			opportunity=true
			break
		step()
	check(opportunity,"Actual transformed gameplay click reaches a real fish opportunity")
	for i in range(180):
		if game.rules.state=="bite_window": break
		step()
	check(game.rules.state=="bite_window","Real deterministic fish collision reaches timed ring")
	if game.rules.state!="bite_window":
		quit(1)
		return
	var before := snapshot()
	fit(Vector2i(2853,2007),Rect2(72,72,2709,1833))
	await process_frame
	check(game.paused and game.frontdoor.page=="pause","Outer-to-inner layout change pauses timed ring")
	step(40)
	check(snapshot()==before,"Outer-to-inner preserves exact rules/RNG/events, ring clock, ledger, visual clock and instances")
	click_button("Settings")
	check(game.frontdoor.page=="settings" and game.paused,"Scaled Settings opens without unpausing")
	click_button("中文")
	await process_frame
	check(game.language=="zh" and game.frontdoor.page=="settings","Scaled Chinese picker rebuilds same settings page")
	step(10)
	check(snapshot()==before,"Chinese switch during transformed pause preserves exact game state")
	click_button("English")
	await process_frame
	check(game.language=="en" and game.frontdoor.page=="settings","Scaled English picker works after UI rebuild")
	step(10)
	check(snapshot()==before,"English switch preserves exact game state")
	click_button("Done")
	check(game.frontdoor.page=="pause" and game.paused,"Scaled Done returns to paused menu")
	click_button("Keep Fishing")
	check(not game.paused and not game.frontdoor.blocking,"Scaled Resume returns to same ring")
	check(snapshot()==before,"Resume does not advance/reset the ring or RNG")
	fit(Vector2i(1398,2034),Rect2(0,180,1398,1752))
	await process_frame
	check(game.paused and game.frontdoor.page=="pause","Inner-to-outer layout change pauses again")
	step(40)
	check(snapshot()==before,"Round-trip fold retains the exact same ring and scene")
	click_button("Keep Fishing")
	check(not game.paused and snapshot()==before,"Second transformed Resume preserves exact state")
	# The physical click is inside the window, but in the adapted left margin.
	click_logical(Vector2(-4,320))
	check(snapshot()==before and not game.pointer_held,"Letterbox click cannot trigger a fishing action")
	game.pointer_held=true
	game.rules.held=true
	event_logical(Vector2(-4,320),false)
	check(not game.pointer_held and not game.rules.held,"Release in letterbox clears both held flags")
	var ring_before: float=game.rules.ring_elapsed
	step()
	check(game.rules.ring_elapsed>ring_before,"Same ring advances only after explicit Resume")
	check(root.get_visible_rect().size.is_equal_approx(Vector2(360,640)),"Actual game logical viewport remains 360x640")
	check(game.test_mode,"Save I/O guard remains enabled throughout every settings and game action")
	game.queue_free()
	await process_frame
	check(root.global_canvas_transform.is_equal_approx(Transform2D.IDENTITY),"Removing game restores root transform")
	print("MOBILE_GAME_INTEGRATION ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures," transformed_gui_clicks=",gui_clicks)
	quit(0 if failures==0 else 1)
