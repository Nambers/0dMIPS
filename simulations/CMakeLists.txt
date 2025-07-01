set(SIM_DIR ${CMAKE_SOURCE_DIR}/simulations)

set(VGA_SRCS
    ${SRC_DIR}/modules/configurations.sv
    ${SRC_DIR}/units/VGA.sv
    ${SRC_DIR}/modules/register.sv
)

set(SDL3_ENABLED SOC_VGA VGA)
set(SOC_run_C_flag -O3 -lto)

find_package(SDL3)
# find_package(capstone REQUIRED)
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
    verilate(${target_name}
        SOURCES ${${srclist}}
        TOP_MODULE ${base_target}
        PREFIX ${unitCap}_sim
        DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${target}
        # TRACE_VCD
    )
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
    verilate(${target_name}
        SOURCES ${${srclist}}
        TOP_MODULE ${base_target}
        PREFIX ${unitCap}_debug
        DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${target}
        TRACE_VCD
        VERILATOR_ARGS +define+DEBUG
    )
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
    verilate(debugger_tui
        SOURCES ${SOC_SRCS}
        TOP_MODULE SOC
        PREFIX SOC_sim
        DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/debugger_tui
        VERILATOR_ARGS +define+DEBUGGER
    )

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
