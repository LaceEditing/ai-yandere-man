extends CanvasLayer
class_name HealthBar

## Simple health bar UI for player

var health_bar: ProgressBar
var health_label: Label
var player_health: PlayerHealth

func _ready():
	# Find player health
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player_health = player.get_node_or_null("PlayerHealth")
		if player_health:
			player_health.health_changed.connect(_on_health_changed)
			player_health.damage_taken.connect(_on_damage_taken)
			_setup_ui()
			_update_health(player_health.current_health, player_health.max_health)
		else:
			push_warning("[HealthBar] PlayerHealth not found on player!")
	else:
		push_warning("[HealthBar] Player not found in 'player' group!")

func _setup_ui():
	"""Create health bar UI elements"""
	# Container for positioning
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	# Health label
	health_label = Label.new()
	health_label.text = "HP: 100/100"
	health_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(health_label)
	
	# Progress bar
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(300, 30)
	health_bar.show_percentage = false
	health_bar.max_value = 100
	health_bar.value = 100
	vbox.add_child(health_bar)
	
	# Style the health bar
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.8, 0.2)  # Green
	style_box.set_corner_radius_all(5)
	health_bar.add_theme_stylebox_override("fill", style_box)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Dark background
	bg_style.set_corner_radius_all(5)
	health_bar.add_theme_stylebox_override("background", bg_style)

func _on_health_changed(current: int, maximum: int):
	_update_health(current, maximum)

func _on_damage_taken(amount: int):
	# Could add additional feedback here (shake, color change, etc.)
	pass

func _update_health(current: int, maximum: int):
	if not health_bar or not health_label:
		return
	
	health_label.text = "HP: %d/%d" % [current, maximum]
	health_bar.max_value = maximum
	health_bar.value = current
	
	# Change color based on health percentage
	var percentage = float(current) / float(maximum)
	var style_box = StyleBoxFlat.new()
	style_box.set_corner_radius_all(5)
	
	if percentage > 0.6:
		style_box.bg_color = Color(0.2, 0.8, 0.2)  # Green
	elif percentage > 0.3:
		style_box.bg_color = Color(0.9, 0.7, 0.1)  # Yellow
	else:
		style_box.bg_color = Color(0.9, 0.2, 0.2)  # Red
	
	health_bar.add_theme_stylebox_override("fill", style_box)
