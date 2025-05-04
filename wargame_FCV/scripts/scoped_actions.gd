class_name ScopedActions

var _end: Callable


func _init(end: Callable) -> void:
	_end = end


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_end.call()
