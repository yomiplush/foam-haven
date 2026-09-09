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
	out[HandInput.J_WRIST] = Vector3(0, 0, -0.03)
	out[HandInput.J_PALM] = Vector3(0, 0, 0.02)
	for fi in HandInput.FINGERS.size():
		var x := -0.024 + 0.016 * float(fi)
		for j in HandInput.FINGERS[fi].size():
			out[HandInput.FINGERS[fi][j]] = Vector3(x, 0.0, 0.05 + float(j) * 0.04)
	for j in HandInput.THUMB.size():
		var x := 0.03
		out[HandInput.THUMB[j]] = Vector3(x * (1.0 - 0.2 * j), 0.0, 0.02 + float(j) * 0.03)
	return out

func rolled_hand(base: Dictionary, angle: float) -> Dictionary:
	var out := base.duplicate()
	var palm: Vector3 = base[HandInput.J_PALM]
	var reach: Vector3 = (base[HandInput.J_MIDDLE_MCP] - base[HandInput.J_WRIST]).normalized()
	var spin := Quaternion(reach, angle)
	for key in out:
		out[key] = palm + spin * (out[key] - palm)
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
	var frame := HandInput.avatar_frame(extended)
	var reach := HandInput.reach_dir(extended)
	check(frame.basis.z.dot(-reach) > 0.95, "avatar hand points along the reach")
	check(frame.origin.distance_to(extended[HandInput.J_PALM]) < 0.001, "avatar hand sits on the palm joint")
	check(absf(frame.basis.determinant() - 1.0) < 0.001, "avatar frame stays a right-handed rotation")
	# Rotating the wrist must roll the avatar hand with it, not freeze it.
	var twisted := rolled_hand(extended, deg_to_rad(70.0))
	var twisted_frame := HandInput.avatar_frame(twisted)
	var roll := rad_to_deg(frame.basis.y.angle_to(twisted_frame.basis.y))
	check(roll > 40.0, "wrist roll is followed by the avatar hand")
	check(roll < 90.0, "dorsal stays on the back of the hand while rolling")
	check(absf(twisted_frame.basis.determinant() - 1.0) < 0.001, "rolled frame stays right-handed")
	await get_tree().process_frame
	if not failed:
		print("HAND_CHECK_OK: grasp, pinch, aim basis, reach, touch point, avatar roll")
	get_tree().quit(1 if failed else 0)
