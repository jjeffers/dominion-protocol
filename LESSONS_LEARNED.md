# Lessons Learned: 3D Globe Web App rendering in Godot 4 Headless

Throughout our development on dynamic spherical plotting mapping and texture mechanics, several key structural lessons were learned:

## 1. Spritesheet Mathematics
When the user says "the 16th row", do not assume the pixels are 16x16 on a 512x512 spritesheet. 512 / 16 rows = 32 pixels. Ensure your math scales match properly (e.g. `32x32`) when cropping images or sizing objects programmatically with `pixel_size`.

## 2. Dynamic Image Loading & Region Slicing
Loading raw `ImageTexture` objects programmatically with `Image.new()` and `ImageTexture.create_from_image(img)` from an un-imported source image avoids Godot editor cache issues during headless dev, BUT setting `region_enabled = true` and `region_rect` on these raw un-imported textures fails to render sub-tiles properly without VRAM metadata.
* **Fix**: Mathematically crop the source frame you need externally using ImageMagick (e.g. `convert src/assets/spritesheet.png -crop 32x32+0+480 out.png`) and explicitly load the exact single-tile image buffer into memory.

## 3. Depth Sorting Over Displaced Terrain
When placing 3D marker objects (like `Sprite3D` or `Label3D`) directly onto mathematical sphere coordinates (like `radius * 1.02`), they can accidentally sink and clip inside randomized procedural displacement shader noise (mountains popping up to a radius of 1.15).
* **Fix**: Apply `no_depth_test = true` and `render_priority = 10` (or higher) to guarantee that markers or labels visually composite fully over the topographic geometry regardless of how deep they clip.

## 4. Facing Spherical Tangents (Sprite Axes)
When telling a `Sprite3D` to lay flat against the surface of a globe by using `city_node.look_at(Vector3.ZERO)`, the default `Sprite3D` axis is `AXIS_Z`, which points through its planar face. This perfectly aligns it parallel wrapping the terrain. 
* **Warning**: Attempting to "fix" the orientation by flipping it to `AXIS_Y` points its edge vector toward the core instead, standing it straight up paper-thin along the radial boundary, which renders it mathematically invisible width-wise to a top-down orbital camera. Always leave mapping overlays on `AXIS_Z` when looking at the core.

## 5. Headless Asset Importing
When generating new assets (like audio files or textures) programmatically via scripts or external tools while the game engine is running, Godot does not automatically generate the required `.import` metadata files if it is not running in editor mode.
* **Fix**: If an asset is missing its loader or fails to load, close the game client and boot the engine briefly in headless editor mode (`godot --headless --editor --quit`). This forces the engine to scan the filesystem and generate all necessary `.import` files before booting the game binary again.

## 6. Passive SceneTree Scanning and Programmatic Unit Loading
When script-instantiating custom `Node3D` actor classes mathematically to plot them on a globe via `GlobeUnitScript.new()` and `add_child(unit)`, the engine's built in `_ready()` function may not consistently fire before those units are needed by early physics or passive scanning loops elsewhere in the scene. 
* **Warning**: If units add themselves to necessary targeting or collision groups (e.g., `add_to_group("units")`) inside `_ready()`, they will be functionally invisible to organic `get_nodes_in_group` loops during their first few vital configuration frames.
* **Fix**: Always assign fundamental group identifiers and initial variable scaffolding directly inside `_init()`.

## 7. Headless Script Parsing Cache & Freed Pointer Iteration
When running Godot dynamically from the command line, particularly in headless multiplayer or testing routines, "Black Screens" where the scene loads but scripts fail to function are usually indicative of a Silent GDScript Parse Error somewhere in the preload dependency tree. 
* **Warning 1**: Godot 4's `Object.get("property")` strictly accepts exactly one argument. Calling `unit.get("faction_name", "")` with a default fallback (permitted in older syntax styles) will trigger a fatal parser compiler error: `Too many arguments for "get()" call`.
* **Warning 2**: Godot aggressively caches its `.godot/` internal global script classes map. If you introduce a severe typo into a core autoloader class and immediately launch the game binary, Godot might fail repeatedly even *after* you fix the typo because the cached mapping still points to the broken compiler pass. You MUST boot the engine briefly in headless editor mode (`godot --headless --editor --quit`) to regenerate the script cache and clear the corrupted memory.
* **Fix**: If the level successfully builds but the screen goes completely blank while scripts execute, check your `_process()` array iteration loops! If an object calls `queue_free()` (like a dying unit), but the main engine `GlobeView` continuously loops over `units_list` to check their faction, it will instantly crash the rendering loop on the now-freed pointer throwing: `Cannot call method 'get' on a previously freed instance.`. ALWAYS wrap array iteration loops reading custom objects continuously across frames with `if not is_instance_valid(obj): continue`.

## 8. Headless Texture Cache Invalidation
When modifying existing `.png` image files (like a spritesheet) from the command line while Godot instances are running or outside the Engine Editor, the game binary (`godot --client`) will NOT automatically re-compile the updated art into the internal `.godot/imported/*.ctex` cache format. It will silently load the stale, outdated visual artwork from the cache indefinitely.
* **Fix**: To force Godot to realize the `.png` has changed and re-import it without opening the UI editor, you must either run `godot --headless --editor --quit` or explicitly delete the stale cache file from the internal `.godot/imported/` directory before launching the game binary.

## 9. Network Flooding & Engine Freezes from Infinite Pathfinding
When mapping logic (like a Nuclear Strike) modifies the terrain grid dramatically (e.g. converting a City to Ruins), units currently pathfinding to that destination may have their physical trajectories blocked. The local navigation math will accurately detect the blockage and securely strip the unit's active destination to prevent physical clipping.
* **Warning**: If controlling AI nodes continuously monitor this stripped state and blindly reissue a brand new `rpc` synchronization command to the exact same blocked target every frame, it will trigger an invisible network flood. At 60 FPS, 20 AI units re-issuing target RPCs will generate 1,200+ outbound packets per second. This completely exhausts ENet's egress buffers, freezing the Host's main thread and permanently crashing the local simulation loop without logging errors.
* **Fix**: Always implement an explicit rate-limit or local transmission debounce inside functions that broadcast spatial sync RPCs (`Time.get_ticks_msec()`). Caching the `last_ordered_target_pos` and suppressing redundant transmissions prevents the AI from DDOS-ing its own host server when pathfinding math encounters legitimate impasses.
