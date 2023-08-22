cmake_minimum_required(VERSION 3.4)

project(async_threads_cpp CXX C Fortran) #  the FortranCInterface requires the C language to be enabled

set (CMAKE_CXX_STANDARD 11)

# get our source files
file(GLOB sources ${CMAKE_CURRENT_LIST_DIR}/*.cpp)

include(FortranCInterface)
FortranCInterface_HEADER(ThreadsManagerFCMacros.h MACRO_NAMESPACE "ThreadsManagerFCMacros_" SYMBOLS init_ccall begin_ccall end_ccall)

add_library(${PROJECT_NAME} ${sources} async_threads_module.F90)
target_include_directories(${PROJECT_NAME}
    PRIVATE ${CMAKE_CURRENT_LIST_DIR} ${CMAKE_CURRENT_BINARY_DIR}
)

target_compile_options(${PROJECT_NAME} PRIVATE -fPIC)
install(TARGETS ${PROJECT_NAME} EXPORT ifs_sp-targets DESTINATION "${FESOM_INSTALL_PREFIX}/lib")
