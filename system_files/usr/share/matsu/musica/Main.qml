// Música do Matsu (no jeito do Apple Music e do Media Player do Windows 11): a
// biblioteca da pasta Música da pessoa, com Início, Músicas, Álbuns, Artistas,
// Playlists e a Fila. A barra do player fica embaixo de todas as páginas, com a
// onda do som (a mesma do player de voz do vídeo de referência); clicar na capa
// abre o Tocando agora, a tela grande com a capa e o fundo na cor dela.
//
// Aqui é o desenho e o player (QtMultimedia). Quem lê a pasta, as etiquetas, as
// capas e a onda de cada música é o ajudante.py desta pasta; quem conversa com os
// controles de mídia do Plasma e com as teclas do teclado (MPRIS) é o mpris.py.
//
// Guarda em ~/.local/share/matsu/musica: estado.json (a fila, a música, a posição,
// o volume, as tocadas recentemente) e playlists.json.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtMultimedia
import org.kde.kirigami as Kirigami
import "../comum"

JanelaMatsu {
    id: janela

    title: t("Música", "Music")
    icone: "org.matsu.musica"
    iconeReserva: "audio-x-generic"
    dicaBusca: t("Buscar músicas, álbuns e artistas", "Search songs, albums and artists")
    // Buscar filtra a página aberta (Músicas, Álbuns, Artistas); das outras, leva para Músicas.
    paginaDaBusca: (pagina === "musicas" || pagina === "albuns" || pagina === "artistas") ? "" : "musicas"
    paginas: [
        { id: "inicio", icone: "matsu-inicio-symbolic", nome: t("Início", "Home") },
        { id: "musicas", icone: ic("nota"), nome: t("Músicas", "Songs") },
        { id: "albuns", icone: ic("album"), nome: t("Álbuns", "Albums") },
        { id: "artistas", icone: ic("artista"), nome: t("Artistas", "Artists") },
        { id: "playlists", icone: ic("playlist"), nome: t("Playlists", "Playlists") },
        { id: "fila", icone: ic("fila"), nome: t("Fila", "Queue") }
    ]
    // O miolo é sempre o mesmo: ele troca as páginas por dentro e tem a barra do player embaixo.
    conteudo: Qt.resolvedUrl("Miolo.qml")
    width: gu * 64
    height: gu * 42
    minimumWidth: gu * 42
    minimumHeight: gu * 28

    readonly property string ajudante: decodeURIComponent(String(Qt.resolvedUrl("ajudante.py")).replace("file://", ""))
    readonly property string ajudanteMpris: decodeURIComponent(String(Qt.resolvedUrl("mpris.py")).replace("file://", ""))
    function comando(args) {
        return ["/usr/bin/python3", "-I", "-S", ajudante].concat(args);
    }
    // Texto (não url): as peças de ../comum conferem o ícone com .length.
    function ic(nome) {
        return String(Qt.resolvedUrl("icones/" + nome + ".svg"));
    }
    function arquivo(caminho) {
        if (!caminho)
            return "";
        if (caminho.indexOf("://") > 0)
            return caminho;
        return "file://" + caminho.split("/").map(encodeURIComponent).join("/");
    }

    // ----- a biblioteca -----
    property string pastaMusica: matsu.pasta("musica")
    readonly property string pastaDados: matsu.pasta("dados")
    property bool lendo: true
    property bool lidaUmaVez: false
    property int feitos: 0
    property int totalLer: 0
    property bool temFfmpeg: true
    property var musicas: []          // todas, como o ajudante mandou (mais "busca", "chaveAlbum", "chaveArtista")
    property var porCaminho: ({})
    property var externas: ({})       // abertas de fora da pasta (pelo gerenciador de arquivos)
    property var albuns: []
    property var porAlbum: ({})
    property var artistas: []
    property var porArtista: ({})
    property string ultimoJson: ""
    property real ultimaLeitura: 0

    // ----- o player -----
    property var fila: []             // caminhos, na ordem em que vão tocar
    property var filaOriginal: []     // a ordem antes do aleatório
    property int indice: -1
    property bool aleatorio: false
    property string repetir: "nao"    // "nao", "tudo", "uma"
    property real volume: 70          // 0 a 100
    property bool mudo: false
    property real posicao: 0          // ms
    property real posicaoPendente: -1 // pular para aqui quando o arquivo abrir
    property var ondas: ({})          // caminho -> amostras
    property var recentes: []         // [{ caminho, quando }]
    property var playlists: []        // [{ id, nome, musicas: [caminhos], criada }]
    property int mudancasPlaylists: 0
    property string ordemMusicas: "titulo"
    property string ordemAlbuns: "nome"
    property bool restaurado: false

    readonly property var atual: indice >= 0 && indice < fila.length ? musicaDe(fila[indice]) : null
    readonly property bool tocando: player.playbackState === MediaPlayer.PlayingState
    readonly property real duracao: player.duration > 0 ? player.duration : (atual ? atual.duracao * 1000 : 0)
    readonly property real progresso: duracao > 0 ? Math.min(1, posicao / duracao) : 0
    readonly property var ondaAtual: atual && ondas[atual.caminho] ? ondas[atual.caminho] : []
    readonly property var proximaMusica: indice + 1 < fila.length ? musicaDe(fila[indice + 1]) : null

    // ----- navegação -----
    property string albumAberto: ""
    property string artistaAberto: ""
    property string playlistAberta: ""
    property bool tocandoAgoraAberto: false
    onPaginaChanged: {
        albumAberto = "";
        artistaAberto = "";
        playlistAberta = "";
    }

    // ----- textos -----
    function nomeArtista(nome) {
        return nome && nome.length > 0 ? nome : t("Artista desconhecido", "Unknown artist");
    }
    function nomeAlbum(nome) {
        return nome && nome.length > 0 ? nome : t("Sem álbum", "Unknown album");
    }
    function artistaDoAlbum(a) {
        return a.varios ? t("Vários artistas", "Various artists") : nomeArtista(a.artista);
    }
    // 1:05, ou 1:02:05 em músicas longas.
    function tempo(segundos) {
        var s = Math.max(0, Math.floor(segundos || 0));
        var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), r = s % 60;
        var ss = r < 10 ? "0" + r : String(r);
        if (h > 0)
            return h + ":" + (m < 10 ? "0" + m : m) + ":" + ss;
        return m + ":" + ss;
    }
    // "34 min" ou "1 h 12 min".
    function tempoTotal(segundos) {
        var m = Math.round((segundos || 0) / 60);
        if (m < 60)
            return m + " min";
        return Math.floor(m / 60) + " h " + (m % 60) + " min";
    }
    function contagem(n, um, varios, one, many) {
        return n === 1 ? t("1 " + um, "1 " + one) : t(num(n) + " " + varios, num(n) + " " + many);
    }
    function resumo(lista) {
        var total = 0;
        for (var i = 0; i < lista.length; i++)
            total += lista[i].duracao || 0;
        return contagem(lista.length, "música", "músicas", "song", "songs") + (total > 0 ? " · " + tempoTotal(total) : "");
    }
    function saudacao() {
        var h = new Date().getHours();
        if (h >= 5 && h < 12)
            return t("Bom dia", "Good morning");
        if (h >= 12 && h < 18)
            return t("Boa tarde", "Good afternoon");
        return t("Boa noite", "Good evening");
    }
    function bate(texto, busca) {
        var b = simples(busca.trim());
        if (b.length === 0)
            return true;
        var palavras = b.split(/\s+/);
        for (var i = 0; i < palavras.length; i++)
            if (texto.indexOf(palavras[i]) < 0)
                return false;
        return true;
    }

    // ----- montar a biblioteca a partir da lista do ajudante -----
    function musicaDe(caminho) {
        return porCaminho[caminho] || externas[caminho] || null;
    }
    function chaveAlbum(m) {
        if (m.album)
            return "a:" + simples(m.album) + "|" + (m.artistaAlbum ? simples(m.artistaAlbum) : m.caminho.substring(0, m.caminho.lastIndexOf("/")));
        return "s:" + simples(m.artista || "");
    }
    function porFaixa(x, y) {
        return (x.disco || 0) - (y.disco || 0) || (x.faixa || 0) - (y.faixa || 0) || x.titulo.localeCompare(y.titulo);
    }
    function preparar(m) {
        m.busca = simples(m.titulo + " " + m.artista + " " + m.album + " " + m.artistaAlbum);
        m.chaveAlbum = chaveAlbum(m);
        m.chaveArtista = simples(m.artista || "");
        return m;
    }
    function montar(lista) {
        var mapa = {}, alb = {}, art = {};
        for (var i = 0; i < lista.length; i++) {
            var m = preparar(lista[i]);
            mapa[m.caminho] = m;
            var a = alb[m.chaveAlbum];
            if (!a)
                a = alb[m.chaveAlbum] = { chave: m.chaveAlbum, nome: m.album, artistaAlbum: m.artistaAlbum, nomes: {}, ano: 0, capa: "",
                                          faixas: [], duracao: 0, adicionada: 0 };
            a.faixas.push(m);
            a.duracao += m.duracao || 0;
            a.adicionada = Math.max(a.adicionada, m.adicionada || 0);
            if (!a.capa && m.capa)
                a.capa = m.capa;
            if (!a.ano && m.ano)
                a.ano = m.ano;
            a.nomes[m.artista || ""] = true;
            var r = art[m.chaveArtista];
            if (!r)
                r = art[m.chaveArtista] = { chave: m.chaveArtista, nome: m.artista || "", faixas: [], albuns: [], capa: "", duracao: 0 };
            r.faixas.push(m);
            r.duracao += m.duracao || 0;
            if (r.albuns.indexOf(m.chaveAlbum) < 0)
                r.albuns.push(m.chaveAlbum);
            if (!r.capa && m.capa)
                r.capa = m.capa;
        }
        var listaAlb = [];
        for (var k in alb) {
            var b = alb[k];
            var nomes = Object.keys(b.nomes);
            b.varios = !b.artistaAlbum && nomes.length > 1;
            b.artista = b.artistaAlbum || (nomes.length === 1 ? nomes[0] : "");
            b.faixas.sort(porFaixa);
            b.busca = simples(b.nome + " " + b.artista);
            b.ordem = b.nome ? simples(b.nome) : "￿";
            delete b.nomes;
            listaAlb.push(b);
        }
        listaAlb.sort(function (x, y) { return x.ordem.localeCompare(y.ordem); });
        var listaArt = [];
        for (var c in art) {
            var p = art[c];
            p.busca = simples(p.nome);
            p.ordem = p.nome ? simples(p.nome) : "￿";
            p.faixas.sort(function (x, y) { return x.chaveAlbum.localeCompare(y.chaveAlbum) || porFaixa(x, y); });
            listaArt.push(p);
        }
        listaArt.sort(function (x, y) { return x.ordem.localeCompare(y.ordem); });
        porCaminho = mapa;
        porAlbum = alb;
        porArtista = art;
        albuns = listaAlb;
        artistas = listaArt;
        musicas = lista;
    }
    function albumDe(chave) {
        return porAlbum[chave] || null;
    }
    function artistaDe(chave) {
        return porArtista[chave] || null;
    }
    function caminhos(lista) {
        return lista.map(function (m) { return m.caminho; });
    }

    function lerBiblioteca() {
        ultimaLeitura = Date.now();
        matsu.iniciar("biblioteca", comando(["biblioteca", pastaMusica]));
    }
    function receberBiblioteca(texto) {
        var d;
        try {
            d = JSON.parse(texto);
        } catch (e) {
            return;
        }
        if (d.idioma)
            lingua = d.idioma;
        if (d.vidro && JSON.stringify(d.vidro) !== JSON.stringify(vidroConf))
            vidroConf = d.vidro;
        if (d.tipo === "inicio") {
            totalLer = d.total;
            feitos = 0;
        } else if (d.tipo === "progresso") {
            feitos = d.feitos;
            totalLer = d.total;
        } else if (d.tipo === "fim") {
            temFfmpeg = !!d.ffmpeg;
            var json = JSON.stringify(d.musicas);
            if (json !== ultimoJson) {
                ultimoJson = json;
                montar(d.musicas);
            }
            lendo = false;
            lidaUmaVez = true;
            if (!restaurado)
                restaurar();
        }
    }

    // ----- a fila e o player -----
    function embaralhado(lista) {
        var r = lista.slice();
        for (var i = r.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1));
            var x = r[i];
            r[i] = r[j];
            r[j] = x;
        }
        return r;
    }
    // Toca uma lista (de caminhos) a partir de "inicio". Com o aleatório ligado
    // (ou "embaralhar"), a escolhida vem primeiro e o resto é embaralhado.
    function tocarLista(lista, inicio, embaralhar) {
        if (!lista || lista.length === 0)
            return;
        if (embaralhar)
            aleatorio = true;
        filaOriginal = lista.slice();
        if (aleatorio) {
            var i0 = inicio >= 0 && inicio < lista.length ? inicio : Math.floor(Math.random() * lista.length);
            var resto = lista.filter(function (c, n) { return n !== i0; });
            fila = [lista[i0]].concat(embaralhado(resto));
            indice = 0;
        } else {
            fila = lista.slice();
            indice = Math.max(0, Math.min(lista.length - 1, inicio || 0));
        }
        carregar(true, 0);
    }
    function tocarTudo(embaralhar) {
        var lista = musicas.slice().sort(function (x, y) {
            return x.chaveArtista.localeCompare(y.chaveArtista) || x.chaveAlbum.localeCompare(y.chaveAlbum) || porFaixa(x, y);
        });
        tocarLista(caminhos(lista), embaralhar ? -1 : 0, embaralhar);
    }
    function tocarASeguir(lista) {
        if (fila.length === 0)
            return tocarLista(lista, 0, false);
        var f = fila.slice();
        f.splice.apply(f, [indice + 1, 0].concat(lista));
        var atualCaminho = fila[indice];
        var o = filaOriginal.slice();
        var p = o.indexOf(atualCaminho);
        o.splice.apply(o, [p >= 0 ? p + 1 : o.length, 0].concat(lista));
        fila = f;
        filaOriginal = o;
        avisoRapido(lista.length === 1 ? t("Vai tocar a seguir", "Playing next") : t(lista.length + " músicas vão tocar a seguir", lista.length + " songs playing next"), "certo");
        salvarDepois();
        enviarMpris(false);
    }
    function adicionarAFila(lista) {
        if (fila.length === 0)
            return tocarLista(lista, 0, false);
        fila = fila.concat(lista);
        filaOriginal = filaOriginal.concat(lista);
        avisoRapido(lista.length === 1 ? t("Adicionada à fila", "Added to the queue") : t(lista.length + " músicas na fila", lista.length + " songs added to the queue"), "certo");
        salvarDepois();
        enviarMpris(false);
    }
    function removerDaFila(i) {
        if (i < 0 || i >= fila.length)
            return;
        var c = fila[i];
        var f = fila.slice();
        f.splice(i, 1);
        var o = filaOriginal.slice();
        var p = o.indexOf(c);
        if (p >= 0)
            o.splice(p, 1);
        filaOriginal = o;
        if (i < indice) {
            fila = f;
            indice--;
        } else if (i === indice) {
            var seguia = tocando;
            fila = f;
            if (f.length === 0) {
                indice = -1;
                carregar(false, 0);
            } else {
                indice = Math.min(indice, f.length - 1);
                carregar(seguia, 0);
            }
        } else {
            fila = f;
        }
        salvarDepois();
        enviarMpris(false);
    }
    function moverNaFila(de, para) {
        if (de === para || de < 0 || para < 0 || de >= fila.length || para >= fila.length)
            return;
        var f = fila.slice();
        var item = f.splice(de, 1)[0];
        f.splice(para, 0, item);
        if (de === indice)
            indice = para;
        else if (de < indice && para >= indice)
            indice--;
        else if (de > indice && para <= indice)
            indice++;
        fila = f;
        salvarDepois();
    }
    // "Limpar" tira o que vem a seguir; a música de agora continua.
    function limparFila() {
        if (indice < 0)
            return;
        var c = fila[indice];
        fila = [c];
        filaOriginal = [c];
        indice = 0;
        salvarDepois();
        enviarMpris(false);
    }
    function alternarAleatorio() {
        aleatorio = !aleatorio;
        if (fila.length > 1 && indice >= 0) {
            var c = fila[indice];
            if (aleatorio) {
                filaOriginal = fila.slice();
                var resto = fila.filter(function (x, n) { return n !== indice; });
                fila = [c].concat(embaralhado(resto));
                indice = 0;
            } else {
                var base = filaOriginal.filter(function (x) { return fila.indexOf(x) >= 0; });
                for (var i = 0; i < fila.length; i++)
                    if (base.indexOf(fila[i]) < 0)
                        base.push(fila[i]);
                fila = base;
                indice = Math.max(0, base.indexOf(c));
            }
        }
        avisoRapido(aleatorio ? t("Aleatório ligado", "Shuffle on") : t("Aleatório desligado", "Shuffle off"));
        salvarDepois();
        enviarMpris(false);
    }
    function alternarRepetir() {
        repetir = repetir === "nao" ? "tudo" : (repetir === "tudo" ? "uma" : "nao");
        avisoRapido(repetir === "tudo" ? t("Repetir a fila", "Repeat all") : (repetir === "uma" ? t("Repetir esta música", "Repeat one") : t("Repetir desligado", "Repeat off")));
        salvarDepois();
        enviarMpris(false);
    }

    // Abre a música de agora no player (e toca, se "tocar").
    function carregar(tocar, pularPara) {
        var m = atual;
        posicao = pularPara > 0 ? pularPara : 0;
        posicaoPendente = pularPara > 0 ? pularPara : -1;
        if (!m) {
            player.stop();
            player.source = "";
            enviarMpris(false);
            return;
        }
        player.source = arquivo(m.caminho);
        if (tocar) {
            player.play();
            marcarRecente(m.caminho);
        }
        pedirOnda(m.caminho);
        salvarDepois();
        enviarMpris(true);
    }
    function tocarPausar() {
        if (!atual) {
            if (musicas.length > 0)
                tocarTudo(aleatorio);
            return;
        }
        if (tocando) {
            player.pause();
        } else {
            if (player.mediaStatus === MediaPlayer.NoMedia || player.source.toString() === "")
                carregar(true, posicao);
            else
                player.play();
            marcarRecente(atual.caminho);
        }
    }
    function proxima(automatico) {
        if (fila.length === 0)
            return;
        if (indice + 1 < fila.length) {
            indice++;
            carregar(automatico || tocando, 0);
        } else if (repetir === "tudo") {
            indice = 0;
            carregar(true, 0);
        } else if (automatico) {
            // Acabou a fila: para no começo da última.
            player.stop();
            posicao = 0;
            enviarMpris(true);
        } else {
            indice = 0;
            carregar(false, 0);
        }
    }
    function anterior() {
        if (fila.length === 0)
            return;
        if (posicao > 3000 || indice === 0) {
            buscarMs(0);
            return;
        }
        indice--;
        carregar(tocando, 0);
    }
    function terminou() {
        if (repetir === "uma") {
            player.setPosition(0);
            player.play();
            return;
        }
        proxima(true);
    }
    function buscarMs(ms) {
        ms = Math.max(0, Math.min(duracao > 0 ? duracao : ms, ms));
        posicao = ms;
        if (player.seekable)
            player.setPosition(ms);
        else
            posicaoPendente = ms;
        enviarMpris(true);
    }
    function buscar(fracao) {
        if (duracao > 0)
            buscarMs(fracao * duracao);
    }
    function mudarVolume(v) {
        volume = Math.max(0, Math.min(100, v));
        if (volume > 0)
            mudo = false;
        salvarDepois();
        enviarMpris(false);
    }
    function pedirOnda(caminho) {
        if (ondas[caminho])
            return;
        matsu.rodar("onda:" + caminho, comando(["onda", caminho, "200"]));
    }
    function marcarRecente(caminho) {
        var r = recentes.filter(function (x) { return x.caminho !== caminho; });
        r.unshift({ caminho: caminho, quando: Date.now() });
        recentes = r.slice(0, 80);
    }

    // Abrir arquivos de fora (pelo gerenciador de arquivos ou "matsu-janela ... arquivo.mp3").
    function pedido(args) {
        var arquivos = [];
        for (var i = 0; i < args.length; i++) {
            var a = args[i];
            if (a === "--aleatorio") {
                if (lidaUmaVez)
                    tocarTudo(true);
                else
                    querAleatorio = true;
            } else if (a.indexOf("/") === 0 || a.indexOf("file://") === 0) {
                arquivos.push(a);
            } else {
                irPara(a);
            }
        }
        if (arquivos.length > 0)
            matsu.rodar("abrir", comando(["etiquetas"].concat(arquivos)));
    }
    property bool querAleatorio: false

    // ----- o que fica guardado -----
    function lerJson(nome) {
        var texto = matsu.ler(pastaDados + "/" + nome);
        if (!texto)
            return null;
        try {
            return JSON.parse(texto);
        } catch (e) {
            return null;
        }
    }
    function salvarEstado() {
        if (!restaurado)
            return;
        matsu.gravar(pastaDados + "/estado.json", JSON.stringify({
            versao: 1, fila: fila, filaOriginal: filaOriginal, indice: indice, posicao: Math.round(posicao),
            volume: volume, mudo: mudo, aleatorio: aleatorio, repetir: repetir, recentes: recentes,
            ordemMusicas: ordemMusicas, ordemAlbuns: ordemAlbuns
        }, null, 1));
    }
    function salvarDepois() {
        tempoSalvar.restart();
    }
    function salvarPlaylists() {
        mudancasPlaylists++;
        matsu.gravar(pastaDados + "/playlists.json", JSON.stringify({ versao: 1, playlists: playlists }, null, 1));
    }
    // Volta como estava ao fechar: a fila, a música (pausada) e a posição.
    function restaurar() {
        restaurado = true;
        var p = lerJson("playlists.json");
        if (p && p.playlists)
            playlists = p.playlists;
        var e = lerJson("estado.json");
        if (e) {
            volume = e.volume !== undefined ? e.volume : 70;
            mudo = !!e.mudo;
            repetir = e.repetir || "nao";
            aleatorio = !!e.aleatorio;
            ordemMusicas = e.ordemMusicas || "titulo";
            ordemAlbuns = e.ordemAlbuns || "nome";
            recentes = (e.recentes || []).filter(function (r) { return !!porCaminho[r.caminho]; });
            var f = (e.fila || []).filter(function (c) { return !!musicaDe(c); });
            var atualAntes = (e.fila || [])[e.indice];
            if (f.length > 0) {
                fila = f;
                filaOriginal = (e.filaOriginal || f).filter(function (c) { return !!musicaDe(c); });
                var i = f.indexOf(atualAntes);
                indice = i >= 0 ? i : 0;
                carregar(false, i >= 0 ? (e.posicao || 0) : 0);
            }
        }
        if (querAleatorio) {
            querAleatorio = false;
            tocarTudo(true);
        }
    }

    Timer {
        id: tempoSalvar
        interval: 1500
        onTriggered: janela.salvarEstado()
    }
    // Tocando, a posição é guardada de vez em quando (se o computador desligar de repente).
    Timer {
        interval: 15000
        running: janela.tocando
        repeat: true
        onTriggered: janela.salvarEstado()
    }
    onClosing: salvarEstado()

    // ----- as playlists -----
    function playlistDe(id) {
        for (var i = 0; i < playlists.length; i++)
            if (playlists[i].id === id)
                return playlists[i];
        return null;
    }
    function musicasDaPlaylist(p) {
        var r = [];
        if (!p)
            return r;
        for (var i = 0; i < p.musicas.length; i++) {
            var m = musicaDe(p.musicas[i]);
            if (m)
                r.push(m);
        }
        return r;
    }
    function criarPlaylist(nome, lista) {
        var p = { id: "p" + Date.now().toString(36) + Math.floor(Math.random() * 1000), nome: nome, musicas: lista || [], criada: Date.now() };
        playlists = playlists.concat([p]);
        salvarPlaylists();
        if (lista && lista.length > 0)
            avisoRapido(t("Adicionada a “" + nome + "”", "Added to “" + nome + "”"), "certo");
        return p.id;
    }
    function renomearPlaylist(id, nome) {
        playlists = playlists.map(function (p) { return p.id === id ? Object.assign({}, p, { nome: nome }) : p; });
        salvarPlaylists();
    }
    function apagarPlaylist(id) {
        var antes = playlists.slice();
        var p = playlistDe(id);
        playlists = playlists.filter(function (x) { return x.id !== id; });
        if (playlistAberta === id)
            playlistAberta = "";
        salvarPlaylists();
        avisoRapido(t("Playlist apagada", "Playlist deleted"), "", t("Desfazer", "Undo"), function () {
            janela.playlists = antes;
            janela.salvarPlaylists();
        });
    }
    function adicionarNaPlaylist(id, lista) {
        var p = playlistDe(id);
        if (!p)
            return;
        var novas = lista.filter(function (c) { return p.musicas.indexOf(c) < 0; });
        var antes = playlists.slice();
        playlists = playlists.map(function (x) { return x.id === id ? Object.assign({}, x, { musicas: x.musicas.concat(novas) }) : x; });
        salvarPlaylists();
        if (novas.length === 0)
            avisoRapido(t("Já está em “" + p.nome + "”", "Already in “" + p.nome + "”"));
        else
            avisoRapido(t("Adicionada a “" + p.nome + "”", "Added to “" + p.nome + "”"), "certo", t("Desfazer", "Undo"), function () {
                janela.playlists = antes;
                janela.salvarPlaylists();
            });
    }
    function tirarDaPlaylist(id, indices) {
        playlists = playlists.map(function (x) {
            return x.id === id ? Object.assign({}, x, { musicas: x.musicas.filter(function (c, n) { return indices.indexOf(n) < 0; }) }) : x;
        });
        salvarPlaylists();
    }

    // ----- navegar -----
    function abrirAlbum(chave) {
        tocandoAgoraAberto = false;
        irPara("albuns");
        albumAberto = chave;
    }
    function abrirArtista(chave) {
        tocandoAgoraAberto = false;
        irPara("artistas");
        artistaAberto = chave;
    }
    function abrirPlaylist(id) {
        irPara("playlists");
        playlistAberta = id;
    }
    function abrirPasta(caminho) {
        // O gerenciador de arquivos do Matsu; sem ele, o padrão do sistema.
        if (!matsu.soltar(["matsu-arquivos", caminho]))
            matsu.soltar(["xdg-open", caminho]);
    }
    function abrirPastaMusica() {
        if (!matsu.existe(pastaMusica))
            matsu.rodar("criar-pasta", ["mkdir", "-p", pastaMusica]);
        else
            abrirPasta(pastaMusica);
    }

    // ----- o menu do botão direito das músicas -----
    property var menuContexto: ({})
    function menuMusicas(item, x, y, lista, contexto) {
        menuContexto = Object.assign({ lista: lista }, contexto || {});
        var um = lista.length === 1 ? musicaDe(lista[0]) : null;
        var itens = [
            { id: "tocar", nome: t("Tocar", "Play"), icone: ic("tocar") },
            { id: "seguir", nome: t("Tocar a seguir", "Play next"), icone: ic("tocar-seguir") },
            { id: "fila", nome: t("Adicionar à fila", "Add to queue"), icone: ic("fila") },
            { id: "playlist", nome: t("Adicionar a uma playlist…", "Add to a playlist…"), icone: ic("playlist") }
        ];
        if (um && !contexto.semAlbum)
            itens.push({ id: "album", nome: t("Ir para o álbum", "Go to album"), icone: ic("album"), separador: true });
        if (um && !contexto.semArtista)
            itens.push({ id: "artista", nome: t("Ir para o artista", "Go to artist"), icone: ic("artista"), separador: !!contexto.semAlbum });
        if (um)
            itens.push({ id: "pasta", nome: t("Mostrar na pasta", "Show in folder"), icone: "matsu-pasta-symbolic" });
        if (contexto.playlist)
            itens.push({ id: "tirar-playlist", nome: t("Tirar da playlist", "Remove from playlist"), icone: "matsu-lixeira-symbolic", perigo: true, separador: true });
        if (contexto.filaIndice !== undefined)
            itens.push({ id: "tirar-fila", nome: t("Tirar da fila", "Remove from queue"), icone: "matsu-fechar-symbolic", perigo: true, separador: true });
        menuMusica.itens = itens;
        menuMusica.abrirEm(item, x, y);
    }
    function escolhaMenu(id) {
        var c = menuContexto;
        var um = c.lista.length === 1 ? musicaDe(c.lista[0]) : null;
        if (id === "tocar")
            tocarLista(c.lista, 0, false);
        else if (id === "seguir")
            tocarASeguir(c.lista);
        else if (id === "fila")
            adicionarAFila(c.lista);
        else if (id === "playlist") {
            var itens = playlists.map(function (p) { return { id: p.id, nome: p.nome, icone: ic("playlist") }; });
            itens.push({ id: "__nova", nome: t("Nova playlist…", "New playlist…"), icone: "matsu-mais-symbolic", separador: playlists.length > 0 });
            menuPlaylist.itens = itens;
            menuPlaylist.x = menuMusica.x;
            menuPlaylist.y = menuMusica.y;
            menuPlaylist.open();
        } else if (id === "album" && um)
            abrirAlbum(um.chaveAlbum);
        else if (id === "artista" && um)
            abrirArtista(um.chaveArtista);
        else if (id === "pasta" && um)
            abrirPasta(um.caminho.substring(0, um.caminho.lastIndexOf("/")));
        else if (id === "tirar-playlist")
            tirarDaPlaylist(c.playlist, c.indices || []);
        else if (id === "tirar-fila")
            removerDaFila(c.filaIndice);
    }
    function novaPlaylist(lista) {
        dialogoNome.pedir(t("Nova playlist", "New playlist"), "", t("Criar", "Create"), function (nome) {
            var id = janela.criarPlaylist(nome, lista || []);
            if (!lista || lista.length === 0)
                janela.abrirPlaylist(id);
        });
    }

    MenuMatsu {
        id: menuMusica
        onEscolhido: (id) => janela.escolhaMenu(id)
    }
    MenuMatsu {
        id: menuPlaylist
        onEscolhido: (id) => {
            if (id === "__nova")
                janela.novaPlaylist(janela.menuContexto.lista);
            else
                janela.adicionarNaPlaylist(id, janela.menuContexto.lista);
        }
    }
    Dialogo {
        id: dialogo
    }
    DialogoNome {
        id: dialogoNome
    }

    // ----- o player de verdade -----
    MediaPlayer {
        id: player
        audioOutput: AudioOutput {
            id: saida
            // A curva cúbica soa natural (como o controle de volume do sistema).
            volume: janela.mudo ? 0 : Math.pow(janela.volume / 100, 3)
        }
        onPositionChanged: {
            if (janela.posicaoPendente < 0)
                janela.posicao = player.position;
        }
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia)
                janela.terminou();
            else if ((mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia) && janela.posicaoPendente >= 0) {
                if (seekable)
                    setPosition(janela.posicaoPendente);
                janela.posicao = janela.posicaoPendente;
                janela.posicaoPendente = -1;
            }
        }
        onPlaybackStateChanged: janela.enviarMpris(true)
        onErrorOccurred: (erro, texto) => {
            if (janela.atual)
                janela.avisoRapido(janela.t("Não deu para tocar “" + janela.atual.titulo + "”", "Couldn't play “" + janela.atual.titulo + "”"), "erro");
        }
    }

    // ----- MPRIS: os controles de mídia do Plasma e as teclas do teclado -----
    property bool mprisLigado: false
    property int mprisTentativas: 0
    function iniciarMpris() {
        // Sem -S: o dbus-python e o PyGObject ficam nos pacotes do sistema.
        matsu.iniciar("mpris", ["/usr/bin/python3", "-I", ajudanteMpris]);
    }
    function enviarMpris(buscou) {
        if (!mprisLigado)
            return;
        var m = atual;
        matsu.escrever("mpris", JSON.stringify({
            estado: !m ? "Stopped" : (tocando ? "Playing" : (player.playbackState === MediaPlayer.PausedState || posicao > 0 ? "Paused" : "Stopped")),
            titulo: m ? m.titulo : "", artista: m ? m.artista : "", artistaAlbum: m ? m.artistaAlbum : "",
            album: m ? m.album : "", capa: m ? m.capa : "", id: m ? m.caminho : "",
            duracao: Math.round(duracao), posicao: Math.round(posicao), volume: mudo ? 0 : volume / 100,
            aleatorio: aleatorio, repetir: repetir, proxima: indice + 1 < fila.length || (repetir === "tudo" && fila.length > 0),
            anterior: fila.length > 0, buscou: !!buscou
        }));
    }
    function pedidoMpris(d) {
        if (d.ok === true) {
            mprisLigado = true;
            mprisTentativas = 0;
            enviarMpris(true);
            return;
        }
        if (d.ok === false) {
            mprisLigado = false;
            return;
        }
        switch (d.cmd) {
        case "PlayPause": tocarPausar(); break;
        case "Play": if (!tocando) tocarPausar(); break;
        case "Pause": player.pause(); break;
        case "Stop": player.stop(); posicao = 0; enviarMpris(true); break;
        case "Next": proxima(false); break;
        case "Previous": anterior(); break;
        case "Seek": buscarMs(posicao + d.offset); break;
        case "SetPosition": buscarMs(d.posicao); break;
        case "Volume": mudarVolume(d.valor * 100); break;
        case "Shuffle": if (d.valor !== aleatorio) alternarAleatorio(); break;
        case "Repetir": repetir = d.valor; salvarDepois(); enviarMpris(false); break;
        case "Raise": janela.show(); janela.raise(); janela.requestActivate(); break;
        case "Quit": janela.close(); break;
        case "Abrir": pedido([d.uri]); break;
        }
    }
    Timer {
        id: religarMpris
        interval: 3000
        onTriggered: janela.iniciarMpris()
    }
    onVolumeChanged: enviarMpris(false)
    onMudoChanged: enviarMpris(false)

    Connections {
        target: matsu
        function onLinha(chave, texto) {
            if (chave === "biblioteca") {
                janela.receberBiblioteca(texto);
            } else if (chave === "mpris") {
                try {
                    janela.pedidoMpris(JSON.parse(texto));
                } catch (e) {
                }
            }
        }
        function onParou(chave, codigo) {
            if (chave === "biblioteca") {
                janela.lendo = false;
            } else if (chave === "mpris") {
                janela.mprisLigado = false;
                // 3: falta o dbus-python ou o PyGObject; o app segue sem os controles do Plasma.
                if (codigo !== 3 && janela.mprisTentativas < 3) {
                    janela.mprisTentativas++;
                    religarMpris.start();
                }
            }
        }
        function onPronto(chave, saida, codigo) {
            var d = null;
            try {
                d = JSON.parse(saida);
            } catch (e) {
                d = null;
            }
            if (chave.indexOf("onda:") === 0) {
                var caminho = chave.substring(5);
                var o = Object.assign({}, janela.ondas);
                o[caminho] = d && d.amostras ? d.amostras : [];
                janela.ondas = o;
            } else if (chave === "abrir" && d && d.musicas && d.musicas.length > 0) {
                var ext = Object.assign({}, janela.externas);
                for (var i = 0; i < d.musicas.length; i++)
                    if (!janela.porCaminho[d.musicas[i].caminho])
                        ext[d.musicas[i].caminho] = janela.preparar(d.musicas[i]);
                janela.externas = ext;
                janela.tocarLista(d.musicas.map(function (m) { return m.caminho; }), 0, false);
            } else if (chave === "criar-pasta") {
                janela.abrirPasta(janela.pastaMusica);
            }
        }
        function onPedido(argumentos) {
            janela.pedido(argumentos);
        }
    }

    // Ao voltar para a janela, lê a pasta de novo (rápido: o que não mudou vem do cache).
    onActiveChanged: {
        if (active && lidaUmaVez && !lendo && Date.now() - ultimaLeitura > 20000) {
            lendo = true;
            lerBiblioteca();
        }
    }

    Component.onCompleted: {
        lerBiblioteca();
        iniciarMpris();
        if (matsu.argumentos.length > 0)
            pedido(matsu.argumentos);
    }

    // ----- atalhos -----
    Shortcut {
        sequences: ["Space"]
        onActivated: janela.tocarPausar()
    }
    Shortcut {
        sequences: ["Ctrl+Right"]
        onActivated: janela.proxima(false)
    }
    Shortcut {
        sequences: ["Ctrl+Left"]
        onActivated: janela.anterior()
    }
    Shortcut {
        sequences: ["Ctrl+Up"]
        onActivated: janela.mudarVolume(janela.volume + 5)
    }
    Shortcut {
        sequences: ["Ctrl+Down"]
        onActivated: janela.mudarVolume(janela.volume - 5)
    }
    Shortcut {
        sequences: ["Escape"]
        enabled: janela.tocandoAgoraAberto
        onActivated: janela.tocandoAgoraAberto = false
    }
    Shortcut {
        sequences: ["Ctrl+N"]
        onActivated: janela.novaPlaylist([])
    }

    // ----- o Tocando agora, por cima de tudo menos a barra de título -----
    TocandoAgora {
        z: 40
        x: 1
        width: parent.width - 2
        y: Math.round(janela.gu * 2.7)
        height: parent.height - y - 1
    }
}
