// Cartão de uma cidade no relógio mundial: o reloginho (mostrador claro de dia,
// escuro de noite), o nome e o país, a hora de lá (rola ao mudar o minuto), a
// diferença ("+4 h") com o sol ou a lua e o dia ("Amanhã"). O xis aparece com o mouse.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

MouseArea {
    id: cartao

    property var cidade: ({ id: "", nome: "", pais: "", fuso: "", desvio: 0, ate: 0, depois: 0 })

    signal remover()
    signal menu(real x, real y)

    readonly property real desvio: janela.desvioCidade(cidade, janela.agora.getTime())
    readonly property date la: new Date(janela.agora.getTime() + desvio * 1000)
    readonly property int horaLa: la.getUTCHours()
    readonly property bool noite: horaLa < 6 || horaLa >= 18
    readonly property real diferenca: desvio - janela.desvioLocal()
    readonly property string textoDiferenca: {
        if (Math.abs(diferenca) < 60)
            return janela.t("Mesmo horário", "Same time");
        var s = Math.abs(diferenca), h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
        return (diferenca > 0 ? "+" : "−") + (h ? h + " h" : "") + (h && m ? " " : "") + (m ? m + " min" : "");
    }
    readonly property string textoDia: {
        var local = janela.agora;
        var a = Date.UTC(la.getUTCFullYear(), la.getUTCMonth(), la.getUTCDate());
        var b = Date.UTC(local.getFullYear(), local.getMonth(), local.getDate());
        var dif = Math.round((a - b) / 86400000);
        return dif > 0 ? janela.t("Amanhã", "Tomorrow") : (dif < 0 ? janela.t("Ontem", "Yesterday") : janela.t("Hoje", "Today"));
    }

    hoverEnabled: true
    acceptedButtons: Qt.RightButton
    onClicked: (m) => cartao.menu(m.x, m.y)
    activeFocusOnTab: true
    Keys.onDeletePressed: cartao.remover()
    Accessible.role: Accessible.StaticText
    Accessible.name: cidade.nome + ", " + janela.hhmm(horaLa, la.getUTCMinutes()) + ", " + textoDiferenca + ", " + textoDia

    Rectangle {
        anchors.fill: parent
        radius: Math.round(janela.gu * 0.6)
        color: janela.cartao
        border.width: 1
        border.color: cartao.activeFocus ? janela.destaque : janela.bordaCartao
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: janela.tinta(0.03)
            opacity: cartao.containsMouse ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.round(janela.gu * 0.8)
        anchors.rightMargin: Math.round(janela.gu * 0.9)
        spacing: Math.round(janela.gu * 0.8)

        RelogioAnalogico {
            Layout.preferredWidth: Math.round(janela.gu * 4)
            Layout.preferredHeight: Layout.preferredWidth
            desvio: cartao.desvio
            numeros: false
            segundos: true
            noite: cartao.noite
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Texto {
                Layout.fillWidth: true
                Layout.rightMargin: Math.round(janela.gu * 1.2)
                text: cartao.cidade.nome
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Texto {
                Layout.fillWidth: true
                text: cartao.cidade.pais
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.6
                elide: Text.ElideRight
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 0.2)
                spacing: Math.round(janela.gu * 0.5)
                NumeroRolante {
                    texto: janela.hhmm(cartao.horaLa, cartao.la.getUTCMinutes())
                    font.pixelSize: Math.round(janela.gu * 1.55)
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    RowLayout {
                        spacing: 3
                        Kirigami.Icon {
                            implicitWidth: Math.round(Kirigami.Units.iconSizes.small * 0.8)
                            implicitHeight: implicitWidth
                            source: cartao.noite ? "matsu-lua-symbolic" : "matsu-brilho-symbolic"
                            isMask: true
                            color: janela.frente
                            opacity: 0.7
                        }
                        Texto {
                            text: cartao.textoDiferenca
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.75
                        }
                    }
                    Texto {
                        text: cartao.textoDia
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.55
                    }
                }
            }
        }
    }

    Botao {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Math.round(janela.gu * 0.3)
        implicitWidth: implicitHeight
        icone: "matsu-fechar-symbolic"
        dica: janela.t("Tirar do relógio mundial", "Remove from world clock")
        opacity: cartao.containsMouse || activeFocus ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
        onClicado: cartao.remover()
    }
}
