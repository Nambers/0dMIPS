# -- start full simulation --
core_sim: src/units/core.sv ${CORE_DEPS} simulations/core_sim.cpp
	@verilator -Wall --trace -cc ${CORE_DEPS} ./src/units/core.sv -y . \
	-Mdir build/core_sim --prefix Core_sim \
	--exe simulations/core_sim.cpp \
	-o Core_sim \
	-CFLAGS "-std=c++20" +define+DEBUG
	@$(MAKE) -C build/core_sim -j$(( $(nproc) - 1)) -f Core_sim.mk --silent 
	@mkdir -p bin
	@cp build/core_sim/Core_sim bin/
	@cp ./memory.*.mem ./bin/
	@./bin/Core_sim

SOC_sim: src/SOC.sv src/modules/configurations.sv src/units/core.sv ${CORE_DEPS} simulations/SOC_sim.cpp
	@verilator -Wall --trace -cc ./src/modules/configurations.sv ${CORE_DEPS} ${PERIPHERAL_DEPS} src/units/core.sv src/SOC.sv -y . \
	-Mdir build/$@ --prefix $@ \
	--exe simulations/$@.cpp \
	-o $@ \
	-CFLAGS "-I/usr/include/SDL3/ -D_REENTRANT -std=c++20" \
	-LDFLAGS "-L/usr/lib -lSDL3" \
	-Wno-WIDTHEXPAND -Wno-WIDTHTRUNC
	@$(MAKE) -C build/$@ -j$(( $(nproc) - 1))  -f $@.mk --silent 
	@mkdir -p bin
	@cp build/$@/$@ bin/
	@cp ./memory.*.mem ./bin/
	@./bin/$@


# -- individual VGA sim --
VGA_sim: src/modules/configurations.sv src/units/VGA.sv
	@verilator -Wall -cc src/modules/configurations.sv src/units/VGA.sv -y . \
	-Mdir build/$@ --prefix $@ \
	--exe simulations/$@.cpp \
	-o $@ \
	-CFLAGS "-I/usr/include/SDL3/ -D_REENTRANT -std=c++20 -O3" \
	-LDFLAGS "-L/usr/lib -lSDL3" \
	-Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
	--threads 1
	@$(MAKE) -C build/$@ -j$(( $(nproc) - 1)) -f $@.mk --silent 
	@mkdir -p bin
	@cp build/$@/$@ bin/
	@./bin/$@