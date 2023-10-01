extends Area2D

signal selected


func _on_SelectableTile_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		emit_signal("selected")
