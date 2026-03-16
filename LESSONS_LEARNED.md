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
