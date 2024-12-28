# MIPS64
## Dependenices
- `mips64-linux-gnu` toolchains(`as` and `objdump`), they're under [mips64-linux-gnu-binutils](https://aur.archlinux.org/packages/mips64-linux-gnu-binutils) in Arch.
- `verilator` <https://github.com/verilator/verilator>.

## How to run
1. `./scripts/cloneGoogleTest.sh` to build gTest.
2. `make runtest` to run all tests.
3. `make <TEST FILE NAME>` (e.g. `make alu`) to run specific test under tests folder.
4. `make example_asm/<ASSEMBLY FILE NAME>` (e.g. `make example_asm/fabonacci`) to compile assembly into binary.
5. `make <SIMULATION FILE NAME>` (e.g. `make full_machine`) to run the simulation of compiled binary.
