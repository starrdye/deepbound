extends RefCounted
class_name TextureFactory

const DELVER_FRAME_SIZE := Vector2i(32, 32)
const DELVER_COLUMNS := 8
const DELVER_ROWS := 7

static var cache: Dictionary = {}

static func _put_rect(image: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
				image.set_pixel(x, y, color)

static func _put_cell_rect(image: Image, origin: Vector2i, rect: Rect2i, color: Color) -> void:
	_put_rect(image, Rect2i(origin + rect.position, rect.size), color)

static func _put_pixel(image: Image, origin: Vector2i, x: int, y: int, color: Color) -> void:
	var point := origin + Vector2i(x, y)
	if point.x >= 0 and point.y >= 0 and point.x < image.get_width() and point.y < image.get_height():
		image.set_pixel(point.x, point.y, color)

static func _load_project_texture(path: String, cache_key: String) -> Texture2D:
	if cache.has(cache_key):
		return cache[cache_key]
	if ResourceLoader.exists(path):
		var texture: Texture2D = load(path)
		if texture != null:
			cache[cache_key] = texture
			return texture
	var image := Image.new()
	var error := image.load(path)
	if error == OK:
		var texture := ImageTexture.create_from_image(image)
		cache[cache_key] = texture
		return texture
	return null

static func make_tile_texture(tile_id: String, tile_def: Dictionary) -> Texture2D:
	var key := "tile:%s" % tile_id
	if cache.has(key):
		return cache[key]
	var asset_texture := _load_project_texture("res://assets/tiles/%s.png" % tile_id, key)
	if asset_texture != null:
		return asset_texture
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(tile_def.color)
	match tile_id:
		"air":
			pass
		"solid_dark_block":
			_put_rect(image, Rect2i(3, 4, 10, 8), Color8(8, 9, 20))
			_put_rect(image, Rect2i(2, 2, 2, 2), tile_def.highlight)
			_put_rect(image, Rect2i(11, 12, 2, 1), Color8(18, 22, 45))
		"hardened_resin":
			_put_rect(image, Rect2i(0, 11, 16, 5), Color8(90, 53, 31))
			_put_rect(image, Rect2i(3, 2, 8, 5), Color8(198, 134, 51))
			_put_rect(image, Rect2i(5, 4, 6, 2), Color8(241, 184, 91))
			_put_rect(image, Rect2i(11, 8, 3, 4), Color8(104, 62, 28))
			_put_pixel(image, Vector2i.ZERO, 4, 3, Color8(255, 225, 130))
			_put_pixel(image, Vector2i.ZERO, 9, 5, Color8(255, 225, 130))
		"royal_jelly":
			_put_rect(image, Rect2i(2, 3, 12, 10), Color8(240, 211, 94))
			_put_rect(image, Rect2i(4, 5, 8, 4), Color8(255, 238, 154))
			_put_rect(image, Rect2i(3, 11, 10, 2), Color8(154, 118, 49))
			_put_pixel(image, Vector2i.ZERO, 6, 6, Color.WHITE)
		"copper_ore":
			_draw_earth_tile(image, tile_def, true)
			_put_rect(image, Rect2i(6, 4, 2, 2), Color8(240, 168, 79))
			_put_rect(image, Rect2i(10, 8, 3, 2), Color8(255, 214, 107))
			_put_pixel(image, Vector2i.ZERO, 7, 5, Color8(255, 228, 141))
		"cursed_treasure":
			_put_rect(image, Rect2i(1, 10, 14, 5), Color8(55, 39, 28))
			_put_rect(image, Rect2i(3, 4, 10, 8), Color8(88, 66, 40))
			_put_rect(image, Rect2i(5, 6, 6, 2), Color8(255, 214, 107))
			_put_rect(image, Rect2i(7, 9, 2, 2), Color8(112, 206, 177))
		"pressure_plate":
			_put_rect(image, Rect2i(1, 10, 14, 3), Color8(62, 143, 116))
			_put_rect(image, Rect2i(3, 8, 10, 2), Color8(112, 206, 177))
			_put_rect(image, Rect2i(0, 13, 16, 2), Color8(36, 61, 57))
		_:
			_draw_earth_tile(image, tile_def, false)
	var texture := ImageTexture.create_from_image(image)
	cache[key] = texture
	return texture

static func _draw_earth_tile(image: Image, tile_def: Dictionary, ore_tile: bool) -> void:
	_put_rect(image, Rect2i(0, 12, 16, 4), Color(tile_def.color, 0.72))
	_put_rect(image, Rect2i(2, 2, 4, 2), Color(tile_def.highlight, 0.82))
	_put_rect(image, Rect2i(10, 5, 3, 2), Color(tile_def.highlight, 0.72))
	_put_rect(image, Rect2i(3, 9, 5, 1), Color(tile_def.highlight, 0.34))
	_put_pixel(image, Vector2i.ZERO, 5, 5, Color(tile_def.highlight, 0.55))
	_put_pixel(image, Vector2i.ZERO, 12, 12, Color(tile_def.highlight, 0.45))
	if not ore_tile:
		_put_rect(image, Rect2i(11, 11, 3, 1), Color(tile_def.color, 0.55))

static func make_delver_texture() -> Texture2D:
	if cache.has("delver_idle"):
		return cache["delver_idle"]
	var sheet := make_delver_sprite_sheet()
	if sheet != null:
		var image := sheet.get_image()
		var frame := image.get_region(Rect2i(0, 0, DELVER_FRAME_SIZE.x, DELVER_FRAME_SIZE.y))
		var frame_texture := ImageTexture.create_from_image(frame)
		cache["delver_idle"] = frame_texture
		return frame_texture
	var image := Image.create(DELVER_FRAME_SIZE.x, DELVER_FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	_draw_delver_frame(image, Vector2i.ZERO, "idle", 0)
	var texture := ImageTexture.create_from_image(image)
	cache["delver_idle"] = texture
	return texture

static func make_delver_sprite_sheet() -> Texture2D:
	if cache.has("delver_sheet_villager"):
		return cache["delver_sheet_villager"]
	var asset_texture := _load_project_texture("res://assets/sprites/delver_villager_sheet.png", "delver_sheet_villager")
	if asset_texture != null:
		return asset_texture
	var image := Image.create(DELVER_FRAME_SIZE.x * DELVER_COLUMNS, DELVER_FRAME_SIZE.y * DELVER_ROWS, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var rows := ["idle", "walk", "jump", "drill_side", "drill_up", "drill_down", "weapon_swing"]
	for row in range(rows.size()):
		for frame in range(DELVER_COLUMNS):
			_draw_delver_frame(image, Vector2i(frame * DELVER_FRAME_SIZE.x, row * DELVER_FRAME_SIZE.y), rows[row], frame)
	var texture := ImageTexture.create_from_image(image)
	cache["delver_sheet_villager"] = texture
	return texture

static func make_enemy_texture(enemy_id: String) -> Texture2D:
	return _load_project_texture("res://assets/enemies/%s.png" % enemy_id, "enemy:%s" % enemy_id)

static func make_item_texture(item_id: String) -> Texture2D:
	return _load_project_texture("res://assets/items/%s.png" % item_id, "item:%s" % item_id)

static func make_ui_texture(icon_id: String) -> Texture2D:
	return _load_project_texture("res://assets/ui/%s.png" % icon_id, "ui:%s" % icon_id)

static func make_prop_texture(prop_id: String) -> Texture2D:
	return _load_project_texture("res://assets/props/%s.png" % prop_id, "prop:%s" % prop_id)

static func make_effect_texture(effect_id: String) -> Texture2D:
	return _load_project_texture("res://assets/effects/%s.png" % effect_id, "effect:%s" % effect_id)

static func _draw_delver_frame(image: Image, origin: Vector2i, pose: String, frame: int) -> void:
	var outline := Color8(24, 23, 36)
	var skin := Color8(224, 154, 116)
	var skin_shadow := Color8(158, 91, 75)
	var hair := Color8(84, 53, 39)
	var shirt := Color8(178, 138, 82)
	var shirt_hi := Color8(215, 172, 104)
	var pants := Color8(49, 74, 104)
	var pants_hi := Color8(77, 104, 132)
	var boot := Color8(47, 35, 31)
	var cloth_shadow := Color8(93, 67, 48)
	var drill := Color8(192, 139, 62)
	var drill_hi := Color8(255, 214, 107)
	var steel := Color8(188, 196, 196)
	var steel_shadow := Color8(91, 98, 105)
	var spark := Color8(255, 166, 43)

	var bob := 0
	var head_x := 0
	var left_leg_x := 0
	var right_leg_x := 0
	var left_arm_y := 0
	var right_arm_y := 0

	match pose:
		"idle":
			bob = 1 if frame % 8 in [2, 3, 4] else 0
			right_arm_y = 1 if frame % 8 in [2, 3, 4] else 0
		"walk":
			var cycle := frame % 8
			bob = 1 if cycle in [1, 2, 5, 6] else 0
			left_leg_x = [-2, -1, 0, 1, 2, 1, 0, -1][cycle]
			right_leg_x = [2, 1, 0, -1, -2, -1, 0, 1][cycle]
			left_arm_y = [1, 0, -1, -2, -1, 0, 1, 2][cycle]
			right_arm_y = [-1, 0, 1, 2, 1, 0, -1, -2][cycle]
		"jump":
			var jump_frame := mini(frame, 7)
			bob = [-1, -2, -2, -1, 0, 1, 1, 0][jump_frame]
			left_leg_x = [-1, -1, 0, 1, 1, 0, -1, 0][jump_frame]
			right_leg_x = [1, 1, 0, -1, -1, 0, 1, 0][jump_frame]
			left_arm_y = [-2, -2, -1, 0, 1, 1, 0, -1][jump_frame]
			right_arm_y = [-2, -2, -1, 0, 1, 1, 0, -1][jump_frame]
		"drill_side":
			bob = 1 if frame % 2 == 1 else 0
			right_arm_y = -1
			head_x = 1
		"drill_up":
			bob = -1 if frame % 2 == 1 else 0
			left_arm_y = -3
			right_arm_y = -3
		"drill_down":
			bob = 1
			left_leg_x = -1
			right_leg_x = 1
			left_arm_y = 2
			right_arm_y = 2
		"weapon_swing":
			var swing_cycle := frame % 8
			bob = 1 if swing_cycle in [2, 3, 4] else 0
			head_x = 1 if swing_cycle in [2, 3] else 0
			left_leg_x = [-1, -1, 0, 1, 1, 0, -1, -1][swing_cycle]
			right_leg_x = [1, 1, 0, -1, -1, 0, 1, 1][swing_cycle]

	# Legs and boots draw first so the tunic overlaps them.
	_put_cell_rect(image, origin, Rect2i(7 + left_leg_x, 21 + bob, 5, 8), outline)
	_put_cell_rect(image, origin, Rect2i(13 + right_leg_x, 21 + bob, 5, 8), outline)
	_put_cell_rect(image, origin, Rect2i(8 + left_leg_x, 22 + bob, 3, 6), pants)
	_put_cell_rect(image, origin, Rect2i(14 + right_leg_x, 22 + bob, 3, 6), pants_hi)
	_put_cell_rect(image, origin, Rect2i(6 + left_leg_x, 28 + bob, 6, 2), boot)
	_put_cell_rect(image, origin, Rect2i(13 + right_leg_x, 28 + bob, 6, 2), boot)

	# Arms are compact and readable like an NPC sheet, with drilling poses allowed to overhang.
	if pose == "drill_side":
		_put_cell_rect(image, origin, Rect2i(14, 14 + bob, 7, 5), outline)
		_put_cell_rect(image, origin, Rect2i(15, 15 + bob, 5, 3), shirt_hi)
		_put_cell_rect(image, origin, Rect2i(19, 14 + bob, 4, 5), drill)
		_put_pixel(image, origin, 22, 15 + bob + (frame % 2), drill_hi)
	elif pose == "drill_up":
		_put_cell_rect(image, origin, Rect2i(8, 11 + bob, 9, 4), outline)
		_put_cell_rect(image, origin, Rect2i(9, 11 + bob, 7, 2), shirt_hi)
		_put_cell_rect(image, origin, Rect2i(12, 3 + bob, 4, 8), drill)
		_put_pixel(image, origin, 13 + (frame % 2), 3 + bob, drill_hi)
	elif pose == "drill_down":
		_put_cell_rect(image, origin, Rect2i(14, 17 + bob, 6, 5), outline)
		_put_cell_rect(image, origin, Rect2i(15, 18 + bob, 4, 3), shirt_hi)
		_put_cell_rect(image, origin, Rect2i(18, 22 + bob, 4, 7), drill)
		_put_pixel(image, origin, 20, 28 + bob - (frame % 2), drill_hi)
	elif pose == "weapon_swing":
		var swing_cycle := frame % 8
		var swing_points := [
			[Vector2i(19, 13), Vector2i(23, 9), Vector2i(25, 7)],
			[Vector2i(20, 13), Vector2i(25, 9), Vector2i(27, 8)],
			[Vector2i(20, 14), Vector2i(27, 11), Vector2i(30, 10)],
			[Vector2i(20, 15), Vector2i(29, 15), Vector2i(31, 15)],
			[Vector2i(19, 17), Vector2i(26, 21), Vector2i(29, 23)],
			[Vector2i(18, 18), Vector2i(23, 24), Vector2i(25, 27)],
			[Vector2i(18, 17), Vector2i(22, 20), Vector2i(24, 22)],
			[Vector2i(18, 15), Vector2i(22, 16), Vector2i(24, 17)]
		]
		var shoulder: Vector2i = swing_points[swing_cycle][0]
		var blade_mid: Vector2i = swing_points[swing_cycle][1]
		var blade_tip: Vector2i = swing_points[swing_cycle][2]
		_put_cell_rect(image, origin, Rect2i(17, 14 + bob, 5, 5), outline)
		_put_cell_rect(image, origin, Rect2i(18, 15 + bob, 3, 3), shirt_hi)
		_draw_cell_line(image, origin, shoulder + Vector2i(0, bob), blade_mid + Vector2i(0, bob), drill)
		_draw_cell_line(image, origin, blade_mid + Vector2i(0, bob), blade_tip + Vector2i(0, bob), steel)
		_put_pixel(image, origin, blade_tip.x, blade_tip.y + bob, steel_shadow)
		if swing_cycle in [2, 3, 4]:
			for point in [Vector2i(23, 8), Vector2i(27, 10), Vector2i(30, 14), Vector2i(27, 20), Vector2i(23, 24)]:
				_put_pixel(image, origin, point.x, point.y + bob, spark)
	else:
		_put_cell_rect(image, origin, Rect2i(4, 14 + bob + left_arm_y, 5, 10), outline)
		_put_cell_rect(image, origin, Rect2i(16, 14 + bob + right_arm_y, 5, 10), outline)
		_put_cell_rect(image, origin, Rect2i(5, 15 + bob + left_arm_y, 3, 5), shirt)
		_put_cell_rect(image, origin, Rect2i(17, 15 + bob + right_arm_y, 3, 5), shirt_hi)
		_put_cell_rect(image, origin, Rect2i(5, 20 + bob + left_arm_y, 3, 3), skin)
		_put_cell_rect(image, origin, Rect2i(17, 20 + bob + right_arm_y, 3, 3), skin)

	# Simple villager cloth torso.
	_put_cell_rect(image, origin, Rect2i(7, 12 + bob, 11, 11), outline)
	_put_cell_rect(image, origin, Rect2i(8, 13 + bob, 9, 8), shirt)
	_put_cell_rect(image, origin, Rect2i(9, 14 + bob, 6, 2), shirt_hi)
	_put_cell_rect(image, origin, Rect2i(8, 20 + bob, 9, 2), cloth_shadow)
	_put_cell_rect(image, origin, Rect2i(11, 13 + bob, 2, 9), Color8(114, 78, 52))

	# Head, hair, and readable face.
	_put_cell_rect(image, origin, Rect2i(7 + head_x, 3 + bob, 10, 10), outline)
	_put_cell_rect(image, origin, Rect2i(8 + head_x, 5 + bob, 8, 7), skin)
	_put_cell_rect(image, origin, Rect2i(7 + head_x, 3 + bob, 10, 4), hair)
	_put_cell_rect(image, origin, Rect2i(7 + head_x, 7 + bob, 2, 3), hair)
	_put_pixel(image, origin, 13 + head_x, 8 + bob, outline)
	_put_pixel(image, origin, 16 + head_x, 9 + bob, skin_shadow)
	_put_pixel(image, origin, 10 + head_x, 11 + bob, Color8(246, 190, 148))

static func _draw_cell_line(image: Image, origin: Vector2i, from_point: Vector2i, to_point: Vector2i, color: Color) -> void:
	var dx := absi(to_point.x - from_point.x)
	var sx := 1 if from_point.x < to_point.x else -1
	var dy := -absi(to_point.y - from_point.y)
	var sy := 1 if from_point.y < to_point.y else -1
	var err := dx + dy
	var x := from_point.x
	var y := from_point.y
	while true:
		_put_pixel(image, origin, x, y, color)
		if x == to_point.x and y == to_point.y:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
