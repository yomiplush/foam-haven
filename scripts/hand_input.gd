extends RefCounted
## Optical hand tracking helpers. Pure math over world joint positions so the
## gesture rules can be unit-tested without a headset. Joint positions come
## from XRHandTracker joint transforms transformed into world space.

const J_WRIST := XRHandTracker.HAND_JOINT_WRIST
const J_PALM := XRHandTracker.HAND_JOINT_PALM
const J_THUMB_MCP := XRHandTracker.HAND_JOINT_THUMB_METACARPAL
const J_THUMB_PIP := XRHandTracker.HAND_JOINT_THUMB_PHALANX_PROXIMAL
const J_THUMB_DIP := XRHandTracker.HAND_JOINT_THUMB_PHALANX_DISTAL
const J_THUMB_TIP := XRHandTracker.HAND_JOINT_THUMB_TIP
const J_INDEX_MCP := XRHandTracker.HAND_JOINT_INDEX_FINGER_METACARPAL
const J_INDEX_PIP := XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_PROXIMAL
const J_INDEX_DIP := XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_DISTAL
const J_INDEX_TIP := XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP
const J_MIDDLE_MCP := XRHandTracker.HAND_JOINT_MIDDLE_FINGER_METACARPAL
const J_MIDDLE_TIP := XRHandTracker.HAND_JOINT_MIDDLE_FINGER_TIP
const J_RING_TIP := XRHandTracker.HAND_JOINT_RING_FINGER_TIP
const J_PINKY_TIP := XRHandTracker.HAND_JOINT_PINKY_FINGER_TIP

const FINGERS := [
	[XRHandTracker.HAND_JOINT_INDEX_FINGER_METACARPAL, XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_PROXIMAL, XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_INTERMEDIATE, XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_DISTAL, XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP],
	[XRHandTracker.HAND_JOINT_MIDDLE_FINGER_METACARPAL, XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_PROXIMAL, XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_INTERMEDIATE, XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_DISTAL, XRHandTracker.HAND_JOINT_MIDDLE_FINGER_TIP],
	[XRHandTracker.HAND_JOINT_RING_FINGER_METACARPAL, XRHandTracker.HAND_JOINT_RING_FINGER_PHALANX_PROXIMAL, XRHandTracker.HAND_JOINT_RING_FINGER_PHALANX_INTERMEDIATE, XRHandTracker.HAND_JOINT_RING_FINGER_PHALANX_DISTAL, XRHandTracker.HAND_JOINT_RING_FINGER_TIP],
	[XRHandTracker.HAND_JOINT_PINKY_FINGER_METACARPAL, XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_PROXIMAL, XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_INTERMEDIATE, XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_DISTAL, XRHandTracker.HAND_JOINT_PINKY_FINGER_TIP],
]
const THUMB := [J_THUMB_MCP, J_THUMB_PIP, J_THUMB_DIP, J_THUMB_TIP]

## Read the joints of one hand into a Dictionary of joint id -> world position.
## Returns an empty Dictionary when the hand tracker has no valid tracking data.
static func world_joints(origin: Node3D, tracker: XRHandTracker) -> Dictionary:
	var result := {}
	if tracker == null or not tracker.get_has_tracking_data():
		return result
	var to_world := origin.global_transform
	for finger in FINGERS:
		for joint in finger:
			result[joint] = to_world * tracker.get_hand_joint_transform(joint).origin
	for joint in THUMB:
		result[joint] = to_world * tracker.get_hand_joint_transform(joint).origin
	result[J_WRIST] = to_world * tracker.get_hand_joint_transform(J_WRIST).origin
	result[J_PALM] = to_world * tracker.get_hand_joint_transform(J_PALM).origin
	return result

## Chain length over the metacarpal-to-tip span: ~1.0 extended, larger when curled.
static func _fold_ratio(positions: Dictionary, joints: Array) -> float:
	var span := 0.0
	var bones := 0.0
	for i in range(1, joints.size()):
		var a: Vector3 = positions.get(joints[i - 1], Vector3.ZERO)
		var b: Vector3 = positions.get(joints[i], Vector3.ZERO)
		bones += a.distance_to(b)
	span = positions.get(joints[0], Vector3.ZERO).distance_to(positions.get(joints[joints.size() - 1], Vector3.ZERO))
	if span < 0.001:
		return 0.0
	return bones / span

## 0 = straight finger, 1 = fully folded. Extended fingers measure around 1.1,
## a loose fist reaches ~2.4, so the curve maps that band.
static func finger_curl(positions: Dictionary, finger: Array) -> float:
	var ratio := _fold_ratio(positions, finger)
	return clampf((ratio - 1.35) / 1.5, 0.0, 1.0)

## Thumb folds across the palm differently; a gentler curve is enough.
static func thumb_curl(positions: Dictionary) -> float:
	var ratio := _fold_ratio(positions, THUMB)
	return clampf((ratio - 1.18) / 1.3, 0.0, 1.0)

## 0 = thumb and index apart, 1 = tips touching.
static func pinch(positions: Dictionary) -> float:
	var distance: float = positions.get(J_THUMB_TIP, Vector3.ZERO).distance_to(positions.get(J_INDEX_TIP, Vector3.ZERO))
	if distance <= 0.012:
		return 1.0
	return clampf(1.0 - (distance - 0.012) / 0.05, 0.0, 1.0)

## Average fold of the four fingers; an open hand ~0, a fist ~1.
static func grasp(positions: Dictionary) -> float:
	var total := 0.0
	for finger in FINGERS:
		total += finger_curl(positions, finger)
	return total / float(FINGERS.size())

## Average fold of the middle, ring and little fingers (index excluded, so
## pointing with an extended index still reads near zero).
static func other_curl(positions: Dictionary) -> float:
	var total := 0.0
	for f in range(1, FINGERS.size()):
		total += finger_curl(positions, FINGERS[f])
	return total / float(FINGERS.size() - 1)

## Direction the hand is reaching: wrist toward the middle fingertip, which
## stays meaningful whether the index points or the hand makes a fist.
static func reach_dir(positions: Dictionary) -> Vector3:
	var from: Vector3 = positions.get(J_WRIST, Vector3.ZERO)
	var to: Vector3 = positions.get(J_MIDDLE_TIP, Vector3.ZERO)
	var dir := to - from
	if dir.length_squared() < 0.0001:
		dir = Vector3.FORWARD
	return dir.normalized()

## A point that represents "touching" the membrane: mostly the palm with a
## little reach toward the fingertips so an open hand registers on the shell.
static func touch_point(positions: Dictionary) -> Vector3:
	var palm: Vector3 = positions.get(J_PALM, Vector3.ZERO)
	var tip: Vector3 = positions.get(J_INDEX_TIP, palm)
	return palm.lerp(tip, 0.55) + reach_dir(positions) * 0.02

## Aim pose for menu rays: index fingertip origin with the finger pointing
## forward. Pinched hands fall back to the palm frame instead of stabbing.
static func aim_pose(positions: Dictionary) -> Dictionary:
	var index_mcp: Vector3 = positions.get(J_INDEX_MCP, Vector3.ZERO)
	var index_tip: Vector3 = positions.get(J_INDEX_TIP, index_mcp)
	var palm: Vector3 = positions.get(J_PALM, index_tip)
	var dir := index_tip - index_mcp
	if dir.length_squared() < 0.002:
		dir = reach_dir(positions)
	else:
		dir = dir.normalized()
	var origin := index_tip + dir * 0.04
	var up_hint: Vector3 = (positions.get(J_MIDDLE_TIP, palm) - positions.get(J_WRIST, palm)).normalized()
	if up_hint.length_squared() < 0.1:
		up_hint = Vector3.UP
	var right := dir.cross(up_hint).normalized()
	if right.length_squared() < 0.1:
		right = dir.cross(Vector3.UP).normalized()
	var back := -dir
	var up := right.cross(back)
	return {"origin": origin, "dir": dir, "basis": Basis(right, up, back)}

## Frame that drives the avatar's hand. The palm joint is the anchor; the
## orientation stays roll-free (roughly level with the world) so the hand mesh
## never spins, and -Z points along the reach so it behaves like a controller.
static func avatar_frame(positions: Dictionary) -> Transform3D:
	var palm: Vector3 = positions.get(J_PALM, Vector3.ZERO)
	var dir := reach_dir(positions)
	if dir.length_squared() < 0.001:
		dir = Vector3.FORWARD
	var back := -dir
	var up: Vector3 = Vector3.UP - back * back.dot(Vector3.UP)
	if up.length_squared() < 0.0001:
		up = Vector3.RIGHT - back * back.dot(Vector3.RIGHT)
	up = up.normalized()
	var x := up.cross(back)
	return Transform3D(Basis(x, up, back), palm)
