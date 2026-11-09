extends Node2D
const Rules=preload("res://scripts/arcade/arcade_rules.gd")
const Surface=preload("res://scripts/arcade/water_surface.gd")
const Rod=preload("res://scripts/arcade/rod_spring.gd")
const Haptics=preload("res://scripts/arcade/haptic_feedback.gd")
const Catalog=preload("res://scripts/arcade/fish_catalog.gd")
const Ledger=preload("res://scripts/arcade/catch_ledger.gd")
const Frontdoor=preload("res://scripts/arcade/frontdoor_ui.gd")
const Music=preload("res://scripts/arcade/music_controller.gd")
const FishGeometry=preload("res://scripts/arcade/fish_geometry.gd")
const SafeArea=preload("res://scripts/arcade/mobile_safe_area.gd")
const INK=Color("173f4a")
const CREAM=Color("fff1ce")
const GOLD=Color("ffd36c")
const SPECIES_ZH=["蓝鳃太阳鱼","南瓜籽太阳鱼","黑莓鲈","黄鲈","大口黑鲈","大眼梭鲈","巨型大口黑鲈","白斑狗鱼"]
var ledger=Ledger.new()
var ledger_session=str(Time.get_unix_time_from_system())+"-"+str(Time.get_ticks_usec())
var ledger_run=0
var catalog_open=false
var catalog_descending=true
var catalog_panel: Panel
var catalog_title: Label
var catalog_rows: VBoxContainer
var catalog_scroll: ScrollContainer
var catalog_detail: Control
var catalog_button: Button
var rules=Rules.new()
var water=Surface.new()
var rod=Rod.new()
var haptics=Haptics.new()
var font=SystemFont.new()
var world: Node2D
var camera: Camera2D
var ui: Control
var title_label: Label
var score_label: Label
var combo_label: Label
var ecology_label: Label
var instruction_label: Label
var sub_label: Label
var pause_button: Button
var debug_button: Button
var pause_panel: Panel
var debug_panel: Panel
var detail_label: Label
var intro_panel: Panel
var intro_active=false
var result_panel: Panel
var result_title: Label
var result_score: Label
var result_detail: Label
var tune_labels: Dictionary={}
var sliders: Dictionary={}
var muted=false
var reduced_motion=false
var paused=false
var debug_open=false
var help_open=false
var rearm_hold=false
var pointer_held=false
var pointer_start=Vector2.ZERO
var pointer_clock=0.0
var flick_sent=false
var visual_time=0.0
var frozen_clock=0.0
var camera_zoom=1.0
var shake_left=0.0
var button_pulse=0.0
var basket_pulse=0.0
var perfect_flash=0.0
var combo_pulse=0.0
var fever_amount=0.0
var night_amount=0.0
var home_clock=0.0
@export_range(.25,1.5,.05) var home_duration=.8
@export_range(.05,.5,.01) var night_duration=.16
@export_range(0,.5,.01) var score_delay=.22
var particles: Array[Dictionary]=[]
var toasts: Array[Dictionary]=[]
var spark_trails: Array[Dictionary]=[]
var sound_bank: Dictionary={}
var fish_textures: Dictionary={}
var voices: Array[AudioStreamPlayer]=[]
var delayed_haptics: Array[Dictionary]=[]
var best_combo=0
var best_score=0
var basket_fish: Array[Dictionary]=[]
var rounds_finished=0
var goodbye_line=""
var fail_visual=""
var escaped_pos=Vector2.ZERO
var escaped_kind=0
var escaped_category="fish"
var escaped_species_id=""
var night_start_delay=0.0
var cue_text=""
var cue_left=0.0
var last_fingerprint=0
var rng=RandomNumberGenerator.new()
var qa=false
var qa_done=false
var qa_target=12
var qa_times: Array[float]=[]
var qa_events: Array[Dictionary]=[]
var frame_samples: Array[float]=[]
var input_samples: Array[float]=[]
var qa_elapsed=0.0
var qa_phase="run"
var qa_failure_mode=""
var qa_cast_plan=-1.0
var qa_salvages=0
var qa_game_over_clock=0.0
var qa_capture_busy=false
var qa_captures: Dictionary={}
var qa_peak_catches=0
var qa_peak_combo=0
var qa_peak_score=0
var frontdoor: Control
var music_controller: Node
var force_frontdoor=false
var force_mobile_safe_area=false
var force_bundled_font=false
var mobile_safe_area
var mobile_target_refresh_queued=false
var language="en"
var force_language=""
var catalog_detail_species=""
var has_started=false
var catalog_return_page=""
var music_enabled=true
var music_volume=.4
var sfx_volume=.85
var app_has_focus=true
var test_mode=false
var data_dir="res://runtime"

func _ready() -> void:
	if OS.get_name()=="iOS" or force_bundled_font or (test_mode and "--qa-bundled-font" in OS.get_cmdline_user_args()):
		font=load("res://assets/fonts/NotoSansSC-Regular.ttf") as FontFile
		font.allow_system_fallback=false
	else:
		font.font_names=PackedStringArray(["PingFang SC","Hiragino Sans GB","Arial"])
	rng.seed=7441
	qa="--arcade-demo" in OS.get_cmdline_user_args() or "--shallow-demo" in OS.get_cmdline_user_args()
	test_mode=test_mode or qa
	language="zh" if test_mode else "en"
	intro_active=false
	force_frontdoor=force_frontdoor or "--qa-frontdoor" in OS.get_cmdline_user_args()
	has_started="--skip-intro" in OS.get_cmdline_user_args() or (test_mode and not force_frontdoor)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--language="): force_language=_normalize_language(arg.trim_prefix("--language="))
		if arg.begins_with("--qa-failure="): qa_failure_mode=arg.trim_prefix("--qa-failure=")
		if arg.begins_with("--demo-catches="): qa_target=maxi(1,int(arg.trim_prefix("--demo-catches=")))
	data_dir="res://runtime" if OS.has_feature("editor") else "user://"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(data_dir))
	_load_settings()
	_load_progress()
	_load_language_preferences()
	if not force_language.is_empty(): language=_normalize_language(force_language)
	goodbye_line=_goodbye_line()
	rules.setup(20261109)
	water.setup(360.0,288.0,64)
	rod.setup(Vector2(83,238),Vector2(148,182))
	rod.set_stiffness(rules.tune.rod_stiffness)
	world=Node2D.new(); add_child(world); world.draw.connect(_draw_world)
	camera=Camera2D.new(); camera.position=Vector2(180,320); add_child(camera)
	camera.position_smoothing_enabled=false
	var layer=CanvasLayer.new(); add_child(layer)
	ui=Control.new(); ui.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(ui)
	for species_id in FishGeometry.DATA:
		var path=FishGeometry.DATA[species_id].texture
		if ResourceLoader.exists(path): fish_textures[species_id]=load(path)
	_build_ui()
	for name in ["cast","slam","bite","snap","counter","breach","basket","chime","fever","miss"]:
		var path="res://assets/audio/arcade/"+name+".wav"
		if ResourceLoader.exists(path): sound_bank[name]=load(path)
	for i in range(8):
		var voice=AudioStreamPlayer.new(); add_child(voice); voices.append(voice)
	Engine.max_fps=60
	get_tree().auto_accept_quit=false
	if force_frontdoor or (not test_mode and not has_started): _build_frontdoor()
	if (not test_mode or qa) and not ("--no-music" in OS.get_cmdline_user_args()):
		music_controller=Music.new(); add_child(music_controller)
		music_controller.set_enabled(music_enabled); music_controller.set_volume(music_volume)
		_update_music_duck(); music_controller.setup()
	_consume_events(); _update_ui()
	if OS.get_name()=="iOS" or force_mobile_safe_area:
		mobile_safe_area=SafeArea.new(); add_child(mobile_safe_area)
		mobile_safe_area.layout_changed.connect(_on_mobile_layout_changed)
		get_tree().node_added.connect(_on_mobile_ui_node_added)
		_queue_mobile_targets()
	print("SHALLOW_READY platform=",OS.get_name()," haptics=",haptics.backend," procedural_assets=true")

func _on_mobile_layout_changed(_previous: Dictionary,_current: Dictionary) -> void:
	_queue_mobile_targets()
	# Folding or a system inset change must not consume a timed catch.
	# Keep the same rules/ledger/scene and let the player resume explicitly.
	if has_started and not paused and not catalog_open and not debug_open and not _frontdoor_blocks() and rules.state!="game_over":
		_toggle_pause()

func _on_mobile_ui_node_added(node: Node) -> void:
	if (node is Button or node is HSlider) and is_instance_valid(ui) and ui.is_ancestor_of(node):
		_queue_mobile_targets()

func _queue_mobile_targets() -> void:
	if mobile_target_refresh_queued: return
	mobile_target_refresh_queued=true
	_refresh_mobile_targets.call_deferred()

func _refresh_mobile_targets() -> void:
	mobile_target_refresh_queued=false
	if not is_instance_valid(mobile_safe_area) or mobile_safe_area.get_layout().is_empty(): return
	var requested: float=mobile_safe_area.minimum_logical_target_size(44)
	# Four-unit gaps in the densest menu support up to 48 units without overlap.
	# Native Duo currently needs 47. Smaller untested screens remain diagnostic,
	# rather than silently enlarging controls into their neighbours.
	var minimum: float=clampf(requested,44,48)
	_grow_mobile_targets(ui,minimum)

func _grow_mobile_targets(node: Node,minimum: float) -> void:
	if node is Button or node is HSlider:
		if not node.has_meta("mobile_base_rect"):
			node.set_meta("mobile_base_rect",Rect2(node.position,node.size))
		var base: Rect2=node.get_meta("mobile_base_rect")
		var expanded=Vector2(maxf(base.size.x,minimum),maxf(base.size.y,minimum))
		node.position=base.position-(expanded-base.size)*.5
		node.size=expanded
	for child in node.get_children(): _grow_mobile_targets(child,minimum)

func _build_ui() -> void:
	title_label=_label("ONE LAST CAST",Vector2(20,17),Vector2(220,28),19,INK)
	score_label=_label("",Vector2(22,48),Vector2(200,25),13,Color("567c78"))
	combo_label=_label("",Vector2(242,68),Vector2(100,42),30,INK)
	combo_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	ecology_label=_label("",Vector2(20,83),Vector2(215,26),12,Color("487a75"))
	catalog_button=_button(_t("鱼册","Fish Log"),Rect2(248,18,44,44),11)
	catalog_button.accessibility_name=_t("鱼类图鉴和累计统计","Fish Log and lifetime catch counts")
	catalog_button.pressed.connect(_toggle_catalog)
	pause_button=_button("Ⅱ",Rect2(298,18,44,44),20)
	pause_button.accessibility_name=_t("暂停与设置","Pause and settings")
	pause_button.pressed.connect(_toggle_pause)
	instruction_label=_label("",Vector2(20,558),Vector2(320,29),21,CREAM)
	instruction_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.accessibility_live=1
	sub_label=_label("",Vector2(18,591),Vector2(324,25),11,Color("b4d5cc"))
	sub_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	debug_button=_button(_t("调参","Tune"),Rect2(16,118,50,44),11)
	debug_button.accessibility_name=_t("打开手感参数","Open gameplay tuning")
	debug_button.pressed.connect(_toggle_debug)
	detail_label=_label("",Vector2(15,166),Vector2(330,60),10,INK)
	detail_label.visible=false
	pause_panel=Panel.new(); pause_panel.position=Vector2(30,163); pause_panel.size=Vector2(300,314)
	pause_panel.add_theme_stylebox_override("panel",_style(CREAM,18,Color("bfd7bb")))
	ui.add_child(pause_panel); pause_panel.visible=false
	_panel_label(pause_panel,_t("竿没收，先歇会儿","Fish can wait."),Vector2(20,18),Vector2(260,35),21)
	var sound=_button(_t("音效：关","Sound effects: Off") if muted else _t("音效：开","Sound effects: On"),Rect2(20,70,260,44),15,pause_panel)
	sound.pressed.connect(func(): muted=not muted; sound.text=_t("音效：关","Sound effects: Off") if muted else _t("音效：开","Sound effects: On"); _save_settings())
	var vibration=_button(_t("触感：开（手机）","Haptics: On (if supported)") if haptics.enabled else _t("触感：关","Haptics: Off"),Rect2(20,119,260,44),15,pause_panel)
	vibration.pressed.connect(func(): haptics.enabled=not haptics.enabled; vibration.text=_t("触感：开（手机）","Haptics: On (if supported)") if haptics.enabled else _t("触感：关","Haptics: Off"); _save_settings())
	var motion=_button(_t("减少动态：开","Reduced motion: On") if reduced_motion else _t("减少动态：关","Reduced motion: Off"),Rect2(20,168,260,44),15,pause_panel)
	motion.pressed.connect(func(): reduced_motion=not reduced_motion; motion.text=_t("减少动态：开","Reduced motion: On") if reduced_motion else _t("减少动态：关","Reduced motion: Off"); _save_settings())
	var resume=_button(_t("继续","Keep Fishing"),Rect2(20,238,260,48),18,pause_panel,true)
	resume.pressed.connect(_toggle_pause)
	intro_panel=Panel.new(); intro_panel.position=Vector2(28,440); intro_panel.size=Vector2(304,177)
	intro_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	intro_panel.add_theme_stylebox_override("panel",_style(CREAM,18,Color("b9cbb2")))
	ui.add_child(intro_panel); intro_panel.visible=intro_active
	_panel_label(intro_panel,_t("两下就行，别急。","Two taps. No tall tales."),Vector2(16,12),Vector2(272,28),20)
	_panel_label(intro_panel,_t("① 看准鱼，点一下下扎\n② 圆环重合，再点一下提竿","1. Watch the fish. Tap to dive.\n2. Tap again when the rings meet."),Vector2(16,49),Vector2(272,52),14)
	_panel_label(intro_panel,_t("空砸、点早、点晚，这局都会结束","Miss, tap early or tap late: this day is done."),Vector2(16,107),Vector2(272,24),11)
	_panel_label(intro_panel,_t("轻点开始","Tap to Start"),Vector2(16,140),Vector2(272,28),18)
	for child in intro_panel.get_children():
		child.mouse_filter=Control.MOUSE_FILTER_IGNORE
		child.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	result_panel=Panel.new(); result_panel.position=Vector2(28,326); result_panel.size=Vector2(304,200)
	result_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	result_panel.add_theme_stylebox_override("panel",_style(CREAM,20,Color("d0ad65")))
	ui.add_child(result_panel); result_panel.visible=false
	result_title=_panel_label(result_panel,_t("这一局结束","That’s a wrap."),Vector2(18,15),Vector2(268,30),20)
	result_score=_panel_label(result_panel,"0",Vector2(18,48),Vector2(268,51),40)
	result_detail=_panel_label(result_panel,"",Vector2(18,106),Vector2(268,33),12)
	var retry_label=_panel_label(result_panel,_t("轻点继续，第二天再来","Tap to come back tomorrow"),Vector2(18,156),Vector2(268,28),17)
	for child in result_panel.get_children():
		child.mouse_filter=Control.MOUSE_FILTER_IGNORE
		child.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var tomorrow=_button(_t("第二天再来  ›","Come Back Tomorrow  ›"),Rect2(18,146,268,44),17,result_panel,true)
	tomorrow.pressed.connect(func(): _press(Vector2(180,600)); _release())
	_build_catalog()
	debug_panel=Panel.new(); debug_panel.position=Vector2(17,265); debug_panel.size=Vector2(326,272)
	debug_panel.add_theme_stylebox_override("panel",_style(Color("fff0d2"),15,Color("abc9b6")))
	ui.add_child(debug_panel); debug_panel.visible=false
	var names=["Dive Gravity",_t("小鱼窗口 ±ms","Small-fish window ±ms"),"Hitstop Frames","Rod Stiffness"]
	var keys=["dive_gravity","hook_window_ms","hitstop_frames","rod_stiffness"]
	var low=[1.0,80.0,0.0,8.0]; var high=[5.0,250.0,6.0,30.0]; var steps=[.1,10.0,1.0,.5]
	for i in range(4):
		var lab=_panel_label(debug_panel,"",Vector2(13,8+i*64),Vector2(300,20),11)
		var slide=HSlider.new(); slide.position=Vector2(14,28+i*64); slide.size=Vector2(296,44)
		slide.min_value=low[i]; slide.max_value=high[i]; slide.step=steps[i]; slide.value=rules.tune[keys[i]]
		slide.accessibility_name=names[i]; debug_panel.add_child(slide)
		var key: String=keys[i]; var label_name: String=names[i]
		slide.value_changed.connect(func(value): rules.tune[key]=value; lab.text=label_name+"   "+str(snappedf(value,.1)); rod.set_stiffness(rules.tune.rod_stiffness); _save_settings())
		lab.text=names[i]+"   "+str(rules.tune[key]); sliders[key]=slide; tune_labels[key]=lab

func _style(color: Color,radius: int,border: Color) -> StyleBoxFlat:
	var s=StyleBoxFlat.new(); s.bg_color=color; s.set_corner_radius_all(radius); s.border_color=border; s.set_border_width_all(1); return s

func _label(value: String,pos: Vector2,size_value: Vector2,pixels: int,color: Color) -> Label:
	var label=Label.new(); label.position=pos; label.size=size_value; label.text=value; label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",font); label.add_theme_font_size_override("font_size",pixels); label.add_theme_color_override("font_color",color); ui.add_child(label); _fit_label(label,pixels,maxi(10,pixels-3)); label.size=size_value; return label

func _panel_label(host: Control,value: String,pos: Vector2,size_value: Vector2,pixels: int) -> Label:
	var l=Label.new(); l.position=pos; l.size=size_value; l.text=value; l.add_theme_font_override("font",font); l.add_theme_font_size_override("font_size",pixels); l.add_theme_color_override("font_color",INK); host.add_child(l); _fit_label(l,pixels,maxi(10,pixels-3)); l.size=size_value; return l

func _button(value: String,rect: Rect2,pixels: int,host: Control=null,accent=false) -> Button:
	var b=Button.new(); b.position=rect.position; b.size=rect.size; b.text=value
	b.add_theme_font_override("font",font); b.add_theme_font_size_override("font_size",pixels)
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]: b.add_theme_color_override(key,INK)
	var color=GOLD if accent else CREAM
	b.add_theme_stylebox_override("normal",_style(color,12,Color("bfd7bb"))); b.add_theme_stylebox_override("hover",_style(color.lightened(.08),12,Color("8fb7a7"))); b.add_theme_stylebox_override("pressed",_style(color.darkened(.12),12,INK))
	_fit_button(b,pixels,maxi(10,pixels-3),rect.size.x-14)
	b.size=rect.size; (host if host else ui).add_child(b); return b

func _unhandled_input(event: InputEvent) -> void:
	# Scripted QA owns its input; physical keys must not alter a background recording.
	if qa or _frontdoor_blocks(): return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			if SafeArea.LOGICAL_RECT.has_point(event.position): _press(event.position)
		else: _release()

	elif event is InputEventKey and not event.echo:
		if event.keycode==KEY_SPACE:
			if event.pressed: _press(Vector2(180,600))
			else: _release()
		elif event.pressed:
			if event.keycode==KEY_ESCAPE: _toggle_pause()
			elif event.keycode==KEY_F1: _toggle_debug()
			elif event.keycode==KEY_N and rules.state=="game_over": _press(Vector2(180,600)); _release()
			elif event.keycode==KEY_F12: _capture_frame.call_deferred("shallow-manual.png")

func _press(at: Vector2) -> void:
	if _frontdoor_blocks(): return
	if intro_active:
		intro_active=false; intro_panel.visible=false; _sound("cast"); _update_ui(); return
	if paused or debug_open or catalog_open: return
	var start=Time.get_ticks_usec()
	pointer_held=true; pointer_start=at; pointer_clock=visual_time; flick_sent=false; button_pulse=1
	if rearm_hold: rearm_hold=false
	rules.press(); _consume_events(); _update_ui()
	if qa: input_samples.append((Time.get_ticks_usec()-start)/1000.0)

func _release() -> void:
	if _frontdoor_blocks(): return
	if paused or debug_open or catalog_open: return
	pointer_held=false
	rules.release(); _consume_events(); _update_ui()

func _toggle_pause() -> void:
	if intro_active: return
	if is_instance_valid(frontdoor):
		if _frontdoor_blocks():
			if frontdoor.page=="pause": _resume_from_frontdoor()
			return
		if catalog_open: _toggle_catalog()
		if debug_open: _toggle_debug()
		paused=true; pointer_held=false; rules.held=false
		frontdoor.show_pause(); _update_ui(); return
	if catalog_open: _toggle_catalog()
	if debug_open: _toggle_debug()
	paused=not paused; pause_panel.visible=paused
	if paused:
		for voice in voices: voice.stop()
	else:
		pointer_held=false; rules.held=false
		if rules.state=="casting": rules.slam_armed=true
	_update_ui()

func _toggle_debug() -> void:
	if intro_active or _frontdoor_blocks(): return
	if not debug_open:
		if catalog_open: catalog_open=false; catalog_panel.visible=false
		if paused: paused=false; pause_panel.visible=false
	debug_open=not debug_open; debug_panel.visible=debug_open; detail_label.visible=debug_open
	debug_button.text=_t("收起","Close") if debug_open else _t("调参","Tune")
	if not debug_open:
		pointer_held=false; rules.held=false
	_update_ui()

func _notification(what: int) -> void:
	if not is_instance_valid(pause_panel): return
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and not qa:
		app_has_focus=false
		if not catalog_open and not intro_active and not _frontdoor_blocks() and rules.state!="idle":
			if is_instance_valid(frontdoor): frontdoor.show_pause()
			else: pause_panel.visible=true
			paused=true; pointer_held=false; rules.held=false; _save_settings(); _update_ui()
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN: app_has_focus=true
	elif what==NOTIFICATION_WM_CLOSE_REQUEST: _save_settings(); _quit_cleanly.call_deferred()

func _physics_process(dt: float) -> void:
	if paused or debug_open or catalog_open or rearm_hold or intro_active or _frontdoor_blocks(): return
	if qa and not qa_done: _demo_input()
	var frozen=rules.hitstop_left>0
	rules.tick(dt)
	_consume_events()
	if not frozen:
		water.tick(dt); rod.tick(dt)
		match rules.state:
			"hookset": rod.set_load(1.0)
			"tug_of_war": rod.set_load(.55+(.3 if rules.duel_flash else 0))
			"launch": rod.set_load(-.55)
			"bite_window": rod.set_load(.12 if not rules.bite_active else .3)
			_: rod.set_load(0)
	_update_ui()

func _process(dt: float) -> void:
	_update_music_duck()
	frozen_clock+=dt
	if not paused and not debug_open and not catalog_open and not rearm_hold and not intro_active and not _frontdoor_blocks():
		visual_time+=minf(dt,.1)
		if rules.state=="game_over":
			home_clock+=dt; night_amount=clampf((home_clock-night_start_delay)/night_duration,0,1)
		else: night_amount=0
		if (night_amount>0 and night_amount<1) or result_panel.visible!=(rules.state=="game_over" and home_clock>=score_delay): _update_ui()
		if qa and not qa_done: frame_samples.append(dt); qa_elapsed+=dt
		button_pulse=move_toward(button_pulse,0,dt*7); basket_pulse=move_toward(basket_pulse,0,dt*5); combo_pulse=move_toward(combo_pulse,0,dt*4)
		perfect_flash=move_toward(perfect_flash,0,dt*5); cue_left=maxf(0,cue_left-dt); shake_left=maxf(0,shake_left-dt)
		fever_amount=move_toward(fever_amount,1.0 if rules.fever else 0.0,dt*2)
		if rules.hitstop_left<=0:
			for p in particles:
				p.life-=dt; p.pos+=p.velocity*dt; p.velocity.y+=p.gravity*dt
			particles=particles.filter(func(p): return p.life>0)
			for toast in toasts: toast.life-=dt; toast.pos+=toast.velocity*dt; toast.velocity.y+=65*dt
			toasts=toasts.filter(func(t): return t.life>0)
		for h in delayed_haptics:
			h.delay-=dt
			if h.delay<=0 and not h.done: haptics.pulse(h.intensity,h.sharpness,h.duration); h.done=true
		delayed_haptics=delayed_haptics.filter(func(h): return not h.done)
		for spark in spark_trails: spark.life-=dt
		spark_trails=spark_trails.filter(func(spark): return spark.life>0)
		if rules.fever and rules.state in ["casting","diving"] and Engine.get_process_frames()%3==0:
			spark_trails.append({"pos":rules.lure_pos,"life":.22})
		if rules.fever and Engine.get_process_frames()%16==0: water.splash(rng.randf_range(115,350),rng.randf_range(-28,28),10)
	var target_zoom=1.08 if rules.state=="bite_window" and rules.bite_active else (.96 if rules.state in ["hookset","launch"] else 1.0)
	if reduced_motion: target_zoom=1
	camera_zoom=lerpf(camera_zoom,target_zoom,minf(1,dt*12)); camera.zoom=Vector2.ONE*camera_zoom
	var target_center=Vector2(180,320)
	if target_zoom>1.0 or (rules.state=="game_over" and home_clock<night_start_delay):
		target_center=Vector2(180+(rules.lure_pos.x-180)*.17,clampf(rules.fish_pos.y-70,320,405))
	var shake=Vector2(sin(frozen_clock*131),cos(frozen_clock*113))*6*(shake_left/.12) if shake_left>0 and not reduced_motion else Vector2.ZERO
	camera.position=camera.position.lerp(target_center+shake,minf(1,dt*30))
	if qa and not qa_done:
		if rules.row_positions.size()==7 and rules.state=="casting" and not qa_captures.has("deep_field"):
			qa_captures.deep_field=true; _capture_frame.call_deferred("journey-seven-rows.png")
		if rules.row_positions.size()==7 and rules.state=="bite_window" and rules.fish_pos.y>450 and not qa_captures.has("deep_ring"):
			qa_captures.deep_ring=true; _capture_frame.call_deferred("journey-deep-ring.png")
		if rules.state=="casting" and not qa_captures.has("field"):
			qa_captures.field=true; _capture_frame.call_deferred("shallow-field.png")
		if rules.state=="bite_window" and rules.ring_progress>.6 and not qa_captures.has("ring"):
			qa_captures.ring=true; _capture_frame.call_deferred("shallow-ring.png")
		if rules.fever and rules.state=="bite_window" and not qa_captures.has("fever"):
			qa_captures.fever=true; _capture_frame.call_deferred("shallow-fever-ring.png")
	if qa and not qa_done and "--qa-difficulty" in OS.get_cmdline_user_args():
		for milestone in [12,25,45,60]:
			var key="density_%d"%milestone
			if rules.catches>=milestone and rules.state=="casting" and rules.state_time>.2 and not qa_captures.has(key):
				qa_captures[key]=true; _capture_frame.call_deferred("difficulty-%d-fish.png"%milestone)
		if rules.fish_tier==3 and rules.ring_duration<=.42 and rules.state=="bite_window" and rules.ring_progress>.45 and not qa_captures.has("fast_trophy"):
			qa_captures.fast_trophy=true; _capture_frame.call_deferred("difficulty-fast-trophy.png")
	world.queue_redraw()

func _consume_events() -> void:
	var events=rules.events.duplicate(true); rules.events.clear()
	for e in events:
		if "--input-trace" in OS.get_cmdline_user_args() and e.type in ["press","release","fish_contact","ring_judgement","hookset","basket","fail","restarted","cast"]: print("INPUT_TRACE ",JSON.stringify(e))
		if qa and e.type not in ["press","release","transition"]: qa_events.append({"type":e.type,"t":e.time,"state":e.state,"combo":e.combo})
		match e.type:
			"ready", "restarted":
				if e.type=="ready": ledger_run+=1
				particles.clear(); toasts.clear(); spark_trails.clear(); basket_fish.clear(); cue_left=0; fever_amount=0; night_amount=0; home_clock=0; fail_visual=""; night_start_delay=0; camera_zoom=1; shake_left=0
			"cast":
				qa_cast_plan=-1
				_sound("cast",1.08 if e.boost>1 else 1.0); rod.kick(-14); _cue(_t("接得漂亮！","Nice follow-through!") if e.boost>1 else "",.45)
			"slam": _sound("cast",.72,-6); _haptic(.3,.4,15); button_pulse=1
			"splash":
				var perfect=e.grade=="perfect"
				water.splash(e.pos.x,150 if perfect else 105,16); _splash(e.pos,28 if perfect else 17,perfect)
				_sound("slam",1.1 if perfect else .92); _haptic(.4,.3,24)
				if perfect: perfect_flash=1; combo_pulse=1; _cue(_t("正中！","Right on target!"),.45)
				elif e.grade=="miss": _cue(_t("偏了，稳住这一口","A little wide. Stay ready."),.75)
			"fish_contact", "item_contact":
				_bubbles(e.pos,12); _haptic(.55,.45,20); combo_pulse=1; _sound("counter",1.3,-8)
			"bite":
				_sound("bite"); _haptic(.85,.2,28); delayed_haptics.append({"delay":.075,"intensity":.8,"sharpness":.2,"duration":25,"done":false})
				_bubbles(rules.lure_pos,14); rod.kick(7); _cue("",0)
			"ring_aligned": _sound("counter",1.65,-12); _haptic(.3,.65,12)
			"hookset":
				_sound("snap",1.0); _haptic(1,.9,34); rod.kick(18); combo_pulse=1
				if e.grade=="perfect": _cue(_t("漂亮提竿！","Clean catch!"),.5); perfect_flash=1
				else: _cue(_t("钩住了！","Got one!"),.35)
			"duel_flash": _sound("counter",.75,-4); _haptic(.55,.4,24); rod.kick(7)
			"counter": _sound("counter",1.15); _haptic(.85,.7,25); _bubbles(rules.fish_pos,10); _cue(_t("压住了！","Not today, fish!"),.25); rod.kick(-13)
			"breach":
				var big=rules.fish_tier>=2
				water.splash(e.pos.x,-210 if big else -155,26 if big else 18); _splash(e.pos,46 if big else 30,rules.fever)
				_sound("breach",.78 if big else 1.1); _haptic(1,.9,40); shake_left=.12; rod.kick(-18)
			"basket":
				ledger.record_catch(e.get("species_id",Catalog.species_for_kind(int(e.fish_kind))),"%s/%d/%d"%[ledger_session,ledger_run,int(e.catches)])
				basket_fish.append({"kind":int(e.fish_kind),"species_id":e.get("species_id",Catalog.species_for_kind(int(e.fish_kind)))})
				if basket_fish.size()>7: basket_fish.pop_front()
				basket_pulse=1; _sound("basket"); _sound("chime",pow(2,mini(12,rules.combo)/12.0),-4)
				if rules.fever: _sound("fever",1,-8); _point_shower(Vector2(37,230),25)
				_haptic(.5,.55,22); _basket_toast(e); best_combo=maxi(best_combo,rules.combo); best_score=maxi(best_score,rules.score)
				qa_times.append(e.cycle_seconds); qa_peak_catches=maxi(qa_peak_catches,rules.catches); qa_peak_combo=maxi(qa_peak_combo,rules.combo); qa_peak_score=maxi(qa_peak_score,rules.score); _save_settings()
				if qa and rules.catches>=qa_target and not qa_done:
					if "--qa-endgame" in OS.get_cmdline_user_args(): qa_phase="miss" if qa_failure_mode=="" else "failure_setup"
					else: qa_done=true; _finish_demo.call_deferred()
			"junk_basket":
				qa_salvages+=1
				if qa and "--qa-salvage" in OS.get_cmdline_user_args(): qa_phase="miss"; _capture_frame.call_deferred("journey-salvage.png")
				basket_pulse=1; _sound("basket",.8); _haptic(.25,.3,18)
				var line=_t("钓点蜗牛，也不算亏。","Well... it’s a snail.") if e.category=="snail" else _t("怎么是水草？再来一竿。","Salad. Not what I ordered.")
				_cue(line,1.5)
				toasts.append({"pos":Vector2(128,210),"velocity":Vector2(4,-22),"life":1.4,"text":_t("蜗牛救场 · 不计鱼获","Snail rescue · Not a fish") if e.category=="snail" else _t("水草救场 · 不计鱼获","Weed rescue · Not a fish"),"points":_t("继续钓！","Still fishing!")})
			"fail":
				home_clock=0; cue_left=0; toasts.clear(); spark_trails.clear()
				fail_visual=e.reason; escaped_pos=rules.fish_pos; escaped_kind=rules.fish_kind; escaped_category=rules.catch_category; escaped_species_id=rules.fish_species_id
				night_start_delay=.2 if e.reason in ["hook_early","hook_late"] else 0
				if e.reason=="hook_early": _bubbles(escaped_pos,10); _sound("breach",1.6,-9)
				elif e.reason=="hook_late": _sound("snap",.62,-2); _point_shower(escaped_pos+Vector2(0,-40),8)
				rounds_finished+=1
				goodbye_line=[_t("说好最后一竿的…","One last cast. Allegedly."),_t("鱼没上来，月亮上班了。","Fish clocked out. Moon’s in."),_t("拎包，今天先放鱼一马。","We let the fish win today."),_t("最后一竿，明天再说。","One last cast. Tomorrow.")][(rounds_finished/2)%4]
				best_combo=maxi(best_combo,rules.best_run_combo); best_score=maxi(best_score,rules.score); _save_settings()
				if e.reason not in ["hook_early","hook_late"]: _sound("miss")
				rod.kick(-4)
			"dry_click": _sound("counter",1.5,-14)

func _update_ui() -> void:
	goodbye_line=_goodbye_line()
	var fingerprint=hash([language,rules.state,rules.held,rules.bite_active,rules.duel_flash,rules.combo,rules.score,rules.fever,paused,debug_open,rearm_hold,cue_text,cue_left>0,rules.final_reason,intro_active,home_clock>=score_delay,catalog_open,night_amount>.5,int(rules.boat_distance),rules.row_positions.size()])
	if fingerprint==last_fingerprint and not debug_open: return
	last_fingerprint=fingerprint
	score_label.text=_t("%06d  ·  最佳连击 %d","%06d  ·  Best combo %d")%[rules.score,best_combo]
	for label in [title_label,combo_label]: label.add_theme_color_override("font_color",CREAM if night_amount>.5 else INK)
	for label in [score_label,ecology_label]: label.add_theme_color_override("font_color",Color("adc5c6") if night_amount>.5 else Color("487a75"))
	combo_label.text="FEVER\nx%d"%rules.combo if rules.fever else ("x%d"%rules.combo if rules.combo>0 else "")
	combo_label.add_theme_font_size_override("font_size",22 if rules.fever else 30)
	ecology_label.text=_t("离岸 %dm · %d 排鱼 · %.1fm 深","%dm out · %d rows · %.1fm deep")%[int(rules.boat_distance),rules.row_positions.size(),rules.depth_meters]
	var headline=""; var detail=""
	match rules.state:
		"idle": headline=_t("看准下方的鱼","Eyes on the fish."); detail=_t("点一下下扎  ·  圆环重合再点  ·  自动续投","Tap to dive · Tap when rings meet · Auto-cast")
		"casting":
			headline=_t("看准鱼，点一下下扎","Watch the fish. Tap to dive.")
			detail=_t("第一条碰到的鱼，就是你的目标","The hook catches the first fish it hits.")
		"diving": headline=_t("下扎！","Dive!"); detail=_t("碰到第一条鱼，就准备第二下","Touch a fish. Get ready for tap two.")
		"bite_window":
			headline=_t("圆环重合时，再点一下","Tap when the rings meet.") if rules.bite_active else _t("看圆环，准备第二下","Watch the ring. Get ready.")
			detail=(_t("稀有大鱼 · 快圈，盯住重合那一下！","Trophy fish · Fast ring. Watch the overlap!") if rules.fish_tier==3 and rules.ring_duration<.54 else _t("小鱼别抢拍，大鱼别走神。","Small fish: take your time. Big fish: stay sharp.")) if rules.catch_category=="fish" else _t("这也能钩？看准圆环再收。","Not a fish. Same rule: tap when the rings meet.")
		"hookset": headline=_t("钩住！","Hooked!"); detail=_t("这一口，有分量","That one has some weight.")
		"tug_of_war": headline=_t("点一下！","Tap!") if rules.duel_flash else _t("稳住…","Steady..."); detail=_t("红圈亮起，反击 %d / %d","Red ring: counter %d / %d")%[rules.duel_done,rules.duel_total]
		"launch": headline=_t("进篮！","In the basket!"); detail=_t("下一竿自动抛出，看准下一条","Next cast is automatic. Pick your next fish.")
		"recast_window": headline=_t("下一竿，接上！","Here comes the next cast."); detail=_t("自动抛竿，点一下下扎","Auto-cast. Tap once to dive.")
		"game_over": headline=goodbye_line; detail=_t("第二天再来，马上开钓","Tomorrow starts with one tap.")
	if cue_left>0 and cue_text!="" and rules.state not in ["bite_window","tug_of_war","game_over"]: headline=cue_text
	if paused: headline=_t("暂停","Paused"); detail=_t("继续时，接回你的节奏","Your fish will wait. Probably.")
	if catalog_open: headline=_t("鱼获都记在这里","A log of fish, not excuses."); detail=_t("关闭后，回到封面","Close to return to the title screen.") if catalog_return_page=="title" else _t("关闭后，接回刚才那一竿","Close to pick up right where you left off.")
	if debug_open: headline=_t("调参中，节奏暂停","Tuning break"); detail=_t("收起面板，马上继续","Close this panel to keep fishing.")
	if rearm_hold: headline=_t("按住，继续这一竿","Ready to keep fishing?"); detail=_t("接回手指后，时间才会继续","Tap to pick up where you left off.")
	result_panel.visible=rules.state=="game_over" and home_clock>=score_delay and not paused and not debug_open and not catalog_open
	if rules.state=="game_over":
		result_title.text={"empty_dive":_t("空竿，鱼没来上班。","Empty hook. Full excuses."),"released_before_bite":_t("松早了，鱼跑了","Too soon. Fish got away."),"late_hook":_t("晚了一拍，鱼跑了","Too late. Fish clocked out."),"hook_early":_t("点早了，鱼先溜了。","Too early. Fish said nope."),"hook_late":_t("点晚了，线先下班。","Too late. The line quit."),"ring_early":_t("点早了，空竿！","Too early. Empty hook."),"ring_late":_t("点晚了，空竿！","Too late. Empty hook."),"missed_counter":_t("大鱼挣脱了","The big one got away."),"not_holding":_t("没有接住这一口","Missed that bite.")}.get(rules.final_reason,_t("这一局结束","That’s a wrap."))
		result_score.text=str(rules.score)
		result_detail.text=_t("钓到 %d 条   ·   最佳连击 x%d\n最高分 %d","%d fish   ·   Best combo x%d\nBest score %d")%[rules.catches,rules.best_run_combo,best_score]
	instruction_label.text=headline; sub_label.text=detail
	_fit_label(instruction_label,21,17); _fit_label(sub_label,11,10)
	_fit_label(ecology_label,12,10); _fit_label(score_label,13,11)
	_fit_label(result_title,20,17)
	instruction_label.visible=not intro_active; sub_label.visible=not intro_active
	debug_button.visible=not intro_active
	pause_button.disabled=intro_active; catalog_button.disabled=intro_active
	if debug_open: detail_label.text="%s  %.2fs  ·  combo %d\nhook %.0fms  hitstop %.0fms  ·  %s"%[rules.state,rules.state_time,rules.combo,rules.bite_elapsed*1000,rules.hitstop_left*1000,haptics.backend]

func _cue(text_value: String,seconds: float) -> void:
	cue_text=text_value; cue_left=seconds

func _sound(name: String,pitch=1.0,offset_db=0.0) -> void:
	if muted or sfx_volume<=0 or intro_active or _frontdoor_blocks() or (test_mode and not qa) or not sound_bank.has(name): return
	for voice in voices:
		if not voice.playing:
			voice.stream=sound_bank[name]; voice.pitch_scale=pitch; voice.volume_db=-6+offset_db+linear_to_db(maxf(.001,sfx_volume)); voice.play(); return

func _haptic(intensity: float,sharpness: float,duration: int) -> void:
	haptics.pulse(intensity,sharpness,duration)

func _splash(pos: Vector2,count: int,golden: bool) -> void:
	var color=GOLD if golden else Color("d6f5df")
	for i in range(count if not reduced_motion else mini(count,9)):
		var velocity=Vector2(rng.randf_range(-140,140),rng.randf_range(-310,-80))
		particles.append({"pos":pos,"velocity":velocity,"life":rng.randf_range(.3,.62),"gravity":720.0,"radius":rng.randf_range(1.3,3.0),"color":color,"kind":"drop"})
	while particles.size()>160: particles.pop_front()

func _bubbles(pos: Vector2,count: int) -> void:
	for i in range(count if not reduced_motion else 4):
		particles.append({"pos":pos+Vector2(rng.randf_range(-6,6),rng.randf_range(-4,4)),"velocity":Vector2(rng.randf_range(-45,45),rng.randf_range(-75,-20)),"life":rng.randf_range(.18,.4),"gravity":-30.0,"radius":rng.randf_range(1.2,3.2),"color":Color("dff6d8"),"kind":"bubble"})

func _point_shower(pos: Vector2,count: int) -> void:
	for i in range(count if not reduced_motion else 6):
		particles.append({"pos":pos,"velocity":Vector2(rng.randf_range(-50,140),rng.randf_range(-180,-70)),"life":rng.randf_range(.5,.9),"gravity":260.0,"radius":rng.randf_range(1.5,3.2),"color":GOLD,"kind":"star"})

func _basket_toast(e: Dictionary) -> void:
	var entry=Catalog.get_species(e.get("species_id",Catalog.species_for_kind(int(e.fish_kind))))
	var name=_species_name(entry)
	toasts.append({"pos":Vector2(128,210),"velocity":Vector2(4,-25),"life":1.1,"text":"%s · %.1f lb  x%d"%[name,e.weight,rules.combo],"points":"+%d"%e.points})
	while toasts.size()>2: toasts.pop_front()

func _draw_world() -> void:
	_draw_background()
	_draw_underwater()
	if rules.combo>=3 and night_amount<.1:
		for i in range(mini(8,rules.combo/2)):
			var p=Vector2(128+i*27+sin(visual_time*1.7+i)*6,263+sin(visual_time*2+i*3)*11)
			world.draw_circle(p,1.2,Color(1,.91,.5,.35))
	_draw_boat()
	_draw_target()
	_draw_rod_and_line()
	_draw_lure()
	if rules.state in ["bite_window","hookset","tug_of_war","launch"]:
		var jiggle=Vector2.ZERO
		if rules.hitstop_left>0: jiggle=Vector2(sin(frozen_clock*176),cos(frozen_clock*151))*4
		var angle=0.0
		if rules.state=="launch": angle=rules.fish_velocity.angle()+PI
		_draw_catch(rules.catch_category,rules.fish_kind,rules.fish_pos+jiggle,rules.fish_scale,angle,1,rules.fish_species_id)
	if rules.state=="game_over" and home_clock<.5 and fail_visual in ["hook_early","hook_late"]:
		var t=home_clock
		var escaped=escaped_pos+Vector2(t*360,sin(t*13)*9)
		_draw_catch(escaped_category,escaped_kind,escaped,Vector2(1.1,.8),0,clampf(1-t*2,0,1),escaped_species_id)
	_draw_water_surface()
	_draw_particles()
	_draw_toasts()
	_draw_touch_indicator()
	if paused or debug_open: world.draw_rect(Rect2(-80,-80,520,800),Color(0.05,.18,.22,.18))

func _draw_background() -> void:
	var sky=Color("f5e9c5").lerp(Color("f6c978"),fever_amount).lerp(Color("142c49"),night_amount)
	world.draw_rect(Rect2(-80,-100,520,388),sky)
	world.draw_circle(Vector2(277,155),27,Color("f3ce88").lerp(Color("ef9852"),fever_amount).lerp(Color("f0e5b6"),night_amount))
	if night_amount>0:
		world.draw_circle(Vector2(287,149),23,Color(sky,night_amount))
		for i in range(15):
			var p=Vector2(17+(i*71)%340,105+(i*37)%112)
			world.draw_line(p-Vector2(2,0),p+Vector2(2,0),Color(.95,.95,.79,night_amount*.7),1,true)
			world.draw_line(p-Vector2(0,2),p+Vector2(0,2),Color(.95,.95,.79,night_amount*.7),1,true)
	for i in range(4):
		var x=fposmod(i*113+visual_time*(1.5+i*.2),460)-50
		var y=125+i%2*39
		for j in range(4): world.draw_circle(Vector2(x+j*13,y+sin(j*2)*3),9+j%2*4,Color(1,.97,.83,.58*(1-night_amount*.9)))
	for layer in range(3):
		var points=PackedVector2Array([Vector2(-80,288)])
		for i in range(54): points.append(Vector2(-80+i*10,225+layer*18+sin(i*.3+layer*2+rules.boat_distance*.006*(layer+1))*12))
		points.append(Vector2(450,288)); world.draw_colored_polygon(points,[Color("c8d4b2"),Color("a8c4a8"),Color("7fae9e")][layer].lerp(Color("203e51"),night_amount))
	# Bank markers slide behind the anchored boat: continuous forward travel.
	for i in range(5):
		var x=fposmod(i*113-rules.boat_distance*2.6,530)-85
		var bank=Color("5c927c").lerp(Color("173648"),night_amount)
		world.draw_line(Vector2(x,270),Vector2(x,244),bank,2,true)
		world.draw_colored_polygon(PackedVector2Array([Vector2(x-9,257),Vector2(x,238),Vector2(x+9,257)]),bank)
	for y in range(288,720,4):
		var depth=clampf((y-288)/352.0,0,1)
		var color=Color("73c9b9").lerp(Color("193b59"),depth)
		world.draw_rect(Rect2(-80,y,520,4),color)
	world.draw_colored_polygon(PackedVector2Array([Vector2(125,289),Vector2(170,289),Vector2(242,587),Vector2(192,587)]),Color(.85,.96,.72,.06))
	world.draw_colored_polygon(PackedVector2Array([Vector2(37,289),Vector2(64,289),Vector2(153,548),Vector2(118,548)]),Color(.85,.96,.72,.07))
	for y in range(536,690,3): world.draw_rect(Rect2(-80,y,520,3),Color(.06,.18,.26,clampf((y-536)/52.0,0,.94)))

func _draw_underwater() -> void:
	# A shallow, clearly readable playfield. Every visible fish here is a collidable entity.
	var bottom=rules.floor_y
	for y in range(288,int(bottom)+12,3):
		var t=(y-288.0)/(bottom-288.0)
		world.draw_rect(Rect2(-80,y,520,3),Color("78cbb8").lerp(Color("529c9c").lerp(Color("356279"),clampf((rules.depth_meters-2)/20,0,.7)),t).lerp(Color("183b51"),night_amount*.86))
	world.draw_rect(Rect2(-80,bottom,520,640-bottom),Color("d8c58c"))
	world.draw_rect(Rect2(-80,bottom+9,520,640-bottom),Color("173f4a"))
	world.draw_line(Vector2(0,bottom),Vector2(360,bottom),Color("ede0ac"),2.5,true)
	for i in range(16):
		var x=float((i*79+13)%360); var y=305+fposmod(i*21.8-visual_time*(3+i%4),bottom-310)
		world.draw_arc(Vector2(x,y),1+(i%3)*.5,0,TAU,10,Color(.83,1,.87,.23),.6,true)
	for i in range(10):
		var x=12+i*38
		world.draw_set_transform(Vector2(x,bottom+3),0,Vector2(1,.3)); world.draw_circle(Vector2.ZERO,2+(i%3),Color("aaaf85")); world.draw_set_transform(Vector2.ZERO)
	for item in rules.bottom_items: _draw_bottom_item(item.category,item.pos,Vector2.ONE,0,1-night_amount*.6)
	for fish in rules.fish_school:
		var p: Vector2=fish.pos
		world.draw_set_transform(p+Vector2(0,16),0,Vector2(1,.2)); world.draw_circle(Vector2.ZERO,fish.radius.x,Color(.1,.3,.3,.12)); world.draw_set_transform(Vector2.ZERO)
		var facing=Vector2(-1,1) if fish.velocity.x<0 else Vector2.ONE
		_draw_fish(fish.kind,p,facing,0,1-night_amount*.65,true,fish.get("species_id",""))
		if fish.multiplier>1 and night_amount<.1 and (rules.row_positions.size()<5 or int(fish.get("tier",0))==3):
			var label_color=GOLD if fish.multiplier>=4 else Color("f5edc7")
			world.draw_string(font,p+Vector2(-8,-fish.radius.y-6),"×%d"%fish.multiplier,HORIZONTAL_ALIGNMENT_LEFT,-1,9,label_color)
		if fish.get("turn_warning",false): world.draw_arc(p,fish.radius.x+5,-PI*.7,-PI*.3,16,GOLD,2,true)
		if debug_open:
			world.draw_set_transform(p,0,fish.radius); world.draw_arc(Vector2.ZERO,1,0,TAU,32,Color(1,.3,.2,.7),.07,true); world.draw_set_transform(Vector2.ZERO)
	for side in [0,1]:
		for i in range(3):
			var x=7+i*6 if side==0 else 353-i*6
			var curve=PackedVector2Array()
			for j in range(10): curve.append(Vector2(x+sin(j*.45+i+visual_time*.7)*j*.6,bottom-j*(2+i*.5)))
			world.draw_polyline(curve,Color("397d6b"),2.2,true)

func _draw_boat() -> void:
	for i in range(3):
		var drift=fposmod(rules.boat_distance*6+i*23,85)
		world.draw_line(Vector2(72-drift,289+i*2),Vector2(82-drift,289+i*2),Color(.87,.98,.8,.28),1.3,true)
	var rock=sin(visual_time*2.1)*1.0+water.get_y(50)-288
	world.draw_set_transform(Vector2(0,rock*.12))
	world.draw_colored_polygon(PackedVector2Array([Vector2(-20,259),Vector2(109,259),Vector2(94,284),Vector2(4,285)]),Color("805943"))
	world.draw_line(Vector2(-10,258),Vector2(110,258),Color("d4a86c"),7,true)
	world.draw_line(Vector2(9,272),Vector2(98,271),Color("b37d50"),2,true)
	for x in [12,40,69,96]: world.draw_line(Vector2(x,261),Vector2(x-3,280),Color("694e40"),1,true)
	# Physical livewell basket behind the angler.
	var bounce=sin(basket_pulse*PI)*4
	world.draw_colored_polygon(PackedVector2Array([Vector2(17,236-bounce),Vector2(55,236-bounce),Vector2(50,258),Vector2(22,258)]),Color("ce9e5e"))
	for x in range(23,52,6): world.draw_line(Vector2(x,238-bounce),Vector2(x-1,255),Color("916f46"),1.2,true)
	for y in [244,250]: world.draw_line(Vector2(21,y),Vector2(52,y),Color("e4bf7b"),1.2,true)
	world.draw_set_transform(Vector2(36,236-bounce),0,Vector2(1,.3)); world.draw_circle(Vector2.ZERO,21,INK); world.draw_arc(Vector2.ZERO,21,0,TAU,32,Color("ebca86"),5,true); world.draw_set_transform(Vector2(0,rock*.12))
	if rules.state=="recast_window":
		world.draw_arc(Vector2(37,244),27,-PI*.5,-PI*.5+TAU*clampf(1-rules.state_time/.35,0,1),40,GOLD,2.2,true)
	# Visible catch collection stays above the boat, never in the aiming lanes.
	for i in range(mini(3,basket_fish.size())):
		var caught=basket_fish[basket_fish.size()-1-i]
		_draw_fish(caught.kind,Vector2(24+i*10,233-(i%2)*3),Vector2(.28,.28),-.2+i*.16,1,true,caught.species_id)
	if rules.catches>3:
		world.draw_string(font,Vector2(23,255),"×%d"%rules.catches,HORIZONTAL_ALIGNMENT_LEFT,-1,9,INK)
	world.draw_set_transform(Vector2(0,rock*.12))
	# On failure, instantly pick up the bag and walk off the left dock. Retry can interrupt.
	if rules.state=="game_over":
		var leave=clampf((home_clock-night_start_delay-.1)/home_duration,0,1)
		var walk_offset=Vector2(-125*leave,-absf(sin(home_clock*22))*3)
		world.draw_line(Vector2(-30,257),Vector2(90,257),Color("c5a271"),6,true)
		world.draw_set_transform(walk_offset)
		world.draw_line(Vector2(79,225),Vector2(92,237),Color("e8b98b"),4,true)
		world.draw_arc(Vector2(94,240),7,PI,TAU,14,CREAM,2,true)
		world.draw_style_box(_style(Color("bd814d"),3,Color("704e3c")),Rect2(84,240,23,17))
		world.draw_line(Vector2(94,241),Vector2(94,256),Color("dfb16c"),2,true)
	# Angler: clean ink outlines and warm hand-drawn components.
	world.draw_line(Vector2(73,243),Vector2(86,249),INK,8,true); world.draw_line(Vector2(85,249),Vector2(94,258),INK,6,true)
	world.draw_line(Vector2(93,258),Vector2(105,258),Color("684b3d"),5,true)
	world.draw_colored_polygon(PackedVector2Array([Vector2(62,213),Vector2(79,212),Vector2(83,242),Vector2(61,244)]),INK)
	world.draw_colored_polygon(PackedVector2Array([Vector2(64,214),Vector2(77,214),Vector2(80,240),Vector2(63,241)]),Color("df9255"))
	world.draw_line(Vector2(67,218),Vector2(68,238),Color("f3bd75"),2,true)
	world.draw_circle(Vector2(72,204),10,INK); world.draw_circle(Vector2(72,204),8.5,Color("e8b98b")); world.draw_circle(Vector2(78,204),1.3,INK)
	world.draw_colored_polygon(PackedVector2Array([Vector2(59,199),Vector2(66,188),Vector2(78,190),Vector2(86,200)]),Color("d1aa68"))
	world.draw_line(Vector2(55,200),Vector2(89,201),INK,5,true); world.draw_line(Vector2(55,199),Vector2(89,200),Color("f1d191"),3,true)
	world.draw_line(Vector2(65,195),Vector2(80,196),Color("866547"),2,true)
	world.draw_line(Vector2(76,220),Vector2(80,234),Color("b57649"),6,true); world.draw_line(Vector2(80,234),Vector2(84,237),Color("efbd89"),5,true)
	world.draw_set_transform(Vector2.ZERO)

func _draw_target() -> void:
	# The line explains the vertical slam. It never chooses or creates a target fish.
	if rules.state not in ["casting","diving"]: return
	var x=rules.lure_pos.x
	for y in range(300,int(rules.floor_y)-5,13):
		world.draw_line(Vector2(x,y),Vector2(x,y+5),Color(1,.94,.73,.22),1.2,true)
	world.draw_line(Vector2(x-5,rules.floor_y-5),Vector2(x,rules.floor_y),Color("f6df99"),1.5,true)
	world.draw_line(Vector2(x+5,rules.floor_y-5),Vector2(x,rules.floor_y),Color("f6df99"),1.5,true)

func _draw_rod_and_line() -> void:
	if rules.state=="game_over":
		if fail_visual=="hook_late" and home_clock<.38:
			var tip=rod.tip
			var split=tip.lerp(escaped_pos,.6)
			var retreat=clampf(home_clock/.2,0,1)
			world.draw_line(tip,split.lerp(tip,retreat*.8),CREAM,1.6,true)
			world.draw_line(split+Vector2(home_clock*15,home_clock*65),escaped_pos+Vector2(home_clock*80,home_clock*80),Color("f8d27b"),1.5,true)
			if home_clock<.1:
				for i in range(6): world.draw_line(split+Vector2.RIGHT.rotated(i*TAU/6)*4,split+Vector2.RIGHT.rotated(i*TAU/6)*11,CREAM,1.6,true)
		return
	var points=rod.get_points()
	var jitter=Vector2.ZERO
	if rules.hitstop_left>0: jitter=Vector2(sin(frozen_clock*176),cos(frozen_clock*151))*4
	for i in range(points.size()): points[i]+=jitter*(i/float(points.size()))
	world.draw_polyline(points,INK,4.6,true); world.draw_polyline(points,Color("d7ad6e"),2.1,true)
	var tip=points[-1]
	var endpoint=rules.lure_pos
	if rules.state in ["hookset","tug_of_war"]: endpoint=rules.fish_pos
	if rules.state in ["launch","recast_window","idle","game_over"]: endpoint=tip+Vector2(1,20)
	var line=PackedVector2Array()
	for i in range(25):
		var t=i/24.0
		var slack=sin(t*PI)*(-8 if rules.state=="casting" else 1)
		line.append(tip.lerp(endpoint,t)+Vector2(0,slack))
	world.draw_polyline(line,Color(.98,.94,.72,.82),1.0,true)

func _draw_lure() -> void:
	if rules.state in ["hookset","tug_of_war","launch","recast_window"]: return
	var pos=rules.lure_pos
	for spark in spark_trails: world.draw_circle(spark.pos,2,Color(1,.83,.35,spark.life/.22*.65))
	if rules.state=="bite_window":
		var bob=Vector2(pos.x,water.get_y(pos.x)+(-2 if not rules.bite_active else 7))
		world.draw_line(bob,pos,Color(.96,.96,.76,.75),1,true)
		world.draw_circle(bob,4.8,INK); world.draw_circle(bob+Vector2(0,-1),3.4,Color("ed8055")); world.draw_line(bob+Vector2(0,-9),bob+Vector2(0,-3),INK,1.5,true)
		var center=rules.fish_pos
		var target=rules.ring_target_radius
		var progress=rules.ring_progress
		var moving_radius=maxf(3,target+52*(1-progress))
		var ready=absf(rules.ring_elapsed-rules.ring_duration)<=rules.ring_window
		var fast_trophy=rules.catch_category=="fish" and rules.fish_tier==3 and rules.ring_duration<.54
		var glow=GOLD if ready else (Color("ffb46a") if fast_trophy else Color("fff6dd"))
		world.draw_arc(center,target,0,TAU,64,Color("17434b"),4.5,true)
		world.draw_arc(center,target,0,TAU,64,Color("f8e7ac"),1.8,true)
		world.draw_arc(center,moving_radius,0,TAU,64,glow,3.4 if ready else 2.3,true)
		world.draw_circle(center+Vector2(0,-moving_radius),3.5,glow)
		if ready: world.draw_string(font,center+Vector2(-16,-target-13),_t("点！","Tap!"),HORIZONTAL_ALIGNMENT_LEFT,-1,15,GOLD)

	world.draw_circle(pos,5.2,INK); world.draw_circle(pos+Vector2(-.7,-.7),3.4,GOLD)
	world.draw_arc(pos+Vector2(0,5),4,-PI*.4,PI,12,CREAM,1.6,true)
	if rules.state=="diving":
		world.draw_line(pos+Vector2(0,-8),pos+Vector2(0,-24),Color(1,.92,.58,.6),2,true)
		world.draw_line(pos+Vector2(-5,-10),pos+Vector2(-5,-19),Color(1,.92,.58,.35),1,true)

func _draw_fish(kind: int,pos: Vector2,scale_value: Vector2,rotation: float,alpha: float,detail: bool,species_id: String="") -> void:
	if species_id!="" and fish_textures.has(species_id):
		var meta=FishGeometry.DATA[species_id]
		var size_scale=FishGeometry.scale_for(species_id)
		world.draw_set_transform(pos,rotation,scale_value)
		world.draw_texture_rect(fish_textures[species_id],Rect2(-meta.anchor*size_scale,meta.canvas*size_scale),false,Color(1,1,1,alpha))
		world.draw_set_transform(Vector2.ZERO)
		return
	var tier=int(kind/2)
	var width=[33.0,43.0,57.0,70.0][tier]; var height_value=[23.0,24.0,28.0,31.0][tier]
	if kind==7: height_value=22
	var body=[Color("d9ad5c"),Color("e9934c"),Color("7b9e8a"),Color("e7c269"),Color("5f9170"),Color("a1b4a1"),Color("c5a65f"),Color("7d9d86")][kind]
	if not detail: body=Color("275b65")
	body.a=alpha
	world.draw_set_transform(pos,rotation,scale_value)
	var tailwave=sin(visual_time*(11 if rules.state=="tug_of_war" else 7)+kind)*2
	var tail=PackedVector2Array([Vector2(-width*.25,0),Vector2(-width*.58,-height_value*.43+tailwave),Vector2(-width*.48,0),Vector2(-width*.58,height_value*.43+tailwave)])
	world.draw_colored_polygon(tail,Color(body.r*.8,body.g*.8,body.b*.8,alpha))
	var outline=PackedVector2Array()
	for i in range(33):
		var a=TAU*i/32
		outline.append(Vector2(cos(a)*width*.45,sin(a)*height_value*.43)*(1 if i<17 else .98))
	world.draw_colored_polygon(outline,body)
	if detail:
		world.draw_polyline(outline,Color(INK,alpha),1.2,true)
		world.draw_colored_polygon(PackedVector2Array([Vector2(-width*.2,-height_value*.29),Vector2(-width*.12,-height_value*.66),Vector2(width*.14,-height_value*.32)]),Color(body.darkened(.22),alpha))
		world.draw_arc(Vector2(width*.15,0),height_value*.28,-1.4,1.5,14,Color(body.darkened(.32),alpha),1.0,true)
		world.draw_arc(Vector2(-1,-1),width*.31,PI*1.15,PI*1.75,20,Color(body.lightened(.35),alpha),1.5,true)
		if kind==1:
			world.draw_circle(Vector2(width*.12,-1),2.6,Color("316b85")); world.draw_circle(Vector2(width*.17,-1),1.3,Color("e04f3f"))
			for j in range(3): world.draw_line(Vector2(width*.2+j*1.5,-height_value*.17),Vector2(width*.14+j*1.8,height_value*.14),Color("79bdc0"),.8,true)
		if kind in [0,3]:
			for i in range(3): world.draw_line(Vector2(-width*.2+i*width*.13,-height_value*.25),Vector2(-width*.22+i*width*.13,height_value*.23),Color(body.darkened(.22),alpha),1.7,true)
		if kind in [2,4,6,7]:
			for i in range(7): world.draw_circle(Vector2(-width*.27+(i%4)*width*.12,-3+(i/4)*7),1.2,Color(body.darkened(.23),alpha))
		world.draw_colored_polygon(PackedVector2Array([Vector2(-3,1),Vector2(5,7),Vector2(6,-2)]),Color(body.darkened(.18),alpha))
		world.draw_circle(Vector2(width*.28,-height_value*.09),3,Color(CREAM,alpha)); world.draw_circle(Vector2(width*.3,-height_value*.1),1.7,Color(INK,alpha)); world.draw_circle(Vector2(width*.31,-height_value*.14),.6,Color(1,1,1,alpha))
		world.draw_line(Vector2(width*.37,height_value*.08),Vector2(width*.45,height_value*.04),Color(INK,alpha),1,true)
	world.draw_set_transform(Vector2.ZERO)
	if rules.state=="tug_of_war" and detail and pos.distance_to(rules.fish_pos)<18:
		var red=Color("ff7c62") if rules.duel_flash else Color(.95,.85,.55,.45)
		world.draw_arc(pos,maxf(width*.52,26),0,TAU,36,red,3 if rules.duel_flash else 1.3,true)

func _draw_water_surface() -> void:
	var points=water.get_surface_points()
	var band=points.duplicate()
	# Follow the same wave for the lower edge: a fixed y=300 edge crossed deep troughs.
	for i in range(points.size()-1,-1,-1): band.append(points[i]+Vector2(0,10))
	world.draw_colored_polygon(band,Color(.72,.91,.73,.33))
	world.draw_polyline(points,Color("def4d1").lerp(GOLD,fever_amount*.5),2.1,true)
	for i in range(0,points.size(),4):
		if absf(points[i].y-288)>5:
			world.draw_line(points[i]+Vector2(-3,3),points[i]+Vector2(3,3),Color(.9,1,.86,.55),1.2,true)

func _draw_particles() -> void:
	for p in particles:
		var color: Color=p.color; color.a=minf(1,p.life*4)
		if p.kind=="bubble": world.draw_arc(p.pos,p.radius,0,TAU,12,color,1,true)
		elif p.kind=="star":
			world.draw_line(p.pos-Vector2(p.radius,0),p.pos+Vector2(p.radius,0),color,1.4,true); world.draw_line(p.pos-Vector2(0,p.radius),p.pos+Vector2(0,p.radius),color,1.4,true)
		else:
			world.draw_set_transform(p.pos,p.velocity.angle()+PI/2,Vector2(.7,1.3)); world.draw_circle(Vector2.ZERO,p.radius,color); world.draw_set_transform(Vector2.ZERO)

func _draw_toasts() -> void:
	for toast in toasts:
		var alpha=clampf(toast.life*4,0,1)
		world.draw_style_box(_style(Color(.99,.94,.78,alpha),7,Color(.67,.7,.5,alpha)),Rect2(toast.pos-Vector2(5,15),Vector2(185,26)))
		world.draw_string(font,toast.pos,toast.text,HORIZONTAL_ALIGNMENT_LEFT,178,10,Color(INK,alpha))
		world.draw_string(font,toast.pos+Vector2(0,-20),toast.points,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color(INK,alpha))

func _draw_touch_indicator() -> void:
	world.draw_set_transform(Vector2(180,535),0,Vector2(1,.24))
	world.draw_circle(Vector2.ZERO,24+button_pulse*4,Color(.77,.92,.8,.05+button_pulse*.09))
	world.draw_set_transform(Vector2.ZERO)
	if rules.held:
		world.draw_circle(Vector2(180,535),4+button_pulse*2,GOLD)
	else: world.draw_arc(Vector2(180,535),4,0,TAU,18,Color(.8,.93,.8,.5),1.3,true)

func _settings_path() -> String: return data_dir.path_join("arcade-settings.json")
func _save_settings() -> void:
	if test_mode: return
	var data={"version":4,"language":language,"music_enabled":music_enabled,"music_volume":music_volume,"sfx_volume":sfx_volume,"catch_ledger":ledger.save_to_dictionary(),"best_combo":best_combo,"best_score":best_score,"muted":muted,"reduced_motion":reduced_motion,"haptics":haptics.enabled,"tune":rules.tune}
	var file=FileAccess.open(_settings_path()+".tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data)); file.flush(); file.close(); DirAccess.rename_absolute(ProjectSettings.globalize_path(_settings_path()+".tmp"),ProjectSettings.globalize_path(_settings_path()))
	_save_progress()
	_save_language_preferences()
func _load_settings() -> void:
	if test_mode or not FileAccess.file_exists(_settings_path()): return
	var parser=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(_settings_path()))!=OK or not parser.data is Dictionary: return
	var d: Dictionary=parser.data
	language=_normalize_language(str(d.get("language","en")))
	if d.get("catch_ledger",{}) is Dictionary: ledger.load_from_dictionary(d.get("catch_ledger",{}))
	muted=bool(d.get("muted",false)); reduced_motion=bool(d.get("reduced_motion",false)); haptics.enabled=bool(d.get("haptics",true)); best_combo=maxi(0,int(d.get("best_combo",0))); best_score=maxi(0,int(d.get("best_score",0)))
	music_enabled=bool(d.get("music_enabled",true))
	for key in ["music_volume","sfx_volume"]:
		var value: Variant=d.get(key,get(key))
		if (value is int or value is float) and is_finite(float(value)): set(key,clampf(float(value),0,1))
	if not d.has("sfx_volume") and muted: sfx_volume=0
	muted=sfx_volume<=0
	if d.get("tune") is Dictionary:
		for key in rules.tune:
			if d.tune.has(key) and (d.tune[key] is float or d.tune[key] is int): rules.tune[key]=d.tune[key]
		if int(d.get("version",1))<2: rules.tune.hook_window_ms=180.0
		rules.tune.hook_window_ms=clampf(float(rules.tune.hook_window_ms),80,250)

func _demo_input() -> void:
	if qa_done: return
	if qa_phase=="retry":
		if rules.state=="casting" and rules.state_time>.18:
			qa_done=true; _capture_frame.call_deferred("shallow-retry.png"); _finish_demo.call_deferred()
		return
	if rules.held: _release()
	match rules.state:
		"casting":
			var candidate=rules.predict_slam_contact()
			if qa_phase=="miss":
				if candidate.is_empty() and rules.lure_pos.x>135: _press(Vector2(180,600)); _release()
			elif "--qa-seek-deep" in OS.get_cmdline_user_args() or "--qa-salvage" in OS.get_cmdline_user_args():
				if qa_cast_plan<0: qa_cast_plan=_plan_deep_demo_cast()
				if qa_cast_plan>=0 and rules.state_time+0.00001>=qa_cast_plan: _press(Vector2(180,600)); _release()
			elif not candidate.is_empty() and candidate.get("category","fish")=="fish" and rules.lure_pos.x>135:
				_press(Vector2(180,600)); _release()
		"bite_window":
			if qa_phase=="failure_setup":
				if qa_failure_mode=="early" and rules.ring_elapsed>=.15:
					qa_phase="fail_expected"; _press(Vector2(180,600)); _release()
				elif qa_failure_mode=="late": qa_phase="fail_expected"
			elif qa_phase!="fail_expected" and rules.ring_elapsed>=rules.ring_duration: _press(Vector2(180,600)); _release()
		"game_over":
			if qa_phase in ["miss","fail_expected"]:
				qa_phase="over"; qa_game_over_clock=0
			elif qa_phase=="over":
				qa_game_over_clock+=1.0/60
				if qa_game_over_clock>.08 and not qa_captures.has("failure_detail"):
					qa_captures.failure_detail=true; _capture_frame.call_deferred("failure-"+qa_failure_mode+".png")
				if qa_game_over_clock>.38 and not qa_captures.has("night"):
					qa_captures.night=true; _capture_frame.call_deferred("shallow-game-over.png")
				if qa_game_over_clock>1.15:
					qa_phase="retry"; _press(Vector2(180,600)); _release()
			else:
				print("QA_UNEXPECTED_GAME_OVER ",rules.final_reason," catches=",rules.catches)
				qa_done=true; _finish_demo.call_deferred()
	if qa_phase=="retry" and rules.state=="casting" and rules.state_time>.18:
		qa_done=true; _capture_frame.call_deferred("shallow-retry.png"); _finish_demo.call_deferred()

func _capture_frame(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var dir="res://captures/shallow" if OS.has_feature("editor") else "user://qa-shallow"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	get_viewport().get_texture().get_image().save_png(dir.path_join(filename))

func _finish_demo() -> void:
	if "--qa-catalog" in OS.get_cmdline_user_args():
		_toggle_catalog()
		await RenderingServer.frame_post_draw
		await _capture_frame("shallow-catalog.png")
		_show_species("channel_catfish")
		await _capture_frame("fish-detail-card.png")
		_toggle_catalog()
	await RenderingServer.frame_post_draw
	var dir="res://captures/shallow" if OS.has_feature("editor") else "user://qa-shallow"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	get_viewport().get_texture().get_image().save_png(dir.path_join("shallow-fever.png"))
	var sorted=frame_samples.duplicate(); sorted.sort()
	var stats={"music_status":music_controller.get_status() if is_instance_valid(music_controller) else {},"platform":OS.get_name(),"physical_device":false,"catches":qa_peak_catches,"combo":qa_peak_combo,"score":qa_peak_score,"final_state":rules.state,"qa_phase":qa_phase,"salvages":qa_salvages,"cycle_seconds":qa_times,"p95_frame_ms":sorted[int(sorted.size()*.95)]*1000 if not sorted.is_empty() else 0,"memory_bytes":OS.get_static_memory_usage(),"input_processing_ms":input_samples,"haptics_backend":haptics.backend,"note":"Scripted real Godot rendering. Input processing is not measured touchscreen latency. Core Haptics hardware unverified.","events":qa_events}
	var file=FileAccess.open(dir.path_join("shallow-run.json"),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(stats,"\t")); file.close()
	print("SHALLOW_QA_COMPLETE catches=",qa_peak_catches," combo=",qa_peak_combo," p95_ms=",stats.p95_frame_ms," cycles=",qa_times)
	if "--quit-demo" in OS.get_cmdline_user_args(): _quit_cleanly.call_deferred()
	else: paused=true

func _exit_tree() -> void:
	if is_instance_valid(music_controller): music_controller.stop_all()
	for voice in voices:
		if is_instance_valid(voice): voice.stop(); voice.stream=null
	sound_bank.clear()

func _build_catalog() -> void:
	catalog_panel=Panel.new(); catalog_panel.position=Vector2(13,109); catalog_panel.size=Vector2(334,435)
	catalog_panel.add_theme_stylebox_override("panel",_style(CREAM,16,Color("a6c6ae")))
	ui.add_child(catalog_panel); catalog_panel.visible=false
	catalog_title=_panel_label(catalog_panel,"",Vector2(14,14),Vector2(255,48),12)
	_panel_label(catalog_panel,_t("点鱼看大图，认认这位常客。","Tap a fish for a closer look."),Vector2(14,50),Vector2(268,15),10)
	var close=_button("×",Rect2(280,8,44,44),20,catalog_panel)
	close.pressed.connect(_toggle_catalog)
	var most=_button(_t("最多 · 常来报到","Most · Regulars"),Rect2(14,68,140,44),12,catalog_panel)
	most.pressed.connect(func(): catalog_descending=true; _refresh_catalog())
	var least=_button(_t("最少 · 难得一见","Least · Rare Guests"),Rect2(165,68,155,44),12,catalog_panel)
	least.pressed.connect(func(): catalog_descending=false; _refresh_catalog())
	var scroll=ScrollContainer.new(); scroll.position=Vector2(12,120); scroll.size=Vector2(310,300)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	catalog_panel.add_child(scroll); catalog_scroll=scroll
	catalog_detail=Control.new(); catalog_detail.position=Vector2(12,120); catalog_detail.size=Vector2(310,300); catalog_panel.add_child(catalog_detail); catalog_detail.visible=false
	catalog_rows=VBoxContainer.new(); catalog_rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(catalog_rows)

func _toggle_catalog() -> void:
	if intro_active or _frontdoor_blocks(): return
	if paused: paused=false; pause_panel.visible=false
	if debug_open: debug_open=false; debug_panel.visible=false; detail_label.visible=false; debug_button.text=_t("调参","Tune")
	catalog_open=not catalog_open; catalog_panel.visible=catalog_open
	pointer_held=false; rules.held=false
	if catalog_open: _refresh_catalog()
	elif catalog_return_page!="" and is_instance_valid(frontdoor):
		if catalog_return_page=="pause": paused=true; frontdoor.show_pause()
		else: _title_from_frontdoor()
		catalog_return_page=""
	_update_ui()

func _refresh_catalog() -> void:
	catalog_detail_species=""
	catalog_detail.visible=false; catalog_scroll.visible=true
	for child in catalog_rows.get_children(): catalog_rows.remove_child(child); child.queue_free()
	catalog_title.text=_t("鱼获本  ·  累计 %d 条\n已记录 %d / 20 种   ·   当前可钓 %d 种","Fish Log · %d lifetime catches\nFound %d / 20 · %d available")%[ledger.total_catches(),ledger.active_caught_species_count(),Catalog.available_count()]
	var rows=ledger.sorted_counts(catalog_descending,true,true)
	# Future species are explicitly separated from real, catchable entries.
	var ordered=rows.filter(func(row): return row.available)+rows.filter(func(row): return not row.available)
	var max_count=1
	for entry in ordered: max_count=maxi(max_count,entry.count)
	for entry in ordered:
		var row=Control.new(); row.custom_minimum_size=Vector2(296,53); catalog_rows.add_child(row)
		var icon=TextureRect.new(); icon.position=Vector2(0,5); icon.size=Vector2(49,35); icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if fish_textures.has(entry.id): icon.texture=fish_textures[entry.id]
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE; row.add_child(icon)
		var chinese=_panel_label(row,_species_name(entry),Vector2(55,2),Vector2(162,20),13)
		var english=_panel_label(row,_t(entry.name_en,entry.scientific_name),Vector2(55,22),Vector2(162,18),9)
		var count=_panel_label(row,"× %d"%entry.count if entry.available else _t("尚未入场","Not in play"),Vector2(217,6),Vector2(75,22),11)
		count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		if not entry.available:
			for label in [chinese,english,count]: label.add_theme_color_override("font_color",Color("9b9d89"))
		var bar=ColorRect.new(); bar.position=Vector2(3,44); bar.size=Vector2(287.0*float(entry.count)/max_count,2); bar.color=Color("6d9e80"); bar.mouse_filter=Control.MOUSE_FILTER_IGNORE; row.add_child(bar)
		row.tooltip_text=entry.scientific_name
		var select=Button.new(); select.position=Vector2.ZERO; select.size=Vector2(296,49); select.flat=true; select.text=""; select.accessibility_name=_species_name(entry)+_t("，查看鱼类详情",", view species details")
		var species_id: String=entry.id
		select.pressed.connect(func(): _show_species(species_id)); row.add_child(select)

func _draw_catch(category: String,kind: int,pos: Vector2,scale_value: Vector2,angle: float,alpha: float,species_id: String="") -> void:
	if category=="fish": _draw_fish(kind,pos,scale_value,angle,alpha,true,species_id)
	else: _draw_bottom_item(category,pos,scale_value,angle,alpha)

func _draw_bottom_item(category: String,pos: Vector2,scale_value: Vector2,angle: float,alpha: float) -> void:
	world.draw_set_transform(pos,angle,scale_value)
	if category=="snail":
		world.draw_line(Vector2(-9,5),Vector2(10,5),Color(Color("d2b78e"),alpha),5,true)
		world.draw_circle(Vector2(-1,-1),8,Color(Color("c99558"),alpha)); world.draw_arc(Vector2(-1,-1),8,0,TAU,24,Color(INK,alpha),1.2,true)
		var spiral=PackedVector2Array()
		for i in range(30):
			var a=i*.3; spiral.append(Vector2(-1,-1)+Vector2(cos(a),sin(a))*i*.2)
		world.draw_polyline(spiral,Color(Color("805b3c"),alpha),1.1,true)
		for x in [8,12]:
			world.draw_line(Vector2(x-2,4),Vector2(x,-3),Color(Color("d2b78e"),alpha),1.6,true); world.draw_circle(Vector2(x,-3),1.1,Color(INK,alpha))
	else:
		for i in range(4):
			var curve=PackedVector2Array()
			for j in range(10): curve.append(Vector2((i-1.5)*4+sin(j*.5+visual_time*2+i)*2,8-j*(1.6+i*.2)))
			world.draw_polyline(curve,Color(Color("bdd29b" if i%2==0 else "559c73"),alpha),2.8,true)
		world.draw_line(Vector2(-7,9),Vector2(7,9),Color(Color("a6a17a"),alpha),2,true)
	world.draw_set_transform(Vector2.ZERO)

func _plan_deep_demo_cast() -> float:
	# QA demonstration only: choose a real future input time, never move fish or hooks.
	var preview=Rules.new()
	preview.restore(rules.snapshot())
	var best_time=-1.0
	var best_depth=-1.0
	for frame in range(150):
		if preview.state!="casting": break
		var hit=preview.predict_slam_contact()
		if not hit.is_empty():
			var priority=hit.pos.y
			if "--qa-salvage" in OS.get_cmdline_user_args() and hit.get("category","")!="fish": priority+=10000
			elif hit.get("category","")!="fish": priority=-1
			if priority>best_depth: best_depth=priority; best_time=preview.state_time
		preview.tick(1.0/60.0); preview.events.clear()
	return best_time

func _show_species(species_id: String) -> void:
	var entry=Catalog.get_species(species_id)
	if entry.is_empty(): return
	catalog_detail_species=species_id
	for child in catalog_detail.get_children(): catalog_detail.remove_child(child); child.queue_free()
	catalog_scroll.visible=false; catalog_detail.visible=true
	var chinese=_panel_label(catalog_detail,_species_name(entry),Vector2(0,4),Vector2(310,28),21); chinese.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var english=_panel_label(catalog_detail,_t(entry.name_en,"SPECIES %02d / 20"%(Catalog.ACTIVE_IDS.find(species_id)+1)),Vector2(0,35),Vector2(310,19),12); english.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var icon=TextureRect.new(); icon.position=Vector2(26,59); icon.size=Vector2(258,126); icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if fish_textures.has(species_id): icon.texture=fish_textures[species_id]
	catalog_detail.add_child(icon)
	var scientific=_panel_label(catalog_detail,entry.scientific_name,Vector2(0,183),Vector2(310,18),10); scientific.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var count=_panel_label(catalog_detail,_t("累计钓到 %d 条","Caught %d in total")%ledger.count_for(species_id),Vector2(0,207),Vector2(310,26),18); count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var tier=FishGeometry.tier_for(species_id)
	var joke=_panel_label(catalog_detail,[_t("个头不大，出勤很稳。","Small fish. Big attendance record."),_t("有点身价，也有点脾气。","A decent catch. With an attitude."),_t("这一口值钱，手别抢跑。","Worth the wait. Don’t jump the gun."),_t("老板鱼，脾气跟身价一样大。","Big fish. Bigger ego.")][tier],Vector2(0,230),Vector2(310,23),12); joke.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var back=_button(_t("‹  返回鱼获本","‹  Back to Fish Log"),Rect2(45,256,220,44),13,catalog_detail)
	back.pressed.connect(func(): catalog_detail_species=""; catalog_detail.visible=false; catalog_scroll.visible=true)

func _quit_cleanly() -> void:
	paused=true; muted=true
	if is_instance_valid(music_controller): music_controller.stop_all()
	for voice in voices:
		if is_instance_valid(voice): voice.stop(); voice.stream=null
	# Let the audio driver release its current playback buffer before SceneTree teardown.
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()

func _save_progress() -> void:
	if test_mode: return
	# Separate from legacy settings: older running prototypes never write this filename.
	var path=data_dir.path_join("catch-progress-v2.json")
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version":1,"ledger":ledger.save_to_dictionary(),"best_combo":best_combo,"best_score":best_score}))
		file.flush(); file.close()
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))

func _load_progress() -> void:
	if test_mode: return
	var path=data_dir.path_join("catch-progress-v2.json")
	if not FileAccess.file_exists(path): return
	var parser=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK or not parser.data is Dictionary: return
	var data: Dictionary=parser.data
	if data.get("version",0)!=1 or not data.get("ledger") is Dictionary: return
	var saved: Dictionary=data.ledger
	if saved.is_empty() or not saved.get("counts") is Dictionary or saved.counts.is_empty() or not saved.get("recent_tokens") is Array: return
	if ledger.load_from_dictionary(saved):
		for key in ["best_combo","best_score"]:
			var value: Variant=data.get(key,0)
			if (value is int or value is float) and is_finite(float(value)) and value>=0:
				set(key,maxi(int(get(key)),int(value)))

func _frontdoor_blocks() -> bool:
	return is_instance_valid(frontdoor) and frontdoor.blocking

func _build_frontdoor() -> void:
	frontdoor=Frontdoor.new(); ui.add_child(frontdoor)
	frontdoor.setup(font,{"language":language,"music_enabled":music_enabled,"music_volume":music_volume,"sfx_volume":sfx_volume,"haptics_enabled":haptics.enabled,"reduced_motion":reduced_motion})
	frontdoor.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	frontdoor.size=Vector2(360,640)
	frontdoor.start_requested.connect(_start_from_frontdoor)
	frontdoor.resume_requested.connect(_resume_from_frontdoor)
	frontdoor.title_requested.connect(_title_from_frontdoor)
	frontdoor.catalog_requested.connect(_catalog_from_frontdoor)
	frontdoor.settings_changed.connect(_apply_setting)
	frontdoor.show_title(false)

func _start_from_frontdoor() -> void:
	frontdoor.close(); paused=false; catalog_open=false; debug_open=false
	catalog_panel.hide(); pause_panel.hide(); debug_panel.hide()
	pointer_held=false; rearm_hold=false
	var restarting=has_started
	if restarting: rules.setup(20261109+ledger_run)
	has_started=true; rules.held=false
	_consume_events()
	if not restarting: _sound("cast")
	_update_ui()

func _resume_from_frontdoor() -> void:
	frontdoor.close(); paused=false; pointer_held=false; rules.held=false
	if rules.state=="casting": rules.slam_armed=true
	_update_ui()

func _title_from_frontdoor() -> void:
	paused=true; pointer_held=false; rules.held=false
	frontdoor.show_title(has_started and rules.state!="game_over")
	_update_ui()

func _catalog_from_frontdoor() -> void:
	catalog_return_page=frontdoor.page
	frontdoor.close(); paused=false
	if not catalog_open: _toggle_catalog()

func _apply_setting(key: String,value: Variant) -> void:
	match key:
		"music_enabled": music_enabled=bool(value)
		"music_volume": music_volume=clampf(float(value),0,1)
		"sfx_volume": sfx_volume=clampf(float(value),0,1); muted=sfx_volume<=0
		"haptics_enabled": haptics.enabled=bool(value)
		"reduced_motion": reduced_motion=bool(value)
		"language":
			language=_normalize_language(str(value))
			if is_instance_valid(frontdoor): frontdoor.set_language(language)
			_rebuild_localized_ui()
	if is_instance_valid(music_controller):
		music_controller.set_enabled(music_enabled); music_controller.set_volume(music_volume)
	_save_settings()

func _update_music_duck() -> void:
	if not is_instance_valid(music_controller): return
	var amount=0.0
	if not app_has_focus: amount=1.0
	elif catalog_open or debug_open or paused: amount=.65
	elif _frontdoor_blocks(): amount=.25 if frontdoor.page in ["title","opening"] else .65
	elif rules.state=="game_over": amount=.35
	music_controller.set_duck(amount)


func _t(chinese: String,english: String) -> String:
	return chinese if language=="zh" else english

func _normalize_language(value: String) -> String:
	return "zh" if value.strip_edges().to_lower().begins_with("zh") else "en"

func _species_name(entry: Dictionary) -> String:
	return str(entry.get("name_zh" if language=="zh" else "name_en",entry.get("name_en","Fish")))

func _goodbye_line() -> String:
	return [_t("说好最后一竿的…","One last cast. Allegedly."),_t("鱼没上来，月亮上班了。","Fish clocked out. Moon’s in."),_t("拎包，今天先放鱼一马。","We let the fish win today."),_t("最后一竿，明天再说。","One last cast. Tomorrow.")][(rounds_finished/2)%4]

func _fit_label(label: Label,preferred: int,minimum: int) -> void:
	var pixels=preferred
	var longest=0.0
	for line in label.text.split("\n"): longest=maxf(longest,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x)
	while longest>label.size.x and pixels>minimum:
		pixels-=1; longest=0.0
		for line in label.text.split("\n"): longest=maxf(longest,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x)
	label.add_theme_font_size_override("font_size",pixels)

func _fit_button(button: Button,preferred: int,minimum: int,width: float) -> void:
	var pixels=preferred
	while font.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x>width and pixels>minimum: pixels-=1
	button.add_theme_font_size_override("font_size",pixels)

func _rebuild_localized_ui() -> void:
	if not is_instance_valid(ui): return
	var selected=catalog_detail_species
	var scroll_position=catalog_scroll.scroll_vertical if is_instance_valid(catalog_scroll) else 0
	for child in ui.get_children():
		if child==frontdoor: continue
		ui.remove_child(child); child.queue_free()
	_build_ui()
	# Rebuild presentation only. Never touch the current cast, ring, score or ledger.
	pause_panel.visible=paused and not is_instance_valid(frontdoor)
	debug_panel.visible=debug_open; detail_label.visible=debug_open
	catalog_panel.visible=catalog_open
	if catalog_open:
		_refresh_catalog()
		catalog_scroll.set_deferred("scroll_vertical",scroll_position)
		if not selected.is_empty(): _show_species(selected)
	cue_text=""; cue_left=0; toasts.clear()
	last_fingerprint=0; _update_ui()

func _save_language_preferences() -> void:
	if test_mode: return
	var path=data_dir.path_join("ui-preferences-v1.json")
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version":1,"language":language})); file.flush(); file.close()
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))

func _load_language_preferences() -> void:
	if test_mode: return
	var path=data_dir.path_join("ui-preferences-v1.json")
	if not FileAccess.file_exists(path): return
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and parsed.get("version")==1 and parsed.get("language") in ["en","zh"]: language=parsed.language
