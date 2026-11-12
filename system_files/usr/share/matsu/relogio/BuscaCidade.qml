// Adicionar uma cidade ao relógio mundial: busca (sem ligar para acentos) na lista
// de cidades em português, com a hora de lá e a diferença. Setas escolhem, Enter põe.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

QQC2.Popup {
    id: busca

    signal escolher(string id)

    property string termo: ""
    readonly property var achadas: {
        var t = janela.simples(termo.trim()), r = [];
        for (var i = 0; i < janela.catalogo.length; i++) {
            var c = janela.catalogo[i];
            if (!t || janela.simples(c.nome).indexOf(t) >= 0 || janela.simples(c.pais).indexOf(t) >= 0)
                r.push(c);
        }
        return r;
    }

    function abrir() {
        campo.texto = "";
        termo = "";
        lista.currentIndex = 0;
        open();
    }
    function pegar(i) {
        if (i < 0 || i >= achadas.length || janela.temCidade(achadas[i].id))
            return;
        escolher(achadas[i].id);
        close();
    }

    parent: QQC2.Overlay.overlay
    anchors.centerIn: parent
    modal: true
    focus: true
    padding: Math.round(janela.gu * 1.1)
    width: Math.min(Math.round(janela.gu * 26), parent ? parent.width - janela.gu * 2 : janela.gu * 26)
    height: Math.min(Math.round(janela.gu * 26), parent ? parent.height - janela.gu * 2 : janela.gu * 26)
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
    onOpened: campo.focar()
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

    contentItem: ColumnLayout {
        spacing: Math.round(janela.gu * 0.7)
        RowLayout {
            Layout.fillWidth: true
            Texto {
                Layout.fillWidth: true
                text: janela.t("Adicionar cidade", "Add city")
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                font.weight: Font.DemiBold
            }
            Botao {
                icone: "matsu-fechar-symbolic"
                dica: janela.t("Fechar", "Close")
                onClicado: busca.close()
            }
        }
        Campo {
            id: campo
            Layout.fillWidth: true
            icone: "matsu-busca-symbolic"
            dica: janela.t("Buscar cidade ou país", "Search city or country")
            onEditado: (t) => {
                busca.termo = t;
                lista.currentIndex = 0;
            }
            onConfirmado: busca.pegar(lista.currentIndex)
            entrada.Keys.onDownPressed: lista.incrementCurrentIndex()
            entrada.Keys.onUpPressed: lista.decrementCurrentIndex()
        }
        ListView {
            id: lista
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: busca.achadas
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 120
            keyNavigationWraps: false
            QQC2.ScrollBar.vertical: BarraRolagem {}
            highlight: Rectangle {
                radius: Math.round(janela.gu * 0.35)
                color: janela.tinta(0.07)
            }
            delegate: MouseArea {
                id: linha
                required property var modelData
                required property int index
                readonly property bool ja: janela.temCidade(modelData.id)
                readonly property date la: new Date(janela.agora.getTime() + modelData.desvio * 1000)
                width: lista.width - Math.round(janela.gu * 0.6)
                height: Math.round(janela.gu * 2.6)
                hoverEnabled: true
                cursorShape: ja ? Qt.ArrowCursor : Qt.PointingHandCursor
                onEntered: lista.currentIndex = index
                onClicked: busca.pegar(index)
                Accessible.role: Accessible.ListItem
                Accessible.name: modelData.nome + ", " + modelData.pais + (ja ? ", " + janela.t("já está no relógio", "already added") : "")
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(janela.gu * 0.6)
                    anchors.rightMargin: Math.round(janela.gu * 0.6)
                    spacing: Math.round(janela.gu * 0.6)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Texto {
                            Layout.fillWidth: true
                            text: linha.modelData.nome
                            elide: Text.ElideRight
                            opacity: linha.ja ? 0.5 : 1
                        }
                        Texto {
                            Layout.fillWidth: true
                            text: linha.modelData.pais
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.55
                            elide: Text.ElideRight
                        }
                    }
                    Texto {
                        text: janela.hhmm(linha.la.getUTCHours(), linha.la.getUTCMinutes())
                        font.features: { "tnum": 1 }
                        opacity: linha.ja ? 0.5 : 0.85
                    }
                    Kirigami.Icon {
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: implicitWidth
                        source: linha.ja ? "matsu-certo-symbolic" : "matsu-mais-symbolic"
                        isMask: true
                        color: janela.frente
                        opacity: linha.ja ? 0.6 : (linha.containsMouse ? 0.9 : 0.35)
                    }
                }
            }
            Texto {
                anchors.centerIn: parent
                visible: lista.count === 0
                text: janela.catalogo.length === 0 ? janela.t("Carregando as cidades…", "Loading cities…")
                                                   : janela.t("Nenhuma cidade com esse nome", "No city with that name")
                opacity: 0.6
            }
        }
    }
}
