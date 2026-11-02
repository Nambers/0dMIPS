#!/usr/bin/env python3
"""Build docs/site/index.html: the concept drawing (draw.py) and its scenes.

The drawing is hand-placed, so when the pipeline changes, edit draw.py / SCENES below and
re-run:  python docs/concept/build.py
docs/gen_export_schematics_site.py then copies docs/site/ into the GitHub Pages output.
"""

import json
import subprocess
import sys
from datetime import date
from html import escape
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.dont_write_bytecode = True  # keep docs/ free of __pycache__
sys.path.insert(0, str(HERE))
import draw  # noqa: E402

# id, group, button label, colour token, title, text, steps.
# Steps are (tag, text). Mechanism scenes tag steps with the cycle they happen in, relative to
# the event the scene follows (c0, c+1 ...), or with letters when the points are simultaneous;
# the drawing's markers (draw.STEPS) carry the same tags. Instruction scenes list one step per
# cycle, c0 = the cycle the instruction sits in IF1.
SCENES = [
    (
        "overview",
        "how",
        "Overview",
        "ink",
        "Six pipeline registers, write-back folded into decode",
        "An instruction spends one cycle in each register: IF1 → IF_regs → ID_regs → EX_regs → MEM1 → MEM_regs. "
        "Fetch and memory each take two cycles, and the register file is written while a younger instruction decodes. "
        "Pick a topic or an instruction to light up only the parts it uses; hover anything for details, click a card to open its Vivado schematic.",
        [],
    ),
    (
        "fetch",
        "how",
        "Fetch & predict",
        "ctrl",
        "Fetch takes two cycles and guesses the next PC",
        "Cycles are counted from the cycle the instruction's PC sits in IF1 (c0).",
        [
            (
                "c−1",
                "Next PC picks the address (the prediction, unless something redirects fetch); it is latched into IF1 at the clock edge.",
            ),
            (
                "c0",
                "IF1 holds fetch_pc: the I-cache and the BHT/BTB are read, and the prediction goes straight back to Next PC as the address of the following fetch.",
            ),
            (
                "c+1",
                "The I-cache's output register is IF_regs.inst, so the decoder sees the instruction one cycle after the lookup.",
            ),
        ],
    ),
    (
        "fwd",
        "how",
        "Forwarding",
        "fwd",
        "Three forwarding sources, youngest wins",
        "All of this happens in one cycle: the one in which the consumer sits in ID_regs and executes.",
        [
            (
                "A",
                "The forwarding unit compares ID_regs rs/rt with the destination registers held in EX_regs, MEM1 and MEM_regs.",
            ),
            (
                "B",
                "EX_regs.out: the instruction one ahead. Not for loads, whose data does not exist yet.",
            ),
            (
                "C",
                "MEM1 result: two ahead, an EX result. Not a load, and MFC0 counts as a load, so a CP0 read comes from MEM_regs after a stall.",
            ),
            (
                "D",
                "MEM_regs.W_data: three ahead, the value being written back right now, loads included.",
            ),
        ],
    ),
    (
        "stall",
        "how",
        "Load-use stall",
        "hazard",
        "A load's data arrives late, so its consumer waits",
        "c0 is the cycle in which the consumer sits in IF_regs and the load just ahead of it in ID_regs.",
        [
            (
                "c0",
                "The hazard unit sees IF_regs read a register the load will write: IF1 and IF_regs hold, ID_regs gets a bubble.",
            ),
            (
                "c+1",
                "The load is in EX_regs and its data still does not exist: a second bubble.",
            ),
            (
                "c+2",
                "The load is in MEM1 and the consumer decodes; one cycle later it executes with the load data forwarded from MEM_regs.",
            ),
            (
                "also",
                "A not-ready MMIO access also inserts a bubble. A D-cache miss instead freezes IF, ID and EX until the line arrives, while MEM1 and MEM2 keep clocking. Only an exception redirects during the freeze; ERET, a mispredict or a jump in ID_regs waits until it ends.",
            ),
        ],
    ),
    (
        "branch",
        "how",
        "Branch & flush",
        "branch",
        "Branches are checked late and flushed on a miss",
        "There are no delay slots. c0 is the cycle the branch or jump sits in IF1.",
        [
            (
                "c0",
                "The predictor guesses while the branch is fetched; fetch follows the guess, which rides along as predicted_npc next to pc_branch.",
            ),
            (
                "c+2",
                "Jumps (J, JAL, JR, JALR, and BAL, which the decoder also marks as a jump) redirect from ID_regs; the two younger instructions are flushed.",
            ),
            (
                "c+3",
                "A conditional branch is checked from EX_regs: on a mismatch with predicted_npc, Next PC redirects and flush clears the three younger instructions, except a JAL/JALR/BAL entering EX, which is kept so it can write its link register. The predictor is trained in the same cycle.",
            ),
        ],
    ),
    (
        "exc",
        "how",
        "Exceptions",
        "exc",
        "CP0 decides in MEM1, fetch jumps two cycles later",
        "c0 is the cycle the faulting instruction sits in EX_regs.",
        [
            (
                "c0",
                "CP0 sees overflow, SYSCALL or BREAK from EX_regs (a reserved instruction from ID_regs) and takes the exception if EXL is clear. EPC = ID_regs.pc: for overflow, SYSCALL and BREAK that is the next instruction (handlers must not add 4); a reserved instruction is caught while it is itself in ID_regs, so EPC is its own PC.",
            ),
            (
                "c+1",
                "takenHandler sits in MEM1. The EPC register already holds the new value; the copy that rides MEM1 and MEM_regs is one cycle behind.",
            ),
            (
                "c+2",
                "takenHandler reaches MEM_regs: Next PC jumps to the handler at 0x0 and flushes IF_regs, ID_regs and EX_regs. The faulting instruction and the two behind it are already past EX and still complete. The handler is fetched from c+3.",
            ),
            (
                "ERET",
                "ERET returns differently: it redirects from ID_regs like a jump, to MEM_regs.EPC, which is the EPC register as it was two cycles earlier.",
            ),
        ],
    ),
    (
        "wb",
        "how",
        "Write-back",
        "ink",
        "Write-back happens in the decode stage",
        "There is no separate WB hardware. c0 is the cycle the instruction sits in MEM1.",
        [
            (
                "c0",
                "MEM2 picks the value: ALU result, load data, MMIO data, CP0 read or pc + 4 for JAL/BAL/JALR.",
            ),
            (
                "c+1",
                "MEM_regs drives the register-file write port while a younger instruction decodes; a same-cycle read sees the new value, and EX gets it by forwarding.",
            ),
        ],
    ),
    (
        "mem",
        "how",
        "Memory & MMIO",
        "mem",
        "Two L1 caches share one bus; peripherals skip the cache",
        "Everything below 0x2000_0000 is cached; peripherals are memory-mapped above it.",
        [
            (
                "A",
                "The D-cache is addressed by EX_regs in MEM1; its registered read comes out in MEM2.",
            ),
            (
                "B",
                "A miss fills a 64-byte line through the cache arbiter, which the I-cache shares.",
            ),
            (
                "C",
                "Addresses ≥ 0x2000_0000 skip the cache and use the d_* port (timer, LED, simulated stdout).",
            ),
            (
                "D",
                "MMIO read data comes back while the access is still in EX_regs and goes straight into the MEM2 select, without passing the MEM1 register.",
            ),
        ],
    ),
    (
        "i-alu",
        "insn",
        "daddu",
        "ink",
        "daddu $3, $1, $2",
        "Encoding 0x0022182D at pc 0x100, with $1 = 5 and $2 = 7. One card per cycle; the marker on the drawing shows which register holds the instruction.",
        [
            (
                "c0",
                "IF1 · fetch: 0x100 is looked up in the I-cache; no BTB entry, so the next fetch is 0x104.",
            ),
            (
                "c1",
                "IF_regs · decode: rs 1, rt 2, rd 3, alu_op add, alu_b_src register, write_enable 1. Reads $1 = 5, $2 = 7.",
            ),
            (
                "c2",
                "ID_regs · execute: nothing to forward; the ALU computes 5 + 7 = 12.",
            ),
            ("c3", "EX_regs · MEM1: out = 12; no memory access."),
            ("c4", "MEM1 · MEM2: the select picks the ALU result, W_data = 12."),
            (
                "c5",
                "MEM_regs · write-back: $3 ← 12, written while a younger instruction decodes.",
            ),
        ],
    ),
    (
        "i-ld",
        "insn",
        "ld",
        "ink",
        "ld $4, 8($1)",
        "Encoding 0xDC240008 at pc 0x104, with $1 = 0x100 and 0x1234 stored at 0x108.",
        [
            ("c0", "IF1 · fetch: 0x104."),
            (
                "c1",
                "IF_regs · decode: rs 1, rt 4 is the destination, imm 8, alu_b_src sign-extended imm, mem_load_type doubleword. Reads $1 = 0x100.",
            ),
            (
                "c2",
                "ID_regs · execute: the ALU computes 0x100 + 8 = 0x108. An instruction right behind that reads $4 is held in IF_regs.",
            ),
            (
                "c3",
                "EX_regs · MEM1: 0x108 is below 0x2000_0000, so the D-cache is read (a hit).",
            ),
            ("c4", "MEM1 · MEM2: the D-cache data 0x1234 becomes W_data."),
            (
                "c5",
                "MEM_regs · write-back: $4 ← 0x1234, also forwarded to the instruction that waited.",
            ),
        ],
    ),
    (
        "i-sd",
        "insn",
        "sd",
        "ink",
        "sd $2, 16($1)",
        "Encoding 0xFC220010 at pc 0x108, with $1 = 0x100 and $2 = 7.",
        [
            ("c0", "IF1 · fetch: 0x108."),
            (
                "c1",
                "IF_regs · decode: rs 1, rt 2 is the store data, imm 16, alu_b_src sign-extended imm, mem_store_type doubleword, write_enable 0.",
            ),
            (
                "c2",
                "ID_regs · execute: the ALU computes 0x100 + 16 = 0x110; B = 7 rides along as store data.",
            ),
            (
                "c3",
                "EX_regs · MEM1: the D-cache writes 7 at 0x110 and marks the line dirty.",
            ),
            ("c4", "MEM1 · MEM2: nothing to select."),
            ("c5", "MEM_regs: write_enable is 0, no register is written."),
        ],
    ),
    (
        "i-beq",
        "insn",
        "beq",
        "ink",
        "beq $1, $2, +12",
        "Encoding 0x10220003 at pc 0x120, with $1 = $2 = 5 and a predictor that has never seen this branch.",
        [
            (
                "c0",
                "IF1 · fetch: 0x120. No BTB entry, so the guess is not taken: the next fetch is 0x124.",
            ),
            (
                "c1",
                "IF_regs · decode: BEQ, pc_branch = 0x124 + 3·4 = 0x130. Reads $1 = 5, $2 = 5.",
            ),
            ("c2", "ID_regs · execute: A == B, so zero = 1."),
            (
                "c3",
                "EX_regs · branch check: taken, so the next PC should be 0x130, not the predicted 0x124. Next PC redirects to 0x130 and flushes 0x124, 0x128 and 0x12C; the BHT/BTB learn the branch.",
            ),
            ("c4", "MEM1 · MEM2: nothing to select."),
            ("c5", "MEM_regs: nothing is written."),
        ],
    ),
    (
        "i-jal",
        "insn",
        "jal",
        "ink",
        "jal 0x200",
        "Encoding 0x0C000080 at pc 0x140.",
        [
            ("c0", "IF1 · fetch: 0x140; the predicted next fetch is 0x144."),
            (
                "c1",
                "IF_regs · decode: J type, jumpAddr = {pc[63:28], 0x80 << 2} = 0x200, rd = 31, linkpc 1.",
            ),
            (
                "c2",
                "ID_regs: Next PC redirects to 0x200 and flushes 0x144 and 0x148; the JAL itself keeps going because it links.",
            ),
            ("c3", "EX_regs · MEM1: carries pc4 = 0x144."),
            ("c4", "MEM1 · MEM2: linkpc selects pc + 4, W_data = 0x144."),
            ("c5", "MEM_regs · write-back: $31 ← 0x144."),
        ],
    ),
]


def scene_buttons(group):
    rows = []
    for sid, g, label, color, *_ in SCENES:
        if g == group:
            cls = ' class="m"' if g == "insn" else ""
            rows.append(
                f'<button type="button"{cls} data-scene="{sid}" style="--c: var(--{color})" aria-pressed="false">{escape(label)}</button>'
            )
    return "\n".join(rows)


scenes_json = json.dumps(
    {
        sid: {"title": t, "text": x, "steps": st, "label": label}
        for sid, _g, label, _c, t, x, st in SCENES
    },
    ensure_ascii=False,
).replace("</", "<\\/")
commit = (
    subprocess.run(
        ["git", "rev-parse", "--short", "HEAD"],
        cwd=REPO,
        capture_output=True,
        text=True,
    ).stdout.strip()
    or "unknown"
)
html = (HERE / "template.html").read_text()
for key, val in (
    ("__SVG__", draw.svg()),
    ("__VIEWBOX__", f"0 0 {draw.W} {draw.H}"),
    ("__HOW__", scene_buttons("how")),
    ("__INSN__", scene_buttons("insn")),
    ("__SCENES__", scenes_json),
    ("__COMMIT__", commit),
    ("__DATE__", date.today().isoformat()),
):
    assert key in html, key
    html = html.replace(key, val)
(REPO / "docs/site/index.html").write_text(html)
print("wrote", len(html), "bytes")
