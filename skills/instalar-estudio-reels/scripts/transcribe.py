"""Transcribe a video locally with Whisper (drop-in replacement for video-use's
ElevenLabs Scribe helper).

Installed by estudio-reels over video-use/helpers/transcribe.py. It keeps the
same public functions (load_api_key, transcript_path, transcribe_one) and the
same output shape that the rest of video-use reads:

    {"language_code": "es", "text": "...", "words": [
        {"text": "Hola", "start": 0.12, "end": 0.40, "type": "word", "speaker_id": "speaker_0"},
        {"text": " ", "start": 0.40, "end": 0.55, "type": "spacing", "speaker_id": "speaker_0"},
        ...]}

No API key and no upload: audio never leaves the computer.

Backend: mlx-whisper on Apple silicon, faster-whisper everywhere else.
Override with ESTUDIO_WHISPER_BACKEND=mlx|faster and ESTUDIO_WHISPER_MODEL=<model>.
Default language is Spanish (ESTUDIO_REELS_LANG or --language; "auto" detects).

Usage:
    python helpers/transcribe.py <video_path>
    python helpers/transcribe.py <video_path> --edit-dir /custom/edit
    python helpers/transcribe.py <video_path> --language en
    python helpers/transcribe.py --warmup          # download the model once
"""

from __future__ import annotations

import argparse
import array
import json
import math
import os
import platform
import subprocess
import sys
import tempfile
import threading
import time
import wave
from pathlib import Path


DEFAULT_LANGUAGE = os.environ.get("ESTUDIO_REELS_LANG", "es")
MLX_MODEL = "mlx-community/whisper-large-v3-turbo"
FASTER_MODEL = "large-v3-turbo"
FASTER_FALLBACK_MODEL = "medium"

# Whisper tends to drop hesitations. A prompt full of them nudges it to keep
# "eh", "este", "mmm"… so the editor can see and cut them.
FILLER_PROMPTS = {
    "es": "Eh… este, o sea, mmm, bueno, pues… ¿no? Ajá. Eh, a ver, este…",
    "en": "Um, uh, like, you know, I mean… so, uh, yeah.",
}

_LOCK = threading.Lock()  # one model run at a time; batch mode uses threads
_FASTER_MODEL_CACHE: dict[str, object] = {}


# --------------------------------------------------------------------------
# Kept for compatibility with transcribe_batch.py
# --------------------------------------------------------------------------

def load_api_key() -> str:
    """No key needed for local Whisper. Kept so transcribe_batch.py works."""
    return ""


def count_audio_tracks(video_path: Path) -> int:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "a",
         "-show_entries", "stream=index", "-of", "csv=p=0", str(video_path)],
        capture_output=True, text=True,
    )
    return len([ln for ln in out.stdout.splitlines() if ln.strip()])


def peak_dbfs(wav_path: Path) -> float:
    peak = 0
    with wave.open(str(wav_path), "rb") as w:
        while frames := w.readframes(1 << 16):
            samples = array.array("h", frames)
            peak = max(peak, max(samples), -min(samples))
    return 20 * math.log10(peak / 32768) if peak > 0 else float("-inf")


def extract_audio(video_path: Path, dest: Path, audio_track: int = 0) -> None:
    cmd = [
        "ffmpeg", "-y", "-i", str(video_path),
        "-map", f"0:a:{audio_track}",
        "-vn", "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le",
        str(dest),
    ]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def transcript_path(edit_dir: Path, video: Path, audio_track: int = 0) -> Path:
    suffix = "" if audio_track == 0 else f".track{audio_track}"
    return edit_dir / "transcripts" / f"{video.stem}{suffix}.json"


# --------------------------------------------------------------------------
# Whisper backends
# --------------------------------------------------------------------------

def pick_backend() -> str:
    forced = os.environ.get("ESTUDIO_WHISPER_BACKEND", "").strip().lower()
    if forced in {"mlx", "faster"}:
        return forced
    if sys.platform == "darwin" and platform.machine() == "arm64":
        try:
            import mlx_whisper  # noqa: F401
            return "mlx"
        except ImportError:
            pass
    return "faster"


def _norm_language(language: str | None) -> str | None:
    lang = (language or DEFAULT_LANGUAGE or "").strip().lower()
    return None if lang in {"", "auto"} else lang


def run_whisper(audio_path: Path, language: str | None) -> tuple[list[dict], str, str]:
    """Return (raw_words, detected_language, model_name).

    raw_words: [{"word": str, "start": float, "end": float, "probability": float}]
    """
    backend = pick_backend()
    lang = _norm_language(language)
    prompt = FILLER_PROMPTS.get(lang or "", None)

    if backend == "mlx":
        import mlx_whisper

        model = os.environ.get("ESTUDIO_WHISPER_MODEL", MLX_MODEL)
        kwargs = dict(path_or_hf_repo=model, word_timestamps=True,
                      condition_on_previous_text=False)
        if lang:
            kwargs["language"] = lang
        if prompt:
            kwargs["initial_prompt"] = prompt
        result = mlx_whisper.transcribe(str(audio_path), **kwargs)
        words: list[dict] = []
        for seg in result.get("segments", []):
            for w in seg.get("words", []) or []:
                words.append({
                    "word": w.get("word", ""),
                    "start": float(w.get("start", 0.0)),
                    "end": float(w.get("end", 0.0)),
                    "probability": float(w.get("probability", 0.0)),
                })
        return words, result.get("language") or (lang or ""), f"mlx:{model}"

    from faster_whisper import WhisperModel

    model_name = os.environ.get("ESTUDIO_WHISPER_MODEL", FASTER_MODEL)
    model = _FASTER_MODEL_CACHE.get(model_name)
    if model is None:
        try:
            model = WhisperModel(model_name, device="auto", compute_type="auto")
        except Exception:
            model_name = FASTER_FALLBACK_MODEL
            model = WhisperModel(model_name, device="auto", compute_type="auto")
        _FASTER_MODEL_CACHE[model_name] = model
    segments, info = model.transcribe(
        str(audio_path), language=lang, word_timestamps=True,
        initial_prompt=prompt, condition_on_previous_text=False,
        vad_filter=False,
    )
    words = []
    for seg in segments:
        for w in seg.words or []:
            words.append({"word": w.word, "start": float(w.start),
                          "end": float(w.end), "probability": float(w.probability)})
    return words, getattr(info, "language", None) or (lang or ""), f"faster:{model_name}"


def to_scribe_words(raw_words: list[dict]) -> list[dict]:
    """Convert Whisper words to the Scribe-like list video-use expects:
    'word' entries plus 'spacing' entries that carry the silence between them."""
    out: list[dict] = []
    prev_end: float | None = None
    for w in raw_words:
        text = (w.get("word") or "").strip()
        if not text:
            continue
        start = round(max(0.0, float(w["start"])), 3)
        end = round(max(start, float(w["end"])), 3)
        if prev_end is not None:
            if start < prev_end:          # Whisper occasionally overlaps
                start = prev_end
                end = max(end, start)
            if start > prev_end:
                out.append({"text": " ", "start": prev_end, "end": start,
                            "type": "spacing", "speaker_id": "speaker_0"})
        out.append({"text": text, "start": start, "end": end, "type": "word",
                    "speaker_id": "speaker_0",
                    "logprob": round(math.log(max(w.get("probability", 1e-6), 1e-6)), 4)})
        prev_end = end
    return out


def build_payload(raw_words: list[dict], language: str, model: str) -> dict:
    words = to_scribe_words(raw_words)
    text = " ".join(w["text"] for w in words if w["type"] == "word")
    for p in (",", ".", "?", "!", ":", ";"):
        text = text.replace(f" {p}", p)
    return {
        "language_code": language,
        "language_probability": None,
        "text": text,
        "words": words,
        "transcriber": "whisper-local",
        "model": model,
    }


# --------------------------------------------------------------------------
# Public API (same signature as the original helper)
# --------------------------------------------------------------------------

def transcribe_one(
    video: Path,
    edit_dir: Path,
    api_key: str = "",
    language: str | None = None,
    num_speakers: int | None = None,  # accepted for compatibility; single speaker
    verbose: bool = True,
    audio_track: int = 0,
) -> Path:
    transcripts_dir = edit_dir / "transcripts"
    transcripts_dir.mkdir(parents=True, exist_ok=True)
    out_path = transcript_path(edit_dir, video, audio_track)

    if out_path.exists():
        if verbose:
            print(f"cached: {out_path.name}")
        return out_path

    if verbose:
        print(f"  extracting audio from {video.name}", flush=True)

    n_tracks = count_audio_tracks(video)
    if n_tracks > 1 and verbose:
        print(f"  note: {video.name} has {n_tracks} audio tracks, using track "
              f"{audio_track + 1} (--audio-track to change)", flush=True)

    t0 = time.time()
    with tempfile.TemporaryDirectory() as tmp:
        audio = Path(tmp) / f"{video.stem}.wav"
        extract_audio(video, audio, audio_track)

        peak = peak_dbfs(audio)
        if peak < -60.0:
            raise RuntimeError(
                f"track {audio_track + 1} of {video.name} is silent (peak {peak:.1f} dBFS). "
                + (f"The file has {n_tracks} audio tracks; try --audio-track "
                   + " or ".join(str(i) for i in range(n_tracks) if i != audio_track) + "."
                   if n_tracks > 1 else "Check the source audio.")
            )

        if verbose:
            print(f"  transcribing locally with Whisper ({pick_backend()})", flush=True)
        with _LOCK:
            raw_words, detected, model = run_whisper(audio, language)

    payload = build_payload(raw_words, detected, model)
    out_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False))

    if verbose:
        kb = out_path.stat().st_size / 1024
        n = sum(1 for w in payload["words"] if w["type"] == "word")
        print(f"  saved: {out_path.name} ({kb:.1f} KB) in {time.time() - t0:.1f}s")
        print(f"    words: {n}")
    return out_path


def warmup() -> None:
    """Download and load the model once, on a short generated tone."""
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "warmup.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(16000)
            frames = array.array("h", (int(3000 * math.sin(2 * math.pi * 220 * i / 16000))
                                       for i in range(16000)))
            w.writeframes(frames.tobytes())
        _, _, model = run_whisper(wav, DEFAULT_LANGUAGE)
    print(f"whisper ready: {model}")


def main() -> None:
    ap = argparse.ArgumentParser(description="Transcribe a video locally with Whisper")
    ap.add_argument("video", type=Path, nargs="?", help="Path to video file")
    ap.add_argument("--edit-dir", type=Path, default=None,
                    help="Edit output directory (default: <video_parent>/edit)")
    ap.add_argument("--language", type=str, default=None,
                    help=f"ISO language code (default: {DEFAULT_LANGUAGE}; 'auto' to detect)")
    ap.add_argument("--num-speakers", type=int, default=None,
                    help="Accepted for compatibility; local Whisper assumes one speaker.")
    ap.add_argument("--audio-track", type=int, default=0,
                    help="Zero-based audio track to transcribe.")
    ap.add_argument("--warmup", action="store_true",
                    help="Download/load the Whisper model and exit.")
    args = ap.parse_args()

    if args.warmup:
        warmup()
        return
    if args.video is None:
        ap.error("video is required (or use --warmup)")

    video = args.video.resolve()
    if not video.exists():
        sys.exit(f"video not found: {video}")
    edit_dir = (args.edit_dir or (video.parent / "edit")).resolve()
    transcribe_one(video=video, edit_dir=edit_dir, language=args.language,
                   num_speakers=args.num_speakers, audio_track=args.audio_track)


if __name__ == "__main__":
    main()
