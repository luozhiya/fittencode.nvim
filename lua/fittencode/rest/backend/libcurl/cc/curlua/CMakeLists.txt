cmake_minimum_required(VERSION 3.25)
project(curlua)

set(CMAKE_BUILD_TYPE Debug)

find_package(CURL REQUIRED)
find_package(Lua51 REQUIRED)

set(SOURCES
    exports.c
    implementation.cc
)

# Add executable
# add_executable(curlua ${SOURCES})
add_library(curlua SHARED ${SOURCES})

target_include_directories(curlua
    PRIVATE
        ${PROJECT_SOURCE_DIR}
)

# Link against libcurl
target_link_libraries(curlua ${CURL_LIBRARIES})
