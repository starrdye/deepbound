# Deepbound Art Bible

## 1. Core Visual Pillars
* **Readability Over Detail:** In a chaotic sandbox where players are mining and fighting simultaneously, the silhouette of an enemy or the boundary of a tile must be instantly recognizable. 
* **The Descent:** The deeper the player goes, the more the visual language shifts from familiar and earthy to alien, hostile, and luminescent. 
* **High Contrast:** Important interactive elements (ores, enemies, dropped loot) must pop against the dark, earthy backgrounds using saturated, high-value colors.

## 2. Technical Specifications
* **Base Resolution:** 16x16 pixel grid for standard tiles (dirt, stone, wood).
* **Character Sprites:** 24x32 or 32x32 pixels to allow for expressive animations and visible equipment changes.
* **Upscaling:** Assets should be drawn at native resolution and scaled up by integers (e.g., 300% or 400%) in-engine to maintain perfectly sharp, unblurred square pixels.
* **Color Palette:** Establish a master indexed color palette to ensure cohesive harmony across all assets.
* **Outlines:** Use dark, colored outlines (not pure black) for characters and enemies to separate them from the background. Terrain tiles should generally not have outlines.

## 3. Environment & Terrain Pipeline
* **Autotiling System:** Tiles must be designed in a standard 47-tile or 16-tile bitmask format to allow the engine to automatically draw corners, edges, and inner blocks as the player excavates.
* **Background Walls:** Player-placed and natural background walls must be shaded darker and use lower-saturation colors than foreground blocks to create depth.
* **Parallax Depth:** The deep background (behind the playable layer) should consist of 3 to 5 distinct parallax layers that scroll at different speeds to give the cavernous voids a sense of massive scale.

## 4. Biome Aesthetic Guidelines
The commercial art direction uses five strict horizontal Band palettes. Each Band must remain readable at `300%` and `400%` integer scale, with high-value interactive objects popping against darker terrain and walls.

* **Band 1: Standard Caverns:** Earth browns, cool stone grays, brass lamp accents, and small copper highlights. Keep shapes familiar and readable.
* **The Colossal Ant Chambers:** Warm, sickly colors. Amber, mustard yellow, and deep resin browns. Tiles should look organic, rounded, and slightly translucent.
* **Buried Pyramids:** Desaturated sand tones, cracked sandstone, and oxidized copper greens. Sharp, geometric, right-angled tiles contrasting with the natural caves.
* **Drow Enclaves:** Cool, ethereal palettes. Deep indigo, bioluminescent cyan, and violet. Flora should emit soft glow maps, making the environment the primary light source.
* **The Abyssal Lava Rivers:** Harsh, aggressive lighting. Pitch-black obsidian tiles cracked with glowing crimson and neon orange. Heat-distortion shader effects near the lava surface.
* **The Obsidian Slums:** A subregion of Band 5. Use forged scrap silhouettes, hanging settlements, lava-lit edges, and hostile industrial UI motifs.
* **Solid Dark Blocks:** Near-black blue-violet material with tiny cold highlights. They absorb light and should look heavy, ancient, and almost unreadable without becoming pure black rectangles.

## 5. Character & Entity Design
* **The Player ("Delver"):** Requires a modular sprite system. The base body template must be divided into Head, Torso, Arms, and Legs to allow overlapping armor sprites. 
* **Armor Progression:** Early gear should look makeshift (mining hats, leather padding). Late-game gear should draw inspiration from heavy mecha or specialized deep-sea diving suits to sell the extreme hostility of the lower depths.
* **Enemies:** Must have distinct silhouettes and telegraph their attacks with exaggerated keyframes. A lost mummy should shamble stiffly, while a tunneling worm should have fluid, segmented movement.

## 6. UI & HUD Aesthetics
* **Minimalist Intrusion:** The UI must not obscure the gameplay. Keep the hotbar and health indicators locked to the screen edges.
* **Crisp Vector Rendering:** To keep menus, inventory grids, and text infinitely scalable and crisp against the chunky pixel art, consider rendering the UI overlays using a custom SVG layout engine. 
* **Thematic Elements:** UI panels should resemble raw materials—stone tablets, forged iron borders, or glowing crystal displays depending on the player's crafting tier.
