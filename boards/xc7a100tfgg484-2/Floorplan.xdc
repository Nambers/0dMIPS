# Floorplan: keep the fetch / execute / memory cluster together.
#
# Why: the timing-critical nets all live in the tightly-coupled IF<->EX<->MEM
# triangle:
#   * data-cache-miss stall : D-cache (MEM) -> I-cache (IF) enable
#   * EX output / forwarding : cache read data (MEM) <-> EX <-> cache address
# When place spreads these across the die the paths become ~80% route delay.
#
# A first attempt that pinned only the two caches into a narrow column made it
# WORSE: it squeezed EX (which talks to both caches) out of the region and a new
# EX path became 85% route from congestion. So this version keeps EX, MEM and IF
# (and the arbiter) together AND gives them room: the whole bottom half of the
# die, both clock-region columns. They cluster without congesting.
#
# Clock-region ranges (not raw SLICE coords) so the box is device-correct and
# easy to retune: widen to CLOCKREGION_X0Y0:CLOCKREGION_X1Y2 if it does not fit,
# or shrink to one clock-region row to pull the cluster tighter.
#
# Implementation-only constraint; placement grouping only (routing not caged).

create_pblock pb_core_exec
add_cells_to_pblock [get_pblocks pb_core_exec] [get_cells -quiet {
    core/IF_stage
    core/EX_stage
    core/MEM_stage
    core/cache_arbiter_
}]
# Two clock-region rows, both columns (Y0-99). Best observed WNS. Device LUT
# util is only ~29%, so the cluster places without congestion while staying
# co-located. Tightening to a single row (Y0-49) did not help (route-bound
# MEM->EX / EX->EX forwarding paths plateau ~+0.58..0.59 ns either way).
resize_pblock [get_pblocks pb_core_exec] -add {CLOCKREGION_X0Y0:CLOCKREGION_X1Y1}

set_property CONTAIN_ROUTING   0 [get_pblocks pb_core_exec]
set_property EXCLUDE_PLACEMENT  0 [get_pblocks pb_core_exec]
