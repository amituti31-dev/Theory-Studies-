# Local TTS relay: keeps Python+edge_tts warm so synthesis starts instantly.
# Text is vocalized (nikud) with Phonikud before synthesis for accurate
# pronunciation. GET /tts?text=...&voice=...&rate=... -> audio/mpeg bytes
import asyncio
import os
import edge_tts
from aiohttp import web

_PK_MODEL = os.path.expandvars(
    r"%LOCALAPPDATA%\TheoryApp\phonikud\phonikud-1.0.int8.onnx")
_phonikud = None
if os.path.exists(_PK_MODEL):
    try:
        from phonikud_onnx import Phonikud
        _phonikud = Phonikud(_PK_MODEL)
    except Exception:
        _phonikud = None


def vocalize(text: str) -> str:
    """Add nikud so the neural voice pronounces ambiguous words correctly."""
    if _phonikud is None:
        return text
    try:
        out = _phonikud.add_diacritics(text)
        # Strip Phonikud's special markers that TTS voices don't understand
        return out.replace("|", "").replace("֫", "").replace("ֽ", "")
    except Exception:
        return text


async def tts(request: web.Request) -> web.Response:
    text = request.query.get("text", "").strip()
    voice = request.query.get("voice", "he-IL-AvriNeural")
    rate = request.query.get("rate", "-15%")
    if not text:
        return web.Response(status=400, text="missing text")
    # Nikud preprocessing is available via vocalize() but disabled by default —
    # Avri reads plain text more naturally (tested: vocalized input sounded worse)
    if request.query.get("nikud") == "1":
        text = vocalize(text)
    last_err = "no audio"
    for _attempt in range(3):
        try:
            communicate = edge_tts.Communicate(text, voice, rate=rate)
            buf = bytearray()
            async for chunk in communicate.stream():
                if chunk["type"] == "audio":
                    buf.extend(chunk["data"])
            if buf:
                return web.Response(body=bytes(buf), content_type="audio/mpeg")
        except Exception as e:  # noqa: BLE001
            last_err = str(e)
        await asyncio.sleep(0.3)
    return web.Response(status=502, text=last_err)


async def health(_request: web.Request) -> web.Response:
    return web.Response(text="ok")


app = web.Application()
app.router.add_get("/tts", tts)
app.router.add_get("/", health)

if __name__ == "__main__":
    web.run_app(app, host="127.0.0.1", port=8179, print=None)
