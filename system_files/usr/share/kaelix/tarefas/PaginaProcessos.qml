// Processos, como no Gerenciador de tarefas do Windows: os apps abertos, o que
// roda em segundo plano e o que é do sistema, com CPU, memória e disco de cada
// um. Clicar no título de uma coluna ordena por ela. Os apps com mais de um
// processo abrem com a setinha.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

FocusScope {
    id: pagina

    readonly property string busca: tarefas.busca
    property string ordem: "nome"
    property bool crescente: true
    property var abertos: ({})
    property string escolhido: ""
    property var linhaEscolhida: null

    readonly property var d: tarefas.dados
    readonly property int colNum: Math.round(tarefas.gu * 6)
    // Espaço da barra de rolagem, para os números não ficarem embaixo dela.
    readonly property int margemDireita: Math.round(tarefas.gu * 0.7)

    focus: true

    function combina(g) {
        if (busca.length === 0)
            return true;
        var b = tarefas.simples(busca);
        if (tarefas.simples(g.nome).indexOf(b) !== -1)
            return true;
        for (var i = 0; i < g.procs.length; i++) {
            var p = g.procs[i];
            if (tarefas.simples(p.nome).indexOf(b) !== -1 || tarefas.simples(p.exe).indexOf(b) !== -1 || String(p.pid) === busca)
                return true;
        }
        return false;
    }

    function comparar(a, b) {
        var r;
        if (ordem === "nome")
            r = String(a.nome).localeCompare(String(b.nome), tarefas.local.name);
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
            ["app", tarefas.t("Apps", "Apps")],
            ["fundo", tarefas.t("Em segundo plano", "Background processes")],
            ["sistema", tarefas.t("Do sistema", "System processes")]
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
                var aberto = g.n > 1 && (abertos[g.id] === true || (busca.length > 0 && !tarefas.simples(g.nome).includes(tarefas.simples(busca))));
                var alvo = g.unidade && g.id === g.unidade ? "unidade:" + g.unidade : String(g.procs[0].pid);
                linhas.push(linha({ tipo: "grupo", chave: "g:" + g.id, nome: g.nome, icone: g.icone || "", n: g.n,
                                    cpu: g.cpu, mem: g.mem, disco: g.disco, acao: g.acao, motivo: g.motivo || "",
                                    alvo: alvo, aberto: aberto, pid: g.n === 1 ? g.procs[0].pid : 0 }));
                if (aberto) {
                    var procs = g.procs.slice().sort(pagina.comparar);
                    for (var j = 0; j < procs.length; j++) {
                        var p = procs[j];
                        linhas.push(linha({ tipo: "proc", chave: "p:" + p.pid, nome: p.nome, n: 1, cpu: p.cpu, mem: p.mem,
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
            kaelix.rodar("acao", tarefas.comando(["reiniciar-barra"]));
            return;
        }
        kaelix.rodar("acao", tarefas.comando([naHora ? "forcar" : "finalizar", l.alvo]));
        escolhido = "";
    }

    function textoBotao(l) {
        if (l && l.acao === "reiniciar")
            return tarefas.t("Reiniciar", "Restart");
        return tarefas.t("Finalizar tarefa", "End task");
    }

    function motivoTexto(l) {
        if (!l)
            return tarefas.t("Escolha um app ou processo na lista.", "Select an app or process in the list.");
        if (l.motivo === "outro-usuario")
            return tarefas.t("É do sistema: só o administrador pode encerrar.", "Belongs to the system: only an administrator can end it.");
        if (l.motivo === "sessao" || l.acao === "nenhuma")
            return tarefas.t("Faz parte da sua sessão: encerrar fecharia tudo.", "Part of your session: ending it would close everything.");
        if (l.acao === "reiniciar")
            return tarefas.t("Reinicia a barra e a área de trabalho, sem fechar os apps.", "Restarts the bar and desktop without closing apps.");
        return "";
    }

    Connections {
        target: tarefas
        function onTiqueChanged() {
            pagina.atualizar();
        }
    }
    Component.onCompleted: atualizar()
    onBuscaChanged: atualizar()

    Keys.onDeletePressed: finalizar(false)
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
            Layout.preferredHeight: Math.round(tarefas.gu * 3)
            Layout.leftMargin: Math.round(tarefas.gu * 1.1)
            Layout.rightMargin: Math.round(tarefas.gu * 0.6)
            spacing: Math.round(tarefas.gu * 0.2)

            Texto {
                Layout.fillWidth: true
                text: tarefas.t("Processos", "Processes")
                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 2
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Botao {
                texto: tarefas.t("Nova tarefa", "Run new task")
                icone: "kaelix-nova-tarefa-symbolic"
                dica: tarefas.t("Abre a busca do sistema para rodar um app ou comando", "Opens the system search to run an app or command")
                onClicado: kaelix.soltar(["krunner"])
            }
            Botao {
                texto: pagina.textoBotao(pagina.linhaEscolhida)
                icone: pagina.linhaEscolhida && pagina.linhaEscolhida.acao === "reiniciar" ? "kaelix-recarregar-symbolic" : "kaelix-parar-symbolic"
                ativo: pagina.linhaEscolhida !== null && pagina.linhaEscolhida.acao !== "nenhuma"
                dica: pagina.motivoTexto(pagina.linhaEscolhida)
                onClicado: pagina.finalizar(false)
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: tarefas.tinta(0.07)
        }

        // Títulos das colunas, com o total em cima (como no Windows).
        Item {
            Layout.fillWidth: true
            implicitHeight: Math.round(tarefas.gu * 2.9)

            RowLayout {
                anchors.fill: parent
                anchors.rightMargin: pagina.margemDireita
                spacing: 0

                Coluna {
                    Layout.fillWidth: true
                    titulo: tarefas.t("Nome", "Name")
                    alinhamento: Text.AlignLeft
                    separador: false
                    coluna: "nome"
                }
                Coluna {
                    Layout.preferredWidth: pagina.colNum
                    titulo: "CPU"
                    total: pagina.d ? tarefas.porcento(pagina.d.cpu.uso) : ""
                    coluna: "cpu"
                }
                Coluna {
                    Layout.preferredWidth: pagina.colNum
                    titulo: tarefas.t("Memória", "Memory")
                    total: pagina.d && pagina.d.memoria.total > 0 ? tarefas.porcento(100 * pagina.d.memoria.usada / pagina.d.memoria.total) : ""
                    coluna: "mem"
                }
                Coluna {
                    Layout.preferredWidth: pagina.colNum
                    titulo: tarefas.t("Disco", "Disk")
                    total: {
                        if (!pagina.d)
                            return "";
                        var maior = 0;
                        for (var i = 0; i < pagina.d.discos.length; i++)
                            maior = Math.max(maior, pagina.d.discos[i].ativo);
                        return tarefas.porcento(maior);
                    }
                    coluna: "disco"
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: tarefas.tinta(0.07)
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
                    color: tarefas.tinta(0.07)
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
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {
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
                    onMenuPedido: {
                        pagina.escolher(linhaDel.model.chave);
                        menu.popup();
                    }
                }

                Texto {
                    anchors.centerIn: parent
                    visible: pagina.d !== null && modelo.count === 0
                    text: tarefas.t("Nada encontrado para “%1”.", "Nothing found for “%1”.").arg(pagina.busca)
                    opacity: 0.6
                }
                QQC2.BusyIndicator {
                    anchors.centerIn: parent
                    visible: pagina.d === null
                    running: visible
                }
            }
        }
    }

    QQC2.Menu {
        id: menu

        QQC2.MenuItem {
            text: pagina.textoBotao(pagina.linhaEscolhida)
            enabled: pagina.linhaEscolhida !== null && pagina.linhaEscolhida.acao !== "nenhuma"
            onTriggered: pagina.finalizar(false)
        }
        QQC2.MenuItem {
            text: tarefas.t("Forçar fechar (se travou)", "Force close (if frozen)")
            enabled: pagina.linhaEscolhida !== null && pagina.linhaEscolhida.acao === "finalizar"
            onTriggered: pagina.finalizar(true)
        }
        QQC2.MenuSeparator {}
        QQC2.MenuItem {
            text: pagina.linhaEscolhida && pagina.linhaEscolhida.aberto ? tarefas.t("Recolher", "Collapse") : tarefas.t("Mostrar os processos", "Show processes")
            enabled: pagina.linhaEscolhida !== null && pagina.linhaEscolhida.tipo === "grupo" && pagina.linhaEscolhida.n > 1
            onTriggered: pagina.alternar(pagina.linhaEscolhida.chave.substring(2))
        }
    }
}
