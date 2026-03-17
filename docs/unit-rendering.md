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