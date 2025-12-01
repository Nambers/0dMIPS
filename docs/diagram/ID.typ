#import "@preview/cetz:0.4.2": draw
#import "circuiteria/src/lib.typ": *

#let IDStage(
  x: none,
  y: none,
) = {
  element.group(
    id: "IDStage",
    name: "IDStage",
    padding: 1em,
    stroke: (dash: "dashed"),
    {
      element.block(
        x: x,
        y: y,
        w: 3,
        h: 35,
        id: "IDReg",
        name: text("ID REG", size: 0.9em),
        fill: util.colors.blue,
        ports: (
          west: (
            (id: "A_data"),
            (id: "B_data"),
            (id: "W_regnum"),
            (id: "cp0_rd"),
            (id: "shamt"),
            (id: "alu_op"),
            (id: "rd_src"),
            (id: "barrel_plus32"),
            (id: "control_type"),
            (id: "mem_load_type"),
            (id: "mem_store_type"),
            (id: "slt_type"),
            (id: "ext_src"),
            (id: "cut_alu_out32"),
            (id: "alu_a_src"),
            (id: "alu_b_src"),
            (id: "ex_out_src"),
            (id: "cut_barrel_out32"),
            (id: "reserved_inst_E"),
            (id: "write_enable"),
            (id: "barrel_right"),
            (id: "shift_arith"),
            (id: "rotator_src"),
            (id: "barrel_src"),
            (id: "barrel_sa_src"),
            (id: "BEQ"),
            (id: "BNE"),
            (id: "BC"),
            (id: "BAL"),
            (id: "lui"),
            (id: "linkpc"),
            (id: "B_is_reg"),
            (id: "signed_mem_out"),
            (id: "ignore_overflow"),
            (id: "MFC0"),
            (id: "MTC0"),
            (id: "ERET"),
            (id: "break_"),
            (id: "syscall"),
            (id: "inst"),
            (id: "jumpAddr"),
            (id: "pc4"),
            (id: "pc_branch"),
          ),
          east: (
            (id: "pc"),
          ),
        ),
      )

      element.block(
        x: (rel: -25, to: "IDReg.west"),
        y: y + 6,
        w: 1.5,
        h: 25,
        id: "Decoder",
        name: text("Decoder", size: 0.9em),
        fill: util.colors.orange,
        ports: (
          west: (
            (id: "inst"),
          ),
          east: (
            (id: "rd_src"),
            (id: "rs"),
            (id: "rt"),
            (id: "rd"),
            (id: "shamt"),
            (id: "alu_op"),
            (id: "control_type"),
            (id: "mem_store_type"),
            (id: "mem_load_type"),
            (id: "slt_type"),
            (id: "ext_src"),
            (id: "lui"),
            (id: "branchAddr_src"),
            (id: "linkpc"),
            (id: "barrel_right"),
            (id: "shift_arith"),
            (id: "barrel_plus32"),
            (id: "ex_out_src"),
            (id: "alu_a_src"),
            (id: "alu_b_src"),
            (id: "rotator_src"),
            (id: "barrel_src"),
            (id: "barrel_sa_src"),
            (id: "cut_barrel_out32"),
            (id: "cut_alu_out32"),
            (id: "MFC0"),
            (id: "MTC0"),
            (id: "ERET"),
            (id: "break_"),
            (id: "syscall"),
            (id: "BEQ"),
            (id: "BNE"),
            (id: "BC"),
            (id: "BAL"),
            (id: "signed_mem_out"),
            (id: "ignore_overflow"),
            (id: "B_is_reg"),
            (id: "write_enable"),
            (id: "reserved_inst_E"),
          ),
        ),
      )


      element.multiplexer(
        x: (rel: -8, to: "IDReg.west"),
        y: (to: "out", from: "IDReg-port-A_data"),
        w: 2,
        h: 2,
        id: "FwdAMux",
        name: text("FwA", size: 0.8em),
        fill: util.colors.orange,
      )

      element.block(
        x: (rel: -17, to: "IDReg.west"),
        y: (to: "A_data", from: "FwdAMux-port-in0"),
        w: 3,
        h: 5,
        id: "RegFile",
        name: text("regfile", size: 0.9em),
        fill: util.colors.pink,
        ports: (
          north: (
            (id: "clk", clock: true),
          ),
          west: (
            (id: "rs"),
            (id: "rt"),
            (id: "W_regnum"),
            (id: "W_data"),
            (id: "write_enable"),
          ),
          east: (
            (id: "A_data"),
            (id: "B_data"),
          ),
        ),
      )

      element.gate-or(
        id: "BadInstrCond",
        x: (rel: 0, to: "RegFile.west"),
        y: (to: "in1", from: "Decoder-port-break_"),
        w: 2,
        h: 2,
        inputs: 3,
      )

      element.multiplexer(
        x: (rel: -12, to: "IDReg.west"),
        y: (to: "in0", from: "RegFile-port-B_data"),
        w: 2,
        h: 2,
        id: "FwdBMux",
        name: text("FwdB", size: 0.8em),
        fill: util.colors.orange,
      )

      element.multiplexer(
        x: (rel: -8, to: "IDReg.west"),
        y: (to: "in0", from: "FwdBMux-port-out"),
        w: 2,
        h: 2,
        id: "BadInstrBMux",
        name: text("BadB", size: 0.8em),
        fill: util.colors.orange,
        sel-down: true,
      )

      element.multiplexer(
        x: (rel: 0, to: "RegFile.west"),
        entries: 4,
        y: (to: "in0", from: "Decoder-port-rd"),
        w: 2,
        h: 3.2,
        id: "RdMux",
        name: text("RD", size: 0.8em),
        fill: util.colors.orange,
      )

      element.group(
        id: "BranchLogic",
        name: "BranchLogic",
        padding: 1em,
        stroke: (dash: "dashed"),
        {
          element.concatenation(
            x: (rel: 6.5, to: "Decoder.east"),
            y: y + 9,
            w: 1.2,
            h: 2,
            entries: (
              "63:28",
              "27:2",
              "2'b00",
            ),
            id: "JumpAddr",
          )
          element.concatenation(
            x: (rel: 0, to: "JumpAddr.west"),
            y: y + 6,
            w: 1.2,
            h: 2,
            entries: (
              "63:18",
              "17:2",
              "2'b00",
            ),
            id: "BranchAddr",
          )
          element.alu(
            x: (rel: 2.2, to: "JumpAddr.east"),
            y: (from: "BranchAddr-port-out", to: "in1"),
            w: 1,
            h: 2,
            name: text("+", size: 1.5em),
            fill: util.colors.green,
            id: "PC4BranchAddr",
          )
          element.concatenation(
            x: (rel: 0, to: "JumpAddr.west"),
            y: y + 3,
            w: 1.2,
            h: 2,
            entries: (
              "63:21",
              "20:2",
              "2'b00",
            ),
            id: "CompactBranchAddr",
          )
          element.alu(
            x: (rel: 2.2, to: "JumpAddr.east"),
            y: (from: "CompactBranchAddr-port-out", to: "in1"),
            w: 1,
            h: 2,
            name: text("+", size: 1.5em),
            fill: util.colors.green,
            id: "PC4CompactBranchAddr",
          )
          element.concatenation(
            x: (rel: 0, to: "JumpAddr.west"),
            y: y,
            w: 1.2,
            h: 2,
            entries: (
              "63:28",
              "27:2",
              "2'b0",
            ),
            id: "PCRelAddr",
          )
          element.alu(
            x: (rel: 2.2, to: "JumpAddr.east"),
            y: (from: "PCRelAddr-port-out", to: "in1"),
            w: 1,
            h: 2,
            name: text("+", size: 1.5em),
            fill: util.colors.green,
            id: "PCPCRelAddrr",
          )

          element.multiplexer(
            id: "BranchAddrMux",
            entries: 3,
            name: "MUX",
            x: (rel: 6, to: "JumpAddr.east"),
            y: (to: "out", from: "IDReg-port-pc_branch"),
            w: 3,
            h: 3,
            fill: util.colors.orange,
          )
        },
      )
    },
  )

  wire.stub("RegFile-port-clk", "north", name: "clk", length: 1)

  // --- unused decoder ports ---
  let directed_ports = (
    "shamt",
    "alu_op",
    "barrel_plus32",
    "control_type",
    "mem_load_type",
    "mem_store_type",
    "slt_type",
    "ext_src",
    "cut_alu_out32",
    "alu_a_src",
    "alu_b_src",
    "ex_out_src",
    "cut_barrel_out32",
    "write_enable",
    "barrel_right",
    "shift_arith",
    "rotator_src",
    "barrel_src",
    "barrel_sa_src",
    "BEQ",
    "BNE",
    "BC",
    "BAL",
    "lui",
    "linkpc",
    "B_is_reg",
    "signed_mem_out",
    "ignore_overflow",
    "MFC0",
    "MTC0",
    "ERET",
  )
  for port-name in directed_ports {
    let id = "Decoder-to-IDReg-" + port-name
    wire.draw.group(
      name: id,
      {
        draw.line(
          "Decoder-port-" + port-name,
          (horizontal: (rel: (5, 0)), vertical: ()),
          (horizontal: (), vertical: "Decoder-port-ex_out_src"),
          (horizontal: (rel: (13, 0)), vertical: ()),
          (horizontal: (), vertical: "IDReg-port-" + port-name),
          "IDReg-port-" + port-name,
          stroke: (paint: util.colors.blue),
        )
        draw.anchor(
          "start",
          "Decoder-port-" + port-name,
        )
        draw.anchor(
          "end",
          "IDReg-port-" + port-name,
        )
      },
    )
    draw.content(id + ".start", anchor: "south-west", padding: 3pt, port-name)
    draw.content(id + ".end", anchor: "south-east", padding: 3pt, port-name)
  }

  // --- RdMux ---
  wire.stub(
    "RdMux-port-in3",
    "west",
    name: "5'd31",
  )
  wire.wire(
    "RD_src-to-RdMux",
    ("Decoder-port-rd_src", "RdMux-port-sel"),
    style: "zigzag",
    zigzag-ratio: 100%,
    name: "rd_src",
    name-pos: "start",
  )
  wire.wire(
    "RD-to-RdMux",
    ("Decoder-port-rd", "RdMux-port-in0"),
    style: "zigzag",
    name: "rd",
    name-pos: "start",
  )
  wire.wire(
    "RT-to-RdMux",
    ("Decoder-port-rt", "RdMux-port-in1"),
    style: "zigzag",
    zigzag-ratio: 30%,
    name: "rt",
    name-pos: "start",
  )
  wire.wire(
    "RS-to-RdMux",
    ("Decoder-port-rs", "RdMux-port-in2"),
    style: "zigzag",
    zigzag-ratio: 15%,
    name: "rs",
    name-pos: "start",
  )
  wire.wire(
    "RdMux-out-to-IDReg-W",
    ("RdMux-port-out", "IDReg-port-W_regnum"),
    style: "zigzag",
    name: "W_regnum",
    name-pos: "end",
    zigzag-ratio: 80%,
  )

  // --- Decoder ---
  wire.wire(
    "Decoder-to-RegFile-rs",
    ("Decoder-port-rs", "RegFile-port-rs"),
    style: "zigzag",
    zigzag-ratio: 15%,
    name: "rs",
    name-pos: "end",
  )
  wire.intersection("Decoder-to-RegFile-rs.zig")
  wire.wire(
    "Decoder-to-RegFile-rt",
    ("Decoder-port-rt", "RegFile-port-rt"),
    style: "zigzag",
    zigzag-ratio: 30%,
    name: "rt",
    name-pos: "end",
  )
  wire.intersection("Decoder-to-RegFile-rt.zig")
  wire.wire(
    "RegFile-to-FwdA",
    ("RegFile-port-A_data", "FwdAMux-port-in0"),
    style: "zigzag",
    name: "A_data",
    name-pos: "start",
  )

  // --- RegFile ---
  wire.wire(
    "RegFile-to-FwdB",
    ("RegFile-port-B_data", "FwdBMux-port-in0"),
    style: "zigzag",
    name: "B_data",
    name-pos: "start",
  )

  // --- Fwd ---
  wire.wire(
    "FwdA-to-IDReg-A_data",
    ("FwdAMux-port-out", "IDReg-port-A_data"),
    style: "zigzag",
    name: "A_data",
    name-pos: "end",
  )
  wire.wire(
    "FwdB-to-BadInstr",
    ("FwdBMux-port-out", "BadInstrBMux-port-in0"),
    style: "zigzag",
  )
  wire.wire(
    "BadInstr-to-IDReg-B_data",
    ("BadInstrBMux-port-out", "IDReg-port-B_data"),
    style: "zigzag",
    name: "B_data",
    name-pos: "end",
    zigzag-ratio: 20%,
  )
  wire.wire(
    "AData-to-FwdA",
    ("RegFile-port-A_data", "FwdAMux-port-in0"),
    style: "zigzag",
  )

  // --- Branch Logic ---
  wire.wire(
    "BranchAddrSrc-to-BranchAddrMux",
    ("Decoder-port-branchAddr_src", "BranchAddrMux-port-sel"),
    style: "zigzag",
    zigzag-ratio: 100%,
    name: "branchAddr_src",
    name-pos: "start",
  )
  wire.wire(
    "JumpAddr-to-IDReg",
    ("JumpAddr-port-out", "IDReg-port-jumpAddr"),
    style: "zigzag",
    name: "jumpAddr",
    name-pos: "end",
    zigzag-ratio: 90%,
  )
  wire.wire(
    "BranchAddr-to-alu",
    ("BranchAddr-port-out", "PC4BranchAddr-port-in1"),
    style: "zigzag",
  )
  wire.wire(
    "CompactBranchAddr-to-alu",
    ("CompactBranchAddr-port-out", "PC4CompactBranchAddr-port-in1"),
    style: "zigzag",
  )
  wire.wire(
    "PCRelAddr-to-alu",
    ("PCRelAddr-port-out", "PCPCRelAddrr-port-in1"),
    style: "zigzag",
  )
  wire.wire(
    "PC4BranchAddr-to-BranchAddrMux",
    ("PC4BranchAddr-port-out", "BranchAddrMux-port-in0"),
    style: "zigzag",
    zigzag-ratio: 90%,
  )
  wire.wire(
    "PC4CompactBranchAddr-to-BranchAddrMux",
    ("PC4CompactBranchAddr-port-out", "BranchAddrMux-port-in1"),
    style: "zigzag",
    zigzag-ratio: 70%,
  )
  wire.wire(
    "PCPCRelAddr-to-BranchAddrMux",
    ("PCPCRelAddrr-port-out", "BranchAddrMux-port-in2"),
    style: "zigzag",
    zigzag-ratio: 50%,
  )
  wire.wire(
    "BranchAddrMux-to-IDReg-pc_branch",
    ("BranchAddrMux-port-out", "IDReg-port-pc_branch"),
    style: "zigzag",
    name: "pc_branch",
    name-pos: "end",
    zigzag-ratio: 90%,
  )
  wire.wire(
    "ORGate-to-BadInstrBMux",
    ("BadInstrCond-port-out", "BadInstrBMux-port-sel"),
    style: "zigzag",
    zigzag-ratio: 100%,
  )
  wire.wire(
    "Decoder-to-ORGate-1",
    ("Decoder-port-reserved_inst_E", "BadInstrCond-port-in2"),
    style: "zigzag",
    name: "reserved_inst_E",
    name-pos: "start",
    zigzag-ratio: 70%,
  )
  wire.wire(
    "Decoder-to-ORGate-2",
    ("Decoder-port-syscall", "BadInstrCond-port-in1"),
    style: "zigzag",
    name: "syscall",
    name-pos: "start",
    zigzag-ratio: 70%,
  )
  wire.wire(
    "Decoder-to-ORGate-3",
    ("Decoder-port-break_", "BadInstrCond-port-in0"),
    style: "zigzag",
    name: "break",
    name-pos: "start",
    zigzag-ratio: 70%,
  )

  // --- IFReg ---
  wire.wire(
    "IFReg-to-JumpAddr",
    bus: true,
    ("IFReg-port-out_fetch_pc", "JumpAddr-port-in0"),
    style: "zigzag",
    zigzag-ratio: 80%,
    name: [pc[63, 28]],
    name-pos: "end",
  )
  wire.wire(
    "IFReg-to-BranchAddr-alu",
    ("IFReg-port-out_fetch_pc4", "PC4BranchAddr-port-in2"),
    style: "zigzag",
    zigzag-ratio: 95%,
    name: "fetch_pc4",
    name-pos: "end",
  )
  wire.wire(
    "IFReg-to-CompactBranchAddr-alu",
    ("IFReg-port-out_fetch_pc4", "PC4CompactBranchAddr-port-in2"),
    style: "zigzag",
    zigzag-ratio: 95%,
    name: ("fetch_pc4", "fetch_pc4"),
  )
  wire.intersection("IFReg-to-CompactBranchAddr-alu.zag")
  wire.wire(
    "IFReg-to-PCRelAddr-alu",
    ("IFReg-port-out_fetch_pc", "PCPCRelAddrr-port-in2"),
    style: "zigzag",
    zigzag-ratio: 90%,
    name: ("fetch_pc", "fetch_pc"),
  )
}

// for direct preview

#set page(width: auto, height: auto, margin: .5cm)

#circuit({
  // IFReg placeholder
  element.block(
    x: -30,
    y: -5,
    w: 1,
    h: 1,
    id: "IFReg",
    fill: util.colors.pink,
    ports: (
      east: (
        (id: "out_fetch_pc"),
        (id: "out_fetch_pc4"),
      ),
    ),
  )
  IDStage(x: 0, y: 0)
})
