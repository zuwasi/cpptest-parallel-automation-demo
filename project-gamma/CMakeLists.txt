cmake_minimum_required(VERSION 3.16)
project(project_gamma C)

add_executable(project_gamma
    src/main.c
    src/ring_buffer.c
)

target_include_directories(project_gamma PRIVATE include)
