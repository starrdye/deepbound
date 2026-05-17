extends RefCounted
class_name CollisionSystem

const TILE_SIZE := 16
const SKIN_WIDTH := 0.05
const MAX_MOTION_PER_STEP := 8.0

static func bottom_center_collider(width: float, height: float, bottom_offset := Vector2.ZERO) -> Dictionary:
	return {
		"width": width,
		"height": height,
		"bottom_offset": bottom_offset
	}

static func move_actor(position: Vector2, velocity: Vector2, delta: float, collider: Dictionary, world) -> Dictionary:
	if delta <= 0.0:
		return {"position": position, "velocity": velocity, "on_ground": false, "blocked_x": false, "blocked_y": false}

	var next_position := position
	var next_velocity := velocity
	var on_ground := false
	var blocked_x := false
	var blocked_y := false
	var total_motion := Vector2(absf(velocity.x * delta), absf(velocity.y * delta))
	var steps: int = maxi(1, ceili(maxf(total_motion.x, total_motion.y) / MAX_MOTION_PER_STEP))
	var step_delta := delta / float(steps)

	for _step in range(steps):
		var x_result := _move_axis(next_position, Vector2(next_velocity.x * step_delta, 0.0), collider, world)
		next_position = x_result.position
		if bool(x_result.blocked):
			next_velocity.x = 0.0
			blocked_x = true

		var falling := next_velocity.y > 0.0
		var y_result := _move_axis(next_position, Vector2(0.0, next_velocity.y * step_delta), collider, world)
		next_position = y_result.position
		if bool(y_result.blocked):
			if falling:
				on_ground = true
			next_velocity.y = 0.0
			blocked_y = true

	return {"position": next_position, "velocity": next_velocity, "on_ground": on_ground, "blocked_x": blocked_x, "blocked_y": blocked_y}

static func overlaps_tiles(position: Vector2, collider: Dictionary, world) -> bool:
	var rect := _aabb_at(position, collider)
	var left := floori((rect.position.x + SKIN_WIDTH) / TILE_SIZE)
	var right := floori((rect.position.x + rect.size.x - SKIN_WIDTH) / TILE_SIZE)
	var top := floori((rect.position.y + SKIN_WIDTH) / TILE_SIZE)
	var bottom := floori((rect.position.y + rect.size.y - SKIN_WIDTH) / TILE_SIZE)
	for y in range(top, bottom + 1):
		for x in range(left, right + 1):
			if world.is_solid_tile(Vector2i(x, y)):
				return true
	return false

static func aabb(position: Vector2, collider: Dictionary) -> Rect2:
	return _aabb_at(position, collider)

static func _move_axis(position: Vector2, motion: Vector2, collider: Dictionary, world) -> Dictionary:
	if motion == Vector2.ZERO:
		return {"position": position, "blocked": false}

	var next_position := position + motion
	var blocked := false
	var width := _width(collider)
	var height := _height(collider)
	var offset := _bottom_offset(collider)
	var rect := _aabb_at(next_position, collider)

	if motion.x > 0.0:
		var tile_x := floori((rect.position.x + rect.size.x - SKIN_WIDTH) / TILE_SIZE)
		var top := floori((rect.position.y + SKIN_WIDTH) / TILE_SIZE)
		var bottom := floori((rect.position.y + rect.size.y - SKIN_WIDTH) / TILE_SIZE)
		for tile_y in range(top, bottom + 1):
			if world.is_solid_tile(Vector2i(tile_x, tile_y)):
				var boundary := float(tile_x * TILE_SIZE)
				next_position.x = boundary - SKIN_WIDTH - width * 0.5 - offset.x
				blocked = true
				break
	elif motion.x < 0.0:
		var tile_x := floori((rect.position.x + SKIN_WIDTH) / TILE_SIZE)
		var top := floori((rect.position.y + SKIN_WIDTH) / TILE_SIZE)
		var bottom := floori((rect.position.y + rect.size.y - SKIN_WIDTH) / TILE_SIZE)
		for tile_y in range(top, bottom + 1):
			if world.is_solid_tile(Vector2i(tile_x, tile_y)):
				var boundary := float((tile_x + 1) * TILE_SIZE)
				next_position.x = boundary + SKIN_WIDTH + width * 0.5 - offset.x
				blocked = true
				break
	elif motion.y > 0.0:
		var tile_y := floori((rect.position.y + rect.size.y - SKIN_WIDTH) / TILE_SIZE)
		var left := floori((rect.position.x + SKIN_WIDTH) / TILE_SIZE)
		var right := floori((rect.position.x + rect.size.x - SKIN_WIDTH) / TILE_SIZE)
		for tile_x in range(left, right + 1):
			if world.is_solid_tile(Vector2i(tile_x, tile_y)):
				var boundary := float(tile_y * TILE_SIZE)
				next_position.y = boundary - SKIN_WIDTH - offset.y
				blocked = true
				break
	elif motion.y < 0.0:
		var tile_y := floori((rect.position.y + SKIN_WIDTH) / TILE_SIZE)
		var left := floori((rect.position.x + SKIN_WIDTH) / TILE_SIZE)
		var right := floori((rect.position.x + rect.size.x - SKIN_WIDTH) / TILE_SIZE)
		for tile_x in range(left, right + 1):
			if world.is_solid_tile(Vector2i(tile_x, tile_y)):
				var boundary := float((tile_y + 1) * TILE_SIZE)
				next_position.y = boundary + SKIN_WIDTH + height - offset.y
				blocked = true
				break

	return {"position": next_position, "blocked": blocked}

static func _aabb_at(position: Vector2, collider: Dictionary) -> Rect2:
	var bottom := position + _bottom_offset(collider)
	var width := _width(collider)
	var height := _height(collider)
	return Rect2(Vector2(bottom.x - width * 0.5, bottom.y - height), Vector2(width, height))

static func _width(collider: Dictionary) -> float:
	return float(collider.get("width", 1.0))

static func _height(collider: Dictionary) -> float:
	return float(collider.get("height", 1.0))

static func _bottom_offset(collider: Dictionary) -> Vector2:
	return collider.get("bottom_offset", Vector2.ZERO)
