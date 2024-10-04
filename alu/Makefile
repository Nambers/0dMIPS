alu: alu.v
	iverilog -Wall -o alu *.v ../mux/mux.v
all: alu
	./alu
clean:
	rm -f alu
	rm -f alu*.vcd

.PHONY: all clean alu
