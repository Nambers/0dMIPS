#import "@preview/cetz:0.4.2": draw
#import "../util.typ"
#import "element.typ"
#import "ports.typ": add-port

#let draw-shape(id, tl, tr, br, bl, fill, stroke) = {
  let f = draw.group(name: id, {
    draw.line(
      tl,
      tr,
      br,
      stroke: stroke,
    )
    draw.anchor("north", (tl, 50%, tr))
    draw.anchor("south", (bl, 50%, br))
    draw.anchor("west", (tl, 50%, bl))
    draw.anchor("east", (tr, 50%, br))
    draw.anchor("north-west", tl)
    draw.anchor("north-east", tr)
    draw.anchor("south-east", br)
    draw.anchor("south-west", bl)
  })

  return (f, tl, tr, br, bl)
}

/// Draws a concatenation block (bit concatenator)
///
/// For other parameters description, see #doc-ref("element.elmt")
/// - entries (int, array): If it is an integer, it defines the number of input ports.
///   If it is an array of strings, it defines the name of each input.
#let concatenation(
  x: none,
  y: none,
  w: none,
  h: none,
  name: none,
  name-anchor: "center",
  entries: 2,
  fill: none,
  stroke: black + 3pt,
  id: "",
  debug: (
    ports: false,
  ),
) = {
  let ports = ()
  let ports-y = (
    out: h => { h * 0.5 },
  )

  if (type(entries) == int) {
    for i in range(entries) {
      ports.push((id: "in" + str(i), name: str(i)))
    }
  } else {
    for (i, port) in entries.enumerate() {
      ports.push((id: "in" + str(i), name: port))
    }
  }

  let space = 100% / ports.len()
  let l = ports.len()
  for (i, port) in ports.enumerate() {
    ports-y.insert(port.id, h => { h * (l - i - 0.5) / l })
  }

  element.elmt(
    draw-shape: draw-shape,
    x: x,
    y: y,
    w: w,
    h: h,
    name: name,
    name-anchor: name-anchor,
    ports: (west: ports, east: ((id: "out"),)),
    fill: fill,
    stroke: stroke,
    id: id,
    ports-y: ports-y,
    auto-ports: false,
    debug: debug,
  )

  for (i, port) in ports.enumerate() {
    let pct = (i + 0.5) * space
    add-port(id, "west", port, (id + ".north-west", pct, id + ".south-west"))
  }
  add-port(id, "east", (id: "out"), (id + ".north-east", 50%, id + ".south-east"))
}
