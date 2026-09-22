#!/usr/bin/env python3
"""Offline renderer for the North Pole opening's COMPOSITION.

Draws the set the real modules build, from the real camera the real shot puts
there (see dump.luau), so framing, depth layering, silhouette separation and
scale can be reviewed without Roblox Studio.

This is NOT a Studio screenshot and must not be read as one. There are no
Roblox materials, no real lights, no shadows, no fog, no atmosphere and no
post-processing - the shading is one fixed key plus ambient, and transparency
is approximated by blending toward the background. What it does show, exactly,
is WHERE everything is and HOW BIG it reads in frame, which is what the
composition questions are about.

The rasteriser itself is tools/phase0a/offline/render.py's, reused rather than
re-implemented, so both reviews draw boxes the same way.
"""
import json, math, pathlib, sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "phase0a" / "offline"))
import render as base  # noqa: E402  (path is set immediately above)

W, H = 960, 540
AMBIENT = 0.34
KEY = (0.38, 0.86, -0.34)   # high, slightly behind-left of the default lens
FILL = (-0.55, 0.22, 0.60)  # weak bounce from the opposite side


def norm(v):
    m = math.sqrt(sum(c * c for c in v))
    return tuple(c / m for c in v)


KEY = norm(KEY)
FILL = norm(FILL)


class Camera:
    """A camera defined by eye + look direction, matching CFrame.lookAt."""

    def __init__(self, eye, look, up, fov, aspect):
        self.eye = eye
        zc = tuple(-c for c in norm(look))       # CFrame's +Z is backwards
        xc = norm(base.cross(up, zc))
        yc = base.cross(zc, xc)
        self.b = (xc, yc, zc)
        self.ty = math.tan(math.radians(fov) / 2)
        self.tx = self.ty * aspect

    def view(self, p):
        d = base.sub(p, self.eye)
        return (base.dot(d, self.b[0]), base.dot(d, self.b[1]), base.dot(d, self.b[2]))

    def project(self, v, w, h):
        z = -v[2]
        if z <= 0.05:
            return None
        return ((v[0] / z / self.tx * 0.5 + 0.5) * w, (1 - (v[1] / z / self.ty * 0.5 + 0.5)) * h, z)


# Box corners, in the winding the face table below expects.
CORNERS = ((-1, 1, 1), (1, 1, 1), (1, -1, 1), (-1, -1, 1),
           (-1, 1, -1), (1, 1, -1), (1, -1, -1), (-1, -1, -1))


def corners_of(part, shrink=1.0):
    p, (sx, sy, sz) = part["p"], [c / 2 * shrink for c in part["s"]]
    X, Y, Z = part["x"], part["y"], part["z"]
    return [tuple(p[k] + X[k] * ix * sx + Y[k] * iy * sy + Z[k] * iz * sz for k in range(3))
            for ix, iy, iz in CORNERS]


def shade_of(part, normal_world, background):
    key = max(0.0, base.dot(normal_world, KEY))
    fill = max(0.0, base.dot(normal_world, FILL)) * 0.30
    f = AMBIENT + (1 - AMBIENT) * key + fill
    rgb = [min(255, c * f) for c in part["c"]]
    t = part.get("t", 0)
    if t > 0:
        rgb = [c * (1 - t) + b * t for c, b in zip(rgb, background)]
    return tuple(int(c) for c in rgb)


def draw_box(canvas, cam, part, background, shrink=1.0):
    c = corners_of(part, shrink)
    X, Y, Z = part["x"], part["y"], part["z"]
    for idx, n in base.FACES:
        nw = tuple(X[k] * n[0] + Y[k] * n[1] + Z[k] * n[2] for k in range(3))
        col = shade_of(part, nw, background)
        a, b, cc, d = [c[i] for i in idx]
        base.tri(canvas, cam, a, b, cc, col)
        base.tri(canvas, cam, a, cc, d, col)


def draw_wedge(canvas, cam, part, background):
    """A Roblox WedgePart: the +Z top edge is collapsed onto the -Z face."""
    c = corners_of(part)
    # 0..3 = +Z face (top-left, top-right, bottom-right, bottom-left)
    # 4..7 = -Z face. The ramp runs from the -Z top edge down to the +Z bottom.
    tl, tr, br, bl = c[4], c[5], c[2], c[3]
    X, Y, Z = part["x"], part["y"], part["z"]

    def face(points, n):
        nw = tuple(X[k] * n[0] + Y[k] * n[1] + Z[k] * n[2] for k in range(3))
        col = shade_of(part, nw, background)
        for i in range(1, len(points) - 1):
            base.tri(canvas, cam, points[0], points[i], points[i + 1], col)

    face([tl, tr, br, bl], (0, 0.7, 0.7))          # the sloped face
    face([c[4], c[5], c[6], c[7]], (0, 0, -1))     # back
    face([c[7], c[6], c[2], c[3]], (0, -1, 0))     # underside
    face([tl, bl, c[7]], (-1, 0, 0))               # left triangle
    face([tr, c[6], br], (1, 0, 0))                # right triangle


def draw_round(canvas, cam, part, background, axis):
    """A ball or cylinder, as a bundle of boxes.

    A single box reads as a crate where the set means a snow drift or a tyre,
    which is exactly the sort of thing this review is meant to judge - so
    round parts are drawn as a few rotated slabs, enough to break the square
    silhouette without paying for a real tessellation.
    """
    for step in range(3):
        angle = step * math.pi / 3
        ca, sa = math.cos(angle), math.sin(angle)
        X, Y, Z = part["x"], part["y"], part["z"]
        if axis == "x":      # cylinder: circular in the part's YZ plane
            ny = tuple(Y[k] * ca + Z[k] * sa for k in range(3))
            nz = tuple(-Y[k] * sa + Z[k] * ca for k in range(3))
            spun = dict(part, y=ny, z=nz)
        else:                # ball: spin about Y
            nx = tuple(X[k] * ca + Z[k] * sa for k in range(3))
            nz = tuple(-X[k] * sa + Z[k] * ca for k in range(3))
            spun = dict(part, x=nx, z=nz)
        draw_box(canvas, cam, spun, background, shrink=0.93 if step else 1.0)


# Above this transparency a part is treated as air by the rasteriser. Roblox
# still draws it, faintly; what it does NOT do is hide what is behind it.
SEE_THROUGH = 0.6


def render(capture, path, label):
    background = (72, 82, 96)
    canvas = base.Canvas(W, H, background)
    cam = Camera(capture["eye"], capture["look"], capture["up"], capture["fov"], W / H)
    # Far to near: the z-buffer is authoritative, but drawing far first means a
    # part rejected for being behind something is rejected on its first pixel.
    parts = sorted(capture["parts"],
                   key=lambda p: -sum((a - b) ** 2 for a, b in zip(p["p"], capture["eye"])))
    for part in parts:
        # A part this transparent cannot hide anything, and drawing it as an
        # opaque wash of background colour makes it ACT like an occluder in the
        # image: the menu's 93%-transparent ground haze was erasing the mecha's
        # legs here while being invisible in Studio. A tool that invents
        # occlusion is worse than no tool, so these are skipped outright.
        if part.get("t", 0) >= SEE_THROUGH:
            continue
        kind = part.get("k", "Block")
        if kind == "Wedge":
            draw_wedge(canvas, cam, part, background)
        elif kind == "Ball":
            draw_round(canvas, cam, part, background, "y")
        elif kind == "Cylinder":
            draw_round(canvas, cam, part, background, "x")
        else:
            draw_box(canvas, cam, part, background)
    # Thirds, so framing is judged against something rather than by feel.
    for x in (W // 3, 2 * W // 3):
        for y in range(0, H, 14):
            for d in range(7):
                if y + d < H:
                    canvas.px(x, y + d, (150, 156, 168))
    for y in (H // 3, 2 * H // 3):
        for x in range(0, W, 14):
            for d in range(7):
                if x + d < W:
                    canvas.px(x + d, y, (150, 156, 168))
    canvas.text(14, 14, label, (238, 242, 248), 2)
    canvas.text(14, H - 26, f"{len(capture['parts'])} PARTS   FOV {capture['fov']:.0f}", (176, 184, 196), 1)
    canvas.png(path)


if __name__ == "__main__":
    captures = json.load(open(sys.argv[1]))
    outdir = pathlib.Path(sys.argv[2])
    outdir.mkdir(parents=True, exist_ok=True)
    only = sys.argv[3] if len(sys.argv) > 3 else None
    for capture in captures:
        tag = capture["tag"]
        if only and only not in tag:
            continue
        name = tag.replace("@", "-at-") + ".png"
        render(capture, str(outdir / name), tag.replace("_", " "))
        print(name)
