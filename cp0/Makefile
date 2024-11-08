cp0: *.v ../mux/mux.v ../alu/alu.v ../register/register.v ../barrel_shifter/barrel_shifter.v ../timer/timer.v
	iverilog -Wall -o $@ $^

all: cp0
	./cp0