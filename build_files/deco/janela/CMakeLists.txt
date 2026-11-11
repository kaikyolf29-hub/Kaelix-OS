# Matsu OS — matsu-janela: abre os apps do Matsu feitos em QML numa janela
# com identidade própria (ver main.cpp).
cmake_minimum_required(VERSION 3.16)
project(matsu-janela LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Widgets Qml Quick QuickControls2 Network)
find_package(KF6WindowSystem QUIET)
option(MATSU_EXIGIR_KWS "Falha se o KWindowSystem não estiver instalado (na imagem do Matsu)" OFF)
if(MATSU_EXIGIR_KWS AND NOT KF6WindowSystem_FOUND)
    message(FATAL_ERROR "matsu-janela: falta o kf6-kwindowsystem-devel (vidro, sombra e trazer a janela para a frente)")
endif()

add_executable(matsu-janela main.cpp)
target_link_libraries(matsu-janela PRIVATE Qt6::Widgets Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Network)
if(KF6WindowSystem_FOUND)
    target_link_libraries(matsu-janela PRIVATE KF6::WindowSystem)
    target_compile_definitions(matsu-janela PRIVATE TEM_KWINDOWSYSTEM=1)
    message(STATUS "matsu-janela: com KWindowSystem (vidro, sombra e trazer a janela para a frente no Wayland)")
else()
    message(WARNING "matsu-janela: sem KWindowSystem; a janela aberta de novo pode não vir para a frente")
endif()

install(TARGETS matsu-janela RUNTIME DESTINATION libexec/matsu)
