import json
with open("src/data/city_data.json", "r") as f:
    d = json.load(f)
d["London"]["latitude"] = 51.5074456
d["London"]["longitude"] = 0.67
d["Hamburg"]["latitude"] = 53.85
d["Hamburg"]["longitude"] = 9.2
d["Bordeaux"]["latitude"] = 44.841225
d["Bordeaux"]["longitude"] = -0.98
d["Kolkata"]["latitude"] = 21.0000000
d["Kolkata"]["longitude"] = 88.3638953
with open("src/data/city_data.json", "w") as f:
    json.dump(d, f, indent="\t")
