set(UNITS alu timer cp0 core)
set(TEST_DIR ${CMAKE_SOURCE_DIR}/tests)

set(alu_SRCS
    ${SRC_DIR}/modules/mux.sv
    ${SRC_DIR}/modules/adder.sv
    ${SRC_DIR}/units/au.sv
    ${SRC_DIR}/units/lu.sv
    ${SRC_DIR}/units/alu.sv
)
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

foreach(target IN LISTS UNITS)
    set(_name "${target}")
    capitalize_first(_name unitCap)

    file(GLOB cpps ${TEST_DIR}/${target}_test*.cpp)

    add_executable(${target}Test ${cpps} ${TEST_DIR}/test.cpp)
    verilate(${target}Test
        SOURCES ${${target}_SRCS}
        TOP_MODULE ${target}
        PREFIX ${unitCap}
        DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${target}
        COVERAGE
    )
    add_test(NAME ${target}Test COMMAND $<TARGET_FILE:${target}Test>)
    target_link_libraries(${target}Test PRIVATE GTest::GTest GTest::Main Threads::Threads)
    target_include_directories(${target}Test PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/${target})
endforeach()
