// A logo oficial de um site (baixada do próprio site pelo ajudante), num quadrado
// arredondado claro, como os apps do celular. Enquanto não chega, um bloco na cor
// da marca com o brilho passando; se não der para baixar, a cor da marca com o globo.
import QtQuick
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: icone

    property var site: null
    readonly property string fonte: site && site.icone ? site.icone : ""
    readonly property color cor: site ? site.cor : janela.frente

    implicitWidth: Math.round(janela.gu * 3)
    implicitHeight: implicitWidth

    Rectangle {
        id: base
        anchors.fill: parent
        radius: Math.round(width * 0.24)
        visible: imagem.status === Image.Ready
        opacity: visible ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutCubic
            }
        }
        color: "#ffffff"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.08)
        layer.enabled: true
        layer.effect: SombraIcone {}
    }
    Image {
        id: imagem
        anchors.fill: parent
        anchors.margins: Math.round(parent.width * 0.14)
        source: icone.fonte ? janela.arquivo(icone.fonte) : ""
        sourceSize.width: Math.max(64, Math.round(width * 2))
        sourceSize.height: Math.max(64, Math.round(height * 2))
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
        cache: false
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutCubic
            }
        }
    }
    Esqueleto {
        anchors.fill: parent
        raio: base.radius
        cor: icone.cor
        forca: 0.35
        visible: icone.fonte === "" && !janela.semIconesWeb
    }
    // Sem a logo (sem internet na hora de baixar): a cor da marca e o globo.
    Rectangle {
        anchors.fill: parent
        radius: base.radius
        visible: (icone.fonte === "" && janela.semIconesWeb) || imagem.status === Image.Error
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(icone.cor, 1.15) }
            GradientStop { position: 1; color: Qt.darker(icone.cor, 1.25) }
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(parent.width * 0.5)
            height: width
            source: "matsu-web-symbolic"
            isMask: true
            color: "#ffffff"
        }
    }
}
