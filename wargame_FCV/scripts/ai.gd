class_name AI2
extends Player


static var mcts:MCTS = MCTS.new()


func _activate_pawn_async(activatable_pawns: Array[Pawn]) -> Pawn:
	assert(not activatable_pawns.is_empty())
	return activatable_pawns.pick_random()

func setup(uid: int, p_board: Board, p_faction: Block.Faction) -> void:
	faction = p_faction
	board = p_board
	mcts.setup(p_faction, board)


func test_mcts(board_state):
	print("Starting MCTS test, initial state:", board_state)

	var mcts_root = MCTS.run_simulation(board_state)  # Run MCTS
	print("MCTS simulation completed")

	var best_move = mcts_root.get_best_move()
	print("Best move calculated by AI:", best_move)

	var winner = MCTS.simulation(board_state)  # Run game simulation
	print("Final winner from MCTS simulation:", winner)


static func test(board_state):
	var temp_state = board_state.duplicate(true)

	print("-------- Activation Test --------")
	print("State before test:", temp_state)
	var re = MCTS.generate_activation_action(temp_state)
	print("State after test:", re[0])
	print("Selected activated pawns:", re[1])
	var temp_state2 = re[2]
	# print("Next phase:", temp_state2)
	# print("Initial state after test:", temp_state)
	# print("Did the original state change after test:", deep_dict_equals(board_state, temp_state))

	var temp_state2_du = re[0].duplicate(true)
	# print("-------- Movement Test --------")
	print("State before test:", temp_state2_du)
	var re2 = MCTS.generate_movement_action(temp_state2_du)
	# print("State after movement phase:", re2[0])
	print("Movement actions taken:", re2[1])
	var temp_state3 = re2[2]
	# print("Next phase:", temp_state3)
	# print("Initial state after test:", temp_state2_du)
	# print("Did the original state change after test:", deep_dict_equals(temp_state2_du, re[0]))

	var temp_state3_du = re2[0].duplicate(true)

	print("-------- Attack Test (ALLIES) --------")
	print("State before test:", temp_state3_du)
	var re3 = MCTS.generate_attack_action(temp_state3_du, Block.Faction.ALLIES)
	print("State after attack phase (ALLIES):", re3[0])
	print("Attack actions taken:", re3[1])
	var temp_state4 = re3[2]
	print("Next phase:", temp_state4)
	# print("Initial state after test:", temp_state3_du)
	print("Did the original state change after test:", deep_dict_equals(temp_state3_du, re2[0]))

	var temp_state4_du = board_state.duplicate(true)

static func test1(board_state):
	var temp_state = board_state.duplicate(true)
	temp_state["Phase"] = Constants.Phase.BATTLE_G
	#print(temp_state["Round"])
	#temp_state["Round"] = 2
	##var re1 = MCTS.get_possible_activation_actions(temp_state)
	##var re2 = MCTS.generate_activation_combinations(temp_state)
	#var re1 = MCTS.generate_possible_movement_actions(temp_state)
	#var re2 = MCTS.generate_movement_combinations(temp_state)
	##var re1 = MCTS.generate_possible_movement_actions(temp_state)
	##var re2 = MCTS.generate_attack_combinations(temp_state, board_state["Player_faction"])
	#print(re1)
	#print("-------")
	#print(re2)
	var root_node = mcts.run_simulation(temp_state)
	print("Best action:", root_node.get_best_move())
	
static func test2(board_state):
	var numOfIteration = 1000
	var GE_WIN_COUND := 0
	var AL_WIN_COUND := 0
	var DRAW_COUND := 0
	for i in range(numOfIteration):
		var winner = MCTS.simulation(board_state)
		print(i)
		match  winner:
			"GERMAN":
				GE_WIN_COUND += 1
			"ALLIES":
				AL_WIN_COUND += 1
			"DRAW":
				DRAW_COUND += 1
			_:
				print("error")

	print(numOfIteration, "games played:\nGerman wins:", GE_WIN_COUND, "\nAllied wins:", AL_WIN_COUND, "\nDraws:", DRAW_COUND)



static func deep_dict_equals(dict1: Dictionary, dict2: Dictionary) -> bool:
	if dict1.keys().size() != dict2.keys().size():
		return false

	for key in dict1.keys():
		if not dict2.has(key):
			return false
		
		var value1 = dict1[key]
		var value2 = dict2[key]

		if typeof(value1) != typeof(value2):
			return false

		if value1 is Dictionary and value2 is Dictionary:
			if not deep_dict_equals(value1, value2):
				return false
		elif value1 is Array and value2 is Array:
			if value1 != value2: 
				return false
		else:
			if value1 != value2:
				return false
	
	return true

func run_mcts(board_state):
	var temp_state = board_state.duplicate(true)
	var root_node = mcts.run_simulation(temp_state)

	return root_node.get_best_move()
	
