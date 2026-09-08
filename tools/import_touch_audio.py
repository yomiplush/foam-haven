"""Prepare CC0 recordings; provenance is in assets/TOUCH_AUDIO_LICENSES.md."""
from pathlib import Path
import subprocess, wave
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
RATE = 32000

def bake(source, output, start):
    raw = subprocess.run(['ffmpeg','-v','error','-ss',str(start),'-i',str(ROOT/'.build-tools/sound-src'/source),'-t','12','-af','highpass=f=85,lowpass=f=2800,acompressor=threshold=0.12:ratio=3:attack=20:release=180','-ac','1','-ar',str(RATE),'-f','f32le','-'],capture_output=True,check=True).stdout
    x=np.frombuffer(raw,dtype=np.float32).copy()
    assert len(x)>RATE*10
    f=RATE
    w=np.linspace(0,1,f,endpoint=False)
    # Tail-to-head overlap: start at head[f], finish with tail blended into head.
    y=np.concatenate([x[f:-f], x[-f:]*(1-w)+x[:f]*w])
    y = np.tanh(y / (4 * np.sqrt(np.mean(y*y)) + 1e-9))
    y*=min(0.13/(np.sqrt(np.mean(y*y))+1e-9),0.65/(np.max(np.abs(y))+1e-9))
    # Exact endpoint continuity for a click-free PCM loop.
    n=320; y[-n:]=y[-n:]*(1-np.linspace(0,1,n))+y[0]*np.linspace(0,1,n)
    assert np.isfinite(y).all() and np.max(np.abs(y))<=0.701
    with wave.open(str(ROOT/'assets'/output),'wb') as out:
        out.setnchannels(1);out.setsampwidth(2);out.setframerate(RATE);out.writeframes((y*32767).astype('<i2').tobytes())
    print(output, 'seconds',len(y)/RATE,'rms',float(np.sqrt(np.mean(y*y))),'peak',float(np.max(np.abs(y))))

bake('balloon_huminaatio.mp3','balloon_recorded.wav',18)
bake('slime_rubberduck.mp3','slime_recorded.wav',24)
