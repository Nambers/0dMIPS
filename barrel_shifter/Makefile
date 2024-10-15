barrel_shifter: *.v ../mux/mux.v
	iverilog -Wall -o $@ $^

all: barrel_shifter
	./barrel_shifter

clean:
	rm -f barrel_shifter
	rm -f barrel_shifter32_tb.vcd