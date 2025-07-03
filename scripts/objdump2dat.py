import re
import os
import sys
import struct

CWD = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()


def parse_objdump(objdump_output, addr_dividor=1):
    pattern = r"^[ ]+([0-9a-f]+):\s+([0-9a-f]+)\s+(.*)$"
    lines = objdump_output.split("\n")
    memory = []
    phrase = []

    def b32toel(vals):
        res = []
        for i in vals:
            res.append(struct.pack("<I", int(i, 16)).hex(" "))
        return res

    next_expected_addr = -1
    for line in lines:
        match = re.match(pattern, line)
        if match:
            print(match.groups())
            address = int(match.group(1), 16)
            instruction = match.group(2)

            if address != next_expected_addr:
                # Flush old phrase if entering new aligned section
                if phrase:
                    memory.extend(b32toel(phrase))
                    phrase = []
                memory.append(f"@{(address // addr_dividor):08x}")

            next_expected_addr = address + 4
            phrase.append(instruction)

    memory.extend(b32toel(phrase))
    return "\n".join(memory)


with open(f"{CWD}/memory_dump.dat", "r") as f:
    objdump_output = f.read()

# rebasing text section may have problem in direct jump
formatted_output = parse_objdump(objdump_output, 1)
with open(f"{CWD}/memory.mem", "w") as f:
    f.write(formatted_output)
