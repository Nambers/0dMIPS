set(ASM_DIR ${CMAKE_SOURCE_DIR}/example_asm)
set(SCRIPT_DIR ${CMAKE_SOURCE_DIR}/scripts)

file(GLOB ASM_SCRIPTS ${ASM_DIR}/*.s)
file(GLOB C_SCRIPTS ${ASM_DIR}/*.c)

set(TOOLCHIAN_FLAGS -mips64r6 -static -lgcc --sysroot=${CMAKE_SOURCE_DIR}/toolchains/mips64el-linux-musl-cross)
if(NOT EXISTS ${CMAKE_SOURCE_DIR}/toolchains/mips64el-linux-musl-cross)
    message(WARNING "Toolchain directory ${CMAKE_SOURCE_DIR}/toolchains/mips64el-linux-musl-cross does not exist. Please set up the toolchain.")
    set(TOOLCHIAN_FLAGS -mips64r6 -static -lgcc)
endif()
# TODO support all compact branches
set(C_FLAGS ${TOOLCHIAN_FLAGS}
    -O0
    -mcompact-branches=never
    -fomit-frame-pointer
    -fno-asynchronous-unwind-tables
    -fno-stack-protector
    -fno-pic
    -fno-pie
    -nostartfiles
    -nostdlib
    -Wl,-e,__start
)

foreach(script IN LISTS ASM_SCRIPTS)
    get_filename_component(script_name ${script} NAME_WE)
    add_custom_target(${script_name}
        COMMAND mips64el-linux-gnu-as -mabi=64 -O0 -mips64r6 ${script} -o ${script_name}.o
        COMMAND mips64el-linux-gnu-ld -m elf64ltsmip -T ${ASM_DIR}/script.ld ${script_name}.o -o ${script_name}.elf
        COMMAND mips64el-linux-gnu-objdump -D ${script_name}.elf > ${CMAKE_SOURCE_DIR}/memory_dump.dat || rm -f ${CMAKE_SOURCE_DIR}/memory_dump.dat
        COMMAND python ${SCRIPT_DIR}/objdump2dat.py ${CMAKE_SOURCE_DIR}
        DEPENDS ${script}
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    )
    set_target_properties(${script_name} PROPERTIES EXCLUDE_FROM_ALL TRUE)
endforeach()

foreach(script IN LISTS C_SCRIPTS)
    # get script name w/o ext
    get_filename_component(script_name ${script} NAME_WE)
    add_custom_target(${script_name}_c
        COMMAND mips64el-linux-gnu-gcc ${C_FLAGS} -T ${ASM_DIR}/script.ld ${script} -o ${script_name}.elf
        COMMAND mips64el-linux-gnu-objdump -D ${script_name}.elf > ${CMAKE_SOURCE_DIR}/memory_dump.dat || rm -f ${CMAKE_SOURCE_DIR}/memory_dump.dat
        COMMAND python ${SCRIPT_DIR}/objdump2dat.py ${CMAKE_SOURCE_DIR}
        DEPENDS ${script}
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    )
    set_target_properties(${script_name}_c PROPERTIES EXCLUDE_FROM_ALL TRUE)
endforeach()
