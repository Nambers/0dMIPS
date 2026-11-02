#!/usr/bin/env python3
"""Build the 0dMIPS GitHub Pages site into docs/schematic_html/.

  docs/site/*                  copied verbatim; index.html is the datapath page
                               (concept diagram + RTL schematic browser)
  docs/schematic_svgs/<m>.svg  -> <m>.html, an interactive viewer for one module's
                               Vivado RTL schematic (written by docs/export_schematics.tcl)
  modules.js                   module hierarchy and instance list, read by index.html

The schematics are Vivado's elaborated RTL (synth_design -rtl): generic RTL cells before
technology mapping. Per-instance sizes come from a real synthesis run of the same design,
docs/schematic_svgs/utilization_hier.rpt (report_utilization -hierarchical), matched to each
page through the instance path its frames show. export_schematics.tcl writes both.

Vivado's Nlview SVG only has drawing primitives, so nets are rebuilt from geometry:
wire and pin-stub polylines are joined where an end point meets another polyline's
vertex or the inside of one of its segments; crossings without a shared point stay
separate. Bus rippers are not joins: a ripper is a wire plus a short black diagonal
whose far end touches the bus, and a bit that enters or leaves a bundle is marked by
a small black triangle. The far end of a diagonal and any meeting point under a
triangle are recorded as a "tap" between the two nets instead, so a slice is never
merged into its bus. Every polyline of a net gets data-n="<net id>" and the net's
pins and taps go into the page as JSON.

Run from anywhere: python docs/gen_export_schematics_site.py
"""

import json
import re
import shutil
import subprocess
from collections import defaultdict, namedtuple
from datetime import datetime
from pathlib import Path
from string import Template
from xml.dom import minidom

DOCS = Path(__file__).resolve().parent
SVG_DIR = DOCS / "schematic_svgs"
SITE_DIR = DOCS / "site"
OUT = DOCS / "schematic_html"
REPO_URL = "https://github.com/Nambers/0dMIPS"
TOP = "TOP"
UTIL_FIELDS = ("lut", "ff", "bram", "dsp")

# Nlview styling. If net tracing or the frame "−" icons break after a Vivado upgrade, start here.
NUM = r"-?\d+(?:\.\d+)?"
TOKEN_RE = re.compile(rf"[A-Za-z]|{NUM}")
STUB_RE = re.compile(rf"M({NUM}) ({NUM})([hv])({NUM})$")
ICON_RE = re.compile(rf"M({NUM}) ({NUM})h16v16h-16z$")
RECT_RE = re.compile(rf"M({NUM}) ({NUM})h({NUM})v({NUM})h-{NUM}z$")
JUNCTION_RE = re.compile(rf"M{NUM} {NUM}h(\d)v\1h-\1z$")
DIAGONAL_RE = re.compile(rf"M{NUM} {NUM}l-?5 -?5[hv]-?1$")  # ripper entering a bus
TRIANGLE_RE = re.compile(rf"M({NUM}) ({NUM})v10l({NUM}) -5$")  # bit joining a bundle
MINUS_RE = re.compile(rf"M({NUM}) ({NUM})h12$")  # "−" (collapse) icon of an enclosing frame
FRAME_RE = re.compile(r"A7\.8|l3 1l3 1l1 3l1 3v")  # rounded corners of an enclosing frame
PIN_STROKE = "#1c1f28"
CELL_STROKE = "#575d6c"
TAP_STROKE = "black"
WIRE_STROKES = {"", "#009633"}  # thin nets inherit #8bc34a from the root <g>

# One drawn net segment. kind: "wire", "stub" (pin stub) or "tap" (ripper diagonal);
# pin: [instance ("" = this module's port), pin, "in"|"out", x, y] on a labelled stub.
Elem = namedtuple("Elem", "lines node kind pin bus")

PAGE = Template("""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$module · 0dMIPS RTL schematic</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;600&family=IBM+Plex+Sans:wght@400;600;700&display=swap">
<link rel="stylesheet" href="schematic_viewer.css">
<script src="https://cdn.jsdelivr.net/npm/svg-pan-zoom@3.5.0/dist/svg-pan-zoom.min.js"></script>
</head>
<body>
<header id="bar">
  <a class="home" href="index.html#rtl" title="0dMIPS datapath site">0dMIPS</a>
  <span class="mod">$module</span>
  <button type="button" id="up" hidden>&uarr; up</button>
  <button type="button" id="stats" hidden></button>
  <form id="find" role="search"><input id="q" type="search" placeholder="Find instance or pin" autocomplete="off" aria-label="Find instance or pin"><span id="hits" aria-live="polite"></span></form>
  <span class="zoom"><button type="button" data-z="in" aria-label="Zoom in">+</button><button type="button" data-z="out" aria-label="Zoom out">&minus;</button><button type="button" data-z="fit">Fit</button></span>
</header>
<main id="stage">$svg</main>
<aside id="net" hidden></aside>
<aside id="util" hidden></aside>
<footer id="foot">Vivado RTL schematic of <code>$module</code> · exported $date · <a href="$repo/commit/$hash" target="_blank" rel="noopener">$hash</a> · click a wire to trace its net, a blue box to open it, a frame's &minus; to go back up</footer>
<script>window.SCHEM = $data;</script>
<script src="schematic_viewer.js"></script>
</body>
</html>
""")


def polylines(d):
    """Split an Nlview wire path into absolute polylines; [] if it is not made of M/h/v/l only."""
    toks = TOKEN_RE.findall(d)
    lines, pts, i, x, y = [], [], 0, 0.0, 0.0
    while i < len(toks):
        c = toks[i]
        i += 1
        if c == "M":
            if len(pts) > 1:
                lines.append(pts)
            x, y = float(toks[i]), float(toks[i + 1])
            i += 2
            pts = [(x, y)]
            continue
        if c == "h":
            x += float(toks[i])
            i += 1
        elif c == "v":
            y += float(toks[i])
            i += 1
        elif c == "l":
            x, y = x + float(toks[i]), y + float(toks[i + 1])
            i += 2
        else:
            return []
        pts.append((x, y))
    if len(pts) > 1:
        lines.append(pts)
    return lines


def text(node):
    return node.firstChild.nodeValue if node.firstChild else None


def frame_icons(groups):
    """Top-left corners of the frames' "−" icons, outermost frame first.

    Nlview draws the instance path of this module as nested frames, each with a "−" icon;
    the module's own box is the innermost one.
    """
    minus = []
    for g in groups:
        paths = g.getElementsByTagName("path")
        if g.getAttribute("stroke") == CELL_STROKE and g.getAttribute("stroke-width") == "3" \
                and len(paths) == 1:
            m = MINUS_RE.match(paths[0].getAttribute("d"))
            if m:
                minus.append((float(m[1]) - 2, float(m[2]) - 8))
    return sorted(minus, key=lambda p: p[1])


def classify(doc, groups, minus, pages):
    """Sort the top-level groups into instances, net elements, bundle joints and frame labels."""
    rects = {}
    for p in doc.getElementsByTagName("path"):
        m = RECT_RE.match(p.getAttribute("d"))
        if m:
            x, y, w, h = map(float, m.groups())
            rects[(x, y)] = (x, y, w, h)
    icons = set(minus)

    def is_frame(g):
        for p in g.getElementsByTagName("path"):
            d = p.getAttribute("d")
            m = ICON_RE.match(d)
            if (m and (float(m[1]), float(m[2])) in icons) or FRAME_RE.search(d):
                return True
        return False

    insts, elems, joints, frame_labels = [], [], [], []
    cur = ""  # instance owning the pin stubs that follow; "" = this module's ports
    for g in groups:
        stroke = g.getAttribute("stroke")
        bus = g.getAttribute("stroke-width") in ("2", "3")
        if stroke == CELL_STROKE:
            texts = g.getElementsByTagName("text")
            if is_frame(g):
                frame_labels += [(float(t.getAttribute("y")), text(t)) for t in texts if text(t)]
                cur = ""  # pins after the innermost frame are this module's ports
                continue
            names = [text(t) for t in texts if text(t)]
            if len(names) < 2:
                continue
            cur, typ = names[-2], names[-1]
            box = None
            for p in g.getElementsByTagName("path"):
                m = ICON_RE.match(p.getAttribute("d"))
                if m:
                    box = rects.get((float(m[1]) - 3, float(m[2]) - 3))
            label = texts[-2]
            insts.append({
                "name": cur,
                "type": typ,
                "box": box,
                "at": (float(label.getAttribute("x")), float(label.getAttribute("y"))),
                "page": typ in pages and box is not None,
            })
        elif stroke == PIN_STROKE:
            kids = [c for c in g.childNodes if c.nodeType == c.ELEMENT_NODE]
            for node, nxt in zip(kids, kids[1:] + [None]):
                if node.tagName != "path" or node.getAttribute("stroke") == "none":
                    continue
                d = node.getAttribute("d")
                m = STUB_RE.match(d)
                if not m:
                    continue
                pin = None
                if nxt is not None and nxt.tagName == "text" and text(nxt):
                    x, y, axis, step = float(m[1]), float(m[2]), m[3], float(m[4])
                    pin = [cur, text(nxt), "in" if axis == "v" or step > 0 else "out", x, y]
                elems.append(Elem(polylines(d), node, "stub", pin, bus))
        elif stroke == TAP_STROKE:
            for node in g.getElementsByTagName("path"):
                d = node.getAttribute("d")
                m = TRIANGLE_RE.match(d)
                if m:
                    x, y, dx = map(float, m.groups())
                    joints.append((min(x, x + dx) - 2, y - 2, max(x, x + dx) + 2, y + 12))
                elif DIAGONAL_RE.match(d):
                    elems.append(Elem(polylines(d), node, "tap", None, bus))
        elif stroke in WIRE_STROKES:
            for node in g.getElementsByTagName("path"):
                d = node.getAttribute("d")
                if not JUNCTION_RE.match(d):
                    elems.append(Elem(polylines(d), node, "wire", None, bus))
    return insts, elems, joints, frame_labels


def connect(elems, joints):
    """Union touching elements into nets, tag their paths with data-n and return the nets."""
    parent = list(range(len(elems)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    at_vertex, horiz, vert = defaultdict(list), defaultdict(list), defaultdict(list)
    for i, e in enumerate(elems):
        for pts in e.lines:
            if e.kind == "tap":  # ripper diagonal: only its slice-side start joins
                at_vertex[pts[0]].append(i)
                continue
            for p in pts:
                at_vertex[p].append(i)
            for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
                if y0 == y1:
                    horiz[y0].append((min(x0, x1), max(x0, x1), i))
                elif x0 == x1:
                    vert[x0].append((min(y0, y1), max(y0, y1), i))

    def touching(x, y):
        yield from at_vertex.get((x, y), ())
        yield from (j for lo, hi, j in horiz.get(y, ()) if lo < x < hi)
        yield from (j for lo, hi, j in vert.get(x, ()) if lo < y < hi)

    def under_joint(x, y):
        return any(x0 <= x <= x1 and y0 <= y <= y1 for x0, y0, x1, y1 in joints)

    taps = []  # element pairs joined only through a ripper / bundle joint
    for i, e in enumerate(elems):
        for pts in e.lines:
            if e.kind == "tap":
                for j in touching(*pts[0]):
                    parent[find(j)] = find(i)
                taps += [(i, j) for j in touching(*pts[-1]) if elems[j].kind != "tap"]
                continue
            for x, y in (pts[0], pts[-1]):
                joint = under_joint(x, y)
                for j in touching(x, y):
                    if joint:
                        taps.append((i, j))
                    else:
                        parent[find(j)] = find(i)

    members_of = defaultdict(list)
    for i in range(len(elems)):
        members_of[find(i)].append(i)
    nets, net_of = [], {}
    for members in members_of.values():
        if all(elems[i].kind == "stub" for i in members):
            continue  # stubs only: unconnected pin or a port with nothing inside
        nid = len(nets)
        nets.append({
            "bus": any(elems[i].bus for i in members),
            "pins": [elems[i].pin for i in members if elems[i].pin],
        })
        for i in members:
            elems[i].node.setAttribute("data-n", str(nid))
            net_of[i] = nid
    for i, j in taps:
        a, b = net_of.get(i), net_of.get(j)
        if a is not None and b is not None and a != b:
            for x, y in ((a, b), (b, a)):
                lst = nets[x].setdefault("taps", [])
                if y not in lst:
                    lst.append(y)
    return nets


def frame_chain(minus, frame_labels):
    """[[instance, module], ...] outermost first, and the "−" icons that go back up.

    Frames carry instance names on top (outer → inner) and module names at the bottom
    (inner → outer).
    """
    n = len(minus)
    if not n or len(frame_labels) != 2 * n:
        return [], []
    labels = [t for _, t in sorted(frame_labels)]
    chain = [[i, m] for i, m in zip(labels[:n], labels[n:][::-1])]
    ups = [
        {"at": [x, y], "to": chain[k - 1][1] if k else TOP, "frame": chain[k][0]}
        for k, (x, y) in enumerate(minus)
    ]
    return chain, ups


def parse(svg_path, pages):
    doc = minidom.parse(str(svg_path))
    root = doc.getElementsByTagName("g")[0]
    groups = [n for n in root.childNodes if n.nodeType == n.ELEMENT_NODE and n.tagName == "g"]
    minus = frame_icons(groups)
    insts, elems, joints, frame_labels = classify(doc, groups, minus, pages)
    nets = connect(elems, joints)
    chain, ups = frame_chain(minus, frame_labels)
    return doc, insts, nets, chain, ups


def parse_utilization():
    """utilization_hier.rpt -> ({instance path: row}, meta); ({}, None) if the reports are missing."""
    hier, summ = SVG_DIR / "utilization_hier.rpt", SVG_DIR / "utilization.rpt"
    if not hier.exists():
        return {}, None
    meta = {"tool": "", "part": "", "device": {}}
    rows, stack = {}, []
    for line in hier.read_text(encoding="utf-8").splitlines():
        if line.startswith("| Tool Version"):
            meta["tool"] = re.search(r"v\.(\S+)", line)[1]
        elif line.startswith("| Device"):
            meta["part"] = line.split(":", 1)[1].strip()
        if not line.startswith("|") or line.count("|") < 11:
            continue
        cells = line.split("|")[1:-1]
        name, module = cells[0], cells[1].strip()
        try:
            lut, _logic, _lutram, _srl, ff, b36, b18, dsp = (float(c) for c in cells[2:10])
        except ValueError:
            continue  # header row
        depth = (len(name) - len(name.lstrip()) - 1) // 2
        name = name.strip()
        row = {
            "lut": int(lut),
            "ff": int(ff),
            "bram": b36 + b18 / 2,
            "dsp": int(dsp),
            "module": module.strip("()") if module != "(top)" else TOP,
        }
        if name.startswith("("):  # logic of the parent itself, outside its child instances
            rows["/".join(stack[:depth])]["own"] = row
            continue
        del stack[depth:]
        stack.append(name)
        path = "/".join(stack)
        rows[path] = dict(row, children=[])
        if depth:
            rows["/".join(stack[:-1])]["children"].append(path)
    if summ.exists():
        keys = {"Slice Registers": "ff", "Block RAM Tile": "bram", "DSPs": "dsp"}
        for line in summ.read_text(encoding="utf-8").splitlines():
            m = re.match(
                r"\|\s*(Slice LUTs\*?|Slice Registers|Block RAM Tile|DSPs)\s*\|.*?\|"
                r"\s*([\d.]+)\s*\|\s*[\d.]+\s*\|\s*$",
                line,
            )
            if m:
                meta["device"][keys.get(m[1], "lut")] = float(m[2])
    return rows, meta


def pick(row):
    return {k: row[k] for k in UTIL_FIELDS}


def util_for(chain, rows, meta):
    """Utilization of the instance a page was exported from (path from its frames)."""
    path = "/".join(["SOC"] + [inst for inst, _ in chain])
    r = rows.get(path)
    if not r:
        return None
    kids = [
        dict(pick(rows[c]), inst=c.rsplit("/", 1)[1], module=rows[c]["module"])
        for c in r["children"]
    ]
    kids.sort(key=lambda k: (-k["lut"], -k["ff"]))
    # everything not in a listed child: the sheet's own logic plus children synthesis merged away
    own = {k: v - sum(c[k] for c in kids) for k, v in pick(r).items()}
    return {
        "path": path,
        "part": meta["part"],
        "tool": meta["tool"],
        "device": meta["device"],
        "total": pick(r),
        "own": own,
        "children": kids,
    }


def git_hash():
    try:
        return subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=DOCS, check=True, capture_output=True, text=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    shutil.copytree(SITE_DIR, OUT)

    svgs = sorted(SVG_DIR.glob("*.svg"))
    pages = {p.stem for p in svgs}
    date, commit = datetime.now().strftime("%Y-%m-%d"), git_hash()
    util_rows, util_meta = parse_utilization()
    if not util_rows:
        print("note: no utilization_hier.rpt, pages get no synthesis statistics")
    modules = {}
    for svg in svgs:
        module = svg.stem
        doc, insts, nets, chain, ups = parse(svg, pages)
        svg_el = doc.documentElement
        svg_el.setAttribute("id", "schem")
        data = {
            "module": module,
            "insts": insts,
            "nets": nets,
            "chain": chain,
            "ups": ups,
            "util": util_for(chain, util_rows, util_meta),
        }
        (OUT / f"{module}.html").write_text(
            PAGE.substitute(
                module=module,
                svg=svg_el.toxml().replace(' cursor="crosshair"', ""),
                data=json.dumps(data, separators=(",", ":")).replace("</", "<\\/"),
                date=date,
                hash=commit,
                repo=REPO_URL,
            ),
            encoding="utf-8",
        )
        modules[module] = [[i["name"], i["type"]] for i in insts if i["page"]]
        if module != TOP and not chain:
            print(f"warning: no instance path found in {svg.name}")
        print(f"{module:40s} {len(insts):4d} cells {len(nets):5d} nets")

    util = None
    if util_rows:
        util = {"meta": util_meta, "rows": {k: pick(v) for k, v in util_rows.items()}}
    index = {"top": TOP, "commit": commit, "date": date, "modules": modules, "util": util}
    (OUT / "modules.js").write_text(
        f"window.SCHEM_MODULES = {json.dumps(index, indent=1)};\n", encoding="utf-8"
    )
    print(f"Wrote {len(svgs)} schematic pages to {OUT}")


if __name__ == "__main__":
    main()
