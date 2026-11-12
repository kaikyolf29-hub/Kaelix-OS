// Próximos: os eventos dos próximos meses numa lista, separada por dia ("Hoje",
// "Amanhã", "sáb., 14 de nov."), com os feriados bem de leve no meio. Com a busca
// da barra de título, mostra os eventos que combinam (do último ano aos próximos dois).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"
import "datas.js" as Datas

Item {
    id: pagina

    readonly property string termo: janela.simples(janela.busca.trim())
    readonly property var itens: {
        janela.versao;
        var hoje = janela.hojeAgora;
        var de = termo ? Datas.somarDias(hoje, -366) : hoje;
        var ate = termo ? Datas.somarDias(hoje, 731) : Datas.somarDias(hoje, 120);
        var lista = Datas.ocorrencias(janela.eventos, de, ate);
        if (termo) {
            lista = lista.filter(function (o) {
                return janela.simples((o.ev.titulo || "") + " " + (o.ev.local || "") + " " + (o.ev.notas || "")).indexOf(termo) >= 0;
            });
        } else {
            // Os que já acabaram hoje saem; os de vários dias que seguem até hoje ficam.
            var agora = new Date();
            lista = lista.filter(function (o) { return o.diaTodo ? Datas.diasEntre(hoje, o.fim) >= 0 : o.fim > agora || o.inicio > agora; });
        }
        lista = lista.slice(0, 300);
        var porDia = {};
        var chaves = [];
        for (var i = 0; i < lista.length; i++) {
            var k = Datas.chave(lista[i].inicio < hoje && !termo ? hoje : lista[i].inicio);
            if (!porDia[k]) {
                porDia[k] = [];
                chaves.push(k);
            }
            porDia[k].push({ tipo: "evento", o: lista[i] });
        }
        if (!termo && janela.mostrarFeriados) {
            var f = Datas.feriadosEntre(hoje, ate);
            for (var c in f) {
                if (!porDia[c]) {
                    porDia[c] = [];
                    chaves.push(c);
                }
                porDia[c].unshift({ tipo: "feriado", feriado: f[c] });
            }
        }
        chaves.sort();
        var r = [];
        for (var j = 0; j < chaves.length; j++) {
            var d = Datas.ler(chaves[j]);
            r.push({ tipo: "dia", chave: chaves[j], dia: d, passado: Datas.diasEntre(hoje, d) < 0 });
            r = r.concat(porDia[chaves[j]].map(function (x) { x.passado = Datas.diasEntre(hoje, d) < 0; return x; }));
        }
        return r;
    }
    readonly property bool soFeriados: itens.filter(function (x) { return x.tipo === "evento"; }).length === 0

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Math.round(janela.gu * 0.6)
        spacing: Math.round(janela.gu * 0.4)

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(janela.gu * 1.2)
            Layout.rightMargin: Math.round(janela.gu * 0.8)
            Texto {
                Layout.fillWidth: true
                text: pagina.termo ? janela.t("Resultados para “" + janela.busca.trim() + "”", "Results for “" + janela.busca.trim() + "”")
                                   : janela.t("Próximos", "Upcoming")
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.45
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            BotaoDestaque {
                icone: "matsu-mais-symbolic"
                texto: pagina.width > janela.gu * 30 ? janela.t("Novo evento", "New event") : ""
                textoFeito: ""
                onClicado: janela.novoEvento(janela.hojeAgora)
            }
        }

        ListView {
            id: lista
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !pagina.soFeriados || (!pagina.termo && janela.eventos.length > 0)
            clip: true
            model: pagina.itens
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            QQC2.ScrollBar.vertical: BarraRolagem {}
            topMargin: Math.round(janela.gu * 0.2)
            bottomMargin: Math.round(janela.gu * 1.2)

            delegate: Item {
                id: item
                required property var modelData
                required property int index
                width: lista.width
                height: modelData.tipo === "dia" ? Math.round(janela.gu * (index === 0 ? 1.9 : 2.6)) : Math.round(janela.gu * (modelData.tipo === "feriado" ? 2.1 : 3.1))
                opacity: 0
                transform: Translate {
                    id: sobe
                    y: 10
                }
                Component.onCompleted: entrada.start()
                SequentialAnimation {
                    id: entrada
                    PauseAnimation { duration: Math.min(item.index, 12) * 22 }
                    ParallelAnimation {
                        NumberAnimation { target: item; property: "opacity"; to: item.modelData.passado ? 0.55 : 1; duration: 220 }
                        NumberAnimation { target: sobe; property: "y"; to: 0; duration: 320; easing.type: Easing.OutCubic }
                    }
                }

                // Cabeçalho do dia.
                RowLayout {
                    visible: item.modelData.tipo === "dia"
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.round(janela.gu * 0.3)
                    anchors.leftMargin: Math.round(janela.gu * 1.2)
                    anchors.rightMargin: Math.round(janela.gu * 1.2)
                    spacing: Math.round(janela.gu * 0.5)
                    readonly property string rel: item.modelData.dia ? Datas.relativo(item.modelData.dia, janela.pt) : ""
                    readonly property string curta: item.modelData.dia ? Datas.dataCurtaAno(item.modelData.dia, janela.pt) : ""
                    Texto {
                        text: parent.rel
                        font.weight: Font.DemiBold
                    }
                    Texto {
                        visible: parent.rel !== parent.curta
                        text: parent.curta
                        opacity: 0.55
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: 1
                        color: janela.tinta(0.08)
                    }
                }

                // Feriado: só o nome, de leve.
                RowLayout {
                    visible: item.modelData.tipo === "feriado"
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(janela.gu * 1.2)
                    anchors.rightMargin: Math.round(janela.gu * 1.2)
                    spacing: Math.round(janela.gu * 0.6)
                    Item {
                        implicitWidth: Math.round(janela.gu * 5.2)
                        implicitHeight: 1
                        Kirigami.Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.round(janela.gu * 0.2)
                            width: Math.round(Kirigami.Units.iconSizes.small * 0.9)
                            height: width
                            source: Qt.resolvedUrl("icones/feriado.svg")
                            isMask: true
                            color: janela.frente
                            opacity: 0.5
                        }
                    }
                    Texto {
                        Layout.fillWidth: true
                        text: item.modelData.feriado ? janela.nomeFeriado(item.modelData.feriado) + "  ·  "
                                                       + (item.modelData.feriado.tipo === "feriado" ? janela.t("Feriado nacional", "National holiday")
                                                          : (item.modelData.feriado.tipo === "facultativo" ? janela.t("Ponto facultativo", "Optional holiday") : janela.t("Data comemorativa", "Observance"))) : ""
                        opacity: 0.6
                        elide: Text.ElideRight
                    }
                }

                // Evento.
                MouseArea {
                    id: linha
                    visible: item.modelData.tipo === "evento"
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(janela.gu * 0.6)
                    anchors.rightMargin: Math.round(janela.gu * 0.6)
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    readonly property var o: item.modelData.o || null
                    onClicked: (m) => {
                        if (!o)
                            return;
                        if (m.button === Qt.RightButton)
                            janela.abrirMenuEvento(linha, m.x, m.y, o.ev, o.chave);
                        else
                            janela.editarEvento(o.ev, o.chave);
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: o ? o.ev.titulo : ""

                    Rectangle {
                        anchors.fill: parent
                        radius: Math.round(janela.gu * 0.45)
                        color: janela.tinta(linha.containsMouse ? 0.06 : 0)
                        Behavior on color {
                            ColorAnimation {
                                duration: Kirigami.Units.shortDuration
                            }
                        }
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Math.round(janela.gu * 0.6)
                        anchors.rightMargin: Math.round(janela.gu * 0.6)
                        spacing: Math.round(janela.gu * 0.6)
                        // A hora (ou "dia todo"), na coluna da esquerda.
                        Column {
                            Layout.preferredWidth: Math.round(janela.gu * 5.2)
                            Layout.alignment: Qt.AlignVCenter
                            Texto {
                                width: parent.width
                                text: linha.o ? (linha.o.diaTodo ? janela.t("Dia todo", "All day") : Datas.hora(linha.o.inicio)) : ""
                                font.features: { "tnum": 1 }
                                font.weight: Font.Medium
                            }
                            Texto {
                                visible: linha.o && !linha.o.diaTodo && linha.o.fim > linha.o.inicio
                                width: parent.width
                                text: linha.o ? Datas.hora(linha.o.fim) : ""
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                font.features: { "tnum": 1 }
                                opacity: 0.5
                            }
                        }
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: Math.round(janela.gu * 0.6)
                            implicitHeight: implicitWidth
                            radius: width / 2
                            color: linha.o ? janela.cor(linha.o.ev.cor) : "transparent"
                        }
                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 1
                            Texto {
                                width: parent.width
                                text: linha.o ? (linha.o.ev.titulo || janela.t("Sem título", "Untitled")) : ""
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Row {
                                width: parent.width
                                spacing: Math.round(janela.gu * 0.35)
                                readonly property var partes: {
                                    if (!linha.o)
                                        return [];
                                    var p = [];
                                    if (linha.o.ev.local)
                                        p.push({ icone: Qt.resolvedUrl("icones/local.svg"), texto: linha.o.ev.local });
                                    if ((linha.o.ev.repetir || "nunca") !== "nunca")
                                        p.push({ icone: Qt.resolvedUrl("icones/repetir.svg"), texto: Datas.textoRepetir(linha.o.ev.repetir, Datas.ler(linha.o.ev.inicio), janela.pt) });
                                    if (linha.o.ev.lembrete >= 0)
                                        p.push({ icone: "matsu-sino-symbolic", texto: janela.textoLembrete(linha.o.ev.lembrete, linha.o.diaTodo) });
                                    if (linha.o.diaTodo && linha.o.extensao > 0)
                                        p.unshift({ icone: "matsu-calendario-symbolic", texto: janela.faixaHoras(linha.o) });
                                    return p;
                                }
                                visible: partes.length > 0
                                Repeater {
                                    model: parent.partes
                                    Row {
                                        required property var modelData
                                        spacing: Math.round(janela.gu * 0.2)
                                        Kirigami.Icon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Math.round(Kirigami.Units.iconSizes.small * 0.8)
                                            height: width
                                            source: parent.modelData.icone
                                            isMask: true
                                            color: janela.frente
                                            opacity: 0.5
                                        }
                                        Texto {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: parent.modelData.texto
                                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                                            opacity: 0.6
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !lista.visible
            Vazio {
                anchors.centerIn: parent
                icone: pagina.termo ? "matsu-busca-symbolic" : "matsu-calendario-symbolic"
                titulo: pagina.termo ? janela.t("Nada encontrado", "Nothing found") : janela.t("Nada marcado por enquanto", "Nothing planned yet")
                texto: pagina.termo ? janela.t("Nenhum evento tem “" + janela.busca.trim() + "” no nome, no local ou nas notas.", "No event has “" + janela.busca.trim() + "” in its title, place or notes.")
                                    : janela.t("Os seus próximos compromissos aparecem aqui, com os feriados no meio.", "Your upcoming events show up here, with holidays in between.")
                botao: pagina.termo ? "" : janela.t("Novo evento", "New event")
                onClicado: janela.novoEvento(janela.hojeAgora)
            }
        }
    }
}
