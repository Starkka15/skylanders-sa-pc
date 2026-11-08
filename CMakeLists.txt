# skylanders_sa - ReXGlue Recompiled Project
#
# SDK boilerplate lives in generated/rexglue.cmake.

cmake_minimum_required(VERSION 3.25)
project(skylanders_sa LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(generated/rexglue.cmake)

# Sources
set(SKYLANDERSSA_SOURCES
    src/main.cpp
    src/shadow_fix.cpp
)

if(WIN32)
    add_executable(skylanders_sa WIN32 ${SKYLANDERSSA_SOURCES})
else()
    add_executable(skylanders_sa ${SKYLANDERSSA_SOURCES})
endif()

rexglue_setup_target(skylanders_sa GPU_PLUGINS xenos)
