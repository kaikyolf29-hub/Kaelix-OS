// Um aviso de app (notificação) na tela, no jeito do Mac: um cartão de vidro
// com o ícone do app à esquerda, o título em negrito, o texto embaixo e a hora
// no canto. Passando o mouse aparece o "x" no canto de cima, à esquerda, e o
// tempo para (o aviso não some enquanto o mouse está em cima). Clicar no
// cartão abre o app (a ação padrão). Os botões do app ficam embaixo do texto.
// Cópias de arquivo mostram a barra de progresso.
//
// Quem cria, posiciona e fecha os avisos é Avisos.qml; aqui é só a janela.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.notificationmanager as NotificationManager

PlasmaCore.Dialog {
    id: janela

    // O aviso (a linha do modelo de notificações do KDE) e quem cuida dele.
    property var aviso: ({})
    property var avisos
    property int tempoPadrao: 5000

    readonly property bool tarefa: aviso.type === NotificationManager.Notifications.JobType
    readonly property bool rodando: tarefa && aviso.jobState !== NotificationManager.Notifications.JobStateStopped
    readonly property var iconeDoApp: aviso.applicationIconName || ""
    // O desenho principal: a foto do aviso (um contato, uma captura de tela), o
    // ícone que o app mandou ou, sem nada disso, o ícone do app.
    readonly property var desenho: aviso.image ? aviso.image : (aviso.iconName ? aviso.iconName : (iconeDoApp || (tarefa ? "edit-copy" : "dialog-information")))
    readonly property bool comSelo: (!!aviso.image || (!!aviso.iconName && aviso.iconName !== iconeDoApp)) && iconeDoApp !== ""
    readonly property string titulo: aviso.summary || aviso.applicationName || ""
    readonly property string texto: {
        if (tarefa) {
            if (aviso.jobError && aviso.jobError.length) {
                return aviso.jobError;
            }
            var d = aviso.jobDetails;
            if (!d) {
                return "";
            }
            // O resumo do KDE ("12 de 40 arquivos para Downloads") ou o que o app mandou.
            var resumo = d.text || "";
            return resumo && resumo !== titulo ? resumo : (d.descriptionValue1 || "");
        }
        return aviso.body || "";
    }
    // No canto: a hora do aviso ou, nas cópias, como elas estão.
    readonly property string situacao: {
        if (!avisos) {
            return "";
        }
        if (tarefa && !rodando) {
            return aviso.jobError && aviso.jobError.length ? avisos.t("Falhou", "Failed") : avisos.t("Concluído", "Finished");
        }
        if (tarefa && aviso.jobState === NotificationManager.Notifications.JobStateSuspended) {
            return avisos.t("Pausado", "Paused");
        }
        return avisos.quando(aviso.updated || aviso.created);
    }
    readonly property var nomesDosBotoes: aviso.actionNames || []
    readonly property var rotulosDosBotoes: aviso.actionLabels || []

    // Quanto tempo fica na tela (o app pode pedir; -1 é o padrão do sistema).
    readonly property int tempo: {
        if (tarefa) {
            return rodando ? 0 : tempoPadrao;
        }
        if (aviso.timeout === -1 || aviso.timeout === undefined) {
            return tempoPadrao + ((aviso.urls || []).length > 0 ? 5000 : 0);
        }
        return aviso.timeout;
    }

    signal acabouOTempo()
    signal fechar()
    signal abrir()
    signal botao(string nome)
    signal cancelarTarefa()
    signal mouseEntrou()

    // Os urgentes aparecem até em cima de um app em tela cheia.
    type: aviso.urgency === NotificationManager.Notifications.CriticalUrgency ? PlasmaCore.Dialog.CriticalNotification : PlasmaCore.Dialog.Notification
    location: PlasmaCore.Types.Floating
    flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    hideOnWindowDeactivate: false
    visible: false

    mainItem: MouseArea {
        id: cartao

        readonly property int folga: Math.round(Kirigami.Units.smallSpacing * 1.5)
        readonly property int lado: Math.round(Kirigami.Units.gridUnit * 2.4)

        width: Kirigami.Units.gridUnit * 21
        height: conteudo.implicitHeight + folga * 2
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: janela.aviso.hasDefaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onContainsMouseChanged: if (containsMouse) janela.mouseEntrou()
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                janela.fechar();
            } else if (janela.aviso.hasDefaultAction) {
                janela.abrir();
            }
        }

        // O tempo na tela, parado enquanto o mouse está em cima.
        Timer {
            interval: janela.tempo
            running: janela.visible && interval > 0 && !cartao.containsMouse && !fecharArea.containsMouse
            onTriggered: janela.acabouOTempo()
        }

        Accessible.role: Accessible.AlertMessage
        Accessible.name: janela.titulo
        Accessible.description: janela.aviso.accessibleDescription || janela.texto

        RowLayout {
            id: conteudo
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: cartao.folga
            }
            spacing: Kirigami.Units.largeSpacing

            // O ícone (com o do app pequeno no canto, quando o desenho é outro).
            Item {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: cartao.lado
                Layout.preferredHeight: cartao.lado

                Kirigami.Icon {
                    anchors.fill: parent
                    source: janela.desenho
                    fallback: "dialog-information"
                }
                Kirigami.Icon {
                    visible: janela.comSelo
                    width: Math.round(cartao.lado * 0.45)
                    height: width
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                        rightMargin: -Math.round(width * 0.2)
                        bottomMargin: -Math.round(width * 0.2)
                    }
                    source: janela.iconeDoApp
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Math.round(Kirigami.Units.smallSpacing / 2)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: janela.titulo
                        textFormat: Text.PlainText
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignTop
                        text: janela.situacao
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.6
                    }
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: janela.texto
                    textFormat: janela.tarefa ? Text.PlainText : Text.StyledText
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: 4
                    opacity: 0.85
                    linkColor: Kirigami.Theme.linkColor
                    onLinkActivated: link => {
                        Qt.openUrlExternally(link);
                        janela.fechar();
                    }
                }

                // Cópia de arquivos: a barra de progresso e a porcentagem.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    visible: janela.rodando
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.ProgressBar {
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        value: janela.aviso.percentage || 0
                        indeterminate: janela.aviso.jobState === NotificationManager.Notifications.JobStateRunning
                                       && !(janela.aviso.percentage > 0)
                    }
                    PlasmaComponents.Label {
                        text: Math.round(janela.aviso.percentage || 0) + "%"
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.7
                    }
                }

                // Os botões do app (no máximo três) e o "Cancelar" das cópias.
                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    visible: repetidor.count > 0 || cancelar.visible
                    spacing: Kirigami.Units.smallSpacing

                    Repeater {
                        id: repetidor
                        model: janela.tarefa ? [] : Math.min(3, janela.nomesDosBotoes.length)
                        PlasmaComponents.Button {
                            required property int index
                            text: janela.rotulosDosBotoes[index] || ""
                            onClicked: janela.botao(janela.nomesDosBotoes[index])
                        }
                    }
                    PlasmaComponents.Button {
                        id: cancelar
                        visible: janela.rodando && !!janela.aviso.killable
                        text: janela.avisos ? janela.avisos.t("Cancelar", "Cancel") : "Cancelar"
                        onClicked: janela.cancelarTarefa()
                    }
                }
            }
        }

        // O "x" redondo no canto, como no Mac: só com o mouse em cima.
        MouseArea {
            id: fecharArea
            readonly property int tamanho: Math.round(Kirigami.Units.gridUnit * 1.05)
            x: -Math.round(tamanho * 0.35)
            y: -Math.round(tamanho * 0.35)
            width: tamanho
            height: tamanho
            visible: janela.aviso.closable !== false || janela.aviso.dismissable === true
            opacity: cartao.containsMouse || containsMouse ? 1 : 0
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: janela.fechar()
            Accessible.role: Accessible.Button
            Accessible.name: janela.avisos ? janela.avisos.t("Fechar", "Close") : "Fechar"
            Behavior on opacity {
                NumberAnimation { duration: Kirigami.Units.shortDuration }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: fecharArea.containsMouse
                       ? Qt.tint(Kirigami.Theme.backgroundColor, Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12))
                       : Kirigami.Theme.backgroundColor
                border.width: 1
                border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.18)
            }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: Math.round(fecharArea.tamanho * 0.55)
                height: width
                source: "window-close-symbolic"
                isMask: true
                color: Kirigami.Theme.textColor
            }
        }
    }
}
