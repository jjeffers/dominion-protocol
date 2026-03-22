# Dynamic Country Generation

- The majority of cities at the start of a scenario are not aligned with any faction. They are neutral.
- Only cities and units detailed at belonging to a faction are assigned to a faction at the start of a scenario.

## Country Generation Algorithm
- Non-aligned countries are formed in a random process.
- Between 8 and 30 contries are formed (scale on a normal distribution), each linked to a contry centroid.
- Country centroids are randomly generated and distributed around the global map.
- Non-aligned cities are clustered by proximity to a coutry centroid, with variation in "clustering strength" to create more organic shapes.
- The region associated with a city is added to the country's list of regions.
- Each country's total geography is the union of all city regions in that country.
- The country names are named "Country 1", "Country 2", etc. [TO BE CHANGED LATER]
- Each country will be assigned a color, slate grey. 
- Each country will have a colored border which will be a slate gray color in the same manner as the faction borders.
- The country formation and city assignment process happens at the start of each scenario and is logged to the game logs.

