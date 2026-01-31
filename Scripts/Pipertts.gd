extends Node
class_name PiperTTS

## Piper TTS - Local text-to-speech using Piper executable
## Uses process piping that works reliably on Windows

signal synthesis_started()
signal synthesis_completed(audio_stream: AudioStreamWAV)
signal synthesis_failed(error: String)

# Paths - selectable in Inspector!
@export_global_file("*.exe") var piper_executable: String = ""
@export_global_file("*.onnx") var voice_model_path: String = ""

# State
var is_synthesizing: bool = false
var _thread: Thread = null
var _pending_audio: AudioStreamWAV = null
var _pending_error: String = ""

func _ready():
	print("PiperTTS ready")
	if is_available():
		print("  Piper: ", piper_executable)
		print("  Voice: ", voice_model_path)
	else:
		print("  Status: ", get_status())


func is_available() -> bool:
	"""Check if Piper is properly set up."""
	if piper_executable.is_empty() or voice_model_path.is_empty():
		return false
	return FileAccess.file_exists(piper_executable) and FileAccess.file_exists(voice_model_path)


func get_status() -> String:
	"""Get human-readable status."""
	if piper_executable.is_empty():
		return "Piper executable not set"
	if voice_model_path.is_empty():
		return "Voice model not set"
	if not FileAccess.file_exists(piper_executable):
		return "Piper not found: " + piper_executable
	if not FileAccess.file_exists(voice_model_path):
		return "Voice not found: " + voice_model_path
	if is_synthesizing:
		return "Synthesizing..."
	return "Ready"


## Synthesize text to speech (async)
func synthesize(text: String):
	if is_synthesizing:
		synthesis_failed.emit("Already synthesizing")
		return
	
	if text.strip_edges().is_empty():
		synthesis_failed.emit("No text provided")
		return
	
	if not is_available():
		synthesis_failed.emit(get_status())
		return
	
	is_synthesizing = true
	synthesis_started.emit()
	
	# Run synthesis in thread to avoid blocking game
	_thread = Thread.new()
	_thread.start(_synthesize_threaded.bind(text))


func _synthesize_threaded(text: String):
	"""Run Piper using cmd /c echo piping (works reliably on Windows)."""
	var piper_path = piper_executable
	var model_path = voice_model_path
	
	# Use user data dir for temp files
	var temp_dir = OS.get_user_data_dir()
	var timestamp = Time.get_ticks_msec()
	var output_path = temp_dir.path_join("piper_%d.wav" % timestamp)
	
	# Escape text for shell (replace quotes, etc)
	var safe_text = text.replace('"', "'").replace("\n", " ").replace("\r", "")
	
	print("PiperTTS: Synthesizing '", safe_text.substr(0, 30), "...'")
	var start_time = Time.get_ticks_msec()
	
	var output: Array = []
	var exit_code: int = -1
	
	if OS.get_name() == "Windows":
		# Windows: use cmd /c with echo piping
		var cmd = 'echo %s | "%s" --model "%s" --output_file "%s"' % [
			safe_text, piper_path, model_path, output_path
		]
		exit_code = OS.execute("cmd.exe", ["/c", cmd], output, true, false)
	else:
		# Linux/Mac: use sh -c with echo piping
		var cmd = "echo '%s' | '%s' --model '%s' --output_file '%s'" % [
			safe_text, piper_path, model_path, output_path
		]
		exit_code = OS.execute("/bin/sh", ["-c", cmd], output, true, false)
	
	var elapsed = Time.get_ticks_msec() - start_time
	print("PiperTTS: Process finished in ", elapsed, "ms (exit code: ", exit_code, ")")
	
	if exit_code != 0:
		_pending_error = "Piper failed (code %d)" % exit_code
		if output.size() > 0 and str(output[0]).length() > 0:
			_pending_error += ": " + str(output[0]).substr(0, 200)
		call_deferred("_on_synthesis_done")
		return
	
	# Check output file exists
	if not FileAccess.file_exists(output_path):
		_pending_error = "Piper did not create output file. Check that .onnx.json config exists next to the .onnx file."
		call_deferred("_on_synthesis_done")
		return
	
	# Load the WAV file
	var audio = _load_wav_file(output_path)
	
	# Clean up output file
	DirAccess.remove_absolute(output_path)
	
	if audio:
		_pending_audio = audio
		_pending_error = ""
		print("PiperTTS: Audio ready (", snapped(audio.get_length(), 0.01), "s)")
	else:
		_pending_error = "Failed to parse generated audio"
	
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
		print("PiperTTS: Error - ", _pending_error)
		synthesis_failed.emit(_pending_error)


func _load_wav_file(path: String) -> AudioStreamWAV:
	"""Load a WAV file from disk."""
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
	
	# Verify RIFF header
	if wav_bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	if wav_bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return null
	
	# Parse chunks
	var pos = 12
	var channels = 1
	var sample_rate = 22050
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
	
	# Create AudioStreamWAV
	var stream = AudioStreamWAV.new()
	stream.data = wav_bytes.slice(data_start, data_start + data_size)
	stream.mix_rate = sample_rate
	stream.stereo = (channels == 2)
	stream.format = AudioStreamWAV.FORMAT_16_BITS if bits_per_sample == 16 else AudioStreamWAV.FORMAT_8_BITS
	
	return stream


func is_busy() -> bool:
	return is_synthesizing


## Cancel current synthesis (if possible)
func cancel():
	# Can't really cancel OS.execute, but we can ignore the result
	_pending_audio = null
	_pending_error = "Cancelled"
