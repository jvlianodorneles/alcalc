QT += core gui widgets qml quick quickcontrols2 dbus

CONFIG += c++17 release
TARGET = alcalc
TEMPLATE = app

HEADERS += \
    src/backend.h \
    src/systemtheme.h

SOURCES += \
    src/main.cpp \
    src/backend.cpp \
    src/systemtheme.cpp

RESOURCES += src/resources.qrc

target.path = /usr/bin
desktop.path = /usr/share/applications
desktop.files = data/alcalc.desktop
icon.path = /usr/share/icons/hicolor/scalable/apps
icon.files = icons/alcalc.svg

INSTALLS += target desktop icon
