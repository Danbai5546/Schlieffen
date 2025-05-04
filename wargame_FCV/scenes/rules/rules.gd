extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%BackBtn.pressed.connect(get_tree().change_scene_to_file.bind("res://scenes/title/title.tscn"))
