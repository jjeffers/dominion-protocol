# Scenarios
- The game will support scenarios [future release].
- A scenario defines the following contraints:
    - Cold war period? If yes. the it also specifies the actuak time (in minutes) of the cold war.
    - If there is no cold war period, then the game starts with the "hot war" and all factions may attack each other.
    - Factions: a list of factions.
    - City list: a list of cities for each faction.
    - Oil list: a list of oil fields for each faction.
    - Starting money and fuel levels.
    - Neutral cities: a list of cities that are not owned by any faction.
    - Any oil not listed in the faction or neutral list is ommitted from the game, and is not visible to any faction. It's associated region is also not conquerable.
    
## Victory

- A faction wins when it controls all capitols of the other factions.
- When a faction loses all of its capitols, it is eliminated from the game.
    - All units of the eliminated faction are removed from the game.
    - All remaining cities become neutral independent regions.
- When only a single faction remains, it wins the game.
- A victory screen will be displayed showing the winner, "<faction name> WINS".

## Faction Starting Cities and Regions
- If the scenario does not specify any cities for a faction, then the game will randomly assign 2-3 cities to a starting faction.
- The location of the starting faction regions should be adjacent if possible, or as close as possible (if separated by bodies of water).
- Starting factions should be balanced in terms of starting proximity to cities, oil, and each other.
- Factions to be renamed will be assigned a name and abbeviation using the faction name generator.
- One city in the starting faction's cities will be designated as the faction's capitol.
- Suggested colors (if not specfied): Red, Blue, Gold, Green, Black, Purple, Orange, Yellow, Cyan, Magenta, White, Gray

## Scenario: Near Future World War
- Cold war: no
- Factions:
    - Faction 1 (to be renamed at start using faction name generator)
        - color: blue
        - cities: none (determined at start)
        - oil: 500
        - money: 100
        - units: none
    - Faction 2 (to be renamed at start using faction name generator)
        - color: red
        - cities: none (determined at start)
        - oil: 500
        - money: 100
        - units: none

## Scenario: Initial test
- Cold war: no
- Factions:
    - Coalition of Free States
        - abbreviation: CFS
        - color: blue
        - cities: London, Paris, Luxembourg, Brussells, Marseilles, Geneva,Amsterdam
        - oil: 500
        - money: 50
        - units: infantry (London), infantry (Paris), infantry (Luxembourg), infantry (Brussels), infantry (Marseilles), infantry (Amsterdam)
    - Central Security Pact
        - abbreviation: CSP
        - color: red
        - cities: Hamburg, Berlin, Munich, Prague
        - oil: 500
        - money: 40
        - units: infantry (Hamburg), infantry (Munich), infantry x7 (spread out along the border between Red and Blue regions)
