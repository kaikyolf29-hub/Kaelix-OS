// Relógio mundial: a hora daqui num cartão grande (relógio de ponteiros e digital,
// a data e o nome do fuso, como "Horário de Brasília · UTC−3") e as cidades em
// cartões. Adicionar abre a busca; tirar tem Desfazer.
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
            busca.abrir();
        }
    }
    property string alvoMenu: ""
    readonly property bool estreita: width < janela.gu * 30

    Flickable {
        id: rolagem
        anchors.fill: parent
        contentHeight: corpo.implicitHeight + janela.gu * 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: BarraRolagem {}

        ColumnLayout {
            id: corpo
            x: Math.round(janela.gu * 1.4)
            y: Math.round(janela.gu * 0.6)
            width: rolagem.width - Math.round(janela.gu * 2.8)
            spacing: Math.round(janela.gu * 0.8)

            Cabecalho {
                Layout.fillWidth: true
                titulo: janela.t("Relógio mundial", "World clock")
                BotaoDestaque {
                    texto: janela.t("Adicionar cidade", "Add city")
                    icone: "matsu-mais-symbolic"
                    onClicado: busca.abrir()
                    QQC2.ToolTip.visible: containsMouse
                    QQC2.ToolTip.text: "Ctrl+N"
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }

            // A hora daqui.
            Cartao {
                Layout.fillWidth: true
                implicitHeight: linhaLocal.implicitHeight + Math.round(janela.gu * 2.4)
                radius: Math.round(janela.gu * 0.7)
                GridLayout {
                    id: linhaLocal
                    anchors.centerIn: parent
                    width: parent.width - Math.round(janela.gu * 2.4)
                    columns: pagina.estreita ? 1 : 2
                    columnSpacing: Math.round(janela.gu * 2)
                    rowSpacing: Math.round(janela.gu * 0.8)

                    RelogioAnalogico {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Math.round(janela.gu * (pagina.estreita ? 8 : 10))
                        Layout.preferredHeight: Layout.preferredWidth
                        intro: true
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: pagina.estreita ? Qt.AlignHCenter : Qt.AlignVCenter
                        spacing: Math.round(janela.gu * 0.15)
                        Row {
                            Layout.alignment: pagina.estreita ? Qt.AlignHCenter : Qt.AlignLeft
                            Accessible.role: Accessible.StaticText
                            Accessible.name: janela.agora.toLocaleTimeString(janela.local, "HH:mm:ss")
                            NumeroRolante {
                                id: horaGrande
                                anchors.bottom: parent.bottom
                                texto: janela.hhmm(janela.agora.getHours(), janela.agora.getMinutes())
                                font.pixelSize: Math.round(janela.gu * 3.6)
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                            }
                            NumeroRolante {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: Math.round(janela.gu * 0.42)
                                texto: ":" + janela.dois(janela.agora.getSeconds())
                                duracao: 380
                                cor: janela.tinta(0.55)
                                font.pixelSize: Math.round(janela.gu * 1.8)
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                            }
                        }
                        Texto {
                            Layout.fillWidth: true
                            horizontalAlignment: pagina.estreita ? Text.AlignHCenter : Text.AlignLeft
                            text: {
                                var s = janela.agora.toLocaleDateString(janela.local, janela.pt ? "dddd, d 'de' MMMM 'de' yyyy" : "dddd, MMMM d, yyyy");
                                return s.charAt(0).toUpperCase() + s.slice(1);
                            }
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
                            wrapMode: Text.WordWrap
                        }
                        Texto {
                            Layout.fillWidth: true
                            horizontalAlignment: pagina.estreita ? Text.AlignHCenter : Text.AlignLeft
                            text: (janela.fuso.nome || "") + " · " + janela.textoUtc(janela.desvioLocal())
                            opacity: 0.62
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 0.4)
                visible: janela.cidades.count > 0
                Texto {
                    Layout.fillWidth: true
                    text: janela.t("Outras cidades", "Other cities")
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
                    font.weight: Font.DemiBold
                }
            }

            GridView {
                id: grade
                Layout.fillWidth: true
                Layout.leftMargin: -Math.round(janela.gu * 0.35)
                Layout.rightMargin: -Math.round(janela.gu * 0.35)
                Layout.preferredHeight: Math.ceil(count / colunas) * cellHeight
                readonly property int colunas: Math.max(1, Math.floor(width / (janela.gu * 15)))
                cellWidth: Math.floor(width / colunas)
                cellHeight: Math.round(janela.gu * 6)
                interactive: false
                model: janela.cidades
                Behavior on Layout.preferredHeight {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
                delegate: Item {
                    id: celula
                    required property int index
                    required property var model
                    width: grade.cellWidth
                    height: grade.cellHeight
                    CartaoCidade {
                        id: cartaoC
                        anchors.fill: parent
                        anchors.margins: Math.round(janela.gu * 0.35)
                        cidade: ({ id: celula.model.id, nome: celula.model.nome, pais: celula.model.pais, fuso: celula.model.fuso,
                                   desvio: celula.model.desvio, ate: celula.model.ate, depois: celula.model.depois })
                        onRemover: janela.removerCidade(celula.model.id)
                        onMenu: (x, y) => {
                            pagina.alvoMenu = celula.model.id;
                            menuContexto.abrirEm(cartaoC, x, y);
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
            }

            // Sem cidades: um convite discreto.
            Rectangle {
                Layout.fillWidth: true
                visible: janela.cidades.count === 0
                implicitHeight: Math.round(janela.gu * 4.4)
                radius: Math.round(janela.gu * 0.6)
                color: "transparent"
                border.width: 1
                border.color: janela.tinta(0.12)
                Row {
                    anchors.centerIn: parent
                    spacing: Math.round(janela.gu * 0.6)
                    Kirigami.Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Kirigami.Units.iconSizes.small
                        height: width
                        source: "matsu-web-symbolic"
                        isMask: true
                        color: janela.frente
                        opacity: 0.6
                    }
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        text: janela.t("Ponha as cidades de quem você gosta para ver a hora de lá.", "Add the cities of people you care about.")
                        opacity: 0.65
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: busca.abrir()
                }
            }
        }
    }

    BuscaCidade {
        id: busca
        onEscolher: (id) => janela.adicionarCidade(id)
    }
    MenuMatsu {
        id: menuContexto
        itens: [{ id: "remover", nome: janela.t("Tirar do relógio mundial", "Remove"), icone: "matsu-lixeira-symbolic", perigo: true }]
        onEscolhido: (id) => janela.removerCidade(pagina.alvoMenu)
    }
}
