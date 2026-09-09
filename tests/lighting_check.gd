extends "res://scripts/haven.gd"

func _smoke_test():
	camera.position = Vector3(0,0.82,0)
	camera.rotation_degrees.x = -7
	_switch_world(3)
	menu_open = false
	menu.hide()
	_update_ui()
	sun.shadow_enabled = false
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dist/lighting_no_shadow.png")
	bubble.hide()
	outer_bubble.hide()
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dist/lighting_no_membrane.png")
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	sun.light_energy = 0.38
	environment.ambient_light_energy = 0.34
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dist/lighting_soft.png")
	print("LIGHTING_CHECK_OK: draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " triangles=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	await _finish_checks()
