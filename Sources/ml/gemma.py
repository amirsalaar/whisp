"""Gemma 4 audio transcription via mlx-vlm."""

from __future__ import annotations

import os
import tempfile
from typing import Any, Dict, List, Optional

from .loader import load_gemma_model

# Max audio length per chunk in seconds (Gemma 4 limit is 30s)
MAX_CHUNK_SECONDS = 28
OVERLAP_SECONDS = 2

DEFAULT_TRANSCRIPTION_PROMPT = (
    "Transcribe the following speech segment in its original language. "
    "Follow these specific instructions for formatting the answer:\n"
    "* Only output the transcription, with no newlines.\n"
    "* When transcribing numbers, write the digits, i.e. write 1.7 and not "
    "one point seven, and write 3 instead of three."
)

DEFAULT_CORRECTION_PROMPT = (
    "Transcribe and clean up the following speech: fix typos, grammar, "
    "punctuation, and remove filler words (um, uh, like, you know). "
    "Keep the original language. Output only the corrected transcription, "
    "nothing else."
)


def _get_audio_duration(audio_path: str) -> float:
    """Get duration of an audio file in seconds using scipy/numpy."""
    import numpy as np

    ext = os.path.splitext(audio_path)[1].lower()

    if ext == ".raw":
        # Raw PCM float32 at 16kHz
        data = np.fromfile(audio_path, dtype=np.float32)
        return len(data) / 16000.0

    if ext == ".wav":
        import wave

        with wave.open(audio_path, "rb") as wf:
            frames = wf.getnframes()
            rate = wf.getframerate()
            return frames / rate

    # Fallback: try librosa
    try:
        import librosa

        duration = librosa.get_duration(path=audio_path)
        return duration
    except Exception:
        # If we can't determine duration, assume it's short enough
        return 0.0


def _split_audio_wav(
    audio_path: str, chunk_seconds: float, overlap: float
) -> List[str]:
    """Split a WAV file into overlapping chunks, returns list of temp file paths."""
    import struct
    import wave

    with wave.open(audio_path, "rb") as wf:
        sr = wf.getframerate()
        n_channels = wf.getnchannels()
        sampwidth = wf.getsampwidth()
        n_frames = wf.getnframes()
        raw = wf.readframes(n_frames)

    chunk_frames = int(chunk_seconds * sr)
    overlap_frames = int(overlap * sr)
    step = chunk_frames - overlap_frames
    bytes_per_frame = n_channels * sampwidth

    chunks = []
    start = 0
    while start < n_frames:
        end = min(start + chunk_frames, n_frames)
        chunk_raw = raw[start * bytes_per_frame : end * bytes_per_frame]

        tmp = tempfile.NamedTemporaryFile(
            suffix=".wav", delete=False, prefix="gemma_chunk_"
        )
        tmp.close()
        with wave.open(tmp.name, "wb") as out:
            out.setnchannels(n_channels)
            out.setsampwidth(sampwidth)
            out.setframerate(sr)
            out.writeframes(chunk_raw)
        chunks.append(tmp.name)

        if end >= n_frames:
            break
        start += step

    return chunks


def transcribe(
    repo: str,
    audio_path: str,
    prompt: Optional[str] = None,
    correct: bool = True,
) -> Dict[str, Any]:
    """Transcribe audio using Gemma 4 via mlx-vlm.

    If correct=True, uses a prompt that combines transcription + correction.
    If correct=False, uses a pure transcription prompt.
    """
    if not os.path.exists(audio_path):
        raise FileNotFoundError(f"Audio file not found: {audio_path}")
    if not os.access(audio_path, os.R_OK):
        raise PermissionError(f"Cannot read audio file: {audio_path}")

    try:
        from mlx_vlm import generate as vlm_generate
        from mlx_vlm.prompt_utils import apply_chat_template
    except ImportError as exc:
        raise RuntimeError(f"mlx-vlm import failed: {exc}") from exc

    model, processor = load_gemma_model(repo)

    # Choose prompt
    if prompt and prompt.strip():
        system_prompt = prompt.strip()
    elif correct:
        system_prompt = DEFAULT_CORRECTION_PROMPT
    else:
        system_prompt = DEFAULT_TRANSCRIPTION_PROMPT

    # Check duration and chunk if needed
    duration = _get_audio_duration(audio_path)
    if duration > MAX_CHUNK_SECONDS + OVERLAP_SECONDS:
        return _transcribe_chunked(model, processor, repo, audio_path, system_prompt)

    return _transcribe_single(model, processor, audio_path, system_prompt)


def _transcribe_single(
    model: Any,
    processor: Any,
    audio_path: str,
    prompt: str,
) -> Dict[str, Any]:
    """Transcribe a single audio file (<=30s)."""
    from mlx_vlm import generate as vlm_generate
    from mlx_vlm.prompt_utils import apply_chat_template

    formatted = apply_chat_template(processor, model.config, prompt, num_audios=1)

    result = vlm_generate(
        model,
        processor,
        formatted,
        audio=[audio_path],
        max_tokens=2048,
        verbose=False,
        temp=0.1,
    )

    text = _clean_output(result.text)
    return {"success": True, "text": text}


def _transcribe_chunked(
    model: Any,
    processor: Any,
    repo: str,
    audio_path: str,
    prompt: str,
) -> Dict[str, Any]:
    """Transcribe long audio by splitting into chunks."""
    chunks = _split_audio_wav(audio_path, MAX_CHUNK_SECONDS, OVERLAP_SECONDS)
    try:
        texts = []
        for i, chunk_path in enumerate(chunks):
            chunk_prompt = prompt
            if i > 0:
                chunk_prompt += "\n(This is a continuation of a longer recording.)"

            result = _transcribe_single(model, processor, chunk_path, chunk_prompt)
            if result["success"]:
                texts.append(result["text"])

        merged = _merge_chunks(texts)
        return {"success": True, "text": merged}
    finally:
        # Clean up temp chunk files
        for path in chunks:
            try:
                os.unlink(path)
            except OSError:
                pass


def _merge_chunks(texts: List[str]) -> str:
    """Merge overlapping transcription chunks.

    Simple approach: concatenate with space, deduplicate obvious overlap
    at chunk boundaries.
    """
    if not texts:
        return ""
    if len(texts) == 1:
        return texts[0]

    merged = texts[0]
    for i in range(1, len(texts)):
        next_text = texts[i]
        # Try to find overlap between end of merged and start of next
        overlap = _find_overlap(merged, next_text)
        if overlap:
            merged += " " + next_text[len(overlap) :]
        else:
            merged += " " + next_text

    return merged.strip()


def _find_overlap(text_a: str, text_b: str, min_words: int = 3) -> Optional[str]:
    """Find overlapping text between the end of text_a and start of text_b."""
    words_a = text_a.split()
    words_b = text_b.split()

    if len(words_a) < min_words or len(words_b) < min_words:
        return None

    # Check increasingly large windows from the end of A
    max_check = min(len(words_a), len(words_b), 15)
    for window_size in range(max_check, min_words - 1, -1):
        tail_a = " ".join(words_a[-window_size:]).lower()
        head_b = " ".join(words_b[:window_size]).lower()
        if tail_a == head_b:
            return " ".join(words_b[:window_size])

    return None


def _clean_output(output: str) -> str:
    """Clean model output, removing artifacts."""
    import re

    # Strip thinking blocks
    cleaned = re.sub(r"<think>.*?</think>", "", output, flags=re.DOTALL)
    cleaned = re.sub(r"<think>.*", "", cleaned, flags=re.DOTALL)

    # Strip quotes
    cleaned = cleaned.strip().strip('"').strip("'").strip()

    return cleaned
