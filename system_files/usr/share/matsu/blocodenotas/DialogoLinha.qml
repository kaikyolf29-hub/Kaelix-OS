// "Ir para a linha" (Ctrl+G): o número da linha, com o aviso se ela não existe.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"
import "logica.js" as Logica

QQC2.Popup {
    id: dialogo

    property Item editor: null
    property int total: 1
    property string erro: ""

    function abrirPara(ed) {
        editor = ed;
        total = Logica.contarLinhas(ed.area.text);
        erro = "";
        campo.texto = String(Logica.linhaColuna(ed.area.text, ed.area.cursorPosition).linha);
        open();
    }
    function ir() {
        var n = parseInt(campo.texto, 10);
        if (!(n >= 1 && n <= total)) {
            erro = janela.t("Essa linha não existe: o texto tem %1.", "That line doesn't exist: the text has %1.")
                   .arg(total === 1 ? janela.t("1 linha", "1 line") : janela.t("%1 linhas", "%1 lines").arg(janela.num(total)));
            sacudir.restart();
            campo.focar();
            return;
        }
        var pos = Logica.inicioDaLinha(editor.area.text, n);
        close();
        editor.area.cursorPosition = pos;
        editor.mostrar(pos);
        editor.focar();
    }

    parent: QQC2.Overlay.overlay
    anchors.centerIn: parent
    modal: true
    focus: true
    padding: Math.round(janela.gu * 1.2)
    width: Math.min(Math.round(janela.gu * 18), parent ? parent.width - janela.gu * 4 : janela.gu * 18)
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
    onOpened: campo.focar()
    QQC2.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, janela.escuro ? 0.35 : 0.18)
    }
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 }
            NumberAnimation { property: "scale"; from: 0.92; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
        }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: 120 }
    }
    background: FundoBalao {
        radius: Math.round(janela.gu * 0.8)
    }

    contentItem: ColumnLayout {
        id: coluna
        spacing: Math.round(janela.gu * 0.6)

        Texto {
            text: janela.t("Ir para a linha", "Go to line")
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
            font.weight: Font.DemiBold
        }
        Campo {
            id: campo
            Layout.fillWidth: true
            icone: janela.ic("ir-linha")
            dica: janela.t("Número da linha", "Line number")
            podeLimpar: false
            onEditado: (t) => {
                var limpo = t.replace(/[^0-9]/g, "");
                if (limpo !== t)
                    campo.texto = limpo;
                dialogo.erro = "";
            }
            onConfirmado: dialogo.ir()
            transform: Translate {
                id: deslocamento
            }
            SequentialAnimation {
                id: sacudir
                NumberAnimation { target: deslocamento; property: "x"; to: -6; duration: 50 }
                NumberAnimation { target: deslocamento; property: "x"; to: 6; duration: 70 }
                NumberAnimation { target: deslocamento; property: "x"; to: -3; duration: 60 }
                NumberAnimation { target: deslocamento; property: "x"; to: 0; duration: 60 }
            }
        }
        Texto {
            Layout.fillWidth: true
            text: dialogo.erro || janela.t("De 1 a %1", "From 1 to %1").arg(janela.num(dialogo.total))
            color: dialogo.erro ? (janela.escuro ? "#ff9a9a" : "#c62828") : janela.frente
            opacity: dialogo.erro ? 1 : 0.6
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            wrapMode: Text.WordWrap
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
                onClicado: dialogo.close()
            }
            BotaoDestaque {
                texto: janela.t("Ir", "Go")
                onClicado: dialogo.ir()
            }
        }
    }
}
