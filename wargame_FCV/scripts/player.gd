class_name Player
extends Node

signal score_updated
@export var score := 0:
	set(v):
		score = v
		score_updated.emit()

var faction := Block.Faction.GERMAN
var board: Board
var master_uid: int = -1


func _ready() -> void:
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(^".:score")
	cfg.property_set_replication_mode(^".:score", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)

	var synchronizer := MultiplayerSynchronizer.new()
	synchronizer.root_path = ^".."
	synchronizer.replication_config = cfg
	add_child(synchronizer)


func setup(uid: int, p_board: Board, p_faction: Block.Faction) -> void:
	faction = p_faction
	board = p_board
	master_uid = uid
	set_multiplayer_authority(uid)


func _activate_pawn_async(activatable_pawns: Array[Pawn]) -> Pawn:
	assert(multiplayer.get_unique_id() == master_uid, str(multiplayer.get_unique_id()))
	var selected: Pawn = null
	while not is_instance_valid(selected):
		var p = await board.to_pawn_clicked()
		if not is_instance_valid(p):
			break
		if p in activatable_pawns:
			selected = p
	return selected


# movable_pawns: pawn -> Array[Vector2i] (movable coords)
# return : [pawn, coords(Vector2i)]
func _move_pawn_async(movable_pawns: Dictionary) -> Array:
	assert(multiplayer.get_unique_id() == master_uid)
	while true:
		var selected: Pawn = null
		while not is_instance_valid(selected):
			var p = await board.to_pawn_clicked()
			if not is_instance_valid(p):
				break
			if p in movable_pawns:
				selected = p

		if not is_instance_valid(selected):
			return []

		var candidates := movable_pawns[selected] as Array

		board.set_blocks_highlight(candidates, true)
		var _s := ScopedActions.new(board.set_blocks_highlight.bind(candidates, false))

		var destination := Board.INVALIC_COORDS
		while destination == Board.INVALIC_COORDS:
			var coords := await board.to_block_clicked() as Vector2i
			if coords == Board.INVALIC_COORDS:
				break
			if coords in candidates:
				destination = coords

		if destination != Board.INVALIC_COORDS:
			return [selected, destination]

	return []


# attackable_blocks: from -> Array[Vector2i] (defence blocks)
# return : [from (Vector2i), to (Vector2i)]
func _order_attack(attackable_blocks: Dictionary) -> Array:
	var from_candidates := attackable_blocks.keys()

	while true:
		board.set_blocks_highlight(from_candidates, true)
		var from := Board.INVALIC_COORDS
		while from == Board.INVALIC_COORDS:
			var c := await board.to_block_clicked() as Vector2i
			if c == Board.INVALIC_COORDS:
				break  # Cancel
			if c in from_candidates:
				from = c
		board.set_blocks_highlight(from_candidates, false)

		if from == Board.INVALIC_COORDS:
			return []  # Cancel

		var to_candidates := attackable_blocks[from] as Array
		board.set_blocks_highlight(to_candidates, true)
		var to := Board.INVALIC_COORDS
		while to == Board.INVALIC_COORDS:
			var c := await board.to_block_clicked() as Vector2i
			if c == Board.INVALIC_COORDS:
				break  # Cancel
			if c in to_candidates:
				to = c
		board.set_blocks_highlight(to_candidates, false)

		if to != Board.INVALIC_COORDS:
			return [from, to]

	return []

func run_mcts(board_state):
	pass
