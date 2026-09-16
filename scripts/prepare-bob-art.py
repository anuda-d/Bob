"""Extract the approved Bob drawings without repainting or resampling them.

Requires Pillow (development only).
Run with --write to rebuild the three PNGs, or --check to verify the assets.
The source images are never modified.
"""

import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
REFERENCES = ROOT / "docs/design-mockups/2026-09-15"
ASSETS = ROOT / "Bob/Assets.xcassets"
# Crops exclude the captions, neighbouring poses and Listening's old emphasis marks.
POSES = {
    "Resting": ("bob-pose-study.png", (30, 160, 505, 835)),
    "Listening": ("bob-listening-v2.png", (240, 50, 1050, 1110)),
    "Pleased": ("bob-pose-study.png", (1015, 160, 1500, 835)),
}


def extract(filename, crop):
    source = Image.open(REFERENCES / filename).convert("RGB").crop(crop)
    # All three illustrations are olive/tan against a neutral, slightly blue grey.
    # Seed the silhouette by chroma, then fill enclosed neutral details (eyes, spots).
    # Only alpha is changed; facial and body RGB values remain byte-for-byte intact.
    mask = Image.new("L", source.size)
    mask.putdata([255 if min(red - blue, green - blue) > 7 else 0
                  for red, green, blue in source.get_flattened_data()])
    ImageDraw.floodfill(mask, (0, 0), 128)
    mask = mask.point(lambda value: 0 if value == 128 else 255)
    # Remove the single-pixel neutral matte fringe around the original outline.
    # No face/body colors are changed, and the approved face remains fully opaque.
    mask = mask.filter(ImageFilter.MinFilter(3))
    if crop == POSES["Resting"][1] and filename == POSES["Resting"][0]:
        # Separate rectangles follow the tilted face without including its backdrop.
        for left, top, right, bottom in [(185, 325, 370, 500), (370, 390, 430, 490)]:
            face = (left - crop[0], top - crop[1], right - crop[0], bottom - crop[1])
            assert mask.crop(face).getextrema() == (255, 255), "Resting's face must stay fully opaque"
    bounds = mask.getbbox()
    assert bounds, f"No silhouette found in {filename}"
    cutout = source.convert("RGBA")
    cutout.putalpha(mask)
    cutout = cutout.crop(bounds)
    padding = round(cutout.height * 0.025)
    side = max(cutout.size) + padding * 2
    output = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    offset = ((side - cutout.width) // 2, side - cutout.height - padding)
    output.paste(cutout, offset)
    # Copying has no resampling, color changes or face-specific replacement.
    recovered = output.crop((offset[0], offset[1],
                             offset[0] + cutout.width, offset[1] + cutout.height))
    assert recovered.convert("RGB").tobytes() == source.crop(bounds).tobytes()
    assert recovered.getchannel("A").getextrema() == (0, 255)
    assert all(mask.getpixel(point) == 0 for point in
               [(0, 0), (mask.width - 1, 0), (0, mask.height - 1),
                (mask.width - 1, mask.height - 1)])
    # Clear invisible background RGB as well so previews cannot expose the old matte.
    output.putdata([(red, green, blue, alpha) if alpha else (0, 0, 0, 0)
                    for red, green, blue, alpha in output.get_flattened_data()])
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()
    for pose, (filename, crop) in POSES.items():
        expected = extract(filename, crop)
        destination = ASSETS / f"Bob{pose}.imageset" / "bob.png"
        if args.write:
            destination.parent.mkdir(parents=True, exist_ok=True)
            expected.save(destination, optimize=True)
        else:
            actual = Image.open(destination).convert("RGBA")
            assert actual.size == expected.size, f"Unexpected dimensions: {pose}"
            assert ImageChops.difference(actual, expected).getbbox(alpha_only=False) is None, \
                f"Asset differs from the approved drawing: {pose}"
        print(f"{pose}: {expected.width}x{expected.height}, alpha verified, original pixels preserved")


if __name__ == "__main__":
    main()
