cmake_minimum_required(VERSION 3.22.1)
project(simpleble_preload C)

# See simpleble_preload.c for why this exists.
add_library(simpleble_preload SHARED simpleble_preload.c)
target_link_libraries(simpleble_preload log dl)
