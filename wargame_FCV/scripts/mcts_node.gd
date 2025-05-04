extends Node
class_name MCTSNode

var state
var parent
var children = []
var visits = 0
var wins = 0
var action
var phase
	
func _init(p_state, p_parent = null, p_action = null, p_phase = null):
	state = p_state
	parent = p_parent
	action = p_action
	phase = p_phase

func is_fully_expanded():
	return children.size() > 10

func best_child():
	var best_score = -INF
	var best_node = null
	for child in children:
		var score = child.wins / (child.visits + 1) + sqrt(2 * log(visits + 1) / (child.visits + 1))
		if score > best_score:
			best_score = score
			best_node = child
	return best_node
	
	
func get_best_move():
	if children.is_empty():
		return null
	children.sort_custom(func(a, b): return a.visits > b.visits)
	return children[0].action
