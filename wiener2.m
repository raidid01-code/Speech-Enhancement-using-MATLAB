clear; close all; clc;

%% ---------------- User Choices ----------------
use_url = true;  
audio_url = 'https://samplelib.com/lib/preview/mp3/sample-12s.mp3'; % clean vocal
local_file = 'your_uploaded.wav'; % if you upload your own

add_noise = true;            % Add artificial noise
use_white_noise = true;      % true = white noise, false = external noise

target_snr_db = 0;           % noisy signal SNR (0 dB works well for demo)

% If you want external noise, set this:
external_noise_url = 'https://samplelib.com/lib/preview/mp3/sample-15s.mp3'; % car noise

%% ---------------- Load Clean Speech ----------------
try
    if use_url
        [clean, Fs] = audioread(audio_url);
    else
        [clean, Fs] = audioread(local_file);
    end
catch ME
    error("Failed to read audio. Check URL or file. MATLAB reported:\n%s", ME.message);
end

% Convert to mono if stereo
if size(clean,2) > 1
    clean = mean(clean,2);
end

% Normalize and length
clean = clean / max(abs(clean)+eps);
L = length(clean);

%% ---------------- Prepare Noise ----------------
if add_noise
    if use_white_noise
        % White Gaussian noise for controlled experiments
        sig_pow = mean(clean.^2);
        snr_lin = 10^(target_snr_db/10);
        noise_pow = sig_pow / max(snr_lin, eps);
        noise = sqrt(noise_pow) * randn(size(clean));
    else
        % External noise (car / street / babble)
        [noise, Fs_n] = audioread(external_noise_url);
        if size(noise,2) > 1, noise = mean(noise,2); end

        % Resample if needed
        if Fs_n ~= Fs
            noise = resample(noise, Fs, Fs_n);
        end

        % Make noise long enough
        if length(noise) < L
            noise = repmat(noise, ceil(L/length(noise)), 1);
        end
        noise = noise(1:L);

        % Adjust noise power to match desired SNR
        sig_pow = mean(clean.^2);
        noise = noise / sqrt(max(mean(noise.^2), eps));     % normalize noise → 1
        noise = noise * sqrt(sig_pow / max(10^(target_snr_db/10), eps));
    end

    noisy = clean + noise;
else
    noisy = clean + 0.02 * randn(size(clean));
end

noisy = noisy / max(abs(noisy)+eps); % normalize

%% ---------------- STFT Setup ----------------
win_len = 512;
hop = 256;
nfft = 512;
win = hamming(win_len, 'periodic');
overlap = win_len - hop;

% detect built-in stft/istft presence
use_builtin = exist('stft','file')==2 && exist('istft','file')==2;

%% ---------------- Compute STFT ----------------
if use_builtin
    % Use MATLAB built-in which handles framing cleanly
    [S, F, T] = stft(noisy, Fs, 'Window', win, 'OverlapLength', overlap, 'FFTLength', nfft);
else
    % Manual framing + FFT
    frames = buffer(noisy, win_len, overlap, 'nodelay');   % each column is a frame
    num_frames = size(frames,2);
    frames = frames .* repmat(win,1,num_frames);
    S = fft(frames, nfft, 1);   % fft along rows (each column is a frame)
end

Mag = abs(S);
Phase = angle(S);

%% ---------------- Noise Estimate ----------------
initial_noise_sec = 0.25;
% number of frames in that time window
num_init_frames = max(1, floor(initial_noise_sec * Fs / hop));
num_init_frames = min(num_init_frames, size(Mag,2));

noise_mag = mean(Mag(:,1:num_init_frames),2);
noise_pow = noise_mag.^2;

%% ---------------- Spectral Subtraction ----------------
alpha = 1.2;       % oversubtraction
beta_floor = 0.02;

Mag_ss = max(Mag - alpha * noise_mag, beta_floor * noise_mag);
S_ss = Mag_ss .* exp(1i * Phase);

%% ---------------- ISTFT (Spectral Subtraction output) ----------------
if use_builtin
    enhanced_ss = istft(S_ss, Fs, 'Window', win, 'OverlapLength', overlap, 'FFTLength', nfft);
else
    % inverse FFT to get time-domain frames (nfft x num_frames)
    ifft_frames = real(ifft(S_ss, nfft, 1));
    ifft_frames = ifft_frames(1:win_len, :);   % keep only first win_len samples of each frame

    num_ifft_frames = size(ifft_frames, 2);
    outLen = max(L, (num_ifft_frames-1)*hop + win_len);   % be safe; ensure large enough
    enhanced_ss = zeros(outLen,1);

    idx = 1;
    for k = 1:num_ifft_frames
        idx_end = idx + win_len - 1;
        % guard against exceeding bounds (shouldn't happen due to outLen calc, but safe)
        if idx_end > outLen
            % truncate the frame to fit remaining samples
            valid_len = max(outLen - idx + 1, 0);
            if valid_len > 0
                enhanced_ss(idx:outLen) = enhanced_ss(idx:outLen) + ifft_frames(1:valid_len,k).*win(1:valid_len);
            end
            break;
        else
            enhanced_ss(idx:idx_end) = enhanced_ss(idx:idx_end) + ifft_frames(:,k).*win;
        end
        idx = idx + hop;
    end
end

% Trim/pad to original length L
enhanced_ss = enhanced_ss(1:min(length(enhanced_ss), L));
if length(enhanced_ss) < L
    enhanced_ss = [enhanced_ss; zeros(L - length(enhanced_ss), 1)];
end
enhanced_ss = enhanced_ss / max(abs(enhanced_ss)+eps);

%% ---------------- Wiener Filtering ----------------
clean_pow_est = Mag_ss.^2;
H = clean_pow_est ./ (clean_pow_est + noise_pow + eps);

S_w = H .* S;

% ISTFT (Wiener output)
if use_builtin
    enhanced_w = istft(S_w, Fs, 'Window', win, 'OverlapLength', overlap, 'FFTLength', nfft);
else
    ifft_frames_w = real(ifft(S_w, nfft, 1));
    ifft_frames_w = ifft_frames_w(1:win_len, :);
    num_ifft_frames_w = size(ifft_frames_w,2);
    outLen_w = max(L, (num_ifft_frames_w-1)*hop + win_len);
    enhanced_w = zeros(outLen_w,1);

    idx = 1;
    for k = 1:num_ifft_frames_w
        idx_end = idx + win_len - 1;
        if idx_end > outLen_w
            valid_len = max(outLen_w - idx + 1, 0);
            if valid_len > 0
                enhanced_w(idx:outLen_w) = enhanced_w(idx:outLen_w) + ifft_frames_w(1:valid_len,k).*win(1:valid_len);
            end
            break;
        else
            enhanced_w(idx:idx_end) = enhanced_w(idx:idx_end) + ifft_frames_w(:,k).*win;
        end
        idx = idx + hop;
    end
end

enhanced_w = enhanced_w(1:min(length(enhanced_w), L));
if length(enhanced_w) < L
    enhanced_w = [enhanced_w; zeros(L - length(enhanced_w), 1)];
end
enhanced_w = enhanced_w / max(abs(enhanced_w)+eps);

%% ---------------- Compute SNR (robust) ----------------
% Avoid dividing by zero
eps_val = 1e-12;
snr_in = 10*log10( sum(clean.^2) / max(sum((noisy-clean).^2), eps_val) );
snr_ss = 10*log10( sum(clean.^2) / max(sum((enhanced_ss-clean).^2), eps_val) );
snr_w  = 10*log10( sum(clean.^2) / max(sum((enhanced_w-clean).^2), eps_val) );

fprintf("\n--- SNR RESULTS ---\n");
fprintf("Input SNR:       %.2f dB\n", snr_in);
fprintf("Spectral Sub:    %.2f dB\n", snr_ss);
fprintf("Wiener Filter:   %.2f dB\n\n", snr_w);

%% ---------------- Save Audio ----------------
%% ---------------- Save Audio ----------------
noisy       = real(noisy);
enhanced_ss = real(enhanced_ss);
enhanced_w  = real(enhanced_w);

audiowrite('noisy.wav', noisy, Fs);
audiowrite('enhanced_ss.wav', enhanced_ss, Fs);
audiowrite('enhanced_wiener.wav', enhanced_w, Fs);


%% ---------------- Waveform Plots ----------------
t = (0:L-1)/Fs;

figure('Name','Waveforms','Position',[30 30 900 600]);
subplot(3,1,1); plot(t, clean); xlabel('Time (s)'); title('Clean Speech');
subplot(3,1,2); plot(t, noisy); xlabel('Time (s)'); title(sprintf('Noisy Speech (SNR = %.2f dB)', snr_in));
subplot(3,1,3); plot(t, enhanced_w); xlabel('Time (s)'); title(sprintf('Wiener Enhanced (SNR = %.2f dB)', snr_w));

%% ---------------- Spectrograms ----------------
figure('Name','Spectrograms','Position',[100 100 900 650]);
subplot(3,1,1); spectrogram(clean, win, overlap, nfft, Fs, 'yaxis'); title('Clean');
subplot(3,1,2); spectrogram(noisy, win, overlap, nfft, Fs, 'yaxis'); title('Noisy');
subplot(3,1,3); spectrogram(enhanced_w, win, overlap, nfft, Fs, 'yaxis'); title('Wiener Enhanced');

%% ---------------- Playback ----------------
disp("Playing Noisy...");
sound(noisy, Fs); pause(min(4, L/Fs+0.2));

disp("Spectral Subtraction...");
sound(enhanced_ss, Fs); pause(min(4, L/Fs+0.2));

disp("Wiener Result...");
sound(enhanced_w, Fs); pause(min(4, L/Fs+0.2));

disp("Done.");
