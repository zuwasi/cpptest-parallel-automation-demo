cmake_minimum_required(VERSION 3.16)
project(project_beta C)

add_executable(project_beta
    src/main.c
    src/text_utils.c
)

target_include_directories(project_beta PRIVATE include)
