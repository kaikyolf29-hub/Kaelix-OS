// O balão da fonte (Exibir > Fonte, ou o botão "Aa"): JetBrains Mono ou Inter,
// o tamanho, e uma amostra que muda na hora.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

QQC2.Popup {
    id: painel

    function abrirEm(item) {
        var p = item.mapToItem(parent, item.width, item.height);
        x = Math.max(4, Math.min(p.x - width, parent.width - width - 4));
        y = p.y + 4;
        open();
    }

    parent: QQC2.Overlay.overlay
    padding: Math.round(janela.gu * 0.9)
    width: Math.round(janela.gu * 19)
    transformOrigin: QQC2.Popup.TopRight
    focus: true // para o Esc fechar o painel
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 }
            NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 220; easing.type: Easing.OutCubic }
        }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: 100 }
    }
    background: FundoBalao {}

    contentItem: ColumnLayout {
        spacing: Math.round(janela.gu * 0.6)

        Texto {
            text: janela.t("Fonte", "Font")
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
            font.weight: Font.DemiBold
        }
        Seletor {
            Layout.fillWidth: true
            opcoes: [
                { id: "mono", nome: janela.temJetBrains ? "JetBrains Mono" : janela.t("Monoespaçada", "Monospace") },
                { id: "inter", nome: "Inter" }
            ]
            escolhido: janela.fonte
            onEscolher: (id) => janela.fonte = id
        }
        RowLayout {
            Layout.fillWidth: true
            Texto {
                Layout.fillWidth: true
                text: janela.t("Tamanho", "Size")
                opacity: 0.8
            }
            Contador {
                valor: janela.tamanho
                minimo: 6
                maximo: 48
                sufixo: " pt"
                nome: janela.t("Tamanho", "Size")
                onMudou: (v) => janela.tamanho = v
            }
        }
        // A amostra, num cartão como o texto da folha.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: amostra.implicitHeight + Math.round(janela.gu * 1.2)
            radius: Math.round(janela.gu * 0.45)
            color: janela.tinta(janela.escuro ? 0.05 : 0.035)
            border.width: 1
            border.color: janela.tinta(janela.escuro ? 0.08 : 0.1)
            clip: true
            Texto {
                id: amostra
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Math.round(janela.gu * 0.6)
                text: janela.t("Açaí, pão de queijo e café.\n0123456789 {[( )]} → ✓", "The quick brown fox jumps.\n0123456789 {[( )]} → ✓")
                font.family: janela.familia
                font.pointSize: Math.min(janela.tamanho, 20)
                wrapMode: Text.WrapAnywhere
                Behavior on font.pointSize {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Texto {
                Layout.fillWidth: true
                text: janela.zoom !== 100 ? janela.t("Zoom de %1 por cima", "%1 zoom on top").arg(janela.num(janela.zoom) + "%") : ""
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.6
                elide: Text.ElideRight
            }
            Botao {
                texto: janela.t("Padrão", "Default")
                ativo: janela.fonte !== "mono" || janela.tamanho !== 11
                dica: janela.t("JetBrains Mono, 11 pt", "JetBrains Mono, 11 pt")
                onClicado: {
                    janela.fonte = "mono";
                    janela.tamanho = 11;
                }
            }
        }
    }
}
