// Escolha numa lista, do jeito do Matsu (no lugar da caixa de opções crua do
// KDE): um botão de vidro com a escolha de agora e a setinha; ao clicar, abre
// uma lista de vidro logo embaixo (ou em cima, se não couber), que aparece
// crescendo de leve. A escolhida tem o sinal de certo; cada linha pode ter um
// detalhe à direita (ex.: "Recomendada").
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

MouseArea {
    id: escolha

    // Cada opção: { valor: "1920x1080", nome: "1920 × 1080", detalhe: "Recomendada" }
    property var opcoes: []
    property string atual: ""
    // O que o botão mostra (vazio = o nome da opção escolhida).
    property string texto: ""
    property string nomeAcessivel: ""
    readonly property bool escuro: Kirigami.Theme.backgroundColor.hslLightness < 0.5
    readonly property int gu: Kirigami.Units.gridUnit

    signal escolhido(string valor)

    readonly property int indice: {
        for (var i = 0; i < opcoes.length; i++)
            if (opcoes[i].valor === atual)
                return i;
        return -1;
    }
    readonly property string mostrado: texto.length > 0 ? texto : (indice >= 0 ? opcoes[indice].nome : "")

    // A largura do texto mais comprido, para a lista não cortar nada.
    readonly property real larguraCheia: {
        var maior = gu * 6;
        for (var i = 0; i < opcoes.length; i++) {
            var w = medida.advanceWidth(opcoes[i].nome) + (opcoes[i].detalhe ? medidaPequena.advanceWidth(opcoes[i].detalhe) + gu * 0.4 : 0);
            maior = Math.max(maior, w);
        }
        // + o sinal de certo, os vãos, as margens e a barra de rolar.
        return Math.ceil(maior * 1.06 + Kirigami.Units.iconSizes.small + gu * 3.4);
    }
    FontMetrics {
        id: medida
        font.family: Kirigami.Theme.defaultFont.family
        font.pointSize: Kirigami.Theme.defaultFont.pointSize
        font.weight: Font.DemiBold
    }
    FontMetrics {
        id: medidaPequena
        font.family: Kirigami.Theme.defaultFont.family
        font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
    }

    function escolherMarcada() {
        if (vista.currentIndex >= 0 && vista.currentIndex < opcoes.length) {
            escolhido(opcoes[vista.currentIndex].valor);
        }
        lista.close();
    }

    implicitWidth: Math.max(gu * 6, conteudo.implicitWidth + gu * 1.3)
    implicitHeight: Math.round(gu * 1.75)
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    activeFocusOnTab: true
    Accessible.role: Accessible.ComboBox
    Accessible.name: nomeAcessivel
    Accessible.description: mostrado
    onClicked: lista.opened ? lista.close() : lista.open()
    Keys.onReturnPressed: lista.open()
    Keys.onSpacePressed: lista.open()

    Rectangle {
        anchors.fill: parent
        radius: Math.round(escolha.gu * 0.5)
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b,
                       escolha.pressed || lista.opened ? 0.14 : (escolha.containsMouse ? 0.11 : 0.07))
        border.width: escolha.activeFocus ? 2 : 1
        border.color: escolha.activeFocus ? Kirigami.Theme.highlightColor
                                          : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
    }

    RowLayout {
        id: conteudo
        anchors.fill: parent
        anchors.leftMargin: Math.round(escolha.gu * 0.65)
        anchors.rightMargin: Math.round(escolha.gu * 0.45)
        spacing: Math.round(escolha.gu * 0.4)

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: escolha.mostrado
            elide: Text.ElideRight
            font.features: ({ "tnum": 1 })
        }
        // A setinha aponta para baixo e gira para cima com a lista aberta.
        Kirigami.Icon {
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
            source: "matsu-seta-symbolic"
            isMask: true
            color: Kirigami.Theme.textColor
            opacity: 0.6
            rotation: lista.opened ? -90 : 90
            Behavior on rotation {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    QQC2.Popup {
        id: lista

        readonly property int altura: Math.min(vista.contentHeight + topPadding + bottomPadding, Math.round(escolha.gu * 15))
        // Abre embaixo; se não couber na janela, abre em cima.
        readonly property bool emCima: {
            var janela = escolha.Window.window;
            if (!janela)
                return false;
            var p = escolha.mapToItem(null, 0, escolha.height);
            return p.y + altura + escolha.gu > janela.height && p.y - escolha.height - altura > 0;
        }

        y: emCima ? -altura - 4 : escolha.height + 4
        x: Math.min(0, escolha.width - width)
        width: Math.max(escolha.width, escolha.larguraCheia + leftPadding + rightPadding)
        height: altura
        padding: 4
        margins: Math.round(escolha.gu * 0.5)
        modal: false
        focus: true
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent
        transformOrigin: emCima ? QQC2.Popup.Bottom : QQC2.Popup.Top

        onAboutToShow: vista.currentIndex = Math.max(0, escolha.indice)
        onOpened: {
            vista.positionViewAtIndex(Math.max(0, escolha.indice), ListView.Contain);
            vista.forceActiveFocus();
        }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 220; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 1; to: 0.97; duration: 120; easing.type: Easing.OutCubic }
            }
        }

        background: Kirigami.ShadowedRectangle {
            radius: Math.round(escolha.gu * 0.6)
            color: escolha.escuro ? Qt.rgba(0.17, 0.17, 0.185, 0.98) : Qt.rgba(0.985, 0.985, 0.99, 0.98)
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
            shadow.size: Math.round(escolha.gu * 1.1)
            shadow.yOffset: 4
            shadow.color: Qt.rgba(0, 0, 0, escolha.escuro ? 0.45 : 0.18)
        }

        contentItem: ListView {
            id: vista

            clip: true
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: true
            highlightMoveDuration: 0
            model: escolha.opcoes
            QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                policy: vista.contentHeight > vista.height ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff
            }
            Keys.onReturnPressed: escolha.escolherMarcada()
            Keys.onEnterPressed: escolha.escolherMarcada()
            Keys.onSpacePressed: escolha.escolherMarcada()

            delegate: MouseArea {
                id: item

                required property var modelData
                required property int index
                readonly property bool escolhida: modelData.valor === escolha.atual
                readonly property bool marcada: containsMouse || (vista.activeFocus && ListView.isCurrentItem)

                width: ListView.view.width
                implicitHeight: Math.round(escolha.gu * 1.85)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.ListItem
                Accessible.name: modelData.nome
                Accessible.selected: escolhida
                onContainsMouseChanged: if (containsMouse) vista.currentIndex = index
                onClicked: {
                    escolha.escolhido(modelData.valor);
                    lista.close();
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Math.round(escolha.gu * 0.4)
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b,
                                   item.pressed ? 0.14 : (item.marcada ? 0.09 : 0))
                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(escolha.gu * 0.4)
                    anchors.rightMargin: Math.round(escolha.gu * 0.6)
                    spacing: Math.round(escolha.gu * 0.4)

                    Item {
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: implicitWidth
                        Kirigami.Icon {
                            anchors.fill: parent
                            visible: item.escolhida
                            source: "matsu-certo-symbolic"
                            isMask: true
                            color: Kirigami.Theme.textColor
                        }
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: item.modelData.nome
                        elide: Text.ElideRight
                        font.weight: item.escolhida ? Font.DemiBold : Font.Normal
                        font.features: ({ "tnum": 1 })
                    }
                    PlasmaComponents.Label {
                        visible: text.length > 0
                        text: item.modelData.detalhe || ""
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                        opacity: 0.6
                    }
                }
            }
        }
    }
}
