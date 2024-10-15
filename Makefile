# Makefile

# Get the list of directories in the current directory
DIRS := $(wildcard */)

# Remove the trailing slash from directory names
DIRS := $(patsubst %/,%,$(DIRS))
FILTER_OUT := vivado_proj
DIRS := $(filter-out $(FILTER_OUT), $(DIRS))

# Default target
all: $(DIRS) memory_dat

memory_dat: memory.s
	mips64-linux-gnu-as -Wall -O0 -mips64 memory.s -o memory.o
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

.PHONY: all clean memory_dat $(DIRS)