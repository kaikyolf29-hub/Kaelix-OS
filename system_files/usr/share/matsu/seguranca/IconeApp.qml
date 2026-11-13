// O ícone de um app: o oficial, que o Flatpak exporta (um caminho de arquivo), ou
// um nome do tema quando se sabe que existe ("tema"). Sem ele, um quadradinho
// suave com o desenho genérico de app, nunca uma letra.
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: iconeApp

    property string fonte: ""
    // true: "fonte" é um nome do tema que existe (o ícone de um .desktop instalado).
    property bool tema: false
    readonly property bool temIcone: fonte !== "" && (tema || fonte.charAt(0) === "/" || fonte.indexOf("file:") === 0)

    Kirigami.Icon {
        anchors.fill: parent
        visible: iconeApp.temIcone
        source: iconeApp.temIcone ? iconeApp.fonte : ""
    }
    Rectangle {
        anchors.fill: parent
        visible: !iconeApp.temIcone
        radius: Math.round(width * 0.26)
        color: janela.tinta(janela.escuro ? 0.08 : 0.06)
        border.width: 1
        border.color: janela.tinta(0.08)
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(parent.width * 0.5)
            height: width
            source: "matsu-apps-symbolic"
            isMask: true
            color: janela.frente
            opacity: 0.55
        }
    }
}
