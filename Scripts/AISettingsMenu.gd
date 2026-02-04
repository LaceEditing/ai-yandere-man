extends CanvasLayer

## AI Settings Menu - Configure provider, API keys, and voice input/output

# UI References
@onready var panel = $PanelContainer
@onready var provider_option = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/ProviderSection/ProviderOption
@onready var status_label = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/StatusLabel

# Local section
@onready var local_section = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/LocalSection
@onready var local_model_label = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/LocalSection/ModelPathLabel

# Groq section
@onready var groq_section = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/GroqSection
@onready var api_key_input = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/GroqSection/APIKeyInput
@onready var groq_model_option = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/GroqSection/GroqModelOption
@onready var show_key_button = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/GroqSection/ShowKeyButton
@onready var model_info_label = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/GroqSection/ModelInfoLabel

# Azure TTS section
@onready var azure_tts_section = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/AzureTTSSection
@onready var azure_api_key_input = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/AzureTTSSection/AzureAPIKeyInput
@onready var azure_region_input = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/AzureTTSSection/AzureRegionInput
@onready var show_azure_key_button = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/AzureTTSSection/ShowAzureKeyButton
@onready var azure_status_label = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/AzureTTSSection/AzureStatusLabel

# Voice input section
@onready var voice_section = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/VoiceSection
@onready var voice_status_label = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/VoiceSection/VoiceStatusLabel

# Buttons
@onready var apply_button = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/ButtonContainer/ApplyButton
@onready var close_button = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer/ButtonContainer/CloseButton

var is_key_visible: bool = false
var is_azure_key_visible: bool = false

# Store model IDs in order
var model_ids: Array = []

func _ready():
	hide()  # Hide by default - can be shown standalone or in PauseMenu
	
	# Setup provider options
	provider_option.clear()
	provider_option.add_item("Local (NobodyWho)", AIManager.Provider.LOCAL)
	provider_option.add_item("Groq API (Cloud)", AIManager.Provider.GROQ)
	
	# Setup Groq model options
	setup_groq_models()
	
	# Connect signals
	provider_option.item_selected.connect(_on_provider_selected)
	show_key_button.toggled.connect(_on_show_key_toggled)
	show_azure_key_button.toggled.connect(_on_show_azure_key_toggled)
	groq_model_option.item_selected.connect(_on_model_selected)
	apply_button.pressed.connect(_on_apply_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	# Wait for AIManager to load settings
	if AIManager.is_node_ready():
		_load_current_settings()
	else:
		AIManager.settings_loaded.connect(_load_current_settings, CONNECT_ONE_SHOT)

func setup_groq_models():
	groq_model_option.clear()
	model_ids.clear()
	
	# Add Production Models first (stable, recommended)
	_add_model_category("── PRODUCTION (Stable) ──")
	var production = GroqProvider.get_production_models()
	for model_id in production:
		_add_model(model_id, production[model_id])
	
	# Add Preview Models (experimental)
	_add_model_category("── PREVIEW (Experimental) ──")
	var preview = GroqProvider.get_preview_models()
	for model_id in preview:
		_add_model(model_id, preview[model_id])

func _add_model_category(label: String):
	groq_model_option.add_separator(label)
	model_ids.append("")  # Placeholder for separator

func _add_model(model_id: String, info: Dictionary):
	var display_text: String = info.name + " (" + info.speed + ")"
	groq_model_option.add_item(display_text)
	var idx: int = groq_model_option.item_count - 1
	groq_model_option.set_item_metadata(idx, model_id)
	model_ids.append(model_id)

func _load_current_settings():
	# Set current provider
	var current_provider = AIManager.get_provider()
	provider_option.select(current_provider)
	_update_sections_visibility(current_provider)
	
	# Set local model path
	local_model_label.text = "Model: " + AIManager.get_local_model_path().get_file()
	
	# Set Groq settings
	api_key_input.text = AIManager.get_groq_api_key()
	_select_groq_model(AIManager.get_groq_model())
	
	# Load Azure TTS settings
	_load_azure_settings()
	
	# Update status
	_update_status()


func _load_azure_settings():
	"""Load Azure TTS settings from config file."""
	var config = ConfigFile.new()
	var err = config.load("user://ai_settings.cfg")
	if err == OK:
		azure_api_key_input.text = config.get_value("tts", "azure_api_key", "")
		azure_region_input.text = config.get_value("tts", "azure_region", "eastus")
	_update_azure_status()


func _save_azure_settings():
	"""Save Azure TTS settings to config file."""
	var config = ConfigFile.new()
	config.load("user://ai_settings.cfg")  # Load existing settings
	config.set_value("tts", "azure_api_key", azure_api_key_input.text.strip_edges())
	config.set_value("tts", "azure_region", azure_region_input.text.strip_edges())
	config.save("user://ai_settings.cfg")


func _update_azure_status():
	"""Update Azure TTS status label."""
	var api_key = azure_api_key_input.text.strip_edges()
	var region = azure_region_input.text.strip_edges()
	
	if api_key.is_empty():
		azure_status_label.text = "Status: Not configured (no API key)"
		azure_status_label.add_theme_color_override("font_color", Color.YELLOW)
	elif region.is_empty():
		azure_status_label.text = "Status: Not configured (no region)"
		azure_status_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		azure_status_label.text = "Status: Ready (region: " + region + ")"
		azure_status_label.add_theme_color_override("font_color", Color.GREEN)

func _select_groq_model(model_id: String):
	for i in range(groq_model_option.item_count):
		var metadata = groq_model_option.get_item_metadata(i)
		if metadata == model_id:
			groq_model_option.select(i)
			_update_model_info(model_id)
			return
	# Default to first actual model if not found
	for i in range(groq_model_option.item_count):
		var metadata = groq_model_option.get_item_metadata(i)
		if metadata != null and metadata != "":
			groq_model_option.select(i)
			_update_model_info(metadata)
			return

func _get_selected_groq_model() -> String:
	var idx: int = groq_model_option.selected
	if idx >= 0:
		var metadata = groq_model_option.get_item_metadata(idx)
		if metadata != null and metadata != "":
			return metadata
	return "llama-3.1-8b-instant"

func _update_model_info(model_id: String):
	if model_info_label == null:
		return
	
	var all_models = GroqProvider.get_all_models()
	if model_id in all_models:
		var info: Dictionary = all_models[model_id]
		model_info_label.text = info.description
	else:
		model_info_label.text = ""

func _on_model_selected(idx: int):
	var model_id = groq_model_option.get_item_metadata(idx)
	if model_id != null and model_id != "":
		_update_model_info(model_id)

func _update_sections_visibility(provider: int):
	local_section.visible = (provider == AIManager.Provider.LOCAL)
	groq_section.visible = (provider == AIManager.Provider.GROQ)

func _update_voice_status():
	voice_status_label.text = "Voice Input: " + AIManager.get_voice_input_status()
	
	if "Ready" in voice_status_label.text:
		voice_status_label.add_theme_color_override("font_color", Color.GREEN)
	elif "required" in voice_status_label.text:
		voice_status_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		voice_status_label.add_theme_color_override("font_color", Color.WHITE)

func _update_status():
	status_label.text = "Status: " + AIManager.get_provider_status()
	
	# Color code the status
	if "Ready" in status_label.text:
		status_label.add_theme_color_override("font_color", Color.GREEN)
	elif "Error" in status_label.text:
		status_label.add_theme_color_override("font_color", Color.RED)
	else:
		status_label.add_theme_color_override("font_color", Color.YELLOW)
	
	_update_voice_status()

func _on_provider_selected(index: int):
	var provider = provider_option.get_item_id(index)
	_update_sections_visibility(provider)

func _on_show_key_toggled(toggled: bool):
	is_key_visible = toggled
	api_key_input.secret = not toggled
	show_key_button.text = "Hide" if toggled else "Show"


func _on_show_azure_key_toggled(toggled: bool):
	is_azure_key_visible = toggled
	azure_api_key_input.secret = not toggled
	show_azure_key_button.text = "Hide" if toggled else "Show"

func _on_apply_pressed():
	# Get selected provider
	var provider = provider_option.get_item_id(provider_option.selected)
	
	# Apply settings
	AIManager.set_provider(provider)
	
	# Apply Groq settings if Groq is selected
	if provider == AIManager.Provider.GROQ:
		AIManager.set_groq_api_key(api_key_input.text.strip_edges())
		AIManager.set_groq_model(_get_selected_groq_model())
	
	# Always save Azure TTS settings (independent of AI provider)
	_save_azure_settings()
	_update_azure_status()
	
	# Update status display
	_update_status()
	
	print("AI settings applied!")

func _on_close_pressed():
	# If we're in standalone mode, hide ourselves
	# If we're embedded in pause menu, close the pause menu
	var pause_menu = get_node_or_null("/root/PauseMenu")
	if pause_menu and pause_menu.visible and pause_menu.is_paused:
		# Embedded in pause menu - close it
		pause_menu.close_menu()
	else:
		# Standalone mode
		hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func show_menu():
	_load_current_settings()
	show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
