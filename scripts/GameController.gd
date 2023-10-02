extends Node2D

export var test_level : PackedScene
export(Array, PackedScene) var levels = []

var level_score = 0
var total_score = 0
var saved_dinos = 0
var current_level : Level = null
var level_end_obj = preload("res://scenes/LevelEnd.tscn")
var level_index = 0
var tutorial_step = 0
var audio_off_icon = preload("res://sprites/audio_off.png")
var audio_on_icon = preload("res://sprites/audio_on.png")

onready var score_label = $CanvasLayer/MarginContainer/Actions/LevelActions/Score
onready var audio_toggle = $CanvasLayer/MarginContainer/Actions/LevelActions/AudioToggle
onready var reset_button = $CanvasLayer/MarginContainer/Actions/LevelActions/Restart
onready var skip_turn_button = $CanvasLayer/MarginContainer/Actions/MoveActions/SkipTurn
onready var cancel_button = $CanvasLayer/MarginContainer/Actions/MoveActions/Cancel
onready var rotate_l_button = $CanvasLayer/MarginContainer/Actions/MoveActions/RotateL
onready var rotate_r_button = $CanvasLayer/MarginContainer/Actions/MoveActions/RotateR
onready var ui_container = $CanvasLayer/MarginContainer
onready var tutorial1 = $CanvasLayer/Tutorial/Part1
onready var tutorial2 = $CanvasLayer/Tutorial/Part2
onready var master_sound = AudioServer.get_bus_index("Master")


func _ready():
	if test_level:
		load_level(test_level)
	else:
		load_level(levels[0])

func _process(delta):
	if Input.is_action_just_pressed("skip_turn") and not skip_turn_button.disabled:
		skip_turn()

func load_level(level_scene):
	if current_level:
		remove_child(current_level)
		current_level.queue_free()
	
	level_score = 0
	saved_dinos = 0
	var level_instance = level_scene.instance()
	current_level = level_instance
	add_child(level_instance)
	
	current_level.connect("dino_exited", self, "increase_score")
	current_level.connect("level_complete", self, "complete_level")
	current_level.connect("object_selected", self, "tutorial_progress")
	current_level.connect("turn_complete", self, "complete_turn")
	current_level.connect("object_selected", self, "enable_object_controls")
	current_level.connect("object_deselected", self, "disable_object_controls")
	
	enable_skip_turn()
	reset_button.set_disabled(true)

func skip_turn():
	skip_turn_button.set_disabled(true)
	current_level.start_turn_processing()

func enable_skip_turn():
	skip_turn_button.set_disabled(false)

func complete_turn():
	enable_skip_turn()
	reset_button.set_disabled(false)
	
	if tutorial_step == 0:
		tutorial1.visible = false
		tutorial2.visible = true
		tutorial_step +=1
	elif tutorial_step == 1:
		tutorial2.visible = false
		tutorial_step +=1

func enable_object_controls():
	rotate_l_button.set_disabled(false)
	rotate_r_button.set_disabled(false)
	cancel_button.set_disabled(false)

func disable_object_controls():
	rotate_l_button.set_disabled(true)
	rotate_r_button.set_disabled(true)
	cancel_button.set_disabled(true)

func _on_SkipTurn_pressed():
	skip_turn()

func complete_level():
	var level_end = level_end_obj.instance()
	ui_container.add_child(level_end)
	level_end.set_scores(level_score, total_score)
	level_end.connect("retry", self, "restart_current_level")
	level_end.connect("next_level", self, "next_level")
	if level_score > 0:
		level_end.enable_next_level()
		var header = "Saved " + str(saved_dinos) + " dinosaur"
		if saved_dinos != 1:
			header += "s"
		level_end.set_header(header)
	else:
		level_end.set_header("All the dinosaurs died")
	
	if tutorial2.visible:
		tutorial2.visible = false

func next_level():
	if level_index < levels.size() - 1:
		level_index += 1
	load_level(levels[level_index])

func restart_current_level():
	total_score -= level_score
	if test_level:
		load_level(test_level)
	else:
		load_level(levels[level_index])

func increase_score(points, dino_count):
	saved_dinos += dino_count
	level_score += points
	total_score += points
	score_label.text = str(level_score)

func _on_Restart_pressed():
	restart_current_level()

func _on_Cancel_pressed():
	current_level.deselect_object()

func _on_RotateL_pressed():
	current_level.rotate_left()

func _on_RotateR_pressed():
	current_level.rotate_right()

func tutorial_progress():
	if tutorial_step > 0:
		return
	tutorial1.visible = false
	tutorial2.visible = true
	tutorial_step = 1


func _on_AudioToggle_toggled(button_pressed):
	if button_pressed:
		audio_toggle.icon = audio_off_icon
		AudioServer.set_bus_mute(master_sound, true)
	else:
		audio_toggle.icon = audio_on_icon
		AudioServer.set_bus_mute(master_sound, false)
