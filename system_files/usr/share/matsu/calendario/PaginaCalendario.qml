// A página do calendário: a barra (setas, "Hoje", o período, o Seletor Mês/Semana/Dia,
// "Novo evento" e o menu) e a visão escolhida, que entra deslizando a cada período.
// Em janela estreita a barra vira duas linhas.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"
import "datas.js" as Datas

Item {
    id: pagina

    readonly property bool estreita: width < janela.gu * 42
    readonly property string titulo: janela.visao === "mes" ? Datas.tituloMes(janela.foco, janela.pt)
                                   : (janela.visao === "semana" ? Datas.tituloSemana(janela.foco, janela.pt)
                                   : (janela.pt ? janela.foco.getDate() + " de " + Datas.MESES[janela.foco.getMonth()] + " de " + janela.foco.getFullYear()
                                                : Datas.MESES_EN[janela.foco.getMonth()] + " " + janela.foco.getDate() + ", " + janela.foco.getFullYear()))
    readonly property var opcoesVisao: [
        { id: "mes", nome: janela.t("Mês", "Month") },
        { id: "semana", nome: janela.t("Semana", "Week") },
        { id: "dia", nome: janela.t("Dia", "Day") }
    ]

    // O título troca deslizando para o lado do tempo.
    property real ultimoFoco: janela.foco.getTime()
    onTituloChanged: {
        var dir = janela.foco.getTime() >= ultimoFoco ? 1 : -1;
        ultimoFoco = janela.foco.getTime();
        trocaTitulo.from = dir * Math.round(janela.gu * 0.8);
        animTitulo.restart();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Math.round(janela.gu * 0.6)
        spacing: Math.round(janela.gu * 0.5)

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(janela.gu * 0.8)
            Layout.rightMargin: Math.round(janela.gu * 0.8)
            spacing: Math.round(janela.gu * 0.3)

            BotaoRedondo {
                icone: "matsu-voltar-symbolic"
                dica: janela.visao === "mes" ? janela.t("Mês anterior", "Previous month") : (janela.visao === "semana" ? janela.t("Semana anterior", "Previous week") : janela.t("Dia anterior", "Previous day"))
                onClicado: janela.andar(-1)
            }
            BotaoRedondo {
                icone: "matsu-seta-symbolic"
                dica: janela.visao === "mes" ? janela.t("Próximo mês", "Next month") : (janela.visao === "semana" ? janela.t("Próxima semana", "Next week") : janela.t("Próximo dia", "Next day"))
                onClicado: janela.andar(1)
            }
            BotaoHoje {
                Layout.leftMargin: Math.round(janela.gu * 0.2)
            }
            Item {
                Layout.fillWidth: true
                Layout.leftMargin: Math.round(janela.gu * 0.5)
                Layout.preferredHeight: rotuloTitulo.implicitHeight
                clip: true
                Texto {
                    id: rotuloTitulo
                    width: parent.width
                    text: pagina.titulo
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.45
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    transform: Translate {
                        id: deslocaTitulo
                    }
                }
                ParallelAnimation {
                    id: animTitulo
                    NumberAnimation { id: trocaTitulo; target: deslocaTitulo; property: "x"; to: 0; duration: 320; easing.type: Easing.OutCubic }
                    NumberAnimation { target: rotuloTitulo; property: "opacity"; from: 0.15; to: 1; duration: 260 }
                }
            }
            Seletor {
                visible: !pagina.estreita
                opcoes: pagina.opcoesVisao
                escolhido: janela.visao
                onEscolher: (id) => janela.visao = id
            }
            BotaoDestaque {
                visible: !pagina.estreita
                Layout.leftMargin: Math.round(janela.gu * 0.3)
                icone: "matsu-mais-symbolic"
                texto: pagina.width > janela.gu * 50 ? janela.t("Novo evento", "New event") : ""
                textoFeito: ""
                Accessible.name: janela.t("Novo evento", "New event")
                onClicado: janela.novoEvento()
                QQC2.ToolTip.visible: containsMouse && texto === ""
                QQC2.ToolTip.text: janela.t("Novo evento (Ctrl+N)", "New event (Ctrl+N)")
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
            BotaoRedondo {
                id: botaoMais
                visible: !pagina.estreita
                icone: Qt.resolvedUrl("icones/mais-opcoes.svg")
                dica: janela.t("Mais opções", "More options")
                onClicado: menu.abrirEm(botaoMais, botaoMais.width - menu.width, botaoMais.height + 4)
            }
        }
        // Janela estreita: o Seletor e os botões descem para uma segunda linha.
        RowLayout {
            visible: pagina.estreita
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(janela.gu * 0.8)
            Layout.rightMargin: Math.round(janela.gu * 0.8)
            spacing: Math.round(janela.gu * 0.3)
            Seletor {
                opcoes: pagina.opcoesVisao
                escolhido: janela.visao
                onEscolher: (id) => janela.visao = id
            }
            Item {
                Layout.fillWidth: true
            }
            BotaoDestaque {
                icone: "matsu-mais-symbolic"
                texto: ""
                textoFeito: ""
                Accessible.name: janela.t("Novo evento", "New event")
                onClicado: janela.novoEvento()
            }
            BotaoRedondo {
                id: botaoMaisEstreita
                icone: Qt.resolvedUrl("icones/mais-opcoes.svg")
                dica: janela.t("Mais opções", "More options")
                onClicado: menu.abrirEm(botaoMaisEstreita, botaoMaisEstreita.width - menu.width, botaoMaisEstreita.height + 4)
            }
        }

        // A visão: troca com um esmaecer curto; dentro, o período desliza.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Loader {
                id: visaoAtual
                anchors.fill: parent
                sourceComponent: janela.visao === "semana" ? compSemana : (janela.visao === "dia" ? compDia : compMes)
                onLoaded: entrar.restart()
                ParallelAnimation {
                    id: entrar
                    NumberAnimation { target: visaoAtual; property: "opacity"; from: 0; to: 1; duration: 220 }
                    NumberAnimation { target: visaoAtual; property: "scale"; from: 0.985; to: 1; duration: 320; easing.type: Easing.OutCubic }
                }
            }

            // Calendário sem nenhum evento: uma dica discreta embaixo.
            Rectangle {
                id: dica
                readonly property bool mostrar: janela.eventos.length === 0
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - (mostrar ? height + Math.round(janela.gu * 1.2) : -Math.round(janela.gu * 0.5))
                width: Math.min(linhaDica.implicitWidth + Math.round(janela.gu * 1.4), parent.width - janela.gu * 2)
                height: Math.round(janela.gu * 2.5)
                radius: height / 2
                opacity: mostrar ? 1 : 0
                visible: opacity > 0
                color: janela.escuro ? Qt.rgba(0.18, 0.18, 0.19, 0.96) : Qt.rgba(1, 1, 1, 0.97)
                border.width: 1
                border.color: janela.tinta(0.1)
                Behavior on y {
                    NumberAnimation {
                        duration: 420
                        easing.type: Easing.OutBack
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 250
                    }
                }
                RowLayout {
                    id: linhaDica
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(janela.gu * 0.8)
                    anchors.rightMargin: Math.round(janela.gu * 0.35)
                    spacing: Math.round(janela.gu * 0.5)
                    Kirigami.Icon {
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: implicitWidth
                        source: "matsu-calendario-symbolic"
                        isMask: true
                        color: janela.frente
                        opacity: 0.7
                    }
                    Texto {
                        Layout.fillWidth: true
                        text: janela.t("Nenhum evento ainda. Dê dois cliques num dia para criar.", "No events yet. Double-click a day to create one.")
                        elide: Text.ElideRight
                        opacity: 0.8
                    }
                    Botao {
                        texto: janela.t("Importar .ics", "Import .ics")
                        onClicado: janela.pedirImportar()
                    }
                }
            }
        }
    }

    Component {
        id: compMes
        Item {
            Row {
                id: nomesDias
                anchors.left: parent.left
                anchors.right: parent.right
                height: Math.round(janela.gu * 1.8)
                Repeater {
                    model: 7
                    Texto {
                        required property int index
                        width: nomesDias.width / 7
                        height: nomesDias.height
                        leftPadding: Math.round(janela.gu * 0.55)
                        verticalAlignment: Text.AlignVCenter
                        text: janela.pt ? Datas.DIAS_CURTOS[index] : Datas.DIAS_CURTOS_EN[index]
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        font.weight: Font.DemiBold
                        opacity: index === 0 || index === 6 ? 0.42 : 0.58
                    }
                }
            }
            Carrossel {
                anchors.top: nomesDias.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                valor: Datas.inicioMes(janela.foco)
                componente: Component {
                    VisaoMes {
                        mostrarCabecalho: false
                    }
                }
            }
        }
    }
    Component {
        id: compSemana
        Carrossel {
            valor: Datas.inicioSemana(janela.foco)
            componente: Component {
                GradeHoras {
                    dias: 7
                }
            }
        }
    }
    Component {
        id: compDia
        Carrossel {
            valor: Datas.meiaNoite(janela.foco)
            componente: Component {
                GradeHoras {
                    dias: 1
                }
            }
        }
    }

    MenuMatsu {
        id: menu
        itens: [
            { id: "importar", nome: janela.t("Importar arquivo .ics…", "Import .ics file…"), icone: "matsu-baixar-symbolic", atalho: "Ctrl+O" },
            { id: "exportar", nome: janela.t("Exportar como .ics…", "Export as .ics…"), icone: Qt.resolvedUrl("icones/exportar.svg"), atalho: "Ctrl+E" },
            { id: "feriados", nome: janela.mostrarFeriados ? janela.t("Esconder feriados", "Hide holidays") : janela.t("Mostrar feriados", "Show holidays"),
              icone: Qt.resolvedUrl("icones/feriado.svg"), separador: true }
        ]
        onEscolhido: (id) => {
            if (id === "importar")
                janela.pedirImportar();
            else if (id === "exportar")
                janela.pedirExportar();
            else if (id === "feriados")
                janela.mostrarFeriados = !janela.mostrarFeriados;
        }
    }
}
