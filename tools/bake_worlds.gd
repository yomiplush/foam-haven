extends SceneTree
## Run after editing authored world geometry. Keeps expensive mesh construction
## out of the headset's frame loop and preserves shared resources/float animation.
const Worlds = preload("res://scripts/worlds.gd")

func _initialize():
	call_deferred("bake")

func assign_owners(node: Node, owner_node: Node):
	for child in node.get_children():
		child.owner = owner_node
		assign_owners(child, owner_node)

func bake():
	DirAccess.make_dir_recursive_absolute("res://assets/worlds")
	var factory := Worlds.new()
	for index in 5:
		var world: Node3D = factory.build(index, false)
		root.add_child(world)
		var floaters: Array[Dictionary] = []
		for motion in factory.animated:
			var data: Dictionary = motion.duplicate()
			data.path = world.get_path_to(motion.node)
			data.erase("node")
			floaters.append(data)
		world.set_meta("floaters", floaters)
		world.set_meta("animated_materials", factory.materials.duplicate())
		assign_owners(world, world)
		var packed := PackedScene.new()
		if packed.pack(world) != OK:
			quit(1)
			return
		var result := ResourceSaver.save(packed, "res://assets/worlds/world_%d.scn" % index, ResourceSaver.FLAG_COMPRESS)
		if result != OK:
			quit(1)
			return
		world.free()
		print("FOAM_BAKED: ", index)
	quit()
