# Matsu OS — matsu-terminal: o terminal do Matsu (ver main.cpp).
cmake_minimum_required(VERSION 3.16)
project(matsu-terminal LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Widgets)
# O terminal de verdade (o mesmo do Konsole) entra como uma peça, a konsolepart.
find_package(KF6Parts REQUIRED)
find_package(KF6CoreAddons REQUIRED)
find_package(KF6Config REQUIRED)
find_package(KF6WindowSystem REQUIRED)

add_executable(matsu-terminal main.cpp)
target_link_libraries(matsu-terminal PRIVATE
    Qt6::Widgets KF6::Parts KF6::CoreAddons KF6::ConfigCore KF6::WindowSystem)

install(TARGETS matsu-terminal RUNTIME DESTINATION bin)
