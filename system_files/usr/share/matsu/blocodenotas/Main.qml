// Bloco de notas do Matsu: o editor de arquivos de texto, como o Bloco de Notas do
// Windows 11, com a cara do Matsu. Abas de arquivos no topo do miolo (a aberta com
// o fundo e a borda fina, sem tracinho colorido), barra de ferramentas leve
// (Arquivo, Editar, Exibir), localizar e substituir numa barra que desliza, a
// barra de status embaixo e as abas que voltam como estavam ao abrir de novo.
//
// A janela é a JanelaMatsu (../comum), sem a lista de assuntos à esquerda.
// Aqui fica o estado (as abas, os ajustes, a sessão) e o que mexe em arquivo;
// o desenho está em Pagina.qml e nas peças desta pasta. O ajudante.py diz o
// tamanho, a codificação e o fim de linha de cada arquivo antes de abrir, e lê e
// grava os que não são UTF-8. A lógica sem tela (fim de linha, busca, sessão)
// está em logica.js, testada por tests/test_blocodenotas.py.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import "../comum"
import "logica.js" as Logica

JanelaMatsu {
    id: janela

    readonly property string nomeApp: t("Bloco de notas", "Notepad")
    title: (abaAtual && abaAtual.nome ? abaAtual.nome + " – " : "") + nomeApp
    icone: "org.matsu.blocodenotas"
    iconeReserva: "accessories-text-editor"
    // Um editor não tem assuntos: a lista da esquerda some (ver Pagina.qml).
    paginas: []
    conteudo: Qt.resolvedUrl("Pagina.qml")

    readonly property string ajudante: decodeURIComponent(String(Qt.resolvedUrl("ajudante.py")).replace("file://", ""))
    function comando(args) {
        return ["/usr/bin/python3", "-I", "-S", ajudante].concat(args);
    }
    readonly property string dados: matsu.pasta("dados")
    readonly property string casa: matsu.pasta("casa")
    function ic(nome) {
        return String(Qt.resolvedUrl("icones/" + nome + ".svg"));
    }

    // ----- as abas -----
    // Cada aba: uid (fixo), caminho ("" = sem arquivo), nome, modificado, fim
    // (crlf/lf/cr), codificacao, carregando, e o que o editor usa ao nascer
    // (textoInicial, cursorInicial, rolagemInicial, modificadoInicial).
    property ListModel abas: ListModel {}
    property int atual: 0
    property int proximoUid: 1
    // Muda a cada troca de nome, caminho, fim de linha... (para quem lê abas.get()).
    property int mudancas: 0
    readonly property var abaAtual: {
        mudancas;
        return atual >= 0 && atual < abas.count ? abas.get(atual) : null;
    }
    // O desenho (Pagina.qml), que tem os editores.
    property Item tela: null
    readonly property Item editorAtual: tela ? tela.editorAtual : null
    property bool iniciado: false

    // ----- os ajustes (guardados em ajustes.json) -----
    property bool quebra: true
    property bool barraStatus: true
    property bool numeros: false
    property string fonte: "mono"
    property int tamanho: 11
    property int zoom: 100
    property bool lembrar: true
    property var recentes: []

    readonly property var familias: Qt.fontFamilies()
    readonly property bool temJetBrains: familias.indexOf("JetBrains Mono") >= 0
    readonly property bool temInter: familias.indexOf("Inter") >= 0
    readonly property string familia: fonte === "inter" ? (temInter ? "Inter" : Kirigami.Theme.defaultFont.family)
                                                       : (temJetBrains ? "JetBrains Mono" : "monospace")
    readonly property real tamanhoNaTela: Math.max(4, tamanho * zoom / 100)

    onQuebraChanged: guardarAjustesDepois()
    onBarraStatusChanged: guardarAjustesDepois()
    onNumerosChanged: guardarAjustesDepois()
    onFonteChanged: guardarAjustesDepois()
    onTamanhoChanged: guardarAjustesDepois()
    onZoomChanged: guardarAjustesDepois()
    onLembrarChanged: guardarAjustesDepois()
    onRecentesChanged: guardarAjustesDepois()
    onAtualChanged: {
        mexeu();
        Qt.callLater(focarEditor);
    }

    function guardarAjustesDepois() {
        if (iniciado)
            tempoAjustes.restart();
    }
    function guardarAjustes() {
        matsu.gravar(dados + "/ajustes.json", JSON.stringify({
            quebra: quebra, barraStatus: barraStatus, numeros: numeros, fonte: fonte,
            tamanho: tamanho, zoom: zoom, lembrar: lembrar, recentes: recentes
        }, null, 1));
    }
    function lerAjustes() {
        var a = Logica.lerAjustes(matsu.ler(dados + "/ajustes.json"));
        quebra = a.quebra;
        barraStatus = a.barraStatus;
        numeros = a.numeros;
        fonte = a.fonte;
        tamanho = a.tamanho;
        zoom = a.zoom;
        lembrar = a.lembrar;
        recentes = a.recentes;
    }
    Timer {
        id: tempoAjustes
        interval: 800
        onTriggered: janela.guardarAjustes()
    }

    // ----- a sessão (as abas que voltam ao abrir, como no Windows 11) -----
    // Guardada sozinha pouco depois de cada mudança e ao fechar: mesmo se o
    // computador desligar de repente, o texto não salvo volta.
    function mexeu() {
        if (iniciado)
            tempoSessao.restart();
    }
    Timer {
        id: tempoSessao
        interval: 1500
        onTriggered: janela.guardarSessao()
    }
    function guardarSessao() {
        var lista = [];
        if (lembrar) {
            for (var i = 0; i < abas.count; i++) {
                var a = abas.get(i);
                var ed = editor(i);
                var pronto = ed && ed.pronto;
                lista.push({
                    caminho: a.caminho, nome: a.nome, modificado: a.modificado, fim: a.fim, codificacao: a.codificacao,
                    texto: pronto ? ed.area.text : a.textoInicial,
                    cursor: pronto ? ed.area.cursorPosition : a.cursorInicial,
                    rolagem: pronto ? ed.rolagem.contentY : a.rolagemInicial
                });
            }
        }
        matsu.gravar(dados + "/sessao.json", Logica.montarSessao(lista, atual));
    }
    function restaurarSessao() {
        var s = Logica.lerSessao(matsu.ler(dados + "/sessao.json"));
        for (var i = 0; i < s.abas.length; i++) {
            var a = s.abas[i];
            if (a.texto !== null) {
                criarAba({ caminho: a.caminho, nome: a.nome, fim: a.fim, codificacao: a.codificacao, textoInicial: a.texto,
                           modificadoInicial: a.modificado, modificado: a.modificado, cursorInicial: a.cursor,
                           rolagemInicial: a.rolagem });
            } else {
                // Arquivo salvo: volta lendo do disco (pode ter mudado lá fora).
                var uid = criarAba({ caminho: a.caminho, nome: a.nome, carregando: true, cursorInicial: a.cursor,
                                     rolagemInicial: a.rolagem });
                examinar(uid, a.caminho, { restaurando: true });
            }
        }
        if (abas.count > 0)
            atual = s.atual;
    }

    // ----- abas -----
    function editor(i) {
        return tela ? tela.editor(i) : null;
    }
    function indiceDe(uid) {
        for (var i = 0; i < abas.count; i++)
            if (abas.get(i).uid === uid)
                return i;
        return -1;
    }
    function indiceDoCaminho(caminho) {
        for (var i = 0; i < abas.count; i++)
            if (abas.get(i).caminho === caminho)
                return i;
        return -1;
    }
    function definir(i, campos) {
        for (var k in campos)
            abas.setProperty(i, k, campos[k]);
        mudancas++;
        mexeu();
    }
    function semTitulo() {
        var nomes = [];
        for (var i = 0; i < abas.count; i++)
            if (!abas.get(i).caminho)
                nomes.push(abas.get(i).nome);
        return Logica.proximoSemTitulo(nomes, t("Sem título", "Untitled"));
    }
    function criarAba(campos, posicao) {
        var e = {
            uid: proximoUid++, caminho: "", nome: "", modificado: false, fim: "lf", codificacao: "utf-8",
            carregando: false, textoInicial: "", cursorInicial: 0, rolagemInicial: 0, modificadoInicial: false
        };
        for (var k in campos)
            e[k] = campos[k];
        if (!e.nome)
            e.nome = e.caminho ? Logica.nomeDoCaminho(e.caminho) : semTitulo();
        var pos = posicao === undefined || posicao < 0 || posicao > abas.count ? abas.count : posicao;
        if (pos <= atual && abas.count > 0)
            atual++;
        abas.insert(pos, e);
        mudancas++;
        mexeu();
        return e.uid;
    }
    // "Novo" abre ao lado da aba de agora; "Nova aba", no fim (como no navegador).
    function novaAba(aoLado) {
        var pos = aoLado ? atual + 1 : abas.count;
        criarAba({}, pos);
        atual = pos;
        focarEditor();
    }
    function irParaAba(i) {
        if (i >= 0 && i < abas.count)
            atual = i;
        focarEditor();
    }
    function proximaAba(passo) {
        if (abas.count > 1)
            atual = (atual + passo + abas.count) % abas.count;
    }
    function moverAba(de, para) {
        if (de === para || de < 0 || para < 0 || de >= abas.count || para >= abas.count)
            return;
        var eraAtual = atual;
        abas.move(de, para, 1);
        if (eraAtual === de)
            atual = para;
        else if (de < eraAtual && para >= eraAtual)
            atual = eraAtual - 1;
        else if (de > eraAtual && para <= eraAtual)
            atual = eraAtual + 1;
        mudancas++;
        mexeu();
    }
    // A aba de agora está sem nada (sem arquivo, sem texto): abrir um arquivo usa ela.
    function abaAtualVazia() {
        if (!abaAtual || abaAtual.caminho || abaAtual.modificado || abaAtual.carregando)
            return false;
        var ed = editorAtual;
        return !ed || ed.area.length === 0;
    }
    function focarEditor() {
        if (editorAtual && !dialogo.opened)
            editorAtual.focar();
    }

    // Fechar uma aba; com mudanças, pergunta antes. Fechar a última fecha a janela (como no Windows 11).
    function fecharAba(i) {
        if (i < 0 || i >= abas.count)
            return;
        var uid = abas.get(i).uid;
        if (abas.get(i).modificado) {
            atual = i;
            perguntarSalvar(i, function (ok) {
                if (ok)
                    removerAba(uid);
            });
        } else {
            removerAba(uid);
        }
    }
    function removerAba(uid) {
        var i = indiceDe(uid);
        if (i < 0)
            return;
        if (abas.count === 1) {
            abas.remove(0);
            atual = 0;
            mudancas++;
            podeFechar = true;
            janela.close();
            return;
        }
        var novo = atual;
        if (i < atual || (i === atual && atual === abas.count - 1))
            novo = atual - 1;
        abas.remove(i);
        atual = Math.max(0, Math.min(novo, abas.count - 1));
        mudancas++;
        mexeu();
        focarEditor();
    }
    function fecharOutras(i) {
        var manter = abas.get(i).uid;
        var lista = [];
        for (var k = 0; k < abas.count; k++)
            if (abas.get(k).uid !== manter)
                lista.push(abas.get(k).uid);
        fecharVarias(lista);
    }
    function fecharADireita(i) {
        var lista = [];
        for (var k = i + 1; k < abas.count; k++)
            lista.push(abas.get(k).uid);
        fecharVarias(lista);
    }
    // Fecha uma por uma, perguntando nas que têm mudanças; "Cancelar" para tudo.
    function fecharVarias(lista) {
        if (lista.length === 0)
            return;
        var uid = lista[0];
        var resto = lista.slice(1);
        var i = indiceDe(uid);
        if (i < 0) {
            fecharVarias(resto);
            return;
        }
        if (!abas.get(i).modificado) {
            removerAba(uid);
            fecharVarias(resto);
            return;
        }
        atual = i;
        perguntarSalvar(i, function (ok) {
            if (!ok)
                return;
            removerAba(uid);
            fecharVarias(resto);
        });
    }

    // ----- abrir arquivos -----
    // O ajudante olha o arquivo antes (tamanho, binário, codificação, fim de
    // linha); a aba aparece na hora, com a rodinha, e o texto chega depois.
    property var pedidos: ({})

    function abrir(arg, opcoes) {
        var caminho = Logica.caminhoLocal(arg);
        if (!caminho)
            return;
        var j = indiceDoCaminho(caminho);
        if (j >= 0) {
            atual = j;
            return;
        }
        var uid;
        var reaproveitada = abaAtualVazia();
        if (reaproveitada) {
            uid = abaAtual.uid;
            definir(atual, { caminho: caminho, nome: Logica.nomeDoCaminho(caminho), carregando: true });
        } else {
            var pos = abas.count;
            uid = criarAba({ caminho: caminho, carregando: true }, pos);
            atual = pos;
        }
        examinar(uid, caminho, { reaproveitada: reaproveitada });
    }
    // Argumentos: arquivos (caminho ou file://) e "--nova-aba" (a ação do menu do app).
    function abrirVarios(lista) {
        for (var i = 0; i < lista.length; i++) {
            var a = String(lista[i]);
            if (a === "--nova-aba") {
                if (!abaAtualVazia())
                    novaAba(false);
            } else if (a.indexOf("--") !== 0) {
                abrir(a);
            }
        }
    }
    function examinar(uid, caminho, opcoes) {
        var chave = "examinar:" + uid;
        pedidos[chave] = { uid: uid, caminho: caminho, opcoes: opcoes || {} };
        matsu.rodar(chave, comando(["examinar", caminho]));
    }
    // A aba que esperava o arquivo volta a ser vazia (se era a de agora) ou some.
    function desistir(uid, opcoes) {
        var i = indiceDe(uid);
        if (i < 0)
            return;
        if (opcoes && opcoes.reaproveitada)
            definir(i, { caminho: "", nome: semTitulo(), carregando: false });
        else
            removerAba(uid);
    }
    function examinado(chave, saida, codigo) {
        var p = pedidos[chave];
        delete pedidos[chave];
        if (!p || indiceDe(p.uid) < 0)
            return;
        var info = null;
        try {
            info = JSON.parse(saida);
        } catch (e) {
            info = null;
        }
        if (!info) {
            // Sem o ajudante: lê como UTF-8 e confere depois.
            info = { caminho: p.caminho, existe: matsu.existe(p.caminho), pasta: false, legivel: true, tamanho: -1,
                     grande: false, binario: false, codificacao: "utf-8", fim: "", semAjudante: true };
        }
        var nome = Logica.nomeDoCaminho(p.caminho);
        if (!info.existe || info.pasta || !info.legivel) {
            if (!p.opcoes.restaurando || info.pasta || info.existe)
                avisoRapido(!info.existe ? t("Não encontrei “%1”", "Couldn't find “%1”").arg(nome)
                                         : (info.pasta ? t("“%1” é uma pasta", "“%1” is a folder").arg(nome)
                                                       : t("Sem permissão para abrir “%1”", "No permission to open “%1”").arg(nome)), "erro");
            else
                avisoRapido(t("“%1” não está mais lá e saiu das abas", "“%1” is gone and was closed").arg(nome), "");
            desistir(p.uid, p.opcoes);
            return;
        }
        // O caminho de verdade (o ajudante resolve "./arquivo.txt" da linha de comando).
        if (info.caminho && info.caminho !== p.caminho) {
            var outra = indiceDoCaminho(info.caminho);
            if (outra >= 0 && abas.get(outra).uid !== p.uid) {
                desistir(p.uid, p.opcoes);
                atual = indiceDoCaminho(info.caminho);
                return;
            }
            definir(indiceDe(p.uid), { caminho: info.caminho, nome: Logica.nomeDoCaminho(info.caminho) });
            p.caminho = info.caminho;
        }
        var seguir = function () {
            carregar(p, info);
        };
        var talvezBinario = function () {
            if (info.binario && !p.opcoes.restaurando)
                perguntar({
                    titulo: t("“%1” não parece ser de texto", "“%1” doesn't look like text").arg(nome),
                    texto: t("Parece um arquivo de programa, imagem ou de outro formato. Aberto aqui, ele mostra caracteres estranhos, e salvar pode estragá-lo.",
                             "It looks like a program, image or another format. Here it shows odd characters, and saving may damage it."),
                    sim: t("Abrir mesmo assim", "Open anyway")
                }, seguir, null, function () {
                    desistir(p.uid, p.opcoes);
                });
            else
                seguir();
        };
        if (info.grande && !p.opcoes.restaurando)
            perguntar({
                titulo: t("“%1” é muito grande", "“%1” is very large").arg(nome),
                texto: t("O arquivo tem %1. Arquivos assim podem deixar o Bloco de notas lento enquanto abrem.",
                         "The file is %1. Files like this can make Notepad slow while they open.").arg(bytes(info.tamanho)),
                sim: t("Abrir mesmo assim", "Open anyway")
            }, talvezBinario, null, function () {
                desistir(p.uid, p.opcoes);
            });
        else
            talvezBinario();
    }
    function carregar(p, info) {
        var cod = info.codificacao || "utf-8";
        if (cod === "utf-8" || cod === "utf-8-bom") {
            var texto = matsu.ler(p.caminho);
            if (info.semAjudante && Logica.pareceBinario(texto) && !p.opcoes.restaurando) {
                info.semAjudante = false;
                info.binario = true;
                // Pergunta como se o ajudante tivesse dito que é binário.
                perguntar({
                    titulo: t("“%1” não parece ser de texto", "“%1” doesn't look like text").arg(Logica.nomeDoCaminho(p.caminho)),
                    texto: t("Aberto aqui, ele mostra caracteres estranhos, e salvar pode estragá-lo.",
                             "Here it shows odd characters, and saving may damage it."),
                    sim: t("Abrir mesmo assim", "Open anyway")
                }, function () {
                    preencher(p, info, texto);
                }, null, function () {
                    desistir(p.uid, p.opcoes);
                });
                return;
            }
            preencher(p, info, texto);
        } else {
            var chave = "ler:" + p.uid;
            pedidos[chave] = { uid: p.uid, caminho: p.caminho, opcoes: p.opcoes, info: info };
            matsu.rodar(chave, comando(["ler", p.caminho, cod]));
        }
    }
    function lido(chave, saida, codigo) {
        var p = pedidos[chave];
        delete pedidos[chave];
        if (!p || indiceDe(p.uid) < 0)
            return;
        var r = null;
        try {
            r = JSON.parse(saida);
        } catch (e) {
            r = null;
        }
        if (!r || typeof r.texto !== "string") {
            avisoRapido(t("Não consegui ler “%1”", "Couldn't read “%1”").arg(Logica.nomeDoCaminho(p.caminho)), "erro");
            desistir(p.uid, p.opcoes);
            return;
        }
        preencher(p, p.info, r.texto);
    }
    function preencher(p, info, texto) {
        var i = indiceDe(p.uid);
        if (i < 0)
            return;
        var fim = info.fim || Logica.detectarFim(texto) || "lf";
        abas.setProperty(i, "textoInicial", Logica.paraEditor(texto));
        abas.setProperty(i, "fim", fim);
        abas.setProperty(i, "codificacao", info.codificacao || "utf-8");
        abas.setProperty(i, "modificadoInicial", false);
        if (!p.opcoes.restaurando)
            abas.setProperty(i, "cursorInicial", 0);
        // O editor lê o texto quando "carregando" vira falso.
        definir(i, { carregando: false });
        if (!p.opcoes.restaurando)
            recentes = Logica.adicionarRecente(recentes, p.caminho, 10);
    }

    // ----- salvar -----
    // "depois(ok)" é chamado no fim: ok falso quando a pessoa desistiu ou deu erro.
    function salvar(i, depois) {
        if (i < 0 || i >= abas.count || abas.get(i).carregando) {
            if (depois)
                depois(false);
            return;
        }
        if (!abas.get(i).caminho)
            salvarComo(i, depois);
        else
            gravarEm(abas.get(i).uid, abas.get(i).caminho, depois);
    }
    property var pedidoSalvar: null
    function salvarComo(i, depois) {
        if (i < 0 || i >= abas.count || abas.get(i).carregando) {
            if (depois)
                depois(false);
            return;
        }
        var a = abas.get(i);
        pedidoSalvar = { uid: a.uid, depois: depois || null };
        var pasta = a.caminho ? Logica.pastaDoCaminho(a.caminho) : (matsu.pasta("documentos") || casa);
        var nome = a.caminho ? a.nome : a.nome + ".txt";
        dialogoSalvar.currentFolder = "file://" + pasta;
        dialogoSalvar.selectedFile = "file://" + pasta + "/" + nome;
        dialogoSalvar.open();
    }
    function gravarEm(uid, caminho, depois) {
        var i = indiceDe(uid);
        var ed = editor(i);
        if (i < 0 || !ed) {
            if (depois)
                depois(false);
            return;
        }
        var a = abas.get(i);
        var texto = Logica.paraArquivo(ed.area.text, a.fim);
        var cod = a.codificacao;
        if (cod === "utf-8" || cod === "utf-8-bom") {
            var ok = matsu.gravar(caminho, (cod === "utf-8-bom" ? "﻿" : "") + texto);
            gravado(uid, caminho, ok, ok ? "" : "gravar", depois);
        } else {
            // Outras codificações: o texto vai em UTF-8 para um arquivo de passagem
            // e o ajudante grava no lugar, na codificação do arquivo.
            var passagem = dados + "/gravando-" + uid + ".txt";
            if (!matsu.gravar(passagem, texto)) {
                gravado(uid, caminho, false, "gravar", depois);
                return;
            }
            var chave = "gravar:" + uid;
            pedidos[chave] = { uid: uid, caminho: caminho, depois: depois, codificacao: cod };
            matsu.rodar(chave, comando(["gravar", passagem, caminho, cod]));
        }
    }
    function gravadoPeloAjudante(chave, saida, codigo) {
        var p = pedidos[chave];
        delete pedidos[chave];
        if (!p)
            return;
        var r = null;
        try {
            r = JSON.parse(saida);
        } catch (e) {
            r = null;
        }
        if (r && r.erro === "caracteres") {
            var i = indiceDe(p.uid);
            perguntar({
                titulo: t("Salvar em UTF-8?", "Save as UTF-8?"),
                texto: t("O texto tem caracteres (como “%1”) que não existem em %2, a codificação deste arquivo. Em UTF-8 eles ficam certos.",
                         "The text has characters (like “%1”) that don't exist in %2, this file's encoding. UTF-8 keeps them right.")
                       .arg(r.caractere).arg(Logica.nomeCodificacao(p.codificacao, pt)),
                sim: t("Salvar em UTF-8", "Save as UTF-8")
            }, function () {
                var k = indiceDe(p.uid);
                if (k < 0)
                    return;
                definir(k, { codificacao: "utf-8" });
                gravarEm(p.uid, p.caminho, p.depois);
            }, null, function () {
                if (p.depois)
                    p.depois(false);
            });
            return;
        }
        gravado(p.uid, p.caminho, !!(r && r.ok), r ? (r.erro || "") : "gravar", p.depois);
    }
    function gravado(uid, caminho, ok, erro, depois) {
        var i = indiceDe(uid);
        var nome = Logica.nomeDoCaminho(caminho);
        if (!ok) {
            avisoRapido(erro === "permissao" ? t("Sem permissão para salvar “%1”", "No permission to save “%1”").arg(nome)
                                             : t("Não consegui salvar “%1”", "Couldn't save “%1”").arg(nome), "erro",
                        t("Salvar como…", "Save as…"), function () {
                            var k = indiceDe(uid);
                            if (k >= 0)
                                salvarComo(k);
                        });
            if (depois)
                depois(false);
            return;
        }
        if (i >= 0) {
            var ed = editor(i);
            if (ed)
                ed.area.textDocument.modified = false;
            definir(i, { caminho: caminho, nome: nome, modificado: false });
        }
        recentes = Logica.adicionarRecente(recentes, caminho, 10);
        if (depois)
            depois(true);
    }

    // "Salvar as alterações?": Salvar, Não salvar ou Cancelar. depois(true) quando
    // pode seguir (salvou ou não quis salvar), depois(false) quando cancelou.
    function perguntarSalvar(i, depois) {
        var a = abas.get(i);
        var uid = a.uid;
        perguntar({
            titulo: t("Salvar as alterações em “%1”?", "Save changes to “%1”?").arg(a.nome),
            texto: a.caminho ? t("Se não salvar, o que você mudou desde a última vez vai ser perdido.",
                                 "If you don't save, your changes since the last save will be lost.")
                             : t("Este texto ainda não tem arquivo. Se não salvar, ele vai ser perdido.",
                                 "This text has no file yet. If you don't save, it will be lost."),
            sim: t("Salvar", "Save"),
            terceiro: t("Não salvar", "Don't save"),
            nao: t("Cancelar", "Cancel")
        }, function () {
            salvar(indiceDe(uid), depois);
        }, function () {
            depois(true);
        }, function () {
            depois(false);
        });
    }

    // ----- perguntas (uma de cada vez, com o cancelar avisado) -----
    property var filaPerguntas: []
    property var perguntaAtual: null
    function perguntar(pedido, aoSim, aoTerceiro, aoCancelar) {
        filaPerguntas.push({ pedido: pedido, aoSim: aoSim, aoTerceiro: aoTerceiro, aoCancelar: aoCancelar, respondida: false });
        if (!perguntaAtual)
            proximaPergunta();
    }
    function proximaPergunta() {
        if (perguntaAtual || filaPerguntas.length === 0)
            return;
        var p = filaPerguntas.shift();
        perguntaAtual = p;
        dialogo.perguntar(p.pedido, function () {
            p.respondida = true;
            if (p.aoSim)
                p.aoSim();
        }, p.pedido.terceiro ? function () {
            p.respondida = true;
            if (p.aoTerceiro)
                p.aoTerceiro();
        } : null);
    }
    Dialogo {
        id: dialogo
        onClosed: {
            var p = janela.perguntaAtual;
            janela.perguntaAtual = null;
            if (p && !p.respondida && p.aoCancelar)
                p.aoCancelar();
            if (janela.filaPerguntas.length > 0)
                Qt.callLater(janela.proximaPergunta);
            else
                Qt.callLater(janela.focarEditor);
        }
    }

    // ----- fechar a janela -----
    // Com "Reabrir as abas ao iniciar" (o padrão, como no Windows 11) nada se
    // perde: o texto não salvo volta na próxima vez, então não precisa perguntar.
    // Sem ele, pergunta em cada aba com mudanças.
    property bool podeFechar: false
    onClosing: function (fecho) {
        if (podeFechar || lembrar) {
            guardarAjustes();
            guardarSessao();
            return;
        }
        var pendentes = [];
        for (var i = 0; i < abas.count; i++)
            if (abas.get(i).modificado)
                pendentes.push(abas.get(i).uid);
        if (pendentes.length === 0) {
            guardarAjustes();
            guardarSessao();
            return;
        }
        fecho.accepted = false;
        perguntarAoFechar(pendentes);
    }
    function perguntarAoFechar(lista) {
        if (lista.length === 0) {
            podeFechar = true;
            Qt.callLater(janela.close);
            return;
        }
        var i = indiceDe(lista[0]);
        if (i < 0 || !abas.get(i).modificado) {
            perguntarAoFechar(lista.slice(1));
            return;
        }
        atual = i;
        perguntarSalvar(i, function (ok) {
            if (ok)
                perguntarAoFechar(lista.slice(1));
        });
    }

    // ----- editar -----
    function desfazer() {
        if (editorAtual)
            editorAtual.desfazer();
    }
    function refazer() {
        if (editorAtual)
            editorAtual.refazer();
    }
    function dataHora() {
        var ed = editorAtual;
        if (!ed)
            return;
        var s = Qt.formatDateTime(new Date(), pt ? "HH:mm dd/MM/yyyy" : "h:mm AP M/d/yyyy");
        var ini = ed.area.selectionStart;
        ed.trocar(ini, ed.area.selectionEnd, s);
        ed.area.cursorPosition = ini + s.length;
        ed.focar();
    }
    function mudarZoom(passo) {
        if (passo === 0)
            zoom = 100;
        else
            zoom = Math.max(10, Math.min(500, Math.round((zoom + passo) / 10) * 10));
    }
    function copiarTexto(s) {
        prancheta.text = s;
        prancheta.selectAll();
        prancheta.copy();
        prancheta.text = "";
    }
    TextEdit {
        id: prancheta
        visible: false
    }
    // Mostra o arquivo no gerenciador de arquivos (com ele escolhido); sem o
    // serviço do gerenciador, abre só a pasta.
    function mostrarNaPasta(caminho) {
        var url = "file://" + encodeURI(caminho).replace(/'/g, "%27");
        pastaPedida = Logica.pastaDoCaminho(caminho);
        matsu.rodar("mostrar", ["gdbus", "call", "--session", "--dest", "org.freedesktop.FileManager1",
                                "--object-path", "/org/freedesktop/FileManager1", "--method",
                                "org.freedesktop.FileManager1.ShowItems", "['" + url + "']", ""]);
    }
    property string pastaPedida: ""

    // ----- conversa com o matsu-janela -----
    Connections {
        target: matsu
        function onPronto(chave, saida, codigo) {
            if (chave.indexOf("examinar:") === 0)
                janela.examinado(chave, saida, codigo);
            else if (chave.indexOf("ler:") === 0)
                janela.lido(chave, saida, codigo);
            else if (chave.indexOf("gravar:") === 0)
                janela.gravadoPeloAjudante(chave, saida, codigo);
            else if (chave === "mostrar" && codigo !== 0 && janela.pastaPedida)
                matsu.soltar(["xdg-open", janela.pastaPedida]);
            else if (chave === "ambiente") {
                try {
                    var d = JSON.parse(saida);
                    if (d.idioma)
                        janela.lingua = d.idioma;
                    if (d.vidro)
                        janela.vidroConf = d.vidro;
                } catch (e) {
                }
            }
        }
        // Aberto de novo com arquivos (o app já estava aberto): cada um numa aba.
        function onPedido(argumentos) {
            janela.abrirVarios(argumentos);
        }
    }

    // Chamado pela Pagina.qml quando o desenho está pronto.
    function iniciar() {
        if (iniciado)
            return;
        matsu.rodar("ambiente", comando(["ambiente"]));
        lerAjustes();
        if (lembrar)
            restaurarSessao();
        abrirVarios(matsu.argumentos);
        if (abas.count === 0)
            criarAba({});
        iniciado = true;
        Qt.callLater(focarEditor);
    }

    // ----- abrir e salvar (com o KDE, a janela de arquivos de verdade) -----
    readonly property var filtros: [
        t("Documentos de texto (*.txt)", "Text documents (*.txt)"),
        t("Textos e código (*.txt *.md *.log *.csv *.json *.xml *.yaml *.yml *.ini *.conf *.sh *.py *.js *.html *.css)",
          "Text and code (*.txt *.md *.log *.csv *.json *.xml *.yaml *.yml *.ini *.conf *.sh *.py *.js *.html *.css)"),
        t("Todos os arquivos (*)", "All files (*)")
    ]
    function abrirDialogo() {
        var pasta = abaAtual && abaAtual.caminho ? Logica.pastaDoCaminho(abaAtual.caminho) : (matsu.pasta("documentos") || casa);
        dialogoAbrir.currentFolder = "file://" + pasta;
        dialogoAbrir.open();
    }
    FileDialog {
        id: dialogoAbrir
        title: janela.t("Abrir", "Open")
        fileMode: FileDialog.OpenFiles
        nameFilters: janela.filtros
        selectedNameFilter.index: 2
        onAccepted: {
            var lista = [];
            for (var i = 0; i < selectedFiles.length; i++)
                lista.push(String(selectedFiles[i]));
            janela.abrirVarios(lista);
        }
    }
    FileDialog {
        id: dialogoSalvar
        title: janela.t("Salvar como", "Save as")
        fileMode: FileDialog.SaveFile
        nameFilters: janela.filtros
        onAccepted: {
            var p = janela.pedidoSalvar;
            janela.pedidoSalvar = null;
            if (!p)
                return;
            var caminho = Logica.caminhoLocal(String(selectedFile));
            // No filtro de texto, sem extensão vira .txt (como no Windows).
            if (selectedNameFilter.index === 0 && Logica.nomeDoCaminho(caminho).indexOf(".") < 0)
                caminho += ".txt";
            // Já aberto em outra aba? Essa outra fica com o texto antigo; avisa.
            var outra = janela.indiceDoCaminho(caminho);
            if (outra >= 0 && janela.abas.get(outra).uid !== p.uid)
                janela.avisoRapido(janela.t("“%1” também está aberto em outra aba", "“%1” is also open in another tab").arg(Logica.nomeDoCaminho(caminho)), "");
            janela.gravarEm(p.uid, caminho, p.depois);
        }
        onRejected: {
            var p = janela.pedidoSalvar;
            janela.pedidoSalvar = null;
            if (p && p.depois)
                p.depois(false);
        }
    }

    // ----- menus -----
    readonly property string certo: "matsu-certo-symbolic"
    readonly property string semCerto: ic("vazio")
    // O menu da barra que está aberto (para trocar de um para o outro passando o mouse).
    property var menuDaBarra: null
    // Os menus pegam o foco (assim o Esc os fecha) e, quando terminam de fechar, o Qt
    // devolve o foco ao editor. O que abre algo que quer o foco (a barra de busca, o
    // "Ir para a linha", a fonte) espera o menu terminar de fechar.
    function depoisDe(menu, fn) {
        if (!menu || !menu.visible) {
            fn();
            return;
        }
        var f = function () {
            menu.closed.disconnect(f);
            fn();
        };
        menu.closed.connect(f);
    }
    // Os menus e balões para as peças do miolo (que não enxergam os ids daqui).
    readonly property var menus: ({ arquivo: menuArquivo, editar: menuEditar, exibir: menuExibir, fonte: painelFonte })

    MenuMatsu {
        id: menuArquivo
        focus: true
        onOpened: janela.menuDaBarra = menuArquivo
        onClosed: if (janela.menuDaBarra === menuArquivo) janela.menuDaBarra = null
        itens: [
            { id: "novo", nome: janela.t("Novo", "New"), icone: janela.ic("novo"), atalho: "Ctrl+N" },
            { id: "aba", nome: janela.t("Nova aba", "New tab"), icone: janela.ic("aba"), atalho: "Ctrl+T" },
            { id: "abrir", nome: janela.t("Abrir…", "Open…"), icone: "matsu-pasta-symbolic", atalho: "Ctrl+O", separador: true },
            { id: "recentes", nome: janela.t("Recentes", "Recent"), icone: janela.ic("historico"), atalho: "›", ativo: janela.recentes.length > 0 },
            { id: "salvar", nome: janela.t("Salvar", "Save"), icone: janela.ic("salvar"), atalho: "Ctrl+S", separador: true },
            { id: "salvarComo", nome: janela.t("Salvar como…", "Save as…"), icone: janela.ic("salvar-como"), atalho: "Ctrl+Shift+S" },
            { id: "lembrar", nome: janela.t("Reabrir as abas ao iniciar", "Reopen tabs on start"), icone: janela.lembrar ? janela.certo : janela.semCerto, separador: true },
            { id: "fechar", nome: janela.t("Fechar aba", "Close tab"), icone: "matsu-fechar-symbolic", atalho: "Ctrl+W", separador: true }
        ]
        onEscolhido: (id) => {
            if (id === "novo")
                janela.novaAba(true);
            else if (id === "aba")
                janela.novaAba(false);
            else if (id === "abrir")
                janela.abrirDialogo();
            else if (id === "recentes")
                Qt.callLater(janela.abrirRecentes);
            else if (id === "salvar")
                janela.salvar(janela.atual);
            else if (id === "salvarComo")
                janela.salvarComo(janela.atual);
            else if (id === "lembrar") {
                janela.lembrar = !janela.lembrar;
                janela.avisoRapido(janela.lembrar ? janela.t("As abas voltam quando abrir de novo", "Tabs come back next time")
                                                  : janela.t("Ao fechar, o Bloco de notas pergunta o que salvar", "On close, Notepad asks what to save"), "certo");
            } else if (id === "fechar")
                janela.fecharAba(janela.atual);
        }
    }
    function abrirRecentes() {
        if (tela)
            menuRecentes.abrirEm(tela.barraFerramentas.botaoArquivo, Math.round(gu * 0.2), tela.barraFerramentas.botaoArquivo.height + 3);
    }
    MenuMatsu {
        id: menuRecentes
        focus: true
        onOpened: janela.menuDaBarra = menuRecentes
        onClosed: if (janela.menuDaBarra === menuRecentes) janela.menuDaBarra = null
        itens: {
            var r = [];
            for (var i = 0; i < janela.recentes.length; i++)
                r.push({ id: janela.recentes[i], nome: Logica.nomeDoCaminho(janela.recentes[i]),
                         atalho: Logica.pastaCurta(janela.recentes[i], janela.casa), icone: janela.ic("novo") });
            r.push({ id: "", nome: janela.t("Limpar a lista", "Clear the list"), icone: "matsu-lixeira-symbolic", separador: true });
            return r;
        }
        onEscolhido: (id) => {
            if (id === "")
                janela.recentes = [];
            else
                janela.abrir(id);
        }
    }
    MenuMatsu {
        id: menuEditar
        focus: true
        onOpened: janela.menuDaBarra = menuEditar
        onClosed: if (janela.menuDaBarra === menuEditar) janela.menuDaBarra = null
        readonly property var area: janela.editorAtual ? janela.editorAtual.area : null
        readonly property bool temSelecao: area !== null && area.selectionEnd > area.selectionStart
        itens: [
            { id: "desfazer", nome: janela.t("Desfazer", "Undo"), icone: janela.ic("desfazer"), atalho: "Ctrl+Z", ativo: area !== null && area.canUndo },
            { id: "refazer", nome: janela.t("Refazer", "Redo"), icone: janela.ic("refazer"), atalho: "Ctrl+Y", ativo: area !== null && area.canRedo },
            { id: "recortar", nome: janela.t("Recortar", "Cut"), icone: janela.ic("recortar"), atalho: "Ctrl+X", ativo: temSelecao, separador: true },
            { id: "copiar", nome: janela.t("Copiar", "Copy"), icone: janela.ic("copiar"), atalho: "Ctrl+C", ativo: temSelecao },
            { id: "colar", nome: janela.t("Colar", "Paste"), icone: janela.ic("colar"), atalho: "Ctrl+V", ativo: area !== null && area.canPaste },
            { id: "localizar", nome: janela.t("Localizar…", "Find…"), icone: "matsu-busca-symbolic", atalho: "Ctrl+F", separador: true },
            { id: "substituir", nome: janela.t("Substituir…", "Replace…"), icone: janela.ic("substituir"), atalho: "Ctrl+H" },
            { id: "linha", nome: janela.t("Ir para a linha…", "Go to line…"), icone: janela.ic("ir-linha"), atalho: "Ctrl+G" },
            { id: "tudo", nome: janela.t("Selecionar tudo", "Select all"), icone: janela.ic("selecionar"), atalho: "Ctrl+A", separador: true },
            { id: "data", nome: janela.t("Data e hora", "Time/Date"), icone: "matsu-relogio-symbolic", atalho: "F5" }
        ]
        onEscolhido: (id) => janela.acaoEditar(id, menuEditar)
    }
    function acaoEditar(id, menu) {
        var ed = editorAtual;
        if (!ed)
            return;
        if (id === "desfazer")
            ed.desfazer();
        else if (id === "refazer")
            ed.refazer();
        else if (id === "recortar")
            ed.area.cut();
        else if (id === "copiar")
            ed.area.copy();
        else if (id === "colar")
            ed.area.paste();
        else if (id === "excluir")
            ed.trocar(ed.area.selectionStart, ed.area.selectionEnd, "");
        else if (id === "localizar" || id === "substituir") {
            depoisDe(menu, () => tela.busca.abrir(id === "substituir"));
            return;
        } else if (id === "linha") {
            depoisDe(menu, abrirIrPara);
            return;
        } else if (id === "tudo")
            ed.area.selectAll();
        else if (id === "data") {
            dataHora();
            return;
        }
        ed.focar();
    }
    MenuMatsu {
        id: menuExibir
        focus: true
        onOpened: janela.menuDaBarra = menuExibir
        onClosed: if (janela.menuDaBarra === menuExibir) janela.menuDaBarra = null
        itens: [
            { id: "mais", nome: janela.t("Aumentar o zoom", "Zoom in"), icone: janela.ic("zoom-mais"), atalho: "Ctrl++", ativo: janela.zoom < 500 },
            { id: "menos", nome: janela.t("Diminuir o zoom", "Zoom out"), icone: janela.ic("zoom-menos"), atalho: "Ctrl+−", ativo: janela.zoom > 10 },
            { id: "normal", nome: janela.t("Zoom normal (100%)", "Restore zoom (100%)"), icone: janela.ic("zoom-normal"), atalho: "Ctrl+0", ativo: janela.zoom !== 100 },
            { id: "quebra", nome: janela.t("Quebra de linha", "Word wrap"), icone: janela.quebra ? janela.certo : janela.semCerto, separador: true },
            { id: "status", nome: janela.t("Barra de status", "Status bar"), icone: janela.barraStatus ? janela.certo : janela.semCerto },
            { id: "numeros", nome: janela.t("Números de linha", "Line numbers"), icone: janela.numeros ? janela.certo : janela.semCerto },
            { id: "fonte", nome: janela.t("Fonte…", "Font…"), icone: "matsu-texto-symbolic", separador: true }
        ]
        onEscolhido: (id) => {
            if (id === "mais")
                janela.mudarZoom(10);
            else if (id === "menos")
                janela.mudarZoom(-10);
            else if (id === "normal")
                janela.mudarZoom(0);
            else if (id === "quebra")
                janela.quebra = !janela.quebra;
            else if (id === "status")
                janela.barraStatus = !janela.barraStatus;
            else if (id === "numeros")
                janela.numeros = !janela.numeros;
            else if (id === "fonte") {
                janela.depoisDe(menuExibir, janela.abrirFonte);
                return;
            }
            janela.focarEditor();
        }
    }
    // Botão direito no texto.
    MenuMatsu {
        id: menuTexto
        focus: true
        readonly property var area: janela.editorAtual ? janela.editorAtual.area : null
        readonly property bool temSelecao: area !== null && area.selectionEnd > area.selectionStart
        itens: [
            { id: "desfazer", nome: janela.t("Desfazer", "Undo"), icone: janela.ic("desfazer"), atalho: "Ctrl+Z", ativo: area !== null && area.canUndo },
            { id: "recortar", nome: janela.t("Recortar", "Cut"), icone: janela.ic("recortar"), atalho: "Ctrl+X", ativo: temSelecao, separador: true },
            { id: "copiar", nome: janela.t("Copiar", "Copy"), icone: janela.ic("copiar"), atalho: "Ctrl+C", ativo: temSelecao },
            { id: "colar", nome: janela.t("Colar", "Paste"), icone: janela.ic("colar"), atalho: "Ctrl+V", ativo: area !== null && area.canPaste },
            { id: "excluir", nome: janela.t("Excluir", "Delete"), icone: "matsu-lixeira-symbolic", atalho: "Del", ativo: temSelecao },
            { id: "tudo", nome: janela.t("Selecionar tudo", "Select all"), icone: janela.ic("selecionar"), atalho: "Ctrl+A", separador: true },
            { id: "localizar", nome: janela.t("Localizar…", "Find…"), icone: "matsu-busca-symbolic", atalho: "Ctrl+F" }
        ]
        onEscolhido: (id) => janela.acaoEditar(id, menuTexto)
    }
    function abrirMenuTexto(item, x, y) {
        menuTexto.abrirEm(item, x, y);
    }
    // Botão direito numa aba.
    property int abaDoMenu: -1
    MenuMatsu {
        id: menuAba
        focus: true
        readonly property var aba: janela.abaDoMenu >= 0 && janela.abaDoMenu < janela.abas.count ? janela.abas.get(janela.abaDoMenu) : null
        itens: [
            { id: "fechar", nome: janela.t("Fechar aba", "Close tab"), icone: "matsu-fechar-symbolic", atalho: "Ctrl+W" },
            { id: "outras", nome: janela.t("Fechar as outras abas", "Close other tabs"), icone: janela.ic("fechar-outras"), ativo: janela.abas.count > 1 },
            { id: "direita", nome: janela.t("Fechar as abas à direita", "Close tabs to the right"), icone: janela.ic("vazio"), ativo: janela.abaDoMenu < janela.abas.count - 1 },
            { id: "caminho", nome: janela.t("Copiar o caminho", "Copy path"), icone: janela.ic("copiar"), ativo: aba !== null && aba.caminho !== "", separador: true },
            { id: "pasta", nome: janela.t("Mostrar na pasta", "Show in folder"), icone: "matsu-pasta-symbolic", ativo: aba !== null && aba.caminho !== "" }
        ]
        onEscolhido: (id) => {
            var i = janela.abaDoMenu;
            if (i < 0 || i >= janela.abas.count)
                return;
            var caminho = janela.abas.get(i).caminho;
            if (id === "fechar")
                janela.fecharAba(i);
            else if (id === "outras")
                janela.fecharOutras(i);
            else if (id === "direita")
                janela.fecharADireita(i);
            else if (id === "caminho") {
                janela.copiarTexto(caminho);
                janela.avisoRapido(janela.t("Caminho copiado", "Path copied"), "certo");
            } else if (id === "pasta")
                janela.mostrarNaPasta(caminho);
        }
    }
    function abrirMenuAba(i, item, x, y) {
        abaDoMenu = i;
        menuAba.abrirEm(item, x, y);
    }
    // Barra de status: fim de linha, codificação e zoom.
    MenuMatsu {
        id: menuFim
        focus: true
        readonly property string fim: janela.abaAtual ? janela.abaAtual.fim : "lf"
        itens: [
            { id: "crlf", nome: "Windows (CRLF)", icone: fim === "crlf" ? janela.certo : janela.semCerto },
            { id: "lf", nome: "Unix (LF)", icone: fim === "lf" ? janela.certo : janela.semCerto },
            { id: "cr", nome: Logica.nomeFim("cr", janela.pt), icone: fim === "cr" ? janela.certo : janela.semCerto }
        ]
        onEscolhido: (id) => janela.trocarFormato("fim", id)
    }
    MenuMatsu {
        id: menuCodificacao
        focus: true
        readonly property string cod: janela.abaAtual ? janela.abaAtual.codificacao : "utf-8"
        itens: {
            var r = [];
            var lista = ["utf-8", "utf-8-bom", "utf-16-le", "utf-16-be", "windows-1252"];
            if (cod === "iso-8859-1")
                lista.push("iso-8859-1");
            for (var i = 0; i < lista.length; i++)
                r.push({ id: lista[i], nome: Logica.nomeCodificacao(lista[i], janela.pt), icone: cod === lista[i] ? janela.certo : janela.semCerto });
            return r;
        }
        onEscolhido: (id) => janela.trocarFormato("codificacao", id)
    }
    // Fim de linha e codificação valem ao salvar: a aba fica com mudanças.
    function trocarFormato(campo, valor) {
        if (!abaAtual || abaAtual[campo] === valor)
            return;
        var c = {};
        c[campo] = valor;
        definir(atual, c);
        if (editorAtual) {
            editorAtual.area.textDocument.modified = true;
            editorAtual.focar();
        }
    }
    MenuMatsu {
        id: menuZoom
        focus: true
        itens: {
            var r = [];
            var lista = [50, 75, 100, 125, 150, 200, 300];
            for (var i = 0; i < lista.length; i++)
                r.push({ id: String(lista[i]), nome: lista[i] + "%", icone: janela.zoom === lista[i] ? janela.certo : janela.semCerto });
            return r;
        }
        onEscolhido: (id) => {
            janela.zoom = Number(id);
            janela.focarEditor();
        }
    }
    function abrirMenuStatus(qual, item) {
        var m = ({ fim: menuFim, codificacao: menuCodificacao, zoom: menuZoom })[qual];
        if (m)
            m.abrirEm(item, 0, -4);
    }

    PainelFonte {
        id: painelFonte
        onClosed: janela.focarEditor()
    }
    function abrirFonte() {
        if (tela)
            painelFonte.abrirEm(tela.barraFerramentas.botaoFonte);
    }
    DialogoLinha {
        id: dialogoLinha
        onClosed: janela.focarEditor()
    }
    function abrirIrPara() {
        if (editorAtual)
            dialogoLinha.abrirPara(editorAtual);
    }

    // ----- atalhos -----
    Shortcut { sequences: ["Ctrl+N"]; onActivated: janela.novaAba(true) }
    Shortcut { sequences: ["Ctrl+T"]; onActivated: janela.novaAba(false) }
    Shortcut { sequences: ["Ctrl+O"]; onActivated: janela.abrirDialogo() }
    Shortcut { sequences: ["Ctrl+S"]; onActivated: janela.salvar(janela.atual) }
    Shortcut { sequences: ["Ctrl+Shift+S"]; onActivated: janela.salvarComo(janela.atual) }
    Shortcut { sequences: ["Ctrl+W"]; onActivated: janela.fecharAba(janela.atual) }
    Shortcut { sequences: ["Ctrl+Tab", "Ctrl+PgDown"]; onActivated: janela.proximaAba(1) }
    Shortcut { sequences: ["Ctrl+Shift+Tab", "Ctrl+Shift+Backtab", "Ctrl+PgUp"]; onActivated: janela.proximaAba(-1) }
    Shortcut { sequences: ["Ctrl+F"]; onActivated: if (janela.tela) janela.tela.busca.abrir(false) }
    Shortcut { sequences: ["Ctrl+H"]; onActivated: if (janela.tela) janela.tela.busca.abrir(true) }
    Shortcut { sequences: ["F3"]; onActivated: if (janela.tela) janela.tela.busca.proximoOuAbrir() }
    Shortcut { sequences: ["Shift+F3"]; onActivated: if (janela.tela) janela.tela.busca.anteriorOuAbrir() }
    Shortcut { sequences: ["Ctrl+G"]; onActivated: janela.abrirIrPara() }
    Shortcut { sequences: ["F5"]; onActivated: janela.dataHora() }
    Shortcut { sequences: ["Ctrl++", "Ctrl+=", "Ctrl+Shift+="]; onActivated: janela.mudarZoom(10) }
    Shortcut { sequences: ["Ctrl+-"]; onActivated: janela.mudarZoom(-10) }
    Shortcut { sequences: ["Ctrl+0"]; onActivated: janela.mudarZoom(0) }
    // Ctrl+1 a Ctrl+8 vão para cada aba; Ctrl+9, para a última.
    Instantiator {
        model: 9
        delegate: Shortcut {
            required property int index
            sequences: ["Ctrl+" + (index + 1)]
            onActivated: janela.irParaAba(index === 8 ? janela.abas.count - 1 : index)
        }
    }
}
