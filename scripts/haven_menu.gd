extends Node3D
## View-only menu. The experience owns state; the menu emits user intent.
## Every string is resolved through the I18n autoload and re-fit on language
## change so longer translations stay readable inside their pixel frames.
signal action_requested(action: StringName, index: int)
const Art = preload("res://scripts/destination_art.gd")
const PIXELS := Vector2(1280, 1000)
const SIZE := Vector2(1.36, 1.0625)
const INK := Color("fff1f6")
const MUTED := Color("cbb9d1")
const MINT := Color("f2c5d8")
const WORLD_KEYS := ["world_0", "world_1", "world_2", "world_3", "world_4", "world_5"]
const DESC_KEYS := ["desc_0", "desc_1", "desc_2", "desc_3", "desc_4", "desc_5"]
var viewport: SubViewport
var panel: Control
var main_page: Control
var help_page: Control
var lang_page: Control
var avatar_page: Control
var buttons: Array[Button] = []
var scene_buttons: Array[Button] = []
var options: Array[Button] = []
var badges: Array[Label] = []
var status: Label
var primary: Button
var hovered: Button
var avatar_note: Label
var avatar_current: Label
var avatar_entries: Array[Dictionary] = []
var avatar_rows: Array[Button] = []
var avatar_offset := 0
var mirror_buttons: Array[Button] = []
var lang_buttons: Array[Button] = []
var ribbon_button: Button
var expression_button: Button

func _ready():
	viewport = SubViewport.new()
	viewport.size = Vector2i(PIXELS)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input = true
	add_child(viewport)
	visibility_changed.connect(_sync_rendering)
	panel = Panel.new()
	panel.size = PIXELS
	panel.add_theme_stylebox_override("panel", style(Color("30263f"), Color("8d728f"), 32))
	_apply_theme()
	viewport.add_child(panel)
	_build_pages()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = viewport.get_texture()
	mat.no_depth_test = true
	mat.render_priority = 100
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var quad := QuadMesh.new()
	quad.size = SIZE
	var surface := MeshInstance3D.new()
	surface.mesh = quad
	surface.material_override = mat
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)
	I18n.language_changed.connect(func(_code): refresh_language())

func _apply_theme():
	var theme := Theme.new()
	theme.default_font = I18n.font()
	theme.default_font_size = 28
	panel.theme = theme

func world_name(index: int) -> String:
	return I18n.t(WORLD_KEYS[index])

func _clear_pages():
	for child in panel.get_children():
		panel.remove_child(child)
		child.free()
	buttons.clear()
	scene_buttons.clear()
	options.clear()
	badges.clear()
	mirror_buttons.clear()
	avatar_rows.clear()
	lang_buttons.clear()
	hovered = null

func _build_pages():
	_clear_pages()
	label(panel, "F O A M   H A V E N", Vector2(52, 38), 24, MINT)
	label(panel, I18n.t("brand_tag"), Vector2(52, 84), 40, INK)
	label(panel, I18n.t("tag_sub"), Vector2(54, 145), 24, MUTED)
	main_page = Control.new()
	panel.add_child(main_page)
	for i in 6:
		var card := button(main_page, "", Rect2(52 + (i % 3) * 399, 205 + (i / 3) * 155, 378, 145), &"travel", i)
		card.clip_contents = true
		var art := Art.new()
		art.destination = i
		art.position = Vector2(10, 10)
		art.size = Vector2(140, 125)
		card.add_child(art)
		label(card, I18n.t(WORLD_KEYS[i]), Vector2(164, 50), 24, INK)
		label(card, I18n.t(DESC_KEYS[i]), Vector2(164, 96), 17, MUTED)
		var badge := label(card, I18n.t("staying"), Vector2(267, 12), 22, Color("493149"))
		var bg := style(MINT, MINT, 9)
		bg.content_margin_left = 9
		bg.content_margin_right = 9
		badge.add_theme_stylebox_override("normal", bg)
		badges.append(badge)
		scene_buttons.append(card)
	label(main_page, I18n.t("how_to"), Vector2(54, 528), 25, MINT)
	for i in 4:
		var action: StringName = [&"mode", &"skin", &"drift", &"sound"][i]
		options.append(button(main_page, "", Rect2(52 + (i % 2) * 598, 580 + (i / 2) * 88, 578, 72), action))
	status = label(main_page, "", Vector2(54, 759), 25, MUTED)
	status.size = Vector2(1170, 40)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	primary = button(main_page, I18n.t("primary_enter"), Rect2(52, 808, 1176, 82), &"close")
	primary.add_theme_stylebox_override("normal", style(MINT, MINT, 18))
	primary.add_theme_stylebox_override("hover", style(Color("ffe1eb"), MINT, 18))
	primary.add_theme_color_override("font_color", Color("493149"))
	primary.add_theme_color_override("font_hover_color", Color("493149"))
	primary.add_theme_color_override("font_pressed_color", Color("493149"))
	button(main_page, I18n.t("btn_help"), Rect2(52, 916, 222, 54), &"help")
	mirror_buttons.append(button(main_page, I18n.t("btn_mirror_on"), Rect2(294, 916, 222, 54), &"mirror"))
	button(main_page, I18n.t("avatar_choose"), Rect2(536, 916, 368, 54), &"avatar_open")
	label(main_page, I18n.t("hint_menu"), Vector2(926, 933), 18, MUTED)
	button(main_page, I18n.t("btn_lang"), Rect2(1080, 38, 150, 52), &"lang_open")
	_make_avatar_page()
	_make_lang_page()
	_make_help()

func _make_help():
	help_page = Control.new()
	panel.add_child(help_page)
	help_page.visible = false
	var titles := [I18n.t("help_0"), I18n.t("help_1"), I18n.t("help_2"), I18n.t("help_3"), I18n.t("help_4")]
	var details := [I18n.t("helpd_0"), I18n.t("helpd_1"), I18n.t("helpd_2"), I18n.t("helpd_3"), I18n.t("helpd_4")]
	for i in 5:
		label(help_page, "0%d" % (i + 1), Vector2(58, 232 + i * 105), 28, MINT)
		label(help_page, titles[i], Vector2(140, 218 + i * 105), 32, INK)
		label(help_page, details[i], Vector2(140, 263 + i * 105), 26, MUTED)
	label(help_page, I18n.t("help_pc"), Vector2(58, 760), 24, MUTED)
	button(help_page, I18n.t("btn_back"), Rect2(52, 886, 1176, 80), &"help")

func _make_lang_page():
	lang_page = Control.new()
	panel.add_child(lang_page)
	lang_page.visible = false
	label(lang_page, I18n.t("lang_title"), Vector2(52, 90), 40, INK)
	for i in 6:
		var row := button(lang_page, I18n.t("lang_" + I18n.LANG_CODES[i]), Rect2(52, 200 + i * 88, 1176, 76), &"lang_select", i)
		if i == I18n.index():
			row.add_theme_stylebox_override("normal", style(Color("2b5058"), MINT, 18))
		lang_buttons.append(row)
	button(lang_page, I18n.t("btn_back"), Rect2(52, 886, 1176, 80), &"lang_back")

func style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	return box

func label(parent: Control, text: String, at: Vector2, font_size: int, color: Color) -> Label:
	var text_label := Label.new()
	text_label.text = text
	text_label.position = at
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.add_theme_font_size_override("font_size", font_size)
	text_label.add_theme_color_override("font_color", color)
	parent.add_child(text_label)
	_fit(text_label, font_size)
	return text_label

func button(parent: Control, text: String, rect: Rect2, action: StringName, index: int = -1) -> Button:
	var control := Button.new()
	control.text = text
	control.position = rect.position
	control.size = rect.size
	control.focus_mode = Control.FOCUS_NONE
	control.add_theme_stylebox_override("normal", style(Color("45334f"), Color("806a89"), 18))
	control.add_theme_stylebox_override("hover", style(Color("64465f"), MINT, 18))
	control.add_theme_stylebox_override("pressed", style(Color("795369"), MINT, 18))
	control.add_theme_color_override("font_color", INK)
	control.add_theme_color_override("font_hover_color", INK)
	control.set_meta("action", action)
	control.set_meta("index", index)
	parent.add_child(control)
	buttons.append(control)
	_fit(control, 28)
	return control

## Auto-fit: pick the largest font that keeps one line inside the control's box.
func _fit(control: Control, base_size: int):
	var text: String = control.text
	if text.is_empty():
		return
	if control.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return
	var available := 0.0
	if control is Button:
		available = control.size.x - 26.0
	else:
		var parent: Control = control.get_parent() if control.get_parent() is Control else null
		if parent != null and parent.size.x > 0.0:
			available = parent.size.x - control.position.x - 14.0
		else:
			available = PIXELS.x - control.position.x - 24.0
	available = maxf(available, 80.0)
	var font := I18n.font()
	var size := float(base_size)
	var min_size := maxf(9.0, float(base_size) * 0.45)
	while size > min_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > available:
		size -= 1.0
	if size < base_size:
		control.add_theme_font_size_override("font_size", int(size))

func update_state(index: int, balloon: bool, membrane: bool, drifting: bool, sound: bool):
	for i in scene_buttons.size():
		badges[i].visible = i == index
		scene_buttons[i].add_theme_stylebox_override("normal", style(Color("594056") if i == index else Color("45334f"), MINT if i == index else Color("806a89"), 18))
	_set_option(options[0], I18n.t("opt_wrap") + "  " + (I18n.t("mode_balloon") if balloon else I18n.t("mode_bubble")))
	_set_option(options[1], I18n.t("opt_membrane") + "  " + (I18n.t("on") if membrane else I18n.t("off")))
	_set_option(options[2], (I18n.t("mr_motion") + "  " + I18n.t("on" if drifting else "off")) if index == 5 else (I18n.t("opt_stop_drift") if drifting else I18n.t("opt_start_drift")))
	_set_option(options[3], I18n.t("opt_sound") + "  " + (I18n.t("on") if sound else I18n.t("off")))
	status.text = I18n.t("mr_status") if index == 5 else (world_name(index) + "   /   " + (I18n.t("drift_on") if drifting else I18n.t("drift_off")))
	primary.text = I18n.t("mr_enter") if index == 5 else I18n.t("primary_enter")
	_fit(primary, 28)

func update_mr_support(available: bool):
	if scene_buttons.size() < 6:
		return
	scene_buttons[5].disabled = not available
	scene_buttons[5].tooltip_text = "" if available else I18n.t("mr_unavailable")

func _set_option(control: Button, text: String):
	control.text = text
	_fit(control, 28)

func show_menu(open: bool):
	visible = open
	set_hover(null)

func _sync_rendering():
	# A hidden 1280x1000 menu was still issuing hundreds of 2D draws per frame.
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED

func set_hover(control: Button):
	if hovered == control:
		return
	if is_instance_valid(hovered):
		hovered.remove_theme_stylebox_override("normal")
		if hovered.has_meta("rest_style"):
			hovered.add_theme_stylebox_override("normal", hovered.get_meta("rest_style"))
			hovered.remove_meta("rest_style")
	hovered = control
	if is_instance_valid(hovered):
		hovered.set_meta("rest_style", hovered.get_theme_stylebox("normal"))
		hovered.add_theme_stylebox_override("normal", hovered.get_theme_stylebox("hover"))

func hit_test(pixel: Vector2) -> Button:
	for control in buttons:
		if control.is_visible_in_tree() and not control.disabled and control.get_global_rect().has_point(pixel):
			return control
	return null

func activate():
	if not is_instance_valid(hovered):
		return
	var action: StringName = hovered.get_meta("action")
	var index: int = hovered.get_meta("index")
	set_hover(null)
	match action:
		&"help":
			help_page.visible = not help_page.visible
			main_page.visible = not help_page.visible
			avatar_page.visible = false
			lang_page.visible = false
		&"lang_open":
			lang_page.visible = true
			main_page.visible = false
			help_page.visible = false
			avatar_page.visible = false
		&"lang_back":
			lang_page.visible = false
			main_page.visible = true
		&"lang_select":
			# I18n.set_lang emits language_changed -> refresh_language rebuilds pages.
			I18n.set_lang(I18n.LANG_CODES[index])
			action_requested.emit(&"lang_changed", index)
		&"avatar_back":
			avatar_page.visible = false
			main_page.visible = true
		&"avatar_prev", &"avatar_next":
			avatar_offset = clampi(avatar_offset + (-4 if action == &"avatar_prev" else 4), 0, maxi(0, ((avatar_entries.size() - 1) / 4) * 4))
			_refresh_avatar_rows()
		_:
			action_requested.emit(action, index)

func _after_language():
	# Rebuild pages, return to the world list, and let the owner refresh state.
	refresh_language()
	lang_page.visible = false
	main_page.visible = true
	help_page.visible = false
	avatar_page.visible = false

func refresh_language():
	if not is_instance_valid(panel):
		return
	_build_pages()
	avatar_entries.clear()
	avatar_offset = 0

func _make_avatar_page():
	avatar_page = Control.new()
	panel.add_child(avatar_page)
	avatar_page.visible = false
	avatar_current = label(avatar_page, I18n.t("avatar_title") + I18n.t("plush_hands"), Vector2(54, 210), 28, INK)
	avatar_current.size.x = 1170
	avatar_current.clip_text = true
	for i in 4:
		var row := button(avatar_page, "", Rect2(52, 263 + i * 86, 1176, 72), &"avatar_select", i)
		row.clip_text = true
		avatar_rows.append(row)
	button(avatar_page, I18n.t("btn_prev"), Rect2(52, 614, 166, 62), &"avatar_prev")
	button(avatar_page, I18n.t("btn_next"), Rect2(232, 614, 166, 62), &"avatar_next")
	button(avatar_page, I18n.t("btn_import"), Rect2(416, 614, 390, 62), &"avatar_import")
	button(avatar_page, I18n.t("btn_refresh"), Rect2(824, 614, 404, 62), &"avatar_refresh")
	button(avatar_page, I18n.t("btn_smaller"), Rect2(52, 690, 220, 62), &"avatar_smaller")
	button(avatar_page, I18n.t("btn_calibrate"), Rect2(290, 690, 700, 62), &"avatar_calibrate")
	button(avatar_page, I18n.t("btn_larger"), Rect2(1008, 690, 220, 62), &"avatar_larger")
	mirror_buttons.append(button(avatar_page, I18n.t("btn_mirror_on"), Rect2(52, 766, 282, 62), &"mirror"))
	button(avatar_page, I18n.t("btn_recenter"), Rect2(350, 766, 282, 62), &"avatar_recenter")
	ribbon_button = button(avatar_page, "", Rect2(648, 766, 282, 62), &"ribbons")
	expression_button = button(avatar_page, "", Rect2(946, 766, 282, 62), &"expression")
	avatar_note = label(avatar_page, I18n.t("avatar_note_default"), Vector2(54, 838), 20, MUTED)
	avatar_note.size = Vector2(1170, 43)
	avatar_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(avatar_page, I18n.t("credit_sample"), Vector2(54, 976), 14, MUTED)
	button(avatar_page, I18n.t("btn_back"), Rect2(52, 886, 1176, 80), &"avatar_back")

func update_avatar_tools(mirror_on: bool, ribbons_on: bool = true, expression_on: bool = true):
	for control in mirror_buttons:
		control.text = I18n.t("btn_mirror_off") if mirror_on else I18n.t("btn_mirror_on")
		_fit(control, 28)
	_set_option(ribbon_button, I18n.t("ribbons") + " " + I18n.t("on" if ribbons_on else "off"))
	_set_option(expression_button, I18n.t("expression") + " " + I18n.t("on" if expression_on else "off"))

func show_avatars(entries: Array[Dictionary], current: String, note: String = ""):
	set_hover(null)
	avatar_entries = entries
	avatar_offset = 0
	avatar_page.visible = true
	main_page.visible = false
	help_page.visible = false
	lang_page.visible = false
	avatar_current.text = I18n.t("avatar_title") + current
	avatar_note.text = note if not note.is_empty() else I18n.t("avatar_note_drag")
	_refresh_avatar_rows()

func _refresh_avatar_rows():
	set_hover(null)
	for i in avatar_rows.size():
		var index := avatar_offset + i
		avatar_rows[i].visible = index < avatar_entries.size()
		if index < avatar_entries.size():
			avatar_rows[i].text = avatar_entries[index].name
			avatar_rows[i].set_meta("index", index)
