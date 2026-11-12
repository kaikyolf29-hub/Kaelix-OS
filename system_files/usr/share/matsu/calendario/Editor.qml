// O editor de evento, no meio da janela com o resto escurecido: título, dia todo
// ou começo/fim, repetir, lembrete, cor (a paleta suave de 6), local e notas.
// Ctrl+Enter salva; Esc fecha. Num evento que se repete, a mudança vale para a série.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import "../comum"
import "datas.js" as Datas

QQC2.Popup {
    id: editor

    property bool novo: true
    property var original: null
    property string chaveOcorrencia: ""
    // A cópia que está sendo editada.
    property string titulo: ""
    property bool diaTodo: false
    property var diaIni: Datas.hoje()
    property var diaFim: Datas.hoje()
    property int minIni: 540
    property int minFim: 600
    property string cor: "salvia"
    property int lembrete: 15
    property string repetir: "nunca"
    property string ate: ""
    property string local: ""
    property string notas: ""

    function abrir(ev, ehNovo, chave) {
        original = ev;
        novo = ehNovo;
        chaveOcorrencia = chave || "";
        var a = Datas.ler(ev.inicio), b = Datas.ler(ev.fim || ev.inicio);
        titulo = ev.titulo || "";
        diaTodo = !!ev.diaTodo;
        diaIni = Datas.meiaNoite(a);
        diaFim = Datas.meiaNoite(b);
        minIni = ev.diaTodo ? 540 : Datas.minutos(a);
        minFim = ev.diaTodo ? 600 : Datas.minutos(b);
        cor = ev.cor || "salvia";
        lembrete = ev.lembrete === undefined ? -1 : ev.lembrete;
        repetir = ev.repetir || "nunca";
        ate = ev.ate || "";
        local = ev.local || "";
        notas = ev.notas || "";
        campoTitulo.texto = titulo;
        campoLocal.texto = local;
        campoNotas.text = notas;
        rolagem.contentY = 0;
        open();
    }

    readonly property var inicio: new Date(diaIni.getFullYear(), diaIni.getMonth(), diaIni.getDate(), Math.floor(minIni / 60), minIni % 60)
    readonly property var fim: new Date(diaFim.getFullYear(), diaFim.getMonth(), diaFim.getDate(), Math.floor(minFim / 60), minFim % 60)

    // Mudar o começo leva o fim junto (a duração fica a mesma).
    function mudarInicio(dia, minutos) {
        var dur = fim.getTime() - inicio.getTime();
        var novoIni = new Date(dia.getFullYear(), dia.getMonth(), dia.getDate(), Math.floor(minutos / 60), minutos % 60);
        var novoFim = new Date(novoIni.getTime() + Math.max(0, dur));
        if (diaTodo)
            novoFim = Datas.somarDias(Datas.meiaNoite(novoIni), Datas.diasEntre(diaIni, diaFim));
        diaIni = Datas.meiaNoite(novoIni);
        minIni = minutos;
        diaFim = Datas.meiaNoite(novoFim);
        if (!diaTodo)
            minFim = Datas.minutos(novoFim);
    }
    function mudarFim(dia, minutos) {
        var f = new Date(dia.getFullYear(), dia.getMonth(), dia.getDate(), Math.floor(minutos / 60), minutos % 60);
        if (diaTodo ? Datas.meiaNoite(f) < diaIni : f < inicio) {
            // Fim antes do começo: o fim vai para o mesmo dia (ou uma hora depois).
            if (diaTodo) {
                diaFim = diaIni;
                return;
            }
            if (Datas.mesmoDia(dia, diaFim) && Datas.mesmoDia(dia, diaIni) && minutos < minIni) {
                f = Datas.somarDias(f, 1);
            } else {
                f = new Date(inicio.getTime() + 3600000);
            }
        }
        diaFim = Datas.meiaNoite(f);
        minFim = Datas.minutos(f);
    }

    function salvar() {
        var t = campoTitulo.texto.trim();
        var a = inicio, b = fim;
        if (!diaTodo && b < a)
            b = new Date(a.getTime() + 3600000);
        var ev = Object.assign({}, original, {
            titulo: t.length > 0 ? t : janela.t("Novo evento", "New event"),
            diaTodo: diaTodo,
            inicio: diaTodo ? Datas.chave(diaIni) : Datas.momento(a),
            fim: diaTodo ? Datas.chave(diaFim < diaIni ? diaIni : diaFim) : Datas.momento(b),
            cor: cor,
            lembrete: lembrete,
            repetir: repetir,
            ate: repetir === "nunca" ? "" : ate,
            local: campoLocal.texto.trim(),
            notas: campoNotas.text.trim()
        });
        if (!ev.excecoes)
            ev.excecoes = [];
        janela.ultimaCor = cor;
        var criado = janela.guardarEvento(ev);
        close();
        janela.focar(diaIni);
        janela.avisoRapido(criado ? janela.t("Evento criado", "Event created") : janela.t("Evento salvo", "Event saved"), "certo");
    }

    readonly property var opcoesLembrete: diaTodo
        ? [{ id: -1, nome: janela.textoLembrete(-1, true) }, { id: 0, nome: janela.textoLembrete(0, true) }, { id: 1440, nome: janela.textoLembrete(1440, true) }]
        : [-1, 0, 5, 15, 30, 60, 1440].map(function (m) { return { id: m, nome: janela.textoLembrete(m, false) }; })
    readonly property var opcoesRepetir: ["nunca", "dia", "semana", "mes", "ano"].map(function (r) { return { id: r, nome: Datas.textoRepetir(r, diaIni, janela.pt) }; })
    onDiaTodoChanged: {
        if (diaTodo && lembrete > 0 && lembrete < 1440)
            lembrete = 0;
    }

    parent: QQC2.Overlay.overlay
    anchors.centerIn: parent
    modal: true
    focus: true
    padding: 0
    width: Math.min(Math.round(janela.gu * 27), janela.width - janela.gu * 2)
    height: Math.min(coluna.implicitHeight + 2 * Math.round(janela.gu * 1.1), janela.height - janela.gu * 2)
    closePolicy: QQC2.Popup.CloseOnEscape
    onOpened: if (novo) campoTitulo.focar()
    QQC2.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, janela.escuro ? 0.45 : 0.25)
    }
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 }
            NumberAnimation { property: "scale"; from: 0.93; to: 1; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; to: 0; duration: 120 }
            NumberAnimation { property: "scale"; to: 0.96; duration: 120 }
        }
    }
    background: FundoBalao {
        radius: Math.round(janela.gu * 0.8)
    }

    Shortcut {
        sequences: ["Ctrl+Return", "Ctrl+Enter", StandardKey.Save]
        enabled: editor.opened
        onActivated: editor.salvar()
    }

    contentItem: Flickable {
        id: rolagem
        clip: true
        contentHeight: coluna.implicitHeight + 2 * Math.round(janela.gu * 1.1)
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: BarraRolagem {}

        ColumnLayout {
            id: coluna
            x: Math.round(janela.gu * 1.1)
            y: Math.round(janela.gu * 1.1)
            width: rolagem.width - 2 * x
            spacing: Math.round(janela.gu * 0.55)

            RowLayout {
                Layout.fillWidth: true
                // A bolinha da cor escolhida, ao lado do título do balão.
                Rectangle {
                    implicitWidth: Math.round(janela.gu * 0.75)
                    implicitHeight: implicitWidth
                    radius: width / 2
                    color: janela.cor(editor.cor)
                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                }
                Texto {
                    Layout.fillWidth: true
                    Layout.leftMargin: Math.round(janela.gu * 0.2)
                    text: editor.novo ? janela.t("Novo evento", "New event") : janela.t("Editar evento", "Edit event")
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                    font.weight: Font.DemiBold
                }
                BotaoRedondo {
                    icone: "matsu-fechar-symbolic"
                    dica: janela.t("Fechar", "Close")
                    onClicado: editor.close()
                }
            }

            Campo {
                id: campoTitulo
                Layout.fillWidth: true
                implicitHeight: Math.round(janela.gu * 2.4)
                dica: janela.t("Título do evento", "Event title")
                maximo: 200
                onConfirmado: editor.salvar()
            }

            // Um aviso quando o evento se repete: mexer vale para todos os dias.
            Texto {
                visible: !editor.novo && editor.original && (editor.original.repetir || "nunca") !== "nunca"
                Layout.fillWidth: true
                text: janela.t("Este evento se repete: as mudanças valem para todos os dias.", "This event repeats: changes apply to every day.")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.55
                wrapMode: Text.WordWrap
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 0.2)
                columns: 2
                columnSpacing: Math.round(janela.gu * 0.7)
                rowSpacing: Math.round(janela.gu * 0.5)

                Rotulo { text: janela.t("Dia todo", "All day") }
                Chave {
                    nome: janela.t("Dia todo", "All day")
                    ligada: editor.diaTodo
                    onTrocada: (l) => editor.diaTodo = l
                }

                Rotulo { text: janela.t("Começa", "Starts") }
                RowLayout {
                    spacing: Math.round(janela.gu * 0.4)
                    CampoData {
                        Layout.fillWidth: true
                        nome: janela.t("Dia do começo", "Start date")
                        dia: editor.diaIni
                        onMudou: (d) => editor.mudarInicio(d, editor.minIni)
                    }
                    CampoHora {
                        visible: opacity > 0
                        opacity: editor.diaTodo ? 0 : 1
                        Layout.preferredWidth: editor.diaTodo ? 0 : implicitWidth
                        nome: janela.t("Hora do começo", "Start time")
                        minutos: editor.minIni
                        onMudou: (m) => editor.mudarInicio(editor.diaIni, m)
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 180
                            }
                        }
                    }
                }

                Rotulo { text: janela.t("Termina", "Ends") }
                RowLayout {
                    spacing: Math.round(janela.gu * 0.4)
                    CampoData {
                        Layout.fillWidth: true
                        nome: janela.t("Dia do fim", "End date")
                        dia: editor.diaFim
                        onMudou: (d) => editor.mudarFim(d, editor.minFim)
                    }
                    CampoHora {
                        visible: opacity > 0
                        opacity: editor.diaTodo ? 0 : 1
                        Layout.preferredWidth: editor.diaTodo ? 0 : implicitWidth
                        nome: janela.t("Hora do fim", "End time")
                        minutos: editor.minFim
                        referencia: Datas.mesmoDia(editor.diaIni, editor.diaFim) ? editor.minIni : -1
                        onMudou: (m) => editor.mudarFim(editor.diaFim, m)
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 180
                            }
                        }
                    }
                }

                Rotulo { text: janela.t("Repetir", "Repeat"); noTopo: true }
                ColumnLayout {
                    spacing: 2
                    Suspensa {
                        Layout.fillWidth: true
                        nome: janela.t("Repetir", "Repeat")
                        icone: Qt.resolvedUrl("icones/repetir.svg")
                        opcoes: editor.opcoesRepetir
                        escolhido: editor.repetir
                        onEscolher: (id) => editor.repetir = id
                    }
                    RowLayout {
                        visible: editor.repetir !== "nunca" && editor.ate !== ""
                        Texto {
                            Layout.fillWidth: true
                            text: editor.ate ? janela.t("Até ", "Until ") + Datas.dataCurtaAno(Datas.ler(editor.ate), janela.pt) : ""
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.6
                        }
                        Botao {
                            texto: janela.t("Sempre", "Forever")
                            onClicado: editor.ate = ""
                        }
                    }
                }

                Rotulo { text: janela.t("Lembrete", "Reminder"); noTopo: true }
                ColumnLayout {
                    spacing: 2
                    Suspensa {
                        Layout.fillWidth: true
                        nome: janela.t("Lembrete", "Reminder")
                        icone: "matsu-sino-symbolic"
                        opcoes: editor.opcoesLembrete
                        escolhido: editor.lembrete
                        onEscolher: (id) => editor.lembrete = id
                    }
                    RowLayout {
                        visible: janela.systemd === false && editor.lembrete >= 0
                        Layout.fillWidth: true
                        spacing: Math.round(janela.gu * 0.3)
                        Kirigami.Icon {
                            Layout.alignment: Qt.AlignTop
                            implicitWidth: Math.round(Kirigami.Units.iconSizes.small * 0.8)
                            implicitHeight: implicitWidth
                            source: "matsu-sino-silencio-symbolic"
                            isMask: true
                            color: janela.frente
                            opacity: 0.5
                        }
                        Texto {
                            Layout.fillWidth: true
                            text: janela.t("Nesta sessão os lembretes não tocam (sem o serviço do sistema). O evento fica guardado.",
                                           "Reminders can't ring in this session (no system service). The event is saved.")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.55
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Rotulo { text: janela.t("Cor", "Color") }
                Row {
                    spacing: Math.round(janela.gu * 0.45)
                    Repeater {
                        model: janela.paleta
                        MouseArea {
                            id: amostra
                            required property var modelData
                            readonly property bool escolhida: editor.cor === modelData.id
                            width: Math.round(janela.gu * 1.55)
                            height: width
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            activeFocusOnTab: true
                            Accessible.role: Accessible.RadioButton
                            Accessible.name: modelData.nome
                            Accessible.checked: escolhida
                            onClicked: editor.cor = modelData.id
                            Keys.onSpacePressed: editor.cor = modelData.id
                            onEscolhidaChanged: if (escolhida) pulo.restart()

                            // O anel em volta da escolhida.
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "transparent"
                                border.width: amostra.escolhida || amostra.activeFocus ? 2 : 0
                                border.color: amostra.activeFocus && !amostra.escolhida ? janela.destaque : janela.cor(amostra.modelData.id)
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: amostra.escolhida ? parent.width - 6 : (amostra.containsMouse ? parent.width - 2 : parent.width - 4)
                                height: width
                                radius: width / 2
                                color: janela.cor(amostra.modelData.id)
                                Behavior on width {
                                    NumberAnimation {
                                        duration: 160
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Shape {
                                    id: visto
                                    readonly property real lado: Math.round(janela.gu * 0.75)
                                    anchors.centerIn: parent
                                    width: lado
                                    height: lado
                                    opacity: amostra.escolhida ? 1 : 0
                                    preferredRendererType: Shape.CurveRenderer
                                    ShapePath {
                                        fillColor: "transparent"
                                        strokeColor: janela.escuro ? "#1a1a1e" : "#ffffff"
                                        strokeWidth: 2
                                        capStyle: ShapePath.RoundCap
                                        joinStyle: ShapePath.RoundJoin
                                        startX: visto.lado * 0.14
                                        startY: visto.lado * 0.52
                                        PathLine { x: visto.lado * 0.41; y: visto.lado * 0.78 }
                                        PathLine { x: visto.lado * 0.88; y: visto.lado * 0.24 }
                                    }
                                }
                            }
                            SequentialAnimation {
                                id: pulo
                                NumberAnimation { target: visto; property: "scale"; from: 0.3; to: 1.2; duration: 180; easing.type: Easing.OutQuad }
                                NumberAnimation { target: visto; property: "scale"; to: 1; duration: 240; easing.type: Easing.OutBack; easing.overshoot: 3 }
                            }
                            QQC2.ToolTip.visible: containsMouse
                            QQC2.ToolTip.text: modelData.nome
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                        }
                    }
                }

                Rotulo { text: janela.t("Local", "Place") }
                Campo {
                    id: campoLocal
                    Layout.fillWidth: true
                    icone: Qt.resolvedUrl("icones/local.svg")
                    dica: janela.t("Onde vai ser", "Where it happens")
                    maximo: 300
                }

                Rotulo {
                    Layout.alignment: Qt.AlignTop | Qt.AlignRight
                    Layout.topMargin: Math.round(janela.gu * 0.4)
                    text: janela.t("Notas", "Notes")
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Math.round(janela.gu * 4.2)
                    radius: Math.round(janela.gu * 0.4)
                    color: janela.tinta(campoNotas.activeFocus ? (janela.escuro ? 0.08 : 0.03) : (janela.escuro ? 0.05 : 0.04))
                    border.width: campoNotas.activeFocus ? 1.5 : 1
                    border.color: campoNotas.activeFocus ? janela.destaque : janela.tinta(janela.escuro ? 0.09 : 0.12)
                    QQC2.ScrollView {
                        anchors.fill: parent
                        anchors.margins: 2
                        QQC2.ScrollBar.vertical: BarraRolagem {}
                        QQC2.TextArea {
                            id: campoNotas
                            background: null
                            color: janela.frente
                            selectionColor: janela.destaque
                            selectedTextColor: janela.sobreDestaque
                            placeholderText: janela.t("Detalhes, links, o que levar...", "Details, links, what to bring...")
                            placeholderTextColor: janela.tinta(0.45)
                            wrapMode: TextEdit.Wrap
                            leftPadding: Math.round(janela.gu * 0.5)
                            topPadding: Math.round(janela.gu * 0.35)
                            Keys.onEscapePressed: (e) => e.accepted = false
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 0.6)
                spacing: Math.round(janela.gu * 0.4)
                Botao {
                    visible: !editor.novo
                    icone: "matsu-lixeira-symbolic"
                    texto: janela.t("Apagar", "Delete")
                    onClicado: {
                        var ev = editor.original, k = editor.chaveOcorrencia;
                        editor.close();
                        janela.pedirApagar(ev, k);
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                Botao {
                    texto: janela.t("Cancelar", "Cancel")
                    onClicado: editor.close()
                }
                BotaoDestaque {
                    texto: editor.novo ? janela.t("Criar", "Create") : janela.t("Salvar", "Save")
                    onClicado: editor.salvar()
                }
            }
        }
    }

    // O nome de cada linha, à direita. "noTopo": alinhado ao controle de cima (a linha tem um aviso embaixo).
    component Rotulo: Texto {
        property bool noTopo: false
        Layout.alignment: (noTopo ? Qt.AlignTop : Qt.AlignVCenter) | Qt.AlignRight
        Layout.topMargin: noTopo ? Math.round((janela.gu * 2 - implicitHeight) / 2) : 0
        horizontalAlignment: Text.AlignRight
        opacity: 0.65
    }
}
