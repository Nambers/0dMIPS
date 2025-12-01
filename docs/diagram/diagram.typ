#import "@preview/cetz:0.4.2": draw
#import "circuiteria/src/lib.typ": *
#import "IF.typ": IFStage
#import "ID.typ": IDStage
#import "EX.typ": EXStage

#set page(width: auto, height: auto, margin: .5cm)

#circuit({
  element.group(id: "toplvl", name: "CPU", {
    IFStage(
      x: 10,
      y: 0,
    )

    IDStage(
      x: (rel: 4 + 30, to: "IFReg.east"),
      y: 0,
    )

    EXStage(
      x: (rel: 4 + 30, to: "IDReg.east"),
      y: 0,
    )
  })
})
