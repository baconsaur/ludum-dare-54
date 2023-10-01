extends Node2D

signal select_group
signal deselect_group

var selected = false
var offsets = []

onready var rocks = get_children()

func _ready():
	for rock in rocks:
		rock.connect("mouse_entered", self, "check_hover")
		rock.connect("mouse_exited", self, "check_hover")
		rock.connect("input_event", self, "check_select")

func set_offsets(offset_coords):
	offsets = offset_coords
	print(offsets)

func check_hover():
	pass

func check_select(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if selected:
			emit_signal("deselect_group")
		else:
			emit_signal("select_group")

func select():
	selected = true
	for rock in rocks:
		rock.modulate = Color(1, 1, 0, 0.5)

func deselect():
	selected = false
	for rock in rocks:
		rock.modulate = Color(1, 1, 1, 1)
