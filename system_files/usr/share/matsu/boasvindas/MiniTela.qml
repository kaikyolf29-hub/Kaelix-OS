// Uma telinha do Matsu desenhada (para escolher o tema e a barra): o papel de
// parede de verdade, uma janela no tema escolhido e a barra no jeito escolhido
// (Fusão: três ilhas embaixo; Mac: barra no alto e doca; Windows: uma barra
// inteira embaixo).
import QtQuick
import QtQuick.Effects

Item {
    id: tela

    property bool claro: false
    property string estilo: "fusao"
    property bool vidro: true

    readonly property real u: height / 20
    readonly property color corBarra: claro ? Qt.rgba(1, 1, 1, vidro ? 0.78 : 0.96) : Qt.rgba(0.06, 0.06, 0.07, vidro ? 0.74 : 0.96)
    readonly property color bordaBarra: claro ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(1, 1, 1, 0.16)
    readonly property color corPonto: claro ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(1, 1, 1, 0.55)
    readonly property color corJanela: claro ? Qt.rgba(0.96, 0.96, 0.97, vidro ? 0.9 : 1) : Qt.rgba(0.13, 0.13, 0.14, vidro ? 0.88 : 1)
    readonly property color corLinha: claro ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.14)
    // As cores dos ícones dos apps do Matsu (Arquivos, Loja, Jogos, Terminal, Ajustes...).
    readonly property var apps: ["#5aa2ff", "#f0729f", "#8f6cf0", "#45d0c1", "#f5c36b", "#7fcf6a"]

    Rectangle {
        id: moldura
        anchors.fill: parent
        radius: Math.round(tela.u * 1.3)
        color: tela.claro ? "#c9b7e8" : "#2b2350"
        // Desenhada fora da tela; o MultiEffect embaixo mostra com os cantos
        // redondos (que cortam o papel e as barras também).
        visible: false
        layer.enabled: true

        Image {
            anchors.fill: parent
            source: "file:///usr/share/wallpapers/Matsu/contents/" + (tela.claro ? "images" : "images_dark") + "/3840x2160.png"
            sourceSize.width: 480
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
        }

        // A janela aberta, com as bolinhas.
        Rectangle {
            x: Math.round(parent.width * 0.16)
            y: Math.round(tela.estilo === "mac" ? tela.u * 3.4 : tela.u * 2.6)
            width: Math.round(parent.width * 0.5)
            height: Math.round(parent.height * 0.5)
            radius: Math.round(tela.u * 0.7)
            color: tela.corJanela
            border.width: 1
            border.color: tela.corLinha
            Row {
                x: Math.round(tela.u * 0.8)
                y: Math.round(tela.u * 0.8)
                spacing: Math.round(tela.u * 0.45)
                Repeater {
                    model: ["#ff5f57", "#febc2e", "#28c840"]
                    Rectangle {
                        required property string modelData
                        width: Math.max(3, Math.round(tela.u * 0.75))
                        height: width
                        radius: width / 2
                        color: modelData
                    }
                }
            }
            Column {
                x: Math.round(tela.u * 0.8)
                y: Math.round(tela.u * 2.6)
                spacing: Math.round(tela.u * 0.6)
                Repeater {
                    model: [0.7, 0.5, 0.6]
                    Rectangle {
                        required property real modelData
                        width: Math.round((tela.width * 0.5 - tela.u * 1.6) * modelData)
                        height: Math.max(2, Math.round(tela.u * 0.55))
                        radius: height / 2
                        color: tela.corLinha
                    }
                }
            }
        }

        // ----- Fusão: três ilhas embaixo -----
        Item {
            anchors.fill: parent
            visible: tela.estilo === "fusao"
            readonly property real alto: Math.round(tela.u * 2)
            readonly property real baixo: parent.height - alto - Math.round(tela.u * 0.7)
            Rectangle {
                x: Math.round(tela.u * 0.8)
                y: parent.baixo
                width: Math.round(tela.u * 3.4)
                height: parent.alto
                radius: height / 2
                color: tela.corBarra
                border.width: 1
                border.color: tela.bordaBarra
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.round(tela.u * 0.55)
                    width: Math.round(tela.u * 1)
                    height: width
                    radius: width / 2
                    color: "#e8a0c8"
                }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.baixo
                width: icones.width + Math.round(tela.u * 1.4)
                height: parent.alto
                radius: height / 2
                color: tela.corBarra
                border.width: 1
                border.color: tela.bordaBarra
                Row {
                    id: icones
                    anchors.centerIn: parent
                    spacing: Math.round(tela.u * 0.45)
                    Repeater {
                        model: tela.apps
                        Rectangle {
                            required property string modelData
                            width: Math.round(tela.u * 1.2)
                            height: width
                            radius: Math.round(width * 0.28)
                            color: modelData
                        }
                    }
                }
            }
            Rectangle {
                x: parent.width - width - Math.round(tela.u * 0.8)
                y: parent.baixo
                width: Math.round(tela.u * 4.6)
                height: parent.alto
                radius: height / 2
                color: tela.corBarra
                border.width: 1
                border.color: tela.bordaBarra
                // A hora.
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.round(tela.u * 2.4)
                    height: Math.max(2, Math.round(tela.u * 0.55))
                    radius: height / 2
                    color: tela.corPonto
                }
            }
        }

        // ----- Mac: barra fina no alto e a doca -----
        Item {
            anchors.fill: parent
            visible: tela.estilo === "mac"
            Rectangle {
                width: parent.width
                height: Math.round(tela.u * 1.4)
                color: tela.corBarra
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.round(tela.u * 0.7)
                    width: Math.round(tela.u * 0.8)
                    height: width
                    radius: width / 2
                    color: "#e8a0c8"
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.round(tela.u * 2)
                    spacing: Math.round(tela.u * 0.6)
                    Repeater {
                        model: [1.6, 1.2, 1.4]
                        Rectangle {
                            required property real modelData
                            width: Math.round(tela.u * modelData)
                            height: Math.max(2, Math.round(tela.u * 0.45))
                            radius: height / 2
                            color: tela.corPonto
                        }
                    }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(tela.u * 0.7)
                    width: Math.round(tela.u * 2.4)
                    height: Math.max(2, Math.round(tela.u * 0.45))
                    radius: height / 2
                    color: tela.corPonto
                }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - height - Math.round(tela.u * 0.6)
                width: doca.width + Math.round(tela.u * 1)
                height: Math.round(tela.u * 2.2)
                radius: Math.round(tela.u * 0.8)
                color: tela.corBarra
                border.width: 1
                border.color: tela.bordaBarra
                Row {
                    id: doca
                    anchors.centerIn: parent
                    spacing: Math.round(tela.u * 0.4)
                    Repeater {
                        model: tela.apps
                        Rectangle {
                            required property string modelData
                            width: Math.round(tela.u * 1.5)
                            height: width
                            radius: Math.round(width * 0.28)
                            color: modelData
                        }
                    }
                }
            }
        }

        // ----- Windows: uma barra inteira embaixo -----
        Rectangle {
            visible: tela.estilo === "windows"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.round(tela.u * 2.2)
            color: tela.corBarra
            Rectangle {
                width: parent.width
                height: 1
                color: tela.bordaBarra
            }
            Row {
                anchors.centerIn: parent
                spacing: Math.round(tela.u * 0.5)
                Repeater {
                    model: tela.apps
                    Rectangle {
                        required property string modelData
                        width: Math.round(tela.u * 1.2)
                        height: width
                        radius: Math.round(width * 0.28)
                        color: modelData
                    }
                }
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: Math.round(tela.u * 0.8)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(tela.u * 3)
                height: Math.max(2, Math.round(tela.u * 0.55))
                radius: height / 2
                color: tela.corPonto
            }
        }
    }

    Rectangle {
        id: mascara
        anchors.fill: parent
        radius: moldura.radius
        visible: false
        layer.enabled: true
        layer.smooth: true
    }
    MultiEffect {
        anchors.fill: parent
        autoPaddingEnabled: false
        source: moldura
        maskEnabled: true
        maskSource: mascara
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }

    // A borda fina por cima, para a telinha não sumir no fundo do cartão.
    Rectangle {
        anchors.fill: parent
        radius: moldura.radius
        color: "transparent"
        border.width: 1
        border.color: tela.claro ? Qt.rgba(0, 0, 0, 0.1) : Qt.rgba(1, 1, 1, 0.1)
    }
}
