set(TARGET allama)
add_executable(${TARGET} allama.c)
target_link_libraries(${TARGET} PRIVATE server-context PUBLIC llama-common ${CMAKE_THREAD_LIBS_INIT})
target_link_libraries(${TARGET} PRIVATE sqlite3)
target_compile_features(${TARGET} PRIVATE cxx_std_17)

include_directories(../server)
include_directories(${CMAKE_SOURCE_DIR}/common)

if(LLAMA_TOOLS_INSTALL)
    install(TARGETS ${TARGET} RUNTIME)
endif()
