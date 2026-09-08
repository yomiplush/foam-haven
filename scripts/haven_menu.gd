extends Node3D
## View-only menu. The experience owns state; the menu emits user intent.
signal action_requested(action: StringName, index: int)
const Art = preload("res://scripts/destination_art.gd")
const PIXELS := Vector2(1280, 1000)
const SIZE := Vector2(1.36, 1.0625)
const NAMES := ["青い海", "夕焼けの空", "風船の部屋", "ぬいぐるみ部屋", "お菓子の国"]
const DESCRIPTIONS := ["波音と、ゆらめく光。", "雲の上で、ひと休み。", "風船に囲まれて。", "おもちゃと、ぬくもり。", "甘い夢に、包まれて。"]
const INK := Color("f4ede1")
const MUTED := Color("9bb4b5")
const MINT := Color("c1e4d1")
var viewport: SubViewport
var panel: Control
var main_page: Control
var help_page: Control
var buttons: Array[Button] = []
var scene_buttons: Array[Button] = []
var options: Array[Button] = []
var badges: Array[Label] = []
var status: Label
var primary: Button
var hovered: Button
var avatar_page: Control
var avatar_note: Label
var avatar_current: Label
var avatar_entries: Array[Dictionary] = []
var avatar_rows: Array[Button] = []
var avatar_offset := 0
var mirror_buttons: Array[Button] = []
var sitting_button: Button

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
	panel.add_theme_stylebox_override("panel", style(Color("122d38"), Color("49646a"), 32))
	var theme := Theme.new()
	theme.default_font = preload("res://assets/japanese.ttf")
	theme.default_font_size = 28
	panel.theme = theme
	viewport.add_child(panel)
	label(panel, "F O A M   H A V E N", Vector2(52, 38), 24, MINT)
	label(panel, "ぬいぐるみの私、泡の中。", Vector2(52, 84), 46, INK)
	label(panel, "やわらかな手で、二重の膜にふれる。", Vector2(54, 151), 26, MUTED)
	main_page = Control.new()
	panel.add_child(main_page)
	for i in 5:
		var card := button(main_page, "", Rect2(52 + (i % 3) * 399, 205 + (i / 3) * 155, 378, 145), &"travel", i)
		card.clip_contents = true
		var art := Art.new()
		art.destination = i
		art.position = Vector2(10, 10)
		art.size = Vector2(140, 125)
		card.add_child(art)
		label(card, NAMES[i], Vector2(164, 50), 24, INK)
		label(card, DESCRIPTIONS[i], Vector2(164, 96), 17, MUTED)
		var badge := label(card, "滞在中", Vector2(267, 12), 22, Color("123c3a"))
		var bg := style(MINT, MINT, 9)
		bg.content_margin_left = 9
		bg.content_margin_right = 9
		badge.add_theme_stylebox_override("normal", bg)
		badges.append(badge)
		scene_buttons.append(card)
	label(main_page, "あなたの過ごし方", Vector2(54, 528), 25, MINT)
	for i in 4:
		var action: StringName = [&"mode", &"skin", &"drift", &"sound"][i]
		options.append(button(main_page, "", Rect2(52 + (i % 2) * 598, 580 + (i / 2) * 88, 578, 72), action))
	status = label(main_page, "", Vector2(54, 759), 25, MUTED)
	primary = button(main_page, "この景色で、くつろぐ    →", Rect2(52, 808, 1176, 82), &"close")
	primary.add_theme_stylebox_override("normal", style(MINT, MINT, 18))
	primary.add_theme_stylebox_override("hover", style(Color("d9f2e3"), MINT, 18))
	primary.add_theme_color_override("font_color", Color("163b3b"))
	primary.add_theme_color_override("font_hover_color", Color("163b3b"))
	primary.add_theme_color_override("font_pressed_color", Color("163b3b"))
	button(main_page, "操作ガイド", Rect2(52, 916, 222, 54), &"help")
	mirror_buttons.append(button(main_page, "鏡を出す", Rect2(294,916,222,54), &"mirror"))
	label(main_page, "B / Y でいつでもメニューへ。", Vector2(548,927), 23, MUTED)
	var avatar_card := button(main_page, "自分の姿を選ぶ    →", Rect2(850, 360, 378, 145), &"avatar_open")
	avatar_card.add_theme_font_size_override("font_size", 26)
	_make_avatar_page()
	_make_help()
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

func _make_help():
	help_page = Control.new()
	panel.add_child(help_page)
	help_page.visible = false
	var titles := ["膜に触れる", "小さな泡をつくる", "浮遊する・止まる", "メニューを開く", "包む泡の位置を戻す"]
	var details := ["手を近づける / グリップを長押し", "トリガーを押す", "A / X を押す。最初は静止しています。", "B / Y を押す。浮遊も止まります。", "スティックを押し込む"]
	for i in 5:
		label(help_page, "0%d" % (i + 1), Vector2(58, 232 + i * 105), 28, MINT)
		label(help_page, titles[i], Vector2(140, 218 + i * 105), 32, INK)
		label(help_page, details[i], Vector2(140, 263 + i * 105), 26, MUTED)
	label(help_page, "左スティック：泡の中をそっと移動、端でぽにょん。\nPC：WASD 移動 / P で膜 / 右ドラッグで見回す\n1〜5 で景色 / Space で浮遊 / M でメニュー", Vector2(58, 760), 24, MUTED)
	button(help_page, "←    景色を選ぶ", Rect2(52, 886, 1176, 80), &"help")

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
	return text_label

func button(parent: Control, text: String, rect: Rect2, action: StringName, index: int = -1) -> Button:
	var control := Button.new()
	control.text = text
	control.position = rect.position
	control.size = rect.size
	control.focus_mode = Control.FOCUS_NONE
	control.add_theme_stylebox_override("normal", style(Color("1b3944"), Color("48616a"), 18))
	control.add_theme_stylebox_override("hover", style(Color("2b5058"), MINT, 18))
	control.add_theme_stylebox_override("pressed", style(Color("365c60"), MINT, 18))
	control.add_theme_color_override("font_color", INK)
	control.add_theme_color_override("font_hover_color", INK)
	control.set_meta("action", action)
	control.set_meta("index", index)
	parent.add_child(control)
	buttons.append(control)
	return control

func update_state(index: int, balloon: bool, membrane: bool, drifting: bool, sound: bool):
	for i in scene_buttons.size():
		badges[i].visible = i == index
		scene_buttons[i].add_theme_stylebox_override("normal", style(Color("1b3944"), MINT if i == index else Color("48616a"), 18))
	options[0].text = "包むもの    " + ("風船" if balloon else "虹色の泡")
	options[1].text = "膜の表示    " + ("ON" if membrane else "OFF")
	options[2].text = "浮遊を止める" if drifting else "ゆっくり浮遊する    →"
	options[3].text = "音    " + ("ON" if sound else "OFF")
	status.text = NAMES[index] + "   /   " + ("ゆっくり浮遊しています" if drifting else "静止しています")

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
		if control.is_visible_in_tree() and control.get_global_rect().has_point(pixel):
			return control
	return null

func activate():
	if not is_instance_valid(hovered):
		return
	var action: StringName = hovered.get_meta("action")
	var index: int = hovered.get_meta("index")
	set_hover(null)
	if action == &"help":
		main_page.visible = not main_page.visible
		help_page.visible = not main_page.visible
		avatar_page.visible = false
	elif action == &"avatar_back":
		avatar_page.visible = false
		main_page.visible = true
	elif action == &"avatar_prev" or action == &"avatar_next":
		avatar_offset = clampi(avatar_offset + (-4 if action == &"avatar_prev" else 4), 0, maxi(0, ((avatar_entries.size() - 1) / 4) * 4))
		_refresh_avatar_rows()
	else:
		action_requested.emit(action, index)

func _make_avatar_page():
	avatar_page = Control.new()
	panel.add_child(avatar_page)
	avatar_page.visible = false
	avatar_current = label(avatar_page, "自分の姿：ぬいぐるみの手", Vector2(54, 210), 28, INK)
	avatar_current.size.x = 1170
	avatar_current.clip_text = true
	for i in 4:
		var row := button(avatar_page, "", Rect2(52, 263 + i * 86, 1176, 72), &"avatar_select", i)
		row.clip_text = true
		avatar_rows.append(row)
	button(avatar_page, "← 前", Rect2(52, 614, 166, 62), &"avatar_prev")
	button(avatar_page, "次 →", Rect2(232, 614, 166, 62), &"avatar_next")
	button(avatar_page, "VRMを追加", Rect2(416, 614, 390, 62), &"avatar_import")
	button(avatar_page, "一覧を更新", Rect2(824, 614, 404, 62), &"avatar_refresh")
	button(avatar_page, "小さく", Rect2(52, 690, 220, 62), &"avatar_smaller")
	button(avatar_page, "腕を広げて体格を合わせる", Rect2(290, 690, 700, 62), &"avatar_calibrate")
	button(avatar_page, "大きく", Rect2(1008, 690, 220, 62), &"avatar_larger")
	mirror_buttons.append(button(avatar_page, "鏡を出す", Rect2(52,766,370,62), &"mirror"))
	sitting_button = button(avatar_page, "女の子座り", Rect2(440,766,388,62), &"avatar_sitting")
	button(avatar_page, "目線と正面を合わせる", Rect2(846,766,382,62), &"avatar_recenter")
	avatar_note = label(avatar_page, "VRMを追加して、自分の姿で過ごせます。", Vector2(54, 838), 20, MUTED)
	avatar_note.size = Vector2(1170, 43)
	avatar_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(avatar_page, "サンプル：Godette / SirRichard94・Lyuma / CC BY 3.0", Vector2(54, 976), 14, MUTED)
	button(avatar_page, "←    景色を選ぶ", Rect2(52, 886, 1176, 80), &"avatar_back")

func update_avatar_tools(mirror_on: bool, sitting_style: int):
	for button in mirror_buttons:
		button.text = "鏡をしまう" if mirror_on else "鏡を出す"
	sitting_button.text = "座り方：女の子座り" if sitting_style == 1 else "座り方：足を前に"

func show_avatars(entries: Array[Dictionary], current: String, note: String = ""):
	set_hover(null)
	avatar_entries = entries
	avatar_offset = 0
	avatar_page.visible = true
	main_page.visible = false
	help_page.visible = false
	avatar_current.text = "自分の姿：" + current
	avatar_note.text = note if not note.is_empty() else "VRMを追加して選択。PCではVRMを画面へドラッグしても追加できます。"
	_refresh_avatar_rows()

func _refresh_avatar_rows():
	set_hover(null)
	for i in avatar_rows.size():
		var index := avatar_offset + i
		avatar_rows[i].visible = index < avatar_entries.size()
		if index < avatar_entries.size():
			avatar_rows[i].text = avatar_entries[index].name
			avatar_rows[i].set_meta("index", index)
