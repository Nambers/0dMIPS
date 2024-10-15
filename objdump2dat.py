import re


def parse_objdump(objdump_output, addr_dividor=1):
    pattern = r"^[ ]+([0-9a-f]+):\s+([0-9a-f]+)\s+(.*)$"
    lines = objdump_output.split("\n")
    memory = []
    current_address = 0

    for line in lines:
        match = re.match(pattern, line)
        if match:
            address = int(match.group(1), 16)
            instruction = match.group(2)
            if address != current_address + 4:
                assert address % addr_dividor == 0
                memory.append(f"@{(address // addr_dividor):08x}")
            current_address = address
            memory.append(instruction)

    return "\n".join(memory)


with open("memory_dump.text.dat", "r") as f:
    objdump_output = f.read()

# rebasing text section may have problem in direct jump
formatted_output = parse_objdump(objdump_output)
with open("memory.text.dat", "w") as f:
    f.write(formatted_output)

with open("memory_dump.data.dat", "r") as f:
    objdump_output = f.read()

formatted_output = parse_objdump(objdump_output, 8)
with open("memory.data.dat", "w") as f:
    f.write(formatted_output)
