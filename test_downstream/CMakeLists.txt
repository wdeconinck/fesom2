cmake_minimum_required(VERSION 3.16 FATAL_ERROR)

project(test_downstream LANGUAGES Fortran)

find_package(fesom REQUIRED)

message("fesom found: ${fesom_DIR}")
message("fesom_VERSION: ${fesom_VERSION}")

if(NOT TARGET fesom)
  message(FATAL_ERROR "fesom was installed wrongly: fesom target not found")
endif()

get_target_property(target_type fesom TYPE)
if( NOT target_type MATCHES "STATIC_LIBRARY|SHARED_LIBRARY")
  message(FATAL_ERROR "fesom target's TYPE is expected to be STATIC_LIBRARY or SHARED_LIBRARY. Actual TYPE: ${target_type}")
endif ()

