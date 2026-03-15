# Rule: Read Lessons Learned
**Trigger:** Whenever generating 3D rendering logic, programmatic textures, or spherical Sprite3D placement in Godot.
**Action:**
1. The agent MUST read `LESSONS_LEARNED.md` located in the root of the repository before suggesting implementation strategies for programmatic un-imported ImageTexture regions or planar objects hugging a sphere.
2. The agent MUST use `no_depth_test = true` when overlaying 2D elements like Labels or Sprites on procedurally displaced terrain to prevent 3D clipping.
3. The agent MUST verify sprite tile resolutions mathematically against the source image bounds (i.e. if row 16 exists on a 512px height image, tiles are 32px, not 16px).

**Invariants:**
- Do not use `region_enabled` for un-imported run-time texture loading. Crop the texture externally (e.g., ImageMagick) before allocating it into `Image.new()`.
- Keep Sprite3D on `AXIS_Z` when using `look_at(Vector3.ZERO)` to map the image tangentially flat against the surface of a globe. DO NOT use `AXIS_Y`, as it will stand the image edge-on radially.
