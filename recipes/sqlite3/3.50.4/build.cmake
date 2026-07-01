
cmake_minimum_required(VERSION 3.15)
project(sqlite3 C)

if(GENERATOR_IS_MULTI_CONFIG)
    message(FATAL_ERROR "Multi-config generators are not supported!")
endif()

option(WITH_SQLITE_DEBUG    "Build SQLite debug features" OFF)
option(WITH_SQLITE_MEMDEBUG "Build SQLite memory debug features" OFF)
option(WITH_SQLITE_RTREE    "Build R*Tree index extension" OFF)

find_package(Threads REQUIRED)

if(WITH_SQLITE_DEBUG)
    add_definitions(-DSQLITE_DEBUG)
endif()
if(WITH_SQLITE_MEMDEBUG)
    add_definitions(-DSQLITE_MEMDEBUG)
endif()
if(WITH_SQLITE_RTREE)
    add_definitions(-DSQLITE_ENABLE_RTREE)
endif()

option(USE_MSVC_STATIC_RUNTIME "Link MSVC runtime library statically " OFF)
cmake_policy(SET CMP0091 NEW)

# This is only required to suppress 'replacing /MT with /MD' message while compiling source files.
# Without it, the workaround below (setting runtime options manually) will not work.
if(NOT USE_MSVC_STATIC_RUNTIME)
    set(MSVC_RUNTIME_SUFFIX "DLL")
endif()
if(NOT CMAKE_MSVC_RUNTIME_LIBRARY)
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>${MSVC_RUNTIME_SUFFIX}")
endif()

# For some reason, setting CMAKE_MSVC_RUNTIME_LIBRARY does not work as intended for this project.
# The variable has the correct value, the policy has been set accordingly, and the target properties
# have the same value copied from the global variable. Yet, the compiler still generates binaries
# that dynamically link to the MSVC runtime library. The resulting binaries only include
# the statically linked MSVC runtime library when we manually force the compile options (as below).
if(WIN32)
    if(CMAKE_C_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC")
        if(USE_MSVC_STATIC_RUNTIME)
            if(CMAKE_BUILD_TYPE STREQUAL "Debug")
                set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /MTd")
            else()
                set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /MT")
            endif()
        else()
            if(CMAKE_BUILD_TYPE STREQUAL "Debug")
                set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /MDd")
            else()
                set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /MD")
            endif()
        endif()
    elseif(CMAKE_C_COMPILER_ID MATCHES "Clang")
        if(USE_MSVC_STATIC_RUNTIME)
            if(CMAKE_BUILD_TYPE STREQUAL "Debug")
                set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fms-runtime-lib=static_dbg")
            else()
                set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fms-runtime-lib=static")
            endif()
        else()
            if(CMAKE_BUILD_TYPE STREQUAL "Debug")
                set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fms-runtime-lib=dynamic_dbg")
            else()
                set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fms-runtime-lib=dynamic")
            endif()        
        endif()
    endif()
endif()

include_directories(${CMAKE_SOURCE_DIR})
add_library(sqlite3 sqlite3.c)
target_link_libraries(sqlite3 ${CMAKE_THREAD_LIBS_INIT} ${CMAKE_DL_LIBS})

add_executable(shell shell.c)
target_link_libraries(shell sqlite3)

find_library(M_LIB m)
if(M_LIB)
    add_library(math::m SHARED IMPORTED)
    set_property(TARGET math::m PROPERTY IMPORTED_LOCATION ${M_LIB})
    target_link_libraries(shell math::m)
endif()

set_target_properties(shell PROPERTIES OUTPUT_NAME sqlite3)

set(prefix ${CMAKE_INSTALL_PREFIX})
set(exec_prefix ${CMAKE_INSTALL_PREFIX})
set(libdir ${CMAKE_INSTALL_PREFIX}/lib)
set(includedir ${CMAKE_INSTALL_PREFIX}/include)
get_target_property(LINK_LIBS sqlite3 INTERFACE_LINK_LIBRARIES)
set(LIBS)
foreach(LIB ${LINK_LIBS})
	set(LIB_FLAG "${LIB}")
    if (EXISTS "${LIB}" OR LIB MATCHES "^[-/]")
    else()
	    set(LIB_FLAG "-l${LIB}")
    endif()
    string(APPEND LIBS " ${LIB_FLAG}")
endforeach()
configure_file(sqlite3.pc.in sqlite3.pc @ONLY)

install(FILES sqlite3.h sqlite3ext.h DESTINATION include)
install(FILES ${CMAKE_BINARY_DIR}/sqlite3.pc DESTINATION lib/pkgconfig)
install(TARGETS sqlite3 DESTINATION lib)
install(TARGETS shell DESTINATION bin)
