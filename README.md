# MIPS64
## Dependenices
- `mips64-linux-gnu` toolchains(`as` and `objdump`), they're under [mips64-linux-gnu-binutils](https://aur.archlinux.org/packages/mips64-linux-gnu-binutils) in Arch.
- \[OPTIONAL\] `mips64-linux-gcc` if you like to write C directly.
- `verilator` <https://github.com/verilator/verilator> for simulations.
- \[OPTIONAL\] `sdl3` <https://github.com/libsdl-org/SDL> for any simulation with VGA output.

## How to run
1. `./scripts/cloneGoogleTest.sh` to build gTest.
2. `make runtest` to run all tests.
3. `make <TEST FILE NAME>` (e.g. `make alu`) to run specific test under tests folder, or `make runtest` to run all tests.
4. `make example_asm/<ASSEMBLY FILE NAME>` (e.g. `make example_asm/fabonacci`) to compile assembly into binary.
5. `make <SIMULATION FILE NAME>` (e.g. `make core`) to run the simulation of compiled binary.
