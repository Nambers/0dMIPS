import re
import os
import sys

CWD = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()


def parse_objdump(objdump_output, addr_dividor=1):
    pattern = r"^[ ]+([0-9a-f]+):\s+([0-9a-f]+)\s+(.*)$"
    lines = objdump_output.split("\n")
    memory = []
    current_address = 0
    phrase = []

    def group_mem(phrase):
        paired_list = [
            f"{phrase[i+1]}{phrase[i]}" for i in range(0, len(phrase) - 1, 2)
        ]
        if len(phrase) % 2 == 1:
            paired_list.append(f"00000000{phrase[-1]}")
        return paired_list

    for line in lines:
        match = re.match(pattern, line)
        if match:
            address = int(match.group(1), 16)
            instruction = match.group(2)
            if address != current_address + 4:
                assert address % addr_dividor == 0
                # group every 2 elements in phrase
                memory.extend(group_mem(phrase))
                phrase = []
                memory.append(f"@{(address // addr_dividor):08x}")
            current_address = address
            phrase.append(instruction)
    memory.extend(group_mem(phrase))
    return "\n".join(memory)


with open(f"{CWD}/memory_dump.text.dat", "r") as f:
    objdump_output = f.read()

# rebasing text section may have problem in direct jump
formatted_output = parse_objdump(objdump_output, 8)
with open(f"{CWD}/memory.text.mem", "w") as f:
    f.write(formatted_output)

# check file existence
if os.path.exists(f"{CWD}/memory_dump.data.dat"):
    with open(f"{CWD}/memory_dump.data.dat", "r") as f:
        objdump_output = f.read()
    formatted_output = parse_objdump(objdump_output, 8)
    with open(f"{CWD}/memory.data.mem", "w") as f:
        f.write(formatted_output)
