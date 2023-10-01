extends Area2D

signal selected
signal deselected
signal hovered
signal unhovered


func _on_SelectableTile_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		emit_signal("selected")

func _on_SelectableTile_mouse_entered():
	emit_signal("hovered")

func _on_SelectableTile_mouse_exited():
	emit_signal("unhovered")
