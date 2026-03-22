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
- A victory screen will be displayed showing the winner, "RED WINS".


## Scenario: Initial test
- Cold war: no
- Factions:
    - Blue
        - cities: London, Paris, Luxembourg, Brussells, Marseilles, Geneva,Amsterdam
        - oil: none
        - fuel: none
        - money: 0
        - units: infantry (London), infantry (Paris), infantry (Luxembourg), infantry (Brussels), infantry (Marseilles), infantry (Amsterdam)
    - Red
        - cities: Hamburg, Berlin, Munich, Prague
        - oil: none
        - fuel: none
        - money: 0
        - units: infantry (Hamburg), infantry (Munich), infantry x7 (spread out along the border between Red and Blue regions)
