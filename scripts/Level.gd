class_name Level
extends Node2D

signal dino_exited
signal level_complete
signal turn_complete
signal object_selected
signal object_deselected

export var turn_time_seconds = 0.25
export var tile_offset = + Vector2(0, 4)
export var snap_tolerance = 4

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
var paused_rock_indices = []
var pending_rock_indices = []
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
var object_preview = null
var available_tiles = []
var available_tile_coords = []
var last_snap = Vector2.ZERO
var snap_distance = 0
var hovered_object = null
var object_rotations_done = 0
var burn_particles = preload("res://scenes/BurnParticles.tscn")
var group_particles = preload("res://scenes/GroupParticles.tscn")
var beam_particles = preload("res://scenes/BeamParticles.tscn")

onready var exit = $Ground/YSort/Exit
onready var tile_map : TileMap = $Ground
onready var y_sort = $Ground/YSort
onready var preview_node = $ObjectPreview
onready var burn_sound = $BurnSound
onready var group_sound = $GroupSound
onready var exit_sound = $ExitSound
onready var fail_sound = $FailSound

func _ready():
	set_up_map()

func _process(delta):
	if turn_timer > 0:
		turn_timer -= delta
		if turn_timer <= 0:
			finish_turn_processing()
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
		if selected_object and event.button_index == BUTTON_RIGHT:
			deselect_object()
	if event is InputEventMouseMotion and selected_object and snap_distance > 0:
		snap_distance -= last_snap.distance_to(event.relative)
		if snap_distance <= 0:
			var cursor_tile = tile_map.world_to_map(preview_node.global_position + tile_offset)
			if not cursor_tile in available_tile_coords:
				object_preview.set_preview(preview_node)

func start_turn_processing():
	# Clean up after player actions
	remove_tiles(available_tiles)
	available_tile_coords = []
	deselect_object()

	# Move dinosaurs
	remove_tiles(dino_previews)
	dino_indices = []
	for dinosaur in dinosaurs:
		var next_move = calculate_next_move(dinosaur)
		if next_move != null:
			dinosaur.global_position = next_move
			dino_indices.append(tile_position_to_index(next_move))
	merge_dinos()
	
	# Pause for movement to be displayed
	turn_timer = turn_time_seconds

func finish_turn_processing():
	# Move lava
	remove_tiles(lava_warnings)
	spread_lava()
	
	# Check if dinosaurs should die
	check_dino_lives()
	if not dinosaurs:
		emit_signal("level_complete")
		return
	# End level if the exit is gone
	if exit_index in lava_indices:
		fail_sound.play()
		emit_signal("level_complete")
		return

	# Wrap up turn
	turn += 1
	preview_next_turn()
	emit_signal("turn_complete")

func merge_dinos():
	var dinosaur_map = {}
	for dinosaur in dinosaurs:
		var dino_index = tile_position_to_index(dinosaur.global_position)
		if dino_index in dinosaur_map:
			dinosaur_map[dino_index].append(dinosaur)
		else:
			dinosaur_map[dino_index] = [dinosaur]

	var dinos_merged = false
	for i in dinosaur_map:
		var dinos_at_i = dinosaur_map[i]
		if dinos_at_i.size() > 1:
			var group_particles_inst = group_particles.instance()
			add_child(group_particles_inst)
			group_particles_inst.global_position = dinos_at_i[0].global_position
			group_particles_inst.emitting = true
			dinos_merged = true
			var first = dinos_at_i.pop_front()
			for dino in dinos_at_i:
				first.add_unit(dino)
				dino.queue_free()
				dinosaurs.erase(dino)
	if dinos_merged:
		group_sound.play()
	
	var dino_exited = false
	for dinosaur in dinosaurs:
		if dinosaur.global_position == exit.global_position:
			dino_exited = true
			emit_signal("dino_exited", dinosaur.points)
			dinosaur.queue_free()
			dinosaurs.erase(dinosaur)
	if dino_exited:
		exit_sound.play()
		var exit_particles = beam_particles.instance()
		add_child(exit_particles)
		exit_particles.global_position = exit.global_position
		exit_particles.emitting = true

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

func check_dino_lives():
	var dino_died = false
	for dinosaur in dinosaurs:
		var dino_index = tile_position_to_index(dinosaur.global_position)
		if dino_index in lava_indices:
			dino_died = true
			var smoke = burn_particles.instance()
			add_child(smoke)
			smoke.global_position = dinosaur.global_position
			smoke.emitting = true
			dinosaur.queue_free()
			dinosaurs.erase(dinosaur)
	if dino_died:
		burn_sound.play()

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

func preview_next_turn():
	# Add lava warnings
	for tile_pos in calculate_lava_spread():
		var lava_warning = lava_warning_obj.instance()
		y_sort.add_child(lava_warning)
		lava_warning.global_position = tile_pos
		lava_warnings.append(lava_warning)
		astar_grid.set_point_weight_scale(tile_position_to_index(tile_pos), 2)
	
	# Add dino movement previews
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
		for rock in group.rocks:
			rock_offsets.append(tile_map.world_to_map(rock.global_position) - center_rock_cell)
		group.set_offsets(rock_offsets)
		group.connect("select_group", self, "select_object", [group])
		group.connect("hover_group", self, "hover_object", [group])
		group.connect("unhover_group", self, "unhover_object")
	
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
		if rock_index >= 0:
			astar_grid.set_point_disabled(rock_index, true)

func enable_rock_tiles(tiles):
	for tile in tiles:
		var tile_cell = tile_map.world_to_map(tile.global_position)
		var rock_index = map_cell_to_index(tile_cell)
		rock_indices.erase(rock_index)
		if rock_index != exit_index and not rock_index in lava_indices:
			# Shouldn't happen but I'm short on debugging time so might as well cover my ass
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
	unhover_object()
	if selected_object:
		# I think this was supposed to be for toggling, not sure if I need it anymore
		remove_tiles(available_tiles)
		available_tile_coords = []
		selected_object.deselect()
	
	obj.select()
	selected_object = obj
	# Make the old spaces available again
	enable_rock_tiles(selected_object.rocks)
	
	# Display helpers
	create_object_preview()
	highlight_valid_moves(selected_object)
	
	# Track rotations
	object_rotations_done = 0
	emit_signal("object_selected")

func deselect_object():
	if not selected_object:
		return
	remove_placement_preview()
	remove_tiles(available_tiles)
	available_tile_coords = []
	selected_object.deselect()
	selected_object = null
	emit_signal("object_deselected")

func highlight_valid_moves(piece):
	if not piece:
		return
	for tile in grid:
		if not can_piece_fit(piece, tile):
			continue
		var selectable_tile_inst = selectable_tile_tile.instance()
		selectable_tile_inst.connect("selected", self, "place_object", [tile])
		selectable_tile_inst.connect("hovered", self, "preview_placement", [tile])
		selectable_tile_inst.connect("unhovered", self, "restore_preview", [tile])
		y_sort.add_child(selectable_tile_inst)
		available_tiles.append(selectable_tile_inst)
		available_tile_coords.append(tile)
		selectable_tile_inst.global_position = tile_map.map_to_world(tile)

func can_piece_fit(piece, target_tile):
	if not is_tile_available(target_tile):
		return false
	var no_illegal_parts = true
	for offset in piece.offsets:
		var offset_tile = target_tile + offset
		if not offset_tile in grid:
			no_illegal_parts = false
			break
		if not is_tile_available(offset_tile):
			no_illegal_parts = false
			break
	return no_illegal_parts

func is_tile_available(tile):
	var tile_index = map_cell_to_index(tile)
	if tile_index < 0:
		return false
	if tile_index == exit_index:
		return false
	if (tile_index in lava_indices) or (tile_index in rock_indices) or (tile_index in dino_indices):
		return false
	if astar_grid.is_point_disabled(tile_index):
		return false
	return true

func preview_placement(tile):
	if not selected_object:
		return
	if not object_preview:
		return
	object_preview.place_preview(y_sort, tile_map.map_to_world(tile))

func create_object_preview():
	if not selected_object:
		return

	object_preview = selected_object.duplicate()
	y_sort.add_child(object_preview)
	object_preview.set_preview(preview_node)

func restore_preview(tile):
	if not object_preview:
		return
	snap_distance = snap_tolerance

func remove_placement_preview():
	if object_preview:
		object_preview.get_parent().remove_child(object_preview)
		object_preview.queue_free()
	object_preview = null
	if selected_object:
		var rocks = selected_object.rocks
		disable_rock_tiles(rocks)

func place_object(tile):
	if not selected_object and not object_preview:
		return

	var original_position = selected_object.global_position
	
	var actual_rocks = selected_object.rocks
	var preview_rocks = object_preview.rocks
	for i in range(preview_rocks.size()):
		actual_rocks[i].position = preview_rocks[i].position
	selected_object.global_position = tile_map.map_to_world(tile)
	var final_position = selected_object.global_position

	if object_rotations_done % 4 != 0 or original_position != final_position:
		# Apologies to everyone who rotates symmetrical pieces then puts them back, I just don't have the time for it
		start_turn_processing()
	else:
		deselect_object()

func rotate_left():
	if not object_preview:
		return
	rotate_direction(Vector2(1, -1))
	object_rotations_done -= 1

func rotate_right():
	if not object_preview:
		return
	rotate_direction(Vector2(-1, 1))
	object_rotations_done += 1

func rotate_direction(direction_modifier: Vector2):
	var rocks = object_preview.rocks

	var start_position = object_preview.global_position
	var start_origin = tile_map.world_to_map(start_position)
	
	# Calculate everything based on the original object's origin for simplicity
	object_preview.global_position = selected_object.global_position
	var origin = tile_map.world_to_map(selected_object.global_position)

	var offsets = []
	for rock in rocks:
		var map_cell = tile_map.world_to_map(rock.global_position)
		var map_minus_origin = map_cell - origin
		var new_cell_pos = Vector2(map_minus_origin.y, map_minus_origin.x) * direction_modifier
		rock.global_position = tile_map.map_to_world(new_cell_pos + origin)
		offsets.append(new_cell_pos)
		object_preview.set_offsets(offsets)

	remove_tiles(available_tiles)
	available_tile_coords = []

	highlight_valid_moves(object_preview)
	
	object_preview.global_position = start_position
	if not can_piece_fit(object_preview, start_origin):
		object_preview.set_invalid()
		snap_distance = snap_tolerance
	else:
		object_preview.set_valid()

func hover_object(obj):
	if hovered_object or selected_object:
		return
	obj.hover()
	hovered_object = obj

func unhover_object():
	if not hovered_object:
		return
	hovered_object.unhover()
	hovered_object = null
