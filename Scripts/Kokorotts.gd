extends Node
class_name KokoroTTS

## Kokoro TTS - High-quality local text-to-speech using sherpa-onnx
## Auto-detects bundled TTS files relative to game executable

signal synthesis_started()
signal synthesis_completed(audio_stream: AudioStreamWAV)
signal synthesis_failed(error: String)

# Auto-detected paths
var sherpa_executable: String = ""
var model_directory: String = ""

# Voice settings
var voice_id: int = 0
var speed: float = 1.0
var num_threads: int = 2

# State
var is_synthesizing: bool = false
var _thread: Thread = null
var _pending_audio: AudioStreamWAV = null
var _pending_error: String = ""
var _is_multilang: bool = false
var _initialized: bool = false

# English voices (kokoro-en-v0_19)
const ENGLISH_VOICES: Dictionary = {
	0: {"name": "af_bella", "desc": "American Female - Bella"},
	1: {"name": "af_nicole", "desc": "American Female - Nicole"},
	2: {"name": "af_sarah", "desc": "American Female - Sarah"},
	3: {"name": "af_sky", "desc": "American Female - Sky"},
	4: {"name": "am_adam", "desc": "American Male - Adam"},
	5: {"name": "am_michael", "desc": "American Male - Michael"},
	6: {"name": "bf_emma", "desc": "British Female - Emma"},
	7: {"name": "bf_isabella", "desc": "British Female - Isabella"},
	8: {"name": "bm_george", "desc": "British Male - George"},
	9: {"name": "bm_lewis", "desc": "British Male - Lewis"},
	10: {"name": "ef_dora", "desc": "European Female - Dora"},
}

# Multi-language voices (kokoro-multi-lang)
const MULTILANG_VOICES: Dictionary = {
	0: {"name": "af_alloy", "desc": "American Female - Alloy"},
	1: {"name": "af_aoede", "desc": "American Female - Aoede"},
	2: {"name": "af_bella", "desc": "American Female - Bella"},
	3: {"name": "af_heart", "desc": "American Female - Heart"},
	4: {"name": "af_jessica", "desc": "American Female - Jessica"},
	5: {"name": "af_kore", "desc": "American Female - Kore"},
	6: {"name": "af_nicole", "desc": "American Female - Nicole"},
	7: {"name": "af_nova", "desc": "American Female - Nova"},
	8: {"name": "af_river", "desc": "American Female - River"},
	9: {"name": "af_sarah", "desc": "American Female - Sarah"},
	10: {"name": "af_sky", "desc": "American Female - Sky"},
	11: {"name": "am_adam", "desc": "American Male - Adam"},
	12: {"name": "am_echo", "desc": "American Male - Echo"},
	13: {"name": "am_eric", "desc": "American Male - Eric"},
	14: {"name": "am_fenrir", "desc": "American Male - Fenrir"},
	15: {"name": "am_liam", "desc": "American Male - Liam"},
	16: {"name": "am_michael", "desc": "American Male - Michael"},
	17: {"name": "am_onyx", "desc": "American Male - Onyx"},
	18: {"name": "am_puck", "desc": "American Male - Puck"},
	19: {"name": "am_santa", "desc": "American Male - Santa"},
	20: {"name": "bf_alice", "desc": "British Female - Alice"},
	21: {"name": "bf_emma", "desc": "British Female - Emma"},
	22: {"name": "bf_isabella", "desc": "British Female - Isabella"},
	23: {"name": "bf_lily", "desc": "British Female - Lily"},
	24: {"name": "bm_daniel", "desc": "British Male - Daniel"},
	25: {"name": "bm_fable", "desc": "British Male - Fable"},
	26: {"name": "bm_george", "desc": "British Male - George"},
	27: {"name": "bm_lewis", "desc": "British Male - Lewis"},
	28: {"name": "ef_dora", "desc": "European Female - Dora"},
	29: {"name": "em_alex", "desc": "European Male - Alex"},
	30: {"name": "ff_siwis", "desc": "French Female - Siwis"},
	31: {"name": "hf_alpha", "desc": "Hindi Female - Alpha"},
	32: {"name": "hf_beta", "desc": "Hindi Female - Beta"},
	33: {"name": "hm_omega", "desc": "Hindi Male - Omega"},
	34: {"name": "hm_psi", "desc": "Hindi Male - Psi"},
	35: {"name": "if_sara", "desc": "Italian Female - Sara"},
	36: {"name": "im_nicola", "desc": "Italian Male - Nicola"},
	37: {"name": "jf_alpha", "desc": "Japanese Female - Alpha"},
	38: {"name": "jf_gongitsune", "desc": "Japanese Female - Gongitsune"},
	39: {"name": "jf_nezumi", "desc": "Japanese Female - Nezumi"},
	40: {"name": "jf_tebukuro", "desc": "Japanese Female - Tebukuro"},
	41: {"name": "jm_kumo", "desc": "Japanese Male - Kumo"},
	42: {"name": "pf_dora", "desc": "Portuguese Female - Dora"},
	43: {"name": "pm_alex", "desc": "Portuguese Male - Alex"},
	44: {"name": "pm_santa", "desc": "Portuguese Male - Santa"},
	45: {"name": "zf_xiaobei", "desc": "Chinese Female - Xiaobei"},
	46: {"name": "zf_xiaoni", "desc": "Chinese Female - Xiaoni"},
	47: {"name": "zf_xiaoxiao", "desc": "Chinese Female - Xiaoxiao"},
	48: {"name": "zf_xiaoyi", "desc": "Chinese Female - Xiaoyi"},
	49: {"name": "zm_yunjian", "desc": "Chinese Male - Yunjian"},
	50: {"name": "zm_yunxi", "desc": "Chinese Male - Yunxi"},
	51: {"name": "zm_yunxia", "desc": "Chinese Male - Yunxia"},
	52: {"name": "zm_yunyang", "desc": "Chinese Male - Yunyang"},
}


func _ready():
	_auto_detect_paths()


func _auto_detect_paths():
	"""Auto-detect sherpa-onnx and model paths."""
	
	# Get game directory
	var game_dir: String
	if OS.has_feature("editor"):
		game_dir = ProjectSettings.globalize_path("res://")
	else:
		game_dir = OS.get_executable_path().get_base_dir()
	
	# Find executable
	sherpa_executable = _find_executable(game_dir)
	if sherpa_executable.is_empty():
		return
	
	# Find model
	var tts_dir = sherpa_executable.get_base_dir()
	model_directory = _find_model(tts_dir)
	if model_directory.is_empty():
		return
	
	# Check model type
	_is_multilang = FileAccess.file_exists(model_directory.path_join("lexicon-us-en.txt"))
	
	_initialized = true
	print("[KokoroTTS] Ready: ", model_directory.get_file(), " (", "multi-lang" if _is_multilang else "English", ")")


func _find_executable(game_dir: String) -> String:
	"""Find sherpa-onnx executable."""
	var exe_names = ["sherpa-onnx-offline-tts.exe", "sherpa-onnx-offline.exe"] if OS.get_name() == "Windows" else ["sherpa-onnx-offline-tts", "sherpa-onnx-offline"]
	
	var search_paths = [
		game_dir.path_join("tts"),
		game_dir.path_join("addons/sherpa-onnx"),
		game_dir,
	]
	
	for search_path in search_paths:
		for exe_name in exe_names:
			var full_path = search_path.path_join(exe_name)
			if FileAccess.file_exists(full_path):
				return full_path
	
	return ""


func _find_model(tts_dir: String) -> String:
	"""Find Kokoro model directory."""
	var model_names = ["kokoro-en-v0_19", "kokoro-multi-lang-v1_0", "kokoro-multi-lang-v1_1", "kokoro"]
	
	for model_name in model_names:
		var model_path = tts_dir.path_join(model_name)
		if _is_valid_model_dir(model_path):
			return model_path
	
	return ""


func _is_valid_model_dir(path: String) -> bool:
	"""Check if directory contains required model files."""
	if not DirAccess.dir_exists_absolute(path):
		return false
	return (FileAccess.file_exists(path.path_join("model.onnx")) and
			FileAccess.file_exists(path.path_join("voices.bin")) and
			FileAccess.file_exists(path.path_join("tokens.txt")) and
			DirAccess.dir_exists_absolute(path.path_join("espeak-ng-data")))


func is_available() -> bool:
	"""Check if TTS is ready to use."""
	return _initialized


func get_status() -> String:
	"""Get human-readable status."""
	if not _initialized:
		return "TTS not available - files not bundled"
	if is_synthesizing:
		return "Synthesizing..."
	return "Ready"


func get_voice_name(id: int) -> String:
	"""Get internal voice name for ID."""
	var voices = MULTILANG_VOICES if _is_multilang else ENGLISH_VOICES
	if id in voices:
		return voices[id].name
	return "voice_" + str(id)


func get_voice_description(id: int) -> String:
	"""Get human-readable voice description."""
	var voices = MULTILANG_VOICES if _is_multilang else ENGLISH_VOICES
	if id in voices:
		return voices[id].desc
	return "Voice " + str(id)


func get_available_voices() -> Dictionary:
	"""Get all available voices for current model."""
	return MULTILANG_VOICES if _is_multilang else ENGLISH_VOICES


func get_max_voice_id() -> int:
	"""Get maximum valid voice ID."""
	return 52 if _is_multilang else 10


func set_voice(id: int):
	"""Set voice by ID (clamped to valid range)."""
	voice_id = clampi(id, 0, get_max_voice_id())


func set_speed(new_speed: float):
	"""Set speech speed (0.5-2.0, lower = faster)."""
	speed = clampf(new_speed, 0.5, 2.0)


func synthesize(text: String):
	"""Synthesize text to speech (async)."""
	if is_synthesizing:
		synthesis_failed.emit("Already synthesizing")
		return
	
	if text.strip_edges().is_empty():
		synthesis_failed.emit("No text")
		return
	
	if not is_available():
		synthesis_failed.emit(get_status())
		return
	
	is_synthesizing = true
	synthesis_started.emit()
	
	_thread = Thread.new()
	_thread.start(_synthesize_threaded.bind(text))


func _synthesize_threaded(text: String):
	"""Run synthesis in background thread."""
	var temp_dir = OS.get_user_data_dir()
	var output_path = temp_dir.path_join("kokoro_%d.wav" % Time.get_ticks_msec())
	
	# Sanitize text for command line
	var safe_text = text
	safe_text = safe_text.replace('"', "")
	safe_text = safe_text.replace("'", "")
	safe_text = safe_text.replace("\n", " ")
	safe_text = safe_text.replace("\r", "")
	safe_text = safe_text.replace("\\", "")
	safe_text = safe_text.replace("`", "")
	safe_text = safe_text.replace("%", "")
	safe_text = safe_text.replace("^", "")
	safe_text = safe_text.replace("&", "and")
	safe_text = safe_text.replace("|", "")
	safe_text = safe_text.replace("<", "")
	safe_text = safe_text.replace(">", "")
	safe_text = safe_text.strip_edges()
	
	var output: Array = []
	var exit_code: int = -1
	
	if OS.get_name() == "Windows":
		# Windows: Use batch file for reliable argument handling
		var batch_path = temp_dir.path_join("kokoro_synth.bat")
		var model_folder = model_directory.get_file()
		
		var batch_content = '@echo off\n'
		batch_content += 'cd /d "%s"\n' % sherpa_executable.get_base_dir()
		batch_content += 'sherpa-onnx-offline-tts.exe '
		batch_content += '--kokoro-model="%s/model.onnx" ' % model_folder
		batch_content += '--kokoro-voices="%s/voices.bin" ' % model_folder
		batch_content += '--kokoro-tokens="%s/tokens.txt" ' % model_folder
		batch_content += '--kokoro-data-dir="%s/espeak-ng-data" ' % model_folder
		batch_content += '--sid=%d ' % voice_id
		batch_content += '--kokoro-length-scale=%s ' % str(speed)
		batch_content += '--num-threads=%d ' % num_threads
		batch_content += '--output-filename="%s" ' % output_path
		batch_content += '"%s"\n' % safe_text
		
		var batch_file = FileAccess.open(batch_path, FileAccess.WRITE)
		if batch_file:
			batch_file.store_string(batch_content)
			batch_file.close()
			exit_code = OS.execute("cmd.exe", ["/c", batch_path], output, true, false)
			DirAccess.remove_absolute(batch_path)
		else:
			_pending_error = "Could not create batch file"
			call_deferred("_on_synthesis_done")
			return
	else:
		# Linux/Mac: Direct execution
		var args: PackedStringArray = []
		args.append("--kokoro-model=" + model_directory.path_join("model.onnx"))
		args.append("--kokoro-voices=" + model_directory.path_join("voices.bin"))
		args.append("--kokoro-tokens=" + model_directory.path_join("tokens.txt"))
		args.append("--kokoro-data-dir=" + model_directory.path_join("espeak-ng-data"))
		args.append("--sid=" + str(voice_id))
		args.append("--kokoro-length-scale=" + str(speed))
		args.append("--num-threads=" + str(num_threads))
		args.append("--output-filename=" + output_path)
		args.append(safe_text)
		exit_code = OS.execute(sherpa_executable, args, output, true, false)
	
	if exit_code != 0:
		_pending_error = "Synthesis failed (code %d)" % exit_code
		call_deferred("_on_synthesis_done")
		return
	
	if not FileAccess.file_exists(output_path):
		_pending_error = "No audio file generated"
		call_deferred("_on_synthesis_done")
		return
	
	# Load WAV
	var audio = _load_wav_file(output_path)
	DirAccess.remove_absolute(output_path)
	
	if audio:
		_pending_audio = audio
		_pending_error = ""
	else:
		_pending_error = "Failed to parse audio"
	
	call_deferred("_on_synthesis_done")


func _on_synthesis_done():
	"""Called on main thread when synthesis completes."""
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	_thread = null
	is_synthesizing = false
	
	if _pending_audio:
		var audio = _pending_audio
		_pending_audio = null
		synthesis_completed.emit(audio)
	else:
		synthesis_failed.emit(_pending_error)


func _load_wav_file(path: String) -> AudioStreamWAV:
	"""Load WAV file from disk."""
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	
	var wav_bytes = file.get_buffer(file.get_length())
	file.close()
	
	return _parse_wav(wav_bytes)


func _parse_wav(wav_bytes: PackedByteArray) -> AudioStreamWAV:
	"""Parse WAV bytes into AudioStreamWAV."""
	if wav_bytes.size() < 44:
		return null
	
	# Verify header
	if wav_bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	if wav_bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return null
	
	# Parse chunks
	var pos = 12
	var channels = 1
	var sample_rate = 24000
	var bits_per_sample = 16
	var data_start = 0
	var data_size = 0
	
	while pos < wav_bytes.size() - 8:
		var chunk_id = wav_bytes.slice(pos, pos + 4).get_string_from_ascii()
		var chunk_size = wav_bytes.decode_u32(pos + 4)
		
		if chunk_id == "fmt ":
			channels = wav_bytes.decode_u16(pos + 10)
			sample_rate = wav_bytes.decode_u32(pos + 12)
			bits_per_sample = wav_bytes.decode_u16(pos + 22)
		elif chunk_id == "data":
			data_start = pos + 8
			data_size = chunk_size
			break
		
		pos += 8 + chunk_size
		if chunk_size % 2 == 1:
			pos += 1
	
	if data_start == 0:
		return null
	
	var stream = AudioStreamWAV.new()
	stream.data = wav_bytes.slice(data_start, data_start + data_size)
	stream.mix_rate = sample_rate
	stream.stereo = (channels == 2)
	stream.format = AudioStreamWAV.FORMAT_16_BITS if bits_per_sample == 16 else AudioStreamWAV.FORMAT_8_BITS
	
	return stream


func is_busy() -> bool:
	"""Check if currently synthesizing."""
	return is_synthesizing


func cancel():
	"""Cancel current synthesis (result will be ignored)."""
	_pending_audio = null
	_pending_error = "Cancelled"
