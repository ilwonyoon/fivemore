#!/usr/bin/env python3
"""Convert generated checkerboard previews into production RGBA assets.

The image model occasionally renders a transparency checkerboard into RGB
pixels. 5 More artwork is intentionally either dark charcoal or highly
saturated crayon, while that checkerboard is neutral gray, so a combined
luminance/saturation matte removes it deterministically.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


def alpha_matte(rgb: np.ndarray, *, include_color: bool) -> np.ndarray:
    normalized = rgb.astype(np.float32) / 255.0
    maximum = normalized.max(axis=2)
    minimum = normalized.min(axis=2)
    saturation = np.divide(
        maximum - minimum,
        maximum,
        out=np.zeros_like(maximum),
        where=maximum > 0,
    )
    luminance = normalized @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)

    # Build a conservative core first. Checkerboard folds can contain a few
    # dark pixels, but unlike the intended crayon marks they do not form large
    # connected components.
    core = luminance < 0.30
    if include_color:
        core |= saturation > 0.30

    labels, count = ndimage.label(core, structure=np.ones((3, 3), dtype=np.uint8))
    component_sizes = np.bincount(labels.ravel())
    minimum_component = max(64, round(core.size * 0.00025))
    keep = component_sizes >= minimum_component
    keep[0] = False
    core = keep[labels]

    # Recover a small antialiased fringe only around retained artwork. This
    # prevents distant checker texture from leaking into the alpha channel.
    support = ndimage.binary_dilation(core, iterations=4)
    dark = np.clip((0.50 - luminance) / 0.34, 0.0, 1.0)
    alpha = dark
    if include_color:
        color = np.clip((saturation - 0.05) / 0.32, 0.0, 1.0)
        alpha = np.maximum(alpha, color)
    alpha = np.where(support, alpha, 0.0)

    # Remove faint paper/checker noise while preserving deliberate crayon gaps.
    alpha[alpha < 0.08] = 0.0
    return np.rint(alpha * 255).astype(np.uint8)


def crop_to_artwork(image: Image.Image, padding_fraction: float) -> Image.Image:
    alpha = np.asarray(image.getchannel("A"))
    ys, xs = np.nonzero(alpha > 8)
    if not len(xs):
        raise ValueError("No foreground pixels remained after alpha extraction")

    left, right = int(xs.min()), int(xs.max()) + 1
    top, bottom = int(ys.min()), int(ys.max()) + 1
    padding = max(8, round(max(right - left, bottom - top) * padding_fraction))
    return image.crop(
        (
            max(0, left - padding),
            max(0, top - padding),
            min(image.width, right + padding),
            min(image.height, bottom + padding),
        )
    )


def place_on_square(image: Image.Image) -> Image.Image:
    side = max(image.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.alpha_composite(
        image,
        dest=((side - image.width) // 2, (side - image.height) // 2),
    )
    return square


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--mode", choices=("icon", "brand"), required=True)
    parser.add_argument("--square", action="store_true")
    args = parser.parse_args()

    source = Image.open(args.input).convert("RGB")
    rgb = np.asarray(source)
    alpha = alpha_matte(rgb, include_color=args.mode == "brand")

    if args.mode == "icon":
        # Template icons are colorized by SwiftUI. Normalizing their RGB avoids
        # checkerboard color contamination in semi-transparent edge pixels.
        output_rgb = np.full_like(rgb, 24)
    else:
        output_rgb = rgb

    rgba = np.dstack((output_rgb, alpha))
    result = crop_to_artwork(Image.fromarray(rgba, "RGBA"), padding_fraction=0.07)
    if args.square:
        result = place_on_square(result)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    result.save(args.output, format="PNG", optimize=True)


if __name__ == "__main__":
    main()
