extends Node

## Global Game Manager - Handles game state, win/lose conditions

signal game_over(reason: String)
signal game_won()

enum GameState {
	PLAYING,
	PAUSED,
	GAME_OVER,
	WON
}

var current_state: GameState = GameState.PLAYING
var game_over_reason: String = ""

func _ready():
	print("[GameManager] Initialized")

func trigger_game_over(reason: String):
	"""Called when player loses"""
	if current_state != GameState.PLAYING:
		return
	
	current_state = GameState.GAME_OVER
	game_over_reason = reason
	print("[GameManager] 🔴 GAME OVER: ", reason)
	game_over.emit(reason)
	
	# Show game over screen after a short delay
	await get_tree().create_timer(2.0).timeout
	_show_game_over_screen()

func trigger_game_won():
	"""Called when player wins"""
	if current_state != GameState.PLAYING:
		return
	
	current_state = GameState.WON
	print("[GameManager] 🎉 GAME WON!")
	game_won.emit()
	
	await get_tree().create_timer(2.0).timeout
	_show_win_screen()

func _show_game_over_screen():
	# For now, just print - we can add a proper UI later
	print("\n" + "=".repeat(50))
	print("GAME OVER")
	print("Reason: ", game_over_reason)
	print("Press R to restart")
	print("=".repeat(50) + "\n")
	
	# TODO: Show actual game over UI

func _show_win_screen():
	print("\n" + "=".repeat(50))
	print("YOU ESCAPED!")
	print("Press R to restart")
	print("=".repeat(50) + "\n")
	
	# TODO: Show actual win screen UI

func _input(event):
	if current_state == GameState.GAME_OVER or current_state == GameState.GAME_WON:
		if event.is_action_pressed("ui_cancel"):  # R key
			restart_game()

func restart_game():
	get_tree().reload_current_scene()

func is_game_over() -> bool:
	return current_state == GameState.GAME_OVER or current_state == GameState.GAME_WON
