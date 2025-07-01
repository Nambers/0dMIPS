# MIPS64

## Dependenices

- `mips64el-linux-gnu-binutils` toolchains(`as` and `objdump`), they're under [mips64el-linux-gnu-binutils](https://aur.archlinux.org/packages/mips64-linux-gnu-binutils) in Arch.
- \[OPTIONAL\] `mips64el-linux-gnu-gcc` if you like to write C directly.
- \[OPTIONAL\] I mainly use `mips64el-linux-gnu-gcc-bootstrap` with `musl` as `sysroot`. Use `scripts/install_mips64el_musl.sh` to download musl and [mips64el-linux-gnu-gcc-bootstrap](https://aur.archlinux.org/packages/mips64-linux-gnu-gcc-bootstrap).
- `verilator` <https://github.com/verilator/verilator> for simulations.
- \[OPTIONAL\] `sdl3` <https://github.com/libsdl-org/SDL> for any simulation with VGA output.

## How to run

1. `cmake -B build .`
2. `cmake --build build -j ${$(nproc)-1}` to build all. All binaries are placed under `build/bin`
3. `cmake --build build --target help` to list all targets
4. `./runAllTest.sh` to run all generated tests under `build/bin`
5. `cmake --build build --target <script_name>` to compile script into memory.dat, e.g. `fabonacci`

## Plan

- [x] Basic 5-stages pipeline
- [x] TUI GDB-style debugger (simulated)
- [ ] Peripherals by MMIO
    - [ ] UART
    - [x] VGA
    - [x] Timer
    - [x] mock stdout
- [ ] Cache
- [ ] Interrupts
    - [x] Timer interrupt
    - [ ] Break
    - [x] Syscall
- [ ] ~~out-of-order execution~~ double-issue in-order
- [ ] AXI
    - [ ] Memory
- [ ] Branch prediction

## Demo

<details>
    <summary>Hello world with debugger (GIF)</summary>

![Hello world with debugger](docs/hello_world.gif)

</details>
