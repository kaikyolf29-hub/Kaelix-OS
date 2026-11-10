// Notificações recebidas (a lista do próprio KDE), com "não perturbe" e
// "limpar tudo" no topo, como a central de notificações do Windows 11.
// Os balões que aparecem na hora continuam sendo do KDE.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.notificationmanager as NotificationManager

ColumnLayout {
    id: notificacoes

    property var tradutor: (portugues, ingles) => portugues
    property bool silencio: false
    signal alternarSilencio()

    function t(portugues, ingles) {
        return tradutor(portugues, ingles);
    }

    spacing: Kirigami.Units.smallSpacing * 2

    NotificationManager.Settings {
        id: ajustes
    }

    NotificationManager.Notifications {
        id: lista
        showExpired: true
        showDismissed: true
        showJobs: false
        sortMode: NotificationManager.Notifications.SortByDate
        groupMode: NotificationManager.Notifications.GroupDisabled
        blacklistedDesktopEntries: ajustes.historyBlacklistedApplications
        blacklistedNotifyRcNames: ajustes.historyBlacklistedServices
        urgencies: NotificationManager.Notifications.CriticalUrgency | NotificationManager.Notifications.NormalUrgency
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            Layout.fillWidth: true
            level: 4
            text: notificacoes.t("Notificações", "Notifications")
            elide: Text.ElideRight
        }
        PlasmaComponents.ToolButton {
            visible: lista.count > 0
            text: notificacoes.t("Limpar tudo", "Clear all")
            onClicked: lista.clear(NotificationManager.Notifications.ClearExpired)
        }
        PlasmaComponents.ToolButton {
            icon.name: notificacoes.silencio ? "kaelix-sino-silencio-symbolic" : "kaelix-sino-symbolic"
            checkable: true
            checked: notificacoes.silencio
            display: QQC2.AbstractButton.IconOnly
            text: notificacoes.t("Não perturbe", "Do not disturb")
            QQC2.ToolTip.text: text
            QQC2.ToolTip.visible: hovered
            onClicked: notificacoes.alternarSilencio()
        }
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        visible: lista.count === 0
        horizontalAlignment: Text.AlignHCenter
        text: notificacoes.silencio
              ? notificacoes.t("Não perturbe ligado: os avisos chegam em silêncio.", "Do not disturb is on: notifications arrive silently.")
              : notificacoes.t("Nenhuma notificação nova", "No new notifications")
        wrapMode: Text.WordWrap
        opacity: 0.7
    }

    ListView {
        id: vista

        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, Kirigami.Units.gridUnit * 13)
        visible: count > 0
        clip: true
        spacing: Kirigami.Units.smallSpacing
        boundsBehavior: Flickable.StopAtBounds
        model: lista

        delegate: Rectangle {
            id: aviso

            required property int index
            required property string applicationName
            required property string applicationIconName
            required property string summary
            required property string body
            required property string iconName
            required property var created
            required property bool closable
            required property bool hasDefaultAction

            readonly property string quando: {
                var d = new Date(created);
                return d.toDateString() === new Date().toDateString()
                    ? d.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
                    : d.toLocaleDateString(Qt.locale(), Locale.ShortFormat);
            }

            width: ListView.view.width
            implicitHeight: conteudo.implicitHeight + Kirigami.Units.largeSpacing * 2
            radius: Math.round(Kirigami.Units.gridUnit * 0.55)
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b,
                           clique.containsMouse ? 0.10 : 0.05)

            MouseArea {
                id: clique
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: aviso.hasDefaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (aviso.hasDefaultAction) {
                        lista.invokeDefaultAction(lista.index(aviso.index, 0), NotificationManager.Notifications.Close);
                    }
                }
            }

            RowLayout {
                id: conteudo
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: Kirigami.Units.iconSizes.medium
                    implicitHeight: Kirigami.Units.iconSizes.medium
                    source: aviso.iconName || aviso.applicationIconName || "preferences-desktop-notification"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: aviso.applicationName
                            font: Kirigami.Theme.smallFont
                            elide: Text.ElideRight
                            opacity: 0.7
                        }
                        PlasmaComponents.Label {
                            text: aviso.quando
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                        }
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: aviso.summary
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: aviso.body.replace(/<[^>]*>/g, "")
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        opacity: 0.85
                    }
                }

                PlasmaComponents.ToolButton {
                    Layout.alignment: Qt.AlignTop
                    visible: aviso.closable
                    icon.name: "window-close-symbolic"
                    display: QQC2.AbstractButton.IconOnly
                    text: notificacoes.t("Fechar", "Close")
                    onClicked: lista.close(lista.index(aviso.index, 0))
                }
            }
        }
    }
}
