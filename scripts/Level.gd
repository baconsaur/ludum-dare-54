class_name Level
extends Node2D

signal dino_exited
signal level_complete

export var tile_offset = Vector2(0, 4)

var turn : int = 0
var astar_grid : AStar2D
var dinosaurs = []
var grid = []
var lava_tiles = []

var debug_rock = preload("res://scenes/Rock.tscn")

onready var exit = $Ground/YSort/Exit
onready var tile_map : TileMap = $Ground

func _ready():
	dinosaurs = [$Ground/YSort/Dinosaur]
	create_astar_grid()

func process_turn():
	for dinosaur in dinosaurs:
		var path = generate_path(dinosaur.position, exit.position)
		if path.size() > 2:
			dinosaur.position = tile_map.map_to_world(grid[path[1]]) + tile_offset
		else:
			dinosaur.queue_free()
			dinosaurs.erase(dinosaur)
			emit_signal("dino_exited")
			
			if not dinosaurs:
				emit_signal("level_complete")

func generate_path(start_coords: Vector2, end_coords: Vector2):
	var start_cell = tile_map.world_to_map(start_coords - tile_offset)
	var end_cell = tile_map.world_to_map(end_coords - tile_offset)

	return astar_grid.get_id_path(get_cell_id(start_cell), get_cell_id(end_cell))

func update_astar_grid():
	for lava_tile in lava_tiles:
		pass

func create_astar_grid():
	astar_grid = AStar2D.new()
	grid = tile_map.get_used_cells()
	
	for i in range(grid.size()):
		astar_grid.add_point(i, grid[i])

	for i in range(grid.size()):
		var cell = grid[i]
		var neighbors = get_cell_neighbors(cell.x, cell.y)
		for neighbor in neighbors:
			if neighbor in grid:
				astar_grid.connect_points(i, get_cell_id(neighbor))

func get_cell_id(grid_cell: Vector2):
	return grid.find(grid_cell)

func get_cell_neighbors(x, y):
	return [
		Vector2(x,y-1),
		Vector2(x,y+1),
		Vector2(x-1,y),
		Vector2(x+1,y),
	]
