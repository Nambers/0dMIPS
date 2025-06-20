cmake_minimum_required(VERSION 3.27)
project(MIPS64 VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(verilator HINTS $ENV{VERILATOR_ROOT})
find_package(GTest REQUIRED)
find_package(Threads REQUIRED)

function(capitalize_first input_var output_var)
    string(SUBSTRING "${${input_var}}" 0 1 first)
    string(TOUPPER "${first}" firstU)
    string(SUBSTRING "${${input_var}}" 1 -1 rest)
    set(${output_var} "${firstU}${rest}" PARENT_SCOPE)
endfunction()

set(SRC_DIR ${CMAKE_SOURCE_DIR}/src)

set(PERIPHERALS VGA timer stdout)
string(REPLACE ";" "|" PERIPH_REGEX "${PERIPHERALS}")

# ensure the include order
set(core_SRCS
    ${SRC_DIR}/modules/structures.sv
    ${SRC_DIR}/modules/mips_define.sv
)
file(GLOB core_other_SRCS
    "${SRC_DIR}/modules/*.sv"
    "${SRC_DIR}/units/*.sv"
)
list(FILTER core_other_SRCS EXCLUDE REGEX ".*/(${PERIPH_REGEX})\\.sv$")
list(REMOVE_ITEM core_other_SRCS
    ${SRC_DIR}/modules/structures.sv
    ${SRC_DIR}/modules/mips_define.sv
    ${SRC_DIR}/modules/configurations.sv
)
list(APPEND core_SRCS ${core_other_SRCS})

add_subdirectory(tests)
add_subdirectory(simulations)
add_subdirectory(example_asm)
