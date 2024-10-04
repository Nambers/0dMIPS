register: *.v ../D_flip_flop/D_flip_flop.v ../barrel_shifter/barrel_shifter.v ../mux/mux.v
	iverilog -Wall -o $@ $^

all: register
	./register

.PHONY: all register