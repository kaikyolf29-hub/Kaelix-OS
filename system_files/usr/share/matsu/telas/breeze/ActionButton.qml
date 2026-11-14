// Matsu OS — os botões redondos das telas do KDE
// (org.kde.breeze.components.ActionButton): Suspender, Reiniciar, Desligar,
// Outros... na tela de login, no lugar do original da Breeze.
//
// Um círculo de vidro com a borda clara e o ícone do Matsu em branco, o nome
// embaixo (igual ao Matsu.BotaoRedondo do bloqueio). Continua sendo o mesmo
// AbstractButton do KDE: text, icon.name, clicked(), atalho pela letra
// sublinhada e Enter.
import QtQuick
import QtQuick.Window
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

PlasmaComponents3.AbstractButton {
    id: root
    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software

    // O tamanho sai da altura da tela, como no bloqueio do Matsu.
    readonly property real alturaTela: Window.window && Window.window.height > 0 ? Window.window.height : 1080
    readonly property real lado: Math.max(36, Math.round(alturaTela * 0.036))

    // Os ícones do Matsu (por arquivo, para valer com qualquer tema de ícones da
    // tela de login); um nome que não está aqui usa o ícone do tema.
    readonly property string iconeMatsu: ({
        "system-suspend": "matsu-lua",
        "system-suspend-hibernate": "matsu-hibernar",
        "system-hibernate": "matsu-hibernar",
        "system-reboot": "matsu-reiniciar",
        "system-shutdown": "matsu-desligar",
        "system-log-out": "matsu-sair",
        "system-switch-user": "matsu-trocar-usuario",
        "system-user-prompt": "matsu-outra-pessoa",
        "system-user-list": "matsu-trocar-usuario"
    })[root.icon.name] || ""

    font.family: Kirigami.Theme.defaultFont.family
    font.pixelSize: Math.max(11, Math.round(lado * 0.27))
    font.weight: Font.Medium

    icon.width: Math.round(lado * 0.46)
    icon.height: Math.round(lado * 0.46)

    hoverEnabled: true
    activeFocusOnTab: true

    leftInset: Math.max(Kirigami.Units.largeSpacing * 2, (implicitContentWidth - implicitBackgroundWidth) / 2)
    rightInset: leftInset
    padding: 0
    horizontalPadding: Kirigami.Units.smallSpacing
    bottomPadding: 0
    spacing: Math.round(lado * 0.18)

    Kirigami.MnemonicData.enabled: root.enabled && root.visible
    Kirigami.MnemonicData.controlType: Kirigami.MnemonicData.SecondaryControl
    Kirigami.MnemonicData.label: root.text

    Shortcut {
        // Quando o texto já tem o & certo, o próprio botão cuida do atalho.
        enabled: !(RegExp(/\&[^\&]/).test(root.text))
        sequence: root.Kirigami.MnemonicData.sequence
        onActivated: root.animateClick()
    }

    background: Item {
        implicitWidth: root.lado
        implicitHeight: root.lado
        width: implicitWidth
        height: implicitHeight
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.rgba(1, 1, 1, root.down ? 0.3 : (root.hovered || root.activeFocus ? 0.24 : 0.14))
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, root.activeFocus ? 0.7 : 0.2)
            scale: root.down ? 0.93 : 1
            Behavior on color {
                ColorAnimation { duration: 150 }
            }
            Behavior on scale {
                NumberAnimation { duration: 120 }
            }
        }
    }

    contentItem: Column {
        spacing: root.spacing
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.lado
            height: root.lado
            Kirigami.Icon {
                anchors.centerIn: parent
                width: root.icon.width
                height: root.icon.height
                source: root.iconeMatsu !== ""
                    ? "/usr/share/icons/Matsu/status/symbolic/" + root.iconeMatsu + "-symbolic.svg"
                    : root.icon.name
                isMask: true
                color: "white"
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, Math.max(parent.width, root.lado * 2.4))
            text: root.Kirigami.MnemonicData.richTextLabel
            textFormat: Text.StyledText
            color: "white"
            opacity: root.hovered || root.activeFocus ? 1 : 0.8
            font: root.font
            style: root.softwareRendering ? Text.Outline : Text.Raised
            styleColor: Qt.rgba(0, 0, 0, root.softwareRendering ? 0.6 : 0.25)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignTop
            wrapMode: Text.WordWrap
        }
    }

    Keys.onEnterPressed: clicked()
    Keys.onReturnPressed: clicked()
}
