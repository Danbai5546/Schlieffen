@tool
class_name Board
extends TileMapLayer

signal block_clicked(coords: Vector2i)
signal pawn_clicked(pawn: Pawn)

const INVALIC_COORDS := Vector2i(-100, -100)

@warning_ignore("unused_private_class_variable")
@export var _setup_toggle := false:
	set(v):
		if not Engine.is_editor_hint():
			return
		_setup()
		notify_property_list_changed()

@export var blocks: Array[Block]:
	set(v):
		blocks = v
		for b in blocks:
			b.changed.connect(_on_block_changed.bind(b))

@onready var used_coords := get_used_cells()

var wait_pawn_click := false


func _ready() -> void:
	for coords in used_coords:
		rearrange_pawns(coords, null)

	if Engine.is_editor_hint():
		set_process_unhandled_input(false)
	else:
		_setup()

	for pawn in get_children():
		pawn = pawn as Pawn
		if not is_instance_valid(pawn):
			continue
		pawn.coords = local_to_map(pawn.position)

		get_block(pawn.coords).faction = pawn.faction

		pawn.initialize_state()
		pawn.clicked.connect(pawn_clicked.emit.bind(pawn))


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if not is_instance_valid(mb):
		return

	if mb.button_index != MOUSE_BUTTON_LEFT or mb.is_echo() or not mb.is_pressed():
		return

	var coords := local_to_map(to_local(mb.global_position))
	block_clicked.emit(coords)
	get_tree().root.set_input_as_handled()


func _setup() -> void:
	for b in blocks:
		if b.changed.is_connected(_on_block_changed):
			b.changed.disconnect(_on_block_changed)

	blocks.clear()

	var coords_to_name := {}
	for label in %Labels.get_children():
		label = label as Label
		if not is_instance_valid(label):
			continue

		coords_to_name[local_to_map(label.position)] = label.text
		label.name = label.text

	for coords in get_used_cells():
		var b := Block.new()
		blocks.push_back(b)
		var alt := get_cell_alternative_tile(coords)
		b.coords = coords
		b.faction = Block.cell_alt_to_faction(alt)
		b.highlight = Block.is_highlight_cell_alt(alt)
		b.name = coords_to_name[coords]
		b.changed.connect(_on_block_changed.bind(b))


func to_block_clicked() -> Signal:
	wait_pawn_click = false
	return block_clicked


func to_pawn_clicked() -> Signal:
	wait_pawn_click = true
	return pawn_clicked


func get_block(coords: Vector2i) -> Block:
	for b in blocks:
		if b.coords == coords:
			return b
	assert(false)
	return null


func get_neighbours_of(coords: Vector2i) -> Array[Vector2i]:
	var ret: Array[Vector2i]
	var pos := map_to_local(coords)
	for i in range(6):
		var n := local_to_map(pos + Vector2.UP.rotated(i * (PI / 3.0) + PI / 6.0) * 300)
		if n in used_coords:
			ret.push_back(n)
	return ret


func get_pawns_at(coords: Vector2i, real: bool) -> Array[Pawn]:
	assert(coords in used_coords)
	var ret: Array[Pawn]
	for pawn in get_children():
		pawn = pawn as Pawn
		if not is_instance_valid(pawn):
			continue

		if pawn.s_disabled:
			continue

		if real:
			if pawn.s_coords == coords:
				ret.push_back(pawn)
		else:
			if pawn.coords == coords and pawn.visibility:
				ret.push_back(pawn)

	return ret


func update_pawns_at(coords: Vector2i, tween: Tween, faction := Block.Faction.UNKNOW) -> void:
	var display_pawns := get_pawns_at(coords, false)
	var real_pawns := get_pawns_at(coords, true)
	if faction != Block.Faction.UNKNOW:
		display_pawns = display_pawns.filter(func(p): return p.faction == faction)
		real_pawns = real_pawns.filter(func(p): return p.faction == faction)
	for p in display_pawns:
		if not p in real_pawns:
			p.set_visibility(false, tween)

	for p in real_pawns:
		p.set_visibility(true, tween)
		p.coords = p.s_coords

	rearrange_pawns(coords, tween)


func rearrange_pawns(coords: Vector2i, tween: Tween) -> void:
	assert(coords in used_coords)
	var pawns := get_pawns_at(coords, false).filter(func(p: Pawn): return p.visibility) as Array[Pawn]
	var count := pawns.size()

	if count <= 0:
		return

	var center := map_to_local(coords)

	if count == 1:
		pawns[0].move_to(center, tween)
	else:
		var mid_row := floorf(float(count) / 2) * 0.5
		const OFFSET = Vector2(55, 40)

		for i in range(pawns.size()):
			var ofs := Vector2()
			ofs.x = OFFSET.x * (-1 if (i % 2) == 0 else 1)
			ofs.y = (floorf(float(i) / 2) - mid_row) * OFFSET.y
			var pawn := pawns[i]
			pawn.move_to(center + ofs, tween)

	if is_instance_valid(tween):
		await tween.finished


func set_blocks_highlight(coords_list: Array, highlight: bool) -> void:
	for b in coords_list:
		get_block(b).highlight = highlight


func _on_block_changed(block: Block) -> void:
	const TILE_SOURCE_ID = 0
	set_cell(block.coords, TILE_SOURCE_ID, get_cell_atlas_coords(block.coords), block.get_cell_alt())
