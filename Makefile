# File is modified from https://github.com/mortenjc/systemverilog/blob/main/Makefile
# Under copyright (C) 2021 Morten Jagd Christensen, LICENSE: BSD2

.SUFFIXES:

include Makefile.macros

VLCOVFLAGS = --annotate logs/annotate --annotate-all --annotate-min 1

# User only needs to edit below
MODULES = 
UNITS = alu timer cp0
UNITS.alu = modules/mux modules/adder units/au units/lu
UNITS.timer = modules/register units/alu $(UNITS.alu)
UNITS.cp0 = modules/register modules/mux
# User only needs to edit above

TARGETS = $(addsuffix Test, $(addprefix bin/, $(MODULES))) $(addsuffix Test, $(addprefix bin/, $(UNITS)))

vpath %.sv src/modules src/units

all: directories $(TARGETS)

# Create dependencies using macros
# main targets
$(foreach module, $(MODULES), $(eval $(call make_bintargets,$(module))))
$(foreach unit, $(UNITS), $(eval $(call make_bintargets,$(unit))))
# dependencies
$(foreach module, $(MODULES), $(eval $(call make_mktargets,$(module),modules)))
$(foreach unit, $(UNITS), $(eval $(call make_mktargets,$(unit),units,$(UNITS.$(unit)))))


%: directories bin/%Test
	@if [ -f bin/$@Test ]; then \
	./bin/$@Test; \
	else \
	echo "Test for $@ not found!"; \
	exit 1; \
	fi

#
runtest: all $(TARGETS)
	@for test in $(TARGETS); do ./$$test || exit 1; done

coverage: runtest
	verilator_coverage $(VLCOVFLAGS) -write-info logs/merged.info logs/coverage1.dat logs/coverage2.dat

genhtml: coverage
	genhtml logs/merged.info --output-directory logs/html

gtest:
	@./scripts/makegtest

# make sure build directory is created
.PHONY: directories
#
directories: build

build:
	@mkdir -p build bin


# Misc clean targets
clean:
	@rm -fr build *.bak bin logs

realclean: clean
	@rm -fr googletest db output_files simulation

include simulations/Makefile
include example_asm/Makefile