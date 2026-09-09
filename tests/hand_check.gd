extends Node
## Headset-free sanity checks for the hand gesture math.
const HandInput = preload("res://scripts/hand_input.gd")
var failed := false

func check(ok: bool, message: String):
	if not ok:
		failed = true
		printerr("HAND_CHECK_FAILED: ", message)

func build_hand() -> Dictionary:
	var out := {}
	out[HandInput.J_WRIST] = Vector3.ZERO
	out[HandInput.J_PALM] = Vector3(0, 0.0, 0.06)
	for finger in HandInput.FINGERS:
		for i in finger.size():
			out[finger[i]] = Vector3(0.0, 0.0, 0.06 + float(i) * 0.04)
	for i in HandInput.THUMB.size():
		out[HandInput.THUMB[i]] = Vector3(0.015, -0.02 + float(i) * 0.005, 0.02 + float(i) * 0.04)
	return out

func fist_hand() -> Dictionary:
	var out := build_hand()
	for finger in HandInput.FINGERS:
		var mcp: Vector3 = out[finger[0]]
		var inward := Vector3(0, -0.4, -0.9).normalized()
		for i in range(1, finger.size()):
			var t := float(i) / float(finger.size() - 1)
			out[finger[i]] = mcp + inward * (0.10 - t * 0.085) + Vector3(sin(t * 5.0) * 0.012, 0.0, 0.0)
	return out

func _ready():
	call_deferred("run")

func run():
	var extended := build_hand()
	var fist := fist_hand()
	check(HandInput.grasp(extended) < 0.35, "open hand reads as no grasp")
	check(HandInput.grasp(fist) > 0.6, "fist reads as grasp")
	check(HandInput.pinch(extended) < 0.1, "open hand has no pinch")
	var pinched := extended.duplicate()
	pinched[HandInput.J_THUMB_TIP] = extended[HandInput.J_INDEX_TIP]
	check(HandInput.pinch(pinched) > 0.9, "touching thumb/index reads as pinch")
	var aim := HandInput.aim_pose(extended)
	check(absf(aim.dir.length() - 1.0) < 0.01, "aim direction is unit length")
	check(aim.basis.z.dot(-aim.dir) > 0.99, "aim basis points forward along dir")
	check(HandInput.reach_dir(fist).length() > 0.5, "reach direction remains stable for a fist")
	check(HandInput.touch_point(extended).distance_to(extended[HandInput.J_PALM]) < 0.2, "touch point stays near the palm")
	await get_tree().process_frame
	if not failed:
		print("HAND_CHECK_OK: grasp, pinch, aim basis, reach, touch point")
	get_tree().quit(1 if failed else 0)
