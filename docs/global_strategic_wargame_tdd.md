# Technical Design Document: Global Strategic Wargame

## 1. Core Map Architecture: The Discrete Global Grid

The game environment uses a **Discrete Global Grid System (DGGS)** to represent the earth as a series of interactable "global pixels."

* **Projection:** Utilizes an equal-area projection (like Cylindrical Equal-Area) to ensure that each pixel represents a consistent physical area, preventing the "Greenland Problem" where polar regions are unfairly distorted.
* **Terrain Abstraction:** Each pixel is assigned a primary terrain type with specific strategic effects:
  * **Plains:** Standard movement and fuel burn.
  * **Woods/Mountains:** Higher movement costs and defense bonuses for land units.
  * **Ocean/Lakes:** Requires units to enter a "Seaborne" state.
* **Center-Pixel Anchor:** Every unit uniquely occupies a **center pixel**. This anchor point determines the terrain type the unit is currently moving through and is the only point capable of capturing static cities or bases.

## 2. Unit Systems & Combat Logic

Units are multi-pixel entities that interact through spatial overlap in real-time.

* **Land Forces:**
  * **Infantry:** Low fuel consumption; can entrench over time when stationary to reduce incoming damage.
  * **Armor/Mechanized:** High movement rates but extreme fuel burn during combat and movement. These units suffer significant penalties in mountainous or wooded terrain.
* **Naval Forces:**
  * **Surface Fleets:** Can bombard adjacent land units and serve as the primary detection tool for submarines when stationary.
  * **Submarines:** Undetectable unless a surface unit is within range and stationary. They deal a "Huge Damage Chunk" if they overlap an undetected enemy fleet.
  * **Carriers:** Mobile airfields that house air units but are highly vulnerable (sinking in 3 hits).
* **"Inflict 1, Take Many" Rule:** Combat is calculated every time unit of overlap. A unit can only inflict damage on one enemy per tick but can receive damage from multiple enemies simultaneously.

## 3. Air Power & Force Projection

Air units are static assets based at cities, bases, or carriers. They operate within a defined **Radius of Operations**.

* **Mission Types:** Strikes against units, strategic bombing of cities to suppress production, resource sabotage, and reconnaissance.
* **Cooldown Mechanic:** After performing a mission or countering an enemy sortie, air units enter an "Unready" state for a prolonged period.
* **Damage Profile:** Air strikes against land units have diminishing returns (decreasing fractions of current HP), while strikes against sea units deal static damage.

## 4. Logistics & Economics

The game revolves around the control of static, non-creatable infrastructure.

* **Cities:** Generate **Money** for unit purchases and provide a "Healing Aura" for nearby friendly land units and docked ships.
* **Bases:** Serve as secondary deployment points but do not generate revenue.
* **Resource Points:** Provide the **Fuel** necessary for mechanized, armor, and naval operations. Sabotaging these points can paralyze an enemy's mobile forces.

## 5. Global Diplomacy & The Cold War Phase

Scenarios can begin with a timed "Cold War" phase focused on non-kinetic expansion.

* **Influence Bidding:** Factions spend money to gain influence in neutral countries. A country joins a faction only if there is a "clear margin" of influence based on the number of cities in that country.
* **Mobilization:** Attacking a neutral country triggers its immediate mobilization, spawning a garrison of units (infantry, naval in ports, and air units if the country is large enough).
* **Nuclear Escalation:** Factions can purchase and deploy nuclear weapons via ready air units. Nukes have a guaranteed kill radius and permanently mutate terrain into "Radioactive" or "Ruin" states, causing severe global diplomatic penalties.
