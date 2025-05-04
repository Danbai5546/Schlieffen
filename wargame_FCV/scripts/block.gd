@tool
class_name Block
extends Resource

enum Faction {
	UNKNOW = 0,
	GERMAN = 2,
	ALLIES = 4,
}

@export var coords: Vector2i
@export var faction := Faction.ALLIES:
	set(v):
		faction = v
		emit_changed()
@export var highlight := false:
	set(v):
		highlight = v
		emit_changed()

@export var name: String:
	set(v):
		resource_name = v
	get:
		return resource_name


func get_cell_alt() -> int:
	return faction + (1 if highlight else 0)


func _to_string() -> String:
	return name if not name.is_empty() else str(coords)


static func cell_alt_to_faction(cell_alt: int) -> Faction:
	return floori(float(cell_alt) / 2.0) * 2 as Faction


static func is_highlight_cell_alt(cell_alt: int) -> bool:
	return cell_alt % 2 > 0
