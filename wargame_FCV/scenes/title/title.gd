extends Control


func _ready() -> void:
	%ViewRules.pressed.connect(_on_view_rules_pressed)
	%Quit.pressed.connect(get_tree().quit)

	%SinglePlayer.pressed.connect(%SingleplayerPanel.show)
	%MultiPlayer.pressed.connect(%MultiplayerPanel.show)

	%BackBtn1.pressed.connect(_on_back_btn_pressed)
	%BackBtn2.pressed.connect(_on_back_btn_pressed)

	%Host.pressed.connect(_on_multiplayer_btn_pressed.bind(true))
	%Client.pressed.connect(_on_multiplayer_btn_pressed.bind(false))

	%German.pressed.connect(_on_singleplayer_btn_pressed.bind(true))
	%Allies.pressed.connect(_on_singleplayer_btn_pressed.bind(false))

	_on_back_btn_pressed()


func _show_connecting() -> void:
	%MultiplayerPanel.hide()
	%ConnectingLabel.show()


func _to_main_scene(singleplayer: bool, local_is_german: bool) -> void:
	var tree := get_tree()
	var main := preload("res://scenes/main/main.tscn").instantiate()

	var current := tree.current_scene
	tree.root.remove_child(current)
	tree.root.add_child(main)
	tree.current_scene = main
	main.setup(singleplayer, local_is_german)

	current.queue_free()


func _on_multiplayer_btn_pressed(host: bool) -> void:
	var peer := ENetMultiplayerPeer.new()
	if host:
		if peer.create_server(%PortLineEdit.text.to_int(), 1) != OK:
			printerr("Create server failed.")
			return
	else:
		if peer.create_client(%IPLineEdit.text.strip_edges(), %PortLineEdit.text.to_int()) != OK:
			printerr("Create client failed.")
			return

	multiplayer.multiplayer_peer = peer
	_show_connecting()

	_to_main_scene(false, host)


func _on_singleplayer_btn_pressed(local_is_german: bool) -> void:
	_to_main_scene(true, local_is_german)


func _on_view_rules_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/rules/rules.tscn")


func _on_back_btn_pressed() -> void:
	%MultiplayerPanel.hide()
	%SingleplayerPanel.hide()
