# MIPS64

## Dependenices

- `mips64-linux-gnu` toolchains(`as` and `objdump`), they're under [mips64-linux-gnu-binutils](https://aur.archlinux.org/packages/mips64-linux-gnu-binutils) in Arch.
- \[OPTIONAL\] `mips64-linux-gcc` if you like to write C directly.
- `verilator` <https://github.com/verilator/verilator> for simulations.
- \[OPTIONAL\] `sdl3` <https://github.com/libsdl-org/SDL> for any simulation with VGA output.

## How to run
1. `cmake -B build .`
2. `cmake --build build -j ${$(nproc)-1}` to build all. All binaries are placed under `build/bin`
3. `cmake --build build --target help` to list all targets
4. `./runAllTest.sh` to run all generated tests under `build/bin`
5. `cmake --build build --target <script_name>` to compile script into memory.dat, e.g. `fabonacci`
