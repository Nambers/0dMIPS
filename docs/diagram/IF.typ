#import "@preview/cetz:0.4.2": draw
#import "circuiteria/src/lib.typ": *

#let IFStage(
  x: none,
  y: none,
) = {
  element.group(
    id: "IFStage",
    name: "IFStage",
    padding: 1em,
    stroke: (dash: "dashed"),
    {
      element.block(
        x: x + 6,
        y: y,
        w: 2,
        h: 10,
        id: "IFReg",
        ports: (
          west: ((id: "fetch_pc"), (id: "fetch_pc4")),
          east: ((id: "out_fetch_pc"), (id: "out_fetch_pc4")),
        ),
        name: text("IF REG", size: 0.8em),
        fill: util.colors.blue,
      )

      element.multiplexer(
        x: (rel: -4, to: "IFReg.west"),
        y: (to: "out", from: "IFReg-port-fetch_pc"),
        w: 1.4,
        h: 2.8,
        id: "PCMux",
        name: text("Mux"),
        fill: util.colors.orange,
      )

      element.multiplexer(
        x: (rel: -4, to: "IFReg.west"),
        y: (to: "out", from: "IFReg-port-fetch_pc4"),
        w: 1.4,
        h: 2.8,
        id: "PC4Mux",
        name: text("Mux"),
        fill: util.colors.orange,
      )

      element.alu(
        x: (rel: -7, to: "IFReg.west"),
        y: (to: "out", from: "PC4Mux-port-in1"),
        w: 1.4,
        h: 2.8,
        id: "PCAdd4",
        name: text("+", size: 1.5em),
        name-anchor: "name",
        fill: util.colors.pink,
      )
    },
  )

  // TODO: connect to branch unit
  wire.stub("PCAdd4-port-in2", "west", name: "4")

  wire.wire(
    "PC4Mux-to-IFReg",
    ("PC4Mux-port-out", "IFReg-port-fetch_pc4"),
    name: "fetch_pc4",
    name-pos: "end",
  )
  wire.wire(
    "PCMUX-to-IFReg",
    ("PCMux-port-out", "IFReg-port-fetch_pc"),
    name: "fetch_pc",
    name-pos: "end",
  )
  wire.wire(
    "ALU_PC4-to-PC4Mux",
    ("PCAdd4-port-out", "PC4Mux-port-in1"),
  )
}

// for direct preview

#set page(width: auto, height: auto, margin: .5cm)

#circuit({
  IFStage(x: 0, y: 0)
})

