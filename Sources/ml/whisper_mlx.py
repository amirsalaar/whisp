"""Whisper MLX transcription via mlx-audio."""

from __future__ import annotations

import os
from typing import Any, Dict

from .loader import load_whisper_mlx_model

DEFAULT_WHISPER_MLX_REPO = "mlx-community/whisper-large-v3-turbo-asr-fp16"


def transcribe(repo: str, audio_path: str) -> Dict[str, Any]:
    """Transcribe audio using Whisper via mlx-audio.

    Accepts WAV files directly; mlx-audio handles audio loading internally.
    """
    if not os.path.exists(audio_path):
        raise FileNotFoundError(f"Audio file not found: {audio_path}")
    if not os.access(audio_path, os.R_OK):
        raise PermissionError(f"Cannot read audio file: {audio_path}")

    model = load_whisper_mlx_model(repo)
    result = model.generate(audio_path)

    text = ""
    if hasattr(result, "text"):
        text = result.text or ""
    elif isinstance(result, dict) and "text" in result:
        text = result.get("text", "") or ""
    elif isinstance(result, str):
        text = result
    else:
        text = str(result)

    return {"success": True, "text": text.strip()}
