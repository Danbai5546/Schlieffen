extends Node

var phase := Constants.Phase.ACTIVATE

var _update_pending_coords: Array[Vector2i]
var _update_pending := false

@onready var _board := %Board as Board
@onready var _arrow := %Arrow as Sprite2D

# Commad :
#	faction: Block.Faction
#	from: Vector2i
#	to: Vector2i
var attack_commands := {
	Block.Faction.ALLIES: [],
	Block.Faction.GERMAN: [],
}

var _round := 0

var _standby_flags := {
	Block.Faction.ALLIES: 0,
	Block.Faction.GERMAN: 0,
}
enum {
	_STANDBY_BIT_MOVE = 1 << 0,
	_STANDBY_BIT_ATTACK = 1 << 1,
}

var _local_player: Player
var _opponent_player: Player


func _ready() -> void:
	%ReturnToTitle.hide()
	%ReturnToTitle.pressed.connect(get_tree().change_scene_to_file.bind("res://scenes/title/title.tscn"))
	%Waiting.show()


func _exit_tree() -> void:
	multiplayer.multiplayer_peer = null


func setup(singleplayer: bool, local_is_german: bool) -> void:
	assert(is_node_ready())

	var german_player: Player
	var allies_player: Player

	if not singleplayer:
		# Setup multiplayer
		var opponent_uid := await multiplayer.peer_connected as int

		german_player = Player.new()
		allies_player = Player.new()

		add_child(german_player)
		add_child(allies_player)

		german_player.setup(1, _board, Block.Faction.GERMAN)
		allies_player.setup(multiplayer.get_unique_id() if opponent_uid == 1 else opponent_uid, _board, Block.Faction.ALLIES)

		if opponent_uid == 1:
			_local_player = allies_player
			_opponent_player = german_player
		else:
			_local_player = german_player
			_opponent_player = allies_player
	else:
		# Setup singleplayer
		if local_is_german:
			german_player = Player.new()
			allies_player = AI2.new()

			_local_player = german_player
			_opponent_player = allies_player

			german_player.setup(1, _board, Block.Faction.GERMAN)
			allies_player.setup(-1, _board, Block.Faction.ALLIES)
		else:
			allies_player = Player.new()
			german_player = AI2.new()

			_local_player = allies_player
			_opponent_player = german_player

			german_player.setup(-1, _board, Block.Faction.GERMAN)
			allies_player.setup(1, _board, Block.Faction.ALLIES)

		add_child(german_player)
		add_child(allies_player)

	%Faction.text = "Your faction: " + (Block.Faction.find_key(_local_player.faction) as String).capitalize()
	#
	german_player.score_updated.connect(_on_score_updated.bind(german_player))
	allies_player.score_updated.connect(_on_score_updated.bind(allies_player))

	for p in _board.get_children():
		if p is Pawn:
			if p.faction == german_player.faction:
				p.set_multiplayer_authority(german_player.master_uid)
			elif p.faction == allies_player.faction:
				p.set_multiplayer_authority(allies_player.master_uid)

	%SkipBtn.pressed.connect(_on_skip_btn_pressed)
	%Waiting.hide()

	set_operate_hint("The Game will start in seconds.")
	if not is_inside_tree():
		return
	await get_tree().create_timer(2.8).timeout
	await _hide_enemy_pawns_async()

	_start()


func _on_skip_btn_pressed() -> void:
	if _board.wait_pawn_click:
		_board.pawn_clicked.emit(null)
	else:
		_board.block_clicked.emit(Board.INVALIC_COORDS)


func _hide_enemy_pawns_async() -> void:
	var tween := await create_tween_async()
	for pawn in _board.get_children():
		if pawn is Pawn:
			if pawn.faction == _local_player.faction:
				continue
			pawn.set_visibility(false, tween)


func _start() -> void:
	while _round < Constants.ROUNDS.size():
		await _process_round_async()

	if _round != Constants.ROUNDS.size():
		return

	var victory := _local_player.score > _opponent_player.score
	_game_set(victory, _local_player.score == _opponent_player.score)


func set_operate_hint(hint := "", cancel_btn := true) -> void:
	%HintLabel.text = "[center]%s[/center]" % hint
	%SkipBtn.visible = not hint.is_empty() and cancel_btn
	%HintPanel.visible = not hint.is_empty()


func _wait_async(flag_bit: int, hint: String) -> void:
	set_operate_hint(hint, false)
	_standby(_local_player.faction, flag_bit)
	while not _standby_flags.values().all(func(f): return f & flag_bit > 0):
		if not is_inside_tree():
			return
		await get_tree().process_frame
	for f in _standby_flags:
		_standby_flags[f] &= ~flag_bit
	set_operate_hint()


func _process_round_async() -> void:
	%Date.text = Constants.ROUNDS[_round]["date"]
	%Date.visible_ratio = 0.1
	await (await create_tween_async()).tween_property(%Date, ^"visible_ratio", 1.0, 0.3).from(0.0).finished
	
	# MCTS test
	#var board_state = _get_board_state(_opponent_player)
	#_opponent_player.test1(board_state)
	
	set_operate_hint("Executing AI ACTIONS!", false)
	#AI ACTION 
	phase = Constants.Phase.ACTIVATE
	if _opponent_player is AI:
		await _activate_phase_async(_opponent_player)
	elif _opponent_player is AI2:
		var board_state = _get_board_state(_opponent_player)
		var actions = _opponent_player.run_mcts(board_state)
		_execute_mcts_activate_actions(actions, _opponent_player.faction)
		
	phase = Constants.Phase.MOVE
	if _opponent_player is AI:
		await _move_phase_async(_opponent_player)
		_set_standby_flag(_opponent_player.faction, _STANDBY_BIT_MOVE)
	elif _opponent_player is AI2:
		var board_state = _get_board_state(_opponent_player)
		var actions = _opponent_player.run_mcts(board_state)
		_execute_mcts_move_actions(actions, _opponent_player.faction)
		_set_standby_flag(_opponent_player.faction, _STANDBY_BIT_MOVE)
	
	# activate phase
	await _activate_phase_async(_local_player)
	# Move phase
	
	
	await _move_phase_async(_local_player)
	await _wait_async(_STANDBY_BIT_MOVE, "Waiting...")
	
	_update_block_faction()

	for f in [Block.Faction.ALLIES, Block.Faction.GERMAN]:
		var actions = []
		
		if f == Block.Faction.ALLIES:
			phase = Constants.Phase.BATTLE_A
		else:
			phase = Constants.Phase.BATTLE_G
			
		var board_state = _get_board_state(_opponent_player)
		
		var f_text := (Block.Faction.find_key(f) as String).capitalize()
		print(f_text + ": Determine attack strategy")
		var hint_text := ""

		if _local_player.faction == f:
			await _order_attack_phase(f, _local_player)
			hint_text = "Waiting..."
		else:
			if _opponent_player is AI:
				await _order_attack_phase(f, _opponent_player)
			elif _opponent_player is AI2:
				actions = _opponent_player.run_mcts(board_state)
				for action in actions:
					_add_attack_command(f, Constants.AI_coords_dic[action[1]], action[2])
					print("MCTS:", f, "attacks from", action[1], "to", Constants.AI_coords_dic.find_key(action[2]))
			hint_text = "Waiting for %s to order attacks..." % f_text

		if _opponent_player is AI  or _opponent_player is AI2:
			_set_standby_flag(_opponent_player.faction, _STANDBY_BIT_ATTACK << f)
		await _wait_async(_STANDBY_BIT_ATTACK << f, hint_text)

		print("Execute attack command for %s" % f_text)
		if attack_commands[f].size() > 0:
			if f_text.ends_with("s"):
				f_text += "'"
			else:
				f_text += "'s"
			set_operate_hint("Executing %s attacks!" % f_text, false)
			await _execute_attack_commands_async(f)
			set_operate_hint()

		_update_block_faction()

	await _hide_enemy_pawns_async()

	# Flush flags.
	for p in _board.get_children():
		if p is Pawn:
			p.moved = false

	# Next
	_round += 1


func _update_block_faction() -> void:
	for coords in _board.used_coords:
		var pawns := _board.get_pawns_at(coords, true)
		if pawns.is_empty():
			continue

		var local_pawns := pawns.filter(func(p: Pawn): return p.faction == _local_player.faction).size()
		var remote_pawns := pawns.filter(func(p: Pawn): return p.faction != _local_player.faction).size()
		var block := _board.get_block(coords)
		var target_faction: Block.Faction = block.faction
		if local_pawns > 0 and remote_pawns > 0:
			target_faction = Block.Faction.UNKNOW
		elif local_pawns > 0:
			target_faction = _local_player.faction
		elif remote_pawns > 0:
			target_faction = _get_enemy_faction(_local_player.faction)

		var german_player: Player = _local_player if _local_player.faction == Block.Faction.GERMAN else _opponent_player
		var allies_player: Player = _local_player if _local_player.faction == Block.Faction.ALLIES else _opponent_player

		if block.name == "PARIS" and (phase == Constants.Phase.BATTLE_A or phase == Constants.Phase.BATTLE_G):
			if block.name == "PARIS" and (block.faction == Block.Faction.GERMAN or target_faction ==Block.Faction.GERMAN):
				block.faction = Block.Faction.GERMAN
				_game_set(_local_player.faction == Block.Faction.GERMAN, false)
				german_player.score += 5
				_round = 10
				print(_local_player.faction, "The German army successfully occupied Paris at the end of the round (direct victory) and scored an additional 5 points")
		else:
			if block.faction != target_faction:
				if block.faction == Block.Faction.UNKNOW:
					block.faction = target_faction
					if target_faction == Block.Faction.GERMAN:
						german_player.score += 1
						print(_local_player.faction, "The German camp has occupied a new plot of land, with a score increase of one")
					elif target_faction == Block.Faction.ALLIES:
						allies_player.score += 1
						print(_local_player.faction, "The Allied camp has occupied a new plot of land, with a score increase of one“")
				else:
					block.faction = target_faction
					if block.faction == Block.Faction.GERMAN:
						german_player.score += 1
						allies_player.score -= 1
						print(_local_player.faction, "The German camp occupied the territory of the Allied camp, with a score increase of one point. The Allied camp lost the territory, the score decrease of one point")
					else:
						allies_player.score += 1
						german_player.score -= 1
						print(_local_player.faction, "The Allied camp occupied the territory of the German camp, with a score increase of one point. The German camp lost the territory, the score decrease of one point")


func _activate_phase_async(player: Player) -> void:
	var d := Constants.ROUNDS[_round]["activatable_pawns"].duplicate() as Dictionary
	var activatable: Array[Pawn]
	while activatable.is_empty():
		for t in d.keys():
			var faction := Pawn.get_faction(t)
			if faction != player.faction:
				continue

			for p in _board.get_children():
				if not p is Pawn:
					continue

				if not p.s_active and p.type == t and d[p.type] > 0 and not p.s_disabled:
					activatable.push_back(p)

		if activatable.is_empty():
			break

		var hint := "Click pawn to activate: "
		for t in d:
			var texture_file := ""
			if Pawn.get_faction(t) != player.faction:
				continue
			match t:
				Pawn.Type.GE:
					texture_file = "ge.jpg"
				Pawn.Type.FR:
					texture_file = "fr.jpg"
				Pawn.Type.BR:
					texture_file = "br.webp"
			hint += " [img color=DIM_GRAY]res://assets/images/%s[/img] %d" % [texture_file, d[t]]

		set_operate_hint(hint, false)
		var pawn := await player._activate_pawn_async(activatable)
		
		set_operate_hint()
		if not is_instance_valid(pawn):
			break
		pawn.set_active(true, await create_tween_async())
		activatable.erase(pawn)
		d[pawn.type] -= 1

		activatable.clear()


func _move_phase_async(player: Player) -> void:
	var movable := {}
	for p in _board.get_children():
		if p is Pawn:
			if p.faction != player.faction:
				continue
			var neighbours := _board.get_neighbours_of(p.s_coords).filter(func(c: Vector2i): return _board.get_block(c).faction in [player.faction, Block.Faction.UNKNOW])
			if neighbours.is_empty():
				continue
			movable[p] = neighbours

	while not movable.is_empty():
		var pawns_hint := ""
		if player.faction == Block.Faction.GERMAN:
			pawns_hint = "[img]res://assets/images/ge.jpg[/img] or [img color=DIM_GRAY]res://assets/images/ge.jpg[/img]"
		else:
			pawns_hint = "[img]res://assets/images/fr.jpg[/img], [img color=DIM_GRAY]res://assets/images/fr.jpg[/img], [img]res://assets/images/br.webp[/img] or [img color=DIM_GRAY]res://assets/images/br.webp[/img]"
		set_operate_hint("Click %s to start moving." % pawns_hint)

		var arr := await player._move_pawn_async(movable) as Array
		set_operate_hint()
		if arr.is_empty():
			break
		var pawn := arr[0] as Pawn
		var dest := arr[1] as Vector2i
		movable.erase(pawn)

		_move_pawn(pawn, dest)
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.21).timeout


func _order_attack_phase(faction: Block.Faction, player: Player) -> void:
	var attackable := {}
	for p in _board.get_children():
		if p is Pawn:
			if p.faction != faction or not p.s_active or p.moved:
				continue

			var neighbours := _board.get_neighbours_of(p.s_coords).filter(func(c: Vector2i): return _board.get_block(c).faction != faction)

			if not neighbours.is_empty():
				attackable[p.s_coords] = neighbours

	while not attackable.is_empty():
		set_operate_hint("Order Attack / Press finish to skip.")
		var arr := await player._order_attack(attackable) as Array
		set_operate_hint()
		if arr.is_empty():
			break
		var from := arr[0] as Vector2i
		var to := arr[1] as Vector2i
		attackable.erase(from)

		_add_attack_command(faction, from, to)

	if not player is AI:
		set_operate_hint("Attack phase: No more manipulable pieces. Please click cancel", true)
		await %SkipBtn.pressed
		set_operate_hint()


func _set_standby_flag(faction: Block.Faction, flag_bit: int) -> void:
	_standby_flags[faction] |= flag_bit


func _standby(faction: Block.Faction, flag_bit: int) -> void:
	_set_standby_flag(faction, flag_bit)
	_rpc_standby.rpc(faction, flag_bit)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_standby(faction: Block.Faction, flag_bit: int) -> void:
	_set_standby_flag(faction, flag_bit)


func _move_pawn(pawn: Pawn, to_coords: Vector2i) -> void:
	assert(not pawn.moved)
	assert(_board.used_coords.has(to_coords))
	assert(_board.get_block(to_coords).faction in [pawn.faction, Block.Faction.UNKNOW])
	_rearrange_block_deferred(pawn.coords)
	pawn.coords = to_coords
	pawn.s_coords = to_coords
	_rearrange_block_deferred(to_coords)
	pawn.moved = true


func _add_attack_command(attacker_faction: Block.Faction, attacker_coords: Vector2i, defencer_coords: Vector2i) -> void:
	_rpc_add_attack_command.rpc(attacker_faction, attacker_coords, defencer_coords)
	_rpc_add_attack_command(attacker_faction, attacker_coords, defencer_coords)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_add_attack_command(attacker_faction: Block.Faction, attacker_coords: Vector2i, defencer_coords: Vector2i) -> void:
	assert(attack_commands[attacker_faction].all(func(c: Dictionary): return c.from != attacker_coords))
	var cmd := {
		faction = attacker_faction,
		from = attacker_coords,
		to = defencer_coords,
	}

	attack_commands[attacker_faction].push_back(cmd)


func _execute_attack_commands_async(faction: Block.Faction) -> void:
	var defencer_faction := _get_enemy_faction(faction)

	for cmd in attack_commands[faction]:
		var attacker_pawns: Array[Pawn]
		var defencer_pawns: Array[Pawn]

		for p in _board.get_pawns_at(cmd.from, true):
			if p.faction != faction:
				continue
			if p.moved or not p.s_active:
				continue
			attacker_pawns.push_back(p)

		for p in _board.get_pawns_at(cmd.to, true):
			p.sync_state_to_display()
			if not p.s_active:
				continue
			if p.faction == faction:
				if not p.moved:
					attacker_pawns.push_back(p)
			else:
				defencer_pawns.push_back(p)

		assert(not attacker_pawns.is_empty())
		#if attacker_pawns.is_empty():
		#continue

		# arrow
		var from_pos := _board.map_to_local(cmd.from)
		var to_pos := _board.map_to_local(cmd.to)
		_arrow.position = (from_pos + to_pos) * 0.5
		_arrow.look_at(_board.to_global(to_pos))
		_arrow.show()

		# visibility
		var tween := await create_tween_async() as Tween
		_board.update_pawns_at(cmd.to, tween)
		await tween.finished

		# deactivate defencer
		tween = await create_tween_async() as Tween
		for i in range(min(attacker_pawns.size(), defencer_pawns.size())):
			defencer_pawns[i].set_active(false, tween)
		await tween.finished

		if not is_inside_tree():
			return
		await get_tree().create_timer(2).timeout

		# deactivate attacker
		tween = await create_tween_async() as Tween
		for p in attacker_pawns:
			p.set_active(false, tween)
		await tween.finished

		_arrow.hide()

		# try routed
		var enemy_pawns := _board.get_pawns_at(cmd.to, true).filter(func(p: Pawn): return p.faction == defencer_faction) as Array[Pawn]
		var need_move := enemy_pawns.is_empty()
		if not enemy_pawns.is_empty() and enemy_pawns.all(func(p: Pawn): return not p.s_active):
			need_move = true
			tween = await create_tween_async() as Tween
			tween.tween_callback(func(): pass)

			for p in enemy_pawns:
				p.s_coords = Vector2i(-100, -100)
				p.coords = p.s_coords
				p.s_disabled = true
				p.set_visibility(false, tween)

				var lose_player: Player = _local_player if _local_player.faction == p.faction else _opponent_player
				var win_player: Player = _local_player if _local_player.faction != p.faction else _opponent_player
				# Calculate score
				lose_player.score -= 1
				win_player.score += 1
				var w_text := (Block.Faction.find_key(win_player.faction) as String).capitalize()
				var l_text := (Block.Faction.find_key(lose_player.faction) as String).capitalize()
				print("%s camp kills %s camp chess piece, %s score plus one, %s reduce s score by one" % [w_text, l_text, w_text, l_text])
			await tween.finished

		# try move
		if need_move:
			for p in attacker_pawns:
				p.s_coords = cmd.to
				p.coords = cmd.to
			_rearrange_block_deferred(cmd.from)
			_rearrange_block_deferred(cmd.to)
			if not is_inside_tree():
				return
			await get_tree().create_timer(0.21).timeout

	attack_commands[faction].clear()


func _get_enemy_faction(f: Block.Faction) -> Block.Faction:
	assert(f != Block.Faction.UNKNOW)
	if f == Block.Faction.GERMAN:
		return Block.Faction.ALLIES
	else:
		return Block.Faction.GERMAN


func _rearrange_block_deferred(coords: Vector2i) -> void:
	if not coords in _update_pending_coords:
		_update_pending_coords.push_back(coords)

	if _update_pending:
		return
	_update_pending = true
	__rearrange_blocks.call_deferred()


func __rearrange_blocks() -> void:
	var tween := await create_tween_async() as Tween
	tween.tween_callback(func(): pass)
	for coords in _update_pending_coords:
		_board.rearrange_pawns(coords, tween)

	_update_pending_coords.clear()
	_update_pending = false


func _game_set(victory: bool, draw := false) -> void:
	if draw:
		%Draw.show()
	else:
		if victory:
			%Victory.show()
		else:
			%Defeat.show()

	print("Game set.")
	print("Current_player:", _local_player.faction, _local_player.score)

	%ReturnToTitle.show()


var _tween: Tween


func create_tween_async() -> Tween:
	if is_instance_valid(_tween) and _tween.is_running():
		await _tween.finished
	_tween = create_tween().set_parallel()
	_tween.tween_callback(func(): pass)
	return _tween


func _on_score_updated(player: Player) -> void:
	if player.faction == Block.Faction.GERMAN:
		%GermainScore.text = str(player.score)
	else:
		%AlliesScore.text = str(player.score)



func _get_board_state(tmp_player: Player):
	var temp_block: Block
	var temp_pawns: Array[Pawn]
	var i: int = 0

	var NUM_ALLIES_PAWNS: int = 0
	var NUM_GERMAN_PAWNS: int = 0

	var current_state: Dictionary = {
		"Player_faction": tmp_player.faction,
		"Round": _round,
		"Phase": phase,
		"winning_faction": null,
		"ALLIES_PAWNS": 0,  
		"GERMANS_PAWNS": 0
	}
	
	var blocks = {}
	
	for coord in _board.used_coords:
		i += 1
		temp_block = _board.get_block(coord)
		temp_pawns = _board.get_pawns_at(coord, true)

		var pawn_counts = {
			Pawn.Type.FR: {"active": 0, "inactive": 0},
			Pawn.Type.BR: {"active": 0, "inactive": 0},
			Pawn.Type.GE: {"active": 0, "inactive": 0}
		}
		
		var pawns_faction_restore = {
			Block.Faction.ALLIES: {},
			Block.Faction.GERMAN: {}
		}
		
		for temp_pawn in temp_pawns:
			pawns_faction_restore[temp_pawn.faction][temp_pawn.name] = {
					"activated": temp_pawn.active, 
					"moved": temp_pawn.moved,
					"type": temp_pawn.type
				}
			if temp_pawn.faction == Block.Faction.ALLIES:
				NUM_ALLIES_PAWNS += 1
				pawn_counts[temp_pawn.type]["active" if temp_pawn.active else "inactive"] += 1
			elif temp_pawn.faction == Block.Faction.GERMAN:
				NUM_GERMAN_PAWNS += 1
				pawn_counts[temp_pawn.type]["active" if temp_pawn.active else "inactive"] += 1

		blocks[temp_block.name] = {
			"block_faction": temp_block.faction,
			"pieces_status": pawn_counts,
			"pieces": pawns_faction_restore
		}
		
	current_state["blocks"] = blocks

	current_state["ALLIES_PAWNS"] = NUM_ALLIES_PAWNS
	current_state["GERMANS_PAWNS"] = NUM_GERMAN_PAWNS

	return current_state

func _execute_mcts_activate_actions(actions, faction):
	print("BEST ACTION:", actions)
	for type in actions:
		if type in [Pawn.Type.GE] if faction == Block.Faction.GERMAN else [Pawn.Type.FR, Pawn.Type.BR]:
			for block_name in actions[type]:
				var pawns = _board.get_pawns_at(Constants.AI_coords_dic[block_name], true)
				for pawn in pawns:
					if pawn.type == type and pawn.active == false:
						pawn.set_active(true, await create_tween_async())
						print("MCTS: 把", block_name, "上的", pawn.name , "设置为激活")
						break
	

func _execute_mcts_move_actions(actions, faction):
	print(actions)
	for action in actions[faction]:
		var pawns = _board.get_pawns_at(action[1], true)
		for pawn in pawns:
			if pawn.name == action[0]:
				_move_pawn(pawn, action[2])
				print("MCTS: 把", pawn.name, "从", action[1] , "移动到", action[2])
	pass
