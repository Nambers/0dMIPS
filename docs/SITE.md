# Updating the Pages site

The site has two tabs:

- **How it works**: a hand-placed concept drawing of the pipeline.
- **RTL schematic**: interactive viewers for the Vivado schematics, with synthesis sizes.

CI (`.github/workflows/static.yml`) only runs `python docs/gen_export_schematics_site.py` and deploys `docs/schematic_html/`. It runs neither Vivado nor `docs/concept/build.py`, so their outputs are committed.

| Path | What it is | How it changes |
|---|---|---|
| `docs/schematic_svgs/*.svg`, `utilization*.rpt` | Elaborated-RTL schematics and post-synthesis reports | step A (Vivado), never by hand |
| `docs/concept/draw.py`, `build.py`, `template.html` | Source of the concept drawing, its scenes and the page | by hand, step B |
| `docs/site/index.html` | Built page | `python docs/concept/build.py`, never by hand |
| `docs/site/schematic_viewer.{js,css}` | Schematic viewer | by hand |
| `docs/schematic_html/` | Deployed output (git-ignored) | `python docs/gen_export_schematics_site.py` |

## Which steps

| You changed | Do |
|---|---|
| Any RTL | A, when convenient: it is slow, and the schematics and sizes are only stale until then. Do it before release, or whenever modules, instances or ports change. |
| Something the drawing shows (see the list in B) | B (and A) |
| Viewer, generator or page template | C |

Always finish with C.

## A. Re-export schematics and sizes (Vivado, roughly half an hour)

`write_schematic` needs the GUI, so on a headless machine it runs under `xvfb-run`. This was validated with Vivado 2025.2.

```sh
WS=$(mktemp -d)
python boards/xc7a100tfgg484-2/generate_vivado_project.py "$WS"
cat > "$WS/export.tcl" <<EOF
source $WS/create_proj.tcl
synth_design -rtl -rtl_skip_mlo -name rtl_1
cd $PWD/docs
source export_schematics.tcl
exit
EOF
rm docs/schematic_svgs/*.svg                        # so pages of removed modules disappear
(cd "$WS" && xvfb-run -a vivado -mode gui -nojournal -source export.tcl)
sed -i '/^| Host /d' docs/schematic_svgs/utilization*.rpt   # Vivado writes the machine name
rm -rf docs/.Xil                                    # Vivado scratch, left behind by the cd into docs
```

Then run the generator. It prints one `cells / nets` line per page. A `warning: no instance path` line means that page will get no sizes.

`cache_L1` has no page: `export_schematics.tcl` skips it because its schematic is too large.

## B. Update the concept drawing

Update the drawing when stages, forwarding sources, stall/flush/redirect cycles, the predictor, CP0/EPC behaviour, the memory map or cache geometry change.

- **Claims.** Every tooltip and step text is a claim about the RTL. Check each one against `src/`, not against AGENTS.md or old text.
- **Coordinates.** `draw.py` coordinates are in a 1280 × 720 design space, stretched piecewise onto the canvas by `XB` / `YB`.
  - To give a crowded strip room, move or add a breakpoint rather than moving elements.
  - Text, pills and markers are not scaled.
- **Elements.** Elements are built with `card`, `mux`, `lane`, `pill` and `rail`. Each takes:
  - `layer`: one of `data ctrl fwd hazard branch exc mem`, which are the Show toggles.
  - `k`: space-separated scene ids that light the element. `ALL_I` means all instruction scenes; rails are always lit.
  - `mod` / `inst`: link the element to `<mod>.html#focus=<inst>`. These must name an existing page and an instance in its SVG.
- **Scenes.** Scenes are listed in `SCENES` in `build.py`.
  - Mechanism scenes tag steps with cycle offsets from the event (`c0`, `c+1` …), or with letters when the steps are simultaneous.
  - Instruction scenes use `c0`–`c5`, one per pipeline register.
  - The markers on the drawing (`draw.STEPS`) use the same tags. Example values go in `draw.BADGES`.
  - To add a scene: add an entry to `SCENES`, add its id to the `k` of the parts it uses, then add its `STEPS` (and `BADGES`).
- **Instruction examples.** Encodings must be real. Check them with `mips64el-linux-gnu-as` + `objdump` (from `toolchains/`) or capstone.
- **Build.** Run `python docs/concept/build.py`. It also stamps the HEAD commit and date into the page.

## C. Build, preview, check

```sh
python docs/gen_export_schematics_site.py
python -m http.server -d docs/schematic_html 8765   # http://127.0.0.1:8765/
```

The page loads fonts and svg-pan-zoom from CDNs, so the preview needs network access.

- **Concept tab.** Paste `docs/concept/check_layout.js` into the DevTools console. It visits every scene and must print `no overlaps` (it returns `{}`). Also look at a few scenes by eye, e.g. `#fwd` and `#i-ld`.
- **RTL tab.** Open `#rtl/core` and check:
  - the tree shows LUT counts;
  - clicking a wire traces its whole net;
  - a blue box drills down;
  - a frame's `−` goes up a level.

  If tracing or the `−` icons break after a Vivado upgrade, the Nlview styling changed: see the regexes and strokes at the top of the generator.

## Commit

- **What to commit.** Commit `docs/schematic_svgs/`, `docs/concept/` and `docs/site/`. Never commit `docs/schematic_html/`.
- **Message.** Use a `docs:` message.
- **Deploying.** Pages redeploys when a push to `main` touches `docs/schematic_svgs/**`, `docs/site/**`, the generator or the workflow. A change only under `docs/concept/` does not deploy until `index.html` is rebuilt and committed.
