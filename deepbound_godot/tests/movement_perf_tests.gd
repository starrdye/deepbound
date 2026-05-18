extends SceneTree

const DeepboundWorld = preload("res://scripts/World.gd")
const PlayerController = preload("res://scripts/controllers/PlayerController.gd")
const CameraController = preload("res://scripts/controllers/CameraController.gd")
const StructureGenerator = preload("res://scripts/systems/StructureGenerator.gd")
const PrefabTemplateRegistry = preload("res://scripts/systems/PrefabTemplateRegistry.gd")

const STEP := 1.0 / 60.0
const SUSTAINED_FALL_FRAMES := 100

var failures: Array[String] = []

class PerfWorld:
	extends DeepboundWorld

	var draw_count := 0
	var solid_probe_count := 0

	func _draw() -> void:
		draw_count += 1
		super._draw()

	func is_solid_tile(_tile: Vector2i) -> bool:
		solid_probe_count += 1
		_record_perf_event("solid_tile_probe")
		return false

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_ensure_input_actions()
	await _test_short_jump_stays_inside_redraw_margin()
	await _test_sustained_fall_redraws_only_past_margin()
	await _test_sustained_fall_warms_chunks_before_redraw()
	await _test_placement_preview_does_not_full_redraw_while_falling()
	await _test_template_heavy_fall_uses_structure_cache()
	_test_mining_ray_skips_duplicate_tile_probes()
	_test_structure_light_cache_reuses_nearby_queries()
	await _test_vertical_fall_probe_and_chunk_counts_are_bounded()
	if failures.is_empty():
		print("Deepbound Godot movement perf tests passed.")
		quit(0)
	else:
		print("Deepbound Godot movement perf tests failed: %d" % failures.size())
		quit(1)

func _test_short_jump_stays_inside_redraw_margin() -> void:
	var rig: Dictionary = await _make_rig(Vector2(0, 96))
	var world: PerfWorld = rig.world
	var player: PlayerController = rig.player
	var camera: CameraController = rig.camera
	player.on_ground = false
	player.velocity = Vector2(0, PlayerController.JUMP_VELOCITY)
	await _reset_rig_counters(rig)
	var start_camera_tile := world.world_to_tile(camera.global_position)

	for _i in range(20):
		await _step_rig(rig, STEP)

	var camera_tile_delta := absi(world.world_to_tile(camera.global_position).y - start_camera_tile.y)
	_assert(camera_tile_delta < DeepboundWorld.REDRAW_DRIFT_TILES, "short jump camera movement should stay inside the full redraw margin")
	_assert(world.draw_count == 0, "short jump inside the camera margin should not redraw the whole world")
	_assert(world.get_debug_perf_counter("chunk_foreground_draw") == 0, "short jump should not redraw cached foreground chunks")
	_assert(world.get_debug_perf_counter("chunk_background_draw") == 0, "short jump should not redraw cached background chunks")
	_free_rig(rig)

func _test_sustained_fall_redraws_only_past_margin() -> void:
	var rig: Dictionary = await _make_rig(Vector2(0, 96))
	var world: PerfWorld = rig.world
	var player: PlayerController = rig.player
	var camera: CameraController = rig.camera
	player.on_ground = false
	player.velocity = Vector2(0, PlayerController.MAX_FALL)
	await _reset_rig_counters(rig)
	var start_camera_tile := world.world_to_tile(camera.global_position)

	for _i in range(SUSTAINED_FALL_FRAMES):
		await _step_rig(rig, STEP)

	var camera_tile_delta := absi(world.world_to_tile(camera.global_position).y - start_camera_tile.y)
	var expected_window_refreshes := ceili(float(camera_tile_delta) / 32.0) + 2
	var window_refreshes := world.get_debug_perf_counter("visible_chunk_window_refresh")
	_assert(window_refreshes > 0, "sustained fall should refresh when the visible chunk window changes")
	_assert(window_refreshes <= expected_window_refreshes, "sustained fall should refresh by chunk-window crossings; expected <= %d got %d" % [expected_window_refreshes, window_refreshes])
	_assert(world.draw_count <= window_refreshes + 1, "sustained fall should redraw the lightweight backdrop only when the chunk window changes")
	_free_rig(rig)

func _test_placement_preview_does_not_full_redraw_while_falling() -> void:
	var rig: Dictionary = await _make_rig(Vector2(0, 96))
	var world: PerfWorld = rig.world
	var player: PlayerController = rig.player
	var camera: CameraController = rig.camera
	player.on_ground = false
	player.velocity = Vector2(0, PlayerController.MAX_FALL)
	player.set_selected_hotbar_item("dirt_clod")
	await _reset_rig_counters(rig)
	var start_camera_tile := world.world_to_tile(camera.global_position)

	for _i in range(SUSTAINED_FALL_FRAMES):
		var preview_tile := world.world_to_tile(player.global_position + Vector2(64, -16))
		world.set_placement_preview(preview_tile, true, true)
		await _step_rig(rig, STEP)

	var camera_tile_delta := absi(world.world_to_tile(camera.global_position).y - start_camera_tile.y)
	var expected_window_refreshes := ceili(float(camera_tile_delta) / 32.0) + 2
	var window_refreshes := world.get_debug_perf_counter("visible_chunk_window_refresh")
	_assert(window_refreshes <= expected_window_refreshes + 2, "falling placement preview should not force extra chunk-window refreshes; expected <= %d got %d" % [expected_window_refreshes + 2, window_refreshes])
	_assert(world.get_debug_perf_counter("placement_preview_update") >= SUSTAINED_FALL_FRAMES / 2, "falling placement preview should update the lightweight overlay repeatedly")
	_assert(world.get_placement_preview_draw_count() >= SUSTAINED_FALL_FRAMES / 2, "placement preview overlay should redraw independently of the world")
	_assert(world.get_debug_perf_counter("world_redraw_placement_preview") == 0, "placement preview updates should never be counted as full-world redraws")
	_free_rig(rig)

func _test_template_heavy_fall_uses_structure_cache() -> void:
	PrefabTemplateRegistry.clear_runtime_structure_cache()
	PrefabTemplateRegistry.reset_debug_perf_counters()
	var structure := _find_first_template_structure(133742)
	_assert(not structure.is_empty(), "template-heavy fall test needs a generated goblin village template")
	var rect: Rect2i = structure.rect
	var start_position := Vector2(float((rect.position.x + rect.size.x / 2) * DeepboundWorld.TILE_SIZE), float((rect.position.y - 8) * DeepboundWorld.TILE_SIZE))
	var rig: Dictionary = await _make_rig(start_position)
	var world: PerfWorld = rig.world
	var player: PlayerController = rig.player
	player.on_ground = false
	player.velocity = Vector2(0, PlayerController.MAX_FALL)
	await _reset_rig_counters(rig)
	PrefabTemplateRegistry.clear_runtime_structure_cache()
	PrefabTemplateRegistry.reset_debug_perf_counters()

	for _i in range(SUSTAINED_FALL_FRAMES):
		await _step_rig(rig, STEP)

	var misses := PrefabTemplateRegistry.get_debug_perf_counter("template_region_cache_miss")
	var hits := PrefabTemplateRegistry.get_debug_perf_counter("template_region_cache_hit")
	var chunk_hits := PrefabTemplateRegistry.get_debug_perf_counter("structure_chunk_cache_hit")
	var chunk_misses := PrefabTemplateRegistry.get_debug_perf_counter("structure_chunk_cache_miss")
	_assert(misses > 0, "template-heavy fall should instantiate at least one template region")
	_assert(hits >= misses, "template-heavy fall should reuse cached template regions; hits=%d misses=%d" % [hits, misses])
	_assert(chunk_hits >= chunk_misses, "template-heavy fall should reuse cached chunk overlap results; hits=%d misses=%d" % [chunk_hits, chunk_misses])
	_assert(world.get_debug_perf_counter("chunk_foreground_draw") <= world.get_debug_perf_counter("chunk_foreground_node_created") + 2, "template-heavy fall should draw newly created foreground chunks, not redraw all chunks")
	_free_rig(rig)

func _test_mining_ray_skips_duplicate_tile_probes() -> void:
	var world := DeepboundWorld.new()
	world.enable_debug_perf_counters(true)
	var origin := Vector2(8, -8)
	for x in range(0, 7):
		var tile := Vector2i(x, -1)
		world.set_tile(tile, "air")
		world.set_background_tile(tile, "empty")
	world.reset_debug_perf_counters()
	var target_info := world.find_mining_target_info(origin, Vector2.RIGHT)
	_assert(not bool(target_info.found), "test ray should stay clear so the full ray is scanned")
	_assert(world.get_debug_perf_counter("solid_tile_probe") <= 6, "mining ray should probe unique tiles instead of every 4px step")
	world.free()

func _test_structure_light_cache_reuses_nearby_queries() -> void:
	var world := DeepboundWorld.new()
	world.enable_debug_perf_counters(true)
	world.get_light_sources(Vector2(0, 96))
	world.get_light_sources(Vector2(16, 96))
	_assert(world.get_debug_perf_counter("structure_light_cache_refresh") == 1, "nearby light-source queries should reuse the structure light cache")
	_assert(world.get_debug_perf_counter("structure_light_cache_hit") == 1, "second nearby light-source query should hit the structure light cache")
	world.free()

func _test_sustained_fall_warms_chunks_before_redraw() -> void:
	var rig: Dictionary = await _make_rig(Vector2(0, 96))
	var world: PerfWorld = rig.world
	var player: PlayerController = rig.player
	player.on_ground = false
	player.velocity = Vector2(0, PlayerController.MAX_FALL)
	await _reset_rig_counters(rig)

	for _i in range(SUSTAINED_FALL_FRAMES):
		await _step_rig(rig, STEP)

	var warm_checks := world.get_debug_perf_counter("chunk_warm_checked")
	var warm_generated := world.get_debug_perf_counter("chunk_warm_generated")
	var max_checks := SUSTAINED_FALL_FRAMES * DeepboundWorld.CHUNK_WARM_PER_FRAME
	_assert(warm_checks > 0, "sustained fall should process queued chunk warm-up work")
	_assert(warm_generated > 0, "sustained fall should pre-generate chunks before the redraw needs them")
	_assert(warm_checks <= max_checks, "chunk warm-up should stay capped per frame; expected <= %d got %d" % [max_checks, warm_checks])
	_free_rig(rig)

func _test_vertical_fall_probe_and_chunk_counts_are_bounded() -> void:
	var rig: Dictionary = await _make_rig(Vector2(0, 96))
	var world: PerfWorld = rig.world
	var player: PlayerController = rig.player
	player.on_ground = false
	player.velocity = Vector2(0, PlayerController.MAX_FALL)
	await _reset_rig_counters(rig)

	for _i in range(SUSTAINED_FALL_FRAMES):
		await _step_rig(rig, STEP)

	var probes_per_frame := float(world.solid_probe_count) / float(SUSTAINED_FALL_FRAMES)
	var generated_chunks := int(world.store.generated_chunk_count) + int(world.store.generated_background_chunk_count)
	var chunk_budget := maxi(32, world.get_debug_perf_counter("visible_chunk_window_refresh") * 12 + DeepboundWorld.CHUNK_WARM_AHEAD_CHUNKS_Y * 8 + 12)
	_assert(probes_per_frame <= 20.0, "vertical fall collision and target probes should stay bounded; got %.2f per frame" % probes_per_frame)
	_assert(generated_chunks <= chunk_budget, "vertical fall chunk generation should stay tied to redraw/chunk-boundary crossings; expected <= %d got %d" % [chunk_budget, generated_chunks])
	_free_rig(rig)

func _make_rig(start_position: Vector2) -> Dictionary:
	var player := PlayerController.new()
	player.name = "Player"
	player.global_position = start_position
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	player.add_child(sprite)
	var camera := CameraController.new()
	camera.name = "Camera2D"
	camera.enabled = true
	camera.zoom = Vector2(2, 2)
	player.add_child(camera)

	var world := PerfWorld.new()
	world.name = "World"
	get_root().add_child(player)
	get_root().add_child(world)
	await process_frame

	camera.make_current()
	camera.camera_target = player.global_position
	camera.smoothed_position = player.global_position
	camera.global_position = player.global_position
	player.world = world
	world.player = player
	world.enable_debug_perf_counters(true)
	PrefabTemplateRegistry.reset_debug_perf_counters()
	world.set_process(false)
	player.set_physics_process(false)
	camera.set_process(false)
	await _flush_frames(2)
	return {"world": world, "player": player, "camera": camera}

func _step_rig(rig: Dictionary, delta: float) -> void:
	var player: PlayerController = rig.player
	var camera: CameraController = rig.camera
	var world: PerfWorld = rig.world
	player._physics_process(delta)
	camera.update_follow(delta)
	world._process(delta)
	await process_frame

func _reset_rig_counters(rig: Dictionary) -> void:
	await _flush_frames(2)
	var world: PerfWorld = rig.world
	var camera: CameraController = rig.camera
	world.draw_count = 0
	world.solid_probe_count = 0
	world.reset_debug_perf_counters()
	PrefabTemplateRegistry.reset_debug_perf_counters()
	if world.store.has_method("reset_debug_counters"):
		world.store.reset_debug_counters()
	world.chunk_warm_queue.clear()
	world.queued_chunk_warmups.clear()
	var overlay := world.get_node_or_null("PlacementPreviewOverlay")
	if overlay != null:
		overlay.set("draw_count", 0)
	world.last_redraw_center_tile = world.world_to_tile(camera.global_position)
	world.last_chunk_warm_center_tile = world.last_redraw_center_tile

func _find_first_template_structure(seed: int) -> Dictionary:
	for chunk_y in range(0, 12):
		for chunk_x in range(-18, 19):
			for structure in StructureGenerator.get_structures_overlapping_chunk(seed, Vector2i(chunk_x, chunk_y)):
				if String(structure.get("type", "")) == "goblin_village":
					return structure
	return {}

func _flush_frames(count: int) -> void:
	for _i in range(count):
		await process_frame

func _free_rig(rig: Dictionary) -> void:
	var player: Node = rig.player
	var world: Node = rig.world
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(world):
		world.queue_free()

func _ensure_input_actions() -> void:
	for action_name in ["move_left", "move_right", "move_up", "jump", "drill"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
