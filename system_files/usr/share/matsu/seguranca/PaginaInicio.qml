// Início: o selo do Matsu com o estado em uma frase (e o que fazer, quando há
// algo a fazer) e um cartão para cada área da segurança.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.6)
    readonly property string geral: janela.geral
    readonly property var esc: janela.escudo
    readonly property var cont: janela.cont
    readonly property var resumo: janela.resumo
    readonly property bool verificando: janela.verRodando
    readonly property var recentes: janela.hist && janela.hist.eventos ? janela.hist.eventos.slice(0, 4) : []
    readonly property int novas: cont ? cont.novas : 0

    readonly property string titulo: {
        if (verificando)
            return janela.verTotal > 0 ? janela.t("Verificando… ", "Scanning… ") + janela.porcento(janela.verParte * 100)
                                       : janela.t("Preparando a verificação…", "Getting the scan ready…");
        switch (geral) {
        case "protegido":
            return janela.t("Seu computador está protegido", "Your computer is protected");
        case "pausado":
            return janela.t("O escudo está pausado", "The shield is paused");
        case "atencao":
            return novas > 1 ? janela.t(novas + " ameaças foram para a quarentena", novas + " threats were quarantined")
                             : janela.t("Uma ameaça foi para a quarentena", "A threat was quarantined");
        case "parado":
            return janela.t("O escudo em tempo real parou", "The real-time shield stopped");
        case "desligado":
            return janela.t("O escudo está desligado", "The shield is off");
        case "baixando":
            return janela.t("Baixando a lista de ameaças…", "Downloading the threat list…");
        case "sem-lista":
            return janela.t("Falta a lista de ameaças", "The threat list is missing");
        case "indisponivel":
            return janela.t("O antivírus não está instalado", "The antivirus is not installed");
        default:
            return janela.t("Conferindo a proteção…", "Checking protection…");
        }
    }
    readonly property string texto: {
        if (verificando)
            return janela.verTotal > 0 ? janela.t(janela.num(janela.verFeitos) + " de " + janela.num(janela.verTotal) + " arquivos conferidos.",
                                                  janela.num(janela.verFeitos) + " of " + janela.num(janela.verTotal) + " files checked.")
                                       : janela.t("Contando os arquivos que vão ser conferidos.", "Counting the files to check.");
        switch (geral) {
        case "protegido":
            var u = cont ? cont.ultimaVerificacao : null;
            if (u && u.data)
                return janela.t("Última verificação ", "Last scan ") + janela.quando(u.data)
                       + (u.ameacas > 0 ? (u.ameacas === 1 ? janela.t(": 1 ameaça na quarentena.", ": 1 threat quarantined.") : janela.t(": " + u.ameacas + " ameaças na quarentena.", ": " + u.ameacas + " threats quarantined."))
                                        : janela.t(", nada encontrado.", ", nothing found."));
            return janela.t("Cada arquivo baixado é conferido sozinho.",
                            "Every downloaded file is checked automatically.");
        case "pausado":
            if (esc && esc.pausaReiniciar)
                return janela.t("Ele volta quando você reiniciar o computador.", "It comes back when you restart the computer.");
            return esc ? janela.t("Ele volta sozinho em " + janela.falta(esc.pausaAte) + ", às " + janela.hora(esc.pausaAte) + ".",
                                  "It comes back by itself in " + janela.falta(esc.pausaAte) + ", at " + janela.hora(esc.pausaAte) + ".") : "";
        case "atencao":
            return janela.t("O arquivo foi trancado e não faz nada.",
                            "The file was locked away and can't do anything.");
        case "parado":
            return janela.t("Os arquivos novos não estão sendo conferidos agora.", "New files aren't being checked right now.");
        case "desligado":
            return janela.t("Os arquivos que chegam não são conferidos até você ligar de novo.", "Incoming files aren't checked until you turn it back on.");
        case "baixando":
            var l = janela.lista;
            return l && l.baixado > 0
                ? janela.t(janela.bytes(l.baixado) + " de uns " + janela.bytes(l.total) + ". O escudo começa a vigiar assim que ela chegar.",
                           janela.bytes(l.baixado) + " of about " + janela.bytes(l.total) + ". The shield starts watching as soon as it arrives.")
                : janela.t("O escudo começa a vigiar assim que ela chegar.", "The shield starts watching as soon as it arrives.");
        case "sem-lista":
            return janela.t("O escudo baixa a lista (uns 230 MB) sozinho quando houver internet.",
                            "The shield downloads the list (about 230 MB) by itself when there's internet.");
        case "indisponivel":
            return janela.t("O ClamAV vem com o Matsu e falta aqui. A rede, as permissões e a integridade continuam funcionando.",
                            "ClamAV ships with Matsu and is missing here. Network, permissions and integrity still work.");
        default:
            return "";
        }
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
            width: Math.min(rolagem.width - 2 * pagina.margem, Math.round(janela.gu * 56))
            x: Math.round((rolagem.width - width) / 2)
            y: pagina.margem
            spacing: Math.round(janela.gu * 0.8)

            // ----- o selo e o estado -----
            Cartao {
                Layout.fillWidth: true
                implicitHeight: Math.max(linhaHeroi.implicitHeight, selo.height) + Math.round(janela.gu * 2.8)

                // Um véu da cor do estado, bem de leve, saindo de trás do selo.
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    opacity: janela.escuro ? 0.16 : 0.12
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: janela.corEstado(pagina.geral) }
                        GradientStop { position: 0.55; color: "transparent" }
                    }
                }

                RowLayout {
                    id: linhaHeroi
                    anchors.fill: parent
                    anchors.margins: Math.round(janela.gu * 1.4)
                    spacing: Math.round(janela.gu * 1.4)

                    Selo {
                        id: selo
                        Layout.preferredWidth: Math.round(janela.gu * 7.4)
                        Layout.preferredHeight: Layout.preferredWidth
                        Layout.alignment: Qt.AlignVCenter
                        estado: pagina.verificando ? "protegido" : (pagina.geral === "lendo" ? "indisponivel" : pagina.geral)
                        progresso: pagina.verificando ? janela.verParte : -1
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: Math.round(janela.gu * 0.35)

                        Texto {
                            Layout.fillWidth: true
                            text: pagina.titulo
                            font.pixelSize: Math.round(janela.gu * 1.45)
                            font.weight: Font.DemiBold
                            wrapMode: Text.WordWrap
                        }
                        Texto {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: pagina.texto
                            opacity: 0.72
                            wrapMode: Text.WordWrap
                        }
                        // A barra do download da lista (no estado "baixando").
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.maximumWidth: Math.round(janela.gu * 18)
                            Layout.topMargin: Math.round(janela.gu * 0.2)
                            visible: pagina.geral === "baixando" && !pagina.verificando
                            implicitHeight: 4
                            radius: 2
                            color: janela.tinta(0.1)
                            Rectangle {
                                readonly property var l: janela.lista
                                height: parent.height
                                radius: 2
                                color: janela.ambar
                                width: parent.width * (l && l.total > 0 ? Math.min(1, l.baixado / l.total) : 0)
                                Behavior on width {
                                    NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
                                }
                            }
                        }
                        RowLayout {
                            Layout.topMargin: Math.round(janela.gu * 0.45)
                            spacing: Math.round(janela.gu * 0.5)
                            visible: principal.acao !== null || secundario.mostrar

                            BotaoDestaque {
                                id: principal
                                readonly property var acao: {
                                    if (pagina.verificando)
                                        return { texto: janela.t("Ver a verificação", "View scan"), f: function () { janela.pagina = "escudo"; } };
                                    switch (pagina.geral) {
                                    case "protegido":
                                        return { texto: janela.t("Verificação rápida", "Quick scan"), f: function () { janela.verificar("rapida"); } };
                                    case "pausado":
                                        return { texto: janela.t("Voltar a proteger agora", "Resume protection now"), f: janela.retomar, ocupado: "retomar" };
                                    case "atencao":
                                        return { texto: janela.t("Ver a quarentena", "View quarantine"), f: function () { janela.abaHistorico = "quarentena"; janela.pagina = "historico"; } };
                                    case "parado":
                                        return { texto: janela.t("Ligar de novo", "Start again"), f: janela.religarEscudo };
                                    case "desligado":
                                        return { texto: janela.t("Ligar o escudo", "Turn on the shield"), f: function () { janela.ajuste("ligado", true); }, ocupado: "ajuste-ligado" };
                                    case "sem-lista":
                                        return { texto: janela.t("Baixar agora", "Download now"), f: janela.atualizarLista, ocupado: "lista" };
                                    default:
                                        return null;
                                    }
                                }
                                visible: acao !== null
                                texto: acao ? acao.texto : ""
                                estado: acao && acao.ocupado && janela.ocupado[acao.ocupado] ? "carregando" : ""
                                onClicado: acao.f()
                            }
                            Botao {
                                id: secundario
                                readonly property bool mostrar: !pagina.verificando && (pagina.geral === "protegido" || pagina.geral === "atencao")
                                visible: mostrar
                                texto: janela.t("Mais verificações", "More scans")
                                icone: "matsu-escudo-symbolic"
                                onClicado: janela.pagina = "escudo"
                            }
                        }
                    }
                }
            }

            Secao {
                titulo: janela.t("Tudo o que protege este computador", "Everything protecting this computer")
            }

            GridLayout {
                id: grade
                Layout.fillWidth: true
                columns: coluna.width > janela.gu * 40 ? 3 : 2
                columnSpacing: Math.round(janela.gu * 0.7)
                rowSpacing: Math.round(janela.gu * 0.7)

                CartaoArea {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    icone: "matsu-escudo-symbolic"
                    titulo: janela.t("Escudo em tempo real", "Real-time shield")
                    lendo: !janela.est
                    cor: pagina.geral === "atencao" ? janela.verde : janela.corEstado(pagina.geral)
                    linha: {
                        switch (pagina.geral) {
                        case "protegido":
                        case "atencao":
                            var p = pagina.esc ? pagina.esc.pastas.map(function (x) { return x.nome; }) : [];
                            return p.length ? janela.t("Vigiando ", "Watching ") + p.join(janela.t(" e ", " and ")) : janela.t("Ligado", "On");
                        case "pausado":
                            return pagina.esc && pagina.esc.pausaReiniciar ? janela.t("Pausado até reiniciar", "Paused until restart")
                                                                           : janela.t("Pausado: volta em ", "Paused: back in ") + janela.falta(pagina.esc ? pagina.esc.pausaAte : 0);
                        case "baixando":
                        case "sem-lista":
                            return janela.t("Esperando a lista de ameaças", "Waiting for the threat list");
                        default:
                            return janela.nomeEstado(pagina.geral);
                        }
                    }
                    onClicked: janela.pagina = "escudo"
                }
                CartaoArea {
                    readonly property var l: janela.lista
                    readonly property bool velha: l && l.presente && janela.agora - l.data > 3 * 86400
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    icone: janela.ic("lista")
                    titulo: janela.t("Lista de ameaças", "Threat list")
                    lendo: !janela.est
                    cor: !janela.est || !janela.est.instalado ? janela.corEstado("") : (l.presente && !velha ? janela.verde : janela.ambar)
                    linha: !janela.est ? "" : !janela.est.instalado ? janela.t("Sem o ClamAV", "No ClamAV")
                         : l.presente ? janela.t("Atualizada ", "Updated ") + janela.ha(l.data)
                         : l.baixando ? janela.t("Baixando…", "Downloading…") : janela.t("Ainda não baixada", "Not downloaded yet")
                    onClicked: janela.pagina = "escudo"
                }
                CartaoArea {
                    readonly property var r: pagina.resumo ? pagina.resumo.rede : null
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    icone: r && r.tipo === "cabo" ? "matsu-rede-cabo-symbolic" : "matsu-web-symbolic"
                    titulo: janela.t("Rede e firewall", "Network & firewall")
                    lendo: !pagina.resumo
                    cor: !r ? janela.corEstado("") : r.firewall === "ligado" ? janela.verde : janela.coral
                    linha: !r ? janela.t("Não deu para ler a rede", "Couldn't read the network")
                         : r.firewall !== "ligado" ? janela.t("Firewall desligado", "Firewall off")
                         : r.nome ? r.nome + " · " + (r.rede === "casa" ? janela.t("Rede de casa", "Home network") : janela.t("Rede pública", "Public network"))
                         : janela.t("Firewall ligado", "Firewall on")
                    onClicked: janela.pagina = "rede"
                }
                CartaoArea {
                    readonly property var a: pagina.resumo ? pagina.resumo.apps : null
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    icone: "matsu-apps-symbolic"
                    titulo: janela.t("Permissões dos apps", "App permissions")
                    lendo: !pagina.resumo
                    linha: !a || !a.flatpak ? janela.t("Nenhum app da Loja", "No Store apps")
                         : janela.t(a.camera + " com câmera · " + a.microfone + " com microfone", a.camera + " with camera · " + a.microfone + " with microphone")
                    onClicked: janela.pagina = "apps"
                }
                CartaoArea {
                    readonly property var i: pagina.resumo ? pagina.resumo.integridade : null
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    icone: "matsu-verificado-symbolic"
                    titulo: janela.t("Integridade do sistema", "System integrity")
                    lendo: !pagina.resumo
                    cor: !i ? janela.corEstado("") : i.nivel === "ok" ? janela.verde : janela.ambar
                    linha: !i ? janela.t("Não deu para conferir", "Couldn't check")
                         : i.atencao.length ? i.atencao[0]
                         : janela.t(i.ok + " de " + i.total + " itens em ordem", i.ok + " of " + i.total + " items in order")
                    onClicked: janela.pagina = "integridade"
                }
                CartaoArea {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    icone: janela.ic("quarentena")
                    titulo: janela.t("Histórico e quarentena", "History & quarantine")
                    lendo: !janela.est
                    cor: pagina.cont && pagina.cont.novas > 0 ? janela.coral : "transparent"
                    linha: !pagina.cont ? ""
                         : pagina.cont.quarentena === 0 ? janela.t("Nada na quarentena", "Nothing in quarantine")
                         : pagina.cont.quarentena === 1 ? janela.t("1 arquivo na quarentena", "1 file in quarantine")
                         : janela.t(pagina.cont.quarentena + " arquivos na quarentena", pagina.cont.quarentena + " files in quarantine")
                    onClicked: janela.pagina = "historico"
                }
            }

            // ----- o que aconteceu por último -----
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 0.7)
                visible: pagina.recentes.length > 0
                Texto {
                    Layout.fillWidth: true
                    text: janela.t("Atividade recente", "Recent activity")
                    font.weight: Font.DemiBold
                    opacity: 0.9
                }
                Botao {
                    texto: janela.t("Ver o histórico", "View history")
                    icone: "matsu-seta-symbolic"
                    iconeNoFim: true
                    onClicado: janela.pagina = "historico"
                }
            }
            Cartao {
                Layout.fillWidth: true
                visible: pagina.recentes.length > 0
                implicitHeight: listaRecentes.implicitHeight + Math.round(janela.gu * 1.2)
                ColumnLayout {
                    id: listaRecentes
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Math.round(janela.gu * 0.6)
                    anchors.leftMargin: Math.round(janela.gu * 0.9)
                    anchors.rightMargin: Math.round(janela.gu * 0.9)
                    spacing: 0
                    Repeater {
                        model: pagina.recentes
                        ColumnLayout {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: 0
                            Rectangle {
                                Layout.fillWidth: true
                                visible: index > 0
                                implicitHeight: 1
                                color: janela.tinta(0.07)
                            }
                            LinhaEvento {
                                Layout.fillWidth: true
                                Layout.topMargin: Math.round(janela.gu * 0.45)
                                Layout.bottomMargin: Math.round(janela.gu * 0.45)
                                evento: modelData
                            }
                        }
                    }
                }
            }
        }
    }
}
