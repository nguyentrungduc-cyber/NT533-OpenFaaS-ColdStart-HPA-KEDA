import base64
import binascii
import io
import json
import time

from PIL import Image

MAX_INPUT_BYTES = 5 * 1024 * 1024      
MAX_SIDE = 4000                        
Image.MAX_IMAGE_PIXELS = 25_000_000    
FORMATS = {"PNG", "JPEG", "WEBP"}


def error(msg):
    return {"statusCode": 400, "body": msg}


def handle(event, context):
    try:
        data = json.loads(event.body or b"{}")
    except ValueError:
        return error('can JSON {"image": "<base64>", "width": ...}')
    if not isinstance(data, dict):
        return error("body phai la JSON object")

    b64 = str(data.get("image", ""))
    if "," in b64 and b64.startswith("data:"):     
        b64 = b64.split(",", 1)[1]
    if not b64:
        return error("thieu truong image (base64)")
    try:
        raw = base64.b64decode(b64, validate=True)
    except (binascii.Error, ValueError):
        return error("image khong phai base64 hop le")
    if len(raw) > MAX_INPUT_BYTES:
        return error("anh qua lon (toi da 5 MB)")

    width, height = data.get("width"), data.get("height")
    try:
        width = int(width) if width is not None else None
        height = int(height) if height is not None else None
    except (TypeError, ValueError):
        return error("width/height phai la so nguyen")
    if width is None and height is None:
        return error("can it nhat width hoac height")
    for side in (width, height):
        if side is not None and not 1 <= side <= MAX_SIDE:
            return error(f"width/height phai trong khoang 1-{MAX_SIDE}")

    start = time.perf_counter()
    try:
        img = Image.open(io.BytesIO(raw))
        img.load()
    except (Image.DecompressionBombError, Image.DecompressionBombWarning):
        return error("anh qua nhieu diem anh")
    except Exception:
        return error("khong doc duoc anh (ho tro PNG, JPEG, WEBP, GIF, BMP)")

    orig_w, orig_h = img.size
    if width is None:
        width = max(1, round(orig_w * height / orig_h))
    if height is None:
        height = max(1, round(orig_h * width / orig_w))

    fmt = str(data.get("format") or img.format or "PNG").upper()
    if fmt == "JPG":
        fmt = "JPEG"
    if fmt not in FORMATS:
        return error("format phai la PNG, JPEG hoac WEBP")

    out = img.resize((width, height), Image.LANCZOS)
    if fmt == "JPEG" and out.mode not in ("RGB", "L"):
        out = out.convert("RGB")          
    buf = io.BytesIO()
    out.save(buf, format=fmt)
    elapsed_ms = (time.perf_counter() - start) * 1000

    return {
        "statusCode": 200,
        "body": json.dumps({
            "original": {"width": orig_w, "height": orig_h},
            "width": width,
            "height": height,
            "format": fmt,
            "bytes": buf.tell(),
            "elapsed_ms": round(elapsed_ms, 2),
            "image": base64.b64encode(buf.getvalue()).decode(),
        }),
        "headers": {"Content-Type": "application/json"},
    }