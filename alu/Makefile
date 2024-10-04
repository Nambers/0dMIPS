alu: *.v ../mux/mux.v
	iverilog -Wall -o $@ $^
all: alu
	./alu
clean:
	rm -f alu
	rm -f alu*.vcd

.PHONY: all clean alu
