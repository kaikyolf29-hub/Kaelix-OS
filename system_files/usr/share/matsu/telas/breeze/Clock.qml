// Matsu OS — a hora das telas do KDE (org.kde.breeze.components.Clock).
//
// A tela de login do Plasma Login Manager vem compilada dentro do programa, mas
// usa esta peça do KDE para a hora. Na montagem, build_files/telas-kde.py põe
// este arquivo no lugar do Clock.qml da Breeze (o original fica guardado em
// /usr/share/matsu/telas/originais/breeze) e a hora fica igual à do bloqueio:
// a data pequena em cima e a hora enorme embaixo (Matsu.Relogio).
//
// Mesmo jeito de usar do KDE: um ColumnLayout com softwareRendering.
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "file:///usr/share/matsu/telas" as Matsu

ColumnLayout {
    id: root

    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software

    spacing: 0

    Matsu.Relogio {
        Layout.alignment: Qt.AlignHCenter
        altura: root.Window.window && root.Window.window.height > 0 ? root.Window.window.height : 1080
    }
}
