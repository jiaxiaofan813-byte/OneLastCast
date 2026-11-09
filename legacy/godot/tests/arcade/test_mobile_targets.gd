extends SceneTree
const Main=preload("res://scripts/arcade/arcade_main.gd")
var game
var checks=0
var failures=0
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL ",label)
func fully_in_clip(node: Control) -> bool:
	var parent=node.get_parent()
	while parent:
		if parent is ScrollContainer and not parent.get_global_rect().grow(.1).encloses(node.get_global_rect()): return false
		parent=parent.get_parent()
	return true
func controls(node: Node) -> Array:
	var result=[]
	if (node is Button or node is HSlider) and node.is_visible_in_tree() and fully_in_clip(node): result.append(node)
	for child in node.get_children(): result.append_array(controls(child))
	return result
func verify(host: Node,label: String) -> void:
	await process_frame; await process_frame
	var nodes=controls(host)
	var factor=float(game.mobile_safe_area.get_layout().points_per_logical_unit)
	for b in nodes:
		check(b.size.x*factor>=43.99 and b.size.y*factor>=43.99,label+" native44pt "+str(b.name))
		check(Rect2(0,0,360,640).grow(.1).encloses(b.get_global_rect()),label+" within logical frame")
		var base: Rect2=b.get_meta("mobile_base_rect")
		check((b.position+b.size*.5).is_equal_approx(base.position+base.size*.5),label+" target centre preserved")
	for a in range(nodes.size()):
		for b in range(a+1,nodes.size()):
			check(not nodes[a].get_global_rect().intersects(nodes[b].get_global_rect()),label+" target nonoverlap")
func run() -> void:
	root.size=Vector2i(1398,2034)
	game=Main.new(); game.test_mode=true; game.force_frontdoor=true; game.force_bundled_font=true; game.force_mobile_safe_area=true; game.force_language="en"; root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.mobile_safe_area.set_test_safe_area(Rect2(0,0,1146,1932),3)
	await process_frame; await process_frame
	check(game.mobile_safe_area.minimum_logical_target_size()==47,"measured Duo needs47logical")
	for language in ["en","zh"]:
		game._apply_setting("language",language)
		game.frontdoor.show_title(false); await verify(game.frontdoor,language+" title")
		game.frontdoor.show_title(true); await verify(game.frontdoor,language+" resumable")
		game.frontdoor.show_pause(); await verify(game.frontdoor,language+" pause")
		game.frontdoor.show_settings("pause"); await verify(game.frontdoor,language+" settings")
		game.frontdoor.show_credits("pause"); await verify(game.frontdoor,language+" credits")
		game.frontdoor._confirm_new_day(); await verify(game.frontdoor,language+" confirm")
		game.frontdoor._show_opening(); await verify(game.frontdoor,language+" opening")
		game.frontdoor.close(); game._toggle_catalog(); await verify(game.ui,language+" catalog")
		game._show_species("channel_catfish"); await verify(game.ui,language+" detail")
		game._toggle_catalog()
	var before=game.pause_button.get_rect()
	for i in range(20): game._refresh_mobile_targets()
	check(game.pause_button.get_rect().is_equal_approx(before),"target size never compounds")
	check(game.ledger.total_catches()==0,"no catch mutation")
	print("MOBILE TARGETS: ",checks," checks, ",failures," failures; measuredDuo47logical>=44pt")
	quit(1 if failures else 0)
