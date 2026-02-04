# RVC Voice Cloning - Speed Optimization Guide

## Overview
RVC post-processing typically adds 0.1-3 seconds latency depending on configuration. Here's how to make it faster.

## Speed Settings (Fastest to Slowest)

### 1. **F0 Method** (Pitch Detection Algorithm)
**Location**: NPCBase → RVC Voice Cloning → RVC Quality

- **crepe-tiny** ⚡ ~0.1-0.3s (FASTEST - use this for real-time)
- **crepe** 🐢 ~0.5-1.0s (balanced quality/speed)
- **rmvpe** 🐌 ~1.5-3.0s (best quality but slowest)

**Recommendation**: Stick with `crepe-tiny` for games. Quality difference is minimal for short voice clips.

---

### 2. **Hop Length** (Pitch Tracking Precision)
**Location**: NPCBase → RVC Voice Cloning → RVC Hop Length

- **512** ⚡ Fastest (~30% faster than 256)
- **256** 🔄 Balanced (default)
- **128** 🐢 Precise but slower
- **64** 🐌 Very slow, rarely needed

**Recommendation**: Use 256 or 512. Going below 256 doesn't improve quality noticeably for dialogue.

---

### 3. **GPU Acceleration**
**Location**: NPCBase → RVC Voice Cloning → RVC Use GPU

- **Enabled** ⚡ 2-5x faster on NVIDIA GPUs with CUDA
- **Disabled** 🐢 CPU-only (slower)

**Requirements**: 
- NVIDIA GPU (GTX 1060 or newer recommended)
- CUDA-enabled PyTorch installed in Python environment
- Check `rvc/SETUP.md` for GPU installation

**Recommendation**: Always enable if you have compatible GPU. Massive speedup.

---

### 4. **Index Rate** (Feature Retrieval Strength)
**Location**: NPCBase → RVC Voice Cloning → RVC Index Rate (NEW!)

- **0.5-0.6** ⚡ Faster feature lookups, more natural blend
- **0.75** 🔄 Balanced (default)
- **0.9-1.0** 🐢 Slower, stronger voice match

**What it does**: Controls how much the RVC model relies on index features vs raw conversion.
- Lower = Faster processing, less "forced" sounding
- Higher = Slower, more like training voice

**Recommendation**: Try 0.6-0.7 for speed. If voice sounds too different, increase to 0.8.

---

### 5. **Server Mode** (Automatic)
**Status**: Enabled by default

The RVC server keeps models loaded in memory:
- **First conversion**: ~2-6 seconds (model loading)
- **Subsequent**: ~0.1-0.3 seconds (server warm)

Server auto-starts when game launches. Check `rvc/logs/server.log` if issues.

---

## Recommended Configurations

### ⚡ **Maximum Speed** (Real-time feel)
```
rvc_quality: "crepe-tiny"
rvc_hop_length: 512
rvc_index_rate: 0.6
rvc_use_gpu: true (if available)
```
**Result**: ~0.1-0.2s latency with GPU, ~0.3-0.5s on CPU

---

### 🔄 **Balanced** (Good quality, decent speed)
```
rvc_quality: "crepe-tiny"
rvc_hop_length: 256
rvc_index_rate: 0.75
rvc_use_gpu: true
```
**Result**: ~0.2-0.4s latency with GPU, ~0.5-1.0s on CPU

---

### 🎯 **Quality First** (Use if speed doesn't matter)
```
rvc_quality: "rmvpe"
rvc_hop_length: 128
rvc_index_rate: 0.9
rvc_use_gpu: true
```
**Result**: ~1.0-2.0s latency with GPU, ~3-6s on CPU

---

## Additional Tips

### **Reduce TTS Length**
Shorter text = faster RVC processing. Consider:
- Breaking long responses into chunks
- Using shorter NPC personalities
- Adjusting `max_response_length` in NPCBase

### **Pre-process Common Phrases**
For frequently used lines (greetings, farewells), convert them offline and cache as AudioStreamWAV files.

### **Multi-threaded Processing**
RVC already runs in a separate thread. Don't worry about blocking main game thread.

### **Monitor Performance**
Check `rvc/logs/server.log` for timing info:
```
[INFO] Conversion completed in 0.15s
```

---

## Troubleshooting Slow Performance

### "RVC takes 5+ seconds every time"
- Server didn't start properly. Check `rvc/logs/server.log`
- Restart game to relaunch server
- Verify Python dependencies: `cd rvc && pip install -r requirements.txt`

### "GPU not being used"
- Check CUDA is installed: `nvidia-smi` in terminal
- Verify PyTorch has CUDA: Run in `rvc/`:
  ```python
  python -c "import torch; print(torch.cuda.is_available())"
  ```
- If False, reinstall PyTorch with CUDA from pytorch.org

### "Still too slow even on GPU"
- Use `crepe-tiny` + hop_length 512
- Lower index_rate to 0.5
- Consider disabling RVC for some NPCs (set `enable_rvc = false`)

---

## Index Rate Visual Guide

```
index_rate = 0.0  → Pure RVC conversion (no index features)
                    ⬇️ Natural but may drift from target voice

index_rate = 0.5  → Light index influence
                    ⬇️ Fast, natural, close to target

index_rate = 0.75 → Moderate index (DEFAULT)
                    ⬇️ Balanced accuracy/naturalness

index_rate = 1.0  → Full index features
                    ⬇️ Most accurate to target, may sound forced
```

Start at 0.75, adjust down for speed or up for accuracy.

---

## Summary

**For best real-time performance in games:**
1. ✅ Use `crepe-tiny` f0 method
2. ✅ Set hop_length to 256 or 512
3. ✅ Enable GPU if available
4. ✅ Set index_rate to 0.6-0.7
5. ✅ Keep server mode enabled (automatic)

**Result**: Sub-0.5 second RVC processing on most systems!
