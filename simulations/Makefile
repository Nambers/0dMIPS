# -- start full simulation --
define make_sim_target
$(1): $(2)
	@mkdir -p build
	@verilator -Wall --trace -cc $(2) -y . \
	-Mdir build/$(1) --prefix $(call capitalize_first,$(1)) \
	--exe simulations/$(1).cpp \
	-o $(call capitalize_first,$(1)) \
	-CFLAGS "-std=c++20 -march=native -flto=auto $(3)" \
	-LDFLAGS "$(4)" \
	-Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
	-O3 \
	--threads 1
	$(MAKE) -C build/$(1) -j$(( $(nproc) - 1)) -f $(call capitalize_first,$(1)).mk --silent 
	@mkdir -p bin
	@cp build/$(1)/$(call capitalize_first,$(1)) bin/
	@cp ./memory.*.mem ./bin/
	@./bin/$(call capitalize_first,$(1))


endef

$(eval $(call make_sim_target,core_sim,${CORE_DEPS} ./src/units/core.sv,,))
$(eval $(call make_sim_target,SOC_sim,src/modules/configurations.sv ${CORE_DEPS} ${PERIPHERAL_DEPS} src/units/core.sv src/SOC.sv,-I/usr/include/SDL3/ -D_REENTRANT,-L/usr/lib -lSDL3))

# -- individual VGA sim --
$(eval $(call make_sim_target,VGA_sim,src/modules/configurations.sv src/units/VGA.sv, -I/usr/include/SDL3/ -D_REENTRANT,-L/usr/lib -lSDL3))
