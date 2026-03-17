# Summary of Units and Unit Behavior

## UI
- Factions may only issue orders to units they own.
- Each unit can be selected by clicking on it.
- When a unit is selected, a path can be drawn to a target location by right clicking on the globe.
- The path will be drawn as a yellow line.
- The unit will move along the path to the target location.
- Units may not occupy the same tile as another unit. The "tile" here means the central 1/3 of a unit, which matches the size of the center of a city tile.


## Deployment Limitations
- Units may only be deployed into controlled cities.
- A city may only deploy one unit at a time.
- A city may only deploy a unit if it is not currently in a production cooldown.
- A city may only deploy a unit if there is physically room to deploy the unit within the 3x3 bounding box of the city. For example a city "fully occupied" by 9 units cannot have another unit deployed to it.
- Land units deploy to any of 3x3 tiles that make up the city tile.
- Sea units deploy to any of the 3x3 tiles that are overlapped with ocean or lake terrain ("docks").

## Land Units

### Health
- All units have a health value. 
- When a unit takes damage, its health is reduced.
- When a unit's health reaches 0, it is removed from the game.
- The default health of a unit is 100.
- A health bar will be displayed on the top of the unit to show it's heath. Full health is green, and it turns red as it approaches 0.

### Combat
- When overlapped with any other land unit with more than it inflicts damage on the unit adjacent to it.
- Adjcancy is determined by distance. If the distance between two units is less than the sum of their radii, they are adjacent.
- A land unit may only inflict damage on one unit at a time.
- A unit that is taking damage will show a brief orange flash and a short sound.
- A unit engaged with an enemy unit will show a small black arrow in the top left corner of the unit. The arrow will point in the direction of the engaged unit.
- A land unit engaged in combat will move at 25% normal speed.



### Movement
- The base rate of movement on land will be 1 unit width per 10 seconds.
- A land unit may not overlap the center tile of another unit, where the center tile is the center of the unit's 3x3 bounding box.

#### Terrain Effects Chart (TEC)
Unit | Terrain | Movement Modifier
---|---|---
Infantry | Plains | 1
Infantry | Forest | 0.5
Infantry | Jungle | 0.25
Infantry | Desert | 0.5
Infantry | Mountains | 0.1
Infantry | Polar | 0.25
Infantry | City | 1

### Infantry
- Infantry units have a relative movement rate of 1.
- Infantry will inflict 15 damage per 5 seconds on units it is engaged with.
- Infantry units that remain motionless for 30 seconds become entrenched. An entrenched unit reduces incoming damage by 50%. Moving that unit will break the entrenchment. Entrenched units have a solid dark green bar at the bottom of their unit icon image.
- Infantry units cost 10 credits to purchase.