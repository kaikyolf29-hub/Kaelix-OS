# Kaelix OS — kaelix-janela: abre os apps do Kaelix feitos em QML numa janela
# com identidade própria (ver main.cpp).
cmake_minimum_required(VERSION 3.16)
project(kaelix-janela LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Widgets Qml Quick QuickControls2 Network)
find_package(KF6WindowSystem QUIET)
option(KAELIX_EXIGIR_KWS "Falha se o KWindowSystem não estiver instalado (na imagem do Kaelix)" OFF)
if(KAELIX_EXIGIR_KWS AND NOT KF6WindowSystem_FOUND)
    message(FATAL_ERROR "kaelix-janela: falta o kf6-kwindowsystem-devel (vidro, sombra e trazer a janela para a frente)")
endif()

add_executable(kaelix-janela main.cpp)
target_link_libraries(kaelix-janela PRIVATE Qt6::Widgets Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Network)
if(KF6WindowSystem_FOUND)
    target_link_libraries(kaelix-janela PRIVATE KF6::WindowSystem)
    target_compile_definitions(kaelix-janela PRIVATE TEM_KWINDOWSYSTEM=1)
    message(STATUS "kaelix-janela: com KWindowSystem (vidro, sombra e trazer a janela para a frente no Wayland)")
else()
    message(WARNING "kaelix-janela: sem KWindowSystem; a janela aberta de novo pode não vir para a frente")
endif()

install(TARGETS kaelix-janela RUNTIME DESTINATION libexec/kaelix)
