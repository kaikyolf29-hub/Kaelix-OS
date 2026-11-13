// Os destaques do Início, como a vitrine da Microsoft Store: um app por vez, na
// cor da marca dele, com a logo oficial, uma foto do app em uma janelinha e o
// botão de obter. Passa sozinho a cada 7 segundos (para com o mouse em cima);
// as bolinhas e as setas trocam na mão.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: vitrine

    property var lista: []
    property int atual: 0
    readonly property int raio: Math.round(janela.gu * 0.8)

    function ir(n) {
        if (lista.length > 0)
            atual = (n + lista.length) % lista.length;
    }

    HoverHandler {
        id: sobre
    }
    Timer {
        interval: 7000
        repeat: true
        running: vitrine.visible && vitrine.lista.length > 1 && !sobre.hovered && janela.active
        onTriggered: vitrine.ir(vitrine.atual + 1)
    }

    Repeater {
        model: vitrine.lista

        Item {
            id: lamina
            required property var modelData
            required property int index
            readonly property bool aqui: index === vitrine.atual
            readonly property var info: {
                var _d = janela.detalhes;
                return janela.detalhes[modelData.id] || null;
            }
            readonly property var resumo: janela.app(modelData.id)
            readonly property string foto: info && info.fotos && info.fotos.length > 0 ? info.fotos[0].url : ""

            anchors.fill: parent
            opacity: aqui ? 1 : 0
            visible: opacity > 0
            z: aqui ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 520
                    easing.type: Easing.InOutQuad
                }
            }

            // A cor da marca, em degradê, com um brilho no canto de cima.
            Rectangle {
                id: cor
                anchors.fill: parent
                radius: vitrine.raio
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: lamina.modelData.cores[1] }
                    GradientStop { position: 1; color: lamina.modelData.cores[0] }
                }
            }
            Item {
                anchors.fill: parent
                clip: true
                // Um círculo de luz grande e macio atrás da foto.
                Rectangle {
                    width: parent.height * 1.6
                    height: width
                    radius: width / 2
                    x: parent.width - width * 0.62
                    y: -height * 0.42
                    opacity: 0.22
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#ffffff" }
                        GradientStop { position: 0.7; color: "transparent" }
                    }
                }

                // Uma foto do app numa janelinha inclinada saindo da borda; sem foto,
                // a logo grande.
                Item {
                    id: janelinha
                    property real deslize: lamina.aqui ? 0 : janela.gu * 2.5
                    width: Math.min(parent.width * 0.5, parent.height * 1.55)
                    height: width * 0.62
                    x: parent.width - width * 0.92 + deslize
                    y: parent.height * 0.2
                    rotation: -3
                    visible: foto.status === Image.Ready
                    Behavior on deslize {
                        NumberAnimation {
                            duration: 700
                            easing.type: Easing.OutCubic
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -Math.round(janela.gu * 0.25)
                        radius: Math.round(janela.gu * 0.6)
                        color: Qt.rgba(1, 1, 1, 0.16)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.3)
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Qt.rgba(0, 0, 0, 0.45)
                            shadowBlur: 1.0
                            shadowVerticalOffset: Math.round(janela.gu * 0.5)
                        }
                    }
                    ImagemRedonda {
                        id: foto
                        anchors.fill: parent
                        raio: Math.round(janela.gu * 0.4)
                        horizontalAlignment: Image.AlignLeft
                        verticalAlignment: Image.AlignTop
                        source: lamina.foto
                        aparecer: true
                    }
                }
                IconeApp {
                    visible: foto.status !== Image.Ready
                    width: Math.round(Math.min(parent.height * 0.62, janela.gu * 9))
                    height: width
                    x: parent.width - width - Math.round(janela.gu * 2.5) + janelinha.deslize
                    anchors.verticalCenter: parent.verticalCenter
                    rotation: -8
                    sombra: true
                    fonte: lamina.resumo ? lamina.resumo.icone : ""
                    appId: lamina.modelData.id
                }
            }
            // Escurece a esquerda, onde fica o texto (branco em qualquer marca).
            Rectangle {
                anchors.fill: parent
                radius: vitrine.raio
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.42) }
                    GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.16) }
                    GradientStop { position: 0.75; color: "transparent" }
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: vitrine.raio
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.14)
            }

            ColumnLayout {
                anchors.left: parent.left
                anchors.leftMargin: Math.round(janela.gu * 1.8)
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -Math.round(janela.gu * 0.35)
                width: Math.min(parent.width * 0.48, janela.gu * 21)
                spacing: Math.round(janela.gu * 0.5)

                Texto {
                    text: janela.t("ESCOLHA DO MATSU", "MATSU PICK")
                    color: "#ffffff"
                    opacity: 0.8
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.3
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(janela.gu * 0.7)
                    IconeApp {
                        Layout.preferredWidth: Math.round(janela.gu * 3.2)
                        Layout.preferredHeight: Layout.preferredWidth
                        sombra: true
                        fonte: lamina.resumo ? lamina.resumo.icone : ""
                        appId: lamina.modelData.id
                    }
                    Texto {
                        Layout.fillWidth: true
                        text: lamina.modelData.titulo
                        color: "#ffffff"
                        font.pixelSize: Math.round(janela.gu * 1.65)
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                }
                Texto {
                    Layout.fillWidth: true
                    text: lamina.modelData.texto
                    color: "#ffffff"
                    opacity: 0.9
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Row {
                    Layout.topMargin: Math.round(janela.gu * 0.3)
                    spacing: Math.round(janela.gu * 0.5)
                    BotaoObter {
                        appId: lamina.modelData.id
                        grande: true
                        sobreCor: true
                    }
                    MouseArea {
                        id: saiba
                        width: linhaSaiba.implicitWidth + Math.round(janela.gu * 1.4)
                        height: Math.round(janela.gu * 2.2)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: janela.abrirApp(lamina.modelData.id)
                        Accessible.role: Accessible.Button
                        Accessible.name: janela.t("Ver detalhes", "See details")
                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: Qt.rgba(1, 1, 1, saiba.containsMouse ? 0.14 : 0)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, saiba.containsMouse ? 0.35 : 0.25)
                        }
                        Row {
                            id: linhaSaiba
                            anchors.centerIn: parent
                            spacing: 4
                            Texto {
                                anchors.verticalCenter: parent.verticalCenter
                                text: janela.t("Ver detalhes", "See details")
                                color: "#ffffff"
                            }
                            Kirigami.Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.round(Kirigami.Units.iconSizes.small * 0.85)
                                height: width
                                source: "matsu-seta-symbolic"
                                isMask: true
                                color: "#ffffff"
                            }
                        }
                    }
                }
            }
        }
    }

    // ----- bolinhas (a do atual é comprida) -----
    Row {
        z: 2
        anchors.left: parent.left
        anchors.leftMargin: Math.round(janela.gu * 1.8)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(janela.gu * 0.8)
        spacing: 6
        visible: vitrine.lista.length > 1
        Repeater {
            model: vitrine.lista.length
            MouseArea {
                required property int index
                width: index === vitrine.atual ? 22 : 8
                height: 8
                cursorShape: Qt.PointingHandCursor
                onClicked: vitrine.ir(index)
                Accessible.role: Accessible.Button
                Accessible.name: janela.t("Destaque ", "Highlight ") + (index + 1)
                Behavior on width {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: "#ffffff"
                    opacity: index === vitrine.atual ? 0.95 : 0.4
                }
            }
        }
    }

    // ----- setas no canto de baixo (aparecem com o mouse em cima) -----
    Row {
        z: 2
        anchors.right: parent.right
        anchors.rightMargin: Math.round(janela.gu * 0.8)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(janela.gu * 0.6)
        spacing: 6
        visible: vitrine.lista.length > 1
        opacity: sobre.hovered ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
        Repeater {
            model: [-1, 1]
            MouseArea {
                id: seta
                required property int modelData
                width: Math.round(janela.gu * 1.75)
                height: width
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: vitrine.ir(vitrine.atual + modelData)
                Accessible.role: Accessible.Button
                Accessible.name: modelData < 0 ? janela.t("Anterior", "Previous") : janela.t("Próximo", "Next")
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(0.06, 0.06, 0.07, seta.containsMouse ? 0.62 : 0.42)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.2)
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Kirigami.Units.iconSizes.small
                    height: width
                    source: "matsu-seta-symbolic"
                    rotation: seta.modelData < 0 ? 180 : 0
                    isMask: true
                    color: "#ffffff"
                }
            }
        }
    }
}
