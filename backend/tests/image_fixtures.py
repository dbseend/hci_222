from io import BytesIO

from PIL import Image


def jpeg_bytes() -> bytes:
    output = BytesIO()
    Image.new("RGB", (2, 2), color=(255, 0, 0)).save(output, format="JPEG")
    return output.getvalue()
