extends Control
## Small, static illustrations; no extra 3D views or per-frame drawing cost.
var destination := 0

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func oval(center: Vector2, radius: Vector2, color: Color):
	var points := PackedVector2Array()
	for i in 48:
		var angle := TAU * i / 48.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)

func _draw():
	var w := size.x
	var h := size.y
	var tops := [Color("123b50"), Color("656b91"), Color("b6a0b5"), Color("a8889f"), Color("c3a4dd"), Color("887b9d")]
	var bottoms := [Color("287d86"), Color("e7baa7"), Color("e7c9b5"), Color("f3d8bd"), Color("ffdbe6"), Color("d7c3d8")]
	for y in int(h):
		draw_line(Vector2(0, y), Vector2(w, y), tops[destination].lerp(bottoms[destination], y / h))
	match destination:
		0:
			for i in 3:
				var x := w * (0.22 + i * 0.27)
				var y := h * (0.44 - sin(i * 2.0) * 0.16)
				var r := 22.0 - i * 3.0
				for j in 4:
					var points := PackedVector2Array()
					for k in 12:
						points.append(Vector2(x + (j - 1.5) * 8 + sin(k * 0.45 + j) * 3, y + k * 3))
					draw_polyline(points, Color("94d9d2"), 1.4, true)
				oval(Vector2(x, y), Vector2(r, r * 0.5), Color("a2dcd5"))
				oval(Vector2(x - 4, y - 3), Vector2(r * 0.55, r * 0.19), Color("d3ede1"))
			for i in 18:
				draw_circle(Vector2(fposmod(i * 71.0, w), fposmod(i * 37.0, h)), 1.0, Color(0.8, 0.95, 0.9, 0.4))
		1:
			draw_circle(Vector2(w * 0.76, h * 0.32), 23, Color("ffe1b6"), true, -1, true)
			for i in 9:
				oval(Vector2(i * w / 7.0 - 20, h * 0.9 + sin(i * 1.9) * 13), Vector2(48, 23), Color("f2d9ce"))
			oval(Vector2(w * 0.33, h * 0.38), Vector2(20, 25), Color("e9b1af"))
			draw_line(Vector2(w * 0.33 - 8, h * 0.38 + 20), Vector2(w * 0.33 - 5, h * 0.38 + 35), Color("e4c3b3"), 1.5)
			draw_line(Vector2(w * 0.33 + 8, h * 0.38 + 20), Vector2(w * 0.33 + 5, h * 0.38 + 35), Color("e4c3b3"), 1.5)
			draw_rect(Rect2(w * 0.33 - 6, h * 0.38 + 33, 12, 8), Color("ad817c"))
		2:
			draw_style_box(_arch(), Rect2(w * 0.34, 14, w * 0.32, h + 10))
			draw_line(Vector2(w * 0.5, 18), Vector2(w * 0.5, h), Color("f9ebdd"), 3, true)
			for i in 4:
				var p := Vector2(w * (0.19 + i * 0.21), h * (0.39 + sin(i * 2) * 0.19))
				draw_line(p, p + Vector2(5, 75), Color("f7e6db"), 1, true)
				oval(p, Vector2(17, 22), [Color("e9abc0"), Color("b7d5ce"), Color("d5b8df"), Color("f0d29e")][i])
				oval(p + Vector2(-5, -7), Vector2(3, 6), Color(1, 1, 1, 0.4))

		3:
			for i in 3:
				var p := Vector2(w * (0.2 + i * 0.3), h * 0.55)
				var c: Color = [Color("cc997a"), Color("f1dbbe"), Color("dab0c6")][i]
				oval(p + Vector2(0, 30), Vector2(27, 31), c)
				oval(p + Vector2(-17, -20), Vector2(12, 14 + i * 5), c)
				oval(p + Vector2(17, -20), Vector2(12, 14 + i * 5), c)
				oval(p, Vector2(26, 23), c)
				for side in [-1, 1]:
					draw_circle(p + Vector2(side * 9, -2), 2.2, Color("634b48"))
				oval(p + Vector2(0, 8), Vector2(10, 7), Color("fae8d3"))
				draw_circle(p + Vector2(0, 5), 2.6, Color("634b48"))

		4:
			for i in 7:
				oval(Vector2(i * w / 6, h * 0.90), Vector2(25, 15), Color("fff1eb"))
			for tier in 3:
				var rect := Rect2(w * 0.5 - 45 + tier * 10, h * 0.75 - tier * 24, 90 - tier * 20, 26)
				draw_style_box(_arch(), rect)
				draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color("efaacb"), 6)
			oval(Vector2(w * 0.5, h * 0.75 - 65), Vector2(10, 12), Color("e67fa6"))
		5:
			draw_rect(Rect2(12, 12, w-24, h-24), Color("e8dbe9"), false, 1.5)
			draw_line(Vector2(12,h-12), Vector2(w*0.35,h*0.65), Color("e8dbe9"), 1.5, true)
			draw_line(Vector2(w-12,h-12), Vector2(w*0.70,h*0.65), Color("e8dbe9"), 1.5, true)
			for i in 3:
				var p := Vector2(w * (0.25 + i*0.27), h * (0.35 + sin(i*2.0)*0.15))
				draw_line(p, p+Vector2(-3,48), Color("fff0e4"), 1.3, true)
				oval(p, Vector2(16,20), [Color("f8abc8"),Color("e0b7f3"),Color("fff1df")][i])
				oval(p+Vector2(-5,-7), Vector2(3,6), Color(1,1,1,0.7))

func _arch() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("eee3d9")
	style.set_corner_radius_all(48)
	return style
