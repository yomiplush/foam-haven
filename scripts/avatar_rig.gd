extends Node3D
## The avatar follows tracking; this node never writes to the XR camera or origin.
const Loader = preload("res://scripts/vrm_loader.gd")
const Anatomy = preload("res://scripts/avatar_anatomy.gd")
var model: Node3D
var skeleton: Skeleton3D
var bones: Dictionary = {}
var rest_eye := Vector3.ZERO
var eye_from_head := Vector3.ZERO
var body_yaw := 0.0
var calibrated := false
var size_multiplier := 1.0
var current_path := ""
var display_name := ""
var last_error := ""
var rest_body_basis := Basis.IDENTITY
var skeleton_body_basis := Basis.IDENTITY
var head_local_frame := Basis.IDENTITY
var hand_anatomy: Array[Dictionary] = []
var fitted_eye_height := 1.55
var last_calibration_note := ""

func _ready():
	display_name = I18n.t("plush_hands")

func is_loaded() -> bool:
	return is_instance_valid(model)

func load_avatar(path: String) -> bool:
	last_error = ""
	var result := Loader.load_model(path)
	if result.has("error"):
		last_error = result.error
		return false
	var candidate: Node3D = result.model
	var candidate_skeleton: Skeleton3D = candidate.find_child("GeneralSkeleton", true, false)
	if candidate_skeleton == null:
		candidate.free()
		last_error = I18n.t("err_humanoid_missing")
		return false
	var mapping: BoneMap = candidate.vrm_meta.humanoid_bone_mapping
	var mapped: Dictionary = {}
	for human in ["Hips", "Head", "LeftEye", "RightEye", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftMiddleProximal", "LeftIndexProximal", "LeftLittleProximal", "RightMiddleProximal", "RightIndexProximal", "RightLittleProximal"]:
		var bone_name: String = mapping.get_skeleton_bone_name(human) if mapping != null else human
		var index := candidate_skeleton.find_bone(bone_name)
		if index < 0:
			index = candidate_skeleton.find_bone(human)
		mapped[human] = index
	for required in ["Hips", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand"]:
		if mapped[required] < 0:
			candidate.free()
			last_error = I18n.tf("err_limbs_missing", [required])
			return false
	var candidate_eye := candidate_skeleton.get_bone_global_rest(mapped.Head).origin + Vector3(0, 0.075, 0.065)
	if mapped.LeftEye >= 0 and mapped.RightEye >= 0:
		candidate_eye = (candidate_skeleton.get_bone_global_rest(mapped.LeftEye).origin + candidate_skeleton.get_bone_global_rest(mapped.RightEye).origin) * 0.5
	var relative := Anatomy.relative_transform(candidate_skeleton, candidate)
	var local_eye := relative * candidate_eye
	if not local_eye.is_finite() or local_eye.y < 0.1 or local_eye.y > 10.0:
		candidate.free()
		last_error = I18n.t("err_height")
		return false
	# All validation precedes replacement, so a bad file cannot remove a good avatar.
	unload_avatar()
	model = candidate
	skeleton = candidate_skeleton
	bones = mapped
	rest_eye = local_eye
	skeleton_body_basis = Anatomy.body_frame(skeleton, bones)
	rest_body_basis = (relative.basis.orthonormalized() * skeleton_body_basis).orthonormalized()
	head_local_frame = skeleton.get_bone_global_rest(bones.Head).basis.orthonormalized().inverse() * skeleton_body_basis
	hand_anatomy.clear()
	for side in ["Left", "Right"]:
		hand_anatomy.append(Anatomy.hand_frame(skeleton, bones, side, skeleton_body_basis))
	eye_from_head = skeleton.get_bone_global_rest(bones.Head).affine_inverse() * candidate_eye
	current_path = path
	display_name = model.vrm_meta.title if not model.vrm_meta.title.is_empty() else path.get_file().get_basename()
	add_child(model)
	calibrated = false
	print("FOAM_VRM_LOADED: ", display_name, " version=", result.version, " bones=", skeleton.get_bone_count())
	return true

func unload_avatar():
	if is_instance_valid(model):
		remove_child(model)
		model.queue_free()
	model = null
	skeleton = null
	bones.clear()
	current_path = ""
	display_name = I18n.t("plush_hands")
	calibrated = false
	hand_anatomy.clear()

func calibrate(head: Transform3D):
	if not is_loaded():
		return
	# Sitting does not shrink a person to the current floor-to-eye distance.
	var normalized_scale := clampf(fitted_eye_height / rest_eye.y, 0.15, 5.0) * size_multiplier
	scale = Vector3.ONE * normalized_scale
	body_yaw = atan2(-head.basis.z.x, -head.basis.z.z)
	calibrated = true
	last_calibration_note = I18n.t("note_cal_done")

func fit_to_arms(head: Transform3D, hands: Array[Transform3D], tracked: Array[bool]) -> bool:
	if not is_loaded() or hands.size() != 2 or tracked.size() != 2 or not tracked[0] or not tracked[1]:
		last_calibration_note = I18n.t("note_need_controllers")
		return false
	var span := hands[0].origin.distance_to(hands[1].origin)
	var right := head.basis.x
	var spread := hands[1].origin - hands[0].origin
	var vertical := absf(hands[0].origin.y - hands[1].origin.y)
	var below := head.origin.y - (hands[0].origin.y + hands[1].origin.y) * 0.5
	if span < 0.75 or vertical > 0.16 or spread.normalized().dot(right) < 0.85 or below < 0.08 or below > 0.55:
		last_calibration_note = I18n.t("note_raise_arms")
		return false
	var rest_left: Vector3 = skeleton.get_bone_global_rest(bones.LeftHand) * hand_anatomy[0].palm_anchor
	var rest_right: Vector3 = skeleton.get_bone_global_rest(bones.RightHand) * hand_anatomy[1].palm_anchor
	var relative := Anatomy.relative_transform(skeleton, model)
	var rest_span: float = (relative * rest_left).distance_to(relative * rest_right)
	var fitted := span / maxf(rest_span, 0.1)
	var eye_height := rest_eye.y * fitted
	if eye_height < 0.85 or eye_height > 2.2:
		last_calibration_note = I18n.t("note_fit_failed")
		return false
	fitted_eye_height = eye_height
	size_multiplier = 1.0
	calibrate(head)
	last_calibration_note = I18n.t("note_fit_done")
	print("FOAM_CALIBRATED: palm_span=", snappedf(span,0.001), " eye_height=", snappedf(fitted_eye_height,0.001))
	return true

func hand_world_frame(hand: int) -> Transform3D:
	var pose := skeleton.global_transform * skeleton.get_bone_global_pose(bones["LeftHand" if hand == 0 else "RightHand"])
	return Transform3D(pose.basis.orthonormalized() * hand_anatomy[hand].local_frame, pose * hand_anatomy[hand].palm_anchor)

func update_pose(head: Transform3D, hands: Array[Transform3D], tracked: Array[bool], delta: float):
	if not is_loaded():
		return
	if not calibrated:
		calibrate(head)
	var forward := -head.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.001:
		var wanted := atan2(forward.x, forward.z)
		# VRChat-style torso: the body drifts toward the gaze with a soft lag.
		# Brief glances stay in the neck; a held turn lets the shoulders catch
		# up, and they settle back as the head returns. No hard threshold snap.
		var diff := wrapf(wanted - body_yaw, -PI, PI)
		var magnitude := absf(diff)
		if magnitude > deg_to_rad(6.0):
			var rate := 0.9 + 3.2 * clampf(magnitude / deg_to_rad(70.0), 0.0, 1.0)
			body_yaw = lerp_angle(body_yaw, wanted, 1.0 - exp(-delta * rate))
	var body_scale := clampf(fitted_eye_height / rest_eye.y, 0.15, 5.0) * size_multiplier
	basis = (Basis(Vector3.UP, body_yaw) * rest_body_basis.inverse()).scaled(Vector3.ONE * body_scale)
	global_position = head.origin - global_basis * rest_eye
	skeleton.reset_bone_poses()
	var inv := skeleton.global_transform.affine_inverse()
	var head_pose := skeleton.get_bone_global_pose(bones.Head)
	head_pose.basis = (skeleton.global_basis.orthonormalized().inverse() * head.basis * Basis(Vector3.UP, PI) * head_local_frame.inverse()).orthonormalized()
	head_pose.origin = inv * head.origin - head_pose.basis * eye_from_head
	skeleton.set_bone_global_pose(bones.Head, head_pose)
	for i in 2:
		var side := "Left" if i == 0 else "Right"
		var sign_side := 1.0 if i == 0 else -1.0
		var target := Transform3D.IDENTITY
		if tracked[i]:
			target = hands[i]
		else:
			target.origin = global_transform * (rest_eye + Vector3(sign_side * 0.22, -0.43, 0.26))
			target.basis = global_basis.orthonormalized() * Basis(Vector3.UP, PI)
		var hand_id: int = bones[side + "Hand"]
		var hand_basis: Basis = (skeleton.global_basis.orthonormalized().inverse() * target.basis.orthonormalized() * hand_anatomy[i].local_frame.inverse()).orthonormalized()
		# The controller lies in the palm, not at the wrist joint.
		var wrist_target: Vector3 = inv * target.origin - hand_basis * hand_anatomy[i].palm_anchor
		var pole := skeleton_body_basis * Vector3(sign_side * 0.60, -0.75, -0.20)
		_solve_limb(bones[side + "UpperArm"], bones[side + "LowerArm"], hand_id, wrist_target, pole)
		_distribute_forearm_twist(bones[side + "LowerArm"], hand_id, hand_basis, hand_anatomy[i].local_frame.y)
		var hand_pose := skeleton.get_bone_global_pose(hand_id)
		hand_pose.basis = hand_basis
		skeleton.set_bone_global_pose(hand_id, hand_pose)
		# Always keep the knees together, feet tucked girl-style.
		var foot: int = bones[side + "Foot"]
		if foot >= 0 and bones[side + "UpperLeg"] >= 0 and bones[side + "LowerLeg"] >= 0:
			_pose_leg(side, sign_side, inv)

func _distribute_forearm_twist(lower: int, hand: int, desired: Basis, dorsal_local: Vector3):
	var elbow := skeleton.get_bone_global_pose(lower)
	var wrist := skeleton.get_bone_global_pose(hand)
	var axis := (wrist.origin - elbow.origin).normalized()
	var current := wrist.basis * dorsal_local
	var target := desired * dorsal_local
	current -= axis * axis.dot(current)
	target -= axis * axis.dot(target)
	if current.length_squared() < 0.01 or target.length_squared() < 0.01:
		return
	var twist := current.normalized().signed_angle_to(target.normalized(), axis)
	elbow.basis = Basis(axis, clampf(twist, -PI*0.7, PI*0.7) * 0.65) * elbow.basis
	skeleton.set_bone_global_pose(lower, elbow)

func _pose_leg(side: String, sign_side: float, inv: Transform3D):
	# Always the "girl sit": knees forward and together, feet folded back so
	# the soles rest beside the hips. Sitting is fixed, whatever the eye height.
	var upper: int = bones[side + "UpperLeg"]
	var lower: int = bones[side + "LowerLeg"]
	var foot: int = bones[side + "Foot"]
	var forward := Basis(Vector3.UP, body_yaw).z
	var left := Basis(Vector3.UP, body_yaw).x
	var up := Basis(Vector3.UP, body_yaw).y
	var hip_world := skeleton.to_global(skeleton.get_bone_global_pose(upper).origin)
	var s := size_multiplier
	# Feet stay anchored to the hips so a height change cannot pop the legs.
	var knee_world := hip_world + forward * 0.22 * s - up * 0.02 * s
	var foot_world := hip_world + forward * 0.04 * s + left * sign_side * 0.085 * s - up * 0.06 * s
	_solve_limb(upper, lower, foot, inv * foot_world, inv * knee_world)
	var pose := skeleton.get_bone_global_pose(foot)
	var rest := skeleton.get_bone_global_rest(foot)
	var desired := Basis.looking_at(forward, Vector3.UP)
	var rest_frame := rest.basis.orthonormalized().inverse() * skeleton_body_basis
	pose.basis = (skeleton.global_basis.orthonormalized().inverse() * desired * rest_frame.inverse()).orthonormalized()
	skeleton.set_bone_global_pose(foot, pose)

func _solve_limb(upper: int, lower: int, tip: int, target: Vector3, pole: Vector3):
	var a := skeleton.get_bone_global_pose(upper)
	var b := skeleton.get_bone_global_pose(lower)
	var c := skeleton.get_bone_global_pose(tip)
	var first := a.origin.distance_to(b.origin)
	var second := b.origin.distance_to(c.origin)
	if first < 0.001 or second < 0.001:
		return
	var offset := target - a.origin
	if offset.length_squared() < 0.000001:
		offset = Vector3(0, -0.01, 0.01)
	var direction := offset.normalized()
	var distance := clampf(offset.length(), absf(first - second) + 0.001, first + second - 0.001)
	var bend := pole - direction * pole.dot(direction)
	if bend.length_squared() < 0.0001:
		bend = direction.cross(Vector3.RIGHT if absf(direction.x) < 0.9 else Vector3.UP)
	bend = bend.normalized()
	var along := (first * first - second * second + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0, first * first - along * along))
	var elbow := a.origin + direction * along + bend * height
	var reach := a.origin + direction * distance
	a.basis = Basis(Quaternion((b.origin - a.origin).normalized(), (elbow - a.origin).normalized())) * a.basis
	skeleton.set_bone_global_pose(upper, a)
	b = skeleton.get_bone_global_pose(lower)
	c = skeleton.get_bone_global_pose(tip)
	b.basis = Basis(Quaternion((c.origin - b.origin).normalized(), (reach - b.origin).normalized())) * b.basis
	skeleton.set_bone_global_pose(lower, b)
