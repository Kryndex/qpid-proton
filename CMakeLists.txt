#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
cmake_minimum_required (VERSION 2.8.12)

project (Proton C)

# Enable testing
enable_testing()
include (CTest)

# Pull in local cmake modules
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/tools/cmake/Modules/")

include (CheckLanguage)
check_language(CXX)
if (CMAKE_CXX_COMPILER)
  enable_language(CXX)
endif()

# TODO - Should change this test to take account of recent MSVC that does support C99
if (MSVC)
  # No C99 capability, use C++
  set(DEFAULT_BUILD_WITH_CXX ON)
endif (MSVC)

if (CMAKE_CXX_COMPILER)
  option(BUILD_WITH_CXX "Compile Proton using C++" ${DEFAULT_BUILD_WITH_CXX})
endif()

if (CMAKE_CONFIGURATION_TYPES)
  # There is no single "build type"...
  message(STATUS "Build types are ${CMAKE_CONFIGURATION_TYPES}")
else (CMAKE_CONFIGURATION_TYPES)
  # There is a single build configuration
  # If the build type is not set then set the default
  if (NOT CMAKE_BUILD_TYPE)
  set (CMAKE_BUILD_TYPE RelWithDebInfo CACHE string
       "Build type: Debug, Release, RelWithDebInfo, MinSizeRel or Coverage (default RelWithDebInfo)" FORCE)
  endif ()

  # Set up extra coverage analysis options for gcc and clang
  if (CMAKE_COMPILER_IS_GNUCC)
    set (CMAKE_C_FLAGS_COVERAGE "-g -O0 --coverage")
    set (CMAKE_CXX_FLAGS_COVERAGE "-g -O0 --coverage")
    set (CMAKE_EXE_LINKER_FLAGS_COVERAGE "--coverage")
    set (CMAKE_MODULE_LINKER_FLAGS_COVERAGE "--coverage")
    set (CMAKE_SHARED_LINKER_FLAGS_COVERAGE "--coverage")
    mark_as_advanced(
      CMAKE_C_FLAGS_COVERAGE CMAKE_CXX_FLAGS_COVERAGE
      CMAKE_EXE_LINKER_FLAGS_COVERAGE CMAKE_MODULE_LINKER_FLAGS_COVERAGE
      CMAKE_SHARED_LINKER_FLAGS_COVERAGE)
  endif()

  if (CMAKE_BUILD_TYPE MATCHES "Deb")
    set (has_debug_symbols " (has debug symbols)")
  endif (CMAKE_BUILD_TYPE MATCHES "Deb")
  message(STATUS "Build type is \"${CMAKE_BUILD_TYPE}\"${has_debug_symbols}")
endif (CMAKE_CONFIGURATION_TYPES)

# Add coverage target if we're building for test coverage
if (CMAKE_BUILD_TYPE MATCHES "Coverage")
  make_directory(coverage_results)
  add_custom_target(coverage
    WORKING_DIRECTORY ./coverage_results
    COMMAND ${CMAKE_SOURCE_DIR}/bin/record-coverage.sh ${CMAKE_SOURCE_DIR} ${CMAKE_BINARY_DIR})
endif()

if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
  if (NOT CMAKE_OSX_ARCHITECTURES)
    set(CMAKE_OSX_ARCHITECTURES "x86_64")
    set(LIB_SUFFIX "")
    set(CMAKE_MACOSX_RPATH ON)
  endif ()
endif ()

file(READ version.txt PN_VERSION_FILE)
string(STRIP ${PN_VERSION_FILE} PN_VERSION_LINE)
string(REPLACE "-" ";" PN_VERSION_SPLIT "${PN_VERSION_LINE}")
list(GET PN_VERSION_SPLIT 0 PN_VERSION_CLEAN)
list(REMOVE_AT PN_VERSION_SPLIT 0)
string(REPLACE ";" "-" PN_VERSION_QUALIFIER "${PN_VERSION_SPLIT}")
string(REGEX MATCHALL "[0-9]+" PN_VERSION_LIST "${PN_VERSION_CLEAN}")

list(GET PN_VERSION_LIST 0 PN_VERSION_MAJOR)
list(GET PN_VERSION_LIST 1 PN_VERSION_MINOR)

list(LENGTH PN_VERSION_LIST PN_VERSION_LENGTH)
if (${PN_VERSION_LENGTH} GREATER 2)
  list(GET PN_VERSION_LIST 2 PN_VERSION_POINT)
  set (PN_VERSION "${PN_VERSION_MAJOR}.${PN_VERSION_MINOR}.${PN_VERSION_POINT}")
else()
  set (PN_VERSION_POINT 0)
  set (PN_VERSION "${PN_VERSION_MAJOR}.${PN_VERSION_MINOR}")
endif()

message(STATUS "PN_VERSION: ${PN_VERSION} (${PN_VERSION_QUALIFIER})")

set (pn_test_root "${CMAKE_CURRENT_SOURCE_DIR}/tests")
set (pn_test_bin "${CMAKE_CURRENT_BINARY_DIR}/tests")

# In rpm builds the build sets some variables:
#  CMAKE_INSTALL_PREFIX - this is a standard cmake variable
#  INCLUDE_INSTALL_DIR
#  LIB_INSTALL_DIR
#  SYSCONF_INSTALL_DIR
#  SHARE_INSTALL_DIR
# So make these cached variables and the specific variables non cached
# and derived from them.

if (NOT DEFINED LIB_SUFFIX)
    get_property(LIB64 GLOBAL PROPERTY FIND_LIBRARY_USE_LIB64_PATHS)
    if ("${LIB64}" STREQUAL "TRUE" AND ${CMAKE_SIZEOF_VOID_P} STREQUAL "8")
        set(LIB_SUFFIX 64)
    else()
        set(LIB_SUFFIX "")
    endif()
endif()

# Start of variables used during install
set (INCLUDE_INSTALL_DIR include CACHE PATH "Include file directory")
set (LIB_INSTALL_DIR "lib${LIB_SUFFIX}" CACHE PATH "Library object file directory")
set (SYSCONF_INSTALL_DIR etc CACHE PATH "System read only configuration directory")
set (SHARE_INSTALL_DIR share CACHE PATH "Shared read only data directory")
set (MAN_INSTALL_DIR share/man CACHE PATH "Manpage directory")

mark_as_advanced (INCLUDE_INSTALL_DIR LIB_INSTALL_DIR SYSCONF_INSTALL_DIR SHARE_INSTALL_DIR MAN_INSTALL_DIR)

## LANGUAGE BINDINGS

# Default directory for language bindings not being installed into
# system specified locations.
set (BINDINGS_DIR ${LIB_INSTALL_DIR}/proton/bindings)

set (SYSINSTALL_BINDINGS OFF CACHE BOOL "If SYSINSTALL_BINDINGS is OFF then proton bindings will be installed underneath ${BINDINGS_DIR} and each user will need to modify their interpreter configuration to load the appropriate binding. If SYSINSTALL_BINDINGS is ON, then each language interpreter will be queried for the appropriate directory and proton bindings will be installed and available system wide with no additional per user configuration.")

set (BINDING_LANGS PERL PHP PYTHON RUBY)

foreach (LANG ${BINDING_LANGS})
  set (SYSINSTALL_${LANG} OFF CACHE BOOL "Install ${LANG} bindings into interpreter specified location.")
  if (SYSINSTALL_BINDINGS OR SYSINSTALL_${LANG})
    set (CHECK_SYSINSTALL_${LANG} ON)
  else ()
    set (CHECK_SYSINSTALL_${LANG} OFF)
  endif ()
endforeach()

set (PROTON_SHARE ${SHARE_INSTALL_DIR}/proton-${PN_VERSION})
# End of variables used during install

# Can't do valgrind and coverage at athe same time - coverage takes precedence
if (CMAKE_BUILD_TYPE MATCHES "Coverage")
  message(STATUS "Building for coverage analysis; no run-time error detection")
else ()
  # Check for valgrind here so tests under proton-c/ and examples/ can use it.
  find_program(VALGRIND_EXECUTABLE valgrind DOC "Location of the valgrind program")
  mark_as_advanced (VALGRIND_EXECUTABLE)

  option(ENABLE_VALGRIND "Use valgrind to detect run-time problems" ON)
  if (ENABLE_VALGRIND)
    if (VALGRIND_EXECUTABLE)
      set (VALGRIND_SUPPRESSIONS ${CMAKE_SOURCE_DIR}/proton-c/src/tests/valgrind.supp CACHE STRING "Default valgrind suppressions")
      set (VALGRIND_OPTIONS "--error-exitcode=42 --quiet --leak-check=full --trace-children=yes" CACHE STRING "Default valgrind options")
      mark_as_advanced(VALGRIND_SUPPRESSIONS VALGRIND_OPTIONS)
      set (VALGRIND_ENV "VALGRIND=${VALGRIND_EXECUTABLE}" "VALGRIND_ARGS=${VALGRIND_OPTIONS} --suppressions=${VALGRIND_SUPPRESSIONS}")
      separate_arguments(VALGRIND_OPTIONS_LIST UNIX_COMMAND ${VALGRIND_OPTIONS})
      set (memcheck-cmd ${VALGRIND_EXECUTABLE} ${VALGRIND_OPTIONS_LIST} "--suppressions=${VALGRIND_SUPPRESSIONS}")
    else ()
      message(STATUS "Can't locate the valgrind command; no run-time error detection")
    endif ()
  endif ()
endif ()

# Options to enable sanitizing compile flags. Compile flags are set in proton-c/CMakeLists.txt
option(ENABLE_SANITIZERS "Compile with sanitizers (ASan, UBSan, TSan); incompatible with Valgrind" OFF)
option(ENABLE_TSAN "Compile with Thread Sanitizer (TSan); incompatible with Valgrind" OFF)
if (ENABLE_SANITIZERS OR ENABLE_TSAN)
  set(DISABLE ENABLE_VALGRIND ENABLE_UNDEFINED_ERROR BUILD_GO)
  message(STATUS "Building with sanitizers; disables ${DISABLE}")
  foreach(d ${DISABLE})
    set(${d} OFF CACHE BOOL "Disabled to run sanitizers" FORCE)
  endforeach()
  unset(VALGRIND_ENV)
endif()

# Set result to a native search path - used by examples and binding tests.
# args after result are directories or search paths.
macro(set_search_path result)
  set(${result} ${ARGN})
  if (UNIX)
    string(REPLACE ";" ":" ${result} "${${result}}") # native search path separators.
  endif()
  file(TO_NATIVE_PATH "${${result}}" ${result}) # native slash separators
endmacro()

add_subdirectory(proton-c)
add_subdirectory(examples)

install (FILES LICENSE README.md
         DESTINATION ${PROTON_SHARE})

# Generate test environment settings
configure_file(${CMAKE_SOURCE_DIR}/config.sh.in
               ${CMAKE_BINARY_DIR}/config.sh @ONLY)
configure_file(${CMAKE_SOURCE_DIR}/config.bat.in
               ${CMAKE_BINARY_DIR}/config.bat @ONLY)
