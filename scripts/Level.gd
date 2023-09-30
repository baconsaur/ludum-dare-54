class_name Level
extends Node2D

signal dino_exited
signal level_complete
signal turn_complete

export var turn_time_seconds = 0.25

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
var turn_timer = 0
var dino_preview_obj = preload("res://scenes/DinoPreview.tscn")
var lava_warning_obj = preload("res://scenes/LavaWarning.tscn")
var dino_previews = []
var lava_warnings = []
var group_preview_sprite = preload("res://sprites/dino_preview_group.png")

onready var exit = $Ground/YSort/Exit
onready var tile_map : TileMap = $Ground
onready var y_sort = $Ground/YSort

func _ready():
	set_up_map()

func _process(delta):
	if turn_timer > 0:
		turn_timer -= delta
		if turn_timer <= 0:
			end_turn()
			if not dinosaurs or exit_index in lava_indices:
				emit_signal("level_complete")
			else:
				preview_next_turn()
				emit_signal("turn_complete")

func process_turn():
	remove_tiles(dino_previews)
	remove_tiles(lava_warnings)
	for dinosaur in dinosaurs:
		var next_move = calculate_next_move(dinosaur)
		if next_move:
			dinosaur.position = next_move
			# TODO flee nearest lava if exit is inaccessible
	# TODO split up dino/lava movement timing
	turn_timer = turn_time_seconds

func calculate_lava_spread():
	var spread_tiles = []
	var neighbors = []
	for tile in lava_tiles:
		var cell = tile_map.world_to_map(tile.position)
		var cell_neighbors = get_cell_neighbors(cell.x, cell.y)
		for neighbor in cell_neighbors:
			if not neighbor in neighbors:
				neighbors.append(neighbor)
	for neighbor in neighbors:
		var neighbor_index = map_cell_to_index(neighbor)
		if neighbor_index in rock_indices or neighbor_index in lava_indices:
			continue
		if neighbor_index >= 0:
			var tile_pos = tile_map.map_to_world(neighbor)
			spread_tiles.append(tile_pos)
	return spread_tiles

func spread_lava():
	for tile_pos in calculate_lava_spread():
		var lava_instance = lava_obj.instance()
		y_sort.add_child(lava_instance)
		lava_instance.position = tile_pos
		lava_tiles.append(lava_instance)
	disable_lava_tiles()

func calculate_next_move(dinosaur):
	var path = generate_path(dinosaur.position, exit.position)
	if path.size() > 1:
		return tile_map.map_to_world(grid[path[1]])

func end_turn():
	var dinosaur_map = {}
	for dinosaur in dinosaurs:
		if dinosaur.position == exit.position:
			emit_signal("dino_exited", dinosaur.points)
			dinosaur.queue_free()
			dinosaurs.erase(dinosaur)
		else:
			var dino_index = tile_position_to_index(dinosaur.position)
			if dino_index in dinosaur_map:
				dinosaur_map[dino_index].append(dinosaur)
			else:
				dinosaur_map[dino_index] = [dinosaur]
	merge_dinos(dinosaur_map)
	spread_lava()
	check_dino_lives()

func check_dino_lives():
	for dinosaur in dinosaurs:
		var dino_index = tile_position_to_index(dinosaur.position)
		if dino_index in lava_indices:
			dinosaur.queue_free()
			dinosaurs.erase(dinosaur)

func find_safe_space(current_index):
	var warning_indices = []
	for tile in lava_warnings:
		 warning_indices.append(tile_position_to_index(tile.position))

	var neighbors = astar_grid.get_point_connections(current_index)
	if not neighbors:
		return current_index
	
	var neighbor_safe_tiles = {}
	var neighbor_warning_tiles = {}
	var neighbor_total_connections = {}
	for neighbor in neighbors:
		if astar_grid.is_point_disabled(neighbor):
				continue
		# From remaining options, check neighbors' neighbors for clear tiles, lava and lava warnings
		var neighbor_neighbors = astar_grid.get_point_connections(neighbor)
		var connection_count = neighbor_neighbors.size()
		var warning_count = 0
		var obstacle_count = 0
		neighbor_total_connections[neighbor] = neighbor_neighbors.size()
		for next_neighbor in neighbor_neighbors:
			if next_neighbor in warning_indices:
				warning_count += 1
			elif astar_grid.is_point_disabled(neighbor):
				obstacle_count -= 1
			neighbor_safe_tiles[neighbor] = connection_count - obstacle_count - warning_count
			neighbor_warning_tiles[neighbor] = warning_count

	
	# Prioritize/tie break options in this order:
	#	1. Most safe adjacent spaces (no warnings or obstacles)
	var max_safe = neighbor_safe_tiles.values().max()
	var most_safe_candidates = []
	for neighbor in neighbor_safe_tiles:
		if neighbor_safe_tiles[neighbor] < max_safe:
			neighbor_warning_tiles.erase(neighbor)
			neighbor_total_connections.erase(neighbor)
		most_safe_candidates.append(neighbor)
	if most_safe_candidates.size() == 1:
		return most_safe_candidates[0]
		
	#	2. Fewest adjacent warnings
	var min_warnings = neighbor_warning_tiles.values().max()
	var least_warning_candidates = []
	for neighbor in neighbor_warning_tiles:
		if neighbor_warning_tiles[neighbor] > min_warnings:
			neighbor_total_connections.erase(neighbor)
		least_warning_candidates.append(neighbor)
	if least_warning_candidates.size() == 1:
		return least_warning_candidates[0]

	#	3. Most total connections (including obstacles)
	var max_connections = neighbor_total_connections.values().max()
	var most_connection_candidates = []
	for neighbor in neighbor_total_connections:
		if neighbor_total_connections[neighbor] < max_connections:
			continue
		most_connection_candidates.append(neighbor)
	if most_connection_candidates.size() == 1:
		return most_connection_candidates[0]

	#	4. Closest to exit
	var distances = {}
	for candidate in most_connection_candidates:
		distances[candidate] = grid[candidate].distance_to(grid[exit_index])
	var min_distance = distances.values().min()

	var final_candidates = []
	for neighbor in distances:
		if distances[neighbor] < min_distance:
			continue
		final_candidates.append(neighbor)
	if final_candidates.size() == 1:
		return final_candidates[0]
	
	#	5. Lowest index (it should never come to this, right? Idk, I'm tired, this whole function is awful, and I probably should be writing tests but on we go)
	return final_candidates.min()


func merge_dinos(dinosaur_map):
	for i in dinosaur_map:
		var dinos_at_i = dinosaur_map[i]
		if dinos_at_i.size() > 1:
			var first = dinos_at_i.pop_front()
			for dino in dinos_at_i:
				first.add_unit(dino)
				dino.queue_free()
				dinosaurs.erase(dino)

func preview_next_turn():
	for tile_pos in calculate_lava_spread():
		var lava_warning = lava_warning_obj.instance()
		y_sort.add_child(lava_warning)
		lava_warning.position = tile_pos
		lava_warnings.append(lava_warning)
	var dinosaur_preview_map = {}
	for dinosaur in dinosaurs:
		var next_move = calculate_next_move(dinosaur)
		if not next_move:
			continue
		if next_move in dinosaur_preview_map:
			dinosaur_preview_map[next_move] += 1
		else:
			dinosaur_preview_map[next_move] = 1
	for next_move in dinosaur_preview_map:
		var dino_preview = dino_preview_obj.instance()
		y_sort.add_child(dino_preview)
		dino_preview.position = next_move
		if dinosaur_preview_map[next_move] > 1:
			dino_preview.get_child(0).texture = group_preview_sprite
		dino_previews.append(dino_preview)

func generate_path(start: Vector2, end: Vector2):
	var start_index = tile_position_to_index(start)
	var end_index = tile_position_to_index(end)
	var path = astar_grid.get_id_path(start_index, end_index)
	if not path:
		var next_move = find_safe_space(start_index)
		if next_move != null:
			return [start_index, next_move]
	return path

func set_up_map():
	grid = tile_map.get_used_cells()
	
	var tree = get_tree()
	dinosaurs = tree.get_nodes_in_group("dinosaurs")
	lava_tiles = tree.get_nodes_in_group("lava")
	rock_tiles = tree.get_nodes_in_group("rocks")
	exit_index = tile_position_to_index(exit.position)
	
	create_astar_grid()
	disable_lava_tiles()
	disable_rock_tiles()
	preview_next_turn()

func disable_lava_tiles():
	for tile in lava_tiles:
		var tile_cell = tile_map.world_to_map(tile.position)
		var lava_index = map_cell_to_index(tile_cell)
		lava_indices.append(lava_index)
		astar_grid.set_point_disabled(lava_index, true)

func disable_rock_tiles():
	for tile in rock_tiles:
		var tile_cell = tile_map.world_to_map(tile.position)
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
	var tile_cell = tile_map.world_to_map(tile)
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

func remove_tiles(tiles):
	for i in range(tiles.size()):
		tiles.pop_back().queue_free()
