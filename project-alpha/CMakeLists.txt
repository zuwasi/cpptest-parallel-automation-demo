cmake_minimum_required(VERSION 3.16)
project(project_alpha C)

add_executable(project_alpha
    src/main.c
    src/statistics.c
)

target_include_directories(project_alpha PRIVATE include)
