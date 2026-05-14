# Deepbound

## 1. Core Concept & Pitch
**Deepbound** is a 2D pixel-art sandbox adventure game featuring an infinitely generated, fully destructible world. While games like Terraria split their focus between the surface and the underground, *Deepbound* forces players to look downward. The surface is merely a barren starting point; the true game, its lore, and its sprawling civilizations exist entirely beneath the crust. 

**Tagline:** *The deeper you dig, the more alive it gets.*

## 2. Core Mechanics

### 2.1 The Mapped Descent: 5 Horizontal Bands
In-world legends still describe the deep as infinite, but the commercial game focuses on the known mapped descent: five strict horizontal Bands and a final late-game boundary of Solid Dark Blocks. Horizontal generation remains unbounded so the player can keep exploring left and right, while vertical progression is paced through authored ecosystems.
* **Band 1: Standard Caverns (`tileY 0-383`):** Dirt, compacted earth, soft stone, copper, starter skitters, and the first light-management pressure.
* **Band 2: Colossal Ant Chambers (`tileY 384-767`):** Resin structures, excavated earth, pheromone trails, royal jelly pockets, and caste-based enemies.
* **Band 3: Buried Pyramids (`tileY 768-1151`):** Sandstone tomb networks, traps, cursed treasure, and mummy patrols.
* **Band 4: Drow Enclaves (`tileY 1152-1535`):** Bioluminescent mushroom forests, shadow cities, diplomacy pressure, and ambush hunters.
* **Band 5: Abyssal Lava Rivers / Obsidian Slums (`tileY 1536-1919`):** Magma highways, heat pressure, obsidian settlements, and hostile outcasts.
* **Solid Dark Blocks (`tileY >= 1920`):** Ultra-dense, light-absorbing material that forms the final boundary and late-game mystery.
* **Total Destructibility:** Most foreground terrain can be mined, blown up, or manipulated. Solid Dark Blocks are the exception: they are a narrative and mechanical boundary until Phase 3 late-game systems.

### 2.2 Subterranean Ecosystems
The underground is not just dirt and stone; each Band has its own ecology, hazards, palette, resources, enemies, and boss arc. Earlier biome concepts are preserved as Band identities or subregions inside the mapped descent.

## 3. Gameplay Systems

### 3.1 Excavation and Traversal
* **Drilling over Swinging:** While traditional pickaxes exist, progression quickly moves to pneumatic drills, tunneling machines, and explosives. 
* **Rappelling & Grappling:** Vertical movement is crucial. Players craft ropes, pitons, and eventually mechanical grappling hooks and jet boots to navigate massive chasms.

### 3.2 Lighting and Visibility
Light is a primary resource. The deeper you go, the darker it gets.
* **Dynamic Darkness:** Monsters spawn in unlit areas.
* **Light Sources:** Flares, luminescent flora, glowing ores, and eventually deployable floodlight networks powered by underground geothermal generators.

### 3.3 Camp-Building & Outposts
Instead of building one massive surface base, players must establish a network of subterranean outposts.
* **Structural Integrity:** If players mine out too large of a cavern without building support beams, cave-ins can occur in highly pressurized lower levels.
* **Automation:** Players can build automated minecarts and vertical elevators to transport resources back to their primary hub.

## 4. Combat and Encounters
* **Directional Combat:** Melee, ranged, and magic combat tailored for tight tunnels and expansive caverns. 
* **Ambushes:** Enemies can dig through soft blocks to ambush the player. A pack of tunneling worms might sense the vibration of the player's drill and close in.
* **Boss Encounters:** Triggered by environmental interaction (e.g., stealing the Pharoah's Crown from a buried pyramid, or cracking the core of a geothermal vent).

## 5. Narrative & Lore
The world above was rendered uninhabitable centuries ago. Humanity survived by diving into the crust. However, they soon discovered they were not the first to do so. The player is a "Delver," tasked with mapping the infinite deep, discovering lost civilizations, and finding the mythological "Core" which supposedly holds the power to restore the surface.

## 6. Art & Audio Direction
* **Visuals:** High-fidelity 2D pixel art. Distinct color palettes for biomes (neon blues/purples for Drow forests, harsh reds/oranges for lava rivers, sickly yellows for ant hives).
* **Audio:** Deep, reverberating sound design. The echoing "clink" of a pickaxe, the distant rumble of moving magma, and dynamic, atmospheric chiptune/synth music that shifts seamlessly based on depth and danger.
