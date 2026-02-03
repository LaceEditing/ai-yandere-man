# RVC Voice Cloning Setup for MaleYanderAI

This folder contains the [rvc-cli](https://github.com/blaisewf/rvc-cli) Python project for voice cloning.
RVC allows you to transform any TTS voice (Kokoro, Azure, etc.) to sound like a target voice.

## Requirements

- **Python 3.10 or 3.11** (NOT 3.12+) - RVC dependencies don't support newer Python versions
- **Windows**: Uses `py -3.11` launcher automatically
- **Optional**: NVIDIA GPU with CUDA for faster processing

## Quick Setup (One-Time)

### CPU-Only Installation (works on any system)
```powershell
# Install PyTorch (CPU version)
py -3.11 -m pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu

# Install other dependencies
py -3.11 -m pip install torchcrepe torchfcpe
py -3.11 -m pip install numpy scipy librosa soundfile faiss-cpu
py -3.11 -m pip install einops transformers pedalboard praat-parselmouth
py -3.11 -m pip install tensorboard onnxruntime onnx beautifulsoup4
py -3.11 -m pip install wget edge-tts pydub gradio noisereduce
```

### GPU-Accelerated Installation (NVIDIA CUDA)
For 5-8x faster processing on NVIDIA GPUs:

```powershell
# For RTX 30/40 series (stable release with CUDA 12.4)
py -3.11 -m pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu124

# For RTX 50 series / Blackwell (nightly with CUDA 12.8 - has sm_120 support)
py -3.11 -m pip install --pre torch torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128

# Install other dependencies (same as CPU)
py -3.11 -m pip install torchcrepe torchfcpe
py -3.11 -m pip install numpy scipy librosa soundfile faiss-cpu
py -3.11 -m pip install einops transformers pedalboard praat-parselmouth
py -3.11 -m pip install tensorboard onnxruntime onnx beautifulsoup4
py -3.11 -m pip install wget edge-tts pydub gradio noisereduce
```

### Download Pretrained Models
First-time setup requires downloading pretrained models (~1.4GB):
```powershell
cd rvc
py -3.11 rvc_cli.py prerequisites
```

## Adding Voice Models

1. Download RVC voice models from:
   - [voice.ai](https://voice.ai/)
   - [weights.gg](https://weights.gg/)
   - [Hugging Face](https://huggingface.co/models?search=rvc)

2. Each model needs 2 files:
   - `.pth` file - The voice model weights
   - `.index` file - Voice embedding index (optional but recommended)

3. Place files in `rvc/models/`:
   ```
   rvc/models/
   ├── YourVoice.pth
   └── YourVoice.index
   ```

4. Configure NPC in Godot Inspector:
   - `Enable RVC`: true
   - `RVC Model Name`: "YourVoice" (without .pth)
   - `RVC Pitch Shift`: 0 (adjust -12 to +12 if needed)

## Testing from Command Line

```powershell
cd rvc
py -3.11 rvc_cli.py infer --help
```

Basic inference test:
```powershell
py -3.11 rvc_cli.py infer `
    --input_path "path/to/input.wav" `
    --output_path "path/to/output.wav" `
    --pth_path "models/YourVoice.pth" `
    --index_path "models/YourVoice.index" `
    --f0_method rmvpe
```

## Troubleshooting

**"Python 3.10/3.11 not found"**: Install Python 3.11 from python.org

**"No module named X"**: Run `py -3.11 -m pip install X`

**Slow first inference**: First run downloads ~300MB of pretrained models

**Poor quality output**: Try different `f0_method` values: rmvpe, fcpe, crepe

**GPU not detected**: Make sure you installed the CUDA version of PyTorch (cu124, not cpu)

**"GPU with CUDA capability sm_XX is not compatible"**: Your GPU is too new for current PyTorch. Either:
- Wait for PyTorch to add support for your GPU
- Try nightly builds: `py -3.11 -m pip install --pre torch --index-url https://download.pytorch.org/whl/nightly/cu124`
- Fall back to CPU (disable GPU in Inspector)

## Performance Notes

| Setting | CPU Time | RTX 3060 | RTX 5070 | Notes |
|---------|----------|----------|----------|-------|
| crepe-tiny (hop 256) | ~2.2s | ~1.7s | ~1.5s | Fastest, good quality |
| crepe (hop 256) | ~6.7s | ~2.5s | ~2.0s | Balanced |
| rmvpe (hop 128) | ~12s | ~1.6s | ~1.5s | Best quality, benefits most from GPU |

- First inference takes extra time for model loading
- GPU acceleration auto-detects compatible NVIDIA GPUs
- Set `RVC CUDA Device` to -1 for auto-detection, or specific device index (0 = first GPU)
- Set `RVC Use GPU` to false to force CPU mode
- RTX 50-series requires PyTorch nightly with CUDA 12.8+
