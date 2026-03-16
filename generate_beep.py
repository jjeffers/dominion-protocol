import math
import struct
import wave

sample_rate = 44100
duration_ms = 150
freq = 300.0
volume = 0.5

file_path = "src/assets/audio/short-low-beep.wav"
with wave.open(file_path, "w") as wav_file:
    wav_file.setnchannels(1)
    wav_file.setsampwidth(2)
    wav_file.setframerate(sample_rate)
    
    num_samples = int(sample_rate * (duration_ms / 1000.0))
    for i in range(num_samples):
        t = i / float(sample_rate)
        value = int(volume * math.sin(2 * math.pi * freq * t) * 32767)
        data = struct.pack("<h", value)
        wav_file.writeframesraw(data)
print(f"Created {file_path}")
