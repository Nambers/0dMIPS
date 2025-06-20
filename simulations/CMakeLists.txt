set(SIM_DIR ${CMAKE_SOURCE_DIR}/simulations)

set(SIM_UNITS core SOC VGA)

set(SOC_SRCS
    ${core_SRCS}
    ${SRC_DIR}/modules/configurations.sv
    ${SRC_DIR}/SOC.sv
)
# add peripheral sources to SOC_SRCS
foreach(peripheral IN LISTS PERIPHERALS)
    list(APPEND SOC_SRCS ${SRC_DIR}/units/${peripheral}.sv)
endforeach()

set(VGA_SRCS
    ${SRC_DIR}/modules/configurations.sv
    ${SRC_DIR}/units/VGA.sv
    ${SRC_DIR}/modules/register.sv
)

set(SDL3_ENABLED SOC VGA)

find_package(SDL3)

foreach(target IN LISTS SIM_UNITS)
    set(_name "${target}")
    capitalize_first(_name unitCap)

    add_executable(${target}_sim ${SIM_DIR}/${target}_sim.cpp)
    verilate(${target}_sim
        SOURCES ${${target}_SRCS}
        TOP_MODULE ${target}
        PREFIX ${unitCap}_sim
        DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${target}
        TRACE_VCD
    )
    target_link_libraries(${target}_sim PRIVATE)
    target_include_directories(${target}_sim PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/${target})

    if(target IN_LIST SDL3_ENABLED)
        if(NOT SDL3_FOUND)
            message(FATAL_ERROR "SDL3 not found. Please install SDL3 development files.")
        endif()
        target_include_directories(${target}_sim PRIVATE ${SDL3_INCLUDE_DIRS})
        target_link_libraries(${target}_sim PRIVATE SDL3::SDL3)
    endif()
endforeach()

