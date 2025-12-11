from pathlib import Path
import os
from string import Template
from io import StringIO
from xml.dom import minidom
import re

OUTPUT_PATH = Path("schematic_html")
SVG_PATH = Path("schematic_svgs")

HTML_TEMPLATE = Template(
    """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$title</title>
    <style>
        svg {
            width: 100%;
            height: 100%;
        }
        rect[onclick] {
            cursor: pointer;
        }
        rect[onclick]:hover {
            fill: rgba(0, 255, 0, 0.7);
        }
        </style>
        <script src="https://cdn.jsdelivr.net/npm/svg-pan-zoom@3.5.0/dist/svg-pan-zoom.min.js"></script>
</head>
<body style="margin:0; padding:0; width:100vw; height:100vh;">
    $svg_content
<script>
    var svgElement = document.querySelector('svg');
    var panZoomTiger = svgPanZoom(svgElement, {
        dblClickZoomEnabled:false
    });
    window.onmousedown = (e) => {
        if (e.button === 1 || e.button === 0) {
            panZoomTiger.enablePan();
        }else{
            panZoomTiger.disablePan();
        }
    };
</script>
</body>
</html>
"""
)


def create_rect_on_path(doc: minidom.Document, d: str, href: str) -> minidom.Element:
    rect = doc.createElement("rect")
    rect.setAttribute("x", d.split(" ")[0].removeprefix("M"))
    rect.setAttribute("y", d.split(" ")[1].split("h")[0])
    rect.setAttribute("width", "15")
    rect.setAttribute("height", "15")
    rect.setAttribute("fill", "transparent")
    rect.setAttribute("stroke", "green")
    rect.setAttribute("onclick", f"location.href='{href}'")
    return rect


if __name__ == "__main__":
    OUTPUT_PATH.mkdir(parents=True, exist_ok=True)
    svg_list: list[tuple[str, list]] = [((SVG_PATH / "TOP.svg").as_posix(), [])]
    exported = set()

    for svg, p in svg_list:
        doc = minidom.parse(svg)
        groups = doc.getElementsByTagName("g")[0].getElementsByTagName("g")
        parents_done = set()
        parents = p + [svg.split(os.sep)[-1].replace(".svg", "")]
        for g in groups:
            texts = g.getElementsByTagName("text")
            module_name = None
            for text in texts:
                name = text.firstChild.nodeValue

                if (
                    name is None
                    or "[" in name
                    or "]" in name
                    or not (SVG_PATH / f"{name}.svg").exists()
                ):
                    continue

                if name in parents:
                    if name not in parents_done:
                        print("  Detected circular reference to", name)
                        pi = parents.index(name)
                        rect = create_rect_on_path(
                            doc,
                            g.getElementsByTagName("path")[0].getAttribute("d"),
                            parents[pi - 1] + ".html",
                        )
                        g.appendChild(rect)
                        parents_done.add(name)
                    continue

                if name in exported:
                    continue

                exported.add(name)

                g.appendChild(
                    create_rect_on_path(
                        doc,
                        g.getElementsByTagName("path")[0].getAttribute("d"),
                        f"{name}.html",
                    )
                )
                svg_list.append(
                    ((SVG_PATH / f"{name}.svg").as_posix(), parents + [name])
                )
                break

        string_ostream = StringIO()
        doc.writexml(string_ostream, encoding="utf-8")
        svg_content = string_ostream.getvalue().replace('cursor="crosshair"', "")
        # svg_content = re.sub(r'viewBox="[\d\s]+"', "", svg_content).strip()
        title = svg.split(os.sep)[-1].replace(".svg", "")
        html_content = HTML_TEMPLATE.substitute(title=title, svg_content=svg_content)
        output_file = OUTPUT_PATH / f"{title}.html"
        with open(output_file, "w", encoding="utf-8") as f:
            f.write(html_content)
        print(f"Generated {output_file}")
