"""Generate the WakeQR stop-code QR image and a printable A5 PDF.

Payload is the exact constant the app accepts: WAKE_UP_BKBI

Outputs:
  qr/wakeqr-print.png - >=1000x1000 print-quality QR
  qr/wakeqr-print.pdf - A5 page (300 dpi) with the QR centered and a caption

Requires: pip install qrcode pillow
"""
import os

import qrcode
from PIL import Image, ImageDraw, ImageFont

PAYLOAD = "WAKE_UP_BKBI"
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "qr")

# A5 at 300 dpi
PAGE_W, PAGE_H = 1748, 2480
DPI = 300


def make_qr():
    q = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_H, box_size=40, border=4)
    q.add_data(PAYLOAD)
    q.make(fit=True)
    img = q.make_image(fill_color="black", back_color="white").convert("RGB")
    if img.width < 1000:
        img = img.resize((1200, 1200), Image.NEAREST)
    return img


def load_font(size):
    for name in ("arialbd.ttf", "arial.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def make_pdf(qr_img):
    page = Image.new("RGB", (PAGE_W, PAGE_H), "white")
    qr_size = 1400
    qr_big = qr_img.resize((qr_size, qr_size), Image.NEAREST)
    page.paste(qr_big, ((PAGE_W - qr_size) // 2, (PAGE_H - qr_size) // 2 - 100))

    draw = ImageDraw.Draw(page)
    title_font = load_font(110)
    cap_font = load_font(64)

    def center_text(text, y, font):
        w = draw.textbbox((0, 0), text, font=font)[2]
        draw.text(((PAGE_W - w) // 2, y), text, fill="black", font=font)

    center_text("WakeQR", 160, title_font)
    center_text("Scan this code to stop the alarm", PAGE_H - 560, cap_font)
    center_text("Print me. Stick me far from your bed.", PAGE_H - 440, cap_font)
    return page


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    qr_img = make_qr()
    qr_img.save(os.path.join(OUT_DIR, "wakeqr-print.png"), dpi=(DPI, DPI))
    make_pdf(qr_img).save(os.path.join(OUT_DIR, "wakeqr-print.pdf"), "PDF", resolution=DPI)
    print(f"QR size: {qr_img.width}x{qr_img.height}; wrote wakeqr-print.png and wakeqr-print.pdf")
