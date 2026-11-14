# Matsu OS — org.matsu.senha: a janela de senha do sistema (agente do polkit) feita
# pelo Matsu. Peça de QML que a matsu-janela carrega (ver agente.h).
cmake_minimum_required(VERSION 3.16)
project(matsu-senha LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Qml)
find_package(PolkitQt6-1 REQUIRED)

qt_standard_project_setup()
qt_add_qml_module(matsusenha
    URI org.matsu.senha
    VERSION 1.0
    PLUGIN_TARGET matsusenha
    SOURCES agente.h agente.cpp
    OUTPUT_DIRECTORY org/matsu/senha
)
target_link_libraries(matsusenha PRIVATE Qt6::Core Qt6::Qml PolkitQt6-1::Agent PolkitQt6-1::Core)
