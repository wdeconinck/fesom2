cmake_minimum_required(VERSION 3.16)

project(async_threads CXX C Fortran) #  the FortranCInterface requires the C language to be enabled

set (CMAKE_CXX_STANDARD 11)

# get our source files
file(GLOB sources ${CMAKE_CURRENT_LIST_DIR}/*.cpp)

include(FortranCInterface)
FortranCInterface_HEADER(ThreadsManagerFCMacros.h MACRO_NAMESPACE "ThreadsManagerFCMacros_" SYMBOLS init_ccall begin_ccall end_ccall)

add_library(${PROJECT_NAME} ${sources} async_threads_module.F90)
target_include_directories(${PROJECT_NAME}
  PRIVATE $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
  PRIVATE $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>
  PUBLIC  $<BUILD_INTERFACE:${CMAKE_Fortran_MODULE_DIRECTORY}>
)

if(ENABLE_OPENMP)
   # there is a problem (at least on levante with ifort) with openmp and I/O multithreading being active at the same time
   # in this case the simulation stops and never finishes
   # this has been observed with IFS-Fesom and Fesom standalone
   # until the problem is identified, we exclude the I/O and multithreading files from openmp compilation, i.e. "-qno-openmp" for ifort
   if(NOT DISABLE_MULTITHREADING)
      if(${CMAKE_Fortran_COMPILER_ID} STREQUAL  Intel )
         set_source_files_properties(${CMAKE_CURRENT_LIST_DIR}/async_threads_module.F90 PROPERTIES COMPILE_OPTIONS "-qno-openmp")
      endif()
   endif()
endif()
