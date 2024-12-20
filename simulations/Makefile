NAME := full_machine
UPPER_NAME := Full_machine

DEPS := $(shell find ./src -name "*.sv" | grep -Ev "($(NAME)|mips_define).sv")

$(NAME): src/units/$(NAME).sv ${DEPS} simulations/$(NAME).cpp
	verilator -Wall -cc src/units/$(NAME).sv ${DEPS} -y . \
	-Mdir build/$(NAME) --prefix $(UPPER_NAME) \
	--exe simulations/$(NAME).cpp \
	-o $(UPPER_NAME) \
	-CFLAGS "-std=c++20"
	@make -C build/$(NAME) -j 8 -f $(UPPER_NAME).mk
	@mkdir -p bin
	@cp build/$(NAME)/$(UPPER_NAME) bin/
	@cp ./memory.*.mem ./bin/
	@./bin/$(UPPER_NAME)
