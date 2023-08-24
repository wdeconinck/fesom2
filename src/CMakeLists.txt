cmake_minimum_required(VERSION 3.9)

project(fesom LANGUAGES C CXX Fortran VERSION 2.5)

message("[${PROJECT_NAME}]")

### Setup project

set(BUILD_SHARED_LIBS ON CACHE BOOL "Default to using shared libs")
set(CMAKE_LINK_DEPENDS_NO_SHARED ON) # relink of downstream libraries not required when shared library is rebuilt

# Default build type: Release
set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Choose the type of build, options are: None(CMAKE_CXX_FLAGS or CMAKE_C_FLAGS used) Debug Release RelWithDebInfo MinSizeRel.")

# Set location to look for find_package modules
set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/../cmake ${CMAKE_MODULE_PATH})

# Set Fortran module directory
set(CMAKE_Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/module/${PROJECT_NAME} )

# Set -fPIC flag etc.
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Build-dir destinations
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

if(DEFINED ENV{FESOM_PLATFORM_STRATEGY})
   set(FESOM_PLATFORM_STRATEGY $ENV{FESOM_PLATFORM_STRATEGY} CACHE STRING "switch to platform specific compile settings, this is usually determined via the env.sh script")
else()
   set(FESOM_PLATFORM_STRATEGY "notset" CACHE STRING "switch to platform specific compile settings, this is usually determined via the env.sh script")
endif()

if(DEFINED ENV{ENABLE_ALEPH_CRAYMPICH_WORKAROUNDS}) # be able to set the initial cache value from our env settings for aleph, not only via cmake command
   option(ALEPH_CRAYMPICH_WORKAROUNDS "workaround for performance issues on aleph" ON)
else()
   option(ALEPH_CRAYMPICH_WORKAROUNDS "workaround for performance issues on aleph" OFF)
endif()
if(DEFINED ENV{ENABLE_ALBEDO_INTELMPI_WORKAROUNDS}) # be able to set the initial cache value from our env settings for aleph, not only via cmake command
   option(ALBEDO_INTELMPI_WORKAROUNDS "workaround for performance issues on albedo" ON)
else()
   option(ALBEDO_INTELMPI_WORKAROUNDS "workaround for performance issues on albedo" OFF)
endif()


if(ALEPH_CRAYMPICH_WORKAROUNDS)
   # todo: enable these options only for our targets
   add_compile_options(-craympich-mt) # alternative cray-mpich library, about 5 % faster with cray-mpich/7.7.3 on aleph, not available for modules cray-mpich > 7.7.3; todo: test compiling and performance with cray-mpich > 7.7.3
   # make sure to also set these variables in the runtime environment:
   #    MPICH_MAX_THREAD_SAFETY=multiple # allows highest MPI thread level (i.e. MPI_THREAD_MULTIPLE)
   #    MPICH_CRAY_OPT_THREAD_SYNC=0 # the Cray MPICH library falls back to using the pthread_mutex-based thread-synchronization implementation
   #    MPICH_OPT_THREAD_SYNC=0 # seems to be a duplicate variable which also appears in some documentation instead of MPICH_CRAY_OPT_THREAD_SYNC (but this one brings a huge speed gain on aleph)
   #add_compile_options(-DDISABLE_PARALLEL_RESTART_READ) # reading restarts is slow when doing it on parallel on aleph, switch it off for now
   add_compile_options(-DENABLE_ALEPH_CRAYMPICH_WORKAROUNDS)
endif()
if(ALBEDO_INTELMPI_WORKAROUNDS)
   add_compile_options(-DENABLE_ALBEDO_INTELMPI_WORKAROUNDS)
   add_compile_options(-DDISABLE_PARALLEL_RESTART_READ)
endif()

if(${FESOM_PLATFORM_STRATEGY} STREQUAL  levante.dkrz.de )
   message(STATUS "multithreading disabled for Levante") # multithreading suddenly produces an error, disable it until a fix is found. issue #413
   option(DISABLE_MULTITHREADING "disable asynchronous operations" ON)
elseif(${FESOM_PLATFORM_STRATEGY} STREQUAL  albedo )
   message(STATUS "multithreading disabled for Albedo") # multithreading suddenly produces an error, disable it until a fix is found. issue #413
   option(DISABLE_MULTITHREADING "disable asynchronous operations" ON)
else()
   option(DISABLE_MULTITHREADING "disable asynchronous operations" OFF)
endif()
message(STATUS "DISABLE_MULTITHREADING: ${DISABLE_MULTITHREADING}")


option(ENABLE_OPENACC "compile with OpenACC support" OFF)
message(STATUS "ENABLE_OPENACC: ${ENABLE_OPENACC}")
set(NV_GPU_ARCH "cc80" CACHE STRING "GPU arch for nvfortran compiler (cc35,cc50,cc60,cc70,cc80,...)")

option(ENABLE_OPENMP "build FESOM with OpenMP" OFF)
message(STATUS "ENABLE_OPENMP: ${ENABLE_OPENMP}")
if(${ENABLE_OPENMP})
   find_package(OpenMP REQUIRED)
endif()

option(USE_ICEPACK "Use ICEPACK" OFF)
message(STATUS "USE_ICEPACK: ${USE_ICEPACK}")

find_package( NETCDF REQUIRED COMPONENTS C Fortran )
find_package( MPI REQUIRED COMPONENTS C Fortran )


option(ENABLE_IFS_INTERFACE "Enable IFS interface" OFF)
if(DEFINED FESOM_ENABLE_IFS_INTERFACE)
  set(ENABLE_IFS_INTERFACE ${FESOM_ENABLE_IFS_INTERFACE}) # To distinguish option in a nested cmake project (bundle)
endif()
message(STATUS "ENABLE_IFS_INTERFACE: ${ENABLE_IFS_INTERFACE}")
if(ENABLE_IFS_INTERFACE)
  if(USE_ICEPACK)
    message(FATAL_ERROR "Could not enable IFS interface as it is incompatible with USE_ICEPACK")
  endif()
endif()

option(ENABLE_MULTIO "Enable MultIO" OFF)
if(DEFINED FESOM_ENABLE_MULTIO)
  set(ENABLE_MULTIO ${FESOM_ENABLE_MULTIO}) # To distinguish option in a nested cmake project (bundle)
endif()
message(STATUS "ENABLE_MULTIO: ${ENABLE_MULTIO}")
if(ENABLE_MULTIO)
  find_package(multio)
  if(NOT multio_FOUND)
    message(FATAL_ERROR "Could not enable multio as multio could not be found")
  endif()
  if(NOT TARGET multio-fapi)
    message(FATAL_ERROR "Could not enable multio as multio was not compiled with 'multio-fapi' target")
  endif()
endif()

# get our source files
set(src_home ${CMAKE_CURRENT_SOURCE_DIR}) # path to src directory starting from the dir containing our CMakeLists.txt
if(${USE_ICEPACK})
   file(GLOB sources_Fortran ${src_home}/*.F90
                             ${src_home}/icepack_drivers/*.F90
                             ${src_home}/icepack_drivers/Icepack/columnphysics/*.F90)
elseif(ENABLE_IFS_INTERFACE)
   file(GLOB sources_Fortran ${src_home}/*.F90
                             ${src_home}/ifs_interface/*.F90) # ICEPACK + LIBRARY NOT SUPPORTED (YET)
else()
   file(GLOB sources_Fortran ${src_home}/*.F90)
endif()
file(GLOB sources_C ${src_home}/*.c)

# generate a custom file from fesom_version_info.F90 which includes the current git SHA
set(FESOM_ORIGINAL_VERSION_FILE ${src_home}/fesom_version_info.F90)
set(FESOM_GENERATED_VERSION_FILE ${CMAKE_CURRENT_BINARY_DIR}/fesom_version_info-generated.F90)
list(REMOVE_ITEM sources_Fortran ${FESOM_ORIGINAL_VERSION_FILE}) # we want to compile the generated file instead
list(APPEND sources_Fortran ${FESOM_GENERATED_VERSION_FILE})
set_source_files_properties(${FESOM_GENERATED_VERSION_FILE} PROPERTIES GENERATED TRUE)

add_custom_target(fesom_version_info-generated.F90 ALL
                  COMMENT "Determining ${PROJECT_NAME} git SHA ..."
                  COMMAND ${CMAKE_COMMAND} -DFESOM_ORIGINAL_VERSION_FILE=${FESOM_ORIGINAL_VERSION_FILE} -DFESOM_GENERATED_VERSION_FILE=${FESOM_GENERATED_VERSION_FILE} -P GitRepositoryInfo.cmake
                  WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR})

#if(${FESOM_STANDALONE})
#   list(REMOVE_ITEM sources_Fortran ${src_home}/cpl_driver.F90)
#endif()
list(REMOVE_ITEM sources_Fortran ${src_home}/fvom_init.F90 ${src_home}/oce_local.F90 ${src_home}/gen_comm.F90)
list(REMOVE_ITEM sources_C       ${src_home}/fort_part.c)
list(REMOVE_ITEM sources_Fortran ${src_home}/fesom_main.F90)

# depends on the metis library
#add_subdirectory(../lib/metis-5.1.0 ${PROJECT_BINARY_DIR}/metis)
#include_directories(../lib/metis-5.1.0/include)
# depends on the fesom_parms library
add_subdirectory(../lib/parms ${PROJECT_BINARY_DIR}/parms)

add_subdirectory(async_threads_cpp)

add_library(${PROJECT_NAME}_C ${sources_C})
target_compile_definitions(${PROJECT_NAME}_C PRIVATE PARMS USE_MPI REAL=double DBL HAS_BLAS FORTRAN_UNDERSCORE VOID_POINTER_SIZE_8 SGI LINUX UNDER_ MPI2)
target_link_libraries(${PROJECT_NAME}_C PRIVATE fesom_parms) #metis
target_link_libraries(${PROJECT_NAME}_C PRIVATE MPI::MPI_C)


# fesom library
add_library(${PROJECT_NAME} ${sources_Fortran})
add_dependencies(${PROJECT_NAME} fesom_version_info-generated.F90)
target_compile_definitions(${PROJECT_NAME} PRIVATE PARMS -DMETIS_VERSION=5 -DPART_WEIGHTED -DMETISRANDOMSEED=35243)
if(ENABLE_MULTIO)
  target_compile_definitions(${PROJECT_NAME} PRIVATE __MULTIO)
endif()

target_include_directories(${PROJECT_NAME} PRIVATE ${NETCDF_Fortran_INCLUDE_DIRECTORIES} ${OASIS_Fortran_INCLUDE_DIRECTORIES})
target_include_directories(${PROJECT_NAME} PRIVATE ${MCT_Fortran_INCLUDE_DIRECTORIES} ${MPEU_Fortran_INCLUDE_DIRECTORIES})
target_include_directories(${PROJECT_NAME} PRIVATE ${SCRIP_Fortran_INCLUDE_DIRECTORIES})
target_link_libraries(${PROJECT_NAME} PRIVATE fesom_parms) #metis
target_link_libraries(${PROJECT_NAME} PRIVATE fesom_async_threads)
target_link_libraries(${PROJECT_NAME} PRIVATE MPI::MPI_Fortran)
target_link_libraries(${PROJECT_NAME} PRIVATE ${PROJECT_NAME}_C ${NETCDF_Fortran_LIBRARIES} ${NETCDF_C_LIBRARIES} ${OASIS_Fortran_LIBRARIES})
target_link_libraries(${PROJECT_NAME} PRIVATE ${MCT_Fortran_LIBRARIES} ${MPEU_Fortran_LIBRARIES} ${SCRIP_Fortran_LIBRARIES})
set_target_properties(${PROJECT_NAME} PROPERTIES LINKER_LANGUAGE Fortran)
if(ENABLE_OPENMP AND NOT ${CMAKE_Fortran_COMPILER_ID} STREQUAL Cray)
   target_link_libraries(${PROJECT_NAME} PRIVATE OpenMP::OpenMP_Fortran)
endif()
if(ENABLE_MULTIO)
  target_link_libraries(${PROJECT_NAME} PRIVATE multio-fapi)
endif()



if(${DISABLE_MULTITHREADING})
   target_compile_definitions(${PROJECT_NAME} PRIVATE DISABLE_MULTITHREADING)
endif()
if(${FESOM_COUPLED})
   find_package(OASIS REQUIRED)
   target_compile_definitions(${PROJECT_NAME} PRIVATE __oasis)
endif()
if(${OIFS_COUPLED})
   target_compile_definitions(${PROJECT_NAME} PRIVATE __oifs)
endif()
if(${USE_ICEPACK})
   target_compile_definitions(${PROJECT_NAME} PRIVATE __icepack)
elseif(${ENABLE_IFS_INTERFACE})
   target_compile_definitions(${PROJECT_NAME} PRIVATE __ifsinterface)
endif()
if(${VERBOSE})
   target_compile_definitions(${PROJECT_NAME} PRIVATE VERBOSE)
endif()
if(${OPENMP_REPRODUCIBLE})
   target_compile_definitions(${PROJECT_NAME} PRIVATE __openmp_reproducible)
endif()

# CMAKE_Fortran_COMPILER_ID will also work if a wrapper is being used (e.g. mpif90 wraps ifort -> compiler id is Intel)
if(${CMAKE_Fortran_COMPILER_ID} STREQUAL  Intel )
   target_compile_options(${PROJECT_NAME} PRIVATE -r8 -i4 -fp-model precise -no-prec-div -no-prec-sqrt -fimf-use-svml -ip -init=zero -no-wrap-margin -fpe0)
   if(${FESOM_PLATFORM_STRATEGY} STREQUAL  levante.dkrz.de )
      target_compile_options(${PROJECT_NAME} PRIVATE -march=core-avx2 -mtune=core-avx2)
   elseif(${FESOM_PLATFORM_STRATEGY} STREQUAL  albedo)
      target_compile_options(${PROJECT_NAME} PRIVATE -march=core-avx2 -O3 -ip -fPIC -qopt-malloc-options=2 -qopt-prefetch=5 -unroll-aggressive) #NEC mpi option
   else()
      target_compile_options(${PROJECT_NAME} PRIVATE -xHost)
   endif()
#    target_compile_options(${PROJECT_NAME} PRIVATE -g -traceback ) #-check all,noarg_temp_created,bounds,uninit ) #-ftrapuv ) #-init=zero)
#    target_compile_options(${PROJECT_NAME} PRIVATE -qopenmp -r8 -i4 -fp-model precise -no-prec-div -no-prec-sqrt -fimf-use-svml -xHost -ip -g -traceback -check all,noarg_temp_created,bounds,uninit ) #-ftrapuv ) #-init=zero)
#    target_compile_options(${PROJECT_NAME} PRIVATE -r8 -i4 -fp-model precise -no-prec-div -no-prec-sqrt -fimf-use-svml -ip -g -traceback -check all,noarg_temp_created,bounds,uninit ) #-ftrapuv ) #-init=zero)

elseif(${CMAKE_Fortran_COMPILER_ID} STREQUAL  GNU )
#    target_compile_options(${PROJECT_NAME} PRIVATE -O3 -finit-local-zero  -finline-functions -fimplicit-none  -fdefault-real-8 -ffree-line-length-none)
   target_compile_options(${PROJECT_NAME} PRIVATE -O2 -g -ffloat-store -finit-local-zero  -finline-functions -fimplicit-none  -fdefault-real-8 -ffree-line-length-none)
   if(CMAKE_Fortran_COMPILER_VERSION VERSION_GREATER_EQUAL 10 )
      target_compile_options(${PROJECT_NAME} PRIVATE -fallow-argument-mismatch) # gfortran v10 is strict about erroneous API calls: "Rank mismatch between actual argument at (1) and actual argument at (2) (scalar and rank-1)"
   endif()
elseif(${CMAKE_Fortran_COMPILER_ID} STREQUAL Cray )
   target_compile_options(${PROJECT_NAME} PRIVATE -c -emf -hbyteswapio -hflex_mp=conservative -hfp1 -hadd_paren -Ounroll0 -hipa0 -r am -s real64 -N 1023)
   if(${ENABLE_OPENMP})
      target_compile_options(${PROJECT_NAME} PRIVATE -homp)
   else()
      target_compile_options(${PROJECT_NAME} PRIVATE -hnoomp)
   endif()
elseif(${CMAKE_Fortran_COMPILER_ID} STREQUAL NVHPC )
   target_compile_definitions(${PROJECT_NAME} PRIVATE ENABLE_NVHPC_WORKAROUNDS)
   target_compile_options(${PROJECT_NAME} PRIVATE -fast -fastsse -O3 -Mallocatable=95 -Mr8 -pgf90libs)
   if(${ENABLE_OPENACC})
      # additional compiler settings
      target_compile_options(${PROJECT_NAME} PRIVATE -acc -ta=tesla:${NV_GPU_ARCH} -Minfo=accel)
      set(CMAKE_EXE_LINKER_FLAGS "-acc -ta=tesla:${NV_GPU_ARCH}")
   endif()
   if(${ENABLE_OPENMP})
      target_compile_options(${PROJECT_NAME} PRIVATE -Mipa=fast)
   else()
      target_compile_options(${PROJECT_NAME} PRIVATE -Mipa=fast,inline)
   endif()
endif()

# fesom.x executable
add_executable(${PROJECT_NAME}.x ${src_home}/fesom_main.F90)
target_link_libraries(${PROJECT_NAME}.x PUBLIC ${PROJECT_NAME})

### Export and installation

# Set install directories
include(GNUInstallDirs)
if( NOT INSTALL_BIN_DIR )
   set( INSTALL_BIN_DIR ${CMAKE_INSTALL_BINDIR} )
endif()
if( NOT INSTALL_LIB_DIR )
   set( INSTALL_LIB_DIR ${CMAKE_INSTALL_LIBDIR} )
endif()
if( NOT INSTALL_INCLUDE_DIR )
   set( INSTALL_INCLUDE_DIR ${CMAKE_INSTALL_INCLUDEDIR} )
endif()
set( INSTALL_CMAKE_DIR ${INSTALL_LIB_DIR}/cmake/${PROJECT_NAME} )

mark_as_advanced( INSTALL_BIN_DIR )
mark_as_advanced( INSTALL_LIB_DIR )
mark_as_advanced( INSTALL_INCLUDE_DIR )
mark_as_advanced( INSTALL_CMAKE_DIR )

set( PROJECT_TARGETS_FILE "${PROJECT_BINARY_DIR}/${PROJECT_NAME}-targets.cmake" )
file( REMOVE ${PROJECT_TARGETS_FILE} )


foreach( tgt ${PROJECT_NAME}_C ${PROJECT_NAME} fesom_parms fesom_async_threads fesom.x )
   install( TARGETS ${tgt}
      EXPORT  ${PROJECT_NAME}-targets
      RUNTIME DESTINATION ${INSTALL_BIN_DIR}
      LIBRARY DESTINATION ${INSTALL_LIB_DIR}
      ARCHIVE DESTINATION ${INSTALL_LIB_DIR} )
   set_target_properties( ${tgt} PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib )
   export( TARGETS ${tgt} APPEND FILE "${PROJECT_TARGETS_FILE}" )
endforeach()

include(CMakePackageConfigHelpers)
write_basic_package_version_file(
    "${PROJECT_NAME}-config-version.cmake"
    VERSION ${${PROJECT_NAME}_VERSION}
    COMPATIBILITY AnyNewerVersion)

configure_package_config_file(fesom-config.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/fesom-config.cmake
  INSTALL_DESTINATION ${INSTALL_CMAKE_DIR})

install(EXPORT ${PROJECT_NAME}-targets DESTINATION "${INSTALL_CMAKE_DIR}")
install(FILES
            ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}-config-version.cmake
            ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}-config.cmake
        DESTINATION "${INSTALL_CMAKE_DIR}")
