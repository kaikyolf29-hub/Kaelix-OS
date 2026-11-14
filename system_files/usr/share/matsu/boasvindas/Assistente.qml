// O miolo das Boas-vindas: a tela do passo atual (entra deslizando de leve, como
// no assistente do Mac) e o rodapé com Voltar, os pontinhos e Continuar.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: assistente

    readonly property bool ultima: janela.passo === janela.telas.length - 1

    Item {
        id: palco
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: rodape.top
        clip: true

        Repeater {
            model: janela.telas
            delegate: Loader {
                id: tela
                required property int index
                required property string modelData
                readonly property bool atual: index === janela.passo
                width: palco.width
                height: palco.height
                source: Qt.resolvedUrl("Tela" + modelData.charAt(0).toUpperCase() + modelData.slice(1) + ".qml")
                // A que sai vai para o lado de onde veio; a nova chega do outro.
                x: atual ? 0 : (index < janela.passo ? -1 : 1) * Math.round(palco.width * 0.08)
                opacity: atual ? 1 : 0
                visible: opacity > 0.01
                enabled: atual
                Behavior on x {
                    NumberAnimation {
                        duration: 380
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    // ----- rodapé -----
    Item {
        id: rodape
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.round(janela.gu * 3.8)

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: janela.tinta(janela.escuro ? 0.07 : 0.08)
        }

        Botao {
            anchors.left: parent.left
            anchors.leftMargin: Math.round(janela.gu * 0.8)
            anchors.verticalCenter: parent.verticalCenter
            texto: janela.t("Voltar", "Back")
            icone: "matsu-voltar-symbolic"
            visible: janela.passo > 0
            onClicado: janela.ir(janela.passo - 1)
        }

        // Um pontinho por tela; o da tela atual estica numa pílula.
        Row {
            anchors.centerIn: parent
            spacing: Math.round(janela.gu * 0.35)
            Repeater {
                model: janela.telas.length
                delegate: Rectangle {
                    required property int index
                    readonly property bool atual: index === janela.passo
                    width: atual ? Math.round(janela.gu * 1.2) : Math.round(janela.gu * 0.42)
                    height: Math.round(janela.gu * 0.42)
                    radius: height / 2
                    color: janela.tinta(atual ? 0.85 : (index < janela.passo ? 0.4 : 0.18))
                    Behavior on width {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 260
                        }
                    }
                }
            }
        }

        BotaoDestaque {
            id: seguir
            anchors.right: parent.right
            anchors.rightMargin: Math.round(janela.gu * 0.9)
            anchors.verticalCenter: parent.verticalCenter
            texto: janela.passo === 0 ? janela.t("Começar", "Get started")
                 : assistente.ultima ? janela.t("Começar a usar", "Start using Matsu")
                 : janela.t("Continuar", "Continue")
            onClicado: janela.seguir()
        }
    }

    // Enter segue; as setas andam entre as telas.
    Shortcut {
        sequences: ["Return", "Enter"]
        onActivated: janela.seguir()
    }
    Shortcut {
        sequence: "Alt+Left"
        onActivated: janela.ir(janela.passo - 1)
    }
    Shortcut {
        sequence: "Alt+Right"
        enabled: !assistente.ultima
        onActivated: janela.ir(janela.passo + 1)
    }
}
