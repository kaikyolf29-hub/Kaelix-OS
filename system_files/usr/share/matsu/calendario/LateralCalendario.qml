// Embaixo da lista da esquerda: o mini-calendário, os eventos do dia escolhido
// (as linhas aparecem subindo, como no cartão do vídeo de referência), a chave dos
// feriados e, quando o systemd do usuário não existe (na prévia), o aviso de que
// os lembretes não tocam aqui.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"
import "datas.js" as Datas

ColumnLayout {
    id: lateral

    spacing: Math.round(janela.gu * 0.5)

    readonly property var dosMarcados: {
        janela.versao;
        var de = Datas.inicioSemana(janela.mesMini);
        var mapa = Datas.porDia(janela.eventos, de, Datas.somarDias(de, 41));
        var r = {};
        for (var k in mapa)
            r[k] = true;
        return r;
    }
    readonly property var doDia: {
        janela.versao;
        return Datas.porDia(janela.eventos, janela.foco, janela.foco)[Datas.chave(janela.foco)] || [];
    }
    readonly property var feriadoDoDia: janela.mostrarFeriados ? (Datas.feriadosEntre(janela.foco, janela.foco)[Datas.chave(janela.foco)] || null) : null
    readonly property bool cabeDia: janela.height > janela.gu * 34

    MiniCalendario {
        Layout.fillWidth: true
        mes: janela.mesMini
        escolhido: janela.foco
        marcas: lateral.dosMarcados
        onEscolher: (d) => {
            janela.focar(d);
            if (janela.pagina !== "calendario")
                janela.pagina = "calendario";
        }
        onMudarMes: (m) => janela.mesMini = m
    }

    // Os eventos do dia escolhido. Altura fixa: o mini-calendário não pula ao trocar de dia.
    ColumnLayout {
        visible: lateral.cabeDia
        Layout.fillWidth: true
        Layout.topMargin: Math.round(janela.gu * 0.2)
        Layout.preferredHeight: Math.round(janela.gu * 8.8)
        spacing: Math.round(janela.gu * 0.25)

        Texto {
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(janela.gu * 0.3)
            text: Datas.relativo(janela.foco, janela.pt) === Datas.dataCurtaAno(janela.foco, janela.pt)
                  ? Datas.dataCurtaAno(janela.foco, janela.pt)
                  : Datas.relativo(janela.foco, janela.pt) + " · " + Datas.dataCurta(janela.foco, janela.pt)
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            font.weight: Font.DemiBold
            opacity: 0.6
            elide: Text.ElideRight
        }
        // Um bloco por dia: trocar de dia faz as linhas entrarem de novo.
        Repeater {
            model: [Datas.chave(janela.foco) + ":" + janela.versao + ":" + janela.mostrarFeriados]
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Math.round(janela.gu * 0.2)
                readonly property var linhas: {
                    var l = [];
                    if (lateral.feriadoDoDia)
                        l.push({ feriado: lateral.feriadoDoDia });
                    for (var i = 0; i < lateral.doDia.length; i++)
                        l.push({ o: lateral.doDia[i] });
                    return l;
                }
                Repeater {
                    model: parent.linhas.slice(0, 3)
                    MouseArea {
                        id: linha
                        required property var modelData
                        required property int index
                        readonly property bool ehFeriado: !!modelData.feriado
                        Layout.fillWidth: true
                        implicitHeight: Math.round(janela.gu * 1.75)
                        hoverEnabled: !ehFeriado
                        cursorShape: ehFeriado ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: if (!ehFeriado) janela.editarEvento(modelData.o.ev, modelData.o.chave)
                        Accessible.role: Accessible.Button
                        Accessible.name: rotulo.text

                        opacity: 0
                        transform: Translate {
                            id: sobe
                            y: 8
                        }
                        Component.onCompleted: entrada.start()
                        SequentialAnimation {
                            id: entrada
                            PauseAnimation { duration: 60 + linha.index * 55 }
                            ParallelAnimation {
                                NumberAnimation { target: linha; property: "opacity"; to: 1; duration: 220 }
                                NumberAnimation { target: sobe; property: "y"; to: 0; duration: 320; easing.type: Easing.OutCubic }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Math.round(janela.gu * 0.4)
                            color: linha.ehFeriado ? "transparent" : janela.tinta(linha.containsMouse ? 0.09 : (janela.escuro ? 0.055 : 0.05))
                            border.width: linha.ehFeriado ? 1 : 0
                            border.color: janela.tinta(0.1)
                            Behavior on color {
                                ColorAnimation {
                                    duration: Kirigami.Units.shortDuration
                                }
                            }
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Math.round(janela.gu * 0.5)
                            anchors.rightMargin: Math.round(janela.gu * 0.5)
                            spacing: Math.round(janela.gu * 0.4)
                            Rectangle {
                                visible: !linha.ehFeriado
                                implicitWidth: Math.round(janela.gu * 0.45)
                                implicitHeight: implicitWidth
                                radius: width / 2
                                color: linha.ehFeriado ? "transparent" : janela.cor(linha.modelData.o.ev.cor)
                            }
                            Kirigami.Icon {
                                visible: linha.ehFeriado
                                implicitWidth: Math.round(Kirigami.Units.iconSizes.small * 0.85)
                                implicitHeight: implicitWidth
                                source: Qt.resolvedUrl("icones/feriado.svg")
                                isMask: true
                                color: janela.frente
                                opacity: 0.6
                            }
                            Texto {
                                id: rotulo
                                Layout.fillWidth: true
                                text: linha.ehFeriado ? janela.nomeFeriado(linha.modelData.feriado) : (linha.modelData.o.ev.titulo || janela.t("Sem título", "Untitled"))
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                font.weight: linha.ehFeriado ? Font.Normal : Font.Medium
                                opacity: linha.ehFeriado ? 0.7 : 1
                                elide: Text.ElideRight
                            }
                            Texto {
                                visible: !linha.ehFeriado
                                text: linha.ehFeriado ? "" : (linha.modelData.o.diaTodo ? janela.t("dia todo", "all day") : Datas.hora(linha.modelData.o.inicio))
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                font.features: { "tnum": 1 }
                                opacity: 0.55
                            }
                        }
                    }
                }
                Texto {
                    visible: parent.linhas.length === 0
                    Layout.fillWidth: true
                    Layout.leftMargin: Math.round(janela.gu * 0.3)
                    text: janela.t("Nada marcado", "Nothing planned")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.45
                }
                MouseArea {
                    visible: parent.linhas.length > 3
                    Layout.fillWidth: true
                    implicitHeight: Math.round(janela.gu * 1.3)
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: janela.abrirDia(janela.foco)
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.round(janela.gu * 0.3)
                        text: janela.t("+" + (parent.parent.linhas.length - 3) + " no dia", "+" + (parent.parent.linhas.length - 3) + " more")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        font.weight: Font.DemiBold
                        opacity: parent.containsMouse ? 0.9 : 0.6
                    }
                }
            }
        }
        Item {
            Layout.fillHeight: true
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: Math.round(janela.gu * 0.2)
        implicitHeight: 1
        color: janela.tinta(0.08)
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Math.round(janela.gu * 0.3)
        spacing: Math.round(janela.gu * 0.4)
        Texto {
            Layout.fillWidth: true
            text: janela.t("Feriados", "Holidays")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.8
            elide: Text.ElideRight
        }
        Chave {
            nome: janela.t("Mostrar feriados", "Show holidays")
            ligada: janela.mostrarFeriados
            onTrocada: (l) => janela.mostrarFeriados = l
        }
    }
    // Sem o systemd do usuário (prévia, contêiner), os lembretes não tocam: avisa de leve.
    MouseArea {
        id: avisoLembretes
        visible: janela.systemd === false
        Layout.fillWidth: true
        implicitHeight: linhaAviso.implicitHeight
        hoverEnabled: true
        RowLayout {
            id: linhaAviso
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Math.round(janela.gu * 0.3)
            spacing: Math.round(janela.gu * 0.35)
            Kirigami.Icon {
                implicitWidth: Math.round(Kirigami.Units.iconSizes.small * 0.85)
                implicitHeight: implicitWidth
                source: "matsu-sino-silencio-symbolic"
                isMask: true
                color: janela.frente
                opacity: 0.5
            }
            Texto {
                Layout.fillWidth: true
                text: janela.t("Lembretes indisponíveis aqui", "Reminders unavailable here")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.5
                elide: Text.ElideRight
            }
        }
        QQC2.ToolTip.visible: containsMouse
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        QQC2.ToolTip.text: janela.t("O serviço de lembretes do sistema (systemd) não responde nesta sessão. Os eventos ficam guardados; os avisos voltam quando ele estiver disponível.",
                                    "The system reminder service (systemd) is not available in this session. Events are saved; alerts return when it is available.")
    }
}
