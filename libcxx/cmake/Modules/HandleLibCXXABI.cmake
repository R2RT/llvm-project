#===============================================================================
# Define targets for linking against the selected ABI library
#
# After including this file, the following targets are defined:
# - libcxx-abi-headers: An interface target that allows getting access to the
#                       headers of the selected ABI library.
# - libcxx-abi-shared: A target representing the selected shared ABI library.
# - libcxx-abi-static: A target representing the selected static ABI library.
#===============================================================================

include(GNUInstallDirs)

# This function copies the provided headers to a private directory and adds that
# path to the given INTERFACE target. That target can then be linked against to
# get access to those headers (and only those).
#
# The problem this solves is that when building against a system-provided ABI library,
# the ABI headers might live side-by-side with an actual C++ Standard Library
# installation. For that reason, we can't just add `-I <path-to-ABI-headers>`,
# since we would end up also adding the system-provided C++ Standard Library to
# the search path. Instead, what we do is copy just the ABI library headers to
# a private directory and add just that path when we build libc++.
function(import_private_headers target include_dirs headers)
  foreach(header ${headers})
    set(found FALSE)
    foreach(incpath ${include_dirs})
      if (EXISTS "${incpath}/${header}")
        set(found TRUE)
        message(STATUS "Looking for ${header} in ${incpath} - found")
        get_filename_component(dstdir ${header} PATH)
        get_filename_component(header_file ${header} NAME)
        set(src ${incpath}/${header})
        set(dst "${LIBCXX_BINARY_DIR}/private-abi-headers/${dstdir}/${header_file}")

        add_custom_command(OUTPUT ${dst}
            DEPENDS ${src}
            COMMAND ${CMAKE_COMMAND} -E make_directory "${LIBCXX_BINARY_DIR}/private-abi-headers/${dstdir}"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different ${src} ${dst}
            COMMENT "Copying C++ ABI header ${header}")
        list(APPEND abilib_headers "${dst}")
      else()
        message(STATUS "Looking for ${header} in ${incpath} - not found")
      endif()
    endforeach()
    if (NOT found)
      message(WARNING "Failed to find ${header} in ${include_dirs}")
    endif()
  endforeach()

  # Work around https://gitlab.kitware.com/cmake/cmake/-/issues/18399
  add_library(${target}-generate-private-headers OBJECT ${abilib_headers})
  set_target_properties(${target}-generate-private-headers PROPERTIES LINKER_LANGUAGE CXX)

  target_link_libraries(${target} INTERFACE ${target}-generate-private-headers)
  target_include_directories(${target} INTERFACE "${LIBCXX_BINARY_DIR}/private-abi-headers")
endfunction()

# This function creates an imported library named <target> of the given <kind> (SHARED|STATIC).
# It imports a library named <name> searched at the given <path>.
function(imported_library target kind path name)
  add_library(${target} ${kind} IMPORTED GLOBAL)
  set(libnames "${CMAKE_${kind}_LIBRARY_PREFIX}${name}${CMAKE_${kind}_LIBRARY_SUFFIX}")
  # Make sure we find .tbd files on macOS
  if (kind STREQUAL "SHARED")
    list(APPEND libnames "${CMAKE_${kind}_LIBRARY_PREFIX}${name}.tbd")
  endif()
  find_library(file
    NAMES ${libnames}
    PATHS "${path}"
    NO_CACHE)
  set_target_properties(${target} PROPERTIES IMPORTED_LOCATION "${file}")
endfunction()

# Link against a system-provided libstdc++
if ("${LIBCXX_CXX_ABI}" STREQUAL "libstdc++")
  add_library(libcxx-abi-headers INTERFACE)
  import_private_headers(libcxx-abi-headers "${LIBCXX_CXX_ABI_INCLUDE_PATHS}"
    "cxxabi.h;bits/c++config.h;bits/os_defines.h;bits/cpu_defines.h;bits/cxxabi_tweaks.h;bits/cxxabi_forced.h")
  target_compile_definitions(libcxx-abi-headers INTERFACE "-DLIBSTDCXX" "-D__GLIBCXX__")

  imported_library(libcxx-abi-shared SHARED "${LIBCXX_CXX_ABI_LIBRARY_PATH}" stdc++)
  target_link_libraries(libcxx-abi-shared INTERFACE libcxx-abi-headers)

  imported_library(libcxx-abi-static STATIC "${LIBCXX_CXX_ABI_LIBRARY_PATH}" stdc++)
  target_link_libraries(libcxx-abi-static INTERFACE libcxx-abi-headers)

# Link against a system-provided libsupc++
elseif ("${LIBCXX_CXX_ABI}" STREQUAL "libsupc++")
  add_library(libcxx-abi-headers INTERFACE)
  import_private_headers(libcxx-abi-headers "${LIBCXX_CXX_ABI_INCLUDE_PATHS}"
    "cxxabi.h;bits/c++config.h;bits/os_defines.h;bits/cpu_defines.h;bits/cxxabi_tweaks.h;bits/cxxabi_forced.h")
  target_compile_definitions(libcxx-abi-headers INTERFACE "-D__GLIBCXX__")

  imported_library(libcxx-abi-shared SHARED "${LIBCXX_CXX_ABI_LIBRARY_PATH}" supc++)
  target_link_libraries(libcxx-abi-shared INTERFACE libcxx-abi-headers)

  imported_library(libcxx-abi-static STATIC "${LIBCXX_CXX_ABI_LIBRARY_PATH}" supc++)
  target_link_libraries(libcxx-abi-static INTERFACE libcxx-abi-headers)

# Link against the in-tree libc++abi
elseif ("${LIBCXX_CXX_ABI}" STREQUAL "libcxxabi")
  add_library(libcxx-abi-headers INTERFACE)
  target_link_libraries(libcxx-abi-headers INTERFACE cxxabi-headers)
  target_compile_definitions(libcxx-abi-headers INTERFACE "-DLIBCXX_BUILDING_LIBCXXABI")

  if (TARGET cxxabi_shared)
    add_library(libcxx-abi-shared ALIAS cxxabi_shared)
  endif()

  if (TARGET cxxabi_static)
    add_library(libcxx-abi-static ALIAS cxxabi_static)
  endif()

# Link against a system-provided libc++abi
elseif ("${LIBCXX_CXX_ABI}" STREQUAL "system-libcxxabi")
  add_library(libcxx-abi-headers INTERFACE)
  import_private_headers(libcxx-abi-headers "${LIBCXX_CXX_ABI_INCLUDE_PATHS}" "cxxabi.h;__cxxabi_config.h")
  target_compile_definitions(libcxx-abi-headers INTERFACE "-DLIBCXX_BUILDING_LIBCXXABI")

  imported_library(libcxx-abi-shared SHARED "${LIBCXX_CXX_ABI_LIBRARY_PATH}" c++abi)
  target_link_libraries(libcxx-abi-shared INTERFACE libcxx-abi-headers)

  imported_library(libcxx-abi-static STATIC "${LIBCXX_CXX_ABI_LIBRARY_PATH}" c++abi)
  target_link_libraries(libcxx-abi-static INTERFACE libcxx-abi-headers)

# Link against a system-provided libcxxrt
elseif ("${LIBCXX_CXX_ABI}" STREQUAL "libcxxrt")
  # libcxxrt does not provide aligned new and delete operators
  # TODO: We're keeping this for backwards compatibility, but this doesn't belong here.
  set(LIBCXX_ENABLE_NEW_DELETE_DEFINITIONS ON)

  if(NOT LIBCXX_CXX_ABI_INCLUDE_PATHS)
    message(STATUS "LIBCXX_CXX_ABI_INCLUDE_PATHS not set, using /usr/include/c++/v1")
    set(LIBCXX_CXX_ABI_INCLUDE_PATHS "/usr/include/c++/v1")
  endif()
  add_library(libcxx-abi-headers INTERFACE)
  import_private_headers(libcxx-abi-headers "${LIBCXX_CXX_ABI_INCLUDE_PATHS}"
    "cxxabi.h;unwind.h;unwind-arm.h;unwind-itanium.h")
  target_compile_definitions(libcxx-abi-headers INTERFACE "-DLIBCXXRT")

  imported_library(libcxx-abi-shared SHARED "${LIBCXX_CXX_ABI_LIBRARY_PATH}" cxxrt)
  target_link_libraries(libcxx-abi-shared INTERFACE libcxx-abi-headers)

  imported_library(libcxx-abi-static STATIC "${LIBCXX_CXX_ABI_LIBRARY_PATH}" cxxrt)
  target_link_libraries(libcxx-abi-static INTERFACE libcxx-abi-headers)

# Link against a system-provided vcruntime
# FIXME: Figure out how to configure the ABI library on Windows.
elseif ("${LIBCXX_CXX_ABI}" STREQUAL "vcruntime")
  add_library(libcxx-abi-headers INTERFACE)
  add_library(libcxx-abi-shared INTERFACE)
  add_library(libcxx-abi-static INTERFACE)

# Don't link against any ABI library
elseif ("${LIBCXX_CXX_ABI}" STREQUAL "none")
  add_library(libcxx-abi-headers INTERFACE)
  target_compile_definitions(libcxx-abi-headers INTERFACE "-D_LIBCPP_BUILDING_HAS_NO_ABI_LIBRARY")

  add_library(libcxx-abi-shared INTERFACE)
  target_link_libraries(libcxx-abi-shared INTERFACE libcxx-abi-headers)

  add_library(libcxx-abi-static INTERFACE)
  target_link_libraries(libcxx-abi-static INTERFACE libcxx-abi-headers)
endif()
