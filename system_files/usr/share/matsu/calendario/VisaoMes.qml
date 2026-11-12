// A visão Mês: a grade de 4 a 6 semanas (começando no domingo), cada dia com os
// eventos em pílulas pequenas e "+2" quando não cabem. O dia escolhido ganha a
// pílula cheia, que desliza de um dia para o outro; o de hoje fica marcado de leve.
// Feriados aparecem bem de leve ao lado do número. Dois cliques num dia criam um
// evento; arrastar um evento leva para outro dia.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../comum"
import "datas.js" as Datas

Item {
    id: visao

    property var periodo: Datas.inicioMes(janela.foco)
    readonly property var grade: Datas.gradeMes(periodo)
    readonly property var inicio: grade.inicio
    readonly property int semanas: grade.semanas
    readonly property var fim: Datas.somarDias(inicio, semanas * 7 - 1)
    readonly property var mapa: {
        janela.versao;
        return Datas.porDia(janela.eventos, inicio, fim);
    }
    readonly property var feriados: janela.mostrarFeriados ? Datas.feriadosEntre(inicio, fim) : ({})
    readonly property int indiceFoco: {
        var n = Datas.diasEntre(inicio, janela.foco);
        return n >= 0 && n < semanas * 7 ? n : -1;
    }

    // Fora do carrossel o cabeçalho vem junto; dentro dele fica parado em cima
    // (os nomes dos dias são os mesmos em todo mês, só a grade desliza).
    property bool mostrarCabecalho: true

    readonly property int alturaPilula: Math.round(janela.gu * 1.05)
    readonly property int ladoNumero: Math.round(janela.gu * 1.55)

    // ----- arrastar um evento para outro dia -----
    property var arraste: null       // { o, origem (índice do dia), titulo, cor }
    property int alvo: -1
    property point ponto
    function indiceEm(p) {
        var c = Math.floor(p.x / corpo.largura), l = Math.floor((p.y - corpo.y) / corpo.altura);
        if (c < 0 || c > 6 || l < 0 || l >= semanas)
            return -1;
        return l * 7 + c;
    }
    function comecar(pilula) {
        var origem = Datas.diasEntre(inicio, Datas.ler(pilula.chaveDia));
        arraste = { o: pilula.o, origem: origem, largura: pilula.width };
        alvo = origem;
    }
    function mover(p) {
        ponto = p;
        var i = indiceEm(p);
        if (i >= 0)
            alvo = i;
    }
    function soltar() {
        if (arraste && alvo >= 0)
            janela.moverEvento(arraste.o.ev, alvo - arraste.origem);
        arraste = null;
        alvo = -1;
    }
    function cancelar() {
        arraste = null;
        alvo = -1;
    }

    // ----- os nomes dos dias -----
    Row {
        id: cabecalho
        anchors.left: parent.left
        anchors.right: parent.right
        visible: visao.mostrarCabecalho
        height: visao.mostrarCabecalho ? Math.round(janela.gu * 1.8) : 0
        Repeater {
            model: 7
            Texto {
                required property int index
                width: cabecalho.width / 7
                height: cabecalho.height
                leftPadding: Math.round(janela.gu * 0.55)
                verticalAlignment: Text.AlignVCenter
                text: janela.pt ? Datas.DIAS_CURTOS[index] : Datas.DIAS_CURTOS_EN[index]
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.weight: Font.DemiBold
                opacity: index === 0 || index === 6 ? 0.42 : 0.58
            }
        }
    }

    Item {
        id: corpo
        anchors.top: cabecalho.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        readonly property real largura: width / 7
        readonly property real altura: height / visao.semanas

        // As linhas da grade, bem finas.
        Repeater {
            model: visao.semanas
            Rectangle {
                required property int index
                y: Math.round(index * corpo.altura)
                width: corpo.width
                height: 1
                color: janela.tinta(janela.escuro ? 0.06 : 0.07)
            }
        }
        Repeater {
            model: 6
            Rectangle {
                required property int index
                x: Math.round((index + 1) * corpo.largura)
                width: 1
                height: corpo.height
                color: janela.tinta(janela.escuro ? 0.05 : 0.06)
            }
        }

        // A pílula cheia do dia escolhido: anda até o novo dia e dá um pulinho.
        Rectangle {
            id: pilulaDia
            readonly property Item celula: visao.indiceFoco >= 0 && celulas.count > visao.indiceFoco ? celulas.itemAt(visao.indiceFoco) : null
            property bool pronta: false
            visible: celula !== null
            x: celula ? celula.x + Math.round(janela.gu * 0.3) : 0
            y: celula ? celula.y + Math.round(janela.gu * 0.25) : 0
            width: visao.ladoNumero
            height: width
            radius: width / 2
            color: janela.destaque
            Behavior on x {
                enabled: pilulaDia.pronta
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                enabled: pilulaDia.pronta
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
            onCelulaChanged: {
                if (celula && pronta)
                    pulo.restart();
                if (!celula)
                    pronta = false;
                else
                    Qt.callLater(function () { pilulaDia.pronta = true; });
            }
            SequentialAnimation {
                id: pulo
                NumberAnimation { target: pilulaDia; property: "scale"; to: 0.82; duration: 100; easing.type: Easing.OutQuad }
                NumberAnimation { target: pilulaDia; property: "scale"; to: 1; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
            }
        }

        Repeater {
            id: celulas
            model: visao.semanas * 7

            MouseArea {
                id: cel
                required property int index
                readonly property var dia: Datas.somarDias(visao.inicio, index)
                readonly property string chave: Datas.chave(dia)
                readonly property bool doMes: dia.getMonth() === visao.periodo.getMonth()
                readonly property bool hoje: Datas.mesmoDia(dia, janela.hojeAgora)
                readonly property bool escolhido: index === visao.indiceFoco
                readonly property var lista: visao.mapa[chave] || []
                readonly property var feriado: visao.feriados[chave] || null
                readonly property int topo: Math.round(janela.gu * 0.25) + visao.ladoNumero + 3
                readonly property int cabem: Math.max(0, Math.floor((height - topo - 3) / (visao.alturaPilula + 2)))
                readonly property var visiveis: lista.length <= cabem ? lista : lista.slice(0, Math.max(0, cabem - 1))
                readonly property int sobra: lista.length - visiveis.length

                x: Math.round((index % 7) * corpo.largura)
                y: Math.round(Math.floor(index / 7) * corpo.altura)
                width: Math.round(((index % 7) + 1) * corpo.largura) - x
                height: Math.round((Math.floor(index / 7) + 1) * corpo.altura) - y
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (m) => {
                    janela.focar(dia);
                    if (m.button === Qt.RightButton)
                        janela.abrirMenuDia(cel, m.x, m.y, dia);
                }
                onDoubleClicked: (m) => { if (m.button === Qt.LeftButton) janela.novoEvento(dia); }

                // Fundo: os dias de fora do mês, um pouco mais fundos; o alvo do arraste acende.
                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 1
                    anchors.topMargin: 1
                    color: visao.alvo === cel.index && visao.arraste ? janela.tinta(0.08)
                         : (cel.containsMouse ? janela.tinta(janela.escuro ? 0.035 : 0.03) : (cel.doMes ? "transparent" : janela.tinta(janela.escuro ? 0.018 : 0.022)))
                    border.width: visao.alvo === cel.index && visao.arraste ? 1 : 0
                    border.color: janela.tinta(0.3)
                    radius: visao.alvo === cel.index && visao.arraste ? Math.round(janela.gu * 0.3) : 0
                    Behavior on color {
                        ColorAnimation {
                            duration: Kirigami.Units.shortDuration
                        }
                    }
                }

                // O dia de hoje: um círculo bem leve atrás do número.
                Rectangle {
                    x: Math.round(janela.gu * 0.3)
                    y: Math.round(janela.gu * 0.25)
                    width: visao.ladoNumero
                    height: width
                    radius: width / 2
                    color: janela.tinta(janela.escuro ? 0.13 : 0.09)
                    opacity: cel.hoje && !cel.escolhido ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                }
                Texto {
                    id: numero
                    x: Math.round(janela.gu * 0.3)
                    y: Math.round(janela.gu * 0.25)
                    width: visao.ladoNumero
                    height: width
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: cel.dia.getDate()
                    color: cel.escolhido ? janela.sobreDestaque : janela.frente
                    opacity: cel.doMes || cel.escolhido ? 1 : 0.38
                    font.weight: cel.hoje || cel.escolhido ? Font.Bold : Font.Normal
                    font.features: { "tnum": 1 }
                    Behavior on color {
                        ColorAnimation {
                            duration: 160
                        }
                    }
                }
                // Ao lado do número: o mês no dia 1 e o feriado, bem de leve.
                Texto {
                    anchors.left: numero.right
                    anchors.leftMargin: Math.round(janela.gu * 0.3)
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(janela.gu * 0.35)
                    anchors.verticalCenter: numero.verticalCenter
                    readonly property string mes: cel.dia.getDate() === 1 ? (janela.pt ? Datas.MESES_CURTOS[cel.dia.getMonth()] : Datas.MESES_CURTOS_EN[cel.dia.getMonth()]) : ""
                    text: mes + (mes && cel.feriado ? " · " : "") + (cel.feriado ? janela.nomeFeriado(cel.feriado) : "")
                    visible: text.length > 0
                    elide: Text.ElideRight
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    color: cel.feriado && cel.feriado.tipo === "feriado" ? janela.cor("coral") : janela.frente
                    opacity: (cel.doMes ? 0.75 : 0.35) * (cel.feriado && cel.feriado.tipo === "feriado" ? 1 : 0.8)
                    QQC2.ToolTip.visible: cel.feriado !== null && fundoFeriado.containsMouse
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                    QQC2.ToolTip.text: cel.feriado ? janela.nomeFeriado(cel.feriado) + " · " + (cel.feriado.tipo === "feriado" ? janela.t("feriado nacional", "national holiday")
                                                                                             : (cel.feriado.tipo === "facultativo" ? janela.t("ponto facultativo", "optional holiday") : janela.t("data comemorativa", "observance"))) : ""
                    HoverHandler {
                        id: fundoFeriado
                        readonly property bool containsMouse: hovered
                    }
                }

                Column {
                    anchors.top: parent.top
                    anchors.topMargin: cel.topo
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 2

                    Repeater {
                        model: cel.visiveis
                        PilulaEvento {
                            required property var modelData
                            required property int index
                            readonly property bool comecaAntes: modelData.diaTodo && Datas.diasEntre(modelData.inicio, cel.dia) > 0
                            readonly property bool segueDepois: modelData.diaTodo && Datas.diasEntre(cel.dia, modelData.fim) > 0
                            x: comecaAntes && cel.index % 7 !== 0 ? 0 : 3
                            width: cel.width - x - (segueDepois && cel.index % 7 !== 6 ? 0 : 3)
                            o: modelData
                            ordem: index
                            chaveDia: cel.chave
                            continuaAntes: comecaAntes && cel.index % 7 !== 0
                            continuaDepois: segueDepois && cel.index % 7 !== 6
                            mostrarTitulo: !comecaAntes || cel.index % 7 === 0
                            grade: visao
                        }
                    }
                    MouseArea {
                        id: mais
                        visible: cel.sobra > 0
                        x: 3
                        width: rotuloMais.implicitWidth + Math.round(janela.gu * 0.7)
                        height: visao.alturaPilula
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: janela.abrirDia(cel.dia)
                        Rectangle {
                            anchors.fill: parent
                            radius: Math.round(janela.gu * 0.3)
                            color: janela.tinta(mais.containsMouse ? 0.08 : 0)
                        }
                        Texto {
                            id: rotuloMais
                            anchors.centerIn: parent
                            text: "+" + cel.sobra
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            font.weight: Font.DemiBold
                            opacity: 0.7
                        }
                        QQC2.ToolTip.visible: containsMouse
                        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                        QQC2.ToolTip.text: janela.t("Ver o dia todo", "See the whole day")
                    }
                }
            }
        }

        // O evento sendo arrastado, colado no mouse.
        Rectangle {
            visible: visao.arraste !== null
            x: visao.ponto.x - width / 2
            y: visao.ponto.y - corpo.y - height / 2
            width: visao.arraste ? Math.max(janela.gu * 5, visao.arraste.largura) : 0
            height: visao.alturaPilula + 4
            radius: Math.round(janela.gu * 0.35)
            color: janela.escuro ? Qt.rgba(0.2, 0.2, 0.21, 0.97) : Qt.rgba(1, 1, 1, 0.98)
            border.width: 1
            border.color: visao.arraste ? janela.cor(visao.arraste.o.ev.cor) : "transparent"
            scale: visible ? 1.04 : 0.9
            Behavior on scale {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutBack
                }
            }
            Row {
                anchors.fill: parent
                anchors.leftMargin: Math.round(janela.gu * 0.4)
                anchors.rightMargin: Math.round(janela.gu * 0.4)
                spacing: Math.round(janela.gu * 0.35)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(janela.gu * 0.45)
                    height: width
                    radius: width / 2
                    color: visao.arraste ? janela.cor(visao.arraste.o.ev.cor) : "transparent"
                }
                Texto {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x
                    text: visao.arraste ? (visao.arraste.o.ev.titulo || janela.t("Sem título", "Untitled")) : ""
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }
        }
    }
}
