// Histórico e memória, lado a lado num Seletor (como o painel da direita da
// Calculadora do Windows). Clicar numa conta do histórico volta a conta; o botão
// direito copia ou apaga. Na memória, cada número tem MC, M+ e M− ao passar o mouse.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"
import "calculo.js" as Calculo

Item {
    id: painel

    // Flutuante: por cima da calculadora (janela estreita); fecha ao escolher.
    property bool flutuante: false
    signal escolheu()

    readonly property bool naMemoria: janela.abaPainel === "memoria"

    MenuMatsu {
        id: menu
        property int linha: -1
        itens: [
            { id: "usar", nome: janela.t("Usar esta conta", "Use this calculation"), icone: Qt.resolvedUrl("icones/historico.svg") },
            { id: "copiar", nome: janela.t("Copiar o resultado", "Copy result") },
            { id: "apagar", nome: janela.t("Apagar", "Delete"), icone: "matsu-lixeira-symbolic", perigo: true, separador: true }
        ]
        onEscolhido: (id) => {
            if (linha < 0 || linha >= janela.historico.count)
                return;
            if (id === "usar") {
                janela.voltarHistorico(linha);
                painel.escolheu();
            } else if (id === "copiar") {
                janela.copiarTexto(Calculo.formatarTexto(janela.historico.get(linha).valor, { ingles: !janela.pt, semGrupo: true }));
            } else if (id === "apagar") {
                janela.apagarHistorico(linha);
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.round(janela.gu * 0.6)
        spacing: Math.round(janela.gu * 0.5)

        Seletor {
            Layout.fillWidth: true
            opcoes: [{ id: "historico", nome: janela.t("Histórico", "History") }, { id: "memoria", nome: janela.t("Memória", "Memory") }]
            escolhido: janela.abaPainel
            onEscolher: (id) => janela.abaPainel = id
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // ----- histórico -----
            Item {
                anchors.fill: parent
                opacity: painel.naMemoria ? 0 : 1
                visible: opacity > 0
                x: painel.naMemoria ? -janela.gu * 1.5 : 0
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
                Behavior on x { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }

                Vazio {
                    anchors.centerIn: parent
                    visible: janela.historico.count === 0
                    icone: Qt.resolvedUrl("icones/historico.svg")
                    titulo: janela.t("Ainda não há histórico", "There's no history yet")
                    texto: janela.t("As contas que você fizer aparecem aqui.", "Your calculations show up here.")
                }
                ListView {
                    id: listaHistorico
                    anchors.fill: parent
                    clip: true
                    spacing: 2
                    model: janela.historico
                    boundsBehavior: Flickable.StopAtBounds
                    QQC2.ScrollBar.vertical: BarraRolagem {}
                    add: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 260 }
                            NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: 340; easing.type: Easing.OutBack }
                        }
                    }
                    displaced: Transition {
                        NumberAnimation { properties: "x,y"; duration: 260; easing.type: Easing.OutCubic }
                    }
                    remove: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; to: 0; duration: 180 }
                            NumberAnimation { property: "x"; to: janela.gu * 2; duration: 220; easing.type: Easing.InCubic }
                        }
                    }
                    delegate: MouseArea {
                        id: linhaH
                        required property int index
                        required property string expressao
                        required property string valor
                        width: ListView.view.width - Math.round(janela.gu * 0.5)
                        height: colunaH.implicitHeight + Math.round(janela.gu * 0.9)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        Accessible.role: Accessible.Button
                        Accessible.name: expressao + " " + textoValor.text
                        onClicked: (m) => {
                            if (m.button === Qt.RightButton) {
                                menu.linha = index;
                                menu.abrirEm(linhaH, m.x, m.y);
                            } else {
                                janela.voltarHistorico(index);
                                painel.escolheu();
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: Math.round(janela.gu * 0.4)
                            color: janela.tinta(linhaH.pressed ? 0.09 : (linhaH.containsMouse ? 0.055 : 0))
                            scale: linhaH.pressed ? 0.98 : 1
                            Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                            Behavior on scale { NumberAnimation { duration: 120 } }
                        }
                        ColumnLayout {
                            id: colunaH
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Math.round(janela.gu * 0.6)
                            anchors.rightMargin: Math.round(janela.gu * 0.6)
                            spacing: 2
                            Texto {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                                text: linhaH.expressao
                                opacity: 0.62
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideLeft
                                font.features: { "tnum": 1 }
                            }
                            Texto {
                                id: textoValor
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                                text: Calculo.formatarTexto(linhaH.valor, janela.opcoes)
                                elide: Text.ElideLeft
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.5
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                            }
                        }
                    }
                }
            }

            // ----- memória -----
            Item {
                anchors.fill: parent
                opacity: painel.naMemoria ? 1 : 0
                visible: opacity > 0
                x: painel.naMemoria ? 0 : janela.gu * 1.5
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
                Behavior on x { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }

                Vazio {
                    anchors.centerIn: parent
                    visible: janela.memoria.count === 0
                    icone: Qt.resolvedUrl("icones/memoria.svg")
                    titulo: janela.t("Nada na memória", "Nothing in memory")
                    texto: janela.t("Use MS para guardar o número do visor.", "Use MS to save the number on the display.")
                }
                ListView {
                    anchors.fill: parent
                    clip: true
                    spacing: 2
                    model: janela.memoria
                    boundsBehavior: Flickable.StopAtBounds
                    QQC2.ScrollBar.vertical: BarraRolagem {}
                    add: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 260 }
                            NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: 340; easing.type: Easing.OutBack }
                        }
                    }
                    displaced: Transition {
                        NumberAnimation { properties: "x,y"; duration: 260; easing.type: Easing.OutCubic }
                    }
                    remove: Transition {
                        NumberAnimation { property: "opacity"; to: 0; duration: 180 }
                    }
                    delegate: MouseArea {
                        id: linhaM
                        required property int index
                        required property string valor
                        width: ListView.view.width - Math.round(janela.gu * 0.5)
                        height: colunaM.implicitHeight + Math.round(janela.gu * 0.9)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: valorM.text
                        onClicked: {
                            janela.memoriaLer(index);
                            painel.escolheu();
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: Math.round(janela.gu * 0.4)
                            color: janela.tinta(linhaM.pressed ? 0.09 : (linhaM.containsMouse ? 0.055 : 0))
                            Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                        }
                        ColumnLayout {
                            id: colunaM
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Math.round(janela.gu * 0.6)
                            anchors.rightMargin: Math.round(janela.gu * 0.6)
                            spacing: Math.round(janela.gu * 0.25)
                            Texto {
                                id: valorM
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                                text: Calculo.formatarTexto(linhaM.valor, janela.opcoes)
                                elide: Text.ElideLeft
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.5
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                            }
                            Row {
                                Layout.alignment: Qt.AlignRight
                                spacing: 4
                                opacity: linhaM.containsMouse ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                                Repeater {
                                    model: [{ c: "MC", r: "MC" }, { c: "M+", r: "M+" }, { c: "M-", r: "M−" }]
                                    MouseArea {
                                        id: mini
                                        required property var modelData
                                        width: Math.round(janela.gu * 2.2)
                                        height: Math.round(janela.gu * 1.4)
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        Accessible.role: Accessible.Button
                                        Accessible.name: modelData.r
                                        onClicked: {
                                            if (modelData.c === "MC")
                                                janela.memoriaApagar(linhaM.index);
                                            else
                                                janela.memoriaSomar(linhaM.index, modelData.c === "M+" ? 1 : -1);
                                        }
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: height / 2
                                            color: janela.tinta(mini.pressed ? 0.16 : (mini.containsMouse ? 0.12 : 0.07))
                                            border.width: 1
                                            border.color: janela.tinta(0.08)
                                            scale: mini.pressed ? 0.94 : 1
                                            Behavior on scale { NumberAnimation { duration: 100 } }
                                        }
                                        Texto {
                                            anchors.centerIn: parent
                                            text: mini.modelData.r
                                            font.pixelSize: Math.round(janela.gu * 0.65)
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Item {
                Layout.fillWidth: true
            }
            Botao {
                icone: "matsu-lixeira-symbolic"
                texto: janela.t("Limpar", "Clear")
                dica: painel.naMemoria ? janela.t("Limpar a memória (Ctrl+L)", "Clear memory (Ctrl+L)")
                                       : janela.t("Limpar o histórico (Ctrl+Shift+D)", "Clear history (Ctrl+Shift+D)")
                ativo: painel.naMemoria ? janela.memoria.count > 0 : janela.historico.count > 0
                onClicado: painel.naMemoria ? janela.memoriaLimpar() : janela.limparHistorico()
            }
        }
    }
}
