@tool
class_name WarpLoopHandler
extends Node2D

@export var tile_lookup:TileMapLayer
@export var overlay_lookup:TileMapLayer
@export var start_tile:int = 0:
	set(value):
		start_tile = value
		position.x = start_tile*16
		end_tile = end_tile

@export var end_tile:int = 0:
	set(value):
		end_tile = max(value,0)
		$End.position.x = end_tile*16.0

@export var node_parents:Array[Node]
@export var force_include:Array[Node]
@export var tick_delay:int = 0 # used to give a delay so other maze nodes have a chance to finish
# create a list memory of tiles
var tile_memory = {}
var overlay_tile_memory = {}
# how many loops we're at
var loops:int = 0
# first is the node's parent, second is the node look
var entity_list:Array[Array] = [] # used for entities outside the maze to stop them looping
var entity_copies:Array[Array] = [] # used for copying entities inside the maze to the next loop
@export var persistant_node_shifts:Array[Node]

var shifted_offset:float = 0.0
var start_offset:int = 0 # added tiles from any mazes behind

signal activated

func _ready() -> void:
	if Engine.is_editor_hint(): return
	if !tile_lookup:
		print(name," Tile map not hooked up")
		return # skip if no tile warp found
	hide()
	for i in range(tick_delay):
		print(i)
		await get_tree().physics_frame
	# add parent scene to list of parents
	node_parents.append(get_parent())
	# write down our set of tiles to copy
	for i:Vector2i in tile_lookup.get_used_cells():
		# if tile position past or equeal start tile, write it down
		if i.x >= start_tile:
			# write down the details of the tile using the coordinants as key
			# we can use the key for tile placement later
			# verify if tile or packed scene
			var source_id = tile_lookup.get_cell_source_id(i)
			var scene_source = tile_lookup.tile_set.get_source(source_id)
			if scene_source is TileSetScenesCollectionSource:
				var alt_id = tile_lookup.get_cell_alternative_tile(i)
				# add PackedScene to entity copy list if in maze, otherwise shift forward list
				var scene = scene_source.get_scene_tile_scene(alt_id).instantiate()
				# set position
				scene.global_position = tile_lookup.global_position+(Vector2(i)*16.0)+Vector2.ONE*8.0
				# treat it like an entity
				if i.x < start_tile+end_tile:
					entity_copies.append([tile_lookup,scene])
				else:
					# add to scene
					entity_list.append([get_parent(),scene])
					get_parent().add_child.call_deferred(scene)
					tile_lookup.erase_cell(i)
			else:
				tile_memory[i] = [tile_lookup.get_cell_source_id(i),tile_lookup.get_cell_atlas_coords(i)]
			
	# repeat the same process for overlay tiles if they exist
	if overlay_lookup:
		for i:Vector2i in overlay_lookup.get_used_cells():
			if i.x >= start_tile:
				var source_id = overlay_lookup.get_cell_source_id(i)
				var scene_source = overlay_lookup.tile_set.get_source(source_id)
				if scene_source is TileSetScenesCollectionSource:
					var alt_id = overlay_lookup.get_cell_alternative_tile(i)
					var scene = scene_source.get_scene_tile_scene(alt_id).instantiate()
					scene.global_position = overlay_lookup.global_position+(Vector2(i)*16.0)+Vector2.ONE*8.0
					if i.x < start_tile+end_tile:
						entity_copies.append([overlay_lookup,scene])
					else:
						# add to scene
						entity_list.append([get_parent(),scene])
						get_parent().add_child.call_deferred(scene)
						overlay_lookup.erase_cell(i)
				else:
					overlay_tile_memory[i] = [overlay_lookup.get_cell_source_id(i),overlay_lookup.get_cell_atlas_coords(i)]
		
	# get all nodes from parent node, only record if after the starting point
	for parent in node_parents:
		if !is_instance_valid(parent): break
		for i in parent.get_children():
			# check if node 2D (need to check positions)
			# also check for exceptions (drop shadows)
			if i is Node2D && i is not DropShadow && i is not TileMapLayer && i is not LevelBG && i != self && i is not Player || force_include.has(i):
				if i.global_position.x >= start_tile*16.0:
					# check if in maze section, if it is create a list of duplicate entities
					if i.global_position.x < (start_tile+end_tile) * 16.0:
						if i.has_signal("player_teleported") || persistant_node_shifts.has(i): # check if maze warp, if it is then add to shifted entity list instead
							entity_list.append([i.get_parent(),i])
						elif i is not EntityGenerator: # do a check for objects like entity generators
							entity_copies.append([i.get_parent(),i.duplicate()])
					else:
						entity_list.append([i.get_parent(),i])
	


func maze_loop():
	loops += 1
	
	for i:Vector2i in tile_lookup.get_used_cells():
		if i.x >= start_tile + (end_tile * loops):
			tile_lookup.erase_cell(i)
	# repeat process for overlays
	if overlay_lookup:
		for i:Vector2i in overlay_lookup.get_used_cells():
			if i.x >= start_tile + (end_tile * loops):
				overlay_lookup.erase_cell(i)
	
	# layout the tiles again
	for i:Vector2i in tile_memory:
		tile_lookup.set_cell(i+Vector2i(start_offset + (end_tile * loops),0),tile_memory[i][0],tile_memory[i][1])
	# repeat for overlays
	if overlay_lookup:
		for i:Vector2i in overlay_tile_memory:
			overlay_lookup.set_cell(i+Vector2i(start_offset + (end_tile * loops),0),overlay_tile_memory[i][0],overlay_tile_memory[i][1])
	# handle the entities
	for i in entity_list:
		# check if instance is still valid
		if is_instance_valid(i[1]):
			i[0].remove_child(i[1])
			i[1].position.x += end_tile * 16.0
			i[0].add_child.call_deferred(i[1])
			# check for a stating position variable (moving platform in LL 5-3)
			if i[1].get("starting_position") != null:
				i[1].starting_position.x += end_tile * 16.0
			if i[1] is WarpLoopHandler:
				#i.loops += 1
				# shift start point on warp handler
				i[1].start_tile += end_tile
				i[1].start_offset += end_tile
				# increase shifted offset for duplicated entities
				i[1].shifted_offset += end_tile*16.0

	# shift border
	Player.camera_right_limit += end_tile * 16
	# create duplicate entities
	for i in entity_copies:
		# make sure to make it a duplicate since we need to re use this for another maze loop
		await get_tree().physics_frame # frame delay to prevent bottlenecks
		var dup_ent = i[1].duplicate()
		i[0].add_child.call_deferred(dup_ent)
		# change position to the new maze
		dup_ent.position.x += (end_tile*16.0 * loops) + shifted_offset
	activated.emit()
	
