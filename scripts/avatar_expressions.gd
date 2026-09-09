extends RefCounted
## Resolve standardized VRM expression bindings once. Models without them work too.
var bindings: Dictionary = {}
var blink_time := 0.0
var next_blink := 3.4
var clock := 0.0
var rng := RandomNumberGenerator.new()

func clear():
	bindings.clear()
	clock = 0.0
	blink_time = 0.0

func configure(model: Node3D):
	clear()
	rng.randomize()
	for player: AnimationPlayer in model.find_children("*", "AnimationPlayer", true, false):
		var root := player.get_node(player.root_node)
		for animation_name in player.get_animation_list():
			var key := String(animation_name).get_slice("/", String(animation_name).get_slice_count("/")-1).to_lower()
			if key not in ["blink", "happy", "relaxed"] or bindings.has(key):
				continue
			var animation := player.get_animation(animation_name)
			var tracks: Array[Dictionary] = []
			for track in animation.get_track_count():
				if animation.track_get_type(track) != Animation.TYPE_BLEND_SHAPE or animation.track_get_key_count(track) == 0:
					continue
				var path := animation.track_get_path(track)
				var mesh := root.get_node_or_null(NodePath(path.get_concatenated_names())) as MeshInstance3D
				if mesh == null or mesh.mesh == null:
					continue
				var shape_name := path.get_concatenated_subnames()
				var shape := mesh.find_blend_shape_by_name(shape_name)
				if shape < 0:
					continue
				tracks.append({"mesh": mesh, "shape": shape, "weight": float(animation.track_get_key_value(track, 0))})
			bindings[key] = tracks

func step(delta: float, gentle: bool):
	clock += delta
	var blink := 0.0
	if clock >= next_blink:
		blink_time += delta
		# Quick close, softer open. Random spacing avoids a metronomic stare.
		blink = sin(clampf(blink_time / 0.22, 0.0, 1.0) * PI)
		if blink_time >= 0.22:
			blink_time = 0.0
			next_blink = clock + rng.randf_range(2.8, 6.2)
	var values: Dictionary = {}
	for key in bindings:
		var amount := blink if key == "blink" else ((0.12 if key == "happy" else 0.18) * (1.0 - blink) if gentle else 0.0)
		for track in bindings[key]:
			var id := "%d:%d" % [track.mesh.get_instance_id(), track.shape]
			if not values.has(id):
				values[id] = {"mesh": track.mesh, "shape": track.shape, "value": 0.0}
			values[id].value += track.weight * amount
	for value in values.values():
		value.mesh.set_blend_shape_value(value.shape, clampf(value.value, 0.0, 0.999))
