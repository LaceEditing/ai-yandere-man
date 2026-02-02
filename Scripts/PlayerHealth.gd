extends Node
class_name PlayerHealth

## Player Health System - Handles damage, death, and game over

signal health_changed(current: int, max: int)
signal player_died()
signal damage_taken(amount: int)

@export var max_health: int = 75  ## 3 hits at 25 damage = death
@export var current_health: int = 75
@export var invincibility_time: float = 1.0  ## Time after taking damage before can be hurt again

var is_invincible: bool = false
var is_dead: bool = false
var invincibility_timer: Timer
var damage_overlay: ColorRect  ## Visual feedback for damage

func _ready():
	current_health = max_health
	
	# Setup invincibility timer
	invincibility_timer = Timer.new()
	invincibility_timer.one_shot = true
	invincibility_timer.timeout.connect(_on_invincibility_timeout)
	add_child(invincibility_timer)
	
	# Create damage overlay (deferred to avoid busy parent)
	call_deferred("_setup_damage_overlay")
	
	print("[PlayerHealth] Initialized - HP: ", current_health, "/", max_health, " (survives 3 hits @ 25 damage)")

func take_damage(amount: int, source = null) -> bool:
	"""Returns true if damage was applied"""
	if is_dead or is_invincible or amount <= 0:
		return false
	
	var source_name = source.get("npc_name") if source and "npc_name" in source else "Unknown"
	
	current_health = max(0, current_health - amount)
	print("[PlayerHealth] 💔 Took ", amount, " damage from ", source_name, " - HP: ", current_health, "/", max_health)
	
	damage_taken.emit(amount)
	health_changed.emit(current_health, max_health)
	
	# Visual feedback
	_flash_damage()
	
	# Start invincibility period
	is_invincible = true
	invincibility_timer.start(invincibility_time)
	
	# Check for death
	if current_health <= 0:
		_die()
	
	return true

func heal(amount: int):
	"""Heal the player"""
	if is_dead:
		return
	
	var old_health = current_health
	current_health = min(max_health, current_health + amount)
	
	if old_health != current_health:
		print("[PlayerHealth] 💚 Healed ", amount, " HP - HP: ", current_health, "/", max_health)
		health_changed.emit(current_health, max_health)

func _die():
	if is_dead:
		return
	
	is_dead = true
	print("[PlayerHealth] ☠️  Player died!")
	player_died.emit()

func _on_invincibility_timeout():
	is_invincible = false

func _setup_damage_overlay():
	"""Create red flash overlay for damage feedback"""
	# Find or create the overlay
	var canvas_layer = get_tree().get_first_node_in_group("ui_canvas")
	if not canvas_layer:
		# Create a canvas layer for UI
		canvas_layer = CanvasLayer.new()
		canvas_layer.name = "DamageOverlay"
		canvas_layer.layer = 100  # High layer to be on top
		get_tree().root.add_child(canvas_layer)
	
	damage_overlay = ColorRect.new()
	damage_overlay.name = "DamageFlash"
	damage_overlay.color = Color(1, 0, 0, 0)  # Start transparent red
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block clicks
	damage_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)  # Fill screen
	
	# Wait a frame before adding to ensure tree is ready
	await get_tree().process_frame
	canvas_layer.add_child(damage_overlay)

func _flash_damage():
	"""Fade in/out red overlay for damage feedback"""
	if not damage_overlay:
		return
	
	# Tween from transparent to semi-transparent red and back
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	
	# Flash in
	tween.tween_property(damage_overlay, "color", Color(1, 0, 0, 0.3), 0.1)
	# Fade out
	tween.tween_property(damage_overlay, "color", Color(1, 0, 0, 0), 0.4)

func get_health_percentage() -> float:
	return float(current_health) / float(max_health) if max_health > 0 else 0.0

func is_player_dead() -> bool:
	return is_dead
