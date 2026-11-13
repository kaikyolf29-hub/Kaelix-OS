// Histórico e quarentena: tudo o que o escudo fez (separado por dia), os arquivos
// trancados na quarentena (restaurar, com confirmação, ou apagar de vez) e a lista
// de exceções (arquivos que você liberou e não são mais avisados).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.6)
    readonly property var dados: janela.hist
    readonly property bool lendo: !dados
    readonly property string aba: janela.abaHistorico
    readonly property string busca: janela.simples(janela.busca.trim())
    function bate(texto) {
        return !busca || janela.simples(texto || "").indexOf(busca) >= 0;
    }
    readonly property var eventos: dados && dados.eventos ? dados.eventos.filter(function (e) {
        var d = janela.descrever(e);
        return pagina.bate(d.titulo + " " + d.texto);
    }) : []
    readonly property var quarentena: dados && dados.quarentena ? dados.quarentena.filter(function (q) {
        return pagina.bate(q.nome + " " + q.ameaca + " " + q.origem);
    }) : []
    readonly property var excecoes: dados && dados.excecoes ? dados.excecoes.filter(function (x) {
        return pagina.bate(x.nome + " " + x.url);
    }) : []
    // Os eventos com o nome do dia antes do primeiro de cada dia.
    function nomeDia(segundos) {
        var d = new Date(segundos * 1000);
        var hoje = new Date();
        var ontem = new Date(hoje.getFullYear(), hoje.getMonth(), hoje.getDate() - 1);
        if (d.toDateString() === hoje.toDateString())
            return janela.t("Hoje", "Today");
        if (d.toDateString() === ontem.toDateString())
            return janela.t("Ontem", "Yesterday");
        return d.toLocaleDateString(janela.local, janela.pt ? "dddd, d 'de' MMMM" : "dddd, MMMM d");
    }
    function site(url) {
        var m = /^[a-z]+:\/\/([^\/:]+)/i.exec(url || "");
        return m ? m[1] : "";
    }

    function restaurar(q) {
        janela.dialogo.perguntar({
            titulo: janela.t("Restaurar " + q.nome + "?", "Restore " + q.nome + "?"),
            texto: janela.t("O escudo achou " + q.ameaca + " neste arquivo. Restaurado, ele volta para a pasta de onde saiu e não será mais avisado. Só faça isso se tiver certeza de que é seguro.",
                            "The shield found " + q.ameaca + " in this file. Once restored, it goes back to its folder and won't be flagged again. Only do this if you're sure it's safe."),
            sim: janela.t("Restaurar mesmo assim", "Restore anyway"), nao: janela.t("Cancelar", "Cancel"), perigo: true
        }, function () {
            janela.agir("restaurar-" + q.id, ["restaurar", q.id], { certo: janela.t(q.nome + " foi restaurado", q.nome + " was restored"), recarregar: ["historico"] });
        });
    }
    function apagar(q) {
        janela.dialogo.perguntar({
            titulo: janela.t("Apagar " + q.nome + " de vez?", "Delete " + q.nome + " for good?"),
            texto: janela.t("O arquivo some para sempre. Não dá para desfazer.", "The file is gone forever. This can't be undone."),
            sim: janela.t("Apagar de vez", "Delete for good"), nao: janela.t("Cancelar", "Cancel"), perigo: true
        }, function () {
            janela.agir("apagar-" + q.id, ["apagar", q.id], { certo: janela.t(q.nome + " foi apagado", q.nome + " was deleted"), recarregar: ["historico"] });
        });
    }
    function tirarExcecao(x) {
        janela.agir("excecao-" + x.sha256, ["excecao-tirar", x.sha256], {
            certo: janela.t("Se abrir " + x.nome + " de novo, o Matsu avisa", "If you open " + x.nome + " again, Matsu will warn you"),
            recarregar: ["historico"]
        });
    }

    Flickable {
        id: rolagem
        anchors.fill: parent
        contentWidth: width
        contentHeight: coluna.implicitHeight + 2 * pagina.margem
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        QQC2.ScrollBar.vertical: BarraRolagem {}

        ColumnLayout {
            id: coluna
            width: Math.min(rolagem.width - 2 * pagina.margem, Math.round(janela.gu * 52))
            x: Math.round((rolagem.width - width) / 2)
            y: pagina.margem
            spacing: Math.round(janela.gu * 0.7)

            Texto {
                text: janela.t("Histórico e quarentena", "History & quarantine")
                font.pixelSize: Math.round(janela.gu * 1.3)
                font.weight: Font.DemiBold
            }
            Seletor {
                opcoes: [
                    { id: "tudo", nome: janela.t("Tudo", "Everything") },
                    { id: "quarentena", nome: janela.t("Quarentena", "Quarantine") + (pagina.dados && pagina.dados.quarentena && pagina.dados.quarentena.length ? "  " + pagina.dados.quarentena.length : "") },
                    { id: "excecoes", nome: janela.t("Liberados", "Allowed") + (pagina.dados && pagina.dados.excecoes && pagina.dados.excecoes.length ? "  " + pagina.dados.excecoes.length : "") }
                ]
                escolhido: pagina.aba
                onEscolher: (id) => janela.abaHistorico = id
            }
            Texto {
                Layout.fillWidth: true
                text: pagina.aba === "quarentena"
                    ? janela.t("Os arquivos aqui ficam trancados: embaralhados, sem permissão de rodar, numa pasta só sua. Não fazem nada enquanto estiverem aqui.",
                               "Files here are locked away: scrambled, not allowed to run, in a folder only you can open. They can't do anything while here.")
                    : pagina.aba === "excecoes"
                    ? janela.t("Arquivos que você abriu mesmo assim ou restaurou. O Matsu não avisa mais sobre eles; tirar da lista faz o aviso voltar.",
                               "Files you opened anyway or restored. Matsu no longer warns about them; removing one brings the warning back.")
                    : janela.t("O que o escudo fez nos últimos tempos.", "What the shield has been doing lately.")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.62
                wrapMode: Text.WordWrap
            }

            // ----- carregando -----
            Repeater {
                model: pagina.lendo ? 4 : 0
                Esqueleto {
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(janela.gu * 3)
                    raio: Math.round(janela.gu * 0.5)
                }
            }

            // ----- tudo -----
            Vazio {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 2)
                visible: !pagina.lendo && pagina.aba === "tudo" && pagina.eventos.length === 0
                icone: "matsu-relogio-symbolic"
                titulo: pagina.busca ? janela.t("Nada com esse nome", "Nothing matches") : janela.t("Nada por enquanto", "Nothing yet")
                texto: pagina.busca ? "" : janela.t("Verificações, ameaças e avisos aparecem aqui.", "Scans, threats and warnings show up here.")
            }
            Cartao {
                Layout.fillWidth: true
                visible: !pagina.lendo && pagina.aba === "tudo" && pagina.eventos.length > 0
                implicitHeight: listaEventos.implicitHeight + Math.round(janela.gu * 1)
                ColumnLayout {
                    id: listaEventos
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Math.round(janela.gu * 0.5)
                    anchors.leftMargin: Math.round(janela.gu * 0.9)
                    anchors.rightMargin: Math.round(janela.gu * 0.9)
                    spacing: 0
                    Repeater {
                        model: pagina.aba === "tudo" ? pagina.eventos.slice(0, 120) : []
                        ColumnLayout {
                            required property var modelData
                            required property int index
                            readonly property string dia: pagina.nomeDia(modelData.data || 0)
                            readonly property bool novoDia: index === 0 || pagina.nomeDia(pagina.eventos[index - 1].data || 0) !== dia
                            Layout.fillWidth: true
                            spacing: 0
                            Texto {
                                Layout.fillWidth: true
                                Layout.topMargin: Math.round(janela.gu * (index === 0 ? 0.4 : 0.9))
                                Layout.bottomMargin: Math.round(janela.gu * 0.2)
                                visible: parent.novoDia
                                text: parent.dia.charAt(0).toUpperCase() + parent.dia.slice(1)
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                font.weight: Font.DemiBold
                                opacity: 0.55
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                visible: !parent.novoDia
                                implicitHeight: 1
                                color: janela.tinta(0.06)
                            }
                            LinhaEvento {
                                Layout.fillWidth: true
                                Layout.topMargin: Math.round(janela.gu * 0.4)
                                Layout.bottomMargin: Math.round(janela.gu * 0.4)
                                evento: parent.modelData
                                soHora: true
                            }
                        }
                    }
                }
            }

            // ----- quarentena -----
            Vazio {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 2)
                visible: !pagina.lendo && pagina.aba === "quarentena" && pagina.quarentena.length === 0
                icone: janela.ic("quarentena")
                titulo: pagina.busca ? janela.t("Nada com esse nome", "Nothing matches") : janela.t("A quarentena está vazia", "Quarantine is empty")
                texto: pagina.busca ? "" : janela.t("Quando o escudo achar uma ameaça, o arquivo fica trancado aqui.", "When the shield finds a threat, the file is locked away here.")
            }
            Repeater {
                model: pagina.aba === "quarentena" ? pagina.quarentena : []
                Cartao {
                    id: cartaoQ
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: colunaQ.implicitHeight + Math.round(janela.gu * 2)
                    ColumnLayout {
                        id: colunaQ
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Math.round(janela.gu * 1)
                        spacing: Math.round(janela.gu * 0.6)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(janela.gu * 0.8)
                            IconeRedondo {
                                Layout.alignment: Qt.AlignTop
                                icone: janela.ic("quarentena")
                                cor: janela.coral
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Texto {
                                    Layout.fillWidth: true
                                    text: cartaoQ.modelData.nome
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideMiddle
                                }
                                Texto {
                                    Layout.fillWidth: true
                                    text: cartaoQ.modelData.ameaca
                                    color: janela.coral
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    elide: Text.ElideRight
                                }
                                Texto {
                                    Layout.fillWidth: true
                                    text: janela.t("Estava em ", "Was in ") + String(cartaoQ.modelData.origem || "").replace(/\/[^\/]*$/, "").replace(/^\/home\/[^\/]+/, "~")
                                          + (pagina.site(cartaoQ.modelData.url) ? janela.t(" · baixado de ", " · downloaded from ") + pagina.site(cartaoQ.modelData.url) : "")
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    opacity: 0.6
                                    elide: Text.ElideMiddle
                                }
                                Texto {
                                    Layout.fillWidth: true
                                    text: janela.t("Trancado ", "Locked away ") + janela.quando(cartaoQ.modelData.data) + " · " + janela.bytes(cartaoQ.modelData.tamanho || 0)
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    opacity: 0.6
                                    elide: Text.ElideRight
                                }
                            }
                        }
                        RowLayout {
                            Layout.leftMargin: Math.round(janela.gu * 3.1)
                            spacing: Math.round(janela.gu * 0.4)
                            BotaoDestaque {
                                texto: janela.t("Apagar de vez", "Delete for good")
                                icone: "matsu-lixeira-symbolic"
                                perigo: true
                                estado: janela.ocupado["apagar-" + cartaoQ.modelData.id] ? "carregando" : ""
                                onClicado: pagina.apagar(cartaoQ.modelData)
                            }
                            Botao {
                                texto: janela.t("Restaurar…", "Restore…")
                                icone: janela.ic("restaurar")
                                ativo: !janela.ocupado["restaurar-" + cartaoQ.modelData.id]
                                onClicado: pagina.restaurar(cartaoQ.modelData)
                            }
                        }
                    }
                }
            }

            // ----- liberados (exceções) -----
            Vazio {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 2)
                visible: !pagina.lendo && pagina.aba === "excecoes" && pagina.excecoes.length === 0
                icone: "matsu-certo-symbolic"
                titulo: pagina.busca ? janela.t("Nada com esse nome", "Nothing matches") : janela.t("Nenhum arquivo liberado", "No allowed files")
                texto: pagina.busca ? "" : janela.t("Quando você abrir um arquivo mesmo com o aviso, ele aparece aqui.", "When you open a file despite the warning, it shows up here.")
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                visible: pagina.aba === "excecoes" && pagina.excecoes.length > 0
                Repeater {
                    model: pagina.aba === "excecoes" ? pagina.excecoes : []
                    LinhaOpcao {
                        id: linhaX
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        primeira: index === 0
                        ultima: index === pagina.excecoes.length - 1
                        icone: janela.ic("arquivo")
                        nome: modelData.nome
                        texto: (modelData.motivo === "restaurado" ? janela.t("Restaurado da quarentena", "Restored from quarantine") : janela.t("Aberto mesmo assim", "Opened anyway"))
                               + " " + janela.quando(modelData.data)
                               + (pagina.site(modelData.url) ? " · " + pagina.site(modelData.url) : "")
                        Botao {
                            texto: janela.t("Tirar da lista", "Remove")
                            ativo: !janela.ocupado["excecao-" + linhaX.modelData.sha256]
                            onClicado: pagina.tirarExcecao(linhaX.modelData)
                        }
                    }
                }
            }
        }
    }
}
