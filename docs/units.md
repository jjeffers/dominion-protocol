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
- All land and sea units have a health value. 
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

### Recovery
- A land unit recovers health at a rate of 10 points per 30 seconds if it is within the 3x3 area of a friendly city.
- Recovery only occurs if the unit is not engaged in combat and the unit is stationary.

### Movement
- The base rate of movement on land will be 1 unit width per 10 seconds.
- A land unit may not overlap the center tile of another unit, where the center tile is the center of the unit's 3x3 bounding box.
- A land unit may move onto ocean terrain: the unit becomes seaborne, which is indicated by it's status "MOVING" becomes "SEA TRANSPORT", and the base movement rate becomes 1.5.


### Infantry
- Infantry units have a relative movement rate of 1.
- Infantry will inflict 15 damage per 5 seconds on units it is engaged with.
- Infantry units that remain motionless for 30 seconds become entrenched. An entrenched unit reduces incoming damage by 50%. Moving that unit will break the entrenchment. Entrenched units have a solid dark green bar at the bottom of their unit icon image.
- Infantry units stop moving once they are engaged and cancel all movement orders. (They become *pinned*.)
- Infantry units cost 5 credits to purchase.

### Armor
- Armor units have a relative movement rate of 2.5.
- Armor will inflict 25 damage per 5 seconds on units it is engaged with.
- Armor units cost 10 credits to purchase.
- Armor units do not automatically stop once they become engaged. (They are never *pinned*.)


#### Terrain Effects Chart (TEC)
Unit | Terrain | Movement Modifier | Defensive Modifier 
---|---|--- | --
Infantry | Plains | 1 | 1 
Infantry | Forest | 0.5 | 0.75 
Infantry | Jungle | 0.25 | 0.5
Infantry | Desert | 0.5 | 1.0 
Infantry | Mountains | 0.1 | 0.50
Infantry | Polar | 0.25 | 1.0
Infantry | City | 1 | 0.50 
Infantry | Ocean | 1.5 | 1.5 
Armor | Plains | 1.5 | 1.0  
Armor | Forest | 0.5 | 0.75 
Armor | Jungle | 0.25 | 0.75 
Armor | Desert | 1.0  | 1.0
Armor | Mountains | 0.1 | 1.0 
Armor | Polar | 0.25 | 1.0 
Armor | City | 1.0 | 0.75 
Armor | Ocean | 1.5 | 1.5 

##### TEC Terms
- Movement Modifier: The factor by which the base movement rate is multiplied. For example, an armor unit on plains terrain has a movement rate of 1.5 * 1.0 = 1.5 unit widths per 10 seconds.
- Defensive Modifier: The factor by which incoming damage is multiplied. For example, an armor unit on plains terrain takes 1.0 * damage per 5 seconds on units it is engaged with. (Low numbers are better for the defender.)

## Air Units
- Air units do not have health, they have instead 2 states: READY and UNREADY.

- An air unit icon represents the "base of operations" for an air unit.
- Air units cost 30 credits.
- Air units have an operations radius of 10*(land unit icon width).
- When an air unit is selected, the UI draws a red circle centered on the air unit with a radius equal to the operations radius.

### Air Unit Visibilty 
- READY air units provide vision of all units within their operations radius.


### Air Unit Operations
- When an air unit is selected and and that air unit is READY, operations can be selectd by using the keyboard:
    - 'a' orders an AIR STRIKE.
    - 'r' orders a REDEPLOY.

#### AIR STRIKE
- When an air strike order is used, the air unit's operations radius wil show as a red circle centered on the air unit.
- AIR STRIKE orders targeting land units will do damage to the land unit equal to 50% of the target unit's health before applying any defensive modifiers.
- AIR STRIKE orders targeting sea units will do 35 points of damage.
- After the AIR STRIKE (successful or not) the air unit becomes UNREADY.

#### COUNTERING AIR OPERATIONS
- Enemy air units have a % chance to intercept AIR STRIKE operations within their operations radius.
    - The base % chance is linearly scaled based on the distance from the defending air unit to the location of the AIR STRIKE.
    - If there is more than one air unit can intercept the AIR STRIKE, the % odds are cumulative.
    - An UNREADY air unit has an interception % penalty of 90% (it becomes much less effective at interception).
    - If an INTERCEPTION occurs:
        - If mulitple air units can perform the INTERCEPTION, following sorting criteria is used:
            - READY air units vs UNREADY air units
            - air units closest to the AIR STRIKE 
        - Determine mission outcome:
            - 25% chance of mission success. The strike succeds, damage is inflicted. Enemy air unit is destroyed. Attacking air unit becomes UNREADY.
            - 50% chance of mission abort. No damage is done. Both air units become UNREADY.
            - 25% chance the attacking air unit is shot down (destroyed).
            - If the intercepting air unit is UNREADY the odds:
                - mission success odds increase to 90%
                - mission abort odds become 10%
                - 0% chance the attacking unit is shot down (destroyed)
        - If an UNREADY air unit participates in an INTERCEPTION, the amount of time to recover to the READY state increases by another 2 minutes.
    - If no INTERCEPTION or after INTERCEPTION occurs:
        - If attacking a land unit, outcome is:
            - 90% success. Damage is inflicted.The attacking air unit becomes UNREADY.
            - 9% mission abort. No damage is done, attacking air unit becomes UNREADY.
            - 1% chance of mission failue, no damage is done and attacking air unit is DESTROYED.
        - If attacking a cruiser the mission abort in increased to 25%, mission loss is 10%.
        

- UNREADY air units recover to READY status after 2 minutes.

#### REDEPLOY
- Choosing REDEPLOY will enter a mode where:
    - the redeoploy radius is indicated by a green circle centered on the city the air unit is in. The radius for the REDPLOY order is x10 the operations radius.
    - Eligible cities for REDEPLOY are marked with colored highlights where the color matches the faction color.
    - the reployment icon is shown following the mouse 
    - clicking on an eligble city will REDEPLOY the air unit to the city, placing that air unit into one of the 3x3 sections.  



### Air Units in Captured Cities
- Air units in cities that are captured are destroyed.

## Sea Units
- Sea units are never pinned by combat.

### Cruisers
- Cruisers cost 50 credits.
- Cruisers move with a relative move rate of 5.
- Cruisers have a combat engagement range of 1.5 unit widths (measured from the center of the unit icon).
- Cruisers may enage sea and land targets (off-shore bombardment).
- Cruisers inflict 30 points per 5 seconds.
- Cruisers may only move on ocean or lake terrain, or into city areas that are also on ocean or lake terrain (docks).
