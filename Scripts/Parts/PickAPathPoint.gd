class_name PickAPathPoint
extends Node2D

@export_category("Maze loop settings")
@export var start_position_shift:Vector2 = Vector2.ZERO

var crossed := false

func _ready() -> void:
	# shift the hitbox back if we're using the classic warp system (mitigates wide screen issues)
	if Global.current_game_mode != Global.GameMode.CHALLENGE && Global.current_campaign != "SMBANN":
		$Hitbox.position += start_position_shift

func on_player_entered(_player: Player) -> void:
	if not crossed: 
		AudioManager.play_global_sfx("correct")
	crossed = true
