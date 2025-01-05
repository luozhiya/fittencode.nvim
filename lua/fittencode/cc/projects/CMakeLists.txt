cmake_minimum_required(VERSION 3.10)

# Project name
project(hash LANGUAGES C)

# Find Lua
find_package(Lua51 REQUIRED)

include_directories(${LUA_INCLUDE_DIR})
message(STATUS "Lua include directory: ${LUA_INCLUDE_DIR}")

# Add the MD5 source file
file(GLOB SOURCES ./src/**.c)
SET(hash ${SOURCES})

# Create the shared library
add_library(hash SHARED ${SOURCES})

# Specify the output name of the shared library
# set_target_properties(hash PROPERTIES OUTPUT_NAME "hash")
# Set the prefix for shared libraries to an empty string
set(CMAKE_SHARED_LIBRARY_PREFIX "")

# Set C standards
set_target_properties(hash PROPERTIES
    C_STANDARD 99
    C_STANDARD_REQUIRED YES
)

# Link the library with Lua
# target_link_libraries(hash PRIVATE Lua51::Lua)
target_link_libraries(hash PRIVATE ${LUA_LIBRARIES})

# 获取当前目录的完整路径
get_filename_component(CURRENT_DIR "${CMAKE_CURRENT_SOURCE_DIR}" ABSOLUTE)

# 创建一个包含路径的字符串
set(CPATH_CONTENT "return \"${CURRENT_DIR}/hash.so\"")

# 将内容写入 cpath.lua 文件
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/cpath.lua.in
    ${CMAKE_CURRENT_SOURCE_DIR}/cpath.lua
    @ONLY
)
