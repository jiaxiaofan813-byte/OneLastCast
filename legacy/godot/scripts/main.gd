extends Node2D

const Rules = preload("res://scripts/fishing_rules.gd")
const Copy = preload("res://scripts/game_copy.gd")
const Store = preload("res://scripts/game_store.gd")
const INK = Color("173f48")
const CREAM = Color("fff4da")
const MINT = Color("afdfcf")

var rules = Rules.new()
var font = SystemFont.new()
var background: Texture2D
var fish_textures: Array = []
var fish_regions: Array[Rect2] = []
var sound_bank: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var particles: Array[Dictionary] = []
var ripples: Array[Dictionary] = []
var floats: Array[Dictionary] = []
var ui_root: Control
var action_button: Button
var pause_button: Button
var mode_button: Button
var replay_button: Button
var mute_button: Button
var pause_panel: Panel
var status_label: Label
var best_label: Label
var result_label: Label
var hint_label: Label
var debug_label: Label
var sound_check: CheckButton
var motion_check: CheckButton
var paused = false
var muted = false
var reduced_motion = false
var debug_view = false
var test_mode = false
var preview_automation = false
var preview_done = false
var visual_time = 0.0
var kick = 0.0
var load_smooth = 0.0
var catch_flash = 0.0
var catch_sound_index = 0
var captured_action = false
var best = {"A": 0, "B": 0}
var rounds_completed = 0
var stroke_rng = RandomNumberGenerator.new()
var last_result: Dictionary = {}
var input_locked = false
var restore_countdown = 0.0
var selected_mode = "B"
var seed_base = 104729
var saved_seed = 104729
var store_data
var saved_data: Dictionary = {}
var language = "zh"
var music_enabled = true
var haptics_enabled = true
var music_player: AudioStreamPlayer
var title_label: Label
var subtitle_label: Label
var pause_title: Label
var resume_button: Button
var reset_button: Button
var help_button: Button
var credits_button: Button
var language_button: Button
var music_check: CheckButton
var haptics_check: CheckButton
var info_panel: Panel
var info_title: Label
var info_text: RichTextLabel
var info_close: Button
var info_kind = ""
var info_return_pause = false
var session_nonce = ""
var committed_rounds: Array = []
var streak = 0
var snapshot_clock = 0.0
var splash_elapsed = 0.0
var last_haptic_ms = -1000
var restoring = false
var qa_round = 0
var qa_clock = 0.0
var qa_cycles = 0
var qa_finished = false
var qa_frame_samples: Array[float] = []
var qa_capture_pending = false
var qa_input_latency_ms: Array[float] = []
var qa_next_language = false
var ui_fingerprint = -1
var screen_notice = ""


func _ready() -> void:
	font.font_names = PackedStringArray(["PingFang SC", "Hiragino Sans GB", "Arial"])
	stroke_rng.seed = 68432
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-round="): qa_round = int(arg.trim_prefix("--qa-round=")); test_mode = true
	preview_automation = "--capture-demo" in OS.get_cmdline_user_args()
	if preview_automation: test_mode = true
	store_data = Store.new(test_mode)
	if not test_mode: _load_settings()
	session_nonce = saved_data.get("session_nonce", str(Time.get_unix_time_from_system()) + "-" + str(randi()))
	background = _texture_if_exists("res://assets/environment/pond.png")
	for n in ["silverleaf", "roundback", "moonfin"]:
		var texture = _texture_if_exists("res://assets/fish/" + n + ".png")
		fish_textures.append(texture)
		if texture:
			var im = texture.get_image()
			if im.is_compressed(): im.decompress()
			var used = Rect2(im.get_used_rect())
			fish_regions.append(Rect2(used.position/texture.get_size(),used.size/texture.get_size()))
		else: fish_regions.append(Rect2(0,0,1,1))
	for n in ["cast", "reel", "catch1", "catch2", "catch3", "splash", "big_splash", "result", "empty"]:
		var path = "res://assets/audio/" + n + ".wav"
		if ResourceLoader.exists(path): sound_bank[n] = load(path)
	for i in range(6):
		var player = AudioStreamPlayer.new()
		add_child(player); voices.append(player)
	rules.setup(seed_base, "B")
	if not test_mode and saved_data.get("snapshot") is Dictionary:
		if rules.restore_snapshot(saved_data.snapshot):
			selected_mode = rules.mode
			restoring = rules.state not in ["ready", "result"]
			paused = restoring
		else: screen_notice = ""
	_build_ui()
	_start_music()
	get_tree().auto_accept_quit = false
	Engine.max_fps = 60
	_update_ui()
	if restoring: pause_panel.visible = true
	if qa_round > 0:
		print("QA_BEGIN round=",qa_round," platform=",OS.get_name()," renderer=",RenderingServer.get_current_rendering_method()," viewport=",get_viewport_rect().size)

func _texture_if_exists(path: String) -> Texture2D:
	if ResourceLoader.exists(path): return load(path)
	return null

func _build_ui() -> void:
	ui_root = Control.new()
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)
	title_label = _label("",Vector2(22,16),Vector2(264,34),25,INK)
	subtitle_label = _label("",Vector2(23,49),Vector2(260,18),8,Color("658982"))
	best_label = _label("",Vector2(23,77),Vector2(200,25),13,INK)
	pause_button = _button("Ⅱ",Rect2(294,18,44,44),20)
	pause_button.pressed.connect(_toggle_pause)
	status_label = _label("",Vector2(40,183),Vector2(280,25),12,Color("ebf6da"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label = _label("",Vector2(20,528),Vector2(320,35),20,CREAM)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.accessibility_live = 1
	hint_label = _label("",Vector2(14,557),Vector2(332,21),11,Color("c6ded1"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_button = _button("",Rect2(81,582,198,46),19,true)
	action_button.button_down.connect(_main_action)
	mute_button = _button("♪",Rect2(20,584,44,44),18)
	mute_button.pressed.connect(func(): muted=not muted; _save_settings(); _update_ui())
	replay_button = _button("?",Rect2(296,584,44,44),20)
	replay_button.pressed.connect(func(): _show_info("help"))
	mode_button = _button("",Rect2(234,77,104,27),10)
	mode_button.visible = false
	mode_button.pressed.connect(_switch_mode)
	debug_label = _label("",Vector2(9,223),Vector2(342,285),10,CREAM)
	debug_label.visible = false
	pause_panel = Panel.new()
	pause_panel.position = Vector2(25,104); pause_panel.size = Vector2(310,440)
	pause_panel.add_theme_stylebox_override("panel",_style(CREAM,20,Color("a8cdb9"),1))
	ui_root.add_child(pause_panel); pause_panel.visible=false
	pause_title = Label.new(); pause_title.position=Vector2(22,17)
	pause_title.add_theme_font_override("font",font); pause_title.add_theme_font_size_override("font_size",22); pause_title.add_theme_color_override("font_color",INK)
	pause_panel.add_child(pause_title)
	sound_check = _check("",Vector2(20,61),not muted)
	sound_check.toggled.connect(func(v): muted=not v; _save_settings(); _update_ui())
	music_check = _check("",Vector2(20,102),music_enabled)
	music_check.toggled.connect(func(v): music_enabled=v; _apply_audio_state(); _save_settings())
	haptics_check = _check("",Vector2(20,143),haptics_enabled)
	haptics_check.toggled.connect(func(v): haptics_enabled=v; _save_settings())
	motion_check = _check("",Vector2(20,184),reduced_motion)
	motion_check.toggled.connect(func(v): reduced_motion=v; _save_settings())
	language_button = _button("",Rect2(22,231,266,37),13,false,pause_panel)
	language_button.pressed.connect(func(): language="en" if language=="zh" else "zh"; _save_settings(); _update_ui())
	help_button = _button("",Rect2(22,280,125,36),12,false,pause_panel)
	help_button.pressed.connect(func(): _show_info("help"))
	credits_button = _button("",Rect2(155,280,133,36),12,false,pause_panel)
	credits_button.pressed.connect(func(): _show_info("credits"))
	resume_button = _button("",Rect2(22,331,266,45),18,true,pause_panel)
	resume_button.pressed.connect(_toggle_pause)
	reset_button = _button("",Rect2(76,391,158,29),11,false,pause_panel)
	reset_button.pressed.connect(_reset_cast)
	info_panel=Panel.new(); info_panel.position=Vector2(25,110); info_panel.size=Vector2(310,430)
	info_panel.add_theme_stylebox_override("panel",_style(CREAM,20,Color("a8cdb9"),1))
	ui_root.add_child(info_panel); info_panel.visible=false
	info_title=Label.new(); info_title.position=Vector2(20,18); info_title.size=Vector2(270,32)
	info_title.add_theme_font_override("font",font); info_title.add_theme_font_size_override("font_size",20); info_title.add_theme_color_override("font_color",INK)
	info_panel.add_child(info_title)
	info_text=RichTextLabel.new(); info_text.position=Vector2(20,65); info_text.size=Vector2(270,288)
	info_text.add_theme_font_override("normal_font",font); info_text.add_theme_font_size_override("normal_font_size",14); info_text.add_theme_color_override("default_color",INK)
	info_text.scroll_active=true; info_text.bbcode_enabled=false
	info_panel.add_child(info_text)
	info_close=_button("",Rect2(22,370,266,40),16,true,info_panel)
	info_close.pressed.connect(_close_info)

func _check(text_value: String, at: Vector2, checked: bool) -> CheckButton:
	var b = CheckButton.new()
	b.position = at
	b.size = Vector2(255, 37)
	b.text = text_value
	b.button_pressed = checked
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_hover_pressed_color", INK)
	pause_panel.add_child(b)
	return b

func _label(value: String, pos: Vector2, size_value: Vector2, pixels: int, color: Color) -> Label:
	var l = Label.new()
	l.position = pos
	l.size = size_value
	l.text = value
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", pixels)
	l.add_theme_color_override("font_color", color)
	ui_root.add_child(l)
	return l

func _style(color: Color, radius: int, border: Color, width: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(width)
	return style

func _button(value: String, rect: Rect2, pixels: int, primary = false, host: Control = null) -> Button:
	var b = Button.new()
	b.position = rect.position
	b.size = rect.size
	b.text = value
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", pixels)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", Color("809e93"))
	var base = Color("f4bc69") if primary else Color("f9f2dc")
	b.add_theme_stylebox_override("normal", _style(base, 13, Color("d8e3c8"), 1))
	b.add_theme_stylebox_override("hover", _style(base.lightened(0.07), 13, INK.lightened(0.5), 1))
	b.add_theme_stylebox_override("pressed", _style(base.darkened(0.12), 13, INK.lightened(0.4), 2))
	b.add_theme_stylebox_override("disabled", _style(Color("224f56"), 13, Color("3f716e"), 1))
	b.add_theme_stylebox_override("focus", _style(Color(0,0,0,0), 13, Color("df8549"), 2))
	(host if host != null else ui_root).add_child(b)
	return b

func _main_action() -> void:
	if paused or restore_countdown>0.0 or input_locked: return
	var before = rules.state
	var started = Time.get_ticks_usec()
	rules.act()
	if before=="ready": last_result.clear()
	kick=1.0
	_consume_events()
	_update_ui()
	if qa_round>0: qa_input_latency_ms.append((Time.get_ticks_usec()-started)/1000.0)
	_save_settings()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE,KEY_ENTER: _main_action()
			KEY_ESCAPE:
				if info_panel.visible: _close_info()
				else: _toggle_pause()
			KEY_R:
				if debug_view: _replay()
			KEY_F2:
				if debug_view: _switch_mode()
			KEY_M: muted=not muted; _save_settings(); _update_ui()
			KEY_F1:
				debug_view=not debug_view; debug_label.visible=debug_view; mode_button.visible=debug_view
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		if event.position.y>210 and event.position.y<525: _main_action()

func _notification(what: int) -> void:
	if not is_instance_valid(pause_panel): return
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED] and not test_mode:
		if rules.state not in ["ready","result"]:
			paused=true; pause_panel.visible=true; _apply_audio_state(); _save_settings(); _update_ui()
	elif what==NOTIFICATION_WM_CLOSE_REQUEST:
		_save_settings(); get_tree().quit()

func _toggle_pause() -> void:
	if info_panel.visible: _close_info(); return
	paused=not paused; pause_panel.visible=paused
	if not paused: restore_countdown=0.6; restoring=false
	_apply_audio_state(); _save_settings(); _update_ui()

func _switch_mode() -> void:
	if paused or (rules.state != "ready" and rules.state != "result"): return
	selected_mode = "A" if selected_mode == "B" else "B"
	rules.setup(seed_base, selected_mode)
	particles.clear()
	floats.clear()
	_save_settings()
	_update_ui()

func _replay() -> void:
	if paused: return
	rules.setup(rules.round_seed, selected_mode)
	particles.clear()
	floats.clear()
	_update_ui()

func _physics_process(dt: float) -> void:
	if qa_round>0: _qa_step(dt)
	if paused: return
	if restore_countdown>0:
		restore_countdown=maxf(0,restore_countdown-dt); _update_ui(); return
	rules.tick(dt)
	_consume_events(); _update_ui()
	snapshot_clock+=dt
	if snapshot_clock>=0.5:
		snapshot_clock=0; _save_settings()
	if preview_automation:
		if rules.state=="ready" and last_result.is_empty(): _main_action()
		if rules.state=="sinking":
			for fish in rules.fish:
				if absf(fish.x-180)<fish.width*.5+5 and rules.hook_y>fish.y+4 and rules.hook_y-fish.y<100:
					_main_action(); break
		if not last_result.is_empty() and not preview_done:
			preview_done=true; _capture_preview.call_deferred()

func _process(dt: float) -> void:
	if not paused and restore_countdown <= 0:
		visual_time += minf(dt, 0.1)
		if rules.state=="splash": splash_elapsed += minf(dt,0.1)
		if qa_round>0: qa_frame_samples.append(dt)
		kick = move_toward(kick, 0.0, dt * 5.0)
		catch_flash = move_toward(catch_flash, 0.0, dt * 6.0)
		var target_load = 0.0
		for f in rules.caught: target_load += [1.0, 2.4, 1.4][int(f.kind)]
		if rules.state == "result" or rules.state == "ready": target_load = 0
		load_smooth = lerpf(load_smooth, target_load, minf(1, dt * 9))
		for p in particles:
			p.life -= dt
			p.position += p.velocity * dt
			p.velocity.y += p.gravity * dt
		particles = particles.filter(func(p): return p.life > 0)
		for r in ripples: r.life -= dt
		ripples = ripples.filter(func(r): return r.life > 0)
		for f in floats: f.life -= dt; f.position.y -= dt * 20
		floats = floats.filter(func(f): return f.life > 0)
	queue_redraw()

func _consume_events() -> void:
	var events: Array = rules.events.duplicate(true)
	rules.events.clear()
	var should_prepare=false
	for e in events:
		match e.type:
			"cast": catch_sound_index=0; _sound("cast"); _ripple(180,0.7,25); _haptic(15,0.12)
			"reel": _sound("reel"); kick=1; _haptic(20,0.16)
			"catch":
				catch_sound_index=mini(3,catch_sound_index+1); _sound("catch"+str(catch_sound_index)); _haptic(26,0.25)
				catch_flash=1; _burst(Vector2(180,rules.hook_y),10 if not reduced_motion else 3,false)
				floats.append({"position":Vector2(200,rules.hook_y-4),"text":"+"+str(e.get("value",10)),"life":.65})
				if (preview_automation or qa_round>0) and not captured_action:
					captured_action=true; _capture_action.call_deferred()
			"splash":
				splash_elapsed=0
				var heavy=false
				for fish in rules.caught:
					if int(fish.kind)==1: heavy=true
				_sound(("big_splash" if heavy else "splash") if rules.caught.size()>0 else "empty")
				_burst(Vector2(180,160),(38 if heavy else 24) if not reduced_motion else 7,true); _ripple(180,.9,60 if heavy else 40)
				if rules.caught.size()>0: _haptic(42 if heavy else 28,.4 if heavy else .22)
			"result":
				var token=session_nonce+":"+str(rules.round_id)+":"+str(rules.round_seed)
				var is_best=rules.score>int(best.get(selected_mode,0))
				if not token in committed_rounds:
					committed_rounds.append(token)
					if committed_rounds.size()>64: committed_rounds.pop_front()
					rounds_completed+=1; best[selected_mode]=maxi(int(best.get(selected_mode,0)),rules.score)
					streak=streak+1 if rules.score>0 else 0
					if rules.score>0: _sound("result")
				last_result={"mode":selected_mode,"seed":rules.round_seed,"score":rules.score,"count":rules.caught.size(),"fish":rules.caught.duplicate(true),"click_time":rules.click_time,"cast_time":rules.cast_time,"new_best":is_best,"round_id":rules.round_id}
				_log_round(last_result); should_prepare=true; qa_cycles+=1
	if should_prepare:
		rules.prepare_next_round()
		_save_settings()

func _sound(name: String) -> void:
	if muted or not sound_bank.has(name): return
	for p in voices:
		if not p.playing:
			p.stream = sound_bank[name]
			p.volume_db = -9.0
			p.play()
			return

func _burst(at: Vector2, amount: int, surface: bool) -> void:
	for i in range(amount):
		var direction = Vector2(stroke_rng.randf_range(-1, 1), stroke_rng.randf_range(-1.8, -0.3))
		particles.append({"position": at, "velocity": direction * stroke_rng.randf_range(23, 83 if surface else 38), "life": stroke_rng.randf_range(0.22, 0.65), "radius": stroke_rng.randf_range(1.0, 3.0), "gravity": 160.0 if surface else -8.0, "surface": surface})

func _ripple(x: float, life: float, radius: float) -> void:
	ripples.append({"x":x, "life":life, "maxlife":life, "radius":radius})

func _update_ui() -> void:
	if not is_instance_valid(action_button): return
	var fingerprint=hash([language,rules.state,rules.caught.size(),rules.capture_left>0,paused,restore_countdown>0,muted,music_enabled,haptics_enabled,reduced_motion,best,streak,last_result,restoring,selected_mode,debug_view])
	if fingerprint==ui_fingerprint and not debug_view: return
	ui_fingerprint=fingerprint
	var state: String=rules.state
	title_label.text=_t("title"); title_label.add_theme_font_size_override("font_size",23 if language=="en" else 25)
	subtitle_label.text=_t("subtitle"); best_label.text=_t("best")%int(best.get(selected_mode,0))
	pause_button.accessibility_name=_t("pause_access"); action_button.accessibility_name=_t("main_access")
	replay_button.accessibility_name=_t("how"); mute_button.accessibility_name=_t("sound_access")
	mode_button.text=_t("mode_dev")%selected_mode; mode_button.disabled=state not in ["ready","result"]
	mute_button.text="♪" if not muted else "×♪"
	action_button.disabled=paused or restore_countdown>0 or state in ["reeling","splash"]
	pause_title.text=_t("pause_title"); sound_check.text=_t("sound"); music_check.text=_t("music"); haptics_check.text=_t("haptics"); motion_check.text=_t("motion")
	sound_check.set_pressed_no_signal(not muted); music_check.set_pressed_no_signal(music_enabled); motion_check.set_pressed_no_signal(reduced_motion); haptics_check.set_pressed_no_signal(haptics_enabled)
	language_button.text=_t("language")+"  ·  "+("简体中文" if language=="zh" else "English")
	help_button.text=_t("how"); credits_button.text=_t("credits"); resume_button.text=_t("resume"); reset_button.text=_t("reset"); info_close.text=_t("close")
	status_label.text=""; result_label.text=""
	match state:
		"ready","result":
			if not last_result.is_empty():
				action_button.text=_t("again")
				result_label.text=(_t("result")%[int(last_result.count),int(last_result.score)]) if int(last_result.score)>0 else _t("empty")
				hint_label.text=_t("record") if last_result.get("new_best",false) else (_t("full_hint") if int(last_result.count)==3 else (_t("win_hint") if int(last_result.score)>0 else _t("empty_hint")))
				if streak>=3 and not last_result.get("new_best",false): hint_label.text=_t("streak")%streak
			else:
				action_button.text=_t("cast"); result_label.text=_t("welcome"); hint_label.text=_t("first_hint") if rounds_completed<2 else _t("ready_hint")
		"sinking": action_button.text=_t("reel"); hint_label.text=_t("sink_hint")
		"aiming": action_button.text=_t("reel"); hint_label.text=_t("aim_hint")
		"reeling":
			action_button.text=_t("reeling"); hint_label.text=_t("window_hint")
			status_label.text=_t("full") if rules.caught.size()>=3 else (_t("open")%rules.caught.size() if rules.capture_left>0 else _t("closed"))
		"splash": action_button.text=_t("splash"); hint_label.text=""
	if restore_countdown>0: status_label.text=_t("resume_wait")
	if restoring: hint_label.text=_t("restored")
	if debug_view:
		debug_label.text="F1 debug · F2 A/B · R replay
seed %d · %s
t %.3f y %.1f
window %.3f fish %d"%[rules.round_seed,state,rules.time,rules.hook_y,rules.capture_left,rules.caught.size()]

func _draw() -> void:
	_draw_environment()
	_draw_fisher()
	for f in rules.fish:
		if not f.caught: _draw_fish(f, Vector2(f.x, f.y), false, 0)
	_draw_line_and_hook()
	for i in range(rules.caught.size()):
		var f: Dictionary = rules.caught[i]
		if rules.state in ["ready","result"]: continue
		var offset = [Vector2(-15, 17), Vector2(16, 31), Vector2(-11, 47)][i]
		var at = Vector2(180, rules.hook_y) + offset
		if rules.state == "splash":
			var leap=clampf((splash_elapsed-i*.08)/.44,0,1)
			at=Vector2(180+(i-1)*26,160+offset.y-70*sin(leap*PI)-leap*22)
		_draw_fish(f, at, true, i)
	for p in particles:
		var a = minf(1, p.life*3)
		var col = Color(0.83,0.98,0.90,a) if p.surface else Color(0.75,0.95,0.85,a*0.8)
		draw_circle(p.position, p.radius, col, not p.surface)
	for r in ripples:
		var progress = 1.0 - r.life/r.maxlife
		draw_set_transform(Vector2(r.x, 161), 0, Vector2(1, 0.17))
		draw_arc(Vector2.ZERO, 4 + progress*r.radius, 0, TAU, 40, Color(0.91,0.98,0.81,r.life/r.maxlife*0.8), 1.7, true)
		draw_set_transform(Vector2.ZERO)
	for f in floats:
		draw_string(font, f.position, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1,0.91,0.62,minf(1,f.life*4)))
	if rules.state in ["ready","result"] and not last_result.is_empty() and last_result.get("fish") is Array:
		var display_fish: Array=last_result.fish
		for i in range(display_fish.size()):
			_draw_fish(display_fish[i],Vector2(180+(i-(display_fish.size()-1)/2.0)*60,493),false,i)
	if paused:
		draw_rect(Rect2(0,0,360,640), Color(0.03,0.15,0.18,0.55))

func _draw_environment() -> void:
	if background:
		draw_texture_rect(background, Rect2(0,0,360,640), false)
	else:
		draw_rect(Rect2(0,0,360,162), Color("f5e9bf"))
		draw_circle(Vector2(280,100), 22, Color("f6d78f"))
		for layer in range(3):
			var verts = PackedVector2Array([Vector2(0,160)])
			for i in range(37): verts.append(Vector2(i*10, 117 + layer*12 + sin(i*0.24+layer*2.3)*13 + cos(i*.5)*4))
			verts.append(Vector2(360,160))
			draw_colored_polygon(verts, [Color("b7cdb3"),Color("90b7a3"),Color("729c8f")][layer])
		for y in range(160,551,3):
			var c = Color("4dafa8").lerp(Color("123e4d"), float(y-160)/390)
			draw_rect(Rect2(0,y,360,3), c)
		for i in range(12):
			var side = 14 if i%2 == 0 else 346
			var p = PackedVector2Array()
			var height_value = 35 + (i*29)%100
			for j in range(12): p.append(Vector2(side + sin(j*0.3+i)*9 + sin(visual_time*.5+i)*j*.4, 545-j*height_value/11))
			draw_polyline(p, Color("245c60") if i%3 else Color("367a70"), 3, true)
		for i in range(17):
			var x = float((i*91)%360)
			draw_set_transform(Vector2(x, 545), 0, Vector2(1.6, 1))
			draw_circle(Vector2.ZERO, 9+(i%4)*5, Color("2c565b"))
			draw_set_transform(Vector2.ZERO)
	# The bottom is a separate quiet interaction zone, never an opaque overlay on fish.
	for y in range(520,640,2):
		var alpha = clampf(float(y-520)/36,0,1)
		draw_rect(Rect2(0,y,360,2), Color(0.055,0.19,0.23,alpha))
	var water = PackedVector2Array()
	for x in range(0,361,4): water.append(Vector2(x,160+sin(x*.055+visual_time*1.4)*1.1))
	draw_polyline(water, Color("d0eac5"), 2.2, true)
	for i in range(10):
		var px = float((i*83+29)%360)
		var py = 190+fposmod(i*47.3-visual_time*(3+i%3),330)
		draw_arc(Vector2(px,py), 1.1+i%3*.4, 0,TAU,12,Color(0.66,0.88,0.79,0.2),.6,true)
	# Hanging capacity dots live at the water edge.
	if rules.state not in ["ready", "result"]:
		for i in range(3 if selected_mode == "B" else 1):
			draw_circle(Vector2(169+i*11,174),3.2, Color("ffe1a0") if i<rules.caught.size() else Color(0.8,0.95,0.84,0.28))

func _draw_fisher() -> void:
	# A small component-built angler keeps the wrist and rod physically connected.
	var bob = 0.0 if reduced_motion else sin(visual_time*2)*0.6
	# Jetty, end grain, rope and bolts.
	draw_rect(Rect2(0,149,127,7), Color("a8774f"))
	draw_rect(Rect2(0,146,129,4), Color("d6b17c"))
	for x in range(9,129,18):
		draw_line(Vector2(x,147),Vector2(x-2,153),Color("805f48"),.8,true)
		draw_circle(Vector2(x+4,149),.7,Color("6d5948"))
	for x in [22,110]:
		draw_line(Vector2(x,152),Vector2(x+1,177),Color("775e49"),6,true)
		draw_line(Vector2(x-3,160),Vector2(x+4,158),Color("c1a779"),1.3,true)
	# Boots, tucked trousers, warm jacket, face and broad straw brim.
	draw_line(Vector2(86,136), Vector2(99,142), INK, 6, true)
	draw_line(Vector2(99,142), Vector2(106,154), INK, 5, true)
	draw_line(Vector2(103,154), Vector2(113,155), Color("75594a"), 5, true)
	draw_set_transform(Vector2(81,126+bob),-0.15)
	draw_colored_polygon(PackedVector2Array([Vector2(-9,-10),Vector2(7,-10),Vector2(12,15),Vector2(-10,13)]),Color("d88e57"))
	draw_line(Vector2(-5,-7),Vector2(-5,11),Color("edb572"),2,true)
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2(83,110+bob),9,Color("e9bd8b"))
	draw_circle(Vector2(90,110+bob),1, INK)
	draw_line(Vector2(77,106+bob),Vector2(81,119+bob),Color("6a5145"),3,true)
	draw_colored_polygon(PackedVector2Array([Vector2(68,105+bob),Vector2(76,97+bob),Vector2(88,98+bob),Vector2(97,106+bob)]),Color("e1b674"))
	draw_line(Vector2(65,106+bob),Vector2(100,108+bob),Color("f1cf8c"),4,true)
	draw_line(Vector2(76,102+bob),Vector2(90,103+bob),Color("97764f"),2,true)
	var hand = Vector2(105,123-kick*5+bob)
	draw_line(Vector2(87,121+bob), Vector2(94,128+bob),Color("c68152"),6,true)
	draw_line(Vector2(94,128+bob), hand,Color("eabf8e"),4,true)
	var rod = PackedVector2Array()
	for i in range(29):
		var t = i/28.0
		var x = lerpf(hand.x,180,t)
		var y = lerpf(hand.y,90+load_smooth*3-kick*7,t) - sin(t*PI)*21 + pow(t,3)*load_smooth*1.8
		rod.append(Vector2(x,y))
	draw_polyline(rod,Color("645446"),2.3,true)
	draw_polyline(rod,Color("b58e5f"),.8,true)
	draw_circle(hand,3,Color("ebc18e"))
	# A tiny tackle tin is decorative, no equipment system.
	draw_rect(Rect2(40,137,19,10),Color("557e76"))
	draw_line(Vector2(39,137),Vector2(60,137),Color("e0c18a"),2,true)

func _draw_line_and_hook() -> void:
	var y: float = rules.hook_y
	if rules.state == "result": y = 170
	var top = Vector2(180,90+load_smooth*4.8-kick*7)
	var line = PackedVector2Array()
	for i in range(33):
		var t = i/32.0
		var slack = sin(t*PI)*sin(visual_time*2.2)*2.0 if rules.state in ["ready","sinking","aiming"] else 0.0
		line.append(top.lerp(Vector2(180,y),t)+Vector2(slack,0))
	draw_polyline(line,Color(0.94,0.94,0.74,0.72),.85,true)
	var is_open = rules.state == "reeling" and rules.capture_left > 0 and rules.caught.size()<3
	if is_open:
		draw_circle(Vector2(180,y),11,Color(0.98,0.83,0.42,0.14))
		if not reduced_motion: draw_arc(Vector2(180,y),13,0,TAU,24,Color(1,0.87,0.52,0.7),1,true)
	var spread = 9.0 if is_open else 3.8
	var color = Color("ffe5a4") if is_open else Color("e1dec5")
	for side in [-1,1]:
		var shape = PackedVector2Array([Vector2(180,y-3),Vector2(180+side*2,y+5),Vector2(180+side*spread,y+4),Vector2(180+side*spread,y-2)])
		draw_polyline(shape,INK.darkened(.15),3.5,true)
		draw_polyline(shape,color,1.7,true)
	draw_circle(Vector2(180,y-4),2,color)
	if catch_flash > 0:
		draw_arc(Vector2(180,y), 12+(1-catch_flash)*12,0,TAU,24,Color(1,.91,.65,catch_flash),1,true)
	if debug_view:
		draw_circle(Vector2(180,y),9,Color(1,0.3,0.2,0.22))
		draw_line(Vector2(145,520),Vector2(215,520),Color("ffa273"),1,true)
		if is_open: draw_line(Vector2(180,y),Vector2(180,maxf(160,y-rules.capture_left*320)),Color("f7d26f"),4,true)

func _draw_fish(f: Dictionary, at: Vector2, attached: bool, slot: int) -> void:
	var kind = int(f.kind)
	var full_width = [45.0,67.0,55.0][kind]
	var full_height = [21.0,38.0,32.0][kind]
	var direction = 1.0 if float(f.vx)>=0 else -1.0
	var wiggle = sin(visual_time*([8.0,4.0,6.0][kind] if attached else 3.8)+int(f.id)*1.7)
	var angle = (0.35 if slot%2 == 0 else -0.35) + wiggle*.12 if attached else sin(visual_time*1.4+int(f.id))*.035
	if reduced_motion: angle *= .25; wiggle *= .4
	if attached: direction = 1.0 if slot%2 == 0 else -1.0
	draw_set_transform(at,angle,Vector2(direction,1))
	if fish_textures[kind]:
		var texture: Texture2D = fish_textures[kind]
		var region: Rect2 = fish_regions[kind]
		full_height = full_width * (region.size.y*texture.get_height()) / (region.size.x*texture.get_width())
		# A six-strip mesh gives body and tail phase lag; the right-side head stays stable.
		var verts = PackedVector2Array()
		var uvs = PackedVector2Array()
		for j in range(7):
			var u = j/6.0
			var deform = sin(visual_time*(14 if attached else 6)+u*2.5+int(f.id))*pow(1-u,2)*2.3
			if reduced_motion: deform *= .25
			verts.append(Vector2((u-.5)*full_width,-full_height*.5+deform)); uvs.append(region.position + Vector2(u,0)*region.size)
		for j in range(6,-1,-1):
			var u = j/6.0
			var deform = sin(visual_time*(14 if attached else 6)+u*2.5+int(f.id))*pow(1-u,2)*2.3
			if reduced_motion: deform *= .25
			verts.append(Vector2((u-.5)*full_width,full_height*.5+deform)); uvs.append(region.position + Vector2(u,1)*region.size)
		draw_polygon(verts,PackedColorArray([Color.WHITE]),uvs,texture)
	else:
		var body = [Color("a9d8bd"),Color("df9c5f"),Color("658faf")][kind]
		var tail = PackedVector2Array([Vector2(-full_width*.24,0),Vector2(-full_width*.53,-full_height*.38+wiggle*1.6),Vector2(-full_width*.44,0),Vector2(-full_width*.53,full_height*.38+wiggle*1.6)])
		draw_colored_polygon(tail,body.darkened(.12))
		draw_set_transform(at,angle,Vector2(direction,full_height/full_width))
		draw_circle(Vector2.ZERO,full_width*.37,body)
		draw_arc(Vector2(-full_width*.02,-full_width*.03),full_width*.29,PI*1.14,PI*1.8,20,body.lightened(.28),2,true)
		draw_set_transform(at,angle,Vector2(direction,1))
		draw_colored_polygon(PackedVector2Array([Vector2(-9,-full_height*.23),Vector2(-4,-full_height*.58),Vector2(9,-full_height*.26)]),body.darkened(.18))
		for i in range(3): draw_arc(Vector2(-10+i*6,0),3,PI*.35,PI*1.65,8,body.darkened(.13),.65,true)
		draw_arc(Vector2(full_width*.16,0),full_height*.24,-PI*.6,PI*.55,12,body.darkened(.25),.8,true)
		draw_circle(Vector2(full_width*.24,-full_height*.08),2.3,CREAM)
		draw_circle(Vector2(full_width*.25,-full_height*.09),1.3,INK)
		draw_circle(Vector2(full_width*.26,-full_height*.12),.5,Color.WHITE)
		if kind == 2:
			for i in range(3): draw_circle(Vector2(-10+i*6,-3+i%2*4),1.8,CREAM)
	draw_set_transform(Vector2.ZERO)
	if debug_view and not attached:
		draw_set_transform(at,0,Vector2(1,float(f.height)/float(f.width)))
		draw_arc(Vector2.ZERO,float(f.width)*.5,0,TAU,30,Color(1,.8,.3,.8),.7,true)
		draw_set_transform(Vector2.ZERO)
		draw_string(font,at+Vector2(-9,-15),str(f.id),HORIZONTAL_ALIGNMENT_LEFT,-1,9,CREAM)

func _save_settings() -> void:
	if test_mode or store_data==null: return
	var data={"version":2,"settings":{"muted":muted,"music":music_enabled,"haptics":haptics_enabled,"reduced_motion":reduced_motion,"language":language},"best":best,"rounds":rounds_completed,"streak":streak,"session_nonce":session_nonce,"committed_rounds":committed_rounds,"last_result":last_result,"snapshot":rules.export_snapshot()}
	if not store_data.save_state(data): screen_notice="Progress could not be saved. Check available storage."

func _load_settings() -> void:
	saved_data=store_data.load_state()
	var settings: Dictionary=saved_data.get("settings",{})
	muted=bool(settings.get("muted",false)); music_enabled=bool(settings.get("music",true)); haptics_enabled=bool(settings.get("haptics",true)); reduced_motion=bool(settings.get("reduced_motion",false))
	language=str(settings.get("language","zh" if OS.get_locale_language()=="zh" else "en"))
	if language not in ["zh","en"]: language="en"
	var records=saved_data.get("best",{})
	best={"A":clampi(int(records.get("A",0)),0,120),"B":clampi(int(records.get("B",0)),0,120)}
	rounds_completed=maxi(0,int(saved_data.get("rounds",0))); streak=maxi(0,int(saved_data.get("streak",0)))
	committed_rounds=saved_data.get("committed_rounds",[]) if saved_data.get("committed_rounds",[]) is Array else []
	last_result=saved_data.get("last_result",{}) if saved_data.get("last_result",{}) is Dictionary else {}
	if not last_result.is_empty():
		if not last_result.has_all(["count","score","fish"]) or not last_result.fish is Array or last_result.fish.size()>3: last_result={}
		elif int(last_result.count)<0 or int(last_result.count)>3 or int(last_result.score)<0 or int(last_result.score)>120: last_result={}
		else:
			for fish in last_result.fish:
				if not fish is Dictionary or not fish.has_all(["kind","vx","id"]): last_result={}; break

func _log_round(result: Dictionary) -> void:
	if not test_mode and store_data: store_data.append_round(result)

func _capture_preview() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/first-playable.png")
	preview_automation = false
	print("CAPTURE_SAVED res://captures/first-playable.png")

func _capture_action() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/first-catch.png")
	print("CAPTURE_SAVED res://captures/first-catch.png")

func _t(key: String) -> String:
	return Copy.get_text(key,language)

func _reset_cast() -> void:
	paused=false; restoring=false; pause_panel.visible=false
	rules.setup(rules.round_seed,selected_mode); last_result.clear(); particles.clear(); floats.clear()
	restore_countdown=.6; _apply_audio_state(); _save_settings(); _update_ui()

func _show_info(kind: String) -> void:
	info_return_pause=paused; paused=true; info_kind=kind
	pause_panel.visible=false; info_panel.visible=true
	info_title.text=_t("help_title" if kind=="help" else "credits_title")
	info_text.text=_t("help" if kind=="help" else "credits_body")
	if kind=="credits":
		info_text.text+="\n\n— GODOT ENGINE —\n"+Engine.get_license_text()
		for component in Engine.get_copyright_info():
			info_text.text+="\n\n"+str(component.get("name",""))
			for part in component.get("parts",[]):
				for copyright_line in part.get("copyright",[]): info_text.text+="\n"+str(copyright_line)
		for license_name in Engine.get_license_info(): info_text.text+="\n\n"+license_name+"\n"+Engine.get_license_info()[license_name]
	info_text.scroll_to_line(0); _apply_audio_state(); _update_ui()

func _close_info() -> void:
	info_panel.visible=false
	paused=info_return_pause; pause_panel.visible=paused
	if not paused: restore_countdown=.6
	_apply_audio_state(); _save_settings(); _update_ui()

func _start_music() -> void:
	var path="res://assets/audio/pond_music.wav"
	if not ResourceLoader.exists(path): return
	music_player=AudioStreamPlayer.new(); add_child(music_player)
	var stream=load(path).duplicate()
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD; stream.loop_begin=0; stream.loop_end=int(stream.get_length()*stream.mix_rate)
	music_player.stream=stream; music_player.volume_db=-15; music_player.play(); _apply_audio_state()

func _apply_audio_state() -> void:
	if music_player: music_player.stream_paused=paused or not music_enabled
	for player in voices:
		if paused: player.stop()

func _haptic(duration: int, amplitude: float) -> void:
	if not haptics_enabled or OS.get_name() not in ["iOS","Android"]: return
	var now=Time.get_ticks_msec()
	if now-last_haptic_ms<110: return
	last_haptic_ms=now; Input.vibrate_handheld(duration,amplitude)

func _qa_step(dt: float) -> void:
	if qa_finished: return
	if qa_cycles>=5:
		qa_finished=true; _finish_qa.call_deferred(); return
	qa_clock+=dt
	if qa_clock>.8 and rules.state=="ready" and not paused:
		_main_action()
	if rules.state=="sinking":
		for fish in rules.fish:
			if absf(fish.x-180)<fish.width*.5+5 and rules.hook_y>fish.y+8 and rules.hook_y-fish.y<95:
				_main_action(); break
	if qa_cycles>=3 and not qa_next_language:
		qa_next_language=true; language="en"; _update_ui()
	if qa_cycles>=5:
		qa_finished=true; _finish_qa.call_deferred()

func _finish_qa() -> void:
	await RenderingServer.frame_post_draw
	var root_path="res://captures/iterations" if OS.has_feature("editor") else "user://qa"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_path))
	get_viewport().get_texture().get_image().save_png(root_path.path_join("round-%d.png"%qa_round))
	var sorted=qa_frame_samples.duplicate(); sorted.sort()
	var sum=0.0
	for dt in sorted: sum+=dt
	var metrics={"iteration":qa_round,"platform":OS.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"cycles":qa_cycles,"elapsed_seconds":qa_clock,"render_frames":sorted.size(),"mean_frame_ms":1000*sum/maxi(1,sorted.size()),"p95_frame_ms":sorted[int(sorted.size()*.95)]*1000 if not sorted.is_empty() else 0,"engine_fps":Engine.get_frames_per_second(),"static_memory_bytes":OS.get_static_memory_usage(),"process_input_ms":qa_input_latency_ms,"physical_device":false,"notes":"Automated real rendered self-play; CPU input processing time is not end-to-end touch latency."}
	var file=FileAccess.open(root_path.path_join("round-%d.json"%qa_round),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(metrics,"\t")); file.close()
	print("QA_COMPLETE ",JSON.stringify(metrics))
	paused=true; _apply_audio_state()
