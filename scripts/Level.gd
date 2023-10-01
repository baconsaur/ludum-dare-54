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
var lava_indices = []
var rock_tiles = []
var rock_groups = []
var exit_index = -1
var rock_indices = []
var lava_obj = preload("res://scenes/Lava.tscn")
var turn_timer = 0
var dino_preview_obj = preload("res://scenes/DinoPreview.tscn")
var lava_warning_obj = preload("res://scenes/LavaWarning.tscn")
var selectable_tile_tile = preload("res://scenes/SelectableTile.tscn")
var dino_previews = []
var dino_indices = []
var lava_warnings = []
var group_preview_sprite = preload("res://sprites/dino_preview_group.png")
var selected_object = null
var available_tiles = []

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
		return
	
	if not selected_object:
		return
		
	if Input.is_action_just_pressed("deselect"):
		deselect_object()
	elif Input.is_action_just_pressed("left"):
		rotate_left()
	elif Input.is_action_just_pressed("right"):
		rotate_right()

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos = get_global_mouse_position() + Vector2(0, 4) # Fuck it
		var cell_index = tile_position_to_index(mouse_pos)
		if cell_index < 0 or cell_index in rock_indices or cell_index in lava_indices:
			return
		print(cell_index)

func process_turn():
	remove_tiles(available_tiles)
	remove_tiles(dino_previews)
	dino_indices = []
	for dinosaur in dinosaurs:
		var next_move = calculate_next_move(dinosaur)
		if next_move != null:
			dinosaur.global_position = next_move
			dino_indices.append(tile_position_to_index(next_move))
	turn_timer = turn_time_seconds

func calculate_lava_spread():
	var spread_tiles = []
	var neighbors = []
	for tile in lava_tiles:
		var cell = tile_map.world_to_map(tile.global_position)
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
		lava_instance.global_position = tile_pos
		lava_tiles.append(lava_instance)
	disable_lava_tiles()

func calculate_next_move(dinosaur):
	var path = generate_path(dinosaur.global_position, exit.global_position)
	if path.size() > 1:
		return tile_map.map_to_world(grid[path[1]])

func end_turn():
	var dinosaur_map = {}
	for dinosaur in dinosaurs:
		if dinosaur.global_position == exit.global_position:
			emit_signal("dino_exited", dinosaur.points)
			dinosaur.queue_free()
			dinosaurs.erase(dinosaur)
		else:
			var dino_index = tile_position_to_index(dinosaur.global_position)
			if dino_index in dinosaur_map:
				dinosaur_map[dino_index].append(dinosaur)
			else:
				dinosaur_map[dino_index] = [dinosaur]
	merge_dinos(dinosaur_map)
	remove_tiles(lava_warnings)
	spread_lava()
	check_dino_lives()

func check_dino_lives():
	for dinosaur in dinosaurs:
		var dino_index = tile_position_to_index(dinosaur.global_position)
		if dino_index in lava_indices:
			dinosaur.queue_free()
			dinosaurs.erase(dinosaur)

func find_safe_space(current_index):
	var warning_indices = []
	for tile in lava_warnings:
		 warning_indices.append(tile_position_to_index(tile.global_position))

	var neighbors = astar_grid.get_point_connections(current_index)
	if not neighbors:
		return current_index
	
	# Include the option to stay put if it's the safest spot
	if not current_index in warning_indices:
		neighbors.append(current_index)
	
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
		lava_warning.global_position = tile_pos
		lava_warnings.append(lava_warning)
	var dinosaur_preview_map = {}
	for dinosaur in dinosaurs:
		var next_move = calculate_next_move(dinosaur)
		if next_move == null:
			continue
		if next_move in dinosaur_preview_map:
			dinosaur_preview_map[next_move] += 1
		else:
			dinosaur_preview_map[next_move] = 1
	for next_move in dinosaur_preview_map:
		var dino_preview = dino_preview_obj.instance()
		y_sort.add_child(dino_preview)
		dino_preview.global_position = next_move
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
	exit_index = tile_position_to_index(exit.global_position)
	
	var tree = get_tree()
	dinosaurs = tree.get_nodes_in_group("dinosaurs")
	lava_tiles = tree.get_nodes_in_group("lava")
	rock_tiles = tree.get_nodes_in_group("rocks")
	rock_groups = tree.get_nodes_in_group("rock_groups")
	
	for group in rock_groups:
		var rock_offsets = []
		var center_rock_cell = tile_map.world_to_map(group.global_position)
		for child in group.get_children():
			rock_offsets.append(tile_map.world_to_map(child.global_position) - center_rock_cell)
		group.set_offsets(rock_offsets)
		group.connect("select_group", self, "select_object", [group])
		group.connect("deselect_group", self, "deselect_object")
	
	for dinosaur in dinosaurs:
		dino_indices.append(tile_position_to_index(dinosaur.global_position))
	
	create_astar_grid()
	disable_lava_tiles()
	disable_rock_tiles(rock_tiles)
	preview_next_turn()

func disable_lava_tiles():
	for tile in lava_tiles:
		var tile_cell = tile_map.world_to_map(tile.global_position)
		var lava_index = map_cell_to_index(tile_cell)
		lava_indices.append(lava_index)
		astar_grid.set_point_disabled(lava_index, true)

func disable_rock_tiles(tiles):
	for tile in tiles:
		var tile_cell = tile_map.world_to_map(tile.global_position)
		var rock_index = map_cell_to_index(tile_cell)
		rock_indices.append(rock_index)
		astar_grid.set_point_disabled(rock_index, true)

func enable_rock_tiles(tiles):
	for tile in tiles:
		var tile_cell = tile_map.world_to_map(tile.global_position)
		var rock_index = map_cell_to_index(tile_cell)
		rock_indices.erase(rock_index)
		astar_grid.set_point_disabled(rock_index, false)

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

func select_object(obj):
	if selected_object:
		remove_tiles(available_tiles)
		selected_object.deselect()
	obj.select()
	selected_object = obj
	highlight_valid_moves()

func deselect_object():
	remove_tiles(available_tiles)
	selected_object.deselect()
	selected_object = null

func highlight_valid_moves():
	if not selected_object:
		return
	for tile in grid:
		if not is_tile_available(tile):
			continue
		var no_illegal_parts = true
		for offset in selected_object.offsets:
			var offset_tile = tile + offset
			if not offset_tile in grid:
				no_illegal_parts = false
				break
			if not is_tile_available(offset_tile):
				no_illegal_parts = false
				break
		if no_illegal_parts:
			var selectable_tile_inst = selectable_tile_tile.instance()
			selectable_tile_inst.connect("selected", self, "place_object", [tile])
			y_sort.add_child(selectable_tile_inst)
			available_tiles.append(selectable_tile_inst)
			selectable_tile_inst.global_position = tile_map.map_to_world(tile)

func is_tile_available(tile):
	var tile_index = map_cell_to_index(tile)
	print(tile_index)
	if tile_index < 0:
		return false
	if tile_index == exit_index:
		return false
	if (tile_index in lava_indices) or (tile_index in rock_indices) or (tile_index in dino_indices):
		return false
	if astar_grid.is_point_disabled(tile_index):
		return false
	return true

func place_object(tile):
	if not selected_object:
		return
	var rocks = selected_object.get_children()
	enable_rock_tiles(rocks)
	selected_object.global_position = tile_map.map_to_world(tile)
	disable_rock_tiles(rocks)
	deselect_object()
	process_turn()

func rotate_left():
	if not selected_object:
		return

	print("left")

func rotate_right():
	if not selected_object:
		return

	print("right")
