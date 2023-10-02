extends Area2D


onready var sprite = $Sprite
onready var sprite_material = $Sprite.material

func make_unique():
	var new_mat = sprite.get_material().duplicate()
	sprite.set_material(new_mat)
	sprite_material = new_mat

func set_outline(is_on, color):
	sprite_material.set_shader_param("outline_on", is_on)
	sprite_material.set_shader_param("outline_col", color)
