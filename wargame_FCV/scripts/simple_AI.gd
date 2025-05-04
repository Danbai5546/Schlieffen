class_name AI
extends Player


func _activate_pawn_async(activatable_pawns: Array[Pawn]) -> Pawn:
	assert(not activatable_pawns.is_empty())
	return activatable_pawns.pick_random()


# movable_pawns: pawn -> Array[Vector2i] (movable coords)
# return : [pawn, coords(Vector2i)]
func _move_pawn_async(movable_pawns: Dictionary) -> Array:
	var pawns := Array(movable_pawns.keys(), TYPE_OBJECT, (Pawn as Script).get_instance_base_type(), Pawn)
	pawns.shuffle()

	var enemy_faction := _get_enemies_faction(faction)
	for pawn: Pawn in pawns:
		var avaliable_coords := movable_pawns[pawn] as Array[Vector2i]

		# Case 1
		var blank_coords := avaliable_coords.filter(
			func(coords: Vector2i) -> bool: return board.get_block(coords).faction == Block.Faction.UNKNOW and _get_pawns_at(coords, faction).size() <= 0
		)
		if not blank_coords.is_empty():
			return [pawn, blank_coords.pick_random()]

		# Case 2
		var friend_coords := avaliable_coords.filter(
			func(coords: Vector2i) -> bool:
				return board.get_block(coords).faction == faction and _get_pawns_at(coords, faction).filter(func(p: Pawn) -> bool: return p.active).size() > 0
		)
		if not friend_coords.is_empty():
			friend_coords.sort_custom(
				func(a: Vector2i, b: Vector2i) -> bool:
					var s_a := _get_pawns_at(a, faction).size()
					var s_b := _get_pawns_at(b, faction).size()
					return s_a > s_b
			)
			var curr_friend_count := _get_pawns_at(pawn.s_coords, faction).size() as int
			if curr_friend_count < _get_pawns_at(friend_coords[0], faction).size():
				return [pawn, friend_coords[0]]

		# Case 3
		var enemies_coords := board.get_neighbours_of(pawn.s_coords).filter(
			func(coords: Vector2i) -> bool: return board.get_block(coords).faction == enemy_faction or _get_pawns_at(coords, enemy_faction).size() > 0
		)
		var escapable_coords := avaliable_coords.filter(func(coords: Vector2i) -> bool: return not coords in enemies_coords)
		if not enemies_coords.is_empty() and not escapable_coords.is_empty():
			enemies_coords.sort_custom(
				func(a: Vector2i, b: Vector2i) -> bool:
					var s_a := _get_pawns_at(a, enemy_faction).size()
					var s_b := _get_pawns_at(b, enemy_faction).size()
					return s_a > s_b
			)
			escapable_coords.sort_custom(
				func(a: Vector2i, b: Vector2i) -> bool:
					var s_a := _esimate_dangrous(enemy_faction, a)
					var s_b := _esimate_dangrous(enemy_faction, b)
					return s_a < s_b
			)

			for coords in enemies_coords:
				if _simulate_battle(enemy_faction, coords, pawn.s_coords):
					return [pawn, escapable_coords[0]]

	return []


# attackable_blocks: from -> Array[Vector2i] (defence blocks)
# return : [from (Vector2i), to (Vector2i)]
func _order_attack(attackable_blocks: Dictionary) -> Array:
	var enemies_faction := _get_enemies_faction(faction)
	for from in attackable_blocks:
		var to_list := (attackable_blocks[from] as Array[Vector2i]).filter(
			func(coords: Vector2i) -> bool: return board.get_block(coords).faction == enemies_faction or _get_pawns_at(coords, enemies_faction).size() > 0
		)
		to_list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _get_pawns_at(a, enemies_faction).size() > _get_pawns_at(b, enemies_faction).size())
		for to in to_list:
			if _simulate_battle(faction, from, to):
				return [from, to]
	return []


#----
static func _get_enemies_faction(f: Block.Faction) -> Block.Faction:
	return Block.Faction.GERMAN if f == Block.Faction.ALLIES else Block.Faction.ALLIES


func _esimate_dangrous(enemy_faction: Block.Faction, coords: Vector2i) -> bool:
	var func_filter := func(p: Pawn) -> bool: return p.active
	var ret := 0
	for neighbour in board.get_neighbours_of(coords):
		ret += _get_pawns_at(neighbour, enemy_faction).filter(func_filter).size()
	ret += _get_pawns_at(coords, enemy_faction).filter(func_filter).size()
	return ret


func _get_pawns_at(coords: Vector2i, p_faction: Block.Faction) -> Array[Pawn]:
	return board.get_pawns_at(coords, true).filter(func(p: Pawn) -> bool: return p.faction == p_faction)


func _simulate_battle(attacker_faction: Block.Faction, from: Vector2i, to: Vector2i) -> bool:
	assert(attacker_faction != Block.Faction.UNKNOW)
	var defencer_faction := _get_enemies_faction(attacker_faction)

	var attackers := _get_pawns_at(from, attacker_faction)
	attackers.append_array(_get_pawns_at(to, attacker_faction))
	attackers = attackers.filter(func(p: Pawn) -> bool: return not p.moved and p.s_active)

	var defencers := _get_pawns_at(to, defencer_faction).filter(func(p: Pawn) -> bool: return p.s_active)

	return attackers.size() >= defencers.size()
