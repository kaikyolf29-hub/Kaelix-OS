// Processos, como no Gerenciador de tarefas do Windows: os apps abertos, o que
// roda em segundo plano e o que é do sistema, com CPU, memória e disco de cada
// um. Clicar no título de uma coluna ordena por ela. Os apps com mais de um
// processo abrem com a setinha. "Finalizar tarefa" pergunta uma vez (o botão fica
// vermelho com o nome), gira enquanto fecha e mostra "Finalizado ✓".
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

FocusScope {
    id: pagina

    readonly property string busca: janela.busca
    property string ordem: "nome"
    property bool crescente: true
    property var abertos: ({})
    property string escolhido: ""
    property var linhaEscolhida: null
    // O botão de finalizar: "" (normal), "pergunta", "carregando" ou "feito".
    property string fase: ""
    property var alvoFase: null

    readonly property var d: janela.dados
    readonly property int colNum: Math.round(janela.gu * 6)
    // Espaço da barra de rolagem, para os números não ficarem embaixo dela.
    readonly property int margemDireita: Math.round(janela.gu * 0.7)

    focus: true

    function combina(g) {
        if (busca.length === 0)
            return true;
        var b = janela.simples(busca);
        if (janela.simples(g.nome).indexOf(b) !== -1)
            return true;
        for (var i = 0; i < g.procs.length; i++) {
            var p = g.procs[i];
            if (janela.simples(p.nome).indexOf(b) !== -1 || janela.simples(p.exe).indexOf(b) !== -1 || String(p.pid) === busca)
                return true;
        }
        return false;
    }

    function comparar(a, b) {
        var r;
        if (ordem === "nome")
            r = String(a.nome).localeCompare(String(b.nome), janela.local.name);
        else
            r = (a[ordem] || 0) - (b[ordem] || 0);
        if (r === 0)
            r = String(a.nome).localeCompare(String(b.nome));
        return crescente ? r : -r;
    }

    function linha(campos) {
        // Todas as linhas têm os mesmos campos, com o mesmo tipo (o ListModel pede).
        var base = { tipo: "", chave: "", nome: "", icone: "", n: 0, cpu: 0, mem: 0, disco: 0, acao: "nenhuma",
                     motivo: "", alvo: "", aberto: false, nivel: 0, pid: 0 };
        for (var k in campos)
            base[k] = campos[k];
        return base;
    }

    function montar() {
        if (!d)
            return [];
        var secoes = [
            ["app", janela.t("Apps", "Apps")],
            ["fundo", janela.t("Em segundo plano", "Background processes")],
            ["sistema", janela.t("Do sistema", "System processes")]
        ];
        var linhas = [];
        for (var s = 0; s < secoes.length; s++) {
            var grupos = d.grupos.filter(g => g.tipo === secoes[s][0] && pagina.combina(g));
            if (grupos.length === 0)
                continue;
            grupos.sort(pagina.comparar);
            linhas.push(linha({ tipo: "secao", chave: "s:" + secoes[s][0], nome: secoes[s][1], n: grupos.length }));
            for (var i = 0; i < grupos.length; i++) {
                var g = grupos[i];
                var aberto = g.n > 1 && (abertos[g.id] === true || (busca.length > 0 && !janela.simples(g.nome).includes(janela.simples(busca))));
                var alvo = g.unidade && g.id === g.unidade ? "unidade:" + g.unidade : String(g.procs[0].pid);
                linhas.push(linha({ tipo: "grupo", chave: "g:" + g.id, nome: g.nome, icone: g.icone || "", n: g.n,
                                    cpu: g.cpu, mem: g.mem, disco: g.disco, acao: g.acao, motivo: g.motivo || "",
                                    alvo: alvo, aberto: aberto, pid: g.n === 1 ? g.procs[0].pid : 0 }));
                if (aberto) {
                    var procs = g.procs.slice().sort(pagina.comparar);
                    for (var j = 0; j < procs.length; j++) {
                        var p = procs[j];
                        // Como no Windows, cada processo do app aparece com a logo: a dele mesmo
                        // (se for outro programa com .desktop) ou a do app.
                        linhas.push(linha({ tipo: "proc", chave: "p:" + p.pid, nome: p.nome, icone: p.icone || g.icone || "",
                                            n: 1, cpu: p.cpu, mem: p.mem,
                                            disco: p.disco, acao: p.acao, alvo: String(p.pid), nivel: 1, pid: p.pid }));
                    }
                }
            }
        }
        return linhas;
    }

    // Atualiza a lista no lugar (sem recriar), para não pular nem piscar.
    function atualizar() {
        var novas = montar();
        for (var i = 0; i < novas.length; i++) {
            if (i < modelo.count)
                modelo.set(i, novas[i]);
            else
                modelo.append(novas[i]);
        }
        if (modelo.count > novas.length)
            modelo.remove(novas.length, modelo.count - novas.length);
        linhaEscolhida = null;
        for (var j = 0; j < novas.length; j++) {
            if (novas[j].chave === escolhido) {
                linhaEscolhida = novas[j];
                lista.currentIndex = j;
                break;
            }
        }
        if (!linhaEscolhida)
            lista.currentIndex = -1;
    }

    function ordenar(coluna) {
        if (ordem === coluna)
            crescente = !crescente;
        else {
            ordem = coluna;
            crescente = coluna === "nome";
        }
        atualizar();
    }

    function alternar(id) {
        var a = abertos;
        a[id] = !(a[id] === true);
        abertos = a;
        atualizar();
    }

    function escolher(chave) {
        // Escolheu outra linha no meio da pergunta: a pergunta some.
        if (fase === "pergunta" && alvoFase && alvoFase.chave !== chave)
            fase = "";
        escolhido = chave;
        atualizar();
    }

    function mover(passo) {
        var i = lista.currentIndex;
        for (var n = 0; n < modelo.count; n++) {
            i += passo;
            if (i < 0 || i >= modelo.count)
                return;
            if (modelo.get(i).tipo !== "secao") {
                escolher(modelo.get(i).chave);
                lista.positionViewAtIndex(i, ListView.Contain);
                return;
            }
        }
    }

    function finalizar(naHora) {
        var l = linhaEscolhida;
        if (!l || l.acao === "nenhuma")
            return;
        if (l.acao === "reiniciar") {
            matsu.rodar("acao", janela.comando(["reiniciar-barra"]));
            return;
        }
        matsu.rodar("acao", janela.comando([naHora ? "forcar" : "finalizar", l.alvo]));
        escolhido = "";
    }

    // Primeiro clique: pergunta; segundo: fecha. Delete faz o mesmo.
    function pedirFinalizar() {
        if (fase === "pergunta") {
            confirmar();
            return;
        }
        var l = linhaEscolhida;
        if (fase !== "" || !l || l.acao === "nenhuma")
            return;
        alvoFase = l;
        fase = "pergunta";
        voltaPergunta.restart();
    }
    function confirmar() {
        voltaPergunta.stop();
        var l = alvoFase;
        if (!l)
            return;
        var antes = linhaEscolhida;
        linhaEscolhida = l;
        fase = "carregando";
        finalizar(false);
        if (l.acao === "reiniciar")
            linhaEscolhida = antes;
    }
    function forcar() {
        var l = linhaEscolhida;
        if (!l || l.acao !== "finalizar" || fase === "carregando")
            return;
        voltaPergunta.stop();
        alvoFase = l;
        fase = "carregando";
        finalizar(true);
    }
    function textoPergunta(l) {
        if (!l)
            return "";
        var nome = l.nome.length > 22 ? l.nome.substring(0, 21) + "…" : l.nome;
        if (l.acao === "reiniciar")
            return janela.t("Reiniciar a barra?", "Restart the bar?");
        return janela.t("Finalizar “" + nome + "”?", "End “" + nome + "”?");
    }
    Timer {
        id: voltaPergunta
        interval: 5000
        onTriggered: if (pagina.fase === "pergunta") pagina.fase = ""
    }
    Timer {
        id: voltaFeito
        interval: 1800
        onTriggered: pagina.fase = ""
    }
    Connections {
        target: matsu
        function onPronto(chave, saida, codigo) {
            if (chave === "acao" && pagina.fase === "carregando") {
                pagina.fase = "feito";
                voltaFeito.restart();
            }
        }
    }

    function textoBotao(l) {
        if (l && l.acao === "reiniciar")
            return janela.t("Reiniciar", "Restart");
        return janela.t("Finalizar tarefa", "End task");
    }

    function motivoTexto(l) {
        if (!l)
            return janela.t("Escolha um app ou processo na lista.", "Select an app or process in the list.");
        if (l.motivo === "outro-usuario")
            return janela.t("É do sistema: só o administrador pode encerrar.", "Belongs to the system: only an administrator can end it.");
        if (l.motivo === "sessao" || l.acao === "nenhuma")
            return janela.t("Faz parte da sua sessão: encerrar fecharia tudo.", "Part of your session: ending it would close everything.");
        if (l.acao === "reiniciar")
            return janela.t("Reinicia a barra e a área de trabalho, sem fechar os apps.", "Restarts the bar and desktop without closing apps.");
        return "";
    }

    Connections {
        target: janela
        function onTiqueChanged() {
            pagina.atualizar();
        }
    }
    Component.onCompleted: atualizar()
    onBuscaChanged: atualizar()

    Keys.onDeletePressed: pedirFinalizar()
    Keys.onEscapePressed: (e) => {
        if (fase === "pergunta") {
            fase = "";
            e.accepted = true;
        } else {
            e.accepted = false;
        }
    }
    Keys.onUpPressed: mover(-1)
    Keys.onDownPressed: mover(1)
    Keys.onReturnPressed: {
        if (linhaEscolhida && linhaEscolhida.tipo === "grupo" && linhaEscolhida.n > 1)
            alternar(linhaEscolhida.chave.substring(2));
    }

    ListModel {
        id: modelo
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Título da página e os botões, como a barra do Windows 11.
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(janela.gu * 3)
            Layout.leftMargin: Math.round(janela.gu * 1.1)
            Layout.rightMargin: Math.round(janela.gu * 0.6)
            spacing: Math.round(janela.gu * 0.2)

            Texto {
                Layout.fillWidth: true
                text: janela.t("Processos", "Processes")
                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 2
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Botao {
                texto: janela.t("Nova tarefa", "Run new task")
                icone: "matsu-nova-tarefa-symbolic"
                dica: janela.t("Abre a busca do sistema para rodar um app ou comando", "Opens the system search to run an app or command")
                onClicado: matsu.soltar(["krunner"])
            }
            // Normal, o botão de vidro; perguntando, fechando ou pronto, o botão cheio
            // (vermelho, a rodinha, verde com o visto). A largura desliza entre eles.
            Item {
                id: lugarFinalizar
                readonly property bool emAcao: pagina.fase !== ""
                Layout.preferredWidth: emAcao ? destaqueFinalizar.implicitWidth : botaoFinalizar.implicitWidth
                Layout.preferredHeight: Math.max(botaoFinalizar.implicitHeight, destaqueFinalizar.implicitHeight)
                Behavior on Layout.preferredWidth {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
                Botao {
                    id: botaoFinalizar
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: lugarFinalizar.emAcao ? 0 : 1
                    visible: opacity > 0
                    texto: pagina.textoBotao(pagina.linhaEscolhida)
                    icone: pagina.linhaEscolhida && pagina.linhaEscolhida.acao === "reiniciar" ? "matsu-recarregar-symbolic" : "matsu-parar-symbolic"
                    ativo: !lugarFinalizar.emAcao && pagina.linhaEscolhida !== null && pagina.linhaEscolhida.acao !== "nenhuma"
                    dica: pagina.motivoTexto(pagina.linhaEscolhida)
                    onClicado: pagina.pedirFinalizar()
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 160
                        }
                    }
                }
                BotaoDestaque {
                    id: destaqueFinalizar
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: lugarFinalizar.emAcao ? 1 : 0
                    visible: opacity > 0
                    perigo: pagina.alvoFase !== null && pagina.alvoFase.acao !== "reiniciar"
                    estado: pagina.fase === "carregando" ? "carregando" : (pagina.fase === "feito" ? "feito" : "")
                    texto: pagina.textoPergunta(pagina.alvoFase)
                    textoFeito: pagina.alvoFase && pagina.alvoFase.acao === "reiniciar" ? janela.t("Reiniciada", "Restarted") : janela.t("Finalizado", "Ended")
                    onClicado: pagina.confirmar()
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 160
                        }
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: janela.tinta(0.07)
        }

        // Títulos das colunas, com o total em cima (como no Windows).
        Item {
            Layout.fillWidth: true
            implicitHeight: Math.round(janela.gu * 2.9)

            RowLayout {
                anchors.fill: parent
                anchors.rightMargin: pagina.margemDireita
                spacing: 0

                Coluna {
                    Layout.fillWidth: true
                    titulo: janela.t("Nome", "Name")
                    alinhamento: Text.AlignLeft
                    separador: false
                    coluna: "nome"
                }
                Coluna {
                    Layout.preferredWidth: pagina.colNum
                    titulo: "CPU"
                    total: pagina.d ? janela.porcento(pagina.d.cpu.uso) : ""
                    coluna: "cpu"
                }
                Coluna {
                    Layout.preferredWidth: pagina.colNum
                    titulo: janela.t("Memória", "Memory")
                    total: pagina.d && pagina.d.memoria.total > 0 ? janela.porcento(100 * pagina.d.memoria.usada / pagina.d.memoria.total) : ""
                    coluna: "mem"
                }
                Coluna {
                    Layout.preferredWidth: pagina.colNum
                    titulo: janela.t("Disco", "Disk")
                    total: {
                        if (!pagina.d)
                            return "";
                        var maior = 0;
                        for (var i = 0; i < pagina.d.discos.length; i++)
                            maior = Math.max(maior, pagina.d.discos[i].ativo);
                        return janela.porcento(maior);
                    }
                    coluna: "disco"
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: janela.tinta(0.07)
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // As linhas finas entre as colunas descem pela lista toda.
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    x: lista.width - pagina.margemDireita - (3 - index) * pagina.colNum
                    width: 1
                    height: parent.height
                    color: janela.tinta(0.07)
                    z: 1
                }
            }

            ListView {
                id: lista
                anchors.fill: parent
                clip: true
                model: modelo
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: -1
                highlightFollowsCurrentItem: false
                QQC2.ScrollBar.vertical: BarraRolagem {
                    id: rolagem
                }

                delegate: LinhaProcesso {
                    id: linhaDel
                    width: ListView.view.width - pagina.margemDireita
                    colNum: pagina.colNum
                    selecionada: linhaDel.model.chave === pagina.escolhido
                    memTotal: pagina.d ? pagina.d.memoria.total : 1
                    onClicada: pagina.escolher(linhaDel.model.chave)
                    onAlternada: pagina.alternar(linhaDel.model.chave.substring(2))
                    onMenuPedido: (x, y) => {
                        pagina.escolher(linhaDel.model.chave);
                        menu.abrirEm(linhaDel, x, y);
                    }
                }

                Texto {
                    anchors.centerIn: parent
                    visible: pagina.d !== null && modelo.count === 0
                    text: janela.t("Nada encontrado para “%1”.", "Nothing found for “%1”.").arg(pagina.busca)
                    opacity: 0.6
                }
                Girando {
                    anchors.centerIn: parent
                    width: Math.round(janela.gu * 1.6)
                    visible: pagina.d === null
                }
            }
        }
    }

    // O menu do botão direito, com o fundo dos balões do Matsu (setas e Enter andam nele).
    MenuMatsu {
        id: menu
        readonly property var l: pagina.linhaEscolhida
        itens: [
            { id: "finalizar", nome: pagina.textoBotao(l), icone: l && l.acao === "reiniciar" ? "matsu-recarregar-symbolic" : "matsu-parar-symbolic",
              ativo: l !== null && l.acao !== "nenhuma" },
            { id: "forcar", nome: janela.t("Forçar fechar (se travou)", "Force close (if frozen)"), icone: "matsu-raio-symbolic",
              perigo: true, ativo: l !== null && l.acao === "finalizar" },
            { id: "alternar", nome: l && l.aberto ? janela.t("Recolher", "Collapse") : janela.t("Mostrar os processos", "Show processes"),
              icone: "matsu-processos-symbolic", separador: true, ativo: l !== null && l.tipo === "grupo" && l.n > 1 }
        ]
        onEscolhido: (id) => {
            if (id === "finalizar")
                pagina.pedirFinalizar();
            else if (id === "forcar")
                pagina.forcar();
            else if (id === "alternar" && pagina.linhaEscolhida)
                pagina.alternar(pagina.linhaEscolhida.chave.substring(2));
        }
    }
}
