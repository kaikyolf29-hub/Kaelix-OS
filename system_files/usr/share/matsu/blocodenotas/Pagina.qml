// O miolo do Bloco de notas: as abas no topo, a folha (barra de ferramentas,
// localizar, o texto e a barra de status) e o arrastar e soltar de arquivos.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: tela

    // A folha: um degrau acima do miolo; a aba aberta tem a mesma cor e se junta a ela.
    readonly property color corFolha: janela.escuro ? Qt.rgba(1, 1, 1, 0.045) : Qt.rgba(1, 1, 1, 0.8)
    readonly property color corLinha: janela.tinta(janela.escuro ? 0.1 : 0.11)
    readonly property Item editorAtual: {
        janela.atual;
        editores.count;
        janela.mudancas;
        return editores.count > janela.atual ? editores.itemAt(janela.atual) : null;
    }
    property alias busca: busca
    property alias barraFerramentas: barraFerramentas

    function editor(i) {
        return i >= 0 && i < editores.count ? editores.itemAt(i) : null;
    }

    Component.onCompleted: {
        janela.tela = tela;
        janela.iniciar();
    }

    // As abas dos arquivos (a peça FaixaAbas de ../comum): a aberta tem o fundo da
    // folha e a borda fina; arrastar muda a ordem, o botão do meio fecha.
    FaixaAbas {
        id: barraAbas
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        modelo: janela.abas
        atual: janela.atual
        corFolha: tela.corFolha
        corLinha: tela.corLinha
        animar: janela.iniciado
        dicaDe: (aba) => aba.caminho ? aba.caminho : janela.t("Ainda não foi salvo", "Not saved yet")
        onEscolher: (i) => janela.irParaAba(i)
        onFechar: (i) => janela.fecharAba(i)
        onMover: (de, para) => janela.moverAba(de, para)
        onNova: janela.novaAba(false)
        onMenu: (i, item, x, y) => janela.abrirMenuAba(i, item, x, y)
    }

    Rectangle {
        id: folha
        anchors.top: barraAbas.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: tela.corFolha
        bottomRightRadius: Math.max(0, janela.raio - 2)
        bottomLeftRadius: Math.max(0, janela.raio - 2)

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            BarraFerramentas {
                id: barraFerramentas
                Layout.fillWidth: true
            }
            BarraBusca {
                id: busca
                Layout.fillWidth: true
                editor: tela.editorAtual
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: janela.tinta(janela.escuro ? 0.06 : 0.07)
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Repeater {
                    id: editores
                    model: janela.abas

                    Editor {
                        anchors.fill: parent
                        visible: index === janela.atual
                        achados: busca.aberta && index === janela.atual ? busca.achados : []
                        tamanhoAchado: busca.consulta.length
                    }
                }
            }
            BarraStatus {
                Layout.fillWidth: true
                visible: janela.barraStatus
                editor: tela.editorAtual
            }
        }
    }

    // Arrastar arquivos para a janela abre cada um numa aba.
    DropArea {
        id: soltar
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: (ev) => {
            var lista = [];
            for (var i = 0; i < ev.urls.length; i++)
                lista.push(String(ev.urls[i]));
            janela.abrirVarios(lista);
            ev.acceptProposedAction();
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: Math.round(janela.gu * 0.5)
        radius: Math.round(janela.gu * 0.6)
        color: janela.tinta(0.05)
        border.width: 1.5
        border.color: janela.tinta(0.35)
        opacity: soltar.containsDrag ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
        Column {
            anchors.centerIn: parent
            spacing: Math.round(janela.gu * 0.4)
            scale: soltar.containsDrag ? 1 : 0.9
            Behavior on scale {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutBack
                }
            }
            Kirigami.Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Kirigami.Units.iconSizes.large
                height: width
                source: janela.ic("novo")
                isMask: true
                color: janela.frente
            }
            Texto {
                anchors.horizontalCenter: parent.horizontalCenter
                text: janela.t("Solte para abrir", "Drop to open")
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
                font.weight: Font.DemiBold
            }
        }
    }
}
