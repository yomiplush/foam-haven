extends RefCounted
## Derive a humanoid frame from positions, never from a guessed bone roll.

static func relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent is Node3D:
		result = parent.transform * result
		if parent == root:
			break
		parent = parent.get_parent()
	return result

static func body_frame(skeleton: Skeleton3D, bones: Dictionary) -> Basis:
	var left := skeleton.get_bone_global_rest(bones.LeftUpperArm).origin
	var right := skeleton.get_bone_global_rest(bones.RightUpperArm).origin
	var head := skeleton.get_bone_global_rest(bones.Head).origin
	var hips := skeleton.get_bone_global_rest(bones.Hips).origin
	var up := (head - hips).normalized()
	var lateral := (left - right).normalized()
	var forward := lateral.cross(up).normalized()
	return Basis(up.cross(forward).normalized(), up, forward).orthonormalized()

static func hand_frame(skeleton: Skeleton3D, bones: Dictionary, side: String, body: Basis) -> Dictionary:
	var rest := skeleton.get_bone_global_rest(bones[side + "Hand"])
	var middle: int = bones.get(side + "MiddleProximal", -1)
	var index: int = bones.get(side + "IndexProximal", -1)
	var little: int = bones.get(side + "LittleProximal", -1)
	var sign_side := 1.0 if side == "Left" else -1.0
	var forward := body.x * sign_side
	var dorsal := body.y
	var anchor := forward * 0.035
	if middle >= 0:
		var knuckle := skeleton.get_bone_global_rest(middle).origin
		forward = (knuckle - rest.origin).normalized()
		anchor = (knuckle - rest.origin) * 0.52
	elif index >= 0 and little >= 0:
		var knuckle := (skeleton.get_bone_global_rest(index).origin + skeleton.get_bone_global_rest(little).origin) * 0.5
		forward = (knuckle - rest.origin).normalized()
		anchor = (knuckle - rest.origin) * 0.52
	if index >= 0 and little >= 0:
		var across := skeleton.get_bone_global_rest(index).origin - skeleton.get_bone_global_rest(little).origin
		var candidate := across.cross(forward) * sign_side
		if candidate.length_squared() > 0.000001:
			dorsal = candidate.normalized()
	dorsal = (dorsal - forward * dorsal.dot(forward)).normalized()
	if dorsal.length_squared() < 0.5:
		dorsal = body.z.cross(forward).normalized() * sign_side
	var frame := Basis(forward.cross(dorsal).normalized(), dorsal, -forward).orthonormalized()
	var inverse := rest.basis.orthonormalized().inverse()
	return {"local_frame": inverse * frame, "palm_anchor": inverse * anchor}
