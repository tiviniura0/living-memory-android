"""Verify the Godot-only Canvas signature in a real composited Android PNG.

No Pillow/runtime dependency in CI. Supports the RGB/RGBA, 8-bit, noninterlaced
PNGs emitted by Android screencap, including all five PNG row filters.
"""
import json
from pathlib import Path
import struct
import sys
import zlib


def inspect_capture(path):
    png = Path(path).read_bytes()
    if png[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Native screen capture is not PNG")
    pos, chunks, header = 8, [], None
    while pos < len(png):
        length = struct.unpack_from(">I", png, pos)[0]
        kind = png[pos + 4:pos + 8]
        payload = png[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", payload)
        elif kind == b"IDAT":
            chunks.append(payload)
        elif kind == b"IEND":
            break
        pos += length + 12
    if header is None:
        raise ValueError("PNG header missing")
    width, height, depth, color, compression, filtering, interlace = header
    if not (0 < width <= 10000 and 0 < height <= 10000 and depth == 8
            and color in (2, 6) and compression == filtering == interlace == 0):
        raise ValueError("Unsupported Android PNG encoding")
    bpp = 3 if color == 2 else 4
    stride = width * bpp
    data = zlib.decompress(b"".join(chunks))
    if len(data) != height * (stride + 1):
        raise ValueError("PNG row data size mismatch")
    previous, position, signature_pixels = bytearray(stride), 0, 0
    for _ in range(height):
        rule = data[position]
        row = bytearray(data[position + 1:position + 1 + stride])
        position += stride + 1
        if rule not in range(5):
            raise ValueError("Invalid PNG filter")
        if rule:
            for x in range(stride):
                left = row[x - bpp] if x >= bpp else 0
                above = previous[x]
                upper_left = previous[x - bpp] if x >= bpp else 0
                if rule == 1:
                    predictor = left
                elif rule == 2:
                    predictor = above
                elif rule == 3:
                    predictor = (left + above) // 2
                else:
                    base = left + above - upper_left
                    distances = (abs(base-left), abs(base-above), abs(base-upper_left))
                    predictor = (left if distances[0] <= min(distances[1:]) else
                                 above if distances[1] <= distances[2] else upper_left)
                row[x] = (row[x] + predictor) & 255
        signature_pixels += sum(row[x:x + 3] == b"\xff\x00\xff" for x in range(0, stride, bpp))
        previous = row
    return {"width": width, "height": height, "godot_marker_pixels": signature_pixels}


if __name__ == "__main__":
    result = inspect_capture(sys.argv[1])
    print(json.dumps(result))
    if result["godot_marker_pixels"] < 64:
        raise SystemExit("Godot Canvas signature missing from composited screen")
