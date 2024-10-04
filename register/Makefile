register: register.v register_tb.v ../D_flip_flop/D_flip_flop.v ../barrel_shifter/barrel_shifter.v ../mux/mux.v
	iverilog -Wall -o $@ $^

regfile: register.v regfile_tb.v ../D_flip_flop/D_flip_flop.v ../barrel_shifter/barrel_shifter.v ../mux/mux.v
	iverilog -Wall -o $@ $^

all: register regfile
	./register
	./regfile

.PHONY: all register regfile