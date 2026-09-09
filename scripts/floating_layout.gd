extends RefCounted
## Keep the tracked camera untouched. Position authored scenery below the cocoon.
const INNER_AXES := Vector3(0.76, 0.91, 0.76)
const OUTER_AXES := INNER_AXES + Vector3.ONE * 0.075
const FLOOR_CLEARANCE := 0.38
const MAX_DEFORMATION := 0.27

static func shell_basis(time: float) -> Basis:
	# Tilt belongs to the membrane, never to the horizon or tracked head.
	return Basis.from_euler(Vector3(deg_to_rad(-4.0 + sin(time * 0.13) * 1.2), 0, deg_to_rad(6.0 + sin(time * 0.17) * 1.5)))

static func support_height(axes: Vector3, orientation: Basis) -> float:
	return Vector3(orientation.x.y * axes.x, orientation.y.y * axes.y, orientation.z.y * axes.z).length()

static func scenery_height(center_y: float) -> float:
	# Conservative sphere bound also covers the full tilt cycle, both hands,
	# shader displacement, the room's rug, and the optional 8 cm user drift.
	return minf(0.0, center_y - OUTER_AXES.y * (1.0 + MAX_DEFORMATION) - FLOOR_CLEARANCE - 0.08)
