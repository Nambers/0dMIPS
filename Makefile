# Makefile

# Get the list of directories in the current directory
DIRS := $(wildcard */)

# Remove the trailing slash from directory names
DIRS := $(patsubst %/,%,$(DIRS))

# Default target
all: $(DIRS) memory_dat fullmachine

VERILOG_MODULES := barrel_shifter mux D_flip_flop alu mips_decoder register
VERILOG_MODULES := $(foreach dir,$(VERILOG_MODULES),$(wildcard $(dir)/*.v))
VERILOG_MODULES := $(filter-out %_tb.v, $(VERILOG_MODULES))

# no need to add mips_define.v, it should be included
fullmachine: rom.v $(VERILOG_MODULES) fullmachine.v fullmachine_tb.v
	iverilog -o $@ $^

memory_dat: memory.s
	mips64-linux-gnu-as memory.s -o memory.o
	mips64-linux-gnu-objdump --section=.text -D memory.o > memory_dump.text.dat
	mips64-linux-gnu-objdump --section=.data -D memory.o > memory_dump.data.dat
	python objdump2dat.py

# Build target for each directory
$(DIRS):
	@echo "Building $@..."
	$(MAKE) -C $@ all

# Clean target for each directory
clean:
	@for dir in $(DIRS); do \
		echo "Cleaning $$dir..."; \
		$(MAKE) -C $$dir clean; \
	done

.PHONY: all clean memory_dat fullmachine $(DIRS)