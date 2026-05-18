# Prefab Template System

Deepbound uses sparse JSON templates for reusable underground structures. The system supports small macro-blocks, room kits, villages, and fortress-scale settlements without hardcoding each settlement into the live chunk generator.

## Files

Built-in templates live under `data/templates/*.json`. Player or local-authored templates can be saved under `user://templates/*.json`.

Current built-ins:

| Template | Band | Purpose |
| --- | --- | --- |
| `goblin_village_full` | `standard_caverns` | Imported full Band 1 goblin village. |
| `dwarf_fortress_full` | `colossal_ant_chambers` | Band 2 stone-and-iron fortress with forge rooms, ladders, lights, containers, and dwarf spawn markers. |

## JSON Shape

Template schema version `1` requires:

- `schema_version`
- `id`
- `name`
- `size`
- `anchor`
- `metadata`
- `layers`

Layer arrays are sparse. Missing cells mean "do not stamp this tile." Explicit entries are intentional:

- `layers.foreground`: `{x, y, id}` using `TileCatalog` ids. `air` means carve terrain.
- `layers.backgrounds`: `{x, y, id}` using `BackgroundCatalog` ids. `empty` means clear the wall.
- `layers.props`: `{x, y, id, kind, size, offset, draw_layer, alpha}` using `assets/props/*.png`.
- `layers.spawns`: `{x, y, enemy_id}` using `EnemyCatalog` ids.

Metadata controls deterministic world placement:

- `bands`: allowed underground bands.
- `rarity`: region spawn roll from `0.0` to `1.0`.
- `enabled`: disables a template without deleting it.
- `allow_mirror_x`, `allow_mirror_y`, `allow_rotation`: deterministic transform permissions.
- `tags`: search/classification labels.
- `spawn_region_size`: optional region scan size.
- `spawn_anchor_offset`: optional anchor point inside the spawn region.
- `structure_type`: runtime structure type string.

## Designer

Launch `scenes/PrefabDesigner.tscn` as a utility scene to author templates. The palette is built from:

- `TileCatalog`
- `BackgroundCatalog`
- `EnemyCatalog`
- `assets/props/*.png`

The designer supports foreground, background, prop, and spawn-marker layers; adjustable canvas size; camera pan/zoom; pencil, eraser, bucket fill, and marquee selection; anchor metadata; band metadata; and JSON save/load.

## Runtime Integration

`PrefabTemplateRegistry.gd` loads built-ins first and then user templates. Duplicate user ids override built-ins locally.

At worldgen time, `StructureGenerator.gd` asks the registry for structures overlapping a chunk. The registry scans deterministic spawn regions, checks starter avoidance and band bounds, rolls rarity, applies allowed transforms, and returns structure dictionaries with:

- `tiles`
- `backgrounds`
- `props`
- `spawns`
- `lights`
- `containers`
- `rect`
- `type`

`ChunkStore` applies foreground and background overlays during chunk generation. World lighting and spawn systems query nearby `lights`, `containers`, and `spawns` from the same registry.

## Performance Notes

Template instantiation is cached by seed, template id, and region. Chunk overlap queries and nearby marker queries are also cached, so camera movement through template-heavy areas should reuse registry results instead of rebuilding fortress/village dictionaries.

Large templates should prefer a `spawn_region_size` at least as large as `template.size + padding` so region scans remain bounded and deterministic.
