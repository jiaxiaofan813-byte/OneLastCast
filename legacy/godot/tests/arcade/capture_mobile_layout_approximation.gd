extends SceneTree
# Actual desktop rendering at synthetic phone safe areas, not a native iOS run.
const Main=preload("res://scripts/arcade/arcade_main.gd")
var game
var profile="outer"
func _init() -> void: call_deferred("run")
func find_button(node: Node, value: String) -> Button:
	if node is Button and node.text==value and node.is_visible_in_tree(): return node
	for child in node.get_children():
		var result=find_button(child,value)
		if result: return result
	return null
func click(value: String) -> void:
	var b=find_button(game.frontdoor,value)
	assert(b!=null,"Missing UI button "+value)
	var at=root.get_final_transform()*b.get_global_rect().get_center()
	for down in [true,false]:
		var e=InputEventMouseButton.new(); e.device=707; e.button_index=MOUSE_BUTTON_LEFT; e.position=at; e.global_position=at; e.pressed=down
		root.push_input(e,false)
func capture(page: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img=root.get_texture().get_image()
	var path="res://captures/english/mobile-approx-"+profile+"-"+page+".png"
	img.save_png(path)
	print("SYNTHETIC_DESKTOP_CAPTURE ",path," pixels=",img.get_size()," layout=",game.mobile_safe_area.get_layout())
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
	game=Main.new(); game.test_mode=true; game.force_frontdoor=true; game.force_language="en"; game.force_mobile_safe_area=true; root.add_child(game)
	root.add_child(load("res://tests/arcade/qa_input_guard.gd").new())
	var safe=Rect2(0,60,466,584) if profile=="outer" else Rect2(24,24,903,611)
	game.mobile_safe_area.set_test_safe_area(safe,1.0)
	await create_timer(.3).timeout
	await capture("cover")
	click("Settings"); await create_timer(.2).timeout; assert(game.frontdoor.page=="settings"); await capture("settings")
	click("Done"); click("One Last Cast"); game.frontdoor._finish_opening()
	await create_timer(.1).timeout
	game.set_process(false); game.set_physics_process(false)
	await capture("gameplay")
	print("APPROXIMATION_COMPLETE actual_platform=",OS.get_name()," physical_device=false profile=",profile)
	game._quit_cleanly()
