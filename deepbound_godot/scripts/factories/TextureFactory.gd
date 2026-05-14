extends RefCounted
class_name TextureFactory

static var cache: Dictionary = {}

static func _put_rect(image: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
				image.set_pixel(x, y, color)

static func make_tile_texture(tile_id: String, tile_def: Dictionary) -> Texture2D:
	var key := "tile:%s" % tile_id
	if cache.has(key):
		return cache[key]
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(tile_def.color)
	if tile_id == "solid_dark_block":
		_put_rect(image, Rect2i(4, 5, 8, 7), Color8(8, 9, 20))
		_put_rect(image, Rect2i(2, 2, 2, 2), tile_def.highlight)
	elif tile_id != "air":
		_put_rect(image, Rect2i(0, 12, 16, 4), Color(tile_def.color, 0.72))
		_put_rect(image, Rect2i(2, 2, 4, 2), tile_def.highlight)
		_put_rect(image, Rect2i(10, 5, 3, 2), tile_def.highlight)
		if tile_id == "copper_ore" or tile_id == "cursed_treasure" or tile_id == "royal_jelly":
			_put_rect(image, Rect2i(6, 6, 4, 3), tile_def.highlight)
	var texture := ImageTexture.create_from_image(image)
	cache[key] = texture
	return texture

static func make_delver_texture() -> Texture2D:
	if cache.has("delver"):
		return cache.delver
	var image := Image.create(24, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var outline := Color8(24, 23, 36)
	_put_rect(image, Rect2i(7, 2, 10, 8), outline)
	_put_rect(image, Rect2i(5, 10, 14, 13), outline)
	_put_rect(image, Rect2i(4, 18, 6, 11), outline)
	_put_rect(image, Rect2i(14, 18, 6, 11), outline)
	_put_rect(image, Rect2i(8, 5, 8, 5), Color8(97, 113, 125))
	_put_rect(image, Rect2i(7, 12, 10, 10), Color8(97, 113, 125))
	_put_rect(image, Rect2i(9, 6, 5, 2), Color8(169, 183, 186))
	_put_rect(image, Rect2i(16, 4, 4, 3), Color8(192, 139, 62))
	_put_rect(image, Rect2i(20, 5, 2, 1), Color8(255, 214, 107))
	_put_rect(image, Rect2i(17, 14, 7, 3), Color8(77, 89, 98))
	var texture := ImageTexture.create_from_image(image)
	cache.delver = texture
	return texture

