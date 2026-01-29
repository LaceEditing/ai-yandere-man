extends Node

# Reference to the model
@onready var llm_model = $LLMModel

# Path to your GGUF model file
@export_file("*.gguf") var model_path: String = "res://AIModels/qwen2.5-0.5b-instruct-q4_k_m.gguf"

func _ready():
	# Set the model path
	if llm_model and model_path:
		llm_model.model_path = model_path
		print("AI Manager initialized with model: ", model_path)
	else:
		push_error("No model path set!")
