#!/usr/bin/env python3
"""
RVC Server - Keeps models loaded in memory for fast inference.
Communicates via simple file-based protocol (no network/sockets).

Protocol:
1. Godot writes request to rvc_request.json
2. Server detects file, processes, writes rvc_response.json
3. Server deletes request file when done
4. Godot reads response and deletes response file
"""

import os
import sys
import json
import time
import signal
import traceback

# Add rvc directory to path
script_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, script_dir)
os.chdir(script_dir)

# Suppress progress bars
os.environ["TQDM_DISABLE"] = "1"

# Communication files (in user's temp directory)
COMM_DIR = os.environ.get("RVC_COMM_DIR", os.path.join(script_dir, "comm"))
REQUEST_FILE = os.path.join(COMM_DIR, "rvc_request.json")
RESPONSE_FILE = os.path.join(COMM_DIR, "rvc_response.json")
HEARTBEAT_FILE = os.path.join(COMM_DIR, "rvc_heartbeat.txt")
SHUTDOWN_FILE = os.path.join(COMM_DIR, "rvc_shutdown.txt")

# Ensure comm directory exists
os.makedirs(COMM_DIR, exist_ok=True)

# Global state
voice_converter = None
running = True


def log(msg):
    """Print with timestamp."""
    timestamp = time.strftime("%H:%M:%S")
    print(f"[RVC Server {timestamp}] {msg}", flush=True)


def load_voice_converter():
    """Load the voice converter (slow, done once at startup)."""
    global voice_converter
    log("Loading voice converter...")
    t0 = time.time()
    
    from rvc.infer.infer import VoiceConverter
    voice_converter = VoiceConverter()
    
    log(f"Voice converter ready in {time.time()-t0:.2f}s")
    return voice_converter


def process_request(request):
    """Process an inference request."""
    global voice_converter
    
    if voice_converter is None:
        return {"error": "Voice converter not loaded"}
    
    try:
        input_path = request.get("input_path")
        output_path = request.get("output_path")
        pth_path = request.get("pth_path")
        index_path = request.get("index_path", "")
        
        if not all([input_path, output_path, pth_path]):
            return {"error": "Missing required parameters: input_path, output_path, pth_path"}
        
        if not os.path.exists(input_path):
            return {"error": f"Input file not found: {input_path}"}
        
        if not os.path.exists(pth_path):
            return {"error": f"Model file not found: {pth_path}"}
        
        # Get optional parameters with defaults
        pitch = request.get("pitch", 0)
        index_rate = request.get("index_rate", 0.75)
        volume_envelope = request.get("volume_envelope", 0.25)
        protect = request.get("protect", 0.33)
        hop_length = request.get("hop_length", 256)
        f0_method = request.get("f0_method", "crepe-tiny")
        export_format = request.get("export_format", "WAV")
        
        t0 = time.time()
        
        # Run inference
        voice_converter.convert_audio(
            audio_input_path=input_path,
            audio_output_path=output_path,
            model_path=pth_path,
            index_path=index_path if index_path and os.path.exists(index_path) else "",
            pitch=pitch,
            index_rate=index_rate if index_path and os.path.exists(index_path) else 0.0,
            volume_envelope=volume_envelope,
            protect=protect,
            hop_length=hop_length,
            f0_method=f0_method,
            pth_path=pth_path,
            split_audio=False,
            f0_autotune=False,
            f0_autotune_strength=0.0,
            clean_audio=False,
            clean_strength=0.7,
            export_format=export_format,
            f0_file="",
            embedder_model="contentvec",
            embedder_model_custom=None,
            post_process=False,
            formant_shifting=False,
            formant_qfrency=1.0,
            formant_timbre=1.0,
            sid=0,
        )
        
        elapsed = time.time() - t0
        log(f"Converted in {elapsed:.2f}s: {os.path.basename(input_path)}")
        
        return {
            "success": True,
            "output_path": output_path,
            "elapsed": elapsed
        }
        
    except Exception as e:
        traceback.print_exc()
        return {"error": str(e)}


def write_heartbeat():
    """Write heartbeat file so Godot knows server is alive."""
    try:
        with open(HEARTBEAT_FILE, "w") as f:
            f.write(str(time.time()))
    except:
        pass


def check_shutdown():
    """Check if shutdown was requested."""
    if os.path.exists(SHUTDOWN_FILE):
        try:
            os.remove(SHUTDOWN_FILE)
        except:
            pass
        return True
    return False


def cleanup():
    """Clean up communication files."""
    for f in [REQUEST_FILE, RESPONSE_FILE, HEARTBEAT_FILE]:
        try:
            if os.path.exists(f):
                os.remove(f)
        except:
            pass


def signal_handler(signum, frame):
    """Handle shutdown signals."""
    global running
    log("Shutdown signal received")
    running = False


def main():
    global running
    
    # Set up signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    log(f"Starting... (comm dir: {COMM_DIR})")
    
    # Clean up any stale files
    cleanup()
    
    # Load models (the slow part - done once)
    try:
        load_voice_converter()
    except Exception as e:
        log(f"Failed to load voice converter: {e}")
        traceback.print_exc()
        return 1
    
    log("Server ready - waiting for requests...")
    write_heartbeat()
    
    last_heartbeat = time.time()
    
    while running:
        try:
            # Check for shutdown request
            if check_shutdown():
                log("Shutdown requested")
                break
            
            # Write heartbeat every 5 seconds
            if time.time() - last_heartbeat > 5:
                write_heartbeat()
                last_heartbeat = time.time()
            
            # Check for request file
            if os.path.exists(REQUEST_FILE):
                try:
                    # Read request
                    with open(REQUEST_FILE, "r") as f:
                        request = json.load(f)
                    
                    # Remove request file immediately
                    os.remove(REQUEST_FILE)
                    
                    # Process request
                    response = process_request(request)
                    
                    # Write response
                    with open(RESPONSE_FILE, "w") as f:
                        json.dump(response, f)
                    
                except json.JSONDecodeError as e:
                    log(f"Invalid request JSON: {e}")
                    try:
                        os.remove(REQUEST_FILE)
                    except:
                        pass
                except Exception as e:
                    log(f"Error processing request: {e}")
                    traceback.print_exc()
                    try:
                        with open(RESPONSE_FILE, "w") as f:
                            json.dump({"error": str(e)}, f)
                    except:
                        pass
            
            # Small sleep to avoid busy-waiting
            time.sleep(0.05)
            
        except KeyboardInterrupt:
            break
        except Exception as e:
            log(f"Error in main loop: {e}")
            time.sleep(1)
    
    log("Shutting down...")
    cleanup()
    return 0


if __name__ == "__main__":
    sys.exit(main())
