#!/usr/bin/env python3
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
ASSETS = ROOT / "assets"
GENERATED = ROOT / "generated"

WIDTH = 540
HEIGHT = 340
TOP = (255, 143, 63)
BOTTOM = (168, 68, 0)


def gradient_pixel(y: int) -> tuple[int, int, int, int]:
    t = y / (HEIGHT - 1)
    return (
        round(TOP[0] * (1 - t) + BOTTOM[0] * t),
        round(TOP[1] * (1 - t) + BOTTOM[1] * t),
        round(TOP[2] * (1 - t) + BOTTOM[2] * t),
        255,
    )


def repaint_rect(image: Image.Image, box: tuple[int, int, int, int]) -> None:
    left, top, right, bottom = box
    pixels = image.load()
    for y in range(top, bottom):
        color = gradient_pixel(y)
        for x in range(left, right):
            pixels[x, y] = color


def build() -> None:
    GENERATED.mkdir(parents=True, exist_ok=True)

    reference = Image.open(ASSETS / "figma-reference.png").convert("RGBA")
    background = reference.copy()

    # Leave the center arrow and bottom instruction from Figma, but remove
    # baked-in icon artwork and labels so Finder can render the real items.
    repaint_rect(background, (70, 105, 215, 252))
    repaint_rect(background, (330, 105, 472, 252))

    background.save(GENERATED / "dmg-background.png")
    background.resize((WIDTH * 2, HEIGHT * 2), Image.Resampling.LANCZOS).save(
        GENERATED / "dmg-background@2x.png"
    )


if __name__ == "__main__":
    build()
