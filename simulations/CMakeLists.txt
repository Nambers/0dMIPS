set(SIM_DIR ${CMAKE_SOURCE_DIR}/simulations)

set(VGA_SRCS
    ${SRC_DIR}/modules/configurations.sv
    ${SRC_DIR}/units/VGA.sv
    ${SRC_DIR}/modules/register.sv
)

set(SDL3_ENABLED SOC_VGA VGA)
set(CAPSTONE_DISABLED SOC_run)
set(SOC_run_C_flag -O3 -flto)
set(VERILATOR_ARGS +define+MOCK_STDOUT_ENABLED ${ODMIPS_VERILATOR_WARN_ARGS})
set(sim_VCD_dump OFF CACHE BOOL "Enable or disable VCD dump in simulation targets")

# SoC harnesses verilate the sim-only wrapper soc_tb: it exposes probes as
# top-level ports and binds read-only DPI inspectors (sv/), so the harnesses
# need no RTL `public` markings. Ignoring them lets Verilator inline and
# optimise the whole SoC (--public-ignore needs Verilator >= 5.034; older
# versions still work, just slower).
set(SOC_TB_SRCS ${SOC_SRCS} ${SIM_DIR}/sv/soc_inspect.sv ${SIM_DIR}/sv/soc_tb.sv)
set(SOC_TB_ARGS)
if("${verilator_VERSION}" VERSION_GREATER_EQUAL 5.034)
    list(APPEND SOC_TB_ARGS --public-ignore)
endif()

# lets soc_inspect.hpp include the model's generated DPI header
function(odmips_dpi_header target prefix)
    target_compile_definitions(${target} PRIVATE "ODMIPS_DPI_HEADER=\"${prefix}__Dpi.h\"")
endfunction()

# sets vl_srcs / vl_top / vl_args for a harness built on ${base}
macro(odmips_verilate_inputs base)
    if("${base}" STREQUAL "SOC")
        set(vl_srcs ${SOC_TB_SRCS})
        set(vl_top soc_tb)
        set(vl_args ${SOC_TB_ARGS})
    else()
        set(vl_srcs ${${base}_SRCS})
        set(vl_top ${base})
        set(vl_args)
    endif()
endmacro()

find_package(SDL3)
find_package(PkgConfig REQUIRED)
pkg_check_modules(CAPSTONE REQUIRED capstone)

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

    add_executable(${target_name} common.cpp ${sim_src})
    if(${target}_C_flag)
        target_compile_options(${target_name} PRIVATE ${${target}_C_flag})
    endif()
    if(${target}_linker_flags)
        set_target_properties(${target_name} PROPERTIES LINK_FLAGS "${${target}_linker_flags}")
    endif()
    odmips_verilate_inputs(${base_target})
    if(target IN_LIST SDL3_ENABLED)
        set(LOCAL_VERILATOR_ARGS ${VERILATOR_ARGS} ${vl_args} +define+VGA_ENABLED)
    else()
        set(LOCAL_VERILATOR_ARGS ${VERILATOR_ARGS} ${vl_args})
    endif()

    if(sim_VCD_dump)
        verilate(${target_name}
            SOURCES ${vl_srcs}
            TOP_MODULE ${vl_top}
            PREFIX ${unitCap}_sim
            VERILATOR_ARGS ${LOCAL_VERILATOR_ARGS}
            DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${target}
            TRACE_VCD
        )
        target_compile_definitions(${target_name} PRIVATE TRACE)
    else()
        verilate(${target_name}
            SOURCES ${vl_srcs}
            TOP_MODULE ${vl_top}
            PREFIX ${unitCap}_sim
            VERILATOR_ARGS ${LOCAL_VERILATOR_ARGS}
            DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${target}
        )
    endif()
    odmips_dpi_header(${target_name} ${unitCap}_sim)
    target_include_directories(${target_name} PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/${target})
    if(NOT target IN_LIST CAPSTONE_DISABLED)
        target_link_libraries(${target_name} PRIVATE ${CAPSTONE_LIBRARIES})
        target_include_directories(${target_name} PRIVATE ${CAPSTONE_INCLUDE_DIRS})
    endif()
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

    add_executable(${target_name} common.cpp ${debug_src})
    odmips_verilate_inputs(${base_target})
    verilate(${target_name}
        SOURCES ${vl_srcs}
        TOP_MODULE ${vl_top}
        PREFIX ${unitCap}_debug
        DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${target}
        TRACE_VCD
        VERILATOR_ARGS +define+DEBUG ${VERILATOR_ARGS} ${vl_args}
    )
    odmips_dpi_header(${target_name} ${unitCap}_debug)
    target_link_libraries(${target_name} PRIVATE ${CAPSTONE_LIBRARIES})
    target_include_directories(${target_name} PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/${target} ${CAPSTONE_INCLUDE_DIRS})
    if(target IN_LIST SDL3_ENABLED)
        if(NOT SDL3_FOUND)
            message(FATAL_ERROR "SDL3 not found. Please install SDL3 development files.")
        endif()
        target_include_directories(${target_name} PRIVATE ${SDL3_INCLUDE_DIRS})
        target_link_libraries(${target_name} PRIVATE SDL3::SDL3 ${CAPSTONE_LIBRARIES})
    endif()
endforeach()

# --- debugger_tui ---

find_package(ftxui)

if(NOT ftxui_FOUND)
    message(WARNING "ftxui not found. Please install ftxui development files.")
else()
    add_executable(debugger_tui common.cpp debugger_tui.cpp)
    odmips_verilate_inputs(SOC)
    verilate(debugger_tui
        SOURCES ${vl_srcs}
        TOP_MODULE ${vl_top}
        PREFIX SOC_sim
        DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/debugger_tui
        VERILATOR_ARGS +define+DEBUGGER ${VERILATOR_ARGS} ${vl_args}
    )
    odmips_dpi_header(debugger_tui SOC_sim)

    target_include_directories(debugger_tui
        PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/debugger_tui ${CAPSTONE_INCLUDE_DIRS}
    )
    target_compile_options(debugger_tui PRIVATE -O3 -lto)
    target_link_libraries(debugger_tui
        PRIVATE ftxui::screen
        PRIVATE ftxui::dom
        PRIVATE ftxui::component
        PRIVATE ${CAPSTONE_LIBRARIES}
    )
endif()
