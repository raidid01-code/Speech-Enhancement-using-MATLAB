# Speech Enhancement — Spectral Subtraction & Wiener Filtering

Built a two-stage noise suppression pipeline in MATLAB that cleans speech corrupted by background noise, using classical frequency-domain techniques implemented from scratch.

---

## What it does

Takes a noisy speech signal and recovers intelligible speech by:

1. **Spectral Subtraction** — estimates and removes the noise floor in the frequency domain
2. **Wiener Filtering** — refines the result, smoothing out artifacts left by the first stage

The two methods complement each other: subtraction handles the bulk of the noise, Wiener filtering cleans up what's left.

---

## Why it's non-trivial

- Noise is estimated blindly from the first 0.25s of silence — no clean reference signal is available
- At 0 dB input SNR, noise energy equals speech energy, making separation genuinely difficult
- Spectral subtraction alone introduces *musical noise* (random tonal artifacts) — the hybrid pipeline addresses this
- Full STFT pipeline built manually with overlap-add reconstruction as a fallback when MATLAB built-ins aren't available

---

## Stack & Concepts

`MATLAB` · `STFT / ISTFT` · `Spectral Subtraction` · `Wiener Filtering` · `Signal-to-Noise Ratio` · `Hamming Windowing` · `Overlap-Add`

---

## Results

Tested on a 12s speech sample with white Gaussian noise at 0 dB SNR — one of the hardest conditions for classical methods.

| | SNR |
|---|---|
| Noisy input | 2.48 dB |
| After enhancement | 2.93 dB |

Spectrogram comparison shows clear reduction in wideband noise energy and partial recovery of low-frequency speech formants.

> Add your spectrogram comparison image here — it makes the result immediately obvious to anyone reading

---

## Possible extensions

- Adaptive noise tracking for non-stationary noise (traffic, crowd)
- Voice Activity Detection for smarter silence identification
- Deep learning post-filter (LSTM/transformer) for harder environments
