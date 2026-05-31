import re
import os
import sys
import struct

CWD = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()


def parse_objdump(objdump_output, line_size=64):
    pattern = r"^[ ]+([0-9a-f]+):\s+([0-9a-f]+)\s+(.*)$"
    lines = objdump_output.split("\n")
    memory = {}

    def b32toel(vals):
        res = []
        for i in vals:
            res.extend(struct.pack("<I", int(i, 16)))
        return res

    for line in lines:
        match = re.match(pattern, line)
        if match:
            address = int(match.group(1), 16)
            instruction = match.group(2)
            for idx, byte in enumerate(b32toel([instruction])):
                memory[address + idx] = byte

    if not memory:
        return ""

    records = []
    for line_addr in range(0, max(memory.keys()) // line_size + 1):
        base = line_addr * line_size
        line_bytes = [memory.get(base + i, 0) for i in range(line_size)]
        if not any(line_bytes):
            continue

        # data_mem is cache-line addressed, so each record is one 512-bit line.
        records.append(f"@{line_addr:08x}")
        # $readmemh writes the rightmost hex digit to the low bits of the packed
        # vector, so emit byte 63 first and byte 0 last.
        records.append("".join(f"{byte:02x}" for byte in reversed(line_bytes)))

    return "\n".join(records)


with open(f"{CWD}/memory_dump.dat", "r") as f:
    objdump_output = f.read()

# rebasing text section may have problem in direct jump
formatted_output = parse_objdump(objdump_output)
with open(f"{CWD}/memory.mem", "w") as f:
    f.write(formatted_output)
