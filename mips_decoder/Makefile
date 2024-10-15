mips_decoder: *.v
	iverilog -Wall -o $@ $^

all: mips_decoder
	./mips_decoder

clean:
	rm -f mips_decoder

.PHONY: all mips_decoder clean