// Pergunta um nome no meio da janela (criar e renomear playlist), no mesmo jeito do
// Dialogo de ../comum: Enter confirma, Esc cancela.
//   dialogoNome.pedir("Nova playlist", "", "Criar", function (nome) { ... })
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

QQC2.Popup {
    id: dialogo

    property string titulo: ""
    property string textoSim: ""
    property var aoConfirmar: null

    function pedir(t, nome, sim, funcao) {
        titulo = t;
        textoSim = sim;
        aoConfirmar = funcao;
        campo.texto = nome;
        open();
    }
    function confirmar() {
        var nome = campo.texto.trim();
        if (nome.length === 0)
            return;
        close();
        if (aoConfirmar)
            aoConfirmar(nome);
    }

    parent: QQC2.Overlay.overlay
    anchors.centerIn: parent
    modal: true
    focus: true
    padding: Math.round(janela.gu * 1.2)
    width: Math.min(Math.round(janela.gu * 22), parent ? parent.width - janela.gu * 4 : janela.gu * 22)
    closePolicy: QQC2.Popup.CloseOnEscape
    onOpened: campo.focar()
    QQC2.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, janela.escuro ? 0.45 : 0.25)
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
        spacing: Math.round(janela.gu * 0.8)
        Texto {
            Layout.fillWidth: true
            text: dialogo.titulo
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
            font.weight: Font.DemiBold
        }
        Campo {
            id: campo
            Layout.fillWidth: true
            dica: janela.t("Nome da playlist", "Playlist name")
            icone: janela.ic("playlist")
            maximo: 80
            onConfirmado: dialogo.confirmar()
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.2)
            spacing: Math.round(janela.gu * 0.5)
            Item {
                Layout.fillWidth: true
            }
            Botao {
                texto: janela.t("Cancelar", "Cancel")
                onClicado: dialogo.close()
            }
            BotaoDestaque {
                texto: dialogo.textoSim
                ativo: campo.texto.trim().length > 0
                onClicado: dialogo.confirmar()
            }
        }
    }
}
