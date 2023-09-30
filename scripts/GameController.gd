extends Node2D

export var start_level : PackedScene
export(Array, PackedScene) var levels = []

var score = 0
var current_level : Level = null

onready var score_label = $CanvasLayer/MarginContainer/HBoxContainer/Score

func _ready():
	load_level(start_level)

func load_level(level_scene):
	var level_instance = level_scene.instance()
	current_level = level_instance
	add_child(level_instance)
	current_level.connect("dino_exited", self, "increase_score")
	current_level.connect("level_complete", self, "complete_level")
	current_level.connect("turn_complete", self, "enable_debug_step")

func step_turn():
	$CanvasLayer/MarginContainer/HBoxContainer/DebugStepTurn.set_disabled(true)
	current_level.process_turn()

func enable_debug_step():
	$CanvasLayer/MarginContainer/HBoxContainer/DebugStepTurn.set_disabled(false)

func _on_DebugStepTurn_pressed():
	step_turn()

func complete_level():
	remove_child(current_level)
	current_level.queue_free()
	load_level(start_level)
	enable_debug_step()

func increase_score(points):
	score += points
	score_label.text = str(score)
