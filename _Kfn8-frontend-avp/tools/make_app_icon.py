#!/usr/bin/env python3
"""Generate the Kfn8 app icons: the visionOS three-layer solid image stack (Back / Middle / Front) and, from the same
layers flattened, the single 1024 px iPhone/iPad icon.

Reproducible, dependency-light (Pillow only). Palette is the Showroom palette from the PRD: bone/paper, walnut/clay,
brass, ink. No purple, indigo or cyan. Each layer is a 1024x1024 PNG drawn at 4x and downsampled for clean edges.
visionOS applies the circular mask and the parallax between layers itself; iOS applies its own rounded-square mask.

Usage: python3 tools/make_app_icon.py [--catalog PATH] [--ios-catalog PATH] [--preview PATH]
"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SS = 4  # supersampling factor
S = SIZE * SS

BONE = (239, 233, 221, 255)
PAPER = (247, 243, 235, 255)
PAPER_EDGE = (226, 218, 203, 255)
WALNUT = (78, 54, 39, 255)
WALNUT_LIGHT = (98, 70, 52, 255)
CLAY = (176, 128, 104, 255)
BRASS = (184, 146, 74, 255)
BRASS_LIGHT = (221, 189, 118, 255)
BRASS_DARK = (139, 106, 50, 255)
INK = (28, 26, 24, 255)
GLOW = (255, 226, 173)


def px(v: float) -> int:
    return int(round(v * SS))


def radial_gradient(size: int, inner: tuple, outer: tuple, centre=(0.5, 0.42), radius=0.78) -> Image.Image:
    """Cheap radial gradient built from concentric ellipses on a small canvas, then upscaled and blurred."""
    small = 256
    img = Image.new("RGBA", (small, small), outer)
    draw = ImageDraw.Draw(img)
    cx, cy = centre[0] * small, centre[1] * small
    r_max = radius * small
    steps = 96
    for i in range(steps, 0, -1):
        t = i / steps
        r = r_max * t
        colour = tuple(int(inner[c] + (outer[c] - inner[c]) * t) for c in range(3)) + (255,)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=colour)
    return img.resize((size, size), Image.LANCZOS).filter(ImageFilter.GaussianBlur(size / 64))


def soft_ellipse(size: int, box, colour, alpha: int, blur: float) -> Image.Image:
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse(box, fill=colour + (alpha,))
    return layer.filter(ImageFilter.GaussianBlur(blur))


def back_layer() -> Image.Image:
    img = radial_gradient(S, PAPER, PAPER_EDGE)
    # Warm floor band in the lower third: a clay wash that grounds the chair.
    floor = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    fd = ImageDraw.Draw(floor)
    horizon = px(690)
    for y in range(horizon, S):
        t = (y - horizon) / (S - horizon)
        a = int(70 * min(1.0, t * 1.6))
        fd.line([(0, y), (S, y)], fill=CLAY[:3] + (a,))
    floor = floor.filter(ImageFilter.GaussianBlur(px(10)))
    img.alpha_composite(floor)
    # Contact shadow where the chair will sit (middle layer), so parallax reads as depth.
    img.alpha_composite(soft_ellipse(S, [px(300), px(700), px(724), px(760)], INK[:3], 60, px(18)))
    return img


def middle_layer() -> Image.Image:
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Armchair silhouette, base-centre at (512, 716). Distinct backrest, seat and arms so it still reads at 60 px.
    # Backrest: tall, slightly narrower than the seat, big radius on top only.
    d.rounded_rectangle([px(384), px(372), px(640), px(600)], radius=px(96), fill=WALNUT)
    d.rectangle([px(384), px(520), px(640), px(600)], fill=WALNUT)
    # Arms: rounded tops, standing proud of the backrest.
    for x0, x1 in ((px(300), px(392)), (px(632), px(724))):
        d.rounded_rectangle([x0, px(488), x1, px(656)], radius=px(44), fill=WALNUT)
        d.rectangle([x0, px(560), x1, px(656)], fill=WALNUT)
    # Seat cushion: lighter walnut, separated from the backrest by a thin bone gap so the two shapes never merge.
    d.rounded_rectangle([px(392), px(576), px(632), px(660)], radius=px(26), fill=WALNUT_LIGHT)
    d.rounded_rectangle([px(392), px(568), px(632), px(578)], radius=px(4), fill=BONE[:3] + (120,))
    # Base rail and tapered legs
    d.rounded_rectangle([px(316), px(650), px(708), px(674)], radius=px(10), fill=WALNUT)
    d.polygon([(px(340), px(672)), (px(384), px(672)), (px(376), px(716)), (px(348), px(716))], fill=WALNUT)
    d.polygon([(px(640), px(672)), (px(684), px(672)), (px(676), px(716)), (px(648), px(716))], fill=WALNUT)
    return img


def front_layer() -> Image.Image:
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    # Light pool first, so the shade draws over it. Falls onto the chair beneath (parallax makes it float).
    img.alpha_composite(soft_ellipse(S, [px(372), px(352), px(652), px(560)], GLOW, 140, px(44)))
    img.alpha_composite(soft_ellipse(S, [px(452), px(336), px(572), px(400)], (255, 244, 214), 200, px(14)))
    d = ImageDraw.Draw(img)
    # Cord and ceiling rose
    d.rounded_rectangle([px(507), px(96), px(517), px(262)], radius=px(5), fill=BRASS_DARK)
    d.rounded_rectangle([px(492), px(84), px(532), px(102)], radius=px(9), fill=BRASS)
    # Shade: bell profile as a polygon at supersampled resolution, then a rounded rim.
    bell = [(px(494), px(258)), (px(530), px(258)), (px(542), px(286)), (px(566), px(318)), (px(586), px(344)),
            (px(438), px(344)), (px(458), px(318)), (px(482), px(286))]
    d.polygon(bell, fill=BRASS)
    d.rounded_rectangle([px(486), px(248), px(538), px(268)], radius=px(10), fill=BRASS)
    d.rounded_rectangle([px(430), px(334), px(594), px(356)], radius=px(11), fill=BRASS)
    # Rim highlight, left-edge specular, bulb sliver under the shade
    d.rounded_rectangle([px(436), px(334), px(588), px(341)], radius=px(3), fill=BRASS_LIGHT)
    d.line([(px(452), px(336)), (px(490), px(266))], fill=BRASS_LIGHT, width=px(7))
    d.ellipse([px(494), px(348), px(530), px(374)], fill=(255, 247, 226, 255))
    return img


def finish(layer: Image.Image) -> Image.Image:
    return layer.resize((SIZE, SIZE), Image.LANCZOS)


def write_catalog(catalog: Path, layers: dict[str, Image.Image]) -> None:
    stack = catalog / "AppIcon.solidimagestack"
    stack.mkdir(parents=True, exist_ok=True)
    info = {"author": "xcode", "version": 1}
    (catalog / "Contents.json").write_text(json.dumps({"info": info}, indent=2) + "\n")
    order = ["Front", "Middle", "Back"]  # front-most first, as Xcode writes it
    (stack / "Contents.json").write_text(json.dumps({
        "info": info,
        "layers": [{"filename": f"{name}.solidimagestacklayer"} for name in order],
    }, indent=2) + "\n")
    for name in order:
        layer_dir = stack / f"{name}.solidimagestacklayer"
        imageset = layer_dir / "Content.imageset"
        imageset.mkdir(parents=True, exist_ok=True)
        (layer_dir / "Contents.json").write_text(json.dumps({"info": info}, indent=2) + "\n")
        filename = f"{name.lower()}.png"
        layers[name].save(imageset / filename, optimize=True)
        (imageset / "Contents.json").write_text(json.dumps({
            "images": [{"filename": filename, "idiom": "vision", "scale": "2x"}],
            "info": info,
        }, indent=2) + "\n")


def write_ios_catalog(catalog: Path, layers: dict[str, Image.Image]) -> None:
    """Opaque flattened icon (iOS rejects alpha in app icons) as a single-size universal appiconset."""
    flat = layers["Back"].copy()
    flat.alpha_composite(layers["Middle"])
    flat.alpha_composite(layers["Front"])
    iconset = catalog / "AppIcon.appiconset"
    iconset.mkdir(parents=True, exist_ok=True)
    info = {"author": "xcode", "version": 1}
    (catalog / "Contents.json").write_text(json.dumps({"info": info}, indent=2) + "\n")
    flat.convert("RGB").save(iconset / "icon-1024.png", optimize=True)
    (iconset / "Contents.json").write_text(json.dumps({
        "images": [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": info,
    }, indent=2) + "\n")


def preview(layers: dict[str, Image.Image], out: Path) -> None:
    """Flattened, circle-masked preview for review. Not what visionOS renders (it adds depth and specular)."""
    flat = layers["Back"].copy()
    flat.alpha_composite(layers["Middle"])
    flat.alpha_composite(layers["Front"])
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, S - 1, S - 1], fill=255)
    mask = mask.resize((SIZE, SIZE), Image.LANCZOS)
    flat.putalpha(mask)
    sheet = Image.new("RGBA", (SIZE * 2 + 96, SIZE + 64), (250, 248, 243, 255))
    sheet.alpha_composite(flat, (32, 32))
    small = flat.resize((256, 256), Image.LANCZOS)
    tiny = flat.resize((96, 96), Image.LANCZOS)
    sheet.alpha_composite(small, (SIZE + 64, 32))
    sheet.alpha_composite(tiny, (SIZE + 64, 320))
    sheet.save(out, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    default_catalog = Path(__file__).resolve().parents[1] / "_Kfn8-frontend-avp-src/Kfn8M0Probe/Assets.xcassets"
    parser.add_argument("--catalog", type=Path, default=default_catalog)
    parser.add_argument("--ios-catalog", type=Path, default=default_catalog.parents[1] / "Kfn8/iOS/Assets.xcassets")
    parser.add_argument("--preview", type=Path, default=None)
    args = parser.parse_args()
    layers = {"Back": finish(back_layer()), "Middle": finish(middle_layer()), "Front": finish(front_layer())}
    write_catalog(args.catalog, layers)
    print(f"wrote {args.catalog}")
    write_ios_catalog(args.ios_catalog, layers)
    print(f"wrote {args.ios_catalog}")
    if args.preview:
        preview(layers, args.preview)
        print(f"wrote {args.preview}")


if __name__ == "__main__":
    main()
