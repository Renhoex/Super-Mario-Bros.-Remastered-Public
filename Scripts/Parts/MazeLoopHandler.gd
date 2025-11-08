@tool
class_name WarpLoopHandler
extends Node2D

@export var tile_lookup:TileMapLayer
@export var start_tile:int = 0:
	set(value):
		start_tile = value
		position.x = start_tile*16
		end_tile = end_tile

@export var end_tile:int = 0:
	set(value):
		end_tile = max(value,0)
		$End.position.x = end_tile*16.0
# create a list memory of tiles
var tile_memory = {}
# how many loops we're at
var loops:int = 0
var entity_list:Array[Node2D] = [] # used for entities outside the maze to stop them looping
var entity_copies:Array[Node2D] = [] # used for copying entities inside the maze to the next loop

var shifted_offset:float = 0.0
var start_offset:int = 0 # added tiles from any mazes behind

func _ready() -> void:
	if Engine.is_editor_hint(): return
	hide()
	# write down our set of tiles to copy
	for i:Vector2i in tile_lookup.get_used_cells():
		# if tile position past or equeal start tile, write it down
		if i.x >= start_tile:
			# write down the details of the tile using the coordinants as key
			# we can use the key for tile placement later
			tile_memory[i] = [tile_lookup.get_cell_source_id(i),tile_lookup.get_cell_atlas_coords(i)]
	# get all nodes from parent node, only record if after the starting point
	for i in get_parent().get_children():
		# check if node 2D (need to check positions)
		# also check for exceptions (drop shadows)
		if i is Node2D && i is not DropShadow && i is not TileMapLayer && i is not LevelBG && i != self:
			if i.global_position.x >= start_tile*16.0:
				# check if in maze section, if it is create a list of duplicate entities
				if i.global_position.x < (start_tile+end_tile) * 16.0:
					if i.has_signal("player_teleported"): # check if maze warp, if it is then add to shifted entity list instead
						entity_list.append(i)
					else:
						entity_copies.append(i.duplicate())
				else:
					entity_list.append(i)
	


func maze_loop():
	loops += 1
	print(loops)
	for i:Vector2i in tile_lookup.get_used_cells():
		if i.x >= start_tile + (end_tile * loops):
			tile_lookup.erase_cell(i)
	# layout the tiles again
	for i:Vector2i in tile_memory:
		tile_lookup.set_cell(i+Vector2i(start_offset + (end_tile * loops),0),tile_memory[i][0],tile_memory[i][1])
	# handle the entities
	for i in entity_list:
		# check if instance is still valid
		if is_instance_valid(i):
			i.position.x += end_tile * 16.0
			if i is WarpLoopHandler:
				#i.loops += 1
				# shift start point on warp handler
				i.start_tile += end_tile
				i.start_offset += end_tile
				# increase shifted offset for duplicated entities
				i.shifted_offset += end_tile*16.0

	# shift border
	Player.camera_right_limit += end_tile * 16
	# create duplicate entities
	for i in entity_copies:
		# make sure to make it a duplicate since we need to re use this for another maze loop
		await get_tree().physics_frame # frame delay to prevent bottlenecks
		var dup_ent = i.duplicate()
		get_parent().add_child.call_deferred(dup_ent)
		# change position to the new maze
		dup_ent.position.x += (end_tile*16.0 * loops) + shifted_offset
