// Pergunta no meio da janela, com o resto escurecido (apagar uma nota, sair sem
// salvar...). Um por janela basta:
//   Dialogo { id: dialogo }
//   dialogo.perguntar({ titulo: "Apagar a nota?", texto: "Não dá para desfazer.",
//                       sim: "Apagar", nao: "Cancelar", perigo: true }, function () { ... })
// Com "terceiro" aparece um terceiro botão (ex.: "Não salvar"), que chama o 3º argumento.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

QQC2.Popup {
    id: dialogo

    property var pedido: ({})
    property var aoSim: null
    property var aoTerceiro: null

    function perguntar(p, sim, terceiro) {
        pedido = p || {};
        aoSim = sim || null;
        aoTerceiro = terceiro || null;
        open();
    }

    parent: QQC2.Overlay.overlay
    anchors.centerIn: parent
    modal: true
    focus: true
    padding: Math.round(janela.gu * 1.2)
    width: Math.min(Math.round(janela.gu * 24), parent ? parent.width - janela.gu * 4 : janela.gu * 24)
    closePolicy: QQC2.Popup.CloseOnEscape
    // Enter confirma: o foco vai para o botão principal ao abrir.
    onOpened: botaoSim.forceActiveFocus()
    QQC2.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, janela.escuro ? 0.45 : 0.25)
        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
    }
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 }
            NumberAnimation { property: "scale"; from: 0.92; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
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
    contentItem: ColumnLayout {
        spacing: Math.round(janela.gu * 0.6)
        Texto {
            Layout.fillWidth: true
            text: dialogo.pedido.titulo || ""
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
        }
        Texto {
            Layout.fillWidth: true
            visible: text.length > 0
            text: dialogo.pedido.texto || ""
            opacity: 0.72
            wrapMode: Text.WordWrap
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.6)
            spacing: Math.round(janela.gu * 0.5)
            Botao {
                visible: !!dialogo.pedido.terceiro
                texto: dialogo.pedido.terceiro || ""
                onClicado: {
                    dialogo.close();
                    if (dialogo.aoTerceiro)
                        dialogo.aoTerceiro();
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Botao {
                texto: dialogo.pedido.nao || janela.t("Cancelar", "Cancel")
                onClicado: dialogo.close()
            }
            BotaoDestaque {
                id: botaoSim
                texto: dialogo.pedido.sim || janela.t("Continuar", "Continue")
                perigo: !!dialogo.pedido.perigo
                onClicado: {
                    dialogo.close();
                    if (dialogo.aoSim)
                        dialogo.aoSim();
                }
            }
        }
    }
}
