// As visões Semana (7 colunas, de domingo a sábado) e Dia (1 coluna): as horas
// de 00:00 a 23:00 na esquerda, os eventos como blocos arredondados na cor deles
// (lado a lado quando se encontram), a faixa "dia todo" em cima e a linha da hora
// de agora no dia de hoje. Dois cliques num horário criam um evento ali.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../comum"
import "datas.js" as Datas

Item {
    id: grade

    property var periodo: Datas.inicioSemana(janela.foco)
    property int dias: 7
    readonly property var fim: Datas.somarDias(periodo, dias - 1)
    readonly property var mapa: {
        janela.versao;
        return Datas.porDia(janela.eventos, periodo, fim);
    }
    readonly property var feriados: janela.mostrarFeriados ? Datas.feriadosEntre(periodo, fim) : ({})
    readonly property int indiceFoco: {
        var n = Datas.diasEntre(periodo, janela.foco);
        return n >= 0 && n < dias ? n : -1;
    }
    readonly property int indiceHoje: {
        var n = Datas.diasEntre(periodo, janela.hojeAgora);
        return n >= 0 && n < dias ? n : -1;
    }

    readonly property int margem: Math.round(janela.gu * 3.6)
    readonly property real largura: (width - margem) / dias
    readonly property real alturaHora: Math.round(janela.gu * 2.7)
    readonly property int folga: Math.round(janela.gu * 0.7)
    readonly property int alturaPilula: Math.round(janela.gu * 1.05)
    property var agora: new Date()

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: grade.agora = new Date()
    }

    // ----- cabeçalho: nome e número de cada dia -----
    Item {
        id: cabecalho
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.round(janela.gu * (grade.dias === 1 ? 3.2 : 3.5))

        Rectangle {
            id: pilulaDia
            readonly property Item alvo: grade.indiceFoco >= 0 && cabecalhos.count > grade.indiceFoco ? cabecalhos.itemAt(grade.indiceFoco) : null
            property bool pronta: false
            visible: alvo !== null && grade.dias > 1
            x: alvo ? alvo.x + alvo.numeroX : 0
            y: alvo ? alvo.numeroY : 0
            width: Math.round(janela.gu * 1.75)
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
            onAlvoChanged: {
                if (alvo && pronta)
                    pulo.restart();
                if (alvo)
                    Qt.callLater(function () { pilulaDia.pronta = true; });
            }
            SequentialAnimation {
                id: pulo
                NumberAnimation { target: pilulaDia; property: "scale"; to: 0.82; duration: 100 }
                NumberAnimation { target: pilulaDia; property: "scale"; to: 1; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
            }
        }

        Repeater {
            id: cabecalhos
            model: grade.dias
            MouseArea {
                id: cab
                required property int index
                readonly property var dia: Datas.somarDias(grade.periodo, index)
                readonly property bool hoje: index === grade.indiceHoje
                readonly property bool escolhido: index === grade.indiceFoco && grade.dias > 1
                readonly property int numeroX: grade.dias === 1 ? Math.round(janela.gu * 0.6) : Math.round((width - janela.gu * 1.75) / 2)
                readonly property int numeroY: grade.dias === 1 ? Math.round((height - janela.gu * 1.75) / 2) : Math.round(janela.gu * 1.4)
                x: grade.margem + Math.round(index * grade.largura)
                width: Math.round(grade.largura)
                height: cabecalho.height
                hoverEnabled: true
                cursorShape: grade.dias > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: janela.focar(dia)
                onDoubleClicked: if (grade.dias > 1) janela.abrirDia(dia)

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: Math.round(janela.gu * 0.35)
                    color: janela.tinta(cab.containsMouse && grade.dias > 1 ? 0.04 : 0)
                }
                Texto {
                    visible: grade.dias > 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(janela.gu * 0.3)
                    text: janela.pt ? Datas.DIAS_CURTOS[cab.dia.getDay()] : Datas.DIAS_CURTOS_EN[cab.dia.getDay()]
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.weight: Font.DemiBold
                    opacity: cab.hoje ? 0.9 : 0.55
                }
                Rectangle {
                    x: cab.numeroX
                    y: cab.numeroY
                    width: Math.round(janela.gu * 1.75)
                    height: width
                    radius: width / 2
                    color: janela.tinta(janela.escuro ? 0.13 : 0.09)
                    opacity: cab.hoje && !cab.escolhido ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                }
                Texto {
                    x: cab.numeroX
                    y: cab.numeroY
                    width: Math.round(janela.gu * 1.75)
                    height: width
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: cab.dia.getDate()
                    color: cab.escolhido ? janela.sobreDestaque : janela.frente
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
                    font.weight: cab.hoje || cab.escolhido ? Font.Bold : Font.Medium
                    font.features: { "tnum": 1 }
                    Behavior on color {
                        ColorAnimation {
                            duration: 160
                        }
                    }
                }
                // No Dia: o nome do dia por extenso ao lado do número.
                Column {
                    visible: grade.dias === 1
                    anchors.left: parent.left
                    anchors.leftMargin: cab.numeroX + Math.round(janela.gu * 2.3)
                    anchors.verticalCenter: parent.verticalCenter
                    Texto {
                        text: janela.pt ? Datas.DIAS[cab.dia.getDay()] : Datas.DIAS_EN[cab.dia.getDay()]
                        font.weight: Font.DemiBold
                    }
                    Texto {
                        text: Datas.relativo(cab.dia, janela.pt) === Datas.dataCurtaAno(cab.dia, janela.pt) ? (janela.pt ? Datas.MESES[cab.dia.getMonth()] + " de " + cab.dia.getFullYear() : Datas.MESES_EN[cab.dia.getMonth()] + " " + cab.dia.getFullYear())
                                                                                                         : Datas.relativo(cab.dia, janela.pt)
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.6
                    }
                }
            }
        }
    }

    // ----- faixa do dia todo (e os feriados, bem de leve) -----
    Item {
        id: faixa
        anchors.top: cabecalho.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        readonly property int linhas: {
            var maior = 0;
            for (var i = 0; i < grade.dias; i++) {
                var k = Datas.chave(Datas.somarDias(grade.periodo, i));
                var n = (grade.feriados[k] ? 1 : 0) + (grade.mapa[k] || []).filter(function (o) { return o.diaTodo; }).length;
                maior = Math.max(maior, n);
            }
            return Math.min(maior, 3);
        }
        height: Math.max(1, linhas) * (grade.alturaPilula + 2) + 6

        Texto {
            width: grade.margem - Math.round(janela.gu * 0.5)
            y: 3 + Math.round((grade.alturaPilula - height) / 2)
            horizontalAlignment: Text.AlignRight
            text: janela.t("dia todo", "all day")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.45
        }
        Repeater {
            model: grade.dias
            Column {
                id: colunaFaixa
                required property int index
                readonly property var dia: Datas.somarDias(grade.periodo, index)
                readonly property string chave: Datas.chave(dia)
                readonly property var feriado: grade.feriados[chave] || null
                readonly property var lista: (grade.mapa[chave] || []).filter(function (o) { return o.diaTodo; })
                readonly property int cabem: Math.max(0, 3 - (feriado ? 1 : 0))
                readonly property var visiveis: lista.length <= cabem ? lista : lista.slice(0, cabem - 1)
                x: grade.margem + Math.round(index * grade.largura)
                y: 3
                width: Math.round(grade.largura)
                spacing: 2

                // Feriado: só o contorno e o nome apagado.
                Rectangle {
                    visible: colunaFaixa.feriado !== null
                    x: 3
                    width: parent.width - 6
                    height: grade.alturaPilula
                    radius: Math.round(janela.gu * 0.3)
                    color: "transparent"
                    border.width: 1
                    border.color: janela.tinta(0.1)
                    Texto {
                        anchors.fill: parent
                        anchors.leftMargin: Math.round(janela.gu * 0.4)
                        anchors.rightMargin: Math.round(janela.gu * 0.3)
                        verticalAlignment: Text.AlignVCenter
                        text: colunaFaixa.feriado ? janela.nomeFeriado(colunaFaixa.feriado) : ""
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        color: colunaFaixa.feriado && colunaFaixa.feriado.tipo === "feriado" ? janela.cor("coral") : janela.frente
                        opacity: 0.7
                        elide: Text.ElideRight
                    }
                }
                Repeater {
                    model: colunaFaixa.visiveis
                    PilulaEvento {
                        required property var modelData
                        required property int index
                        readonly property bool comecaAntes: Datas.diasEntre(modelData.inicio, colunaFaixa.dia) > 0
                        readonly property bool segueDepois: Datas.diasEntre(colunaFaixa.dia, modelData.fim) > 0
                        x: comecaAntes && colunaFaixa.index > 0 ? 0 : 3
                        width: colunaFaixa.width - x - (segueDepois && colunaFaixa.index < grade.dias - 1 ? 0 : 3)
                        o: modelData
                        ordem: index
                        chaveDia: colunaFaixa.chave
                        continuaAntes: comecaAntes && colunaFaixa.index > 0
                        continuaDepois: segueDepois && colunaFaixa.index < grade.dias - 1
                        mostrarTitulo: !comecaAntes || colunaFaixa.index === 0
                    }
                }
                MouseArea {
                    visible: colunaFaixa.lista.length > colunaFaixa.visiveis.length
                    x: 3
                    width: rotuloMaisFaixa.implicitWidth + Math.round(janela.gu * 0.7)
                    height: grade.alturaPilula
                    cursorShape: Qt.PointingHandCursor
                    onClicked: janela.abrirDia(colunaFaixa.dia)
                    Texto {
                        id: rotuloMaisFaixa
                        anchors.centerIn: parent
                        text: "+" + (colunaFaixa.lista.length - colunaFaixa.visiveis.length)
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        font.weight: Font.DemiBold
                        opacity: 0.7
                    }
                }
            }
        }
    }
    Rectangle {
        id: linhaFaixa
        anchors.top: faixa.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: janela.tinta(janela.escuro ? 0.09 : 0.1)
    }

    // ----- as horas -----
    Flickable {
        id: rolagem
        anchors.top: linhaFaixa.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        contentWidth: width
        contentHeight: 24 * grade.alturaHora + 2 * grade.folga
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: BarraRolagem {}

        property bool pronta: false
        Component.onCompleted: {
            var y;
            if (janela.rolagemHoras >= 0)
                y = janela.rolagemHoras;
            else if (grade.indiceHoje >= 0)
                y = (Datas.minutos(new Date()) / 60 - 1.5) * grade.alturaHora;
            else
                y = 7.5 * grade.alturaHora;
            contentY = Math.max(0, Math.min(y, contentHeight - height));
            pronta = true;
        }
        onContentYChanged: if (pronta && visible && height > 0) janela.rolagemHoras = contentY

        Item {
            id: conteudoHoras
            width: rolagem.width
            height: rolagem.contentHeight

            // Hoje: a coluna um pouco mais clara.
            Rectangle {
                visible: grade.indiceHoje >= 0 && grade.dias > 1
                x: grade.margem + Math.round(grade.indiceHoje * grade.largura)
                width: Math.round(grade.largura)
                height: parent.height
                color: janela.tinta(janela.escuro ? 0.025 : 0.03)
            }

            // Clicar escolhe o dia; dois cliques criam um evento naquela meia hora.
            MouseArea {
                anchors.fill: parent
                anchors.leftMargin: grade.margem
                acceptedButtons: Qt.LeftButton
                function diaEm(mx) {
                    return Datas.somarDias(grade.periodo, Math.max(0, Math.min(grade.dias - 1, Math.floor(mx / grade.largura))));
                }
                function minutoEm(my) {
                    return Math.max(0, Math.min(23 * 60 + 30, Math.floor((my - grade.folga) / grade.alturaHora * 2) * 30));
                }
                onClicked: (m) => janela.focar(diaEm(m.x))
                onDoubleClicked: (m) => janela.novoEvento(diaEm(m.x), minutoEm(m.y))
            }

            Repeater {
                model: 24
                Item {
                    required property int index
                    y: grade.folga + index * grade.alturaHora
                    width: conteudoHoras.width
                    Rectangle {
                        x: grade.margem - 4
                        width: parent.width - x
                        height: 1
                        color: janela.tinta(janela.escuro ? 0.06 : 0.07)
                    }
                    // A meia hora, mais apagada.
                    Rectangle {
                        x: grade.margem
                        y: Math.round(grade.alturaHora / 2)
                        width: parent.width - x
                        height: 1
                        color: janela.tinta(janela.escuro ? 0.025 : 0.03)
                    }
                    Texto {
                        // Perto da hora de agora, o rótulo some para a hora certa aparecer.
                        readonly property bool perto: grade.indiceHoje >= 0 && Math.abs(Datas.minutos(grade.agora) - parent.index * 60) < 16
                        width: grade.margem - Math.round(janela.gu * 0.65)
                        y: -Math.round(height / 2)
                        horizontalAlignment: Text.AlignRight
                        text: Datas.deMinutos(parent.index * 60)
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        font.features: { "tnum": 1 }
                        opacity: perto ? 0 : 0.5
                    }
                }
            }
            Repeater {
                model: grade.dias
                Rectangle {
                    required property int index
                    x: grade.margem + Math.round(index * grade.largura)
                    width: 1
                    height: conteudoHoras.height
                    color: janela.tinta(janela.escuro ? 0.05 : 0.06)
                }
            }

            // Os blocos de cada dia.
            Repeater {
                model: grade.dias
                Item {
                    id: colunaDia
                    required property int index
                    readonly property var dia: Datas.somarDias(grade.periodo, index)
                    readonly property var blocos: Datas.blocosDoDia(grade.mapa[Datas.chave(dia)] || [], dia)
                    x: grade.margem + Math.round(index * grade.largura)
                    y: grade.folga
                    width: Math.round(grade.largura)
                    height: 24 * grade.alturaHora

                    Repeater {
                        model: colunaDia.blocos
                        MouseArea {
                            id: bloco
                            required property var modelData
                            required property int index
                            readonly property var o: modelData.o
                            readonly property real util: colunaDia.width - 6
                            readonly property bool baixo: height < janela.gu * 2.2
                            x: 3 + Math.round(modelData.coluna * util / modelData.colunas)
                            y: Math.round(modelData.de * grade.alturaHora / 60) + 1
                            width: Math.round(util / modelData.colunas) - (modelData.colunas > 1 ? 2 : 0)
                            height: Math.max(Math.round(janela.gu * 1.2), Math.round((modelData.ate - modelData.de) * grade.alturaHora / 60) - 2)
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (m) => {
                                if (m.button === Qt.RightButton)
                                    janela.abrirMenuEvento(bloco, m.x, m.y, o.ev, o.chave);
                                else
                                    janela.editarEvento(o.ev, o.chave);
                            }
                            Accessible.role: Accessible.Button
                            Accessible.name: o.ev.titulo

                            opacity: 0
                            scale: 0.96
                            Component.onCompleted: entrada.start()
                            ParallelAnimation {
                                id: entrada
                                NumberAnimation { target: bloco; property: "opacity"; to: 1; duration: 240 }
                                NumberAnimation { target: bloco; property: "scale"; to: 1; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Math.round(janela.gu * 0.4)
                                color: janela.fundoEvento(bloco.o.ev.cor, bloco.containsMouse)
                                border.width: 1
                                border.color: janela.corSuave(bloco.o.ev.cor, janela.escuro ? 0.5 : 0.45)
                                Behavior on color {
                                    ColorAnimation {
                                        duration: Kirigami.Units.shortDuration
                                    }
                                }
                            }
                            Column {
                                anchors.fill: parent
                                anchors.leftMargin: Math.round(janela.gu * 0.45)
                                anchors.rightMargin: Math.round(janela.gu * 0.35)
                                anchors.topMargin: bloco.baixo ? 0 : Math.round(janela.gu * 0.25)
                                clip: true
                                spacing: 0
                                Texto {
                                    width: parent.width
                                    height: bloco.baixo ? bloco.height : implicitHeight
                                    verticalAlignment: bloco.baixo ? Text.AlignVCenter : Text.AlignTop
                                    text: (bloco.o.ev.titulo || janela.t("Sem título", "Untitled")) + (bloco.baixo ? "  " + Datas.hora(bloco.o.inicio) : "")
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    font.weight: Font.DemiBold
                                    wrapMode: bloco.baixo ? Text.NoWrap : Text.Wrap
                                    maximumLineCount: bloco.height > janela.gu * 4 ? 2 : 1
                                    elide: Text.ElideRight
                                }
                                Texto {
                                    visible: !bloco.baixo
                                    width: parent.width
                                    text: janela.faixaHoras(bloco.o)
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    font.features: { "tnum": 1 }
                                    opacity: 0.7
                                    elide: Text.ElideRight
                                }
                                Texto {
                                    visible: !bloco.baixo && bloco.o.ev.local && bloco.height > janela.gu * 3.4
                                    width: parent.width
                                    text: bloco.o.ev.local || ""
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    opacity: 0.6
                                    elide: Text.ElideRight
                                }
                            }
                            QQC2.ToolTip.visible: containsMouse && bloco.baixo
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                            QQC2.ToolTip.text: (o.ev.titulo || "") + "\n" + janela.faixaHoras(o) + (o.ev.local ? " · " + o.ev.local : "")
                        }
                    }
                }
            }

            // A hora de agora: a linha no dia de hoje (e um fio nos outros dias) e o horário na margem.
            Item {
                visible: grade.indiceHoje >= 0
                y: grade.folga + Math.round(Datas.minutos(grade.agora) * grade.alturaHora / 60)
                width: conteudoHoras.width
                z: 5
                Rectangle {
                    x: grade.margem
                    y: -0.5
                    width: parent.width - grade.margem
                    height: 1
                    color: janela.corAgora
                    opacity: grade.dias > 1 ? 0.35 : 0
                }
                Rectangle {
                    x: grade.margem + Math.round(Math.max(0, grade.indiceHoje) * grade.largura)
                    y: -1
                    width: Math.round(grade.largura)
                    height: 2
                    radius: 1
                    color: janela.corAgora
                }
                Rectangle {
                    x: grade.margem + Math.round(Math.max(0, grade.indiceHoje) * grade.largura) - width / 2
                    y: -height / 2
                    width: Math.round(janela.gu * 0.55)
                    height: width
                    radius: width / 2
                    color: janela.corAgora
                }
                Rectangle {
                    x: grade.margem - width - Math.round(janela.gu * 0.35)
                    y: -height / 2
                    width: rotuloAgora.implicitWidth + Math.round(janela.gu * 0.6)
                    height: rotuloAgora.implicitHeight + 2
                    radius: height / 2
                    color: janela.corAgora
                    Texto {
                        id: rotuloAgora
                        anchors.centerIn: parent
                        text: Datas.hora(grade.agora)
                        color: janela.escuro ? "#1a1a1e" : "#ffffff"
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }
    }
}
