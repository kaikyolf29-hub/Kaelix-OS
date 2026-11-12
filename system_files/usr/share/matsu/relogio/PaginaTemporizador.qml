// Temporizador: vários ao mesmo tempo, cada um num cartão com o anel. O fim vai
// para o systemd do usuário (toca com o app fechado). Vazio, mostra atalhos para
// começar rápido (1, 5, 10, 15 e 30 min).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    opacity: 0
    transform: Translate { id: desliza; y: janela.gu * 0.6 }
    Component.onCompleted: entrada.start()
    ParallelAnimation {
        id: entrada
        NumberAnimation { target: pagina; property: "opacity"; to: 1; duration: 220 }
        NumberAnimation { target: desliza; property: "y"; to: 0; duration: 380; easing.type: Easing.OutCubic }
    }

    Connections {
        target: janela
        function onNovo() {
            novo.abrir(null);
        }
    }

    // Batida rápida só com temporizador correndo (o anel anda liso).
    property real agoraMs: Date.now()
    Timer {
        interval: 50
        repeat: true
        running: janela.temporizadoresRodando > 0
        onTriggered: pagina.agoraMs = Date.now()
    }
    property string alvoMenu: ""

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.round(janela.gu * 1.4)
        anchors.rightMargin: Math.round(janela.gu * 1.4)
        anchors.topMargin: Math.round(janela.gu * 0.6)
        spacing: Math.round(janela.gu * 0.6)

        Cabecalho {
            Layout.fillWidth: true
            titulo: janela.t("Temporizador", "Timer")
            subtitulo: janela.temporizadoresRodando > 0
                       ? (janela.temporizadoresRodando === 1 ? janela.t("1 correndo", "1 running")
                                                             : janela.t(janela.temporizadoresRodando + " correndo", janela.temporizadoresRodando + " running"))
                       : ""
            BotaoDestaque {
                texto: janela.t("Novo temporizador", "New timer")
                icone: "matsu-mais-symbolic"
                onClicado: novo.abrir(null)
                QQC2.ToolTip.visible: containsMouse
                QQC2.ToolTip.text: "Ctrl+N"
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        GridView {
            id: grade
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: -Math.round(janela.gu * 0.35)
            Layout.rightMargin: -Math.round(janela.gu * 0.35)
            readonly property int colunas: Math.max(1, Math.floor(width / (janela.gu * 14)))
            cellWidth: Math.floor(width / colunas)
            cellHeight: Math.round(janela.gu * 14.2)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            bottomMargin: Math.round(janela.gu * 3)
            model: janela.temporizadores
            QQC2.ScrollBar.vertical: BarraRolagem {}

            delegate: Item {
                id: celula
                required property int index
                required property var model
                width: grade.cellWidth
                height: grade.cellHeight
                CartaoTemporizador {
                    id: cartaoT
                    anchors.fill: parent
                    anchors.margins: Math.round(janela.gu * 0.35)
                    agoraMs: Math.max(pagina.agoraMs, janela.agora.getTime())
                    item: ({ id: celula.model.id, nome: celula.model.nome, total: celula.model.total, restante: celula.model.restante,
                             fim: celula.model.fim, estado: celula.model.estado })
                    onEditar: novo.abrir(item)
                    onApagar: janela.apagarTemporizador(celula.model.id)
                    onMenu: (x, y) => {
                        pagina.alvoMenu = celula.model.id;
                        menuContexto.abrirEm(cartaoT, x, y);
                    }
                }
            }

            populate: Transition {
                id: chegada
                SequentialAnimation {
                    PropertyAction { property: "opacity"; value: 0 }
                    PauseAnimation { duration: Math.min(chegada.ViewTransition.index, 8) * 45 }
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; to: 1; duration: 260 }
                        NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 360; easing.type: Easing.OutCubic }
                    }
                }
            }
            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 240 }
                    NumberAnimation { property: "scale"; from: 0.86; to: 1; duration: 380; easing.type: Easing.OutBack }
                }
            }
            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: 180 }
                    NumberAnimation { property: "scale"; to: 0.9; duration: 180 }
                }
            }
            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 320; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; to: 1; duration: 120 }
                NumberAnimation { property: "scale"; to: 1; duration: 120 }
            }

            // Vazio: o convite e os atalhos de começar já.
            ColumnLayout {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -janela.gu
                width: Math.min(parent.width - janela.gu * 2, janela.gu * 26)
                visible: janela.temporizadores.count === 0
                spacing: Math.round(janela.gu * 0.9)
                Vazio {
                    Layout.alignment: Qt.AlignHCenter
                    icone: Qt.resolvedUrl("icones/ampulheta.svg")
                    titulo: janela.t("Nenhum temporizador", "No timers")
                    texto: janela.t("Para o chá, a massa ou a pausa do estudo. Avisa mesmo com o Relógio fechado.",
                                    "For the tea, the pasta or a study break. It alerts you even with Clock closed.")
                }
                Texto {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: janela.t("Comece agora", "Start now")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.6
                }
                Flow {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: parent.width
                    Layout.preferredWidth: implicitWidth
                    spacing: Math.round(janela.gu * 0.35)
                    Repeater {
                        model: [1, 5, 10, 15, 30]
                        Etiqueta {
                            required property int modelData
                            icone: "matsu-jogar-symbolic"
                            texto: modelData + " min"
                            onTrocada: janela.novoTemporizador(modelData + " min", modelData * 60, true)
                        }
                    }
                }
            }
        }
    }

    NovoTemporizador {
        id: novo
        onCriar: (nome, segundos) => janela.novoTemporizador(nome, segundos, true)
        onMudar: (ident, nome, segundos) => janela.editarTemporizador(ident, nome, segundos)
    }

    MenuMatsu {
        id: menuContexto
        itens: [
            { id: "editar", nome: janela.t("Editar", "Edit"), icone: Qt.resolvedUrl("icones/lapis.svg") },
            { id: "zerar", nome: janela.t("Zerar", "Reset"), icone: Qt.resolvedUrl("icones/zerar.svg") },
            { id: "apagar", nome: janela.t("Apagar", "Delete"), icone: "matsu-lixeira-symbolic", perigo: true, separador: true }
        ]
        onEscolhido: (id) => {
            var i = janela.indiceTemporizador(pagina.alvoMenu);
            if (i < 0)
                return;
            if (id === "editar")
                novo.abrir(janela.temporizadores.get(i));
            else if (id === "zerar")
                janela.zerarTemporizador(pagina.alvoMenu);
            else
                janela.apagarTemporizador(pagina.alvoMenu);
        }
    }
}
