extends SceneTree

func _init():
var file = FileAccess.open("res://src/data/oil_data.json", FileAccess.READ)
var data = JSON.parse_string(file.get_as_text())
file.close()

for item in data:
var pos = item.position
var tile = item.tile
var vec = Vector3(pos.x, pos.y, pos.z).normalized()
var lat = rad_to_deg(asin(vec.y))
var lon = rad_to_deg(atan2(vec.x, vec.z))
print("Tile: ", tile, " | Approx Lat: ", lat, " Lon: ", lon)
quit()
