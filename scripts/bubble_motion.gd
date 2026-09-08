extends RefCounted
const MAX_BUBBLES := 48
const RESTITUTION := 0.84

static func contain(entry: Dictionary, axes: Vector3) -> bool:
	var radius: float = entry.radius
	var bounds: Vector3 = axes - Vector3.ONE * (radius + 0.01)
	var unit: Vector3 = entry.position / bounds
	if unit.length_squared() <= 1.0:
		return false
	entry.position = unit.normalized() * bounds
	var normal: Vector3 = (entry.position / (bounds * bounds)).normalized()
	var outward: float = entry.velocity.dot(normal)
	if outward > 0:
		entry.velocity -= normal * (1.0 + RESTITUTION) * outward
	return true

static func step(entries: Array[Dictionary], delta: float, axes: Vector3, head: Vector3):
	var remaining := minf(delta, 0.1)
	while remaining > 0:
		var dt := minf(remaining, 1.0/90.0)
		for entry in entries:
			entry.velocity *= exp(-dt * 0.025)
			entry.position += entry.velocity * dt
			var offset: Vector3 = entry.position - head
			var clearance: float = entry.radius + 0.13
			if offset.length_squared() < clearance * clearance:
				var normal := offset.normalized() if offset.length_squared() > 0.000001 else Vector3.FORWARD
				entry.position = head + normal * clearance
				var inward: float = entry.velocity.dot(normal)
				if inward < 0:
					entry.velocity -= normal * inward * 1.5
			contain(entry, axes)
		# Equal-mass soft collisions keep the little bubbles from forming one visual clump.
		for i in entries.size():
			for j in range(i+1, entries.size()):
				var a := entries[i]
				var b := entries[j]
				var offset: Vector3 = a.position - b.position
				var separation: float = a.radius + b.radius
				var squared := offset.length_squared()
				if squared >= separation * separation:
					continue
				var distance := sqrt(squared)
				var normal := offset / distance if distance > 0.0001 else Vector3.RIGHT
				var correction := normal * (separation-distance) * 0.5
				a.position += correction
				b.position -= correction
				var closing: float = (a.velocity-b.velocity).dot(normal)
				if closing < 0:
					var impulse := normal * closing * 0.80
					a.velocity -= impulse
					b.velocity += impulse
				contain(a, axes)
				contain(b, axes)
		remaining -= dt
