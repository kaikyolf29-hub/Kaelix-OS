// Criar e editar um alarme, num diálogo no meio da janela: a hora nas rodas de rolar
// (com "Toca em ..." embaixo, que muda enquanto a roda gira), o nome, o som (com
// "Ouvir"), a soneca e os dias da semana em etiquetas. Enter salva, Esc fecha.
//   editor.abrir(null)          novo alarme
//   editor.abrir(alarme)        editar
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

QQC2.Popup {
    id: editor

    property string ident: ""
    property int hora: 7
    property int minuto: 0
    property string nome: ""
    property var dias: [0, 1, 2, 3, 4]
    property string som: "alarme"
    property int soneca: 10
    property bool ligado: true

    signal salvar(var alarme)
    signal apagar(string ident)

    readonly property var alvo: janela.proximoToque({ hora: hora, minuto: minuto, dias: dias, ligado: true, data: "" }, janela.agora)

    function abrir(a) {
        if (a) {
            ident = a.id;
            nome = a.nome;
            dias = a.dias.slice();
            som = a.som;
            soneca = a.soneca;
            ligado = a.ligado;
            hora = a.hora;
            minuto = a.minuto;
        } else {
            // Novo: a próxima hora cheia (ou 07:00 de manhã cedo), nos dias úteis.
            var d = new Date();
            ident = "";
            nome = "";
            dias = [0, 1, 2, 3, 4];
            som = "alarme";
            soneca = 10;
            ligado = true;
            hora = d.getHours() < 5 ? 7 : (d.getHours() + 1) % 24;
            minuto = 0;
        }
        campoNome.texto = nome;
        open();
    }
    function confirmar() {
        matsu.parar("ouvir");
        salvar({ id: ident, nome: campoNome.texto.trim(), hora: hora, minuto: minuto, dias: dias, som: som, soneca: soneca,
                 ligado: true });
        close();
    }
    function trocarDia(d, sim) {
        var novos = dias.filter(function (x) { return x !== d; });
        if (sim)
            novos.push(d);
        novos.sort();
        dias = novos;
    }

    parent: QQC2.Overlay.overlay
    anchors.centerIn: parent
    modal: true
    focus: true
    padding: Math.round(janela.gu * 1.2)
    width: Math.min(Math.round(janela.gu * 34), parent ? parent.width - janela.gu * 2 : janela.gu * 34)
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
    onOpened: rodaHora.forceActiveFocus()
    onClosed: matsu.parar("ouvir")
    QQC2.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, janela.escuro ? 0.45 : 0.25)
    }
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 }
            NumberAnimation { property: "scale"; from: 0.92; to: 1; duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
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
        sequences: ["Return", "Enter", "Ctrl+Return"]
        enabled: editor.opened
        onActivated: editor.confirmar()
    }

    contentItem: ColumnLayout {
        spacing: Math.round(janela.gu * 0.7)

        RowLayout {
            Layout.fillWidth: true
            Texto {
                Layout.fillWidth: true
                text: editor.ident ? janela.t("Editar alarme", "Edit alarm") : janela.t("Novo alarme", "New alarm")
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Botao {
                icone: "matsu-fechar-symbolic"
                dica: janela.t("Fechar sem salvar", "Close without saving")
                onClicado: editor.close()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(janela.gu * 1.4)

            // A hora: duas rodas e o "Toca em".
            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: Math.round(janela.gu * 0.5)
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Math.round(janela.gu * 0.3)
                    RodaNumero {
                        id: rodaHora
                        quantos: 24
                        valor: editor.hora
                        nome: janela.t("Hora", "Hour")
                        onMudou: (v) => editor.hora = v
                    }
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ":"
                        font.pixelSize: Math.round(janela.gu * 1.4)
                        font.weight: Font.DemiBold
                        opacity: 0.6
                    }
                    RodaNumero {
                        id: rodaMinuto
                        quantos: 60
                        valor: editor.minuto
                        nome: janela.t("Minuto", "Minute")
                        onMudou: (v) => editor.minuto = v
                    }
                }
                Texto {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: Math.round(janela.gu * 9)
                    horizontalAlignment: Text.AlignHCenter
                    text: editor.alvo ? janela.t("Toca em ", "Rings in ") + janela.textoFalta(editor.alvo - janela.agora) : ""
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.features: { "tnum": 1 }
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                }
            }

            // Nome, som e soneca.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Math.round(janela.gu * 0.3)

                Texto {
                    text: janela.t("Nome", "Name")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.7
                }
                Campo {
                    id: campoNome
                    Layout.fillWidth: true
                    dica: janela.t("Ex.: Acordar, Remédio", "E.g. Wake up, Medicine")
                    maximo: 60
                    onConfirmado: editor.confirmar()
                }
                Texto {
                    Layout.topMargin: Math.round(janela.gu * 0.4)
                    text: janela.t("Som", "Sound")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.7
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(janela.gu * 0.4)
                    Suspensa {
                        Layout.fillWidth: true
                        nome: janela.t("Som do alarme", "Alarm sound")
                        icone: "matsu-volume-2-symbolic"
                        opcoes: [
                            { id: "alarme", nome: janela.t("Despertador", "Alarm clock") },
                            { id: "campainha", nome: janela.t("Campainha", "Ringtone") },
                            { id: "sino", nome: janela.t("Sino", "Bell") },
                            { id: "suave", nome: janela.t("Suave", "Gentle") }
                        ]
                        escolhido: editor.som
                        onEscolher: (id) => {
                            editor.som = id;
                            matsu.parar("ouvir");
                        }
                    }
                    Botao {
                        icone: "matsu-jogar-symbolic"
                        texto: janela.t("Ouvir", "Play")
                        dica: janela.t("Ouvir o som uma vez", "Play the sound once")
                        onClicado: {
                            matsu.parar("ouvir");
                            matsu.iniciar("ouvir", janela.comando(["ouvir", editor.som]));
                        }
                    }
                }
                Texto {
                    Layout.topMargin: Math.round(janela.gu * 0.4)
                    text: janela.t("Soneca", "Snooze")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.7
                }
                Seletor {
                    Layout.fillWidth: true
                    opcoes: [
                        { id: "0", nome: janela.t("Sem", "Off") },
                        { id: "5", nome: "5 min" },
                        { id: "10", nome: "10 min" },
                        { id: "15", nome: "15 min" }
                    ]
                    escolhido: String(editor.soneca)
                    onEscolher: (id) => editor.soneca = Number(id)
                }
            }
        }

        // Os dias.
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.2)
            Texto {
                text: janela.t("Repetir", "Repeat")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
            }
            Item {
                Layout.fillWidth: true
            }
            Texto {
                text: janela.resumoDias(editor.dias)
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(janela.gu * 0.3)
            Repeater {
                model: 7
                Etiqueta {
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    texto: janela.curtosDias[index]
                    escolhida: editor.dias.indexOf(index) >= 0
                    Accessible.name: janela.nomesDias[index]
                    onTrocada: (e) => editor.trocarDia(index, e)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(janela.gu * 0.5)
            spacing: Math.round(janela.gu * 0.5)
            Botao {
                visible: editor.ident.length > 0
                icone: "matsu-lixeira-symbolic"
                texto: janela.t("Apagar", "Delete")
                onClicado: {
                    var id = editor.ident;
                    editor.close();
                    editor.apagar(id);
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
                texto: janela.t("Salvar", "Save")
                onClicado: editor.confirmar()
            }
        }
    }
}
