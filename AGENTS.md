# 0dMIPS

MIPS64r6 SoC in SystemVerilog: in-order 5-stage pipeline (IF and MEM each take 2 cycles), L1 I/D caches, CP0, MMIO peripherals. Simulated and unit-tested with Verilator + GoogleTest; FPGA target is an Artix-7 board under `boards/`.

## Commands

```sh
cmake -B build .                                   # configure (re-run after adding/removing .sv files: sources are GLOBbed)
cmake --build build -j"$(nproc)"                   # everything -> build/bin
./runAllTests.sh                                   # all unit tests via ctest
DUMP_COV=1 ./runAllTests.sh                        # + Verilator coverage into coverage.info
./build/bin/coreTest --gtest_filter='CoreTest.SLL_ADD'   # one test

# CI (.github/workflows/codecov.yml): tests only, no simulators
cmake -B build -G Ninja -DODMIPS_BUILD_SIMULATIONS=OFF . && cmake --build build --target allTests

# X check: every explicit 'x becomes a per-run random value; tests must pass for any seed
cmake -B build-x -DODMIPS_TEST_X_UNIQUE=ON . && cmake --build build-x --target allTests
./build-x/bin/coreTest +verilator+seed+3

# example programs -> memory.mem in repo root (needs toolchains/, see scripts/install_mips64el_musl.sh)
cmake --build build --target stdout            # example_asm/stdout.s
cmake --build build --target fibonacci_c       # example_asm/fibonacci.c  (C targets get a _c suffix)
./build/bin/SOC_sim                            # run from repo root: memory.mem is loaded relative to cwd
```

Simulators in `build/bin/`: `SOC_sim` (info log + capstone disasm), `SOC_run_sim` (no log, `-O3 -flto`), `SOC_debug` (step per keypress, VCD), `SOC_VGA_sim` / `VGA_sim` (SDL3 window), `debugger_tui` (ftxui). Building them needs capstone and SDL3; ftxui is optional. `-Dsim_VCD_dump=ON` adds VCD to the other sims.

## Layout

- `src/SOC.sv` top level (`sys_clk`, active-low `sys_rst_n`); `src/units/` stages (`core_IF/ID/EX/MEM.sv`), `core.sv`, `cache_L1.sv`, `cache_arbiter.sv`, `cp0.sv`, peripherals; `src/modules/` packages (`structures.sv`, `mips_define.sv`, `configurations.sv`), `mips_decoder.sv`, hazard/forward/branch units, `core_branch_predictor.sv`, muxes/registers.
- `tests/<unit>_test*.cpp` → one Verilated binary per unit (`timer`, `cp0`, `core`, `cache_L1`); unit and source lists in `tests/CMakeLists.txt` (`core` uses `core_SRCS` from the top-level CMakeLists).
- `simulations/` C++ harnesses. The SoC-based ones verilate the sim-only top `simulations/sv/soc_tb.sv` and observe the design only through its `probe_*` ports and the DPI inspectors in `simulations/sv/soc_inspect.sv` (C++ side: `simulations/soc_inspect.hpp`).
- `example_asm/` programs + `script.ld` + `header.h`; `scripts/objdump2dat.py` turns objdump output into `memory.mem`.
- `docs/ISA.md` lists every supported instruction. Schematics, the concept drawing and the Pages site: see `docs/SITE.md`.

## Pipeline map

`<Stage>_regs` is the pipeline register at the *output* of that stage:

| Register | Between | Notes |
|---|---|---|
| `IF1` (inside `core_IF`) | IF1 → IF2 | I-cache lookup + branch-predictor lookup on `IF1.fetch_pc` |
| `IF_regs` | IF → ID | |
| `ID_regs` | ID → EX | register file is written here from `MEM_regs` (WB happens in ID) |
| `EX_regs` | EX → MEM1 | D-cache / MMIO access, CP0 exception detection |
| `MEM1` (inside `core_MEM`) | MEM1 → MEM2 | |
| `MEM_regs` | MEM2 → WB | |

- Forwarding sources: `EX_regs`, `MEM1`, `MEM_regs`. A load's data only exists after MEM2, so load-use costs up to 2 bubbles (`core_hazard.sv`).
- Stalls: load-use and not-ready MMIO insert a bubble into `ID_regs`; a D-cache miss (`data_cache_miss_stall`) freezes the whole pipeline; an I-cache miss (`inst_cache_miss_stall`) only holds IF1.
- Addresses `>= 0x2000_0000` (`PERIPHERAL_BASE`) bypass the D-cache and go out on the `d_*` MMIO port.

## Control flow and exceptions

- Conditional branches (BEQ/BNE/BC/BAL) resolve from `EX_regs`; J/JR resolve from `ID_regs`. While a D-cache miss freezes the pipeline, only reset and `takenHandler` redirect; other redirects wait for the freeze to end.
- `core_branch_predictor` (2-bit BHT + tagged direct-mapped BTB, 64 entries) predicts conditional branches in IF1; `core_branch` flushes on mismatch, so the predictor only affects timing.
- No branch delay slots, and compact branches other than `BC` are not implemented — hence the mandatory C flags `-fno-delayed-branch -mcompact-branches=never` (plus `-mno-abicalls -nostdlib -nostartfiles`, entry `__start`), all set in `example_asm/CMakeLists.txt`.
- CP0 (`cp0.sv`) detects overflow/syscall/break from `EX_regs` and reserved-instruction from `ID_regs`; the redirect happens two cycles later via `MEM_regs.takenHandler`.
- EPC is **not** MIPS-spec: exceptions save the PC of the *next* instruction (`ID_regs.pc`), so handlers must not add 4; interrupts save `IF1.fetch_pc`.
- Handler entry is `core_branch.interrupeHandlerAddr` (sic; default 0). Programs put a vector at 0x0 via `DEFAULT_HEADER_DEFINITIONS` in `example_asm/header.h` (`jal exception_handler`, which clobbers `$ra`); `.text` and the reset PC start at 0x100.

## Memory map

RAM `0x0` (16 MB) · ROM `0x1000_0000` · Timer `0x2000_0000` (cnt +0, ctrl +4) · VGA color `0x2000_0008` · mock stdout `0x2000_0010` (sim only) · LED `0x2000_0018` (4-bit). Source of truth: `src/modules/configurations.sv`.

## Testing patterns (core)

- Core tests do not model main memory: `preloadCacheLine` / `setAddrDWord` write instructions and data straight into way 0 of `ICACHE` / `DCACHE`; `inst_comb(lo, hi)` packs two instructions per dword. Every `TestGenMem*` case preloads `0x0`–`0x13f` (zero-filled) in both caches; any other line misses.
- To exercise a miss, leave the line un-preloaded and serve fills from the test loop with `mem_resp_set_ready(inst_->mem_bus_resp, mem_req_is_load(inst_->mem_bus_req))` (see `JAL_during_DCacheMiss`).
- Core tests decode packed structs by bit offset (`buildMemRegs` behind `WRITE_RF`, `mem_req_*` / `mem_resp_*`): changing `MEM_regs_t` / `mem_bus_req_t` / `mem_bus_resp_t` in `structures.sv` requires updating `tests/core_test.hpp`.
- `WRITE_RF(r, v)` injects a write-back through `MEM_regs` and ticks once. `RESET_PC()` restarts fetch at 0.
- `TestGenMem*` macros (`tests/core_test.hpp`): plain variants loop over `common_boundary_cases`, `Once` runs a single case, `NoCheck` allows a given exception code; all others assert `exc_code == 0` every cycle.
- Prefer counting register-file writes (`RF->wr_enable`, `RF->W_addr`) over checking `FETCH_PC` at fixed cycles.

## Rules

- `structures.sv` and `mips_define.sv` come first in every Verilator source list; `configurations.sv` and `xpm_memory_sdpram_verilator.sv` are SOC-only.
- Peripherals are `ifdef`-gated (`VGA_ENABLED`, `LED_ENABLED`, `MOCK_STDOUT_ENABLED`). VGA is deprecated: don't build new features on it.
- Unit tests read signals marked `/* verilator public */`; sims never reach into the RTL hierarchy, they add a `probe_*` port to `soc_tb.sv` or a DPI function to `soc_inspect.sv`.
- Mux inputs that are don't-cares are marked with `XMASK` (see `src/modules/mux.sv`).
- Update `docs/ISA.md` together with the decoder.
- Must build with both CI's Ubuntu Verilator and current releases.
- `.gitignore` is a whitelist (`*`, then `!path`). Never commit build outputs, traces, memory images or `toolchains/`.

## Conventions

- 4-space indent (SV and C++); lower_snake_case modules/signals; registered values `*_Q`, next-state `*_D`.
- GTest fixtures `<Unit>Test`; core case names describe the sequence (`SLL_ADD`) or feature (`BranchPredictor_*`).
- Commits: `feat:` / `fix:` / `perf:` / `chore:` / `docs:` / `CI:` + imperative subject. PRs state behavioural impact, the exact test commands run, and any new dependency; attach captures for VGA/TUI changes.
