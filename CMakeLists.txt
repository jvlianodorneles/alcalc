cmake_minimum_required(VERSION 3.16)

project(alcalc LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Qml Quick QuickControls2 DBus)

qt_standard_project_setup()

set(SOURCES
    src/main.cpp
    src/backend.h
    src/backend.cpp
    src/systemtheme.h
    src/systemtheme.cpp
    src/resources.qrc
)

qt_add_executable(alcalc ${SOURCES})

target_link_libraries(alcalc PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::DBus
)

install(TARGETS alcalc DESTINATION bin)
install(FILES data/alcalc.desktop DESTINATION share/applications)
install(FILES icons/alcalc.svg DESTINATION share/icons/hicolor/scalable/apps)
