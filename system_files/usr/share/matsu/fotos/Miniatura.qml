// Uma foto na grade: carrega sem travar (no fundo, já no tamanho da miniatura),
// com o brilho passando até chegar e entrando de leve. Cantos redondos, o giro que
// a pessoa deu (só na exibição) e, com o mouse em cima, o nome e o coração.
// Usa a miniatura que o KDE (Dolphin) já fez, quando ela existe e basta.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: mini

    property var foto: ({})
    property real raio: Math.round(janela.gu * 0.45)

    signal abrir()
    signal pedirMenu(real px, real py)

    readonly property string caminho: foto.caminho || ""
    readonly property int giro: janela.giroDe(caminho)
    readonly property bool deLado: giro === 90 || giro === 270
    readonly property bool favorita: janela.ehFavorita(caminho)
    readonly property bool pronta: imagem.status === Image.Ready
    readonly property bool quebrada: imagem.status === Image.Error
    readonly property bool emVoo: janela.fotoEmVoo !== "" && janela.fotoEmVoo === caminho
    readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    // Tamanho pedido em degraus de 64 px (a mesma miniatura serve em vários tamanhos da grade).
    function degrau(v) {
        return Math.max(64, Math.ceil(v * dpr / 64) * 64);
    }
    readonly property int pedidoL: degrau(deLado ? height : width)
    readonly property int pedidoA: degrau(deLado ? width : height)
    readonly property bool usaMini: (foto.mini || "") !== "" && Math.max(pedidoL, pedidoA) <= (foto.miniLado || 0) * 1.15
    readonly property url fonte: usaMini ? janela.arquivo(foto.mini) : janela.arquivo(caminho)
    // O que o visualizador usa enquanto a foto grande carrega (a mesma do cache, na hora).
    readonly property var provisoria: ({ fonte: fonte, largura: pedidoL, altura: pedidoA })

    // Enquanto ela voa para o visualizador (ou volta dele), o lugar fica vazio.
    opacity: emVoo ? 0 : 1

    Esqueleto {
        anchors.fill: parent
        radius: mini.raio
        visible: !mini.pronta && !mini.quebrada
    }

    // A foto com os cantos redondos (a máscara recorta a foto e o degradê do nome).
    Item {
        id: quadro
        anchors.fill: parent
        scale: area.pressed ? 0.97 : 1
        visible: mini.pronta
        layer.enabled: mini.pronta
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mascara
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
        Behavior on scale {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        Image {
            id: imagem
            anchors.centerIn: parent
            width: mini.deLado ? parent.height : parent.width
            height: mini.deLado ? parent.width : parent.height
            rotation: mini.giro
            source: mini.caminho !== "" ? mini.fonte : ""
            sourceSize: Qt.size(mini.pedidoL, mini.pedidoA)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            autoTransform: true
            cache: true
            smooth: true
            opacity: mini.pronta ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }
        }
        // Com o mouse em cima: clareia de leve e escurece embaixo, para o nome aparecer.
        Rectangle {
            anchors.fill: parent
            color: "#ffffff"
            opacity: area.containsMouse ? 0.06 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.min(parent.height, Math.round(janela.gu * 3.4))
            opacity: area.containsMouse || botaoCoracao.containsMouse ? 1 : (mini.favorita ? 0.55 : 0)
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0) }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.5) }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }
        }
    }
    Rectangle {
        id: mascara
        anchors.fill: parent
        visible: false
        layer.enabled: true
        radius: mini.raio
        color: "white"
    }

    // Não deu para abrir (formato que o sistema não lê, arquivo estragado).
    Rectangle {
        anchors.fill: parent
        visible: mini.quebrada
        radius: mini.raio
        color: janela.tinta(janela.escuro ? 0.06 : 0.05)
        border.width: 1
        border.color: janela.tinta(0.08)
        Column {
            anchors.centerIn: parent
            spacing: 4
            Kirigami.Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Kirigami.Units.iconSizes.medium
                height: width
                source: String(Qt.resolvedUrl("icones/foto-quebrada.svg"))
                isMask: true
                color: janela.frente
                opacity: 0.45
            }
            Texto {
                anchors.horizontalCenter: parent.horizontalCenter
                text: janela.nomeTipo(mini.foto.tipo)
                opacity: 0.5
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: mini.foto.nome || ""
        onClicked: (m) => {
            if (m.button === Qt.RightButton)
                mini.pedirMenu(m.x, m.y);
            else
                mini.abrir();
        }
    }

    // O nome, embaixo à esquerda, com o mouse em cima (se a miniatura for larga o bastante).
    Texto {
        anchors.left: parent.left
        anchors.right: botaoCoracao.left
        anchors.leftMargin: Math.round(janela.gu * 0.55)
        anchors.verticalCenter: botaoCoracao.verticalCenter
        visible: mini.width > janela.gu * 6.5 && mini.pronta
        opacity: area.containsMouse || botaoCoracao.containsMouse ? 1 : 0
        text: mini.foto.nome || ""
        color: "#ffffff"
        elide: Text.ElideMiddle
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
    }

    // O coração: aparece com o mouse em cima, e fica nas favoritas. Clicar pula.
    BotaoCoracao {
        id: botaoCoracao
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Math.round(janela.gu * 0.2)
        visible: mini.pronta || mini.quebrada
        ligado: mini.favorita
        mostrar: area.containsMouse || containsMouse || mini.favorita
        claro: true
        onClicado: janela.alternarFavorita(mini.caminho)
    }
}
