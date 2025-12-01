#import "@preview/cetz:0.4.2": draw
#import "circuiteria/src/lib.typ": *

#let EXStage(
  x: none,
  y: none,
) = {
  element.group(
    id: "EXStage",
    name: "EXStage",
    padding: 1em,
    stroke: (dash: "dashed"),
    {
      element.block(
        x: x,
        y: y,
        w: 2,
        h: 14,
        id: "EXReg",
        name: text("EX REG", size: 0.8em),
        fill: util.colors.blue,
        ports: (
          west: (
            (id: "out"),
            (id: "B_data"),
            (id: "pc4"),
            (id: "pc_branch"),
            (id: "W_regnum"),
            (id: "cp0_rd"),
            (id: "sel"),
            (id: "mem_load_type"),
            (id: "mem_store_type"),
            (id: "overflow"),
            (id: "zero"),
            (id: "MFC0"),
            (id: "MTC0"),
            (id: "break_"),
            (id: "syscall"),
            (id: "write_enable"),
            (id: "BEQ"),
            (id: "BNE"),
            (id: "BC"),
            (id: "BAL"),
            (id: "signed_mem_out"),
            (id: "lui"),
            (id: "linkpc"),
          ),
        ),
      )
    },
  )
}

// for direct preview

#set page(width: auto, height: auto, margin: .5cm)

#circuit({
  EXStage(x: 0, y: 0)
})

