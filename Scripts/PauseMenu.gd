extends CanvasLayer

## Unified Pause/Settings Menu - Opens with Tab key
## Contains tabs for: Game Controls, AI Settings, and UI Settings

signal pause_state_changed(is_paused: bool)

# UI References
@onready var panel = $PanelContainer
@onready var tab_container = $PanelContainer/MarginContainer/VBoxContainer/TabContainer

# Game tab buttons
@onready var resume_button = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Game/ButtonContainer/ResumeButton
@onready var restart_button = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Game/ButtonContainer/RestartButton
@onready var quit_button = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Game/ButtonContainer/QuitButton

# Tab content containers
@onready var ai_settings_tab = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/AISettings
@onready var ui_settings_tab = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/UISettings

var is_paused: bool = false
var ai_settings_content: Control = null
var ui_settings_content: Control = null

func _ready():
	hide()
	
	# Connect game tab buttons
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	
	# Setup settings tabs with actual content
	call_deferred("_setup_settings_tabs")

func _setup_settings_tabs():
	"""Reparent the settings menu content into the tabs."""
	var ai_settings = get_node_or_null("/root/AISettingsMenu")
	var ui_settings = get_node_or_null("/root/UISettingsMenu")
	
	if ai_settings and ai_settings_tab:
		# Get the main panel from AISettingsMenu
		ai_settings_content = ai_settings.get_node_or_null("PanelContainer")
		if ai_settings_content:
			# Remove from original parent and add to tab
			ai_settings_content.get_parent().remove_child(ai_settings_content)
			ai_settings_tab.add_child(ai_settings_content)
			# Make it fill the tab
			ai_settings_content.anchors_preset = Control.PRESET_FULL_RECT
			ai_settings_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	if ui_settings and ui_settings_tab:
		# Get the main panel from UISettingsMenu
		ui_settings_content = ui_settings.get_node_or_null("PanelContainer")
		if ui_settings_content:
			# Remove from original parent and add to tab
			ui_settings_content.get_parent().remove_child(ui_settings_content)
			ui_settings_tab.add_child(ui_settings_content)
			# Make it fill the tab
			ui_settings_content.anchors_preset = Control.PRESET_FULL_RECT
			ui_settings_content.set_anchors_preset(Control.PRESET_FULL_RECT)

func _input(event):
	# Toggle pause menu with Tab
	if event.is_action_pressed("OpenMenu"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	# Close with ESC while paused
	elif visible and event.is_action_pressed("ui_cancel"):
		_on_resume_pressed()
		get_viewport().set_input_as_handled()

func toggle_pause():
	"""Toggle pause menu visibility."""
	if visible:
		close_menu()
	else:
		open_menu()

func open_menu():
	"""Open the pause menu."""
	is_paused = true
	show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	pause_state_changed.emit(true)
	
	# Set to Game tab by default
	if tab_container:
		tab_container.current_tab = 0

func close_menu():
	"""Close the pause menu and resume game."""
	is_paused = false
	hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().paused = false
	pause_state_changed.emit(false)

func _on_resume_pressed():
	"""Resume button - close menu and continue game."""
	close_menu()

func _on_restart_pressed():
	"""Restart button - reload current scene."""
	# Unpause before reloading
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_pressed():
	"""Quit button - exit to desktop."""
	get_tree().quit()
