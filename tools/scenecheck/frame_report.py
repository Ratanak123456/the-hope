#!/usr/bin/env python3
"""Where everything lands IN THE FRAME, as numbers.

The renderer answers "does this shot read?"; this answers "why not". For each
capture it prints every named part's horizontal and vertical span as a
percentage of the half-frame at that part's own distance, so -100% is the left
edge and +100% the right.

That turns the questions this project keeps getting wrong into arithmetic:

  * is the foreground actually cropping an edge, or is it off-screen entirely?
    (the welcome screen's whole foreground layer was outside the frustum)
  * is something sitting on the lens? (a route marker flag covered a quarter
    of the convoy tracking shot)
  * does a foreground element overlap the subject it is meant to frame?

Usage: frame_report.py <dump.json> [substring of tag] [substring of part name]
"""
import json, math, sys

# Parts small enough that their position in frame is not a composition
# question. Reporting every bolt buries the elements that matter.
MIN_EXTENT = 0.6


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def report(capture, part_filter, aspect=16 / 9):
    eye, look, up = capture["eye"], capture["look"], capture["up"]
    right = cross(look, up)
    half_angle = math.tan(math.radians(capture["fov"]) / 2)
    print(f"\n=== {capture['tag']}   fov {capture['fov']:.0f} ===")
    print(f"{'part':<22}{'dist':>7}{'lateral span':>20}{'vertical span':>20}")
    rows = []
    for part in capture["parts"]:
        if part_filter and part_filter.lower() not in part["n"].lower():
            continue
        if max(part["s"]) < MIN_EXTENT:
            continue
        rel = [part["p"][i] - eye[i] for i in range(3)]
        distance = dot(rel, look)
        if distance <= 0.2:
            continue
        # Half-extent of the (rotated) box projected onto a screen axis.
        def extent(axis):
            return sum(abs(dot(part[k], axis)) * part["s"][i] / 2 for i, k in enumerate("xyz"))
        hh = distance * half_angle
        hw = hh * aspect
        lat, ver = dot(rel, right), dot(rel, up)
        el, ev = extent(right), extent(up)
        rows.append((distance, part["n"],
                     (lat - el) / hw * 100, (lat + el) / hw * 100,
                     (ver - ev) / hh * 100, (ver + ev) / hh * 100))
    rows.sort()
    for distance, name, l0, l1, v0, v1 in rows:
        print(f"{name:<22}{distance:7.2f}   {l0:6.0f}% ..{l1:6.0f}%   {v0:6.0f}% ..{v1:6.0f}%")


if __name__ == "__main__":
    captures = json.load(open(sys.argv[1]))
    tag_filter = sys.argv[2] if len(sys.argv) > 2 else None
    part_filter = sys.argv[3] if len(sys.argv) > 3 else None
    for capture in captures:
        if tag_filter and tag_filter.lower() not in capture["tag"].lower():
            continue
        report(capture, part_filter)
