# CMakeLists.txt - CMake configuration file for ssse3_test

# Copyright (c) 2013 Alex Marsev

# This code is released under the libpng license.
# For conditions of distribution and use, see the disclaimer
# and license in png.h

cmake_minimum_required(VERSION 2.8.4)

find_package(ZLIB REQUIRED)
include_directories(${ZLIB_INCLUDE_DIR})

# Use the prebuilt pnglibconf.h file from the scripts folder
configure_file(../../scripts/pnglibconf.h.prebuilt
	${CMAKE_CURRENT_BINARY_DIR}/pnglibconf.h)
include_directories(${CMAKE_CURRENT_BINARY_DIR})

find_program(CMAKE_ASM_NASM_COMPILER yasm)
if(NOT CMAKE_ASM_NASM_COMPILER)
	message(FATAL_ERROR "YASM was not found")
endif()

if(CMAKE_SIZEOF_VOID_P EQUAL 8)
	set(TARGET_64BIT ON)
	set(CMAKE_ASM_NASM_FLAGS_INIT "${CMAKE_ASM_NASM_FLAGS_INIT} -D__x86_64__")
else()
	set(TARGET_64BIT OFF)
endif()

if(WIN32)
	set(CMAKE_ASM_NASM_FLAGS_INIT "${CMAKE_ASM_NASM_FLAGS_INIT} -D_WINDOWS")
	if (NOT TARGET_64BIT)
		set(CMAKE_ASM_NASM_FLAGS_INIT "${CMAKE_ASM_NASM_FLAGS_INIT} --prefix=_")
	endif()
else()
	find_library(LIBRT rt)
	find_library(LIBM m)
endif()

enable_language(ASM_NASM)
message(STATUS "YASM flags: ${CMAKE_ASM_NASM_FLAGS_INIT}")

set(pngssse3_test_sources ssse3_test.c
	../../ssse3/filter_ssse3.asm
	../../pngmem.c
	../../pngset.c
	../../pngerror.c
	../../png.c
	../../pngrtran.c
	../../pngtrans.c
	../../pngrio.c
)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../..)
add_executable(pngssse3_test ${pngssse3_test_sources})
target_link_libraries(pngssse3_test ${ZLIB_LIBRARY} ${LIBRT} ${LIBM})
