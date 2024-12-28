ASM_FOLDER := example_asm
SCRIPT_FOLDER := scripts

$(ASM_FOLDER)/%: $(ASM_FOLDER)/%.s
	mips64-linux-gnu-as -Wall -O0 -mips64 $< -o $@
	mips64-linux-gnu-ld -T $(ASM_FOLDER)/script.ld $@ -o $@.elf
	mips64-linux-gnu-objdump --section=.text -D $@.elf > ./memory_dump.text.dat
	mips64-linux-gnu-objdump --section=.data -D $@.elf > ./memory_dump.data.dat
	python $(SCRIPT_FOLDER)/objdump2dat.py

clean_asm:
	rm -f  $(ASM_FOLDER)/*.o $(ASM_FOLDER)/*.elf
	rm -f ./memory_dump.text.dat ./memory_dump.data.dat ./memory.text.dat ./memory.data.dat

