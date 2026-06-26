# Speech Enhancement Using Spectral Subtraction and Wiener Filtering

A MATLAB implementation of classical frequency-domain speech enhancement techniques, combining **Spectral Subtraction** and **Wiener Filtering** in the STFT domain.

## Overview

Speech signals captured in real-world environments — classrooms, streets, vehicles — are often corrupted by background noise, degrading intelligibility and downstream system performance (ASR, VoIP, hearing aids).

This project addresses that problem using a **hybrid two-stage pipeline**:

1. **Spectral Subtraction** — aggressively removes dominant noise in the frequency domain
2. **Wiener Filtering** — refines the output by smoothing residual noise and reducing musical artifacts

Both methods operate in the **Short-Time Fourier Transform (STFT)** domain, making them computationally efficient and suitable for real-time use.

---

## How It Works

The enhancement pipeline follows these steps:

```
Noisy Speech
    │
    ▼
Frame Blocking & Hamming Windowing
    │
    ▼
FFT → Magnitude + Phase Separation
    │
    ▼
Noise Estimation (first 0.25s silence frames)
    │
    ▼
Spectral Subtraction (oversubtraction + spectral flooring)
    │
    ▼
Wiener Filter Gain Computation
    │
    ▼
IFFT + Overlap-Add Reconstruction
    │
    ▼
Enhanced Speech Output
```

**Spectral Subtraction** estimates the noise magnitude from initial silence frames and subtracts it from each frame's spectrum, with oversubtraction (`α = 1.2`) and a spectral floor (`β = 0.02`) to prevent negative magnitudes.

**Wiener Filtering** uses the spectral-subtracted output to estimate clean speech power, then computes a gain function:

```
H(k) = P_speech(k) / (P_speech(k) + P_noise(k))
```

This gain is applied to suppress residual noise more smoothly than subtraction alone.

---

## Setup & Usage

### Requirements

- MATLAB (R2019b or later recommended)
- Signal Processing Toolbox (for `stft`/`istft` built-ins; a manual fallback is included)

### Running the Code

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/speech-enhancement-dsp.git
   cd speech-enhancement-dsp
   ```

2. Open `speech_enhancement.m` in MATLAB.

3. Configure the top section of the script:
   ```matlab
   use_url        = true;          % true = load audio from URL, false = local file
   add_noise      = true;          % add artificial noise to clean speech
   use_white_noise = true;         % true = white Gaussian, false = external noise file
   target_snr_db  = 0;            % input SNR in dB (0 dB = highly noisy)
   ```

4. Run the script. It will:
   - Load and normalize the speech signal
   - Add noise at the target SNR
   - Apply spectral subtraction and Wiener filtering
   - Display waveform and spectrogram plots
   - Print SNR results to the console
   - Save three audio files: `noisy.wav`, `enhanced_ss.wav`, `enhanced_wiener.wav`

### Parameters

| Parameter | Value | Description |
|---|---|---|
| Frame length | 512 samples | STFT window size |
| Hop size | 256 samples | 50% overlap |
| Window | Hamming | Reduces spectral leakage |
| FFT size | 512 | Frequency resolution |
| Noise estimation | First 0.25s | Silence-frame average |
| Oversubtraction (α) | 1.2 | Controls noise aggressiveness |
| Spectral floor (β) | 0.02 | Prevents musical noise |

---

## Results

Tests were run on a ~12s speech sample with white Gaussian noise added at ~0 dB SNR.

| Signal | SNR (dB) |
|---|---|
| Noisy Input | 2.48 |
| Spectral Subtraction | — |
| Wiener Enhanced | **2.93** |

**SNR improvement: ~0.45 dB** under highly adverse conditions (0 dB target input SNR).

**Waveform analysis** showed that after enhancement, speech-silence boundaries became more distinguishable and the speech envelope was partially restored.

**Spectrogram analysis** confirmed reduced wideband noise energy and recovery of low-frequency formant structure, with some residual noise at higher frequencies — expected behavior at low input SNR.

---

## Limitations & Future Work

- SNR improvement is modest at very low input SNR (≤ 0 dB); performance improves significantly at higher SNR conditions
- Noise estimation assumes a stationary noise profile from initial silence frames
- Possible extensions:
  - Adaptive noise tracking for non-stationary environments
  - Voice Activity Detection (VAD) for improved silence identification
  - Deep learning post-filter for non-stationary noise (e.g., LSTM or transformer-based)
