extends Node2D

signal select_group
signal deselect_group
signal hover_group
signal unhover_group

export var leave_hover_pause = 0.25

var selected = false
var hovered = false
var offsets = []
var leave_hover_cooldown = 0
var is_preview = false
var colliders = []
var rocks = []

onready var last_position =  position

func _ready():
	var children = get_children()
	for child in children:
		if child is Area2D:
			rocks.append(child)
	recalculate_colliders()

func recalculate_colliders():
	for collider in colliders:
		remove_child(collider)
		collider.queue_free()
	colliders = []
	for rock in rocks:
		var rock_collider = rock.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
		if not rock_collider:
			continue
		var self_collider = rock_collider.duplicate()
		colliders.append(self_collider)
		add_child(self_collider)
		self_collider.set_disabled(false)
		self_collider.global_position = rock_collider.global_position

func _process(delta):
	if leave_hover_cooldown > 0:
		leave_hover_cooldown -= delta
		unhover()

func set_offsets(offset_coords):
	offsets = offset_coords

func set_preview():
	is_preview = true
	deselect()
	unhover()
	set_invalid()

func select():
	if selected:
		return
	selected = true
	for rock in rocks:
		rock.modulate = Color(1, 1, 0, 0.5)

func deselect():
	selected = false
	if hovered:
		hover()
	else:
		for rock in rocks:
			rock.modulate = Color(1, 1, 1, 1)

func set_valid():
	if not is_preview:
		return
	for rock in rocks:
		rock.modulate = Color(1, 1, 0, 1)

func set_invalid():
	if not is_preview:
		return
	for rock in rocks:
		rock.modulate = Color(1, 0, 0, 0.75)

func hover():
	if selected:
		return
	for rock in rocks:
		rock.modulate = Color(0, 1, 1, 1)
	hovered = true

func unhover():
	if selected:
		return
	hovered = false
	for rock in rocks:
		rock.modulate = Color(1, 1, 1, 1)

func _on_RockGroup_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if selected:
			emit_signal("deselect_group")
		else:
			emit_signal("select_group")

func _on_RockGroup_mouse_entered():
	emit_signal("hover_group")

func _on_RockGroup_mouse_exited():
	emit_signal("unhover_group")

func preview_mode(preview_node):
	last_position = position
	var parent = get_parent()
	if parent:
		parent.remove_child(self)
	preview_node.add_child(self)
	position = Vector2.ZERO

func place(container, pos):
	var parent = get_parent()
	if parent:
		parent.remove_child(self)
	container.add_child(self)
	position = last_position
	global_position = pos
