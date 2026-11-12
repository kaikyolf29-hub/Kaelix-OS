// Alarmes: os cartões numa grade (entram, saem e trocam de lugar com animação), o
// botão de novo alarme e, sem o systemd do usuário, um aviso discreto. Apagar tem
// Desfazer no aviso de baixo.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    // Entra subindo de leve, como as outras páginas.
    opacity: 0
    transform: Translate { id: desliza; y: janela.gu * 0.6 }
    Component.onCompleted: {
        entrada.start();
        if (janela.pedirNovoAlarme) {
            janela.pedirNovoAlarme = false;
            editor.abrir(null);
        }
    }
    ParallelAnimation {
        id: entrada
        NumberAnimation { target: pagina; property: "opacity"; to: 1; duration: 220 }
        NumberAnimation { target: desliza; property: "y"; to: 0; duration: 380; easing.type: Easing.OutCubic }
    }

    Connections {
        target: janela
        function onNovo() {
            janela.pedirNovoAlarme = false;
            editor.abrir(null);
        }
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
            titulo: janela.t("Alarmes", "Alarms")
            subtitulo: !janela.carregado || janela.alarmes.count === 0 ? ""
                       : (janela.proximo ? janela.t("Próximo: ", "Next: ") + janela.quandoDia(janela.proximo.quando, janela.agora)
                                           + janela.t(" às ", " at ") + janela.hhmm(janela.proximo.alarme.hora, janela.proximo.alarme.minuto)
                                         : janela.t("Todos desligados", "All off"))
            BotaoDestaque {
                texto: janela.t("Novo alarme", "New alarm")
                icone: "matsu-mais-symbolic"
                onClicado: editor.abrir(null)
                QQC2.ToolTip.visible: containsMouse
                QQC2.ToolTip.text: "Ctrl+N"
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        // Sem os timers do systemd (a prévia, ou uma sessão sem ele): toca só com o app aberto.
        Rectangle {
            Layout.fillWidth: true
            visible: janela.carregado && !janela.systemd
            implicitHeight: linhaAviso.implicitHeight + Math.round(janela.gu * 0.9)
            radius: Math.round(janela.gu * 0.45)
            color: janela.tinta(janela.escuro ? 0.045 : 0.035)
            border.width: 1
            border.color: janela.tinta(0.07)
            RowLayout {
                id: linhaAviso
                anchors.fill: parent
                anchors.leftMargin: Math.round(janela.gu * 0.8)
                anchors.rightMargin: Math.round(janela.gu * 0.8)
                spacing: Math.round(janela.gu * 0.6)
                Kirigami.Icon {
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: implicitWidth
                    source: "matsu-info-symbolic"
                    isMask: true
                    color: janela.frente
                    opacity: 0.7
                }
                Texto {
                    Layout.fillWidth: true
                    text: janela.t("Os alarmes só tocam com o Relógio aberto: o serviço de horários do sistema (systemd) não respondeu.",
                                   "Alarms only ring while Clock is open: the system timer service (systemd) didn't respond.")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.75
                    wrapMode: Text.WordWrap
                }
            }
        }

        GridView {
            id: grade
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: -Math.round(janela.gu * 0.35)
            Layout.rightMargin: -Math.round(janela.gu * 0.35)
            readonly property int colunas: Math.max(1, Math.floor(width / (janela.gu * 15.5)))
            cellWidth: Math.floor(width / colunas)
            cellHeight: Math.round(janela.gu * 8.6)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: janela.alarmes
            bottomMargin: Math.round(janela.gu * 3)
            QQC2.ScrollBar.vertical: BarraRolagem {}

            delegate: Item {
                id: celula
                required property int index
                required property var model
                width: grade.cellWidth
                height: grade.cellHeight
                CartaoAlarme {
                    id: cartaoAlarme
                    anchors.fill: parent
                    anchors.margins: Math.round(janela.gu * 0.35)
                    alarme: ({ id: celula.model.id, nome: celula.model.nome, hora: celula.model.hora, minuto: celula.model.minuto,
                               ligado: celula.model.ligado, som: celula.model.som, soneca: celula.model.soneca, data: celula.model.data,
                               dias: celula.model.dias.length ? celula.model.dias.split(",").map(Number) : [] })
                    onEditar: editor.abrir(alarme)
                    onLigar: (sim) => janela.ligarAlarme(celula.model.id, sim)
                    onMenu: (x, y) => {
                        pagina.alvoMenu = celula.model.id;
                        menuContexto.abrirEm(cartaoAlarme, x, y);
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
            move: Transition {
                NumberAnimation { properties: "x,y"; duration: 360; easing.type: Easing.OutCubic }
            }

            Vazio {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -janela.gu
                visible: janela.carregado && janela.alarmes.count === 0
                icone: Qt.resolvedUrl("icones/alarme.svg")
                titulo: janela.t("Nenhum alarme", "No alarms")
                texto: janela.t("Crie um alarme para acordar, lembrar do remédio ou de qualquer hora importante. Ele toca mesmo com o Relógio fechado.",
                                "Create an alarm to wake up, take your medicine or remember any important time. It rings even with Clock closed.")
                botao: janela.t("Novo alarme", "New alarm")
                onClicado: editor.abrir(null)
            }
        }
    }

    EditorAlarme {
        id: editor
        onSalvar: (a) => {
            var novo = !a.id;
            janela.salvarAlarme(a);
            var q = janela.proximoToque({ hora: a.hora, minuto: a.minuto, dias: a.dias, ligado: true, data: "" }, new Date());
            janela.avisoRapido((novo ? janela.t("Alarme criado", "Alarm created") : janela.t("Alarme salvo", "Alarm saved"))
                               + (q ? " · " + janela.t("toca em ", "rings in ") + janela.textoFalta(q - new Date()) : ""), "certo");
        }
        onApagar: (id) => janela.apagarAlarme(id)
    }

    MenuMatsu {
        id: menuContexto
        itens: [
            { id: "editar", nome: janela.t("Editar", "Edit"), icone: Qt.resolvedUrl("icones/lapis.svg") },
            { id: "duplicar", nome: janela.t("Duplicar", "Duplicate"), icone: "matsu-mais-symbolic" },
            { id: "apagar", nome: janela.t("Apagar", "Delete"), icone: "matsu-lixeira-symbolic", perigo: true, separador: true }
        ]
        onEscolhido: (id) => {
            var i = janela.indiceAlarme(pagina.alvoMenu);
            if (i < 0)
                return;
            var a = janela.alarmeDe(janela.alarmes.get(i));
            if (id === "editar")
                editor.abrir(a);
            else if (id === "apagar")
                janela.apagarAlarme(a.id);
            else if (id === "duplicar") {
                a.id = "";
                janela.salvarAlarme(a);
            }
        }
    }
}
