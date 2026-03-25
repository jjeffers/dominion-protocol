# Dominion Protocol: Player Manual

## Overview
Dominion Protocol is a global strategic wargame where you command land, sea, and air forces on a discrete global grid representing the Earth. Your strategic objective is to capture enemy cities, maintain your economy, eradicate your opponents, and achieve absolute global victory.

## The World Map
The game environment uses a global grid to represent the earth interactively. 
- **Terrain Types**: Each hex is assigned a primary terrain type with specific strategic effects.
  - **Plains**: Standard movement speed, standard defense.
  - **Forest & Jungle**: Reduced movement speed, enhanced defense bonuses.
  - **Mountains**: Heavily reduced movement speed, significant defense bonuses.
  - **Ocean & Lakes**: Only traversable by Sea units, or Land units that embark into "SEA TRANSPORT" mode.
- **Cities**: Vital infrastructure nodes. Cities generate continuous income, heal damaged land units stationed within them, and act as deployment anchor points for newly purchased reinforcements.

## Economy & Deployment
Capturing and maintaining territory is the lifeblood of your war machine.
- Every city you control passively generates **1 credit every 5 minutes**.
- Press the **'P'** key to open the Purchase Menu. 
- Once a unit is purchased, you must deploy it to a friendly, controlled city. 
- A city is placed into a **5-minute manufacturing cooldown** after deploying any unit, preventing consecutive rapid drops. You also cannot deploy into a city if its physical space (a 3x3 grid) is completely blocked.

## Units
You can purchase and deploy three classes of core units: Land, Sea, and Air forces.

### Land Units
- **Infantry (Cost: 5)**: Represents ground troops and basic logistics. They move at a standard pace. If infantry remain completely stationary for 30 seconds, they become *Entrenched*, allowing them to absorb 50% less incoming damage until they move again. When an infantry unit is engaged in active combat, it becomes *pinned* and stops moving entirely.
- **Armor (Cost: 10)**: Fast mechanized forces and tanks. They move 2.5x faster than Infantry and deal significantly more damage. Armor units are *never pinned* in combat, meaning they can push through enemy lines, but they also cannot entrench.

### Sea Units
- **Cruisers (Cost: 50)**: High-speed naval vessels. They can only traverse Ocean and Lake tiles (or dock at coastal cities). Cruisers excel at off-shore bombardment, inflicting heavy damage from a 1.5 unit range against both naval and ground targets.

### Air Units
- **Air Bases (Cost: 30)**: Air units station permanently at your cities and project a massive Operations Radius around themselves. Air units don't have health—they are either **READY** or **UNREADY**.
- **Air Strike (Hot Key 'A')**: Target enemies within the air unit's radius. Ground strikes strip 50% of the target's total maximum Health, while sea strikes deal a flat 35 damage. Air strikes instantly turn the attacker UNREADY.
- **Redeploy (Hot Key 'R')**: Transfers the air base to another friendly city up to 10x the operational radius.
- **Dogfights & Interception**: If your air strike enters an enemy Air unit's operational radius, there is a chance they will intercept you. Depending on the dice roll, your strike may succeed, randomly abort, or your aircraft may be shot down. If your intercepting air unit is caught while UNREADY, it suffers massive interception capability penalties.

## Movement
Select any unit you own by `Left-Clicking` on it. Once selected, `Right-Click` anywhere on the globe to issue an automated movement order. 
- A designated yellow path traces their intended route.
- Land units embarking into the ocean automatically swap into "SEA TRANSPORT" mode. While seaborne, they move faster but suffer extreme defensive vulnerabilities in combat.

## Diplomacy & Neutral Countries
The global stage includes neutral countries that can be swayed to join your faction or pushed to align with your enemies. A list of all countries and their diplomatic opinion (ranging from +100 to -100) is displayed on your screen.
- **Neutrality & Alignment**: At the start, most countries have a diplomatic opinion of 0. If a country's opinion of your faction reaches 50, they align with your faction. This grants you their city revenue, production capabilities, and access to their cities for repairs and air bases. If their opinion drops below 50, they become neutral again. If it drops below -50, they align with an enemy faction.
- **Violating Neutrality**: Moving land units into a neutral country without aligning them first violates their neutrality, causing their opinion to decay rapidly (10 points every 10 seconds). Capturing a neutral city immediately drops their opinion to -100, instantly aligning them with an enemy faction.
- **Foreign Aid**: For 10 credits, you can purchase Foreign Aid to improve diplomatic relations. Delivering aid to a country shifts their opinion in your favor (the total shift is 100 divided by the country's total number of cities). This can be used to peacefully align neutral countries to your side or pull enemy-aligned countries away from your rivals.

## Combat Mechanics
Combat resolves automatically in real-time. 
- "Engaged" status occurs the second a unit physically overlaps the engagement boundaries of an enemy.
- Engaged units constantly inflict incremental damage on each other every 5 seconds.
- Damage taken is actively scaled by the terrain the defending unit sits on (e.g. holding a mountain pass mitigates intense casualties). 
- Units flash orange with corresponding audio cues when taking hits. Destroyed units are permanently removed from the map.
- While under heavy fire on land, active movement speed is drastically reduced by 75%.
- Friendly land units will slowly regenerate 10 HP every 30 seconds if resting safely inside a friendly city while avoiding combat.

## Capturing Cities
Cities dictate control of the game board. 
- A city instantly flips allegiance when an allied unit secures the center 3x3 tiles without any enemy units remaining in those same bounds.
- Capturing a city instantly grants you its resource benefits, flips the surrounding region's borders to your color, and instantly destroys any docked enemy Air Units previously stationed there.

## Achieving Victory
Dominion Protocol is won through capital supremacy. 
- By methodically dismantling the enemy war machine and executing a successful siege on their **Capitol City**, that opposing faction is permanently eliminated.
- When all adversaries are wiped off the globe and only one faction remains standing, absolute global victory is achieved.
