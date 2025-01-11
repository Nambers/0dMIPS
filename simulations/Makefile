# -- start full simulation --
NAME := core
UPPER_NAME := Core
PERIPHERALS := VGA|timer

DEPS := $(shell find ./src -name "*.sv" | grep -Ev "($(NAME)|mips_define|structures|SOC|$(PERIPHERALS)).sv")

$(NAME): src/modules/structures.sv src/units/$(NAME).sv ${DEPS} simulations/$(NAME).cpp
	verilator -Wall --trace -cc src/modules/structures.sv src/units/$(NAME).sv ${DEPS} -y . \
	-Mdir build/$(NAME) --prefix $(UPPER_NAME) \
	--exe simulations/$(NAME).cpp \
	-o $(UPPER_NAME) \
	-CFLAGS "-std=c++20"
	@$(MAKE) -C build/$(NAME) -j 8 -f $(UPPER_NAME).mk
	@mkdir -p bin
	@cp build/$(NAME)/$(UPPER_NAME) bin/
	@cp ./memory.*.mem ./bin/
	@./bin/$(UPPER_NAME)

# -- individual VGA sim --
VGA_sim:
	verilator -Wall -cc src/units/VGA.sv src/modules/register.sv -y . \
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