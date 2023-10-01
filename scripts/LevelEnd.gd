extends Panel

signal retry
signal next_level

onready var header = $MarginContainer/VBoxContainer/Header
onready var level_score = $MarginContainer/VBoxContainer/LevelScore
onready var total_score = $MarginContainer/VBoxContainer/TotalScore
onready var next_level = $MarginContainer/VBoxContainer/NextLevel

func set_header(text):
	header.text = text

func set_scores(level_points, total_points):
	level_score.text = "Level Score: " + str(level_points)
	total_score.text = "Total Score: " + str(total_points)

func enable_next_level():
	next_level.visible = true

func _on_NextLevel_pressed():
	emit_signal("next_level")
	queue_free()

func _on_Retry_pressed():
	emit_signal("retry")
	queue_free()
