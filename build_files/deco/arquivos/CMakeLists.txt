# Matsu OS — matsu-arquivos: os Arquivos do Matsu (ver main.cpp).
cmake_minimum_required(VERSION 3.16)
project(matsu-arquivos LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Widgets DBus)
# A lista de arquivos de verdade (a mesma do Dolphin) entra como uma peça, a dolphinpart.
find_package(KF6Parts REQUIRED)
find_package(KF6CoreAddons REQUIRED)
find_package(KF6Config REQUIRED)
find_package(KF6WindowSystem REQUIRED)
find_package(KF6KIO REQUIRED)
find_package(KF6Solid REQUIRED)

add_executable(matsu-arquivos main.cpp)
target_link_libraries(matsu-arquivos PRIVATE
    Qt6::Widgets Qt6::DBus KF6::Parts KF6::CoreAddons KF6::ConfigCore KF6::WindowSystem
    KF6::KIOCore KF6::KIOGui KF6::KIOWidgets KF6::KIOFileWidgets KF6::Solid)

install(TARGETS matsu-arquivos RUNTIME DESTINATION bin)
