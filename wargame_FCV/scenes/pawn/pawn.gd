@tool
class_name Pawn
extends Sprite2D

const DURATION := 0.2

signal clicked

enum Type {
	GE,
	FR,
	BR,
}

@export var type := Type.GE:
	set(v):
		type = v

		match type:
			Type.GE:
				texture = load("res://assets/images/ge.jpg")
			Type.FR:
				texture = load("res://assets/images/fr.jpg")
			Type.BR:
				texture = load("res://assets/images/br.webp")

		if type == Type.GE:
			faction = Block.Faction.GERMAN
		else:
			faction = Block.Faction.ALLIES

@export var active := true:
	set(v):
		set_active(v)
	get:
		return _active
@export var coords: Vector2i

# Real states
@export var s_active := active
@export var s_disabled := false
@export var s_coords := coords

var visibility := true

var faction := Block.Faction.GERMAN
var moved := false

var _active := true

@onready var _board := get_parent() as Board


func _ready() -> void:
	type = type

	if Engine.is_editor_hint():
		return

	assert(is_instance_valid(_board))

	initialize_state()


func initialize_state() -> void:
	s_active = active
	s_coords = coords


func sync_state_to_display() -> void:
	active = s_active
	coords = s_coords


func _unhandled_input(event: InputEvent) -> void:
	if not get_parent().wait_pawn_click:
		return

	var mb := event as InputEventMouseButton
	if not is_instance_valid(mb):
		return

	if not get_rect().has_point(to_local(mb.global_position)):
		return

	if mb.is_echo() or mb.button_index != MOUSE_BUTTON_LEFT or not mb.is_pressed():
		return

	clicked.emit()
	get_tree().root.set_input_as_handled()


func set_active(p_active: bool, tween: Tween = null) -> void:
	_active = p_active
	s_active = p_active
	if not is_instance_valid(tween):
		self_modulate = Color.WHITE if _active else Color.DIM_GRAY
	else:
		tween.tween_property(self, ^"self_modulate", Color.WHITE if _active else Color.DIM_GRAY, DURATION)


func move_to(pos: Vector2, tween: Tween = null) -> void:
	if not is_instance_valid(tween):
		position = pos
	else:
		tween.tween_property(self, ^"position", pos, DURATION)


func set_visibility(v: bool, tween: Tween = null) -> void:
	visibility = v
	if not is_instance_valid(tween):
		modulate.a = 1.0 if v else 0.0
	else:
		tween.tween_property(self, "modulate:a", 1.0 if v else 0.0, DURATION)


func is_active() -> bool:
	return _active


static func get_faction(pawn_type: Type) -> Block.Faction:
	if pawn_type == Type.GE:
		return Block.Faction.GERMAN
	else:
		return Block.Faction.ALLIES


func _to_string() -> String:
	return "<%s: %s %s - %s>" % ["German" if get_faction(type) == Block.Faction.GERMAN else "Allies", s_active, moved, s_coords]
