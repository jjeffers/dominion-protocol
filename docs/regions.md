## Technical Design: Weighted Voronoi Territorial Partitioning

This document details the process for subdividing a global quad-sphere grid into distinct administrative regions based on city locations and geographical resistance.

---

### 1. Conceptual Overview

Unlike a standard Voronoi diagram that uses Euclidean distance, a **Weighted Voronoi Partition** uses a cost-based "Flood Fill." Territory expands from city seeds until it hits a natural boundary or a competing claim. This ensures that a desert or mountain range acts as a logical limit to a city's influence.

### 2. The Resistance Matrix

Every tile in the global catalog is assigned a **Resistance Value ($R$)** based on its topography and terrain type. This value acts as a multiplier for the "cost" of claiming that tile.

| Terrain Type | Resistance ($R$) | Logic |
| --- | --- | --- |
| **Plains** | 1.0 | High infrastructure potential; easy to control. |
| **Woods** | 2.5 | Natural cover slows administrative expansion. |
| **Desert/Vast** | 10.0 | Logistics nightmare; serves as a natural border. |
| **Mountain** | 15.0 | Hard barrier; territory usually stops at the foothills. |
| **Ocean** | $\infty$ | Territorial regions are clamped to landmasses. |

---

### 3. The Expansion Algorithm (Dijkstra-Based BFS)

The partitioning is performed during the pre-bake phase using a priority-queue-based expansion.

#### A. Initialization

1. **Seed Points:** Every city is assigned a unique `Region_ID`.
2. **Priority Queue:** A queue is populated with all city tiles. Each entry contains `(Current_Cost, Tile_ID, Origin_City_ID)`.
3. **Cost Map:** A global array tracks the lowest cost to reach each tile, initialized to infinity.

#### B. The Propagation Loop

While the queue is not empty:

1. Pop the entry with the **Lowest Current Cost**.
2. For each **Neighbor** of the current tile (using the Quad-Sphere edge-stitching logic):
* Calculate `New_Cost = Current_Cost + Neighbor_Resistance`.
* **Sovereignty Check:** If the Neighbor’s `Country_ID` is different from the Origin City's `Country_ID`, the `New_Cost` is multiplied by 100 (preventing border bleeding).
* **Comparison:** If `New_Cost` < `Lowest_Cost_Map[Neighbor]`:
* Update `Lowest_Cost_Map[Neighbor] = New_Cost`.
* Assign `tile_catalog[Neighbor].region_id = Origin_City_ID`.
* Push `(New_Cost, Neighbor, Origin_City_ID)` to the queue.





---

### 4. Special Constraints & Edge Cases

#### Natural Boundaries

By setting Desert and Mountain resistance significantly higher than Plains, the algorithm naturally creates "dead zones" or borders that align with geographical features. A city on the edge of the Sahara will claim the fertile coast quickly, but struggle to claim the deep desert tiles if another city exists on the opposite side of the sands.

#### Territorial Enclaves

If a landmass has no city, it remains "Wilderness" (Unassigned) unless a city is manually flagged as a "Regional Hub" to claim distant islands or uninhabited zones.

---

### 5. Data Integration & Gameplay Usage

#### The Baked Dataset

The final `face_catalog` stores the `region_id` as a static integer or string. This allows for $O(1)$ lookup during gameplay.

#### Gameplay Logic: The "Chain Capture"

When a city's status changes to `Captured`:

1. **Trigger:** `on_city_captured(city_id, new_faction)`
2. **Execution:**
```gdscript
# All tiles in the pre-baked region flip simultaneously
for tile in face_catalog.values():
    if tile.region_id == city_id:
        tile.controller_faction = new_faction
        # Update UI/Shader to reflect the new color

```
