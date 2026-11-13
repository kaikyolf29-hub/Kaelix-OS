// Escudo: a proteção em tempo real (ligar, pausar por um tempo), as verificações
// manuais (rápida, completa, uma pasta ou arquivo), a lista de ameaças do ClamAV,
// os ajustes e o que fica de fora (e por quê).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: pagina

    readonly property int margem: Math.round(janela.gu * 1.6)
    readonly property string geral: janela.geral
    readonly property var esc: janela.escudo
    readonly property var lista: janela.lista
    readonly property var ajustes: janela.est ? janela.est.ajustes : ({})
    readonly property bool instalado: janela.est ? janela.est.instalado : true
    readonly property bool vigiando: geral === "protegido" || geral === "atencao"
    // A chave fica ligada com o escudo vigiando (ou esperando a lista); pausado ou desligado, apagada.
    readonly property bool chaveLigada: janela.ligado && !janela.pausado && instalado
    property string escolha: janela.verTipo === "caminho" ? "escolher" : janela.verTipo
    readonly property string fase: janela.verRodando ? "rodando" : (janela.verFase === "fim" || janela.verFase === "erro" ? janela.verFase : "")

    function caminhoDe(url) {
        return decodeURIComponent(String(url).replace(/^file:\/\//, ""));
    }
    function pastasVigiadas() {
        var p = esc ? esc.pastas.map(function (x) { return x.nome; }) : [];
        return p.join(janela.t(" e ", " and "));
    }

    FolderDialog {
        id: escolherPasta
        title: janela.t("Escolher a pasta para verificar", "Choose a folder to scan")
        currentFolder: "file://" + matsu.pasta("casa")
        onAccepted: janela.verificar("caminho", [pagina.caminhoDe(selectedFolder)])
    }
    FileDialog {
        id: escolherArquivo
        title: janela.t("Escolher o arquivo para verificar", "Choose a file to scan")
        currentFolder: "file://" + matsu.pasta("downloads")
        onAccepted: janela.verificar("caminho", [pagina.caminhoDe(selectedFile)])
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

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Texto {
                    text: janela.t("Escudo", "Shield")
                    font.pixelSize: Math.round(janela.gu * 1.3)
                    font.weight: Font.DemiBold
                }
                Texto {
                    Layout.fillWidth: true
                    text: janela.t("O antivírus do Matsu (ClamAV): confere os arquivos que chegam e os que você pedir.",
                                   "Matsu's antivirus (ClamAV): checks incoming files and the ones you ask for.")
                    opacity: 0.65
                    wrapMode: Text.WordWrap
                }
            }

            // ----- a proteção em tempo real -----
            Cartao {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(janela.gu * 0.4)
                implicitHeight: colunaTempoReal.implicitHeight + Math.round(janela.gu * 2.2)

                ColumnLayout {
                    id: colunaTempoReal
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Math.round(janela.gu * 1.1)
                    spacing: Math.round(janela.gu * 0.8)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Math.round(janela.gu * 0.9)

                        IconeRedondo {
                            Layout.alignment: Qt.AlignTop
                            implicitWidth: Math.round(janela.gu * 2.8)
                            icone: janela.pausado ? janela.ic("pausa") : (!janela.ligado ? janela.ic("escudo-desligado") : "matsu-escudo-symbolic")
                            cor: pagina.geral === "atencao" ? janela.verde : janela.corEstado(pagina.geral)
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Texto {
                                Layout.fillWidth: true
                                text: janela.t("Proteção em tempo real", "Real-time protection")
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Texto {
                                Layout.fillWidth: true
                                text: {
                                    switch (pagina.geral) {
                                    case "protegido":
                                    case "atencao":
                                        return janela.t("Ligada. Confere cada arquivo novo em ", "On. Checks every new file in ") + pagina.pastasVigiadas() + ".";
                                    case "pausado":
                                        return pagina.esc && pagina.esc.pausaReiniciar ? janela.t("Pausada até você reiniciar o computador.", "Paused until you restart the computer.")
                                                                                       : janela.t("Pausada. Volta sozinha às ", "Paused. Comes back by itself at ") + janela.hora(pagina.esc ? pagina.esc.pausaAte : 0) + ".";
                                    case "desligado":
                                        return janela.t("Desligada. Os arquivos novos não são conferidos.", "Off. New files aren't checked.");
                                    case "parado":
                                        return janela.t("O serviço do escudo não está rodando agora.", "The shield service isn't running right now.");
                                    case "baixando":
                                    case "sem-lista":
                                        return janela.t("Ligada, esperando a lista de ameaças para começar.", "On, waiting for the threat list to start.");
                                    case "indisponivel":
                                        return janela.t("O ClamAV não está instalado neste computador.", "ClamAV isn't installed on this computer.");
                                    default:
                                        return "";
                                    }
                                }
                                opacity: 0.68
                                wrapMode: Text.WordWrap
                            }
                        }
                        Chave {
                            id: chave
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 2
                            visible: pagina.instalado
                            nome: janela.t("Proteção em tempo real", "Real-time protection")
                            ligada: pagina.chaveLigada
                            onTrocada: (quer) => {
                                if (quer) {
                                    if (janela.pausado)
                                        janela.retomar();
                                    else
                                        janela.ajuste("ligado", true);
                                } else {
                                    // Desligar pergunta por quanto tempo (a pausa volta sozinha).
                                    janela.menuPausa.abrirEm(chave, chave.width - janela.menuPausa.width, chave.height + 4);
                                }
                            }
                        }
                    }

                    // A contagem da pausa, com os números rolando.
                    Rectangle {
                        Layout.fillWidth: true
                        visible: janela.pausado
                        implicitHeight: linhaPausa.implicitHeight + Math.round(janela.gu * 1.0)
                        radius: Math.round(janela.gu * 0.45)
                        color: Qt.rgba(janela.ambar.r, janela.ambar.g, janela.ambar.b, janela.escuro ? 0.12 : 0.1)
                        RowLayout {
                            id: linhaPausa
                            anchors.fill: parent
                            anchors.leftMargin: Math.round(janela.gu * 0.9)
                            anchors.rightMargin: Math.round(janela.gu * 0.5)
                            spacing: Math.round(janela.gu * 0.7)
                            ColumnLayout {
                                spacing: 0
                                Texto {
                                    text: pagina.esc && pagina.esc.pausaReiniciar ? janela.t("Volta ao reiniciar", "Back after restart") : janela.t("Volta em", "Back in")
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    opacity: 0.7
                                }
                                NumeroRolante {
                                    visible: !(pagina.esc && pagina.esc.pausaReiniciar)
                                    texto: janela.falta(pagina.esc ? pagina.esc.pausaAte : 0)
                                    font.pixelSize: Math.round(janela.gu * 1.6)
                                    font.weight: Font.DemiBold
                                    font.features: { "tnum": 1 }
                                    cor: janela.ambar
                                }
                                Texto {
                                    readonly property int n: pagina.esc ? pagina.esc.pendentes : 0
                                    visible: n > 0
                                    text: (n === 1 ? janela.t("1 arquivo esperando para ser conferido", "1 file waiting to be checked") : janela.t(n + " arquivos esperando para serem conferidos", n + " files waiting to be checked"))
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    opacity: 0.7
                                }
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            BotaoDestaque {
                                texto: janela.t("Voltar agora", "Resume now")
                                estado: janela.ocupado["retomar"] ? "carregando" : ""
                                onClicado: janela.retomar()
                            }
                        }
                    }

                    // O que o escudo está fazendo agora.
                    Flow {
                        Layout.fillWidth: true
                        visible: pagina.esc && pagina.esc.servico && !janela.pausado && janela.ligado
                        spacing: Math.round(janela.gu * 0.45)
                        Repeater {
                            model: {
                                var e = pagina.esc;
                                if (!e)
                                    return [];
                                var l = [];
                                l.push({ icone: janela.ic("arquivo"), texto: janela.t(janela.num(e.verificados) + " arquivos conferidos desde que você entrou", janela.num(e.verificados) + " files checked since you signed in") });
                                l.push({ icone: janela.ic("pendrive"), texto: pagina.ajustes.pendrive_auto ? janela.t("Pendrives: verifica sozinho", "USB drives: checks by itself")
                                                                                                       : janela.t("Pendrives: pergunta antes", "USB drives: asks first") });
                                if (e.jogo && e.fila > 0)
                                    l.push({ icone: "matsu-jogos-symbolic", texto: janela.t(e.fila + " na fila até o jogo fechar", e.fila + " queued until the game closes") });
                                else if (e.fila > 0)
                                    l.push({ icone: "matsu-relogio-symbolic", texto: (e.fila === 1 ? janela.t("Conferindo 1 arquivo", "Checking 1 file") : janela.t("Conferindo " + e.fila + " arquivos", "Checking " + e.fila + " files")) });
                                l.push({ icone: janela.ic("chip"), texto: e.clamd === "ligado" ? janela.t("Motor acordado", "Engine awake")
                                                                                              : janela.t("Motor dormindo (acorda quando precisa)", "Engine asleep (wakes when needed)") });
                                return l;
                            }
                            Rectangle {
                                required property var modelData
                                width: linhaChip.implicitWidth + Math.round(janela.gu * 1.1)
                                height: Math.round(janela.gu * 1.6)
                                radius: height / 2
                                color: janela.tinta(janela.escuro ? 0.06 : 0.045)
                                Row {
                                    id: linhaChip
                                    anchors.centerIn: parent
                                    spacing: Math.round(janela.gu * 0.35)
                                    Kirigami.Icon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.round(janela.gu * 0.85)
                                        height: width
                                        source: modelData.icone
                                        isMask: true
                                        color: janela.frente
                                        opacity: 0.7
                                    }
                                    Texto {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.texto
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        opacity: 0.8
                                    }
                                }
                            }
                        }
                    }
                    Botao {
                        visible: pagina.geral === "parado"
                        texto: janela.t("Ligar o escudo de novo", "Start the shield again")
                        icone: "matsu-recarregar-symbolic"
                        onClicado: janela.religarEscudo()
                    }
                }
            }

            // ----- verificar agora -----
            Secao {
                titulo: janela.t("Verificar agora", "Scan now")
            }
            Cartao {
                id: cartaoVer
                Layout.fillWidth: true
                implicitHeight: (pagina.fase === "rodando" ? rodando.implicitHeight : pagina.fase === "" ? escolher.implicitHeight : resultado.implicitHeight)
                                + Math.round(janela.gu * 2.2)
                clip: true
                Behavior on implicitHeight {
                    NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                }

                // Escolher o tipo e começar.
                ColumnLayout {
                    id: escolher
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Math.round(janela.gu * 1.1)
                    spacing: Math.round(janela.gu * 0.8)
                    visible: opacity > 0
                    opacity: pagina.fase === "" ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: 200 }
                    }

                    Seletor {
                        opcoes: [
                            { id: "rapida", nome: janela.t("Rápida", "Quick") },
                            { id: "completa", nome: janela.t("Completa", "Full") },
                            { id: "escolher", nome: janela.t("Pasta ou arquivo", "Folder or file") }
                        ]
                        escolhido: pagina.escolha
                        onEscolher: (id) => pagina.escolha = id
                    }
                    Texto {
                        Layout.fillWidth: true
                        text: ({
                            rapida: janela.t("Downloads, Área de trabalho, os apps que abrem sozinhos e os programas da sua pasta. Leva poucos minutos.",
                                             "Downloads, Desktop, apps that start by themselves and programs in your folder. Takes a few minutes."),
                            completa: janela.t("A sua pasta pessoal inteira e os pendrives, menos os jogos e os caches (veja abaixo). Pode passar de uma hora; dá para usar o computador enquanto isso.",
                                               "Your whole home folder and USB drives, except games and caches (see below). It can take over an hour; you can keep using the computer."),
                            escolher: janela.t("Só a pasta ou o arquivo que você escolher.", "Only the folder or file you choose.")
                        })[pagina.escolha] || ""
                        opacity: 0.7
                        wrapMode: Text.WordWrap
                    }
                    Texto {
                        Layout.fillWidth: true
                        visible: pagina.instalado && pagina.lista && !pagina.lista.presente
                        text: janela.t("A lista de ameaças ainda não chegou: a verificação começa depois que ela baixar.",
                                       "The threat list hasn't arrived yet: scans start after it downloads.")
                        color: janela.ambar
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        wrapMode: Text.WordWrap
                    }
                    RowLayout {
                        spacing: Math.round(janela.gu * 0.5)
                        BotaoDestaque {
                            visible: pagina.escolha !== "escolher"
                            texto: janela.t("Verificar agora", "Scan now")
                            icone: "matsu-escudo-symbolic"
                            ativo: pagina.instalado && !!pagina.lista && pagina.lista.presente
                            onClicado: janela.verificar(pagina.escolha)
                        }
                        BotaoDestaque {
                            visible: pagina.escolha === "escolher"
                            texto: janela.t("Escolher pasta…", "Choose folder…")
                            icone: "matsu-pasta-symbolic"
                            ativo: pagina.instalado && !!pagina.lista && pagina.lista.presente
                            onClicado: escolherPasta.open()
                        }
                        Botao {
                            visible: pagina.escolha === "escolher"
                            texto: janela.t("Escolher arquivo…", "Choose file…")
                            icone: janela.ic("arquivo")
                            ativo: pagina.instalado && !!pagina.lista && pagina.lista.presente
                            onClicado: escolherArquivo.open()
                        }
                    }
                }

                // Rodando: o anel, os números rolando e o arquivo da vez.
                RowLayout {
                    id: rodando
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Math.round(janela.gu * 1.1)
                    spacing: Math.round(janela.gu * 1.3)
                    visible: opacity > 0
                    opacity: pagina.fase === "rodando" ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: 200 }
                    }

                    Item {
                        Layout.preferredWidth: Math.round(janela.gu * 6.2)
                        Layout.preferredHeight: Layout.preferredWidth
                        Anel {
                            anchors.fill: parent
                            visible: janela.verTotal > 0
                            valor: janela.verParte
                            texto: janela.porcento(janela.verParte * 100)
                            cor: janela.verAmeacas.length > 0 ? janela.coral : janela.destaque
                        }
                        Girando {
                            anchors.centerIn: parent
                            width: Math.round(janela.gu * 2.4)
                            height: width
                            visible: janela.verTotal === 0
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Math.round(janela.gu * 0.25)
                        Texto {
                            Layout.fillWidth: true
                            text: janela.verTipo === "rapida" ? janela.t("Verificação rápida", "Quick scan")
                                : janela.verTipo === "completa" ? janela.t("Verificação completa", "Full scan")
                                : janela.t("Verificando ", "Scanning ") + janela.verNome
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        RowLayout {
                            visible: janela.verTotal > 0
                            spacing: 0
                            NumeroRolante {
                                Layout.alignment: Qt.AlignBottom
                                texto: janela.num(janela.verFeitos)
                                font.pixelSize: Math.round(janela.gu * 1.5)
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                            }
                            Texto {
                                Layout.alignment: Qt.AlignBottom
                                Layout.bottomMargin: Math.round(janela.gu * 0.12)
                                text: janela.t(" de ", " of ") + janela.num(janela.verTotal) + janela.t(" arquivos", " files")
                                opacity: 0.7
                            }
                        }
                        Texto {
                            Layout.fillWidth: true
                            text: janela.verFase === "verificando" && janela.verAtual ? janela.verAtual
                                : janela.verFase === "contando" ? janela.t("Contando os arquivos…", "Counting files…")
                                : (janela.verTexto || janela.t("Preparando…", "Getting ready…"))
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.55
                            elide: Text.ElideMiddle
                        }
                        Texto {
                            Layout.fillWidth: true
                            visible: janela.verAmeacas.length > 0
                            text: janela.verAmeacas.length === 1 ? janela.t("1 ameaça encontrada e trancada na quarentena", "1 threat found and quarantined")
                                                                 : janela.t(janela.verAmeacas.length + " ameaças encontradas e trancadas na quarentena", janela.verAmeacas.length + " threats found and quarantined")
                            color: janela.coral
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            wrapMode: Text.WordWrap
                        }
                        Botao {
                            Layout.topMargin: Math.round(janela.gu * 0.2)
                            texto: janela.t("Cancelar", "Cancel")
                            icone: "matsu-fechar-symbolic"
                            onClicado: janela.cancelarVerificacao()
                        }
                    }
                }

                // O resultado (ou o erro).
                ColumnLayout {
                    id: resultado
                    readonly property var fim: janela.verFim
                    readonly property int ameacas: janela.verAmeacas.length
                    readonly property bool cancelada: !!(fim && fim.cancelada)
                    readonly property bool erro: pagina.fase === "erro"
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Math.round(janela.gu * 1.1)
                    spacing: Math.round(janela.gu * 0.8)
                    visible: opacity > 0
                    opacity: pagina.fase === "fim" || pagina.fase === "erro" ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: 240 }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Math.round(janela.gu * 0.9)
                        IconeRedondo {
                            id: iconeResultado
                            Layout.alignment: Qt.AlignTop
                            implicitWidth: Math.round(janela.gu * 2.8)
                            icone: resultado.erro || resultado.ameacas > 0 ? "matsu-alerta-symbolic" : resultado.cancelada ? "matsu-info-symbolic" : "matsu-certo-symbolic"
                            cor: resultado.erro ? janela.ambar : resultado.ameacas > 0 ? janela.coral : resultado.cancelada ? janela.frente : janela.verde
                            scale: resultado.visible ? 1 : 0.6
                            Behavior on scale {
                                NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2 }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Texto {
                                Layout.fillWidth: true
                                text: resultado.erro ? (janela.verSemLista ? janela.t("Falta a lista de ameaças", "The threat list is missing") : janela.t("Não deu para verificar", "Couldn't scan"))
                                    : resultado.ameacas === 1 ? janela.t("1 ameaça foi para a quarentena", "1 threat was quarantined")
                                    : resultado.ameacas > 1 ? janela.t(resultado.ameacas + " ameaças foram para a quarentena", resultado.ameacas + " threats were quarantined")
                                    : resultado.cancelada ? janela.t("Verificação cancelada", "Scan cancelled")
                                    : janela.t("Nada encontrado", "Nothing found")
                                font.pixelSize: Math.round(janela.gu * 1.2)
                                font.weight: Font.DemiBold
                                wrapMode: Text.WordWrap
                            }
                            Texto {
                                Layout.fillWidth: true
                                text: {
                                    if (resultado.erro)
                                        return janela.verErro;
                                    var f = resultado.fim;
                                    if (!f)
                                        return "";
                                    var s = janela.t(janela.num(f.feitos) + " arquivos conferidos", janela.num(f.feitos) + " files checked");
                                    if (!resultado.cancelada)
                                        s += janela.t(" em ", " in ") + janela.tempoCurto(f.duracao || 0);
                                    if (f.pulados > 0)
                                        s += janela.t(" · " + janela.num(f.pulados) + " pulados (grandes demais ou sem acesso)", " · " + janela.num(f.pulados) + " skipped (too big or no access)");
                                    return s + ".";
                                }
                                opacity: 0.7
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                    // As ameaças desta verificação.
                    Repeater {
                        model: janela.verAmeacas
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.leftMargin: Math.round(janela.gu * 3.7)
                            spacing: Math.round(janela.gu * 0.5)
                            Kirigami.Icon {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Layout.preferredWidth
                                source: janela.ic("quarentena")
                                isMask: true
                                color: janela.coral
                            }
                            Texto {
                                Layout.fillWidth: true
                                text: modelData.nome + "  ·  " + modelData.ameaca + (modelData.quarentena ? "" : janela.t(" (não deu para trancar: apague o arquivo)", " (couldn't lock it away: delete the file)"))
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                elide: Text.ElideMiddle
                            }
                        }
                    }
                    RowLayout {
                        Layout.leftMargin: Math.round(janela.gu * 3.7)
                        spacing: Math.round(janela.gu * 0.5)
                        BotaoDestaque {
                            visible: resultado.ameacas > 0
                            texto: janela.t("Ver a quarentena", "View quarantine")
                            onClicado: {
                                janela.abaHistorico = "quarentena";
                                janela.pagina = "historico";
                            }
                        }
                        BotaoDestaque {
                            visible: resultado.erro && janela.verSemLista
                            texto: janela.t("Baixar a lista agora", "Download the list now")
                            estado: janela.ocupado["lista"] ? "carregando" : ""
                            onClicado: janela.atualizarLista()
                        }
                        Botao {
                            texto: janela.t("Verificar de novo", "Scan again")
                            icone: "matsu-recarregar-symbolic"
                            visible: !(resultado.erro && janela.verSemLista)
                            onClicado: janela.verFase = ""
                        }
                        Botao {
                            texto: janela.t("Fechar", "Close")
                            onClicado: janela.verFase = ""
                        }
                    }
                }
            }

            // ----- a lista de ameaças -----
            Secao {
                titulo: janela.t("Lista de ameaças", "Threat list")
                texto: janela.t("O que o ClamAV conhece. Ela se atualiza sozinha a cada 4 horas e espera o jogo fechar.",
                                "What ClamAV knows. It updates by itself every 4 hours and waits for games to close.")
            }
            Cartao {
                Layout.fillWidth: true
                implicitHeight: linhaLista.implicitHeight + Math.round(janela.gu * 1.8)
                RowLayout {
                    id: linhaLista
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Math.round(janela.gu * 1.1)
                    spacing: Math.round(janela.gu * 0.9)

                    IconeRedondo {
                        icone: janela.ic("lista")
                        cor: !pagina.instalado ? janela.corEstado("") : pagina.lista && pagina.lista.presente ? janela.verde : janela.ambar
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Texto {
                            Layout.fillWidth: true
                            readonly property var l: pagina.lista
                            text: !pagina.instalado ? janela.t("Sem o ClamAV, não há lista", "Without ClamAV there's no list")
                                : l && l.baixando ? (l.presente ? janela.t("Atualizando…", "Updating…") : janela.t("Baixando a lista de ameaças…", "Downloading the threat list…"))
                                : l && l.presente ? janela.t(janela.muitos(l.assinaturas) + " ameaças conhecidas", janela.muitos(l.assinaturas) + " known threats")
                                : janela.t("Ainda não baixada", "Not downloaded yet")
                            elide: Text.ElideRight
                        }
                        Texto {
                            Layout.fillWidth: true
                            readonly property var l: pagina.lista
                            visible: text.length > 0
                            text: !l || !pagina.instalado ? ""
                                : l.baixando && !l.presente ? (l.baixado > 0 ? janela.t(janela.bytes(l.baixado) + " de uns " + janela.bytes(l.total), janela.bytes(l.baixado) + " of about " + janela.bytes(l.total))
                                                                             : janela.t("Começando…", "Starting…"))
                                : l.presente ? janela.t("Versão " + janela.num(l.versao) + " · atualizada " + janela.ha(l.data), "Version " + janela.num(l.versao) + " · updated " + janela.ha(l.data))
                                : janela.t("Uns 230 MB, baixados uma vez só; depois vêm só as novidades.", "About 230 MB, downloaded once; then only what's new.")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.62
                            wrapMode: Text.WordWrap
                        }
                        Rectangle {
                            readonly property var l: pagina.lista
                            Layout.fillWidth: true
                            Layout.topMargin: 3
                            visible: !!l && l.baixando && !l.presente
                            implicitHeight: 4
                            radius: 2
                            color: janela.tinta(0.1)
                            Rectangle {
                                height: parent.height
                                radius: 2
                                color: janela.ambar
                                width: parent.width * (parent.l && parent.l.total > 0 ? Math.min(1, parent.l.baixado / parent.l.total) : 0)
                                Behavior on width {
                                    NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
                                }
                            }
                        }
                        Texto {
                            Layout.fillWidth: true
                            visible: !!pagina.lista && pagina.lista.erro
                            text: janela.t("A última atualização não deu certo. Confira a internet; o Matsu tenta de novo sozinho.",
                                           "The last update failed. Check the internet; Matsu tries again by itself.")
                            color: janela.ambar
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            wrapMode: Text.WordWrap
                        }
                    }
                    Botao {
                        visible: pagina.instalado
                        texto: pagina.lista && pagina.lista.presente ? janela.t("Atualizar agora", "Update now") : janela.t("Baixar agora", "Download now")
                        icone: "matsu-recarregar-symbolic"
                        ativo: !(pagina.lista && pagina.lista.baixando) && !janela.ocupado["lista"]
                        dica: pagina.lista && pagina.lista.baixando ? janela.t("Já está baixando", "Already downloading") : ""
                        onClicado: janela.atualizarLista()
                    }
                }
            }

            // ----- ajustes -----
            Secao {
                titulo: janela.t("Ajustes", "Settings")
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                LinhaOpcao {
                    Layout.fillWidth: true
                    ultima: false
                    icone: janela.ic("pendrive")
                    nome: janela.t("Verificar pendrives sozinho", "Scan USB drives by themselves")
                    texto: janela.t("Desligado, o Matsu pergunta antes de verificar cada pendrive que você conecta.",
                                    "When off, Matsu asks before scanning each USB drive you plug in.")
                    Chave {
                        nome: janela.t("Verificar pendrives sozinho", "Scan USB drives by themselves")
                        ligada: !!pagina.ajustes.pendrive_auto
                        onTrocada: (v) => janela.ajuste("pendrive_auto", v)
                    }
                }
                LinhaOpcao {
                    Layout.fillWidth: true
                    primeira: false
                    icone: "matsu-jogos-symbolic"
                    nome: janela.t("Não atrapalhar os jogos", "Don't get in the way of games")
                    texto: janela.t("Com um jogo aberto, os arquivos novos esperam na fila e são conferidos quando o jogo fechar.",
                                    "While a game is open, new files wait in line and are checked when the game closes.")
                    Chave {
                        nome: janela.t("Não atrapalhar os jogos", "Don't get in the way of games")
                        ligada: !!pagina.ajustes.esperar_jogo
                        onTrocada: (v) => janela.ajuste("esperar_jogo", v)
                    }
                }
            }

            // ----- o que fica de fora -----
            Sanfona {
                Layout.topMargin: Math.round(janela.gu * 0.5)
                titulo: janela.t("O que o escudo não confere, e por quê", "What the shield skips, and why")
                icone: "matsu-info-symbolic"
                Repeater {
                    model: [
                        { t: janela.t("Jogos e a Steam", "Games and Steam"),
                          x: janela.t("A Steam confere os arquivos dos jogos sozinha, e verificar gigabytes de jogo deixaria tudo lento. Os instaladores que você baixa continuam conferidos.",
                                      "Steam checks game files itself, and scanning gigabytes of games would slow everything down. Installers you download are still checked.") },
                        { t: janela.t("A pasta /tmp", "The /tmp folder"),
                          x: janela.t("É onde os programas guardam rascunhos que somem sozinhos. Vigiar ali pesaria muito; o que sai de lá para os seus Downloads é conferido.",
                                      "It's where programs keep scratch files that vanish by themselves. Watching it would be heavy; anything that moves from there to Downloads is checked.") },
                        { t: janela.t("Downloads pela metade", "Unfinished downloads"),
                          x: janela.t("Os arquivos .part, .crdownload e .tmp ainda estão chegando. O escudo espera o download terminar e confere o arquivo pronto.",
                                      ".part, .crdownload and .tmp files are still arriving. The shield waits for the download to finish and checks the final file.") },
                        { t: janela.t("Caches e arquivos acima de 400 MB", "Caches and files over 400 MB"),
                          x: janela.t("Caches são cópias que os apps refazem sozinhos. Arquivos enormes (vídeos, imagens de disco) quase nunca levam vírus e deixariam a verificação muito longa.",
                                      "Caches are copies apps rebuild by themselves. Huge files (videos, disk images) rarely carry viruses and would make scans very long.") },
                        { t: janela.t("A pasta do sistema", "The system folder"),
                          x: janela.t("Ela só pode ser lida e vem assinada pelo Matsu: nenhum programa consegue mudá-la. A página Integridade confere isso.",
                                      "It's read-only and signed by Matsu: no program can change it. The Integrity page checks this.") }
                    ]
                    ColumnLayout {
                        required property var modelData
                        width: parent.width
                        spacing: 1
                        Texto {
                            Layout.fillWidth: true
                            text: modelData.t
                            font.weight: Font.DemiBold
                            font.pointSize: Kirigami.Theme.smallFont.pointSize + 0.5
                        }
                        Texto {
                            Layout.fillWidth: true
                            text: modelData.x
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.68
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
