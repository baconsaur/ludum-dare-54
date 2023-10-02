class_name Dinosaur
extends Node2D

export var points = 1
export var is_group = false
export var group_size = 1

onready var sprite = $Sprite
onready var score = $Score

func add_unit(unit : Dinosaur):
	if not is_group:
		sprite.play("group")
		is_group = true
	
	group_size += unit.group_size
	points += unit.points * group_size

func toggle_score():
	score.text = str(points)
	score.visible = not score.visible
