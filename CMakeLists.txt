cmake_minimum_required(VERSION 3.20)
project(ContextHandler LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Static-link the CRT so the handler has no VC++ redist dependency when loaded
# inside the packaged COM surrogate.
cmake_policy(SET CMP0091 NEW)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

add_library(ContextHandler SHARED
    src/dllmain.cpp
    src/ContextCommand.cpp
    src/TerminalLauncher.cpp
    src/ContextHandler.def
)

set_target_properties(ContextHandler PROPERTIES
    OUTPUT_NAME "ContextHandler"
    PREFIX ""                       # no "lib" prefix
)

target_compile_definitions(ContextHandler PRIVATE
    UNICODE
    _UNICODE
    WIN32_LEAN_AND_MEAN
)

# Comctl32 v6 (for TaskDialog) is provided by Explorer's activation context when
# the DLL is hosted; link the import libs we use directly.
target_link_libraries(ContextHandler PRIVATE
    shlwapi
)

# Placeholder exe required by the sparse package's <Application> element.
add_executable(TerminalContextStub src/stub.cpp)
set_target_properties(TerminalContextStub PROPERTIES OUTPUT_NAME "TerminalContextStub")
