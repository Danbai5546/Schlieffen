extends Node
class_name MCTS

static var board:Board

static func setup( p_faction: Block.Faction, p_board: Board) -> void:
	board = p_board


static func run_simulation(board_state):
	var state = board_state.duplicate(true)
	var root = MCTSNode.new(state, null, null,state["Phase"])
	var iterations = 1000
	for i in range(iterations):
		var node = selection(root)
		var new_node = expansion(node)
		var result = simulation(new_node.state)
		backpropagation(new_node, result)
	
	return root


static func selection(node):
	while node.is_fully_expanded() and node.children.size() > 0:
		#print("Current selected node:", node, "Visits:", node.visits, "Wins:", node.wins)
		node = node.best_child()
	return node


static func expansion(node):
	var possible_actions = get_possible_actions(node.state, node.phase)
	#print(possible_actions)

	var selected_action = possible_actions.pick_random()
	#print("Current simulated action:", selected_action, node.phase)

	if selected_action == null:
		#print("Im here", node.state, node.phase)
		selected_action = []
	var new_state_data = apply_action(node.state, selected_action, node.phase)
	var new_state = new_state_data[0]
	var action = new_state_data[1]
	var next_phase = new_state_data[2]

	var new_node = MCTSNode.new(new_state, node, action, next_phase)
	node.children.append(new_node)

	return new_node

#static func expansion(node):
	#var temp_re= process_phase(node.state, node.phase)
	#var new_state = temp_re[0]
	#var action = temp_re[1]
	#var next_phase = temp_re[2]
	#var new_node = MCTSNode.new(new_state, node, action, next_phase)
	#node.children.append(new_node)
	#return new_node


static func backpropagation(node, result):
	while node != null:
		node.visits += 1
		if result == "DRAW":
			node.wins += 0.5
		elif result ==  node.state["winning_faction"]:
			node.wins += 1
		node = node.parent


static func simulation(state):
	var sim_state = state.duplicate(true)

	while sim_state["winning_faction"] == null:
		# print("Current Round:", sim_state["Round"]+1, "Current State:", sim_state["Phase"]) 
		# print("Current State:", sim_state["Phase"])
		if check_paris_capture(sim_state):
			sim_state["winning_faction"] = "GERMAN"
		elif sim_state["Round"] == 5:
			sim_state["winning_faction"] = determine_winner(sim_state)
			break
			
		var tmp_re = process_phase(sim_state, sim_state["Phase"])
		sim_state = tmp_re[0]
		sim_state["Phase"] = tmp_re[2]
		
		if tmp_re[2] == Constants.Phase.ACTIVATE:  
			sim_state["Round"] += 1 
			
	#print("Running random simulation... Current winner:", sim_state["winning_faction"])
	return sim_state["winning_faction"]


static func get_possible_actions(state, phase):
	match phase:
		Constants.Phase.ACTIVATE:
			return generate_activation_combinations(state)
		Constants.Phase.MOVE:
			return generate_movement_combinations(state)
		Constants.Phase.BATTLE_A:
			return generate_attack_combinations(state, Block.Faction.ALLIES)
		Constants.Phase.BATTLE_G:
			return generate_attack_combinations(state, Block.Faction.GERMAN)
	return []


static func apply_action(state, action, phase):
	match phase:
		Constants.Phase.ACTIVATE:
			return process_chosen_activation_actions(state, action)
		Constants.Phase.MOVE:
			return process_chosen_movement_actions(state, action)
		Constants.Phase.BATTLE_A:
			return process_chosen_attack_actions(state, Block.Faction.ALLIES, action)
		Constants.Phase.BATTLE_G:
			return process_chosen_attack_actions(state, Block.Faction.GERMAN, action)
	return state



static func process_phase(state, phase):
	#print("phase:", phase)
	match phase:
		Constants.Phase.ACTIVATE:
			return generate_activation_action(state)
		Constants.Phase.MOVE:
			return generate_movement_action(state)
		Constants.Phase.BATTLE_A:
			return generate_attack_action(state, Block.Faction.ALLIES)
		Constants.Phase.BATTLE_G:
			return generate_attack_action(state, Block.Faction.GERMAN)
	return [state, null, phase]


static func check_paris_capture(state):
	if state["blocks"]["PARIS"]["block_faction"] == Block.Faction.GERMAN:
		return true
	return false


static func get_score(state):
	var allies_score = 0
	var germans_score = 0
	
	var blocks = state["blocks"]
	for block_key in blocks:
		if blocks[block_key]["block_faction"] == Block.Faction.ALLIES:
			allies_score += 1
		elif blocks[block_key]["block_faction"] == Block.Faction.GERMAN:
			germans_score += 1

	allies_score += 8 - state.get("ALLIES_PAWNS", 8)
	germans_score += 8 - state.get("GERMANS_PAWNS", 8)
	
	return [allies_score, germans_score]


static func determine_winner(state):
	var result = get_score(state)
	
	var allies_score = result[0]
	var germans_score = result[1]

	#print("Current game: Allies score -", allies_score, "Germans score -", germans_score)
	if allies_score > germans_score:
		return "ALLIES"
	elif germans_score > allies_score:
		return "GERMAN"
	else:
		return "DRAW"


static func generate_activation_action(state):
	var new_state = state.duplicate(true)
	var round_index = min(state["Round"], Constants.ROUNDS.size() - 1)
	var activatable_rules = Constants.ROUNDS[round_index]["activatable_pawns"]
	var flag_br = activatable_rules.get(Pawn.Type.BR, 0)

	var activatable_pawns = {
		Pawn.Type.FR: [],
		Pawn.Type.GE: []
	}
	var chosen_pawns = []
	
	#print("Current round:", state["Round"], "| Allowed activations:", activatable_rules)
	
	var blocks = new_state["blocks"]
	# Traverse the board to find inactive pawns that meet the activation conditions
	for block_key in new_state["blocks"]:
		var block = blocks[block_key]
		for type in block["pieces_status"]:
			if blocks[block_key]["pieces_status"][type]["inactive"] > 0:
				#print("Found activatable pawn at:", block_key, "| Type:", type, "| Faction:", block["block_faction"])
				if flag_br>0 and type==Pawn.Type.BR:
					new_state["blocks"][block_key]["pieces_status"][type]["inactive"] -= 1
					new_state["blocks"][block_key]["pieces_status"][type]["active"] += 1
					chosen_pawns.append([block_key, type])
					
					var temp_pawns = new_state["blocks"][block_key]["pieces"][Block.Faction.ALLIES]
					# print(temp_pawns)
					for temp_pawn_key in temp_pawns:
						if temp_pawns[temp_pawn_key]["type"] == Pawn.Type.BR:
							temp_pawns[temp_pawn_key]["activated"] = true
							
				elif type != Pawn.Type.BR:
					for i in range(blocks[block_key]["pieces_status"][type]["inactive"]):
						activatable_pawns[type].append(block_key)
	
	#print("Activatable French pawns:", activatable_pawns[Pawn.Type.FR])
	#print("Activatable German pawns:", activatable_pawns[Pawn.Type.GE])

	
	# Selecting pawns that meet activation rules
	for pawn_type in [Pawn.Type.FR, Pawn.Type.GE]:
		if activatable_pawns[pawn_type].size() > 0:
			var num_to_activate = min(activatable_rules[pawn_type], activatable_pawns[pawn_type].size())
			for i in range(num_to_activate):
				var chosen_pawn_block = activatable_pawns[pawn_type].pick_random()
				activatable_pawns[pawn_type].erase(chosen_pawn_block)
				new_state["blocks"][chosen_pawn_block]["pieces_status"][pawn_type]["inactive"] -= 1
				new_state["blocks"][chosen_pawn_block]["pieces_status"][pawn_type]["active"] += 1
				
				var temp_faction = Block.Faction.ALLIES if pawn_type == Pawn.Type.FR else Block.Faction.GERMAN
				var temp_pawns = new_state["blocks"][chosen_pawn_block]["pieces"][temp_faction]
				for temp_pawn_key in temp_pawns:
					if temp_pawns[temp_pawn_key]["activated"] == false:
						new_state["blocks"][chosen_pawn_block]["pieces"][temp_faction][temp_pawn_key]["activated"] = true
						break  
				
				chosen_pawns.append([chosen_pawn_block, pawn_type])

	new_state["Phase"] = Constants.Phase.MOVE
	return [new_state, chosen_pawns, Constants.Phase.MOVE]


static func generate_movement_action(state):
	var new_state = state.duplicate(true)
	var blocks = new_state["blocks"]
	var chosen_moves = []
	
	# Traverse the board to find all possible movable actions
	for block_key in blocks:
		var block = blocks[block_key]
		for type_key in block["pieces"]:
			var temp_pawns:Dictionary = block["pieces"][type_key]
			for temp_pawn_key:String in temp_pawns:
				var temp_pawn_data:Dictionary = temp_pawns[temp_pawn_key]
				
				var move_flag:bool = ([false, true, true]).pick_random()
				
				if move_flag and temp_pawn_data["moved"] == false:
					var neighbors = board.get_neighbours_of(Constants.AI_coords_dic[block_key]).filter(func(c: Vector2i): return blocks[Constants.AI_coords_dic.find_key(c)]["block_faction"] in [Block.Faction.GERMAN if temp_pawn_data["type"] == Pawn.Type.GE else Block.Faction.ALLIES, Block.Faction.UNKNOW])
					#print(block_key, "block can move to destinations:", neighbors)

					
					if neighbors.size() > 0 :
						temp_pawn_data["moved"] = true
						var destination_coord:Vector2i = neighbors.pick_random()
						var destination_block:String = Constants.AI_coords_dic.find_key(destination_coord)
						chosen_moves.append([type_key, temp_pawn_key, block_key, Constants.AI_coords_dic[block_key], destination_block, destination_coord])
						#print("Pawn", temp_pawn_key, "chooses to move from", block_key, Constants.AI_coords_dic[block_key], "to", destination_block, destination_coord)


	#Move
	for move in chosen_moves:
		var temp_data = new_state["blocks"][move[2]]["pieces"][move[0]][move[1]]
		var act_flag = "active" if temp_data["activated"] else "inactive"
		new_state["blocks"][move[2]]["pieces"][move[0]].erase(move[1])
		new_state["blocks"][move[2]]["pieces_status"][temp_data["type"]][act_flag] -= 1
		new_state["blocks"][move[4]]["pieces"][move[0]][move[1]] = temp_data
		new_state["blocks"][move[4]]["pieces_status"][temp_data["type"]][act_flag] += 1
	
	new_state = update_state(new_state)
	
	return [new_state, chosen_moves, Constants.Phase.BATTLE_A]


static func generate_attack_action(state, attacker_faction):
	var next_phase = Constants.Phase.BATTLE_G if attacker_faction == Block.Faction.ALLIES else Constants.Phase.ACTIVATE
	var new_state = state.duplicate(true)
	var blocks = new_state["blocks"]
	var chosen_attacks = []
	
	var enemy_faction = Block.Faction.GERMAN if attacker_faction == Block.Faction.ALLIES else Block.Faction.ALLIES
	
	for block_key in blocks:
		var block = blocks[block_key]
		if block["block_faction"] == enemy_faction:
			#print(block, "- Block controlled by enemy, skipping attack check")
			continue  # Only check blocks controlled by current faction
		
		# print(block, "- Block is valid for attack check")
		var attack_targets = []   # List of possible attack targets from this block
		var can_attack = false    # Flag indicating if this block has attack options
		var attacking_pawns = []  # Pawns that can engage in the attack
		
		for type_key in block["pieces"]:
			var temp_pawns:Dictionary = block["pieces"][type_key]
			for temp_pawn_key:String in temp_pawns:
				var temp_pawn_data:Dictionary = temp_pawns[temp_pawn_key]
				
				if temp_pawn_data["activated"] and not temp_pawn_data["moved"]:
					var tmp_range = [Pawn.Type.GE] if attacker_faction == Block.Faction.GERMAN else [Pawn.Type.FR, Pawn.Type.BR]
					if temp_pawn_data["type"] in tmp_range:
						can_attack = true
						attacking_pawns.append(temp_pawn_key)
		
		# print("Block", block_key, "- List of attackable pawns:", attacking_pawns)

		# Controls the AI's tendency to attack:
		# More `true` entries → more aggressive
		# More `false` entries → more conservative
		var attack_flag = [true, true, false].pick_random()
		if can_attack and attack_flag:
			var neighbours
			if attacker_faction == Block.Faction.UNKNOW:
				neighbours = board.get_neighbours_of(Constants.AI_coords_dic[block_key]).filter(func(c: Vector2i): return blocks[Constants.AI_coords_dic.find_key(c)]["block_faction"] == enemy_faction)
			else:
				neighbours = board.get_neighbours_of(Constants.AI_coords_dic[block_key]).filter(func(c: Vector2i): return blocks[Constants.AI_coords_dic.find_key(c)]["block_faction"] != attacker_faction)

			if neighbours.size() > 0:
				var attacked_block_coord:Vector2i = neighbours.pick_random()
				var attacked_block:String = Constants.AI_coords_dic.find_key(attacked_block_coord)
				chosen_attacks.append([block_key, Constants.AI_coords_dic[block_key], attacking_pawns, Constants.AI_coords_dic.find_key(attacked_block_coord), attacked_block_coord])	
				# print("🎯 Block", block_key, Constants.AI_coords_dic[block_key], "attacks block", attacked_block, attacked_block_coord)
			else:
				pass
				# print("🎯 Block", block_key, Constants.AI_coords_dic[block_key], "has no adjacent attackable blocks, skipping attack")

				
		elif !attack_flag:
			pass
	
	for attack in chosen_attacks:
		var attacker_block = attack[0]
		var target_block = attack[3]
		var attacking_pawns = attack[2]
		

		var attacker_count = attacking_pawns.size()
		var defender_count = 0
		var defending_pawns = []

		#for type in blocks[target_block]["pieces"]:
		for pawn_key in blocks[target_block]["pieces"][enemy_faction]:
			if blocks[target_block]["pieces"][enemy_faction][pawn_key]["activated"]:
				defender_count += 1
				defending_pawns.append([pawn_key, blocks[target_block]["pieces"][enemy_faction][pawn_key]["type"]])
		
		#print("HERE:", attacking_pawns)
		# print("Blocks", new_state["blocks"])
		var attack_block_faction = new_state["blocks"][attacker_block]["block_faction"]
		for pawn_key in attacking_pawns:
			#print(new_state["blocks"][attacker_block]["pieces"])
			#print(attacker_faction)
			#print(new_state["blocks"][attacker_block]["pieces"][attacker_faction])
			new_state["blocks"][attacker_block]["pieces"][attacker_faction][pawn_key]["activated"] = false
			
		for pawn_key in attacking_pawns:
			var pawn_type = new_state["blocks"][attacker_block]["pieces"][attacker_faction][pawn_key]["type"]
			new_state["blocks"][attacker_block]["pieces_status"][pawn_type]["active"] -= 1
			new_state["blocks"][attacker_block]["pieces_status"][pawn_type]["inactive"] += 1

		if attacker_count >= defender_count:
			new_state["blocks"][target_block]["block_faction"] = attacker_faction

			# Remove all defending pawns
			for pawn_key in blocks[target_block]["pieces"][enemy_faction]:
					#for pawn_key in blocks[target_block]["pieces"][type]:
				var act_flag = "active" if blocks[target_block]["pieces"][enemy_faction][pawn_key]["activated"] else "inactive"
				blocks[target_block]["pieces_status"] [blocks[target_block]["pieces"][enemy_faction][pawn_key]["type"]] [act_flag] -= 1
			blocks[target_block]["pieces"][enemy_faction] = {}
			
			# Attacking pawns move to the newly occupied block
			for pawn_key in attacking_pawns:
				var pawn_data = new_state["blocks"][attacker_block]["pieces"][attacker_faction][pawn_key]
				new_state["blocks"][target_block]["pieces"][attacker_faction][pawn_key] = pawn_data

				var pawn_type = pawn_data["type"]
				new_state["blocks"][target_block]["pieces_status"][pawn_type]["inactive"] += 1
				new_state["blocks"][attacker_block]["pieces_status"][pawn_type]["inactive"] -= 1

				# Clear attacking pawns from the original block
				new_state["blocks"][attacker_block]["pieces"].erase(pawn_key)

			# print(attacker_block, "successfully attacked", target_block, "and captured the area!")


		else:
			var num_to_deactivate = min(attacker_count, defender_count)
			for i in range(num_to_deactivate):
				var pawn_to_deactivate = defending_pawns.pick_random()
				new_state["blocks"][target_block]["pieces"][enemy_faction][pawn_to_deactivate[0]]["activated"] = false
				new_state["blocks"][target_block]["pieces_status"][pawn_to_deactivate[1]]["active"] -= 1
				new_state["blocks"][target_block]["pieces_status"][pawn_to_deactivate[1]]["inactive"] += 1
				defending_pawns.erase(pawn_to_deactivate)

	new_state = update_state(new_state)
	
	return [new_state, chosen_attacks, next_phase]


static func update_state(state):
	var new_state = state.duplicate(true)
	var blocks = new_state["blocks"]
	
	for block_key in blocks:
		var block = blocks[block_key]
		
		var allies_count = 0
		var germans_count = 0
		
		# Count the number of Allied and German pawns in this block
		for type in block["pieces"]:
			var numfOfPawn = (block["pieces"][type]).size()
			if type == Block.Faction.ALLIES:
				allies_count += numfOfPawn
			elif type == Block.Faction.GERMAN:
				germans_count += numfOfPawn
				
			# Clear movement flags
			if state["Phase"] == Constants.Phase.BATTLE_G:
				for pawn_key in block["pieces"][type]:
					block["pieces"][type][pawn_key]["moved"] = false 
			
		# Update block ownership
		if block["block_faction"] == Block.Faction.UNKNOW:
			if allies_count > 0 and germans_count == 0:
				block["block_faction"] = Block.Faction.ALLIES
			elif germans_count > 0 and allies_count == 0:
				block["block_faction"] = Block.Faction.GERMAN
			else:
				block["block_faction"] = Block.Faction.UNKNOW
		else:
			var pawn_mem_count = allies_count if block["block_faction"] != Block.Faction.ALLIES else germans_count
			if pawn_mem_count > 0:
				block["block_faction"] = Block.Faction.GERMAN  if block["block_faction"] != Block.Faction.ALLIES else Block.Faction.ALLIES
		#print(block_key, "faction ownership check", allies_count, germans_count, new_state["blocks"][block_key]["block_faction"])

	
	return new_state


static func get_possible_activation_actions(state):
	var round_index = min(state["Round"], Constants.ROUNDS.size() - 1)
	var activatable_rules = Constants.ROUNDS[round_index]["activatable_pawns"]
	
	var possible_actions = {
		Pawn.Type.FR: [],
		Pawn.Type.GE: [],
		Pawn.Type.BR: []
	}
	
	#print("Current round:", state["Round"], "| Activatable pawns:", activatable_rules)

	var blocks = state["blocks"]
	# Traverse the board to find inactive pawns that meet activation conditions
	for block_key in blocks:
		var block = blocks[block_key]
		for type in block["pieces_status"]:
			if blocks[block_key]["pieces_status"][type]["inactive"] > 0:
				# print("Found activatable pawn in:", block_key, "| Type:", type, "| Faction:", block["block_faction"])
				for i in range(blocks[block_key]["pieces_status"][type]["inactive"]):
					possible_actions[type].append(block_key)
	
	return possible_actions


# Recursively generate all valid combinations of pawn activations
static func get_combinations(arr: Array, k: int, start: int = 0, current_combination: Array = [], result: Array = []) -> Array:
	if current_combination.size() == k:
		result.append(current_combination.duplicate())
		return result

	for i in range(start, arr.size()):
		current_combination.append(arr[i])
		get_combinations(arr, k, i + 1, current_combination, result)
		current_combination.pop_back()

	return result


static func generate_activation_combinations(state: Dictionary) -> Array:
	var round_index = min(state["Round"], Constants.ROUNDS.size() - 1)  
	var activatable_rules = Constants.ROUNDS[round_index]["activatable_pawns"]

	var possible_actions = get_possible_activation_actions(state)
	var all_combinations = {} 

	var activation_options = {}

	for pawn_type in activatable_rules.keys():
		var required_count = activatable_rules[pawn_type]
		var available_pawns = possible_actions.get(pawn_type, []).duplicate()
		
		if available_pawns.size() >= required_count:
			activation_options[pawn_type] = get_combinations(available_pawns, required_count)
		else:
			activation_options[pawn_type] = [available_pawns]
			
	# Compute the Cartesian product of all activation options

	var cartesian_product = []  
	if activation_options.size() > 0:
		cartesian_product = get_cartesian_product(activation_options.values())

	for activation_set in cartesian_product:
		var activation_decision = {}
		var index = 0
		for pawn_type in activation_options.keys():
			activation_decision[pawn_type] = activation_set[index]
			index += 1

		var combo_key = JSON.stringify(activation_decision)
		all_combinations[combo_key] = activation_decision

	return all_combinations.values()



static func get_cartesian_product(arrays: Array, index: int = 0, current_combination: Array = [], result: Array = []) -> Array:
	if index == arrays.size():
		result.append(current_combination.duplicate())
		return result

	for item in arrays[index]:
		current_combination.append(item)
		get_cartesian_product(arrays, index + 1, current_combination, result)
		current_combination.pop_back()

	return result



static func process_chosen_activation_actions(state, chosen_actions):
	var new_state = state.duplicate(true)
	var activatable_rules = Constants.ROUNDS[min(state["Round"], Constants.ROUNDS.size() - 1)]["activatable_pawns"]
	
	for pawn_type in chosen_actions:
		if chosen_actions.size() > 0:
			for block in chosen_actions[pawn_type]:
				new_state["blocks"][block]["pieces_status"][pawn_type]["inactive"] -= 1
				new_state["blocks"][block]["pieces_status"][pawn_type]["active"] += 1
				
				var temp_faction = Block.Faction.GERMAN if pawn_type == Pawn.Type.GE else Block.Faction.ALLIES
				var temp_pawns = new_state["blocks"][block]["pieces"][temp_faction]
				for temp_pawn_key in temp_pawns:
					if temp_pawns[temp_pawn_key]["type"] == pawn_type and temp_pawns[temp_pawn_key]["activated"] == false:
						new_state["blocks"][block]["pieces"][temp_faction][temp_pawn_key]["activated"] = true
						break  

	new_state["Phase"] = Constants.Phase.MOVE
	return [new_state, chosen_actions, Constants.Phase.MOVE]


static func generate_possible_movement_actions(state):
	var blocks = state["blocks"]
	var possible_actions = {
		Block.Faction.GERMAN: [],
		Block.Faction.ALLIES: []
	}

	for block_key in blocks:
		var block = blocks[block_key]
		for type_key in block["pieces"]:
			var temp_pawns:Dictionary = block["pieces"][type_key]
			for temp_pawn_key:String in temp_pawns:
				var temp_pawn_data:Dictionary = temp_pawns[temp_pawn_key]
				
				if temp_pawn_data["moved"] == false:
					var neighbors = board.get_neighbours_of(Constants.AI_coords_dic[block_key]).filter(func(c: Vector2i): return blocks[Constants.AI_coords_dic.find_key(c)]["block_faction"] in [Block.Faction.GERMAN if temp_pawn_data["type"] == Pawn.Type.GE else Block.Faction.ALLIES, Block.Faction.UNKNOW])
					if neighbors.size() > 0 :
						possible_actions[type_key].append([temp_pawn_key, Constants.AI_coords_dic[block_key], neighbors])
						
	return possible_actions

static func generate_movement_combinations(state: Dictionary) -> Array:
	var possible_moves = generate_possible_movement_actions(state)  
	#print("generate_possible_movement_actions返回:", possible_moves)

	if possible_moves.is_empty():
		print("⚠️ 没有可移动的棋子！")
		return []

	var all_pawn_moves = {
		Block.Faction.GERMAN: [],
		Block.Faction.ALLIES: []
	}  

	for type_key in possible_moves.keys():
		var pawn_moves = []
		for move_data in possible_moves[type_key]:
			var pawn_name = move_data[0]
			var start_pos = move_data[1]
			var end_positions = move_data[2] 

			if start_pos != null:
				pawn_moves.append([pawn_name, start_pos, start_pos])

			for end_pos in end_positions:
				if end_pos != start_pos:
					pawn_moves.append([pawn_name, start_pos, end_pos])

		if type_key == 2:
			all_pawn_moves[Block.Faction.GERMAN].append(pawn_moves)
		else:
			all_pawn_moves[Block.Faction.ALLIES].append(pawn_moves)


	var german_combinations = []
	var allies_combinations = []
	
	if all_pawn_moves[Block.Faction.GERMAN].size() > 0:
		german_combinations = get_cartesian_product(all_pawn_moves[Block.Faction.GERMAN])
	
	if all_pawn_moves[Block.Faction.ALLIES].size() > 0:
		allies_combinations = get_cartesian_product(all_pawn_moves[Block.Faction.ALLIES])

	var valid_combinations = []

	if german_combinations.is_empty():
		for ally_moves in allies_combinations:
			valid_combinations.append({
				Block.Faction.GERMAN: [],
				Block.Faction.ALLIES: ally_moves
			})
	elif allies_combinations.is_empty():
		for german_moves in german_combinations:
			valid_combinations.append({
				Block.Faction.GERMAN: german_moves,
				Block.Faction.ALLIES: []
			})
	else:
		for german_moves in german_combinations:
			for ally_moves in allies_combinations:
				valid_combinations.append({
					Block.Faction.GERMAN: german_moves,
					Block.Faction.ALLIES: ally_moves
				})

	var final_combinations = []
	for move_set in valid_combinations:
		if not _has_swapped_positions(move_set[Block.Faction.GERMAN]) and not _has_swapped_positions(move_set[Block.Faction.ALLIES]):
			final_combinations.append(move_set)

	return final_combinations


static func _has_swapped_positions(move_set: Array) -> bool:
	var position_map = {}

	for move in move_set:
		var pawn_name = move[0]
		var start_pos = move[1]
		var end_pos = move[2]
		
		if start_pos == end_pos:
			continue


		if end_pos in position_map and position_map[end_pos] == start_pos:
			return true


		position_map[start_pos] = end_pos

	return false 



static func process_chosen_movement_actions(state, chosen_actions):
	
	var new_state = state.duplicate(true)
	
	#Move
	for type_key in chosen_actions:
		for move in chosen_actions[type_key]:
			#print(move)
			var start_block = Constants.AI_coords_dic.find_key(move[1])
			var end_block = Constants.AI_coords_dic.find_key(move[2])
			if start_block == end_block:
				continue
				
			var temp_data = new_state["blocks"][start_block]["pieces"][type_key][move[0]]
			temp_data['moved'] = true
			var act_flag = "active" if temp_data["activated"] else "inactive"
			new_state["blocks"][start_block]["pieces"][type_key].erase(move[0])
			new_state["blocks"][start_block]["pieces_status"][temp_data["type"]][act_flag] -= 1
			new_state["blocks"][end_block]["pieces"][type_key][move[0]] = temp_data
			new_state["blocks"][end_block]["pieces_status"][temp_data["type"]][act_flag] += 1
	
	new_state = update_state(new_state)

	return [new_state, chosen_actions, Constants.Phase.BATTLE_A]


static func get_possible_attack_actions(state, attacker_faction):
	var next_phase = Constants.Phase.BATTLE_G if attacker_faction == Block.Faction.ALLIES else Constants.Phase.ACTIVATE
	var new_state = state.duplicate(true)
	var blocks = new_state["blocks"]
	var chosen_attacks = []
	
	var enemy_faction = Block.Faction.GERMAN if attacker_faction == Block.Faction.ALLIES else Block.Faction.ALLIES
	
	for block_key in blocks:
		var block = blocks[block_key]
		if block["block_faction"] == enemy_faction:
			continue
		
		var attack_targets = []
		var can_attack = false
		var attacking_pawns = []
		
		for type_key in block["pieces"]:
			var temp_pawns:Dictionary = block["pieces"][type_key]
			for temp_pawn_key:String in temp_pawns:
				var temp_pawn_data:Dictionary = temp_pawns[temp_pawn_key]
				
				if temp_pawn_data["activated"] and not temp_pawn_data["moved"]:
					var tmp_range = [Pawn.Type.GE] if attacker_faction == Block.Faction.GERMAN else [Pawn.Type.FR, Pawn.Type.BR]
					if temp_pawn_data["type"] in tmp_range:
						can_attack = true
						attacking_pawns.append(temp_pawn_key)
		
		if can_attack:
			var neighbours = []
			if attacker_faction == Block.Faction.UNKNOW:
				neighbours = board.get_neighbours_of(Constants.AI_coords_dic[block_key]).filter(func(c: Vector2i): return blocks[Constants.AI_coords_dic.find_key(c)]["block_faction"] == enemy_faction)
			else:
				neighbours = board.get_neighbours_of(Constants.AI_coords_dic[block_key]).filter(func(c: Vector2i): return blocks[Constants.AI_coords_dic.find_key(c)]["block_faction"] != attacker_faction)

			if neighbours.size() > 0:
				chosen_attacks.append([attacking_pawns, block_key, neighbours])
				# print("Block", block_key, Constants.AI_coords_dic[block_key], "attacks block", attacked_block, attacked_block_coord)

			else:
				# print("Block", block_key, Constants.AI_coords_dic[block_key], "has no adjacent attackable blocks, skipping attack")
				pass
				
	
	return chosen_attacks


static func generate_attack_combinations(state: Dictionary, attacker_faction) -> Array:
	var possible_attacks = get_possible_attack_actions(state, attacker_faction)
	var all_attack_combinations = []
	
	if possible_attacks.size() == 0:
		return []


	for attack_data in possible_attacks:
		var attacking_pawns = attack_data[0]
		var attacker_block = attack_data[1]
		var possible_targets = attack_data[2]

		for target_block in possible_targets:
			all_attack_combinations.append([attacking_pawns, attacker_block, target_block])

	var all_combinations = []
	all_combinations = get_cartesian_product([all_attack_combinations])

	return all_combinations


static func process_chosen_attack_actions(state, attacker_faction, chosen_actions):
	var next_phase = Constants.Phase.BATTLE_G if attacker_faction == Block.Faction.ALLIES else Constants.Phase.ACTIVATE
	var new_state = state.duplicate(true)
	var blocks = new_state["blocks"]
	var enemy_faction = Block.Faction.GERMAN if attacker_faction == Block.Faction.ALLIES else Block.Faction.ALLIES
	if next_phase == Constants.Phase.ACTIVATE:
		new_state["Round"] += 1
		
	for attack in chosen_actions:
		var attacker_block = attack[1]
		var target_block = Constants.AI_coords_dic.find_key(attack[2])
		var attacking_pawns = attack[0]
		
		var attacker_count = attacking_pawns.size()
		var defender_count = 0
		var defending_pawns = []

		for pawn_key in blocks[target_block]["pieces"][enemy_faction]:
			if blocks[target_block]["pieces"][enemy_faction][pawn_key]["activated"]:
				defender_count += 1
				defending_pawns.append([pawn_key, blocks[target_block]["pieces"][enemy_faction][pawn_key]["type"]])
		
		#print("HERE:", attacking_pawns)
		# print("Blocks", new_state["blocks"])
		#print(attacker_block)
		#var attack_block_faction = new_state["blocks"][attacker_block]["block_faction"]
		for pawn_key in attacking_pawns:
			#print(new_state["blocks"][attacker_block]["pieces"])
			#print(attacker_faction)
			#print(new_state["blocks"][attacker_block]["pieces"][attacker_faction])
			if new_state["blocks"][attacker_block]["pieces"][attacker_faction][pawn_key]["activated"] == true:
				new_state["blocks"][attacker_block]["pieces"][attacker_faction][pawn_key]["activated"] = false
				var pawn_type = new_state["blocks"][attacker_block]["pieces"][attacker_faction][pawn_key]["type"]
				new_state["blocks"][attacker_block]["pieces_status"][pawn_type]["active"] -= 1
				new_state["blocks"][attacker_block]["pieces_status"][pawn_type]["inactive"] += 1


		if attacker_count >= defender_count:
			new_state["blocks"][target_block]["block_faction"] = attacker_faction

			for pawn_key in blocks[target_block]["pieces"][enemy_faction]:
					#for pawn_key in blocks[target_block]["pieces"][type]:
				var act_flag = "active" if blocks[target_block]["pieces"][enemy_faction][pawn_key]["activated"] else "inactive"
				blocks[target_block]["pieces_status"] [blocks[target_block]["pieces"][enemy_faction][pawn_key]["type"]][act_flag] -= 1
			blocks[target_block]["pieces"][enemy_faction] = {}
			

			for pawn_key in attacking_pawns:
				var pawn_data = new_state["blocks"][attacker_block]["pieces"][attacker_faction][pawn_key]
				new_state["blocks"][target_block]["pieces"][attacker_faction][pawn_key] = pawn_data  # 移动到新地块

				var pawn_type = pawn_data["type"]
				new_state["blocks"][target_block]["pieces_status"][pawn_type]["inactive"] += 1
				new_state["blocks"][attacker_block]["pieces_status"][pawn_type]["inactive"] -= 1

				new_state["blocks"][attacker_block]["pieces"].erase(pawn_key)


		else:
			var num_to_deactivate = min(attacker_count, defender_count)
			for i in range(num_to_deactivate):
				var pawn_to_deactivate = defending_pawns.pick_random()
				new_state["blocks"][target_block]["pieces"][enemy_faction][pawn_to_deactivate[0]]["activated"] = false
				new_state["blocks"][target_block]["pieces_status"][pawn_to_deactivate[1]]["active"] -= 1
				new_state["blocks"][target_block]["pieces_status"][pawn_to_deactivate[1]]["inactive"] += 1
				defending_pawns.erase(pawn_to_deactivate)

	new_state = update_state(new_state)
	
	return [new_state, chosen_actions, next_phase]
