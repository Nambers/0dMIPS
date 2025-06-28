import re
import os
import sys

CWD = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()


def parse_objdump(objdump_output, addr_dividor=1):
    pattern = r"^[ ]+([0-9a-f]+):\s+([0-9a-f]+)\s+(.*)$"
    lines = objdump_output.split("\n")
    memory = []
    phrase = []

    def group_mem(phrase):
        paired_list = [
            f"{phrase[i]}{phrase[i+1]}" for i in range(0, len(phrase) - 1, 2)
        ]
        if len(phrase) % 2 == 1:
            paired_list.append(f"{phrase[-1]}00000000")
        return paired_list

    next_expected_addr = -1
    for line in lines:
        match = re.match(pattern, line)
        if match:
            address = int(match.group(1), 16)
            instruction = match.group(2)

            if address != next_expected_addr:
                # Flush old phrase if entering new aligned section
                if phrase:
                    memory.extend(group_mem(phrase))
                    phrase = []
                memory.append(f"@{(address // addr_dividor):08x}")

            next_expected_addr = address + len(instruction) // 2
            phrase.append(instruction)

    memory.extend(group_mem(phrase))
    return "\n".join(memory)


with open(f"{CWD}/memory_dump.dat", "r") as f:
    objdump_output = f.read()

# rebasing text section may have problem in direct jump
formatted_output = parse_objdump(objdump_output, 8)
with open(f"{CWD}/memory.mem", "w") as f:
    f.write(formatted_output)
