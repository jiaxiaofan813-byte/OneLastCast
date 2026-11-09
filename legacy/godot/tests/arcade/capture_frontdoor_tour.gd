extends SceneTree
const Main=preload("res://scripts/arcade/arcade_main.gd")
var game
func _init() -> void: call_deferred("run")
func hold(seconds: float) -> void: await create_timer(seconds).timeout
func find_button(node: Node, text_value: String) -> Button:
	if node is Button and node.text==text_value and node.is_visible_in_tree(): return node
	for child in node.get_children():
		var found=find_button(child,text_value)
		if found: return found
	return null
func click(text_value: String) -> void:
	var button=find_button(game.frontdoor if game._frontdoor_blocks() else game,text_value)
	if not button:
		push_error("Tour button missing: "+text_value); quit(1); return
	for down in [true,false]:
		var event=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT
		event.position=button.get_global_rect().get_center(); event.pressed=down
		root.push_input(event,true)
	print("TOUR_CLICK ",text_value," page=",game.frontdoor.page)
func capture(label: String) -> void:
	await process_frame
	var image=root.get_texture().get_image()
	var prefix=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tour-label="): prefix=arg.trim_prefix("--tour-label=")+"-"
	var target="res://captures/frontdoor/"+prefix+label+".png"
	image.save_png(target)
	print("TOUR_CAPTURE ",label," ",image.get_size())
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures/frontdoor"))
	game=Main.new(); game.test_mode=true; game.force_frontdoor=true; root.add_child(game)
	await hold(.5); await capture("cover"); await hold(1.5)
	click("设置"); await hold(.3); await capture("settings"); await hold(1.7)
	click("完成 · 返回"); await hold(.2); click("致谢"); await hold(.3); await capture("credits"); await hold(2.2)
	click("返回"); await hold(.2); click("鱼册"); await hold(.3); await capture("catalog"); await hold(1.5)
	click("×"); await hold(.25)
	click("开钓，最后一竿"); await hold(.25); await capture("opening")
	await hold(.8)
	game._toggle_pause(); await hold(.2); await capture("pause"); await hold(1.5)
	if "--qa-menu-only" in OS.get_cmdline_user_args():
		game._quit_cleanly(); return
	click("继续钓鱼")
	print("TOUR_GAMEPLAY_BEGIN")
