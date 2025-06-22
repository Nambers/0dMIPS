find_package(ftxui)

if(NOT ftxui_FOUND)
    message(WARNING "ftxui not found. Please install ftxui development files.")
else()
    add_executable(debugger_tui tui.cpp)

    verilate(debugger_tui
        SOURCES ${SOC_SRCS}
        TOP_MODULE SOC
        PREFIX SOC_sim
        DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/debugger_tui
        VERILATOR_ARGS +define+DEBUGGER
    )

    target_include_directories(debugger_tui
        PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/debugger_tui
    )
    target_link_libraries(debugger_tui
        PRIVATE ftxui::screen
        PRIVATE ftxui::dom
        PRIVATE ftxui::component
    )
endif()
