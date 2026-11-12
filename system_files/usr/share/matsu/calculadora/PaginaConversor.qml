// Conversor de unidades (como o da Calculadora do Windows): a categoria em cima,
// duas linhas com o valor e a unidade, o ⇅ que troca as linhas de lugar (elas
// passam uma pela outra) e o teclado numérico. Digita-se na linha escolhida
// (fundo e borda fina); a outra mostra a conversão, com os algarismos rolando.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"
import "calculo.js" as Calculo

FocusScope {
    id: pagina

    readonly property var cat: Calculo.categoria(janela.convCategoria)
    readonly property bool temperatura: janela.convCategoria === "temperatura"
    readonly property var opcoesUnidades: {
        var l = [];
        for (var i = 0; i < cat.unidades.length; i++) {
            var u = cat.unidades[i];
            var s = !janela.pt && u.sEn ? u.sEn : u.s;
            l.push({ id: u.id, nome: (janela.pt ? u.pt : u.en) + " (" + s + ")" });
        }
        return l;
    }
    readonly property var opcoesCategorias: {
        var l = [];
        for (var i = 0; i < Calculo.CATEGORIAS.length; i++) {
            var c = Calculo.CATEGORIAS[i];
            l.push({ id: c.id, nome: janela.pt ? c.pt : c.en, icone: Qt.resolvedUrl("icones/" + c.id + ".svg") });
        }
        return l;
    }

    focus: true
    Keys.onPressed: (e) => {
        if (janela.teclaFisica(e))
            e.accepted = true;
    }
    Connections {
        target: janela
        function onActiveFocusItemChanged() {
            if (!janela.activeFocusItem || janela.activeFocusItem === janela.contentItem)
                pagina.forceActiveFocus();
        }
    }

    opacity: 0
    Component.onCompleted: {
        forceActiveFocus();
        entrada.start();
    }
    ParallelAnimation {
        id: entrada
        NumberAnimation { target: pagina; property: "opacity"; from: 0; to: 1; duration: 260 }
        NumberAnimation { target: deslocaPagina; property: "y"; from: janela.gu * 0.6; to: 0; duration: 360; easing.type: Easing.OutCubic }
    }
    transform: Translate {
        id: deslocaPagina
    }

    // Uma linha do conversor: o valor grande e a unidade embaixo.
    component Linha: MouseArea {
        id: linha
        property string lado: "a"
        readonly property bool ativa: janela.convAtivo === lado
        readonly property string valor: lado === "a" ? janela.convValorA : janela.convValorB
        readonly property string mostrado: ativa ? Calculo.formatarEntrada(janela.convEntrada, janela.opcoes) : Calculo.formatarTexto(valor, janela.opcoes)
        hoverEnabled: true
        cursorShape: ativa ? Qt.ArrowCursor : Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: mostrado
        onClicked: janela.conversorAtivar(lado)
        onMostradoChanged: numeroLinha.mostrar(mostrado, !ativa)
        Component.onCompleted: numeroLinha.mostrar(mostrado, false)

        Rectangle {
            anchors.fill: parent
            radius: Math.round(janela.gu * 0.55)
            color: linha.ativa ? janela.tinta(janela.escuro ? 0.06 : 0.045) : janela.tinta(linha.containsMouse ? 0.03 : 0)
            border.width: 1
            border.color: linha.ativa ? janela.tinta(janela.escuro ? 0.14 : 0.16) : "transparent"
            Behavior on color { ColorAnimation { duration: Kirigami.Units.longDuration } }
            Behavior on border.color { ColorAnimation { duration: Kirigami.Units.longDuration } }
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.round(janela.gu * 0.6)
            spacing: Math.round(janela.gu * 0.3)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                TextMetrics {
                    id: medidaLinha
                    font.family: modeloLinha.font.family
                    font.pixelSize: Math.round(janela.gu * 2.1)
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    text: linha.mostrado
                }
                Text {
                    id: modeloLinha
                    visible: false
                    font.family: Kirigami.Theme.defaultFont.family
                    font.pixelSize: Math.max(1, Math.min(Math.round(janela.gu * 2.1), parent.height * 0.95,
                                                         Math.floor(janela.gu * 2.1 * parent.width / Math.max(1, medidaLinha.advanceWidth * 1.04))))
                    font.weight: linha.ativa ? Font.DemiBold : Font.Normal
                    font.features: { "tnum": 1 }
                }
                VisorNumero {
                    id: numeroLinha
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: implicitWidth
                    fonte: modeloLinha.font
                    opacity: linha.ativa ? 1 : 0.82
                }
            }
            SuspensaLonga {
                Layout.fillWidth: true
                Layout.maximumWidth: Math.round(janela.gu * 18)
                nome: janela.t("Unidade", "Unit")
                opcoes: pagina.opcoesUnidades
                escolhido: linha.lado === "a" ? janela.convA : janela.convB
                onEscolher: (id) => janela.conversorUnidade(linha.lado, id)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.round(janela.gu * 0.5)
        spacing: Math.round(janela.gu * 0.45)

        Texto {
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(janela.gu * 0.35)
            Layout.topMargin: Math.round(janela.gu * 0.25)
            text: janela.t("Conversor", "Converter")
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
            font.weight: Font.DemiBold
        }
        SuspensaLonga {
            Layout.fillWidth: true
            nome: janela.t("Categoria", "Category")
            opcoes: pagina.opcoesCategorias
            escolhido: janela.convCategoria
            onEscolher: (id) => janela.conversorCategoria(id)
        }

        // As duas linhas e o ⇅ entre elas.
        Item {
            id: blocos
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(Math.min(janela.gu * 10.5, pagina.height * 0.36))
            readonly property real alturaLinha: (height - janela.gu * 0.5) / 2
            readonly property real yBaixo: height - alturaLinha

            Linha {
                lado: "a"
                width: parent.width
                height: blocos.alturaLinha
                y: janela.convAEmCima ? 0 : blocos.yBaixo
                Behavior on y { NumberAnimation { duration: 380; easing.type: Easing.InOutCubic } }
            }
            Linha {
                lado: "b"
                width: parent.width
                height: blocos.alturaLinha
                y: janela.convAEmCima ? blocos.yBaixo : 0
                Behavior on y { NumberAnimation { duration: 380; easing.type: Easing.InOutCubic } }
            }
            MouseArea {
                id: trocar
                property int voltas: 0
                width: Math.round(janela.gu * 2.2)
                height: width
                anchors.right: parent.right
                anchors.rightMargin: Math.round(janela.gu * 0.8)
                anchors.verticalCenter: parent.verticalCenter
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: janela.t("Trocar as unidades", "Swap units")
                onClicked: {
                    voltas++;
                    janela.conversorTrocar();
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: janela.escuro ? Qt.rgba(0.22, 0.22, 0.23, 1) : "#ffffff"
                    border.width: 1
                    border.color: janela.tinta(trocar.containsMouse ? 0.2 : 0.12)
                    scale: trocar.pressed ? 0.9 : (trocar.containsMouse ? 1.06 : 1)
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    Behavior on border.color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.round(janela.gu * 1.1)
                    height: width
                    source: Qt.resolvedUrl("icones/trocar.svg")
                    isMask: true
                    color: janela.frente
                    rotation: trocar.voltas * 180
                    Behavior on rotation { NumberAnimation { duration: 420; easing.type: Easing.OutBack } }
                }
                QQC2.ToolTip.visible: containsMouse
                QQC2.ToolTip.text: janela.t("Trocar as unidades", "Swap units")
                QQC2.ToolTip.delay: 700
            }
        }

        Texto {
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(janela.gu * 0.35)
            text: Calculo.taxa(janela.convCategoria, janela.convAtivo === "a" ? janela.convA : janela.convB,
                               janela.convAtivo === "a" ? janela.convB : janela.convA, janela.opcoes)
            opacity: 0.6
            elide: Text.ElideRight
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            font.features: { "tnum": 1 }
        }

        // ----- teclado -----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 1
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 1
                BotaoCalc {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 10
                    Layout.preferredHeight: 10
                    chave: "CE"
                    rotulo: "CE"
                    dica: janela.t("Limpar (Esc)", "Clear (Esc)")
                    onAcionado: (c) => janela.conversorTecla(c)
                }
                BotaoCalc {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 10
                    Layout.preferredHeight: 10
                    chave: "apagar"
                    icone: Qt.resolvedUrl("icones/apagar.svg")
                    repete: true
                    dica: janela.t("Apagar (Backspace)", "Backspace")
                    onAcionado: (c) => janela.conversorTecla(c)
                }
            }
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 40
                columns: 3
                columnSpacing: 1
                rowSpacing: 1
                Repeater {
                    model: ["7", "8", "9", "4", "5", "6", "1", "2", "3", "neg", "0", "virgula"]
                    BotaoCalc {
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 10
                        Layout.preferredHeight: 10
                        chave: modelData
                        rotulo: modelData === "neg" ? "+/−" : (modelData === "virgula" ? janela.t(",", ".") : modelData)
                        tipo: "numero"
                        ativo: modelData !== "neg" || pagina.temperatura
                        dica: modelData === "neg" ? janela.t("Trocar o sinal (só temperatura)", "Negate (temperature only)") : ""
                        onAcionado: (c) => janela.conversorTecla(c)
                    }
                }
            }
        }
    }
}
