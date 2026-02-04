extends Node

## Global Game Manager - Handles game state, win/lose conditions, and background music

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

# Background Music System
const NORMAL_BGM_PATH: String = "res://Audio/BGM/BGM.mp3"
const CHASE_BGM_PATH: String = "res://Audio/BGM/ChaseMusic.wav"
@export_range(0.0, 1.0, 0.05) var music_crossfade_time: float = 0.0 ## Time to crossfade between tracks
@export_range(-80.0, 0.0, 0.5) var normal_music_volume: float = 0.0 ## Volume for normal BGM (dB)
@export_range(-80.0, 0.0, 0.5) var chase_music_volume: float = -12.0 ## Volume for chase music (dB)

var music_player: AudioStreamPlayer = null
var is_chase_music_playing: bool = false
var normal_bgm: AudioStream = null
var chase_bgm: AudioStream = null

func _ready():
	print("[GameManager] Initialized")
	
	# Load music files
	normal_bgm = load(NORMAL_BGM_PATH)
	chase_bgm = load(CHASE_BGM_PATH)
	
	if not normal_bgm:
		push_warning("[GameManager] Failed to load normal BGM from: " + NORMAL_BGM_PATH)
	if not chase_bgm:
		push_warning("[GameManager] Failed to load chase BGM from: " + CHASE_BGM_PATH)
	
	# Find existing music player in scene (Main scene has AudioStreamPlayer)
	# Search for any AudioStreamPlayer in the scene tree that's already playing
	await get_tree().process_frame  # Wait a frame for scene to fully load
	
	var root = get_tree().root
	music_player = _find_music_player(root)
	
	if music_player:
		print("[GameManager] Found existing music player: ", music_player.get_path())
		# Save original volume for normal music
		normal_music_volume = music_player.volume_db
	else:
		# Fallback: create our own player if none found
		print("[GameManager] No existing music player found, creating new one")
		music_player = AudioStreamPlayer.new()
		music_player.name = "MusicPlayer"
		music_player.bus = "Master"
		add_child(music_player)
		
		# Start normal BGM if loaded
		if normal_bgm:
			play_normal_music()

func _find_music_player(node: Node) -> AudioStreamPlayer:
	"""Recursively search for an AudioStreamPlayer that's playing BGM."""
	if node is AudioStreamPlayer:
		# Check if it's playing or has BGM stream
		if node.playing or (node.stream and node.stream.resource_path.contains("BGM")):
			return node
	
	for child in node.get_children():
		var result = _find_music_player(child)
		if result:
			return result
	
	return null

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
	print("Press Tab to open menu and restart")
	print("=".repeat(50) + "\n")
	
	# TODO: Show actual game over UI

func _show_win_screen():
	print("\n" + "=".repeat(50))
	print("YOU ESCAPED!")
	print("Press Tab to open menu and restart")
	print("=".repeat(50) + "\n")
	
	# TODO: Show actual win screen UI


# ============ MUSIC SYSTEM ============

func play_normal_music():
	"""Start or resume normal background music."""
	if not normal_bgm:
		return
	
	if is_chase_music_playing:
		print("[GameManager] 🎵 Switching to normal music")
		_crossfade_to_track(normal_bgm, normal_music_volume)
		is_chase_music_playing = false
	elif not music_player.playing:
		print("[GameManager] 🎵 Starting normal music")
		music_player.stream = normal_bgm
		music_player.volume_db = normal_music_volume
		music_player.play()

func play_chase_music():
	"""Switch to chase/hostile music."""
	if not chase_bgm:
		print("[GameManager] ⚠️ Chase music not configured")
		return
	
	if not is_chase_music_playing:
		print("[GameManager] 🎵 Switching to CHASE music")
		_crossfade_to_track(chase_bgm, chase_music_volume)
		is_chase_music_playing = true

func _crossfade_to_track(new_track: AudioStream, target_volume: float = 0.0):
	"""Smoothly crossfade to a new music track."""
	if not new_track:
		push_warning("[GameManager] Invalid music track")
		return
	
	# Fade out current music
	if music_player.playing:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80, music_crossfade_time)
		await tween.finished
	
	# Switch track
	music_player.stream = new_track
	music_player.volume_db = -80
	music_player.play()
	
	# Fade in new music
	var fade_in_tween = create_tween()
	fade_in_tween.tween_property(music_player, "volume_db", target_volume, music_crossfade_time)

func stop_music():
	"""Stop all background music."""
	if music_player:
		music_player.stop()
		is_chase_music_playing = false

func is_game_over() -> bool:
	return current_state == GameState.GAME_OVER or current_state == GameState.WON
