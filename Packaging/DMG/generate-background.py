#!/usr/bin/env python3
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
GENERATED = ROOT / "generated"

WIDTH = 540
HEIGHT = 340
RENDER_SCALE = 2
TOP = (33, 38, 52)
BOTTOM = (8, 11, 18)


def scaled_box(box: tuple[int, int, int, int], scale: int) -> tuple[int, int, int, int]:
    return tuple(value * scale for value in box)


def scaled_point(point: tuple[int, int], scale: int) -> tuple[int, int]:
    return (point[0] * scale, point[1] * scale)


def gradient(size: tuple[int, int]) -> Image.Image:
    width, height = size
    image = Image.new("RGBA", size)
    pixels = image.load()

    for y in range(height):
        t = y / (height - 1)
        color = tuple(round(TOP[index] * (1 - t) + BOTTOM[index] * t) for index in range(3))
        for x in range(width):
            pixels[x, y] = (*color, 255)

    return image


def add_glow(
    image: Image.Image,
    box: tuple[int, int, int, int],
    color: tuple[int, int, int, int],
    blur_radius: int,
) -> None:
    glow = Image.new("RGBA", image.size)
    ImageDraw.Draw(glow).ellipse(box, fill=color)
    image.alpha_composite(glow.filter(ImageFilter.GaussianBlur(blur_radius)))


def add_glass_card(image: Image.Image, box: tuple[int, int, int, int], scale: int) -> None:
    shadow = Image.new("RGBA", image.size)
    shadow_box = (box[0], box[1] + 7 * scale, box[2], box[3] + 7 * scale)
    ImageDraw.Draw(shadow).rounded_rectangle(
        shadow_box,
        radius=24 * scale,
        fill=(0, 0, 0, 96),
    )
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(13 * scale)))

    card = Image.new("RGBA", image.size)
    draw = ImageDraw.Draw(card)
    draw.rounded_rectangle(
        box,
        radius=24 * scale,
        fill=(255, 255, 255, 20),
        outline=(255, 255, 255, 72),
        width=scale,
    )
    draw.rounded_rectangle(
        (box[0] + scale, box[1] + scale, box[2] - scale, box[1] + 22 * scale),
        radius=22 * scale,
        fill=(255, 255, 255, 14),
    )
    image.alpha_composite(card)


def cubic_bezier(
    start: tuple[float, float],
    control_one: tuple[float, float],
    control_two: tuple[float, float],
    end: tuple[float, float],
    scale: int,
) -> list[tuple[int, int]]:
    points = []
    for step in range(25):
        t = step / 24
        inverse_t = 1 - t
        x = (
            inverse_t**3 * start[0]
            + 3 * inverse_t**2 * t * control_one[0]
            + 3 * inverse_t * t**2 * control_two[0]
            + t**3 * end[0]
        )
        y = (
            inverse_t**3 * start[1]
            + 3 * inverse_t**2 * t * control_one[1]
            + 3 * inverse_t * t**2 * control_two[1]
            + t**3 * end[1]
        )
        points.append((round(x * scale), round(y * scale)))
    return points


def add_direction_arrow(image: Image.Image, scale: int) -> None:
    arrow = Image.new("RGBA", image.size)
    draw = ImageDraw.Draw(arrow)
    color = (255, 255, 255, 170)
    width = 2 * scale

    curve = cubic_bezier((218, 176), (244, 176), (244, 147), (232, 152), scale)
    curve += cubic_bezier((232, 152), (227, 155), (241, 190), (274, 179), scale)[1:]
    curve += cubic_bezier((274, 179), (292, 173), (302, 166), (314, 163), scale)[1:]
    draw.line(curve, fill=color, width=width, joint="curve")
    draw.line(
        [scaled_point((314, 163), scale), scaled_point((300, 160), scale)],
        fill=color,
        width=width,
    )
    draw.line(
        [scaled_point((314, 163), scale), scaled_point((305, 174), scale)],
        fill=color,
        width=width,
    )
    image.alpha_composite(arrow)


def add_instruction(image: Image.Image, scale: int) -> None:
    font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 10 * scale)
    text = "Drag to Applications"
    draw = ImageDraw.Draw(image)
    text_box = draw.textbbox((0, 0), text, font=font)
    text_width = text_box[2] - text_box[0]
    draw.text(
        ((image.width - text_width) // 2, 310 * scale),
        text,
        font=font,
        fill=(255, 255, 255, 162),
    )


def build() -> None:
    GENERATED.mkdir(parents=True, exist_ok=True)

    size = (WIDTH * RENDER_SCALE, HEIGHT * RENDER_SCALE)
    background = gradient(size)
    add_glow(background, scaled_box((-130, -130, 270, 250), RENDER_SCALE), (255, 106, 0, 115), 62 * RENDER_SCALE)
    add_glow(background, scaled_box((275, -100, 650, 250), RENDER_SCALE), (105, 160, 255, 82), 74 * RENDER_SCALE)
    add_glow(background, scaled_box((70, 180, 500, 470), RENDER_SCALE), (216, 76, 184, 45), 94 * RENDER_SCALE)

    add_glass_card(background, scaled_box((62, 98, 218, 232), RENDER_SCALE), RENDER_SCALE)
    add_glass_card(background, scaled_box((322, 98, 478, 232), RENDER_SCALE), RENDER_SCALE)
    add_direction_arrow(background, RENDER_SCALE)
    add_instruction(background, RENDER_SCALE)

    background.save(GENERATED / "dmg-background@2x.png")
    background.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS).save(
        GENERATED / "dmg-background.png"
    )


if __name__ == "__main__":
    build()
