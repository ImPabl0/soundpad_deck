cmake_minimum_required(VERSION 3.20)
project(soundpad_deck_cpp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_executable(soundpad_deck WIN32
    api/main.cpp
    api/api_icon.rc
)

target_compile_definitions(soundpad_deck PRIVATE
    UNICODE
    _UNICODE
    WIN32_LEAN_AND_MEAN
    NOMINMAX
)

target_link_libraries(soundpad_deck PRIVATE
    ws2_32
    shell32
)