add_executable(desktop_pipe_test
  desktop_pipe_test.cpp
  ../runner/desktop_pipe.cpp
  ../runner/desktop_callbacks.cpp
)
target_compile_features(desktop_pipe_test PRIVATE cxx_std_17)
target_compile_definitions(desktop_pipe_test PRIVATE UNICODE _UNICODE NOMINMAX)
target_compile_options(desktop_pipe_test PRIVATE /W4 /WX /EHsc /utf-8)
target_include_directories(desktop_pipe_test PRIVATE ../runner)
target_link_libraries(desktop_pipe_test PRIVATE bcrypt advapi32 user32)

add_executable(desktop_storage_test
  desktop_storage_test.cpp
  ../runner/desktop_storage.cpp
)
target_compile_features(desktop_storage_test PRIVATE cxx_std_17)
target_compile_definitions(desktop_storage_test PRIVATE UNICODE _UNICODE NOMINMAX)
target_compile_options(desktop_storage_test PRIVATE /W4 /WX /EHsc /utf-8)
target_include_directories(desktop_storage_test PRIVATE ../runner)
target_link_libraries(desktop_storage_test PRIVATE flutter_wrapper_app crypt32 advapi32 shell32 ole32)

add_test(NAME desktop_pipe COMMAND desktop_pipe_test)
add_test(NAME desktop_storage COMMAND desktop_storage_test)
set_tests_properties(desktop_pipe desktop_storage PROPERTIES TIMEOUT 30)
add_custom_command(TARGET desktop_storage_test POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${FLUTTER_LIBRARY}" "$<TARGET_FILE_DIR:desktop_storage_test>"
)
