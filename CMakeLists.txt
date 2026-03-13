cmake_minimum_required(VERSION 3.16)

project(Dactyl VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick DBus)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appDactyl
    main.cpp
)

qt_add_qml_module(appDactyl
    URI Dactyl
    VERSION 1.0
    QML_FILES
        Main.qml
    SOURCES
        fingerprintmanager.h
        fingerprintmanager.cpp
)

set_target_properties(appDactyl PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appDactyl
    PRIVATE Qt6::Quick Qt6::DBus
)

include(GNUInstallDirs)
install(TARGETS appDactyl
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
