"""Concept drawing of the 0dMIPS pipeline for docs/site/index.html (built by build.py).

Layout: stage bands left to right, pipeline registers as rails between them, units as
cards. Feedback paths never cut through the datapath: forwarding runs in a channel above
it, write-back / flush / redirects in channels below it.

Every element is a <g> with
  data-layer  one of data ctrl fwd hazard branch exc mem  (the "Show" toggles)
  data-k      the scenes it belongs to (see SCENES in build.py)
  data-tip    tooltip text;  data-mod / data-inst  link into the RTL schematic tab
"""

from html import escape

# Coordinates below are written in a 1280 × 720 design space and stretched piecewise-linearly
# onto the canvas: the crowded strips (forwarding muxes, register file, result and MEM2
# selects, the ALU row, the redirect channels) get extra room, everything else keeps its size.
# Text, pill and marker sizes are not scaled.
XB = [
    (0, 0),
    (404, 404),
    (520, 535),
    (612, 687),
    (692, 767),
    (800, 895),
    (990, 1085),
    (1150, 1270),
    (1280, 1400),
]
YB = [(0, 0), (160, 160), (200, 210), (330, 370), (520, 560), (604, 664), (720, 780)]
W, H = XB[-1][1], YB[-1][1]


def _map(v, bp):
    for (a0, b0), (a1, b1) in zip(bp, bp[1:]):
        if v <= a1:
            return round(b0 + (v - a0) * (b1 - b0) / (a1 - a0), 1)
    return round(bp[-1][1] + v - bp[-1][0], 1)


def X(x):
    return _map(x, XB)


def Y(y):
    return _map(y, YB)


def P(pt):
    return (X(pt[0]), Y(pt[1]))


BANDS = [  # x0, x1, title, subtitle
    (0, 96, "Next PC", "core_branch"),
    (96, 288, "Fetch", "I$ · predictor"),
    (288, 520, "Decode", "RF read · write-back"),
    (520, 800, "Execute", "ALU · shift"),
    (800, 990, "Memory 1", "D$ · MMIO · CP0"),
    (990, 1150, "Memory 2", "pick the result"),
    (1150, 1280, "Write-back", "into the RF in ID"),
]
RAIL_TOP, RAIL_BOT = 158, 474
ALL_I = "i-alu i-ld i-sd i-beq i-jal"
out = []


def esc(s):
    return escape(s, quote=True)


def grp(layer, inner, k="", tip=None, mod=None, inst=None, cls=None):
    a = f' data-layer="{layer}"'
    if cls:
        a += f' class="{cls}"'
    if k:
        a += f' data-k="{k}"'
    if tip:
        a += f' data-tip="{esc(tip)}"'
    if mod:
        a += f' data-mod="{mod}" tabindex="0" role="link"'
        if inst:
            a += f' data-inst="{inst}"'
    out.append(f"<g{a}>{inner}</g>")


def TM(x, y, s, cls, anchor=None):
    """Text at a design-space position."""
    return T(X(x), Y(y), s, cls, anchor)


def T(x, y, s, cls, anchor=None):
    a = f' text-anchor="{anchor}"' if anchor else ""
    return f'<text class="{cls}" x="{x}" y="{y}"{a}>{esc(s)}</text>'


def rpath(pts, hops=(), r=7):
    """Orthogonal polyline with rounded corners; hops = points on horizontal segments
    where this line jumps over another one."""
    d = f"M{pts[0][0]} {pts[0][1]}"
    for i in range(1, len(pts)):
        a, b = pts[i - 1], pts[i]
        if a[1] == b[1]:  # horizontal: draw hops that lie on it
            sx = 1 if b[0] > a[0] else -1
            for hx, hy in sorted(
                (
                    h
                    for h in hops
                    if h[1] == a[1] and min(a[0], b[0]) < h[0] < max(a[0], b[0])
                ),
                key=lambda h: h[0] * sx,
            ):
                d += f"L{hx - 5 * sx} {hy}A5 5 0 0 {1 if sx > 0 else 0} {hx + 5 * sx} {hy}"
        if i == len(pts) - 1:
            d += f"L{b[0]} {b[1]}"
            break
        c = pts[i + 1]
        l1 = abs(b[0] - a[0]) + abs(b[1] - a[1])
        l2 = abs(c[0] - b[0]) + abs(c[1] - b[1])
        rr = min(r, l1 / 2, l2 / 2)

        def toward(p, q, dist):
            dx = (q[0] > p[0]) - (q[0] < p[0])
            dy = (q[1] > p[1]) - (q[1] < p[1])
            return (p[0] + dx * dist, p[1] + dy * dist)

        p1 = toward(b, a, rr)
        p2 = toward(b, c, rr)
        d += f"L{p1[0]} {p1[1]}Q{b[0]} {b[1]} {p2[0]} {p2[1]}"
    return d


def lane(
    layer,
    pts,
    label=None,
    at=None,
    k="",
    dash=False,
    arrow=True,
    dots=(),
    hops=(),
    tip=None,
    anchor=None,
    cls="",
):
    c = (
        "ln"
        + (" dash" if dash else "")
        + (" ar" if arrow else "")
        + (f" {cls}" if cls else "")
    )
    pts, hops, dots = [P(q) for q in pts], [P(q) for q in hops], [P(q) for q in dots]
    at = P(at) if at else at
    s = f'<path class="{c}" d="{rpath(pts, hops)}"/>'
    for x, y in dots:
        s += f'<circle class="dot" cx="{x}" cy="{y}" r="3"/>'
    if label:
        x, y = at
        s += T(x, y, label, "lbl", anchor)
    grp(layer, s, k=k, tip=tip)


def card(
    layer,
    x,
    y,
    w,
    h,
    title,
    sub=None,
    k="",
    mod=None,
    inst=None,
    tip=None,
    extra="",
    ty=None,
    sub2=None,
):
    cls = "card" if layer == "data" else "card unit"
    x, w = X(x), round(X(x + w) - X(x), 1)
    y, h = Y(y), round(Y(y + h) - Y(y), 1)
    s = f'<rect class="{cls}" x="{x}" y="{y}" width="{w}" height="{h}" rx="8"/>'
    ty = (
        Y(ty) if ty is not None else y + h / 2 - (5 if sub else -4) - (5 if sub2 else 0)
    )
    s += T(x + w / 2, ty, title, "ct", "middle")
    if sub:
        s += T(x + w / 2, ty + 15, sub, "cs", "middle")
    if sub2:
        s += T(x + w / 2, ty + 28, sub2, "cs", "middle")
    if mod:
        s += (
            f'<path class="go" d="M{x + w - 13} {y + 6}h7v7M{x + w - 6} {y + 6}l-7 7"/>'
        )
    s += extra
    grp(layer, s, k=k, tip=tip, mod=mod, inst=inst)


def mux(layer, x, y, h, ins=(), w=16, k="", mod=None, inst=None, tip=None, label=None):
    x, w = X(x), round(X(x + w) - X(x), 1)
    y, h = Y(y), round(Y(y + h) - Y(y), 1)
    ins = [(Y(iy), lab) for iy, lab in ins]
    s = (
        f'<path class="mx" d="M{x} {y + 3}Q{x} {y} {x + 3} {y + 1}L{x + w - 2} {y + 7}Q{x + w} {y + 8} {x + w} {y + 11}'
        f'V{y + h - 11}Q{x + w} {y + h - 8} {x + w - 2} {y + h - 7}L{x + 3} {y + h - 1}Q{x} {y + h} {x} {y + h - 3}Z"/>'
    )
    for iy, lab in ins:
        s += T(x - 3, iy - 3, lab, "pin", "end")
    if label:
        s += T(x + w / 2, y + h + 13, label, "pin", "middle")
    grp(layer, s, k=k, tip=tip, mod=mod, inst=inst)


def pill(layer, x, y, text, k="", side="left", tip=None):
    """Small tag whose point touches (x, y): an input that comes from somewhere not drawn."""
    x, y = P((x, y))
    w = len(text) * 6.6 + 14
    if side == "down":
        d = f"M{x} {y}l-5 -5H{x - w / 2}a3 3 0 0 1 -3 -3v-10a3 3 0 0 1 3 -3H{x + w / 2}a3 3 0 0 1 3 3v10a3 3 0 0 1 -3 3H{x + 5}Z"
        grp(
            layer,
            f'<path class="tag" d="{d}"/>' + T(x, y - 9, text, "tagt", "middle"),
            k=k,
            tip=tip,
        )
        return
    if side == "left":
        d = f"M{x} {y}l-6 -8H{x - w}a3 3 0 0 0 -3 3v10a3 3 0 0 0 3 3H{x - 6}Z"
        tx = x - w + 3
    else:
        d = f"M{x} {y}l6 -8H{x + w}a3 3 0 0 1 3 3v10a3 3 0 0 1 -3 3H{x + 6}Z"
        tx = x + 11
    grp(
        layer,
        f'<path class="tag" d="{d}"/>' + T(tx, y + 3.6, text, "tagt"),
        k=k,
        tip=tip,
    )


RAIL_TAGS = []


def rail(x, name, bits, mod, tip):
    x, top, bot = X(x), Y(RAIL_TOP), Y(RAIL_BOT)
    s = f'<rect class="rail" x="{x - 4}" y="{top}" width="8" height="{bot - top}" rx="4"/>'
    grp("data", s, k="rail", tip=tip, mod=mod, cls="rail-g")
    RAIL_TAGS.append((x, f"{name} · {bits}b", mod, tip))


def rail_tags():
    """Drawn after all lines so a line never runs across a register's name."""
    for x, label, mod, tip in RAIL_TAGS:
        w = len(label) * 6.6 + 14
        s = f'<rect class="railtag" x="{x - w / 2}" y="{Y(RAIL_BOT)}" width="{w}" height="17" rx="4"/>'
        s += T(x, Y(RAIL_BOT) + 12, label, "railt", "middle")
        grp("data", s, k="rail", tip=tip, mod=mod, cls="rail-g")


def marker(scene, tag, x, y):
    x, y = P((x, y))
    w = max(20, len(tag) * 7.2 + 12)
    s = (
        f'<rect class="st" x="{x - w / 2}" y="{y - 10}" width="{w}" height="20" rx="10"/>'
        + T(x, y + 4, tag, "stn", "middle")
    )
    out.append(f'<g class="step" data-scene="{scene}" data-tag="{tag}">{s}</g>')


def badge(scene, x, y, text):
    x, y = P((x, y))
    w = len(text) * 6.9 + 12
    s = (
        f'<rect class="val" x="{x - w / 2}" y="{y - 9}" width="{w}" height="18" rx="4"/>'
        + T(x, y + 4, text, "valt", "middle")
    )
    out.append(f'<g class="badge" data-scene="{scene}">{s}</g>')


# ------------------------------------------------------------------ stage bands
for i, (x0, x1, t, sub) in enumerate(BANDS):
    x0, x1 = X(x0), X(x1)
    out.append(
        f'<rect class="band b{i % 2}" x="{x0}" y="0" width="{x1 - x0}" height="{H}"/>'
    )
    out.append(T((x0 + x1) / 2, 20, t.upper(), "bh", "middle"))
    out.append(T((x0 + x1) / 2, 35, sub, "bsub", "middle"))
out.append(f'<line class="hr" x1="0" y1="44" x2="{W}" y2="44"/>')

# ------------------------------------------------------------------ rails
rail(
    96,
    "IF1",
    128,
    "core_IF",
    "IF1 (in core_IF): fetch_pc and fetch_pc + 4. Held by stall, still loaded on flush.",
)
rail(
    288,
    "IF_regs",
    224,
    "core_IF",
    "IF_regs: fetch_pc, fetch_pc4, predicted_npc, and inst (which is the I-cache's own output register).",
)
rail(
    520,
    "ID_regs",
    544,
    "core_ID",
    "ID_regs: operands, targets and ~50 control bits. Bubble on stall or flush; held on a D-cache miss.",
)
rail(
    800,
    "EX_regs",
    354,
    "core_EX",
    "EX_regs: result, store data, flags. Cleared by flush unless the instruction entering EX links (JAL/BAL/JALR).",
)
rail(
    990,
    "MEM1",
    266,
    "core_MEM",
    "MEM1 (in core_MEM): EX result, CP0 read data, EPC / takenHandler, pc4. Never stalled.",
)
rail(
    1150,
    "MEM_regs",
    135,
    "core_MEM",
    "MEM_regs: W_data, W_regnum, write_enable, EPC, takenHandler.",
)

# ------------------------------------------------------------------ control lane (decoder → every stage)
lane(
    "ctrl",
    [(358, 196), (358, 172), (1146, 172)],
    "decoded control",
    (372, 167),
    dash=True,
    k="ctrl " + ALL_I,
    tip="~50 control bits decoded once in ID and carried in ID_regs → EX_regs → MEM1 → MEM_regs.",
)
lane(
    "ctrl",
    [(652, 172), (652, 198)],
    "op",
    (657, 190),
    dash=True,
    k="i-alu i-ld i-sd i-beq",
)
lane(
    "ctrl", [(723, 172), (723, 214)], "sel", (728, 190), dash=True, k="i-alu i-ld i-sd"
)
lane(
    "ctrl",
    [(920, 172), (920, 268)],
    "type",
    (915, 190),
    anchor="end",
    dash=True,
    k="i-ld i-sd mem",
)
lane(
    "ctrl",
    [(1067, 172), (1067, 222)],
    "sel",
    (1072, 214),
    dash=True,
    k="wb i-alu i-ld i-jal",
)

# ------------------------------------------------------------------ FETCH
lane(
    "data",
    [(40, 604), (40, 226), (92, 226)],
    "next PC",
    (88, 216),
    anchor="end",
    k="fetch branch exc " + ALL_I,
)
card(
    "data",
    118,
    196,
    150,
    84,
    "I-cache",
    "4 KB · 2-way",
    sub2="registered read",
    mod="core_IF",
    inst="inst_cache",
    k="fetch mem " + ALL_I,
    tip="Looked up with IF1.fetch_pc. Its output register is IF_regs.inst, so the instruction reaches the decoder a cycle later. Line fills go through the cache arbiter. A miss holds IF1 and IF_regs' PC; the cache output reads 0 meanwhile, so decode sees NOPs until the line arrives.",
)
lane("data", [(100, 226), (118, 226)], dots=[(108, 226)], k="fetch " + ALL_I)
lane(
    "data",
    [(108, 226), (108, 404), (118, 404)],
    dots=[(108, 320)],
    k="fetch branch " + ALL_I,
)
lane("data", [(108, 320), (284, 320)], "pc", (238, 315), k="fetch branch i-beq i-jal")
card(
    "branch",
    118,
    372,
    150,
    66,
    "Branch predictor",
    "BHT + BTB · 64",
    mod="core_branch_predictor",
    k="fetch branch " + ALL_I,
    tip="2-bit BHT + tagged direct-mapped BTB, looked up with IF1.fetch_pc. Only BEQ/BNE/BC/BAL are installed and EX checks the prediction of every one of them; the lookup is by PC alone (16-bit partial tag).",
)
lane("data", [(268, 226), (284, 226)], k="fetch " + ALL_I)
lane(
    "branch",
    [(200, 438), (200, 586)],
    "prediction",
    (206, 458),
    k="fetch branch " + ALL_I,
    tip="Taken in the BTB/BHT → BTB target, otherwise fetch_pc + 4. Used as next PC unless something redirects.",
)
lane("branch", [(268, 412), (284, 412)], k="branch i-beq")

# ------------------------------------------------------------------ DECODE
lane("data", [(292, 226), (312, 226)], k="fetch " + ALL_I)
card(
    "data",
    312,
    196,
    92,
    110,
    "Decoder",
    "~50 ctrl bits",
    mod="mips_decoder",
    k=ALL_I,
    tip="One-hot instruction classes → control. Unknown encodings set reserved_inst_E, which CP0 sees from ID_regs.",
)
lane(
    "data", [(404, 222), (428, 222)], "rs", (410, 216), k="i-alu i-ld i-sd i-beq stall"
)
lane("data", [(404, 266), (428, 266)], "rt", (410, 260), k="i-alu i-sd i-beq stall")
card(
    "data",
    428,
    196,
    80,
    110,
    "Registers",
    "32 × 64 b",
    sub2="write-first",
    mod="core_ID",
    inst="rf",
    k="i-alu i-ld i-sd i-beq i-jal wb",
    tip="Written from MEM_regs during ID (this is the WB stage). forwarded_A/B_mux make a same-cycle write visible to the read.",
)
lane("data", [(508, 214), (516, 214)], k="i-alu i-ld i-sd i-beq fwd")
lane("data", [(508, 274), (516, 274)], k="i-alu i-sd i-beq fwd")
lane("data", [(292, 320), (300, 320), (300, 352), (312, 352)], k="branch i-beq i-jal")
card(
    "data",
    312,
    330,
    92,
    50,
    "Targets",
    "branch · jump",
    mod="core_ID",
    inst="BranchAddr_mux",
    k="branch i-beq i-jal",
    tip="Branch target (pc4 + off·4 for BEQ/BNE/BAL, BC, ADDIUPC) and J/JAL target {pc[63:28], inst[25:0], 00}, computed in ID.",
)
lane(
    "data",
    [(404, 355), (516, 355)],
    "targets",
    (410, 349),
    k="branch i-beq i-jal",
    tip="pc_branch (BEQ/BNE/BC/ADDIUPC) and jumpAddr (J/JAL), carried in ID_regs.",
)
lane("branch", [(292, 412), (516, 412)], "predicted_npc", (300, 406), k="branch i-beq")

# ------------------------------------------------------------------ EXECUTE
lane("data", [(524, 214), (556, 214)], k="i-alu i-ld i-sd i-beq fwd")
lane("data", [(524, 276), (556, 276)], k="i-alu i-sd i-beq fwd")
mux(
    "data",
    556,
    204,
    50,
    ins=(),
    k="fwd i-alu i-ld i-sd i-beq",
    mod="core_EX",
    inst="forward_mux_A",
    tip="forward_mux_A: register value, EX_regs.out, MEM1 result or MEM_regs.W_data.",
)
mux(
    "data",
    556,
    266,
    50,
    ins=(),
    k="fwd i-alu i-sd i-beq",
    mod="core_EX",
    inst="forward_mux_B",
    tip="forward_mux_B: same sources, used only when operand B is a register.",
)
# forwarding lanes: EX_regs.out, MEM1 result, MEM_regs.W_data
lane(
    "fwd",
    [(812, 236), (812, 122), (532, 122), (532, 226), (556, 226)],
    "EX_regs",
    (760, 117),
    dots=[(812, 236), (532, 226)],
    k="fwd",
    tip="Forward from EX_regs.out: the previous instruction's result (not a load).",
)
lane("fwd", [(532, 226), (532, 288), (556, 288)], k="fwd")
lane(
    "fwd",
    [(1004, 236), (1004, 134), (540, 134), (540, 236), (556, 236)],
    "MEM1 result",
    (860, 129),
    dots=[(1004, 236), (540, 236)],
    k="fwd",
    tip="Forward from MEM1: the result two instructions back (not a load).",
)
lane("fwd", [(540, 236), (540, 298), (556, 298)], k="fwd")
lane(
    "fwd",
    [(1166, 317), (1166, 146), (548, 146), (548, 246), (556, 246)],
    "MEM_regs.W_data",
    (1018, 141),
    dots=[(1166, 317), (548, 246)],
    k="fwd stall i-ld",
    tip="Forward from MEM_regs: the value being written to the register file this cycle, loads included.",
)
lane("fwd", [(548, 246), (548, 308), (556, 308)], k="fwd stall i-ld")
card(
    "data",
    612,
    200,
    80,
    96,
    "ALU",
    "+ A == B",
    mod="core_EX",
    inst="alu_",
    k="i-alu i-ld i-sd i-beq branch",
    tip="64-bit ALU with 32-bit cut for the word ops; the branch comparison A == B is computed beside it.",
)
lane("data", [(572, 229), (612, 229)], k="i-alu i-ld i-sd i-beq")
lane(
    "data",
    [(572, 291), (590, 291)],
    arrow=False,
    dots=[(590, 291)],
    k="i-alu i-sd i-beq",
)
lane("data", [(590, 291), (590, 280), (612, 280)], k="i-alu i-beq")
lane("data", [(590, 291), (590, 330)], arrow=False, dots=[(590, 330)], k="i-sd")
lane("data", [(590, 330), (612, 330)], k="")
pill(
    "data",
    626,
    200,
    "imm",
    k="i-ld i-sd",
    side="down",
    tip="Sign- or zero-extended imm16 (alu_b_src) replaces B for loads, stores and the immediate ALU ops.",
)
card(
    "data",
    612,
    312,
    80,
    38,
    "Shifter",
    mod="core_EX",
    inst="shifter",
    k="",
    tip="barrel_shifter32 + 2 × barrel_rotator32, 32-bit cut and ±32 adjust; shifter_small feeds LSA.",
)
mux(
    "data",
    716,
    212,
    70,
    k="i-alu i-ld i-sd",
    mod="core_EX",
    inst="out_sel",
    label="8:1",
    tip="out_sel: ALU, shift, LUI, SLT/SLTU, SEB/SEH or pc_branch (ADDIUPC), one 8:1 mux.",
)
lane("data", [(692, 224), (716, 224)], k="i-alu i-ld i-sd")
lane("data", [(692, 331), (704, 331), (704, 250), (716, 250)], k="")
lane("data", [(732, 247), (796, 247)], "result", (746, 241), k="i-alu i-ld i-sd")
lane("branch", [(692, 282), (796, 282)], "zero", (722, 277), k="branch i-beq")
lane(
    "data", [(590, 330), (590, 446), (796, 446)], "store data", (680, 440), k="i-sd mem"
)
lane("data", [(524, 355), (796, 355)], k="branch i-beq")
lane("branch", [(524, 412), (796, 412)], "predicted_npc", (680, 406), k="branch i-beq")

# ------------------------------------------------------------------ MEMORY 1
lane(
    "data",
    [(804, 247), (812, 247), (812, 236), (986, 236)],
    dots=[(830, 236)],
    k="i-alu i-ld i-sd wb mem",
)
lane(
    "data",
    [(830, 236), (830, 300), (870, 300)],
    "addr",
    (836, 294),
    dots=[(830, 300)],
    k="i-ld i-sd mem",
)
lane("mem", [(830, 300), (830, 612)], "d_addr", (835, 560), k="mem")
card(
    "data",
    870,
    268,
    100,
    92,
    "D-cache",
    "4 KB · 2-way",
    sub2="registered read",
    mod="core_MEM",
    inst="data_cache",
    k="i-ld i-sd mem stall",
    tip="Addressed by EX_regs.out in MEM1, data out in MEM2. Skipped when d_valid (MMIO). A miss raises data_cache_miss_stall and freezes IF, ID and EX; MEM1 and MEM2 keep clocking.",
)
lane(
    "data",
    [(804, 446), (846, 446), (846, 340), (870, 340)],
    hops=[(830, 446)],
    k="i-sd mem",
)
lane("data", [(970, 316), (986, 316)], k="i-ld mem wb")
lane("mem", [(966, 360), (966, 584), (1070, 584), (1070, 612)], k="mem")
pill(
    "hazard",
    868,
    378,
    "miss → stall",
    k="stall mem",
    side="right",
    tip="data_cache_miss_stall holds IF1, IF_regs, ID_regs and EX_regs until the 64-byte line arrives.",
)
# CP0
card(
    "exc",
    830,
    52,
    150,
    60,
    "CP0",
    "exceptions · EPC",
    sub2="RI · ERET ← ID_regs",
    mod="cp0",
    k="exc",
    tip="In MEM1: overflow/syscall/break from EX_regs, reserved instruction and ERET from ID_regs. takenHandler reaches core_branch two cycles later through MEM1 and MEM_regs. EPC = ID_regs.pc: the next instruction, or a reserved instruction itself.",
)
lane(
    "exc",
    [(804, 190), (816, 190), (816, 82), (830, 82)],
    "exc flags",
    (812, 95),
    anchor="end",
    k="exc",
)
lane("exc", [(950, 112), (950, 200), (986, 200)], k="wb")
lane("exc", [(970, 112), (970, 184), (986, 184)], k="exc")

# ------------------------------------------------------------------ MEMORY 2
lane("data", [(994, 236), (1060, 236)], "alu", (1012, 230), k="i-alu wb")
lane(
    "exc",
    [(994, 200), (1040, 200), (1040, 266), (1060, 266)],
    "cp0",
    (1012, 196),
    k="wb",
)
lane("data", [(994, 316), (1060, 316)], "load", (1012, 310), k="i-ld wb mem")
pill(
    "data",
    1060,
    346,
    "pc+4",
    k="i-jal wb",
    side="left",
    tip="Link value for JAL/BAL/JALR.",
)
lane(
    "mem",
    [(944, 612), (944, 398), (1060, 398)],
    "mmio",
    (1000, 392),
    hops=[(966, 584)],
    k="mem wb",
    tip="d_rdata from the peripheral, combinational: it enters the MEM2 select without passing MEM1.",
)
mux(
    "data",
    1060,
    222,
    190,
    k="wb i-alu i-ld i-jal",
    mod="core_MEM",
    inst="alu_mem_mux",
    tip="alu_mem_mux → mfc0_mux → linkpc_mux: EX result, D$ data, MMIO data, CP0 read or pc+4.",
)
lane("data", [(1076, 317), (1146, 317)], "W_data", (1088, 311), k="wb i-alu i-ld i-jal")
lane(
    "exc",
    [(994, 184), (1146, 184)],
    k="exc",
    tip="EPC and takenHandler from CP0, carried through MEM1 and MEM_regs.",
)

# ------------------------------------------------------------------ WRITE-BACK
lane(
    "data",
    [(1154, 317), (1205, 317), (1205, 508), (468, 508), (468, 306)],
    "write-back → RF (in ID)",
    (590, 504),
    dots=[(1166, 317)],
    k="wb i-alu i-ld i-jal",
    tip="MEM_regs.W_data / W_regnum / write_enable drive the register-file write port during ID.",
)

# ------------------------------------------------------------------ CONTROL ROW
card(
    "hazard",
    120,
    52,
    180,
    60,
    "Hazard unit",
    "load-use · MMIO not ready",
    mod="core_hazard",
    k="stall i-ld",
    tip="Stall when IF_regs reads the destination of a load (MFC0 counts as one) still in ID_regs or EX_regs, or an MMIO access is not ready.",
)
lane(
    "hazard",
    [(210, 112), (210, 128), (96, 128), (96, 154)],
    "hold",
    (104, 144),
    dash=True,
    dots=[(210, 128), (288, 128)],
    k="stall i-ld",
)
lane("hazard", [(288, 128), (288, 154)], "hold", (296, 144), dash=True, k="stall i-ld")
lane(
    "hazard",
    [(210, 128), (520, 128), (520, 154)],
    "bubble",
    (452, 144),
    anchor="end",
    dash=True,
    k="stall i-ld",
)
card(
    "fwd",
    548,
    52,
    190,
    60,
    "Forwarding unit",
    "EX_regs › MEM1 › MEM_regs",
    mod="core_forward",
    k="fwd",
    tip="Compares ID_regs rs/rt with the destinations in EX_regs (not a load), MEM1 (not a load) and MEM_regs. Youngest wins.",
)
lane("fwd", [(564, 112), (564, 206)], dash=True, k="fwd")
lane("fwd", [(578, 112), (578, 260), (564, 260), (564, 268)], dash=True, k="fwd")

# ------------------------------------------------------------------ NEXT PC + redirects
npc_rows = [
    (616, "exception/irq · ERET", "exc"),
    (640, "mispredict", "branch i-beq"),
    (664, "J · JR", "branch i-jal"),
    (692, "prediction", "fetch branch"),
]
inner = ""
for y, t, _ in npc_rows:
    inner += TM(30, y + 4, t, "row")
card(
    "branch",
    16,
    586,
    208,
    116,
    "Next PC",
    None,
    mod="core_branch",
    k="fetch branch exc " + ALL_I,
    ty=604,
    extra=inner,
    tip="core_branch picks next_fetch_pc by priority: exception > ERET > mispredict > J/JR > prediction. During a D-cache freeze only an exception redirects; ERET, mispredict and J/JR wait until it ends. Any redirect also raises flush.",
)
grp("exc", TM(1172, 214, "EPC · exc", "lbl"), k="exc")
lane(
    "exc",
    [(1154, 184), (1240, 184), (1240, 545), (232, 545), (232, 616), (224, 616)],
    "exception → handler 0x0 · ERET → EPC",
    (980, 540),
    hops=[(830, 545)],
    k="exc",
    tip="MEM_regs.takenHandler: an exception redirect lands two cycles after CP0 decides. ERET instead redirects from ID_regs to MEM_regs.EPC.",
)
lane(
    "branch",
    [(600, 612), (600, 560), (246, 560), (246, 640), (224, 640)],
    "mispredict → correct PC",
    (300, 555),
    k="branch i-beq",
)
lane(
    "branch",
    [(524, 370), (536, 370), (536, 575), (260, 575), (260, 664), (224, 664)],
    "J / JR target (from ID_regs)",
    (300, 570),
    hops=[],
    k="branch i-jal",
    tip="J/JAL jump to jumpAddr; JR/JALR to the forwarded rs. Resolved from ID_regs, 2 younger slots flushed.",
)
lane(
    "branch",
    [(150, 586), (150, 524), (520, 524)],
    "flush",
    (330, 519),
    dash=True,
    arrow=False,
    dots=[(288, 524), (520, 524)],
    hops=[(200, 524)],
    k="branch exc i-jal i-beq",
    tip="flush loads IF1 with the new PC and clears IF_regs, ID_regs, and EX_regs unless the instruction entering EX links (and no exception is being taken).",
)
lane(
    "branch",
    [(520, 524), (800, 524), (800, 495)],
    dash=True,
    hops=[(536, 524)],
    k="branch exc i-beq",
    tip="flush loads IF1 with the new PC and clears IF_regs, ID_regs, and EX_regs unless the instruction entering EX links (and no exception is being taken).",
)
lane(
    "branch", [(150, 524), (96, 524), (96, 495)], dash=True, k="branch exc i-jal i-beq"
)
lane("branch", [(288, 524), (288, 495)], dash=True, k="branch exc i-jal i-beq")
lane("branch", [(520, 524), (520, 495)], dash=True, k="branch exc i-jal i-beq")
card(
    "branch",
    560,
    612,
    200,
    80,
    "Branch check",
    "taken? → correct next PC",
    sub2="≠ predicted_npc → redirect",
    mod="core_branch",
    k="branch i-beq",
    tip="From EX_regs: taken = BC | BAL | BEQ·zero | BNE·!zero; correct = taken ? pc_branch : pc4. A mismatch with predicted_npc redirects and flushes 3 slots; EX_regs also trains the predictor.",
)
lane(
    "branch",
    [(804, 412), (814, 412), (814, 652), (760, 652)],
    "EX_regs → check",
    (808, 600),
    anchor="end",
    k="branch i-beq",
)

# ------------------------------------------------------------------ MEMORY ROW
card(
    "mem",
    820,
    612,
    150,
    80,
    "MMIO port",
    "d_* · ≥ 0x2000_0000",
    sub2="timer · LED · stdout",
    mod="TOP",
    k="mem",
    tip="Peripherals in SOC.sv. d_valid comes from core_hazard. The timer answers in the same cycle; stdout and LED raise d_ready a cycle later. Only the timer returns read data.",
)
card(
    "mem",
    1000,
    612,
    140,
    80,
    "Cache arbiter",
    "I$ + D$ → 1 bus",
    sub2="512-bit lines",
    mod="cache_arbiter",
    k="mem",
    tip="Serialises I-cache and D-cache line fills / write-backs onto mem_bus.",
)
lane("mem", [(1140, 652), (1156, 652)], k="mem")
card(
    "mem",
    1156,
    612,
    116,
    80,
    "RAM",
    "4 KB @ 0x0",
    sub2="ROM: not built",
    mod="TOP",
    inst="data_mem",
    k="mem",
    tip="Outside the core: data_mem (DATA_LEN = 0x1000, 4 KB) behind mem_bus. 0x1000_0000 is reserved for a ROM that is not instantiated.",
)

rail_tags()

# ------------------------------------------------------------------ scene markers
# mechanism scenes: cycle tags relative to the event the scene follows (c0, c+1 ...),
# or letters where the points happen together; instruction scenes: which register holds
# the instruction in each cycle.
STEPS = {
    "fetch": [("c−1", 40, 420), ("c0", 118, 196), ("c0", 118, 372), ("c+1", 288, 250)],
    "fwd": [("A", 548, 52), ("B", 812, 280), ("C", 1004, 280), ("D", 1166, 350)],
    "stall": [
        ("c0", 120, 52),
        ("c+1", 520, 146),
        ("c+2", 1166, 350),
        ("also", 866, 398),
    ],
    "branch": [
        ("c0", 118, 372),
        ("c0", 440, 412),
        ("c+2", 536, 440),
        ("c+3", 560, 612),
        ("c+3", 150, 548),
    ],
    "exc": [
        ("c0", 816, 140),
        ("c0", 830, 52),
        ("c+1", 990, 184),
        ("c+2", 1150, 184),
        ("c+2", 246, 600),
    ],
    "wb": [("c0", 1068, 420), ("c+1", 1150, 340), ("c+1", 468, 318)],
    "mem": [("A", 870, 268), ("B", 1070, 600), ("C", 830, 600), ("D", 944, 440)],
}
RAILS = [96, 288, 520, 800, 990, 1150]
for sid in ("i-alu", "i-ld", "i-sd", "i-beq", "i-jal"):
    STEPS[sid] = [(f"c{i}", x, 458) for i, x in enumerate(RAILS)]
for scene, marks in STEPS.items():
    for tag, x, y in marks:
        marker(scene, tag, x, y)

# example values for the instruction scenes (see the cycle text in build.py)
BADGES = {
    "i-alu": [
        (468, 186, "$1=5 $2=7"),
        (772, 262, "12"),
        (1110, 332, "12"),
        (800, 508, "$3 ← 12"),
    ],
    "i-ld": [
        (468, 186, "$1=0x100"),
        (772, 262, "0x108"),
        (1027, 289, "0x1234"),
        (800, 508, "$4 ← 0x1234"),
    ],
    "i-sd": [(462, 186, "$1=0x100 $2=7"), (772, 262, "0x110"), (700, 461, "7")],
    "i-beq": [
        (468, 186, "$1=5 $2=5"),
        (764, 297, "1"),
        (460, 370, "0x130"),
        (620, 427, "0x124"),
        (545, 560, "→ 0x130"),
    ],
    "i-jal": [
        (460, 370, "0x200"),
        (536, 440, "→ 0x200"),
        (1110, 332, "0x144"),
        (800, 508, "$31 ← 0x144"),
    ],
}
for scene, items in BADGES.items():
    for x, y, t in items:
        badge(scene, x, y, t)


def svg():
    return "\n".join(out)
