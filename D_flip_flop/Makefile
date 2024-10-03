D_flip_flop: D_flip_flop.v
	iverilog -o D_flip_flop D_flip_flop_tb.v D_flip_flop.v
all: D_flip_flop
	./D_flip_flop
clean:
	rm -f D_flip_flop
	rm -f D_flip_flop*.vcd

.PHONY: all clean D_flip_flop
