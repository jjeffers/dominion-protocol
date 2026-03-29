# Oil Resources
- Locations are taken from the oil data json file.
- Each oil resource is associated with a region, just like a city, and that region is labelled the same as the oil resource name.
- All oil resources are assigned to an adjacent country.
- Each oil location is captured just like a city - a land unit must occupy the same "tile" as the oil resource for 30 seconds.
- Each oil resource is associated with a region around it.
- If an oil resource is adjacent to one or more conutries, the oil resource and its region is assigned to one of those countries randomly.
- Oil consumpion:
    - Infantry: consume 1 oil per 10 seconds.
    - Armor: consume 2 oil per 10 seconds.
    - Air Units: consume 3 oil per 10 seconds.
    - Cities: consume 2 oil per 10 seconds.
- Factions may begin with oil resources depending on the scenario.
- Once an oil resource is captured or if it is owned, it produces 25 oil per 10 seconds.
- Oil is stored in a global variable for each faction.
- There is no limit on the oil that can be stored.
- The current oil production and consumption is displayed in the game status panel.
    - The oil status is displayed as a fraction: production / consumption / stored. All values are integers.

# Effects of Oil Shortages
- When a faction has no oil in storage, and the rate of conumption is greater than production, that faction suffers the following penalties:
    - Infantry unit movement rate is slowed by 50%.
    - Armor unit movement rate is slowed by 200%.
    - Air unit readiness cooldown is increased by 200%.
    - City credit production is reduced by 90%.
- When a faction oil storage is 0, the number in the display is red.