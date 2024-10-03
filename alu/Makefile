alu: alu.v
	iverilog -o alu *.v
all: alu
	./alu
clean:
	rm -f alu
	rm -f alu*.vcd

.PHONY: all clean alu
