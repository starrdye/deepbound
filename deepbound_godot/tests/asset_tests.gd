extends SceneTree

const TextureFactory = preload("res://scripts/factories/TextureFactory.gd")
const BackgroundCatalog = preload("res://scripts/catalogs/BackgroundCatalog.gd")

var failures: Array[String] = []

const TILE_IDS := [
	"surface_grass",
	"surface_loam",
	"surface_root_loam",
	"surface_stone",
	"loose_dirt",
	"compacted_dirt",
	"soft_stone",
	"copper_ore",
	"hardened_resin",
	"royal_jelly",
	"dwarf_granite_brick",
	"dwarf_cut_granite_floor",
	"dwarf_ironbound_block",
	"dwarf_rune_block",
	"dwarf_iron_platform",
	"sandstone_block",
	"pressure_plate",
	"cursed_treasure",
	"goblin_timber_wall",
	"goblin_packed_floor",
	"goblin_hide_canopy",
	"goblin_mossy_brick",
	"goblin_plank_platform",
	"glow_mushroom_loam",
	"obsidian_ash",
	"solid_dark_block"
]

const ENEMY_IDS := [
	"cave_skitter",
	"goblin_grunt",
	"goblin_slinger",
	"goblin_shaman",
	"worker_ant",
	"soldier_ant",
	"dwarf_guard",
	"dwarf_crossbowman",
	"dwarf_smith",
	"mummy_sentry",
	"tunneling_worm_head",
	"tunneling_worm_segment",
	"rootbound_foreman",
	"amber_queen",
	"pharaoh_of_buried_sun",
	"drow_matriarch",
	"obsidian_baron"
]

const ITEM_IDS := [
	"dirt_clod",
	"stone_chunk",
	"copper_nugget",
	"wooden_sword",
	"hammer",
	"dirt_background_block",
	"stone_background_block",
	"wooden_background_block",
	"resin_shard",
	"royal_jelly",
	"sandstone_shard",
	"cursed_relic",
	"glow_spore",
	"drow_silk",
	"obsidian_chip",
	"heat_core",
	"dark_block_sliver",
	"copper_brace",
	"resin_seal",
	"tomb_key"
]

const UI_IDS := [
	"health",
	"heart_full",
	"heart_half",
	"heart_empty",
	"drill_heat",
	"quickbar_slot",
	"quickbar_selected",
	"inventory_slot",
	"flare_bundle",
	"outpost_beacon",
	"copper_brace",
	"resin_seal",
	"tomb_key",
	"light",
	"danger_pulse"
]

const BACKGROUND_IDS := [
	"surface_root_background",
	"dirt_background_block",
	"stone_background_block",
	"wooden_background_block",
	"goblin_timber_background",
	"goblin_hide_background",
	"goblin_packed_earth_background",
	"dwarf_granite_background",
	"dwarf_forge_background",
	"dwarf_rune_background"
]

const SURFACE_IDS := {
	"tree_backdrop": Vector2i(384, 192),
	"rocks_backdrop": Vector2i(560, 192)
}

const UI_SHEETS := {
	"heart_sheet": Vector2i(48, 16)
}

const EFFECT_IDS := [
	"tile_crack_1",
	"tile_crack_2",
	"tile_crack_3",
	"tile_break_stage_1",
	"tile_break_stage_2",
	"tile_break_stage_3",
	"tile_break_stage_4",
	"tile_break_stage_5",
	"tile_breaking_sheet",
	"drill_impact_spark",
	"pickup_magnet",
	"worm_telegraph_crescent",
	"worm_dust_crack",
	"enemy_hit_flash"
]

const BREAK_TILE_IDS := [
	"loose_dirt",
	"compacted_dirt",
	"soft_stone",
	"copper_ore",
	"hardened_resin",
	"royal_jelly",
	"dwarf_granite_brick",
	"dwarf_cut_granite_floor",
	"dwarf_ironbound_block",
	"dwarf_rune_block",
	"dwarf_iron_platform",
	"sandstone_block",
	"pressure_plate",
	"cursed_treasure",
	"goblin_timber_wall",
	"goblin_packed_floor",
	"goblin_hide_canopy",
	"goblin_mossy_brick",
	"goblin_plank_platform",
	"glow_mushroom_loam",
	"obsidian_ash",
	"surface_grass",
	"surface_loam",
	"surface_root_loam",
	"surface_stone"
]

const PROP_IDS := [
	"flare",
	"outpost_beacon",
	"dart_trap",
	"dart_projectile",
	"pressure_plate_depressed",
	"goblin_bone_altar",
	"goblin_crate",
	"goblin_cage",
	"goblin_torch",
	"goblin_banner",
	"goblin_door_flap",
	"goblin_palisade_post",
	"goblin_rope_ladder",
	"goblin_rope_bridge",
	"goblin_scaffold_post",
	"goblin_diagonal_brace",
	"goblin_central_hut",
	"goblin_back_hut_lit",
	"goblin_back_hut_dark",
	"goblin_work_shelf",
	"goblin_wall_torch",
	"dwarf_forge",
	"dwarf_anvil",
	"dwarf_lantern",
	"dwarf_banner",
	"dwarf_gate",
	"dwarf_barrel",
	"dwarf_ladder",
	"dwarf_chain_lift",
	"dwarf_bridge",
	"dwarf_chest",
	"dwarf_armor_rack",
	"dwarf_back_tower_lit",
	"dwarf_back_tower_dark",
	"dwarf_ore_cart",
	"dwarf_rune_marker",
	"chest_closed",
	"chest_open",
	"chest_open_sheet",
	"surface_grass_clump",
	"surface_flower_clump",
	"surface_root_arch",
	"surface_mushroom"
]

const SOURCE_AI_IDS := [
	"villager_delver_ai_reference",
	"delver_main_character_v2_ai_reference",
	"enemy_roster_ai_reference",
	"world_asset_ai_reference",
	"drow_village_tiles_ai_reference",
	"goblin_village_ai_reference",
	"goblin_village_backgrounds_ai_reference",
	"goblin_village_expansion_ai_reference",
	"dwarf_fortress_ai_reference",
	"chest_heart_ai_reference",
	"weapon_modular_ai_reference",
	"held_item_pose_ai_reference",
	"world_atlas_surface_reference"
]

const PROP_SIZES := {
	"goblin_rope_ladder": Vector2i(16, 48),
	"goblin_rope_bridge": Vector2i(48, 16),
	"goblin_scaffold_post": Vector2i(16, 48),
	"goblin_diagonal_brace": Vector2i(32, 32),
	"goblin_central_hut": Vector2i(64, 48),
	"goblin_back_hut_lit": Vector2i(48, 32),
	"goblin_back_hut_dark": Vector2i(48, 32),
	"goblin_work_shelf": Vector2i(48, 32),
	"goblin_wall_torch": Vector2i(16, 32),
	"dwarf_forge": Vector2i(48, 32),
	"dwarf_banner": Vector2i(16, 32),
	"dwarf_gate": Vector2i(32, 48),
	"dwarf_ladder": Vector2i(16, 48),
	"dwarf_chain_lift": Vector2i(16, 48),
	"dwarf_bridge": Vector2i(48, 16),
	"dwarf_chest": Vector2i(32, 32),
	"dwarf_armor_rack": Vector2i(16, 32),
	"dwarf_back_tower_lit": Vector2i(64, 48),
	"dwarf_back_tower_dark": Vector2i(64, 48),
	"dwarf_ore_cart": Vector2i(32, 16)
}

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_test_source_art_boards()
	_test_player_sheet()
	_test_tiles()
	_test_backgrounds()
	_test_enemies()
	_test_items()
	_test_ui()
	_test_effects_and_props()
	_test_surface_backdrops()
	if failures.is_empty():
		print("Deepbound Godot asset tests passed.")
		quit(0)
	else:
		print("Deepbound Godot asset tests failed: %d" % failures.size())
		quit(1)

func _test_source_art_boards() -> void:
	for source_id in SOURCE_AI_IDS:
		var path := "res://assets/source_ai/%s.png" % source_id
		_assert(FileAccess.file_exists(path), "missing source art-board %s" % path)

func _test_player_sheet() -> void:
	var texture := TextureFactory.make_delver_sprite_sheet()
	_assert(texture != null, "delver villager sheet should load")
	_assert(texture.get_width() == 256 and texture.get_height() == 224, "delver villager sheet should be 8x7 32px frames including weapon swing")
	var hand_sheet := TextureFactory.make_weapon_hand_swing_texture()
	_assert(hand_sheet != null, "weapon hand swing sheet should load")
	_assert(hand_sheet.get_width() == 256 and hand_sheet.get_height() == 32, "weapon hand swing sheet should be eight 32x32 frames")
	var sword_sheet := TextureFactory.make_weapon_swing_texture("wooden_sword")
	_assert(sword_sheet != null, "wooden sword swing sheet should load")
	_assert(sword_sheet.get_width() == 256 and sword_sheet.get_height() == 32, "wooden sword swing sheet should be eight 32x32 frames")
	var ready_hand_sheet := TextureFactory.make_weapon_ready_hand_texture()
	_assert(ready_hand_sheet != null, "weapon ready hand sheet should load")
	_assert(ready_hand_sheet.get_width() == 256 and ready_hand_sheet.get_height() == 96, "weapon ready hand sheet should be eight frames across three movement rows")
	var ready_sword_sheet := TextureFactory.make_weapon_ready_texture("wooden_sword")
	_assert(ready_sword_sheet != null, "wooden sword ready sheet should load")
	_assert(ready_sword_sheet.get_width() == 256 and ready_sword_sheet.get_height() == 96, "wooden sword ready sheet should be eight frames across three movement rows")
	var held_hand_sheet := TextureFactory.make_held_item_hand_texture()
	_assert(held_hand_sheet != null, "held item hand sheet should load")
	_assert(held_hand_sheet.get_width() == 256 and held_hand_sheet.get_height() == 96, "held item hand sheet should be eight frames across three movement rows")
	var held_dirt := TextureFactory.make_held_item_texture("dirt_clod")
	_assert(held_dirt != null and held_dirt.get_width() == 16 and held_dirt.get_height() == 16, "held dirt should resolve to a 16x16 placed block texture")

func _test_tiles() -> void:
	for tile_id in TILE_IDS:
		var path := "res://assets/tiles/%s.png" % tile_id
		_assert(FileAccess.file_exists(path), "missing tile asset %s" % path)
		var texture := TextureFactory.make_tile_texture(tile_id, {"color": Color.WHITE, "highlight": Color.WHITE})
		_assert(texture != null, "tile texture should load for %s" % tile_id)
		_assert(texture.get_width() == 16 and texture.get_height() == 16, "tile %s should be 16x16" % tile_id)

func _test_backgrounds() -> void:
	for background_id in BACKGROUND_IDS:
		var path := "res://assets/backgrounds/%s.png" % background_id
		_assert(FileAccess.file_exists(path), "missing background block asset %s" % path)
		var background_def := BackgroundCatalog.get_background(background_id)
		_assert(not background_def.is_empty() and not BackgroundCatalog.is_empty(background_id), "background catalog should define %s" % background_id)
		var texture := TextureFactory.make_background_texture(background_id, background_def)
		_assert(texture != null, "background texture should load for %s" % background_id)
		_assert(texture.get_width() == 16 and texture.get_height() == 16, "background %s should be 16x16" % background_id)

func _test_enemies() -> void:
	for enemy_id in ENEMY_IDS:
		var path := "res://assets/enemies/%s.png" % enemy_id
		_assert(FileAccess.file_exists(path), "missing enemy asset %s" % path)
		var texture := TextureFactory.make_enemy_texture(enemy_id)
		_assert(texture != null, "enemy texture should load for %s" % enemy_id)
		_assert(texture.get_width() == 256 and texture.get_height() == 128, "enemy %s should be an 8x4 32px modular move sheet" % enemy_id)

func _test_items() -> void:
	for item_id in ITEM_IDS:
		var path := "res://assets/items/%s.png" % item_id
		_assert(FileAccess.file_exists(path), "missing item asset %s" % path)
		var texture := TextureFactory.make_item_texture(item_id)
		_assert(texture != null, "item texture should load for %s" % item_id)
		_assert(texture.get_width() == 16 and texture.get_height() == 16, "item %s should be 16x16" % item_id)

func _test_ui() -> void:
	for icon_id in UI_IDS:
		var path := "res://assets/ui/%s.png" % icon_id
		_assert(FileAccess.file_exists(path), "missing UI asset %s" % path)
		var texture := TextureFactory.make_ui_texture(icon_id)
		_assert(texture != null, "UI texture should load for %s" % icon_id)
		_assert(texture.get_width() == 16 and texture.get_height() == 16, "UI icon %s should be 16x16" % icon_id)
	for sheet_id in UI_SHEETS:
		var path := "res://assets/ui/%s.png" % sheet_id
		_assert(FileAccess.file_exists(path), "missing UI sheet %s" % path)
		var texture := TextureFactory.make_ui_texture(sheet_id)
		var expected: Vector2i = UI_SHEETS[sheet_id]
		_assert(texture != null, "UI sheet should load for %s" % sheet_id)
		_assert(texture.get_width() == expected.x and texture.get_height() == expected.y, "UI sheet %s should be %dx%d" % [sheet_id, expected.x, expected.y])

func _test_effects_and_props() -> void:
	for effect_id in EFFECT_IDS:
		var path := "res://assets/effects/%s.png" % effect_id
		_assert(FileAccess.file_exists(path), "missing effect asset %s" % path)
		var texture := TextureFactory.make_effect_texture(effect_id)
		_assert(texture != null, "effect texture should load for %s" % effect_id)
		if effect_id == "tile_breaking_sheet":
			_assert(texture.get_width() == 80 and texture.get_height() == 16, "tile breaking sheet should be five 16x16 stages")
		elif effect_id.begins_with("tile_break_stage_") or effect_id.begins_with("tile_crack_"):
			_assert(texture.get_width() == 16 and texture.get_height() == 16, "%s should be a 16x16 transparent overlay" % effect_id)
	for tile_id in BREAK_TILE_IDS:
		var effect_id := "tile_breaking_%s_sheet" % tile_id
		var path := "res://assets/effects/%s.png" % effect_id
		_assert(FileAccess.file_exists(path), "missing material breaking sheet %s" % path)
		var texture := TextureFactory.make_effect_texture(effect_id)
		_assert(texture != null, "material breaking sheet should load for %s" % tile_id)
		_assert(texture.get_width() == 80 and texture.get_height() == 16, "%s should be five 16x16 material break stages" % effect_id)
	for prop_id in PROP_IDS:
		var path := "res://assets/props/%s.png" % prop_id
		_assert(FileAccess.file_exists(path), "missing prop asset %s" % path)
		var texture := TextureFactory.make_prop_texture(prop_id)
		_assert(texture != null, "prop texture should load for %s" % prop_id)
		if prop_id == "chest_open_sheet":
			_assert(texture.get_width() == 256 and texture.get_height() == 32, "chest_open_sheet should be eight 32x32 frames")
		elif prop_id.begins_with("chest_"):
			_assert(texture.get_width() == 32 and texture.get_height() == 32, "%s should be 32x32" % prop_id)
		elif PROP_SIZES.has(prop_id):
			var expected: Vector2i = PROP_SIZES[prop_id]
			_assert(texture.get_width() == expected.x and texture.get_height() == expected.y, "%s should be %dx%d" % [prop_id, expected.x, expected.y])
		else:
			_assert(texture.get_width() == 16 and texture.get_height() == 16, "%s should be 16x16" % prop_id)

func _test_surface_backdrops() -> void:
	for surface_id in SURFACE_IDS:
		var path := "res://assets/surface/%s.png" % surface_id
		_assert(FileAccess.file_exists(path), "missing surface backdrop asset %s" % path)
		var texture := TextureFactory.make_surface_texture(surface_id)
		var expected: Vector2i = SURFACE_IDS[surface_id]
		_assert(texture != null, "surface backdrop should load for %s" % surface_id)
		_assert(texture.get_width() == expected.x and texture.get_height() == expected.y, "surface backdrop %s should be %dx%d" % [surface_id, expected.x, expected.y])
