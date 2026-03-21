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
    - A 5-second delay is counted down, then the nuclear weapon hits.
     - A black grey circle is shown on the global map immediately after launch, and it expands to the radius of the blast over 1 second.
    - The black "nuke zone" fades after a few seconds.
    - Any and all units (sea, air, and land) are killed within radius of 1.5 unit widths of the targe location.
    - Land and sea units between 1.5 and 2.0 unit widths receive damage equal 90 health, scaled down to 10 health at 2.0 unit widths.
    - The original 1.5 radius blast circle converted land terrain to WASTELAND, and converts both CITY and DOCKS to RUINS.
    - A news message is displayed to all players indicating the launch of the nuclear weapon and the target location.

## WASTELAND and RUINS
- Units in these terrains suffer attrition at 5 health per 30 seconds.
- RUINS and WASTELAND terrain cannot be repaired or rebuilt (they are permanent).
- RUINS prevent units from repairing.
- RUINS cannot be used for deployment.