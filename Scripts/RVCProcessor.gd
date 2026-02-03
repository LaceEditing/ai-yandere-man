extends Node
class_name RVCProcessor

## RVC Voice Conversion - Post-process TTS audio through voice cloning
## Uses a background server to keep models warm for fast inference (~0.1s vs ~6s cold).
## Server starts automatically on game launch - completely invisible to player.

signal conversion_started()
signal conversion_completed(audio_stream: AudioStreamWAV)
signal conversion_failed(error: String)

# Auto-detected paths
var rvc_dir: String = ""
var models_directory: String = ""

# Voice model settings
var model_file: String = ""
var index_file: String = ""
var pitch_shift: int = 0
var index_rate: float = 0.75
var rms_mix_rate: float = 0.25
var protect_rate: float = 0.33

# Processing settings
var f0_method: String = "crepe-tiny"
var hop_length: int = 256

# GPU settings
var use_gpu: bool = true
var cuda_device: int = -1

# Debug mode - set true to see detailed logs
var debug_mode: bool = false

# State
var is_converting: bool = false
var _thread: Thread = null
var _pending_audio: AudioStreamWAV = null
var _pending_error: String = ""
var _initialized: bool = false
var _available_models: Dictionary = {}

# Server state
var _server_pid: int = -1
var _server_ready: bool = false
var _comm_dir: String = ""
var _use_server_mode: bool = true


func _ready():
	_auto_detect_paths()
	if _initialized:
		_scan_models()
		_setup_comm_dir()
		if _use_server_mode:
			_start_server()


func _exit_tree():
	_stop_server()


func _auto_detect_paths():
	var game_dir: String
	if OS.has_feature("editor"):
		game_dir = ProjectSettings.globalize_path("res://")
	else:
		game_dir = OS.get_executable_path().get_base_dir()
	
	var search_paths = [game_dir.path_join("rvc"), game_dir.path_join("addons/rvc")]
	
	for search_path in search_paths:
		var server_script = search_path.path_join("rvc_server.py")
		if FileAccess.file_exists(server_script):
			rvc_dir = search_path
			break
	
	if rvc_dir.is_empty():
		return
	
	models_directory = rvc_dir.path_join("models")
	if not DirAccess.dir_exists_absolute(models_directory):
		DirAccess.make_dir_recursive_absolute(models_directory)
	
	_initialized = true
	_log("Ready")


func _setup_comm_dir():
	_comm_dir = OS.get_user_data_dir().path_join("rvc_comm")
	DirAccess.make_dir_recursive_absolute(_comm_dir)


func _start_server():
	if _server_pid > 0:
		return
	
	var python_cmd = _find_python()
	if python_cmd.is_empty():
		_log("Python not found - using direct mode")
		_use_server_mode = false
		return
	
	var server_script = rvc_dir.path_join("rvc_server.py")
	if not FileAccess.file_exists(server_script):
		_use_server_mode = false
		return
	
	_log("Starting voice engine...")
	
	# Start server as hidden background process
	if OS.get_name() == "Windows":
		var batch = 'cd /d "' + rvc_dir + '" && set RVC_COMM_DIR=' + _comm_dir + ' && set TQDM_DISABLE=1 && '
		if python_cmd.begins_with("py -"):
			var ver = python_cmd.split(" ")[1]
			batch += "py " + ver + " rvc_server.py"
		else:
			batch += python_cmd + " rvc_server.py"
		var ps_cmd = 'Start-Process -WindowStyle Hidden -FilePath cmd -ArgumentList "/c ' + batch.replace('"', '`"') + '"'
		_server_pid = OS.create_process("powershell", ["-Command", ps_cmd])
	else:
		var cmd = 'cd "' + rvc_dir + '" && RVC_COMM_DIR="' + _comm_dir + '" TQDM_DISABLE=1 ' + python_cmd + ' rvc_server.py &'
		_server_pid = OS.create_process("bash", ["-c", cmd])
	
	# Wait for server to be ready
	var heartbeat_file = _comm_dir.path_join("rvc_heartbeat.txt")
	var wait_start = Time.get_ticks_msec()
	
	while Time.get_ticks_msec() - wait_start < 15000:
		if FileAccess.file_exists(heartbeat_file):
			_server_ready = true
			_log("Voice engine ready!")
			return
		OS.delay_msec(100)
	
	_log("Voice engine timeout - using direct mode")
	_use_server_mode = false


func _stop_server():
	if not _server_ready:
		return
	var shutdown_file = _comm_dir.path_join("rvc_shutdown.txt")
	var f = FileAccess.open(shutdown_file, FileAccess.WRITE)
	if f:
		f.store_string("shutdown")
		f.close()
	_server_ready = false
	_server_pid = -1


func _scan_models():
	_available_models.clear()
	if models_directory.is_empty():
		return
	
	var dir = DirAccess.open(models_directory)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".pth"):
			var model_name = file_name.get_basename()
			var pth_path = models_directory.path_join(file_name)
			var index_path = _find_index_for_model(model_name)
			_available_models[model_name] = {"pth": pth_path, "index": index_path}
			_log("Found model: " + model_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _find_index_for_model(model_name: String) -> String:
	if models_directory.is_empty():
		return ""
	var dir = DirAccess.open(models_directory)
	if not dir:
		return ""
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".index") and model_name.to_lower() in file_name.to_lower():
			dir.list_dir_end()
			return models_directory.path_join(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return ""


func _find_python() -> String:
	if OS.get_name() == "Windows":
		for ver in ["3.11", "3.10"]:
			var output = []
			if OS.execute("py", ["-" + ver, "--version"], output, true) == 0:
				return "py -" + ver
	for cmd in ["python3.11", "python3.10", "python3", "python"]:
		var output = []
		if OS.execute(cmd, ["--version"], output, true) == 0:
			var v = "".join(output)
			if "3.10" in v or "3.11" in v:
				return cmd
	return ""


func _log(msg: String):
	if debug_mode or "Ready" in msg or "Warning" in msg or "Error" in msg or "engine" in msg:
		print("[RVC] " + msg)


# ============ PUBLIC API ============

func is_available() -> bool:
	return _initialized and not model_file.is_empty()


func is_busy() -> bool:
	return is_converting


func get_status() -> String:
	if not _initialized:
		return "RVC not available"
	if model_file.is_empty():
		return "No voice model"
	if is_converting:
		return "Converting..."
	return "Ready"


func get_available_models() -> Array:
	return _available_models.keys()


func set_model(model_name: String) -> bool:
	if model_name in _available_models:
		model_file = _available_models[model_name].pth
		index_file = _available_models[model_name].index
		return true
	return false


func set_model_paths(pth_path: String, idx_path: String = ""):
	model_file = pth_path
	index_file = idx_path


func convert(input_audio: AudioStreamWAV) -> void:
	if is_converting:
		conversion_failed.emit("Already converting")
		return
	if not is_available():
		conversion_failed.emit(get_status())
		return
	is_converting = true
	conversion_started.emit()
	_thread = Thread.new()
	_thread.start(_convert_threaded.bind(input_audio))


func convert_file(input_path: String) -> void:
	if is_converting:
		conversion_failed.emit("Already converting")
		return
	if not is_available():
		conversion_failed.emit(get_status())
		return
	if not FileAccess.file_exists(input_path):
		conversion_failed.emit("Input file not found")
		return
	is_converting = true
	conversion_started.emit()
	_thread = Thread.new()
	_thread.start(_convert_file_threaded.bind(input_path))


func _convert_threaded(audio: AudioStreamWAV):
	var temp_dir = OS.get_user_data_dir()
	var input_path = temp_dir.path_join("rvc_input_%d.wav" % Time.get_ticks_msec())
	if not _save_wav(audio, input_path):
		_pending_error = "Failed to save input"
		call_deferred("_on_thread_done")
		return
	_run_conversion(input_path)


func _convert_file_threaded(input_path: String):
	_run_conversion(input_path)


func _run_conversion(input_path: String):
	var temp_dir = OS.get_user_data_dir()
	var output_path = temp_dir.path_join("rvc_output_%d.wav" % Time.get_ticks_msec())
	
	var success: bool
	if _use_server_mode and _server_ready:
		success = _run_via_server(input_path, output_path)
	else:
		success = _run_via_cli(input_path, output_path)
	
	if not success:
		call_deferred("_on_thread_done")
		return
	
	if not FileAccess.file_exists(output_path):
		_pending_error = "Output not created"
		call_deferred("_on_thread_done")
		return
	
	_pending_audio = _load_wav(output_path)
	if not _pending_audio:
		_pending_error = "Failed to load output"
	
	_cleanup_file(input_path)
	_cleanup_file(output_path)
	call_deferred("_on_thread_done")


func _run_via_server(input_path: String, output_path: String) -> bool:
	var request_file = _comm_dir.path_join("rvc_request.json")
	var response_file = _comm_dir.path_join("rvc_response.json")
	_cleanup_file(response_file)
	
	var request = {
		"input_path": input_path,
		"output_path": output_path,
		"pth_path": model_file,
		"index_path": index_file,
		"pitch": pitch_shift,
		"index_rate": index_rate,
		"volume_envelope": rms_mix_rate,
		"protect": protect_rate,
		"hop_length": hop_length,
		"f0_method": f0_method,
		"export_format": "WAV"
	}
	
	var f = FileAccess.open(request_file, FileAccess.WRITE)
	if not f:
		_pending_error = "Failed to write request"
		return false
	f.store_string(JSON.stringify(request))
	f.close()
	
	var wait_start = Time.get_ticks_msec()
	while Time.get_ticks_msec() - wait_start < 30000:
		if FileAccess.file_exists(response_file):
			var rf = FileAccess.open(response_file, FileAccess.READ)
			if rf:
				var text = rf.get_as_text()
				rf.close()
				_cleanup_file(response_file)
				var response = JSON.parse_string(text)
				if response == null:
					_pending_error = "Invalid response"
					return false
				if response.has("error"):
					_pending_error = str(response.error)
					return false
				if debug_mode and response.has("elapsed"):
					_log("Converted in " + str(response.elapsed) + "s")
				return true
		OS.delay_msec(50)
	
	_pending_error = "Server timeout"
	return false


func _run_via_cli(input_path: String, output_path: String) -> bool:
	var python_cmd = _find_python()
	if python_cmd.is_empty():
		_pending_error = "Python not found"
		return false
	
	var args = PackedStringArray([
		"infer",
		"--input_path", input_path,
		"--output_path", output_path,
		"--pth_path", model_file,
		"--f0_method", f0_method,
		"--pitch", str(pitch_shift),
		"--volume_envelope", str(rms_mix_rate),
		"--protect", str(protect_rate),
		"--export_format", "WAV",
		"--hop_length", str(hop_length),
		"--index_path", index_file if not index_file.is_empty() else "",
		"--index_rate", str(index_rate) if not index_file.is_empty() else "0.0",
	])
	
	var executable: String
	var final_args: PackedStringArray
	if python_cmd.begins_with("py -"):
		executable = "py"
		var ver = python_cmd.split(" ")[1]
		final_args = PackedStringArray([ver, "rvc_cli.py"])
	else:
		executable = python_cmd
		final_args = PackedStringArray(["rvc_cli.py"])
	final_args.append_array(args)
	
	var output = []
	var env_prefix = "set TQDM_DISABLE=1 && " if OS.get_name() == "Windows" else "TQDM_DISABLE=1 "
	var exit_code: int
	
	if OS.get_name() == "Windows":
		var cmd = 'cd /d "' + rvc_dir + '" && ' + env_prefix + executable + " " + " ".join(final_args)
		exit_code = OS.execute("cmd", ["/c", cmd], output, true)
	else:
		var cmd = 'cd "' + rvc_dir + '" && ' + env_prefix + executable + " " + " ".join(final_args)
		exit_code = OS.execute("bash", ["-c", cmd], output, true)
	
	if exit_code != 0:
		_pending_error = "RVC failed"
		return false
	return true


func _cleanup_file(path: String):
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _on_thread_done():
	if _thread:
		_thread.wait_to_finish()
		_thread = null
	is_converting = false
	if not _pending_error.is_empty():
		conversion_failed.emit(_pending_error)
		_pending_error = ""
	elif _pending_audio:
		conversion_completed.emit(_pending_audio)
		_pending_audio = null
	else:
		conversion_failed.emit("Unknown error")


func _process(_delta):
	pass


# ============ WAV UTILITIES ============

func _save_wav(audio: AudioStreamWAV, path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	var data = audio.data
	var sr = audio.mix_rate
	var ch = 2 if audio.stereo else 1
	var bps = 16 if audio.format == AudioStreamWAV.FORMAT_16_BITS else 8
	file.store_buffer("RIFF".to_utf8_buffer())
	file.store_32(36 + data.size())
	file.store_buffer("WAVE".to_utf8_buffer())
	file.store_buffer("fmt ".to_utf8_buffer())
	file.store_32(16)
	file.store_16(1)
	file.store_16(ch)
	file.store_32(sr)
	file.store_32(sr * ch * (bps / 8))
	file.store_16(ch * (bps / 8))
	file.store_16(bps)
	file.store_buffer("data".to_utf8_buffer())
	file.store_32(data.size())
	file.store_buffer(data)
	file.close()
	return true


func _load_wav(path: String) -> AudioStreamWAV:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var data = file.get_buffer(file.get_length())
	file.close()
	if data.size() < 44:
		return null
	var ch = data[22] | (data[23] << 8)
	var sr = data[24] | (data[25] << 8) | (data[26] << 16) | (data[27] << 24)
	var bps = data[34] | (data[35] << 8)
	var ds = 12
	while ds < data.size() - 8:
		var id = data.slice(ds, ds + 4).get_string_from_ascii()
		var sz = data[ds + 4] | (data[ds + 5] << 8) | (data[ds + 6] << 16) | (data[ds + 7] << 24)
		if id == "data":
			ds += 8
			break
		ds += 8 + sz
	if ds >= data.size():
		return null
	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS if bps == 16 else AudioStreamWAV.FORMAT_8_BITS
	audio.mix_rate = sr
	audio.stereo = ch == 2
	audio.data = data.slice(ds)
	return audio
