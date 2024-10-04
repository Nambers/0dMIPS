register: *.v ../D_flip_flop/D_flip_flop.v
	iverilog -Wall -o register *.v ../D_flip_flop/D_flip_flop.v

all: register
	./register

.PHONY: all register