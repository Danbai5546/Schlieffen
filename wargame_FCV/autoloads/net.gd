extends Node

var oppoent_uid := -1

func _ready() -> void:
	multiplayer.peer_connected.connect(
		func(uid):
			oppoent_uid = uid
	)
	multiplayer.peer_disconnected.connect(
		func(uid):
			print("%d disconnected. Will return to title after 5 sec.")
			await get_tree().create_timer(5).timeout
			_reset_to_title()
	)

	multiplayer.connection_failed.connect(
		func():
			print("Connection failed.")
			_reset_to_title()
	)


func _reset_to_title() -> void:
	oppoent_uid = -1
	get_tree().change_scene_to_file("res://scenes/title/title.tscn")
