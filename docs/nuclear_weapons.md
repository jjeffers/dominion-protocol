# Nuclear Weapons
- Available for purchase for 20 credits.
- Each faction shall have an inventory of purchased nuclear weapons, or an amount set by the scenario to start.
- The amount is displayed in the game status panel along with the city coun and credit balance.
- When a faction purchases the nuclear weapon, it is added to their inventory.
- When a faction has a positive nuclear weapon balance, a key hint is shown on the bottom of the display, where "N" is the key used to launch the weapon.
    - Target Restrictions:
        - Enemy capitols are protectd by strong SDI/ABM systems in a 1.5 unit width radius around the capitol.
        - A faction may launch no more than 3 nuclear weapons more than any other faction has launched.
    - When launched, the target reticle image is shown in red and it follow the mouse position.
    - When the left mouse button is clicked, the nuclear weapon is launched at the target location.
        - The launchig faction inventory is reduced by 1.
        - A nuclear weapon alarm is played for all players. The sound asset is "nuke-alert.mp3".
        - A news message is display "NUCLEAR WEAPON LAUNCH DETECTED"
    - A 10-second visual fireball effect is triggered upon successful strike impact.
    - An emissive orange sphere expands to the primary blast radius over 0.5 seconds, then cools into a grey ash cloud while swelling to the secondary radius and fading out over the remaining 9.5 seconds.
    - Any and all units (sea, air, and land) are killed within radius of 1.35 unit widths of the targe location.
    - Land and sea units between 1.35 and 2.25 unit widths receive damage equal 90 health, scaled down to 10 health at 2.25 unit widths.
    - Terrain within the 1.35 unit width blast zone is permanently converted to WASTELAND, and converts both CITY and DOCKS to RUINS.
    - A news message is displayed to all players indicating the launch of the nuclear weapon and the target location.
    - Cities struck by a nuclear weapon have a production cooldown increase of 10 minutes, and the owning player loses 10 credits.

## WASTELAND and RUINS
- Units in these terrains suffer attrition at 5 health per 30 seconds.
- RUINS and WASTELAND terrain cannot be repaired or rebuilt (they are permanent).
- RUINS prevent units from repairing.
- RUINS cannot be used for deployment.
- RUINS and WASTELAND have the same movement penalties as DESERT.