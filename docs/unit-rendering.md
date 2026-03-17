# Unit Rendering Guide

## Basic Rules
- Every unit is represented on the global map as a `unit icon`
- A `unit icon` is made up of the following elements:
    - a base image, which is 32x32 pixels with a transparent background, which is a visual representation of the unit type (infantry, armor, sumbarine, etc)
    - a solid white backround when the unit is on land, or a solid colored background where the color matches the ocean/lake color whent the unit is seaborne (on ocean/lake)
    - colored border around the edge of the 32x32 area
    - a health bar, which is displayed across the "top" of the icon, just below the top border.
        - the health bar is green at full health and then becomes red when on low heath, moving between colors on a gradient as heath degrades.
    - an enegagement arrow, which points towards the unit's current damage target when the unit is engaged in combat, is renderd on the left middle side of the icon
    - an entrenchment bar, a dark green bar across the bottom of the icon just above the bottom colored border

- Units have a visual "stacking order":
    - units "on top" are fully displayed
    - units "below" other units are partially obscured to the viewer
    - obscured unit icons (and any associated components) will be visually masked by other unit icons
    - it's possible that unit interaction, like selection by a user or that unit taking damage, will "pop" that unit to the top of the visual rendering order 


## Movement Indicators
- Units that have been given an order will project a movement arrow showing their current movement target.
- The target of a movement order (a position on the map) will be indicated by the target bracket, which is centered on the map over the movement target.
- The movement arrow is a semi-transparent line that extends from the unit to its target.
- The movment arrow is no more than 1/3 of a unit icon in width.
- Factions only see movement arrows for their own units.