# Saving and Loading Games

## Saving Games
- Any player may save a game in progress using any of the existing "Save Game" options in the settings menu.
- A save game persists the current game state into a file that a payer saves to a local file system.
- Game state data includes an inventory of the game state:
    - All factions
        - The faction name
        - The faction color
        - All units owned by the faction, their position, and status (health, engaged or not, current movement orders, in recovery, entrenched, cooldowns)
        - All cities (and regions) owned or controlled by the faction.
        - All oil resources (and regions) owned or controlled by the faction.
        - current credit balance
        - current oil storage
    - the current game time 
    - Each neutral country city list and regions, and their opinions of each faction.

## Loading Games
- A host may select a saved game to load from the start screen.
- After selecting a saved game, the game opens the lobby, and the faction list is presented as buttons for connected players to join each faction.
- Once at least one player has joined a faction, the game may be started.
- The game started reflected the game state loaded from the save file.