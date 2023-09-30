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
var rock_tiles = []
var lava_indices = []
var exit_index = -1
var rock_indices = []
var lava_obj = preload("res://scenes/Lava.tscn")

var debug_rock = preload("res://scenes/Rock.tscn")

onready var exit = $Ground/YSort/Exit
onready var tile_map : TileMap = $Ground
onready var y_sort = $Ground/YSort

func _ready():
	var tree = get_tree()
	dinosaurs = tree.get_nodes_in_group("dinosaurs")
	lava_tiles = tree.get_nodes_in_group("lava")
	rock_tiles = tree.get_nodes_in_group("rocks")
	
	set_up_map()

func process_turn():
	for dinosaur in dinosaurs:
		var path = generate_path(dinosaur.position, exit.position)
		if path.size() > 1:
			dinosaur.position = tile_map.map_to_world(grid[path[1]]) + tile_offset
			if dinosaur.position == exit.position:
				dinosaur.queue_free()
				dinosaurs.erase(dinosaur)
				emit_signal("dino_exited")
		# TODO flee nearest lava if exit is inaccessible
	
	spread_lava()
	if not dinosaurs or exit_index in lava_indices:
		# TODO pause and show modal
		emit_signal("level_complete")
	preview_next_turn()

func spread_lava():
	var neighbors = []
	for tile in lava_tiles:
		var cell = tile_map.world_to_map(tile.position - tile_offset)
		var cell_neighbors = get_cell_neighbors(cell.x, cell.y)
		for neighbor in cell_neighbors:
			if not neighbor in neighbors:
				neighbors.append(neighbor)
	for neighbor in neighbors:
		var neighbor_index = map_cell_to_index(neighbor)
		if neighbor_index > 0 and not neighbor_index in rock_indices:
			var lava_instance = lava_obj.instance()
			y_sort.add_child(lava_instance)
			lava_instance.position = tile_map.map_to_world(neighbor) + tile_offset
			lava_tiles.append(lava_instance)
	disable_lava_tiles()
	
	for dinosaur in dinosaurs:
		var dino_index = tile_position_to_index(dinosaur.position)
		if dino_index in lava_indices:
			dinosaur.queue_free()
			dinosaurs.erase(dinosaur)

func preview_next_turn():
	# TODO
	pass

func generate_path(start: Vector2, end: Vector2):
	return astar_grid.get_id_path(tile_position_to_index(start), tile_position_to_index(end))

func set_up_map():
	grid = tile_map.get_used_cells()
	create_astar_grid()
	disable_lava_tiles()
	disable_rock_tiles()
	preview_next_turn()
	exit_index = tile_position_to_index(exit.position)

func disable_lava_tiles():
	for tile in lava_tiles:
		var tile_cell = tile_map.world_to_map(tile.position - tile_offset)
		var lava_index = map_cell_to_index(tile_cell)
		lava_indices.append(lava_index)
		astar_grid.set_point_disabled(lava_index, true)

func disable_rock_tiles():
	for tile in rock_tiles:
		var tile_cell = tile_map.world_to_map(tile.position - tile_offset)
		var rock_index = map_cell_to_index(tile_cell)
		rock_indices.append(rock_index)
		astar_grid.set_point_disabled(rock_index, true)

func create_astar_grid():
	astar_grid = AStar2D.new()
	
	for i in range(grid.size()):
		astar_grid.add_point(i, grid[i])

	for i in range(grid.size()):
		var cell = grid[i]
		var neighbors = get_cell_neighbors(cell.x, cell.y)
		for neighbor in neighbors:
			if neighbor in grid:
				astar_grid.connect_points(i, map_cell_to_index(neighbor))

func tile_position_to_index(tile):
	var tile_cell = tile_map.world_to_map(tile - tile_offset)
	return map_cell_to_index(tile_cell)

func map_cell_to_index(grid_cell: Vector2):
	return grid.find(grid_cell)

func get_cell_neighbors(x, y):
	return [
		Vector2(x,y-1),
		Vector2(x,y+1),
		Vector2(x-1,y),
		Vector2(x+1,y),
	]
