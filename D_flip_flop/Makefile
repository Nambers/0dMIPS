D_flip_flop: *.v
	iverilog -Wall -o $@ $^
all: D_flip_flop
	./D_flip_flop
clean:
	rm -f D_flip_flop
	rm -f D_flip_flop_tb.vcd

.PHONY: all clean D_flip_flop
