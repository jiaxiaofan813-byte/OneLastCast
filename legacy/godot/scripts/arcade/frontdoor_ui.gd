extends Control
## Standalone modal shell. The owner persists settings and pauses gameplay.
signal start_requested
signal resume_requested
signal catalog_requested
signal settings_changed(key: String, value: Variant)
signal title_requested

const INK = Color("173f4a")
const CREAM = Color("fff3d8")
const TEAL = Color("216b70")
const GOLD = Color("ffd36c")
const DEFAULTS = {"music_enabled": true, "music_volume": 0.4, "sfx_volume": 0.85, "haptics_enabled": true, "reduced_motion": false, "language": "en"}
var blocking := false
var page := "closed"
var settings: Dictionary = DEFAULTS.duplicate()
var _font: Font
var _content: Control
var _return_page := "title"
var _can_resume := false
var _opening_time := 0.0
var _first_focus: Control
var _cover: Texture2D
var _opening_art: TextureRect

func setup(ui_font: Font, values: Dictionary = {}) -> void:
	_font = ui_font
	for key in DEFAULTS:
		if values.has(key):
			settings[key] = _setting_value(key, values[key])
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	if _font: add_theme_font_override("font", _font)
	var cover_path := "res://assets/ui/cover/cover.png"
	if ResourceLoader.exists(cover_path): _cover = load(cover_path)
	elif FileAccess.file_exists(cover_path):
		var cover_image := Image.load_from_file(cover_path)
		if cover_image: _cover = ImageTexture.create_from_image(cover_image)
	close()

func _normalize_language(value: Variant) -> String:
	return "zh" if str(value).strip_edges().to_lower() == "zh" else "en"

func _setting_value(key: String, value: Variant) -> Variant:
	if key == "language": return _normalize_language(value)
	return clampf(float(value), 0.0, 1.0) if key.ends_with("volume") else bool(value)

func _t(chinese: String, english: String) -> String:
	return chinese if settings.language == "zh" else english

## Rebuild text without changing the run, navigation origin, or opening timer.
## The owner can call this when loading a saved preference; it does not emit a change.
func set_language(language: String) -> void:
	var next := _normalize_language(language)
	if settings.language == next: return
	settings.language = next
	match page:
		"title": show_title(_can_resume)
		"pause": show_pause()
		"settings": show_settings(_return_page)
		"credits": show_credits(_return_page)
		"confirm_new": _confirm_new_day()
		"opening": _show_opening()

func get_return_page() -> String:
	return _return_page

func show_title(can_resume: bool = false) -> void:
	_can_resume = can_resume
	_begin("title")
	var hero := TextureRect.new()
	hero.position = Vector2.ZERO
	hero.size = Vector2(360, 640)
	hero.texture = _cover
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(hero)
	# Legible brand plate, independent of the artwork's contrast.
	var plate := Panel.new()
	plate.position = Vector2(20, 88)
	plate.size = Vector2(320, 103)
	plate.add_theme_stylebox_override("panel", _box(Color.TRANSPARENT, 18))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(plate)
	_label(plate, _t("ONE LAST CAST", "JUST ONE MORE. PROMISE."), Vector2(14, 8), Vector2(292, 22), 16, TEAL)
	_label(plate, _t("最后一竿", "ONE LAST CAST"), Vector2(14, 28), Vector2(292, 48), 36 if settings.language == "zh" else 30)
	_label(plate, _t("再钓一竿。上次也是这么说的。", "You said that three fish ago."), Vector2(8, 77), Vector2(304, 22), 13)
	var card := _panel(Vector2(16, 382), Vector2(328, 252 if can_resume else 242))
	_label(card, _t("鱼不一定来，快乐先到。", "The fish are ignoring your calendar."), Vector2(12, 13), Vector2(304, 28), 16 if settings.language == "zh" else 14)
	_button(card, _t("继续这一天", "Keep Fishing") if can_resume else _t("开钓，最后一竿", "One Last Cast"), Vector2(16, 50), Vector2(296, 52), _resume if can_resume else _start, true)
	if can_resume:
		_button(card, _t("重新开钓 · 开始新一天", "Start a New Day"), Vector2(16, 106), Vector2(296, 44), _confirm_new_day)
		_button(card, _t("鱼册", "Fish Log"), Vector2(16, 154), Vector2(94, 44), func(): catalog_requested.emit())
		_button(card, _t("设置", "Settings"), Vector2(116, 154), Vector2(94, 44), func(): show_settings("title"))
		_button(card, _t("致谢", "Credits"), Vector2(216, 154), Vector2(96, 44), func(): show_credits("title"))
	else:
		_button(card, _t("鱼册", "Fish Log"), Vector2(16, 116), Vector2(94, 48), func(): catalog_requested.emit())
		_button(card, _t("设置", "Settings"), Vector2(116, 116), Vector2(94, 48), func(): show_settings("title"))
		_button(card, _t("致谢", "Credits"), Vector2(216, 116), Vector2(96, 48), func(): show_credits("title"))
	var tutorial_height := maxf(34.0, _font.get_height(12) * 2.0)
	var instruction := _label(card, _t("点一下下扎 · 圈重合再点 · 自动续投", "Tap to dive. Tap again when rings meet.\nAutomatic recast. Your next fish is waiting."), Vector2(8, (202 if can_resume else 192) - (tutorial_height - 34)), Vector2(312, tutorial_height), 12)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.add_theme_constant_override("line_spacing", 0)
	# Reset after typography changes: Label keeps its earlier, larger minimum size.
	instruction.size = Vector2(312, tutorial_height)
	instruction.set_meta("cover_tutorial", true)
	_focus_first()

func show_pause() -> void:
	_begin("pause")
	var card := _panel(Vector2(22, 134), Vector2(316, 380))
	_label(card, _t("鱼先等等", "The Fish Can Wait"), Vector2(16, 20), Vector2(284, 46), 30 if settings.language == "zh" else 28)
	_label(card, _t("你休息，鱼也假装很忙。", "They were ignoring you anyway."), Vector2(12, 70), Vector2(292, 26), 15)
	_button(card, _t("继续钓鱼", "Keep Fishing"), Vector2(20, 114), Vector2(276, 50), _resume, true)
	_button(card, _t("查看鱼册", "Fish Log"), Vector2(20, 176), Vector2(276, 46), func(): catalog_requested.emit())
	_button(card, _t("设置", "Settings"), Vector2(20, 234), Vector2(276, 46), func(): show_settings("pause"))
	_button(card, _t("回到封面", "Back to Title"), Vector2(20, 292), Vector2(276, 46), func():
		title_requested.emit())
	_focus_first()

func show_settings(return_page: String = "title") -> void:
	_return_page = return_page if return_page in ["title", "pause"] else "title"
	_begin("settings")
	var card := _panel(Vector2(16, 36), Vector2(328, 568))
	var heading_height := maxf(40.0, _font.get_height(28))
	_label(card, _t("调好再下竿", "Tackle the Settings"), Vector2(12, 14 - (heading_height - 40) * .5), Vector2(304, heading_height), 28)
	_label(card, _t("声音小一点，鱼不会更好骗。", "Quieter music won't fool the fish."), Vector2(10, 57), Vector2(308, 25), 14)
	var english := _button(card, "English", Vector2(18, 94), Vector2(142, 44), func(): _set_setting("language", "en"), settings.language == "en")
	english.accessibility_name = "Language: English"
	english.accessibility_description = "Selected" if settings.language == "en" else "Switch to English"
	var chinese := _button(card, "中文", Vector2(168, 94), Vector2(142, 44), func(): _set_setting("language", "zh"), settings.language == "zh")
	chinese.accessibility_name = "语言：中文"
	chinese.accessibility_description = "已选择" if settings.language == "zh" else "切换为中文"
	_toggle(card, _t("背景音乐", "Background Music"), "music_enabled", 146)
	_slider(card, _t("音乐音量", "Music Volume"), "music_volume", 198)
	_slider(card, _t("音效音量", "Sound Effects"), "sfx_volume", 270)
	_toggle(card, _t("触觉反馈", "Haptic Feedback"), "haptics_enabled", 346)
	_label(card, _t("需设备支持；不影响钓鱼操作。", "Haptics need a supported device."), Vector2(10, 394), Vector2(308, 23), 12)
	_toggle(card, _t("减少动态效果", "Reduce Motion"), "reduced_motion", 420)
	_button(card, _t("完成 · 返回", "Done"), Vector2(18, 490), Vector2(292, 50), _back, true)
	_focus_first()

func show_credits(return_page: String = "title") -> void:
	_return_page = return_page if return_page in ["title", "pause"] else "title"
	_begin("credits")
	var card := _panel(Vector2(16, 30), Vector2(328, 580))
	_label(card, _t("鸣谢与制作", "Credits"), Vector2(12, 16), Vector2(304, 42), 28)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 76)
	scroll.size = Vector2(288, 416)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	var body := Label.new()
	body.custom_minimum_size.x = 272
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_color_override("font_color", INK)
	body.text = _t("最后一竿 · ONE LAST CAST\n私人预览版\n\n游戏引擎\nGodot 4.7.2 · MIT 许可\n许可全文随项目附带。\n\n鱼类与画面\n20 种鱼采用项目原创 SVG / PNG，参考官方鱼类形态资料；未使用外部鱼类照片素材。\n\n声音\n原创程序音效。背景音乐：LakesideArcade、LakesideArcade-2，由用户提供。商业发行授权尚未核实。\n\n字体\n手机字体：Noto Sans SC，SIL 开放字体许可 1.1。版权与许可全文随包附带。\n\n特别鸣谢\n每一位说着“最后一竿”、又坐回去的人。\n也谢谢鱼：虽然它们并未同意出镜。", "ONE LAST CAST\nPrivate preview\n\nENGINE\nGodot 4.7.2 · MIT License\nFull license included with the project.\n\nFISH & ART\n20 fish illustrated as original project SVG / PNG artwork, with anatomy informed by official fish references. No external fish photos were used.\n\nSOUND\nOriginal procedural sound effects. Music: LakesideArcade and LakesideArcade-2, supplied by the user. Commercial release rights have not been verified.\n\nFONT\nMobile font: Noto Sans SC, SIL Open Font License 1.1. Copyright and full license are included.\n\nSPECIAL THANKS\nTo everyone who said “one last cast” and sat back down.\nAnd to the fish, who never signed a release.")
	scroll.add_child(body)
	_button(card, _t("返回", "Back"), Vector2(18, 510), Vector2(292, 50), _back, true)
	_focus_first()

func close() -> void:
	blocking = false
	page = "closed"
	_opening_time = 0.0
	hide()
	set_process(false)

func _begin(next_page: String) -> void:
	if is_instance_valid(_content):
		remove_child(_content)
		_content.queue_free()
	_content = Control.new()
	_content.size = Vector2(360, 640)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_first_focus = null
	page = next_page
	blocking = true
	show()
	set_process(next_page == "opening")
	queue_redraw()

func _panel(at: Vector2, dimensions: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = dimensions
	panel.add_theme_stylebox_override("panel", _box(CREAM, 24))
	_content.add_child(panel)
	return panel

func _box(color: Color, radius: int, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(width)
	style.border_color = border
	return style

func _label(parent: Control, text: String, at: Vector2, dimensions: Vector2, font_size: int = 16, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Control, text: String, at: Vector2, dimensions: Vector2, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.accessibility_name = text
	button.position = at
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", CREAM if primary else INK)
	button.add_theme_color_override("font_focus_color", CREAM if primary else INK)
	button.add_theme_color_override("font_hover_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", Color("547078"))
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_stylebox_override("normal", _box(TEAL if primary else Color("f4dfb5"), 13))
	button.add_theme_stylebox_override("hover", _box(GOLD, 13))
	button.add_theme_stylebox_override("pressed", _box(Color("e9b650"), 13))
	button.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, 13, Color("e77f48"), 3))
	button.pressed.connect(action)
	parent.add_child(button)
	if _first_focus == null: _first_focus = button
	return button

func _toggle(parent: Control, text: String, key: String, y: float) -> void:
	var button := _button(parent, _toggle_text(text, bool(settings[key])), Vector2(18, y), Vector2(292, 46), func(): pass)
	button.pressed.connect(func():
		_set_setting(key, not bool(settings[key]))
		button.text = _toggle_text(text, bool(settings[key]))
		button.accessibility_name = button.text)

func _toggle_text(text: String, enabled: bool) -> String:
	return text + _t("：开" if enabled else "：关", ": On" if enabled else ": Off")

func _slider(parent: Control, text: String, key: String, y: float) -> void:
	var label := _label(parent, text + "  %d%%" % roundi(settings[key] * 100), Vector2(18, y), Vector2(292, 24), 16)
	var slider := HSlider.new()
	slider.position = Vector2(24, y + 26)
	slider.size = Vector2(280, 44)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = settings[key]
	slider.accessibility_name = label.text
	slider.accessibility_description = _t("使用方向键调节音量。", "Use the arrow keys to adjust the volume.")
	slider.focus_mode = Control.FOCUS_ALL
	slider.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, 8, Color("e77f48"), 3))
	slider.value_changed.connect(func(value: float):
		_set_setting(key, value)
		label.text = text + "  %d%%" % roundi(value * 100)
		slider.accessibility_name = label.text)
	parent.add_child(slider)

func _set_setting(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key): return
	if key == "language":
		set_language(_normalize_language(value))
	else:
		settings[key] = _setting_value(key, value)
	settings_changed.emit(key, settings[key])

func _focus_first() -> void:
	_apply_focus.call_deferred()

func _apply_focus() -> void:
	if blocking and is_instance_valid(_first_focus) and _first_focus.is_inside_tree():
		_first_focus.grab_focus()

func _back() -> void:
	if _return_page == "pause": show_pause()
	else: show_title(_can_resume)

func _resume() -> void:
	close()
	resume_requested.emit()

func _confirm_new_day() -> void:
	_begin("confirm_new")
	var card := _panel(Vector2(22, 180), Vector2(316, 280))
	_label(card, _t("重新开钓？", "Start a New Day?"), Vector2(16, 20), Vector2(284, 42), 28)
	_label(card, _t("本局进度会结束，鱼册仍然保留。", "This day ends. Your Fish Log stays."), Vector2(8, 78), Vector2(300, 30), 15)
	_button(card, _t("继续当前这一天", "Keep Fishing"), Vector2(20, 130), Vector2(276, 48), func(): show_title(true), true)
	_button(card, _t("开始新一天", "Start a New Day"), Vector2(20, 190), Vector2(276, 48), _start)
	_focus_first()

func _start() -> void:
	_opening_time = 0.0
	_show_opening()

func _show_opening() -> void:
	_begin("opening")
	if _cover:
		_opening_art = TextureRect.new()
		_opening_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_opening_art.stretch_mode = TextureRect.STRETCH_SCALE
		_opening_art.texture = _cover
		_opening_art.size = Vector2(360, 640)
		_opening_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(_opening_art)
	var caption := Panel.new()
	caption.position = Vector2(14, 400)
	caption.size = Vector2(332, 108)
	caption.add_theme_stylebox_override("panel", _box(Color("153f4a"), 18))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(caption)
	_label(_content, _t("船已就位，借口请留岸上。", "Boat ready. Excuses stay ashore."), Vector2(10, 410), Vector2(340, 40), 22 if settings.language == "zh" else 20, CREAM)
	_label(_content, _t("轻点或按空格跳过", "Tap or press Space to skip"), Vector2(10, 468), Vector2(340, 28), 14, CREAM)
	if settings.reduced_motion: _finish_opening.call_deferred()

func _finish_opening() -> void:
	if page != "opening": return
	close()
	start_requested.emit()

func _process(delta: float) -> void:
	if page != "opening": return
	_opening_time += delta
	if is_instance_valid(_opening_art):
		var travel := clampf(_opening_time / 0.75, 0.0, 1.0)
		_opening_art.scale = Vector2.ONE * (1.0 + travel * 0.035)
		_opening_art.position = Vector2(-6.3, -10) * travel
		_opening_art.modulate.a = 1.0 - maxf(0.0, travel - 0.6) * 1.2
	queue_redraw()
	if _opening_time >= 0.75: _finish_opening()

func _input(event: InputEvent) -> void:
	if not blocking: return
	if page == "opening":
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]):
			_finish_opening()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if page in ["settings", "credits"]: _back()
		elif page == "confirm_new": show_title(true)
		elif page == "pause": _resume()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if not blocking: return
	draw_rect(Rect2(Vector2.ZERO, size.max(Vector2(360, 640))), Color("153f4a"))
	if page == "title" and _cover == null:
		draw_circle(Vector2(270, 190), 66, Color("f5b96a"))
		for i in range(5): draw_line(Vector2(0, 270 + i * 22), Vector2(360, 240 + i * 22), Color("367c80"), 12)
	elif page == "opening" and _cover == null:
		var t := clampf(_opening_time / 0.75, 0.0, 1.0)
		draw_circle(Vector2(278, 180), 45, GOLD)
		for i in range(5): draw_line(Vector2(0, 300 + i * 21), Vector2(360, 300 + i * 21), Color("367c80"), 2)
		var x := lerpf(55, 265, t)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 30, 282), Vector2(x + 30, 282), Vector2(x + 18, 302), Vector2(x - 18, 302)]), CREAM)
		draw_circle(Vector2(x, 264), 9, GOLD)
		draw_line(Vector2(x, 273), Vector2(x, 283), CREAM, 5)
		draw_line(Vector2(x + 5, 278), Vector2(x + 37, 241), GOLD, 3)
