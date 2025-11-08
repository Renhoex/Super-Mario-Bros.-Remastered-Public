extends Node2D

@export var reset_pos := Vector2.ZERO
@export_category("Maze loop settings")
@export var warp_handler:WarpLoopHandler
@export var start_position_shift:Vector2 = Vector2.ZERO

signal player_teleported
func _ready() -> void:
	# shift the hitbox back if we're using the classic warp system (mitigates wide screen issues)
	if warp_handler && Global.current_game_mode != Global.GameMode.CHALLENGE && Global.current_campaign != "SMBANN":
		$Hitbox.position += start_position_shift


func on_player_entered(_player: Player) -> void:
	if get_child_count() <= 1:
		for i in get_tree().get_nodes_in_group("Players"):
			teleport_player(i)
		return
	for i in get_children():
		if i is PickAPathPoint:
			if not i.crossed:
				for x in get_tree().get_nodes_in_group("Players"):
					teleport_player(x)
				return
	queue_free()

func teleport_player(player: Player) -> void:
	for i in get_children():
		if i is PickAPathPoint:
			i.crossed = false
	# Challenges are handled in their own node
	if warp_handler && Global.current_game_mode != Global.GameMode.CHALLENGE && Global.current_campaign != "SMBANN":
		warp_handler.maze_loop()
	else:
		player.teleport_player(reset_pos)
	player_teleported.emit()
