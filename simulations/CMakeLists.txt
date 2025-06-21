set(SIM_DIR ${CMAKE_SOURCE_DIR}/simulations)

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

set(SDL3_ENABLED SOC_VGA VGA)

find_package(SDL3)

file(GLOB SIM_SOURCES "${SIM_DIR}/*_sim.cpp")

foreach(sim_src IN LISTS SIM_SOURCES)
    get_filename_component(sim_file "${sim_src}" NAME_WE)
    string(REPLACE "_sim" "" target "${sim_file}")
    string(REPLACE "_" ";" split_target "${target}")
    list(GET split_target 0 base_target)

    set(srclist "${base_target}_SRCS")
    if(NOT DEFINED ${srclist})
        message(FATAL_ERROR "Missing source list for base target ${base_target}")
    endif()

    set(target_name "${target}_sim")
    capitalize_first(target unitCap)

    add_executable(${target_name} ${sim_src})
    verilate(${target_name}
        SOURCES ${${srclist}}
        TOP_MODULE ${base_target}
        PREFIX ${unitCap}_sim
        DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${target}
        TRACE_VCD
    )
    target_include_directories(${target_name} PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/${target})
    if(target IN_LIST SDL3_ENABLED)
        if(NOT SDL3_FOUND)
            message(FATAL_ERROR "SDL3 not found. Please install SDL3 development files.")
        endif()
        target_include_directories(${target_name} PRIVATE ${SDL3_INCLUDE_DIRS})
        target_link_libraries(${target_name} PRIVATE SDL3::SDL3)
    endif()
endforeach()

file(GLOB DEBUG_SOURCES "${SIM_DIR}/*_debug.cpp")
foreach(debug_src IN LISTS DEBUG_SOURCES)
    get_filename_component(debug_file "${debug_src}" NAME_WE)
    string(REPLACE "_debug" "" target "${debug_file}")
    string(REPLACE "_" ";" split_target "${target}")
    list(GET split_target 0 base_target)

    set(srclist "${base_target}_SRCS")
    if(NOT DEFINED ${srclist})
        message(FATAL_ERROR "Missing source list for base target ${base_target}")
    endif()

    set(target_name "${target}_debug")
    capitalize_first(target unitCap)

    add_executable(${target_name} ${debug_src})
    verilate(${target_name}
        SOURCES ${${srclist}}
        TOP_MODULE ${base_target}
        PREFIX ${unitCap}_debug
        DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${target}
        TRACE_VCD
        VERILATOR_ARGS +define+DEBUG
    )
    target_include_directories(${target_name} PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/${target})
    if(target IN_LIST SDL3_ENABLED)
        if(NOT SDL3_FOUND)
            message(FATAL_ERROR "SDL3 not found. Please install SDL3 development files.")
        endif()
        target_include_directories(${target_name} PRIVATE ${SDL3_INCLUDE_DIRS})
        target_link_libraries(${target_name} PRIVATE SDL3::SDL3)
    endif()
endforeach()
