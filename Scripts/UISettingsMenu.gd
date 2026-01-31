extends CanvasLayer

## UI Settings Menu - Adjust DialogueUI scaling with live preview
## Press Tab to open (or call show_menu() from anywhere)

# UI References
@onready var scale_label = $PanelContainer/MarginContainer/VBoxContainer/ScaleLabel
@onready var scale_slider = $PanelContainer/MarginContainer/VBoxContainer/ScaleSlider
@onready var preview_label = $PanelContainer/MarginContainer/VBoxContainer/PreviewLabel

@onready var auto_button = $PanelContainer/MarginContainer/VBoxContainer/ScalingModeButtons/AutoButton
@onready var manual_button = $PanelContainer/MarginContainer/VBoxContainer/ScalingModeButtons/ManualButton

@onready var small_button = $PanelContainer/MarginContainer/VBoxContainer/PresetButtons/SmallButton
@onready var medium_button = $PanelContainer/MarginContainer/VBoxContainer/PresetButtons/MediumButton
@onready var large_button = $PanelContainer/MarginContainer/VBoxContainer/PresetButtons/LargeButton

@onready var apply_button = $PanelContainer/MarginContainer/VBoxContainer/ButtonsContainer/ApplyButton
@onready var close_button = $PanelContainer/MarginContainer/VBoxContainer/ButtonsContainer/CloseButton

# Settings
const SETTINGS_PATH = "user://ui_settings.cfg"
var pending_scale: float = 1.5
var pending_auto: bool = true

func _ready():
	hide()
	
	# Connect signals
	scale_slider.value_changed.connect(_on_scale_changed)
	
	auto_button.toggled.connect(_on_auto_toggled)
	manual_button.toggled.connect(_on_manual_toggled)
	
	small_button.pressed.connect(_on_small_pressed)
	medium_button.pressed.connect(_on_medium_pressed)
	large_button.pressed.connect(_on_large_pressed)
	
	apply_button.pressed.connect(_on_apply_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	# Load current settings
	_load_current_settings()

func _input(event):
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func show_menu():
	"""Open the settings menu and load current values."""
	_load_current_settings()
	show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _load_current_settings():
	"""Load current DialogueUI settings into the menu."""
	# Get current scale from DialogueUI
	pending_scale = DialogueUI.get_current_scale()
	pending_auto = DialogueUI.enable_auto_scaling
	
	# Update UI
	scale_slider.value = pending_scale
	_update_scale_label(pending_scale)
	_update_preview(pending_scale)
	
	# Update mode buttons
	auto_button.button_pressed = pending_auto
	manual_button.button_pressed = not pending_auto
	
	# Enable/disable slider based on mode
	scale_slider.editable = not pending_auto

func _on_scale_changed(value: float):
	"""Called when slider moves."""
	pending_scale = value
	_update_scale_label(value)
	_update_preview(value)

func _update_scale_label(scale: float):
	"""Update the scale display label."""
	var font_size = int(18 * scale)
	scale_label.text = "UI Scale: %.1fx (%dpx)" % [scale, font_size]

func _update_preview(scale: float):
	"""Update the preview text size."""
	var preview_size = int(18 * scale)
	preview_label.add_theme_font_size_override("font_size", preview_size)

func _on_auto_toggled(toggled: bool):
	"""Auto mode selected."""
	if toggled:
		pending_auto = true
		scale_slider.editable = false
		
		# Calculate what auto would be
		var viewport_size = get_viewport().get_visible_rect().size
		var auto_scale = clamp(viewport_size.x / 1920.0, 1.0, 2.0)
		scale_slider.value = auto_scale
		_update_scale_label(auto_scale)
		_update_preview(auto_scale)

func _on_manual_toggled(toggled: bool):
	"""Manual mode selected."""
	if toggled:
		pending_auto = false
		scale_slider.editable = true

func _on_small_pressed():
	"""Small preset (1.0x)."""
	manual_button.button_pressed = true
	scale_slider.value = 1.0

func _on_medium_pressed():
	"""Medium preset (1.5x)."""
	manual_button.button_pressed = true
	scale_slider.value = 1.5

func _on_large_pressed():
	"""Large preset (2.0x)."""
	manual_button.button_pressed = true
	scale_slider.value = 2.0

func _on_apply_pressed():
	"""Apply the settings to DialogueUI."""
	if pending_auto:
		DialogueUI.reset_to_auto_scaling()
	else:
		DialogueUI.set_manual_scale(pending_scale)
	
	# Save to config file
	_save_settings()
	
	print("UI settings applied!")

func _on_close_pressed():
	"""Close the menu without applying (or after applying)."""
	hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _save_settings():
	"""Save settings to config file."""
	var config = ConfigFile.new()
	
	config.set_value("ui", "auto_scale", DialogueUI.enable_auto_scaling)
	config.set_value("ui", "manual_scale", DialogueUI.get_current_scale())
	
	var error = config.save(SETTINGS_PATH)
	if error == OK:
		print("UI settings saved")
	else:
		push_error("Failed to save UI settings: ", error)

func load_saved_settings():
	"""Load and apply saved settings from config file."""
	var config = ConfigFile.new()
	var error = config.load(SETTINGS_PATH)
	
	if error != OK:
		print("No saved UI settings, using defaults")
		return
	
	var auto_scale = config.get_value("ui", "auto_scale", true)
	var manual_scale = config.get_value("ui", "manual_scale", 1.5)
	
	if auto_scale:
		DialogueUI.reset_to_auto_scaling()
	else:
		DialogueUI.set_manual_scale(manual_scale)
	
	print("UI settings loaded")
