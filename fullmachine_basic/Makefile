all: fullmachine

VERILOG_MODULES := barrel_shifter mux D_flip_flop alu mips_decoder register rom
VERILOG_MODULES := $(foreach dir,$(VERILOG_MODULES),$(wildcard ../$(dir)/*.v))
VERILOG_MODULES := $(filter-out %_tb.v, $(VERILOG_MODULES))

# no need to add mips_define.v, it should be included
fullmachine: $(VERILOG_MODULES) fullmachine.v fullmachine_tb.v
	iverilog -DSIMULATION -Wall -o $@ $^

clean:
	rm -f fullmachine

.PHONY: all