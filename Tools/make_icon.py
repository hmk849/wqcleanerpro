#!/usr/bin/env python3
"""生成 WQ Cleaner Pro 图标：深青到蓝渐变底 + 白色粗体 WQ + 右上四角星光。"""
from PIL import Image, ImageDraw, ImageFont, ImageOps

S = 2048
top, bot = (8, 148, 160), (10, 42, 110)
g = Image.linear_gradient("L").resize((S, S), Image.BICUBIC)
bg = Image.composite(Image.new("RGB", (S, S), bot), Image.new("RGB", (S, S), top), g)
glow = ImageOps.invert(Image.radial_gradient("L").resize((S, S), Image.BICUBIC)).point(lambda v: int(v * 0.35))
bg = Image.composite(Image.new("RGB", (S, S), (90, 200, 220)), bg, glow)

d = ImageDraw.Draw(bg, "RGBA")
# 右上四角星光
cx, cy, r = int(S * 0.78), int(S * 0.22), int(S * 0.075)
star = [(cx, cy - r), (cx + r * 0.22, cy - r * 0.22), (cx + r, cy),
        (cx + r * 0.22, cy + r * 0.22), (cx, cy + r), (cx - r * 0.22, cy + r * 0.22),
        (cx - r, cy), (cx - r * 0.22, cy - r * 0.22)]
d.polygon(star, fill=(255, 255, 255, 235))
# 左下小星光
cx2, cy2, r2 = int(S * 0.20), int(S * 0.80), int(S * 0.045)
star2 = [(cx2, cy2 - r2), (cx2 + r2 * 0.22, cy2 - r2 * 0.22), (cx2 + r2, cy2),
         (cx2 + r2 * 0.22, cy2 + r2 * 0.22), (cx2, cy2 + r2), (cx2 - r2 * 0.22, cy2 + r2 * 0.22),
         (cx2 - r2, cy2), (cx2 - r2 * 0.22, cy2 - r2 * 0.22)]
d.polygon(star2, fill=(255, 255, 255, 160))

font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", int(S * 0.34))
text = "WQ"
bbox = d.textbbox((0, 0), text, font=font)
tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
# 轻微阴影 + 白字
d.text(((S - tw) / 2 - bbox[0] + 6, (S - th) / 2 - bbox[1] + 10), text, font=font, fill=(6, 30, 60, 255))
d.text(((S - tw) / 2 - bbox[0], (S - th) / 2 - bbox[1]), text, font=font, fill=(255, 255, 255, 255))

out = "Sources/WQCleanerPro/Resources/Assets.xcassets/AppIcon.appiconset"
import os
os.makedirs(out, exist_ok=True)
for px in (20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024):
    bg.resize((px, px), Image.LANCZOS).save(f"{out}/icon-{px}.png")
print("ok")
