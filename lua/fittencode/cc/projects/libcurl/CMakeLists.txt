cmake_minimum_required(VERSION 3.10)

# Project name
project(libcurl LANGUAGES CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find Lua
# find_package(Lua51 REQUIRED)
# find_package(Luajit REQUIRED)

# Find the libcurl package
find_package(CURL REQUIRED)

include_directories(${LUA51_INCLUDE_DIR})

# Add the MD5 source file
file(GLOB SOURCES ./src/**.cc)
SET(libcurl ${SOURCES})

# Create the shared library
add_library(libcurl SHARED ${SOURCES})

# Set the prefix for shared libraries to an empty string
set(CMAKE_SHARED_LIBRARY_PREFIX "")

# Link the library with Lua
target_link_libraries(libcurl PRIVATE ${LUA51_LIBRARIES})

# Link the library with libcurl
target_link_libraries(libcurl PRIVATE ${CURL_LIBRARIES})

# 获取当前目录的完整路径
get_filename_component(CURRENT_DIR "${CMAKE_CURRENT_SOURCE_DIR}" ABSOLUTE)

# 创建一个包含路径的字符串
set(CPATH_CONTENT "return \"${CURRENT_DIR}/libcurl.so\"")

# 将内容写入 cpath.lua 文件
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/cpath.lua.in
    ${CMAKE_CURRENT_SOURCE_DIR}/cpath.lua
    @ONLY
)

SET(CMAKE_C_FLAGS  "-pipe -fPIC -Wall -fmessage-length=0")