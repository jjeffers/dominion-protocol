This distribution logic creates a "Deep Logistics" game. By pushing oil away from cities, you force players to extend their supply lines into potentially hostile or neutral territory. The "Cluster" rule creates high-value strategic zones—like the Middle East in your 1986 scenario—that become natural flashpoints for the Cold War influence phase.

Here is the algorithmic step-by-step for the **Global Resource Distributor** to meet these specific constraints.

---

## 1. The Distribution Algorithm

Since you have a $7:1$ ratio, the first step is to count your total cities ($N$). You will then need to place $R = N / 7$ oil resources.

### Phase A: Candidate Filtering

1. **Exclude Oceans:** Filter your `tile_catalog` for only those with `terrain != "Ocean"`.
2. **Buffer Zones:** Identify all tiles that are within $D$ tiles of a city. For your "further away" rule, $D$ should be roughly 10–15 tiles. These tiles are marked as **Low Priority**.
3. Favor desert regions. Add a bias towards arid areas like desert terrain.
4. Each continent will have at least 1 oil resource.

### Phase B: Cluster Generation

To handle the "2–3 resource clusters" without adjacency:

1. **Seed Selection:** Pick a random high-priority tile (far from cities) as the "Cluster Lead."
2. **Member Placement:** * Pick a second (and potentially third) tile that is **3–5 tiles away** from the lead.
* Use a `Breadth-First Search` (BFS) to ensure the path between them is entirely land.
* **Constraint Check:** Ensure no two oil resources in the cluster are **adjacent** (Distance $> 1$).



### Phase C: Lone Resource Scattering

Fill the remaining $R$ quota with single oil resources scattered across the landmasses, maintaining a minimum distance from both cities and existing clusters to prevent "Logistics Bloat."

---