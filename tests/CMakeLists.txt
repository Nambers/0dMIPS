set(UNITS timer cp0 core cache_L1)
set(TEST_DIR ${CMAKE_SOURCE_DIR}/tests)
set(TEST_TARGETS)

set(timer_SRCS
    ${SRC_DIR}/modules/configurations.sv
    ${SRC_DIR}/modules/register.sv
    ${SRC_DIR}/units/timer.sv
)
set(cp0_SRCS
    ${SRC_DIR}/modules/register.sv
    ${SRC_DIR}/modules/mux.sv
    ${SRC_DIR}/units/cp0.sv
)
set(cache_L1_SRCS
    ${SRC_DIR}/modules/structures.sv
    ${SRC_DIR}/units/cache_L1.sv
)

# Replace every explicit 'x (don't-care) with a per-run random value
option(ODMIPS_TEST_X_UNIQUE "Verilate unit tests with --x-assign unique" OFF)
set(ODMIPS_TEST_X_ARGS)
if(ODMIPS_TEST_X_UNIQUE)
    set(ODMIPS_TEST_X_ARGS --x-assign unique --x-initial 0)
endif()

foreach(target IN LISTS UNITS)
    set(_name "${target}")
    capitalize_first(_name unitCap)

    file(GLOB cpps ${TEST_DIR}/${target}_test*.cpp)
    if(NOT cpps)
        message(FATAL_ERROR "No test files found for target ${target}. Please add test files in ${TEST_DIR}.")
    endif()

    add_executable(${target}Test ${cpps} ${TEST_DIR}/test.cpp)
    verilate(${target}Test
        SOURCES ${${target}_SRCS}
        TOP_MODULE ${target}
        PREFIX ${unitCap}
        VERILATOR_ARGS +define+MOCK_STDOUT_ENABLED ${ODMIPS_VERILATOR_WARN_ARGS} ${ODMIPS_TEST_X_ARGS}
        DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${target}
        COVERAGE
    )
    add_test(NAME ${target}Test COMMAND $<TARGET_FILE:${target}Test>)
    target_link_libraries(${target}Test PRIVATE GTest::GTest GTest::Main Threads::Threads)
    target_include_directories(${target}Test PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/${target})
    list(APPEND TEST_TARGETS ${target}Test)
    message(STATUS "Added test target: ${target}Test")
endforeach()

add_custom_target(allTests DEPENDS ${TEST_TARGETS})
