# Makefile

# Get the list of directories in the current directory
DIRS := $(wildcard */)

# Remove the trailing slash from directory names
DIRS := $(patsubst %/,%,$(DIRS))
FILTER_OUT := vivado_proj
DIRS := $(filter-out $(FILTER_OUT), $(DIRS))

# Default target
all: $(DIRS)

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

.PHONY: all clean $(DIRS)