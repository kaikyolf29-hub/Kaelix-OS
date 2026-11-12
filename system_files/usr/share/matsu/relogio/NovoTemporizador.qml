// Criar (ou editar) um temporizador: os atalhos de 1, 5, 10, 15 e 30 min (as rodas
// rolam até o tempo escolhido), as rodas de hora, minuto e segundo e o nome.
//   novo.abrir(null)   novo        novo.abrir(item)   editar
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

QQC2.Popup {
    id: novo

    property string ident: ""
    property int horas: 0
    property int minutos: 5
    property int segundos: 0
    readonly property int total: horas * 3600 + minutos * 60 + segundos

    signal criar(string nome, int segundos)
    signal mudar(string ident, string nome, int segundos)

    function abrir(item) {
        ident = item ? item.id : "";
        var t = item ? item.total : 300;
        horas = Math.floor(t / 3600);
        minutos = Math.floor(t / 60) % 60;
        segundos = t % 60;
        campoNome.texto = item ? item.nome : "";
        open();
    }
    function confirmar() {
        if (total <= 0)
            return;
        if (ident)
            mudar(ident, campoNome.texto.trim(), total);
        else
            criar(campoNome.texto.trim(), total);
        close();
    }

    parent: QQC2.Overlay.overlay
    anchors.centerIn: parent
    modal: true
    focus: true
    padding: Math.round(janela.gu * 1.2)
    width: Math.min(Math.round(janela.gu * 26), parent ? parent.width - janela.gu * 2 : janela.gu * 26)
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
    onOpened: rodaMin.forceActiveFocus()
    QQC2.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, janela.escuro ? 0.45 : 0.25)
    }
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 }
            NumberAnimation { property: "scale"; from: 0.92; to: 1; duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; to: 0; duration: 120 }
            NumberAnimation { property: "scale"; to: 0.96; duration: 120 }
        }
    }
    background: FundoBalao {
        radius: Math.round(janela.gu * 0.8)
    }
    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: novo.opened
        onActivated: novo.confirmar()
    }

    contentItem: ColumnLayout {
        spacing: Math.round(janela.gu * 0.8)

        RowLayout {
            Layout.fillWidth: true
            Texto {
                Layout.fillWidth: true
                text: novo.ident ? janela.t("Editar temporizador", "Edit timer") : janela.t("Novo temporizador", "New timer")
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Botao {
                icone: "matsu-fechar-symbolic"
                dica: janela.t("Fechar", "Close")
                onClicado: novo.close()
            }
        }

        // Atalhos de tempo.
        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(janela.gu * 0.3)
            Repeater {
                model: [1, 5, 10, 15, 30]
                Etiqueta {
                    required property int modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    texto: modelData + " min"
                    escolhida: novo.total === modelData * 60
                    onTrocada: {
                        novo.horas = 0;
                        novo.minutos = modelData;
                        novo.segundos = 0;
                    }
                }
            }
        }

        // As rodas.
        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: Math.round(janela.gu * 0.9)
            spacing: Math.round(janela.gu * 0.3)
            RodaNumero {
                quantos: 24
                valor: novo.horas
                nome: janela.t("Horas", "Hours")
                sufixo: "h"
                onMudou: (v) => novo.horas = v
            }
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: ":"
                font.pixelSize: Math.round(janela.gu * 1.4)
                font.weight: Font.DemiBold
                opacity: 0.6
            }
            RodaNumero {
                id: rodaMin
                quantos: 60
                valor: novo.minutos
                nome: janela.t("Minutos", "Minutes")
                sufixo: "min"
                onMudou: (v) => novo.minutos = v
            }
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: ":"
                font.pixelSize: Math.round(janela.gu * 1.4)
                font.weight: Font.DemiBold
                opacity: 0.6
            }
            RodaNumero {
                quantos: 60
                valor: novo.segundos
                nome: janela.t("Segundos", "Seconds")
                sufixo: "s"
                onMudou: (v) => novo.segundos = v
            }
        }

        Campo {
            id: campoNome
            Layout.fillWidth: true
            dica: janela.t("Nome (ex.: Chá, Massa, Pausa)", "Name (e.g. Tea, Pasta, Break)")
            maximo: 40
            onConfirmado: novo.confirmar()
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.3)
            spacing: Math.round(janela.gu * 0.5)
            Item {
                Layout.fillWidth: true
            }
            Botao {
                texto: janela.t("Cancelar", "Cancel")
                onClicado: novo.close()
            }
            BotaoDestaque {
                texto: novo.ident ? janela.t("Salvar", "Save") : janela.t("Começar", "Start")
                icone: novo.ident ? "" : "matsu-jogar-symbolic"
                ativo: novo.total > 0
                onClicado: novo.confirmar()
            }
        }
    }
}
