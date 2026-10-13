#!/usr/bin/env python3
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SCALE = 2
EXPANDED = (250, 0, 850, 330)
COLLAPSED = (320, 0, 780, 84)
APPROVAL = (270, 0, 830, 190)

STILLS = {
    "music-claude": EXPANDED,
    "agenda": EXPANDED,
    "weather": EXPANDED,
    "shelf-drop": EXPANDED,
    "shelf": EXPANDED,
    "bluetooth": EXPANDED,
    "clipboard": EXPANDED,
    "approval": APPROVAL,
    "collapsed": COLLAPSED,
    "volume": COLLAPSED,
    "brightness": COLLAPSED,
    "peek-done": COLLAPSED,
    "peek-battery": COLLAPSED,
    "peek-airpods": COLLAPSED,
    "peek-meeting": COLLAPSED,
}

TOUR = [
    ("collapsed", 1600),
    ("peek-done", 1600),
    ("music-claude", 2400),
    ("agenda", 1800),
    ("weather", 1800),
    ("shelf-drop", 1600),
    ("shelf", 1600),
    ("bluetooth", 1800),
    ("clipboard", 1600),
    ("volume", 1400),
    ("approval", 2200),
]


def crop(image, box):
    return image.crop(tuple(value * SCALE for value in box))


def rounded(image, radius):
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, image.width - 1, image.height - 1), radius, fill=255)
    result = image.convert("RGBA")
    result.putalpha(ImageChops.multiply(result.getchannel("A"), mask))
    return result


def shadowed(image, radius, blur=36, offset=18, opacity=150):
    pad = blur * 2
    canvas = Image.new("RGBA", (image.width + pad * 2, image.height + pad * 2), (0, 0, 0, 0))
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (pad, pad + offset, pad + image.width, pad + image.height + offset), radius, fill=(0, 0, 0, opacity)
    )
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(blur)))
    canvas.alpha_composite(rounded(image, radius), (pad, pad))
    return canvas


def wallpaper(raw, size):
    source = Image.open(raw / "collapsed.png").convert("RGB")
    band = source.crop((0, 120, source.width, source.height))
    return band.resize(size, Image.LANCZOS).convert("RGBA")


def windows(raw):
    settings = Image.open(raw / "settings.png").convert("RGBA")
    settings = settings.crop((0, 0, settings.width, 1230))
    welcome = Image.open(raw / "welcome.png").convert("RGBA")
    left = shadowed(welcome, 22)
    right = shadowed(settings, 22)
    gap = -60
    width = left.width + right.width + gap
    height = max(left.height, right.height)
    canvas = wallpaper(raw, (width, height))
    canvas.alpha_composite(left, (0, (height - left.height) // 2))
    canvas.alpha_composite(right, (left.width + gap, (height - right.height) // 2))
    return rounded(canvas.resize((canvas.width // 2, canvas.height // 2), Image.LANCZOS), 18)


def tour(raw, width):
    frames, durations = [], []
    scenes = []
    for name, hold in TOUR:
        image = crop(Image.open(raw / f"{name}.png").convert("RGB"), EXPANDED)
        height = round(image.height * width / image.width)
        scenes.append((image.resize((width, height), Image.LANCZOS), hold))
    steps = 5
    for index, (image, hold) in enumerate(scenes):
        frames.append(image)
        durations.append(hold)
        following = scenes[(index + 1) % len(scenes)][0]
        for step in range(1, steps):
            frames.append(Image.blend(image, following, step / steps))
            durations.append(60)
    return frames, durations


def main():
    raw_root = Path(sys.argv[1])
    out_root = Path(sys.argv[2])
    for raw in sorted(path for path in raw_root.iterdir() if path.is_dir()):
        out = out_root / raw.name
        out.mkdir(parents=True, exist_ok=True)
        for name, box in STILLS.items():
            image = crop(Image.open(raw / f"{name}.png"), box)
            rounded(image, 28).save(out / f"{name}.png", optimize=True)
        windows(raw).save(out / "windows.png", optimize=True)
        frames, durations = tour(raw, 1200)
        frames[0].save(
            out / "tour.webp", save_all=True, append_images=frames[1:], duration=durations, loop=0, quality=86, method=6
        )
        print(f"{out}: {sum(path.stat().st_size for path in out.iterdir()) // 1024} KB")


if __name__ == "__main__":
    main()
