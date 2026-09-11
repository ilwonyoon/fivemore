#!/usr/bin/env python3
"""Make smaller navigation artwork without changing SwiftUI tab-bar layout.

Liquid Glass uses the image's visual bounds, so the hand-drawn navigation
icons need deliberate transparent breathing room inside their existing 40pt
asset canvases. Source PNGs remain untouched in art/generated.
"""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ART_SCALE = 0.70
ASSETS = {
    "IconHome": ROOT / "art/generated/icons/home-transparent-v2.png",
    "IconMemories": ROOT / "art/generated/icons/memories-transparent-v3.png",
}


def output(source: Path, destination: Path, pixels: int) -> None:
    image = Image.open(source).convert("RGBA")
    artwork = image.copy()
    artwork.thumbnail((round(pixels * ART_SCALE), round(pixels * ART_SCALE)), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (pixels, pixels), (0, 0, 0, 0))
    canvas.alpha_composite(artwork, ((pixels - artwork.width) // 2, (pixels - artwork.height) // 2))
    canvas.save(destination, optimize=True)


for name, source in ASSETS.items():
    imageset = ROOT / "FiveMore/Assets.xcassets" / f"{name}.imageset"
    output(source, imageset / f"{name}.png", 40)
    output(source, imageset / f"{name}@2x.png", 80)
    output(source, imageset / f"{name}@3x.png", 120)
