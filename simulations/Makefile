# -- start full simulation --
core_sim: src/units/core.sv ${CORE_DEPS} simulations/core_sim.cpp
	@verilator -Wall --trace -cc ${CORE_DEPS} ./src/units/core.sv -y . \
	-Mdir build/core_sim --prefix Core_sim \
	--exe simulations/core_sim.cpp \
	-o Core_sim \
	-CFLAGS "-std=c++20"
	@$(MAKE) -C build/core_sim -j 8 -f Core_sim.mk
	@mkdir -p bin
	@cp build/core_sim/Core_sim bin/
	@cp ./memory.*.mem ./bin/
	@./bin/Core_sim

SOC_sim: src/SOC.sv src/modules/configurations.sv src/units/core.sv ${CORE_DEPS} simulations/SOC_sim.cpp
	@verilator -Wall --trace -cc ./src/modules/configurations.sv ${CORE_DEPS} ${PERIPHERAL_DEPS} src/units/core.sv src/SOC.sv -y . \
	-Mdir build/SOC_sim --prefix SOC_sim \
	--exe simulations/SOC_sim.cpp \
	-o SOC_sim \
	-CFLAGS "-I/usr/include/SDL3/ -D_REENTRANT -std=c++20" \
	-LDFLAGS "-L/usr/lib -lSDL3" \
	-Wno-WIDTHEXPAND -Wno-WIDTHTRUNC
	@$(MAKE) -C build/SOC_sim -j 8 -f SOC_sim.mk
	@mkdir -p bin
	@cp build/SOC_sim/SOC_sim bin/
	@cp ./memory.*.mem ./bin/
	@./bin/SOC_sim


# -- individual VGA sim --
VGA_sim:
	@verilator -Wall -cc src/units/VGA.sv src/modules/register.sv -y . \
	-Mdir build/$@ --prefix $@ \
	--exe simulations/$@.cpp \
	-o $@ \
	-CFLAGS "-I/usr/include/SDL3/ -D_REENTRANT -std=c++20" \
	-LDFLAGS "-L/usr/lib -lSDL3" \
	-Wno-WIDTHEXPAND -Wno-WIDTHTRUNC
	@$(MAKE) -C build/$@ -j 8 -f $@.mk
	@mkdir -p bin
	@cp build/$@/$@ bin/
	@./bin/$@