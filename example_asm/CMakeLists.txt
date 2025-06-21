set(ASM_DIR ${CMAKE_SOURCE_DIR}/example_asm)
set(SCRIPT_DIR ${CMAKE_SOURCE_DIR}/scripts)

file(GLOB ASM_SCRIPTS ${ASM_DIR}/*.s)
file(GLOB C_SCRIPTS ${ASM_DIR}/*.c)

set(C_FLAGS -O0 -mips64r6 -mcompact-branches=never -fomit-frame-pointer -nostartfiles -nostdlib -fno-asynchronous-unwind-tables -fomit-frame-pointer -fno-stack-protector)

foreach(script IN LISTS ASM_SCRIPTS)
    get_filename_component(script_name ${script} NAME_WE)
    add_custom_target(${script_name}
        COMMAND mips64-linux-gnu-as -O0 -mips64r6 ${script} -o ${script_name}.o
        COMMAND mips64-linux-gnu-ld -T ${ASM_DIR}/script.ld ${script_name}.o -o ${script_name}.elf
        COMMAND mips64-linux-gnu-objdump --section=.text -D ${script_name}.elf > ${CMAKE_SOURCE_DIR}/memory_dump.text.dat
        COMMAND mips64-linux-gnu-objdump --section=.data -D ${script_name}.elf > ${CMAKE_SOURCE_DIR}/memory_dump.data.dat || rm -f memory_dump.data.dat
        COMMAND python ${SCRIPT_DIR}/objdump2dat.py ${CMAKE_SOURCE_DIR}
        DEPENDS ${script}
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    )
    set_target_properties(${script_name} PROPERTIES EXCLUDE_FROM_ALL TRUE)
endforeach()

foreach(script IN LISTS C_SCRIPTS)
    # get script name w/o ext
    get_filename_component(script_name ${script} NAME_WE)
    # TODO support compact branch inst and remove `-mcompact-branches=never` 
    add_custom_target(${script_name}_c
        COMMAND mips64-linux-gnu-gcc ${C_FLAGS} -T ${ASM_DIR}/script.ld ${script} -o ${script_name}.elf
        COMMAND mips64-linux-gnu-objdump --section=.text -D ${script_name}.elf > ${CMAKE_SOURCE_DIR}/memory_dump.text.dat
        COMMAND mips64-linux-gnu-objdump --section=.data -D ${script_name}.elf > ${CMAKE_SOURCE_DIR}/memory_dump.data.dat || rm -f ${CMAKE_SOURCE_DIR}/memory_dump.data.dat
        COMMAND python ${SCRIPT_DIR}/objdump2dat.py ${CMAKE_SOURCE_DIR}
        DEPENDS ${script}
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    )
    set_target_properties(${script_name}_c PROPERTIES EXCLUDE_FROM_ALL TRUE)
endforeach()
