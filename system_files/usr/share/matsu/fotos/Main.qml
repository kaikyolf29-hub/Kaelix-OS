// Fotos do Matsu (como o Fotos do Windows 11 e o do Mac): a galeria das fotos da
// pasta Imagens, agrupadas por mês, as favoritas (o coração), os álbuns (cada
// subpasta de Imagens), as capturas de tela e os vídeos. Clicar numa foto abre o
// visualizador, que sai da miniatura com zoom, num fundo escuro: anterior e
// próxima, zoom, girar, favoritar, informações, apresentação de slides, papel de
// parede, copiar e mandar para a Lixeira (com Desfazer).
//
// É o app padrão para abrir imagens: o Arquivos manda o arquivo (%F) e ele abre
// direto no visualizador, passando pelas outras imagens da mesma pasta.
//
// A janela de vidro é a JanelaMatsu, de ../comum. Quem varre as pastas, lê o
// tamanho e a data de cada foto e mexe na Lixeira é o ajudante.py desta pasta.
// As favoritas e o giro de cada foto (só na exibição, o arquivo não muda) ficam
// em ~/.local/share/matsu/fotos/.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

JanelaMatsu {
    id: janela

    title: visor.aberto && visor.atual ? visor.atual.nome + " — " + t("Fotos", "Photos") : t("Fotos", "Photos")
    icone: "org.matsu.fotos"
    iconeReserva: "gwenview"
    // Com o visualizador aberto, a busca sai (o Ctrl+F não rouba o teclado dele).
    dicaBusca: visorAberto ? "" : t("Buscar fotos pelo nome", "Search photos by name")
    paginas: [
        { id: "todas", icone: String(Qt.resolvedUrl("icones/fotos.svg")), nome: t("Todas as fotos", "All photos") },
        { id: "favoritas", icone: "matsu-coracao-symbolic", nome: t("Favoritas", "Favorites") },
        { id: "albuns", icone: String(Qt.resolvedUrl("icones/album.svg")), nome: t("Álbuns", "Albums") },
        { id: "capturas", icone: String(Qt.resolvedUrl("icones/captura.svg")), nome: t("Capturas de tela", "Screenshots") },
        { id: "videos", icone: String(Qt.resolvedUrl("icones/video.svg")), nome: t("Vídeos", "Videos") }
    ]
    conteudo: Qt.resolvedUrl(({ albuns: "PaginaAlbuns.qml", videos: "PaginaVideos.qml" })[pagina] || "PaginaFotos.qml")
    width: gu * 64
    height: gu * 42
    minimumWidth: gu * 40
    minimumHeight: gu * 26

    readonly property string ajudante: decodeURIComponent(String(Qt.resolvedUrl("ajudante.py")).replace("file://", ""))
    function comando(args) {
        return ["/usr/bin/python3", "-I", "-S", ajudante].concat(args);
    }

    // ----- o que o ajudante achou -----
    property bool lido: false
    property bool lendo: false
    property bool existePasta: true
    property string raiz: ""
    property var fotos: []
    property var albuns: []
    property var videos: []
    property bool temFfmpeg: false
    property real ultimaLeitura: 0
    property bool lerDeNovo: false

    // ----- o que a pessoa escolheu (guardado em ~/.local/share/matsu/fotos) -----
    readonly property string pastaDados: matsu.pasta("dados")
    property var favoritas: ({})       // caminho -> true
    property var rotacoes: ({})        // caminho -> 0, 90, 180 ou 270
    property string formaGrade: "ajustada"  // "ajustada" (linhas justificadas) ou "quadrada"
    property int nivelGrade: 2         // tamanho das miniaturas, de 0 a 4

    // ----- a página -----
    property string albumAberto: ""
    // A foto que está "voando" entre a grade e o visualizador (a miniatura dela some).
    property string fotoEmVoo: ""
    // A grade aberta diz onde está a miniatura de uma foto (para o visualizador voltar a ela).
    property var localizador: null

    onPaginaChanged: albumAberto = ""

    // A cor do miolo como ele aparece (o vidro com a camada funda por cima), para o
    // cabeçalho do mês que gruda no topo esconder as fotos que passam por baixo.
    readonly property color corPagina: {
        var f = fundo, m = miolo, a = m.a;
        var alfa = 1 - (1 - f.a) * (1 - a);
        return Qt.rgba(f.r * (1 - a) + m.r * a, f.g * (1 - a) + m.g * a, f.b * (1 - a) + m.b * a, Math.max(alfa, 0.94));
    }
    // O coração das favoritas, no rosa do Matsu (nada de vermelho de alerta).
    readonly property color corCoracao: "#ff5c8d"

    // ----- datas e números -----
    function arquivo(caminho) {
        if (!caminho)
            return "";
        if (String(caminho).indexOf("://") > 0)
            return caminho;
        return "file://" + String(caminho).split("/").map(encodeURIComponent).join("/");
    }
    function dois(n) {
        return n < 10 ? "0" + n : String(n);
    }
    function chaveMes(segundos) {
        var d = new Date(segundos * 1000);
        return d.getFullYear() + "-" + dois(d.getMonth() + 1);
    }
    function tituloMes(chave) {
        var ano = parseInt(chave.substring(0, 4));
        var mes = parseInt(chave.substring(5, 7));
        var nome = local.standaloneMonthName(mes - 1, Locale.LongFormat);
        return pt ? nome.toLowerCase() + " de " + ano : nome + " " + ano;
    }
    function dataLonga(segundos) {
        var d = new Date(segundos * 1000);
        var dia = pt ? d.getDate() + " de " + local.monthName(d.getMonth(), Locale.LongFormat).toLowerCase() + " de " + d.getFullYear()
                     : local.monthName(d.getMonth(), Locale.LongFormat) + " " + d.getDate() + ", " + d.getFullYear();
        return dia + ", " + dois(d.getHours()) + ":" + dois(d.getMinutes());
    }
    // De quando a quando são as fotos da lista (que vem da mais nova para a mais velha).
    function periodo(lista) {
        if (lista.length === 0)
            return "";
        var nova = lista[0].mes || chaveMes(lista[0].data);
        var velha = lista[lista.length - 1].mes || chaveMes(lista[lista.length - 1].data);
        if (nova === velha)
            return tituloMes(nova);
        var mesV = local.standaloneMonthName(parseInt(velha.substring(5, 7)) - 1, Locale.LongFormat);
        if (nova.substring(0, 4) === velha.substring(0, 4))
            return (pt ? mesV.toLowerCase() + " a " : mesV + t("", " to ")) + tituloMes(nova);
        return tituloMes(velha) + t(" a ", " to ") + tituloMes(nova);
    }
    function quantas(n) {
        return n === 1 ? t("1 foto", "1 photo") : num(n) + t(" fotos", " photos");
    }
    function quantosVideos(n) {
        return n === 1 ? t("1 vídeo", "1 video") : num(n) + t(" vídeos", " videos");
    }
    // A pasta como a pessoa reconhece: "Imagens › Viagem" em vez do caminho todo.
    function pastaBonita(pasta) {
        var casa = matsu.pasta("casa");
        if (raiz && (pasta === raiz || pasta.indexOf(raiz + "/") === 0)) {
            var nomeRaiz = raiz.split("/").pop();
            var resto = pasta.substring(raiz.length + 1);
            return resto ? nomeRaiz + " › " + resto.split("/").join(" › ") : nomeRaiz;
        }
        if (casa && pasta.indexOf(casa + "/") === 0)
            return pasta.substring(casa.length + 1).split("/").join(" › ");
        return pasta;
    }
    function nomeTipo(tipo) {
        var t2 = String(tipo || "").toUpperCase();
        return ({ JPG: "JPEG", JPE: "JPEG", JFIF: "JPEG", TIF: "TIFF", SVGZ: "SVG" })[t2] || t2;
    }
    function busca2(lista) {
        var b = simples(busca.trim());
        if (b.length === 0)
            return lista;
        return lista.filter(function (f) {
            return f.chave.indexOf(b) >= 0;
        });
    }

    // ----- favoritas, giro e ajustes -----
    function ehFavorita(caminho) {
        return favoritas[caminho] === true;
    }
    function alternarFavorita(caminho) {
        var f = Object.assign({}, favoritas);
        if (f[caminho])
            delete f[caminho];
        else
            f[caminho] = true;
        favoritas = f;
        matsu.gravar(pastaDados + "/favoritas.json", JSON.stringify(Object.keys(f), null, 1));
        return f[caminho] === true;
    }
    function giroDe(caminho) {
        return rotacoes[caminho] || 0;
    }
    function girar(caminho, passo) {
        var r = Object.assign({}, rotacoes);
        var novo = (((r[caminho] || 0) + passo) % 360 + 360) % 360;
        if (novo === 0)
            delete r[caminho];
        else
            r[caminho] = novo;
        rotacoes = r;
        matsu.gravar(pastaDados + "/rotacoes.json", JSON.stringify(r, null, 1));
    }
    function guardarAjustes() {
        matsu.gravar(pastaDados + "/ajustes.json", JSON.stringify({ grade: formaGrade, nivel: nivelGrade }));
    }
    function lerGuardados() {
        try {
            var lista = JSON.parse(matsu.ler(pastaDados + "/favoritas.json") || "[]");
            var f = {};
            for (var i = 0; i < lista.length; i++)
                f[lista[i]] = true;
            favoritas = f;
        } catch (e) {
            favoritas = {};
        }
        try {
            rotacoes = JSON.parse(matsu.ler(pastaDados + "/rotacoes.json") || "{}");
        } catch (e) {
            rotacoes = {};
        }
        try {
            var a = JSON.parse(matsu.ler(pastaDados + "/ajustes.json") || "{}");
            if (a.grade === "quadrada" || a.grade === "ajustada")
                formaGrade = a.grade;
            if (a.nivel >= 0 && a.nivel <= 4)
                nivelGrade = a.nivel;
        } catch (e) {}
    }

    // ----- ler as pastas -----
    function carregar() {
        if (lendo) {
            lerDeNovo = true;
            return;
        }
        lendo = true;
        matsu.rodar("listar", comando(["listar", matsu.pasta("imagens"), matsu.pasta("videos")]));
    }
    function preparar(lista) {
        for (var i = 0; i < lista.length; i++) {
            lista[i].chave = simples(lista[i].nome + " " + (lista[i].album || ""));
            lista[i].mes = chaveMes(lista[i].data);
        }
        return lista;
    }
    function receberLista(texto) {
        var d;
        try {
            d = JSON.parse(texto);
        } catch (e) {
            lido = true;
            return;
        }
        if (d.idioma)
            lingua = d.idioma;
        if (d.vidro && JSON.stringify(d.vidro) !== JSON.stringify(vidroConf))
            vidroConf = d.vidro;
        raiz = d.raiz || "";
        existePasta = d.existe !== false;
        temFfmpeg = !!d.temFfmpeg;
        // Só troca as listas se algo mudou (a grade não pisca ao voltar para a janela).
        var novas = preparar(d.fotos || []);
        if (JSON.stringify(novas) !== JSON.stringify(fotos))
            fotos = novas;
        if (JSON.stringify(d.albuns || []) !== JSON.stringify(albuns))
            albuns = d.albuns || [];
        var vids = preparar(d.videos || []);
        if (JSON.stringify(vids) !== JSON.stringify(videos))
            videos = vids;
        lido = true;
        ultimaLeitura = Date.now();
        // Capas dos vídeos que ainda não têm (com o ffmpeg; sem ele, ficam com o desenho).
        var semCapa = videos.filter(function (v) { return !v.capa; }).map(function (v) { return v.caminho; });
        if (semCapa.length > 0 && temFfmpeg)
            matsu.rodar("capas", comando(["capas"].concat(semCapa.slice(0, 40))));
    }

    // ----- abrir imagens (pela grade ou pelo Arquivos) -----
    readonly property bool visorAberto: visor.aberto
    property bool semSom: false
    property int visibilidadeAntes: Window.Windowed
    function alternarTelaCheia() {
        if (visibility === Window.FullScreen) {
            if (visibilidadeAntes === Window.Maximized)
                showMaximized();
            else
                showNormal();
        } else {
            visibilidadeAntes = visibility;
            showFullScreen();
        }
    }
    function abrirVisor(lista, indice, origem) {
        visor.abrir(lista, indice, origem);
    }
    // Apresentação de slides de uma lista, a partir de uma foto.
    function apresentar(lista, indice) {
        if (lista.length === 0)
            return;
        visor.abrir(lista, indice, null);
        visor.apresentar();
    }
    function abrirArquivos(argumentos) {
        for (var i = 0; i < argumentos.length; i++) {
            var a = String(argumentos[i]);
            if (a.indexOf("file://") === 0)
                a = decodeURIComponent(a.substring(7));
            if (a.length > 0 && a.charAt(0) === "/" && matsu.existe(a)) {
                visor.abrirArquivo(a);
                matsu.rodar("vizinhas", comando(["vizinhas", a]));
                return true;
            }
        }
        return false;
    }

    // ----- ações sobre uma foto -----
    function usarComoPapel(caminho) {
        if (matsu.soltar(["/usr/libexec/matsu/matsu-central", "papel", caminho]))
            avisoRapido(t("Papel de parede trocado", "Wallpaper changed"), "certo");
        else
            avisoRapido(t("Não deu para trocar o papel de parede", "Couldn't change the wallpaper"), "erro");
    }
    function mostrarNaPasta(caminho) {
        var pasta = caminho.substring(0, caminho.lastIndexOf("/")) || "/";
        if (!matsu.soltar(["matsu-arquivos", pasta]) && !matsu.soltar(["xdg-open", pasta]))
            avisoRapido(t("Não deu para abrir a pasta", "Couldn't open the folder"), "erro");
    }
    function abrirPasta(pasta) {
        if (!matsu.soltar(["matsu-arquivos", pasta]) && !matsu.soltar(["xdg-open", pasta]))
            avisoRapido(t("Não deu para abrir a pasta", "Couldn't open the folder"), "erro");
    }
    property string copiando: ""
    function copiar(caminho) {
        copiando = caminho;
        matsu.rodar("copiar", comando(["copiar", caminho]));
    }
    // Sem wl-copy nem xclip: copia o caminho do arquivo como texto (colar no Arquivos funciona).
    TextEdit {
        id: copiador
        visible: false
    }
    function copiarTexto(texto) {
        copiador.text = texto;
        copiador.selectAll();
        copiador.copy();
        copiador.text = "";
    }

    // Lixeira: pergunta antes, manda pelo ajudante e oferece o Desfazer.
    property var apagando: ({})        // caminho -> { foto, posicao no visualizador }
    function apagar(foto) {
        var video = foto.video === true;
        dialogo.perguntar({
            titulo: video ? t("Mover o vídeo para a Lixeira?", "Move the video to the Trash?") : t("Mover a foto para a Lixeira?", "Move the photo to the Trash?"),
            texto: t("“" + foto.nome + "” vai para a Lixeira. Dá para restaurar depois, se mudar de ideia.",
                     "“" + foto.nome + "” goes to the Trash. You can restore it later if you change your mind."),
            sim: t("Mover para a Lixeira", "Move to Trash"),
            perigo: true
        }, function () {
            var a = Object.assign({}, apagando);
            a[foto.caminho] = { foto: foto, posicao: visor.posicaoDe(foto.caminho) };
            apagando = a;
            matsu.rodar("lixeira:" + foto.caminho, comando(["lixeira", foto.caminho]));
        });
    }
    function tirarDasListas(caminho) {
        fotos = fotos.filter(function (f) { return f.caminho !== caminho; });
        videos = videos.filter(function (f) { return f.caminho !== caminho; });
        visor.tirar(caminho);
    }
    function aoApagar(caminho, texto) {
        var info = apagando[caminho];
        var a = Object.assign({}, apagando);
        delete a[caminho];
        apagando = a;
        var r = {};
        try {
            r = JSON.parse(texto);
        } catch (e) {}
        if (!r.ok) {
            avisoRapido(r.erro === "sem-lixeira" ? t("Não achei a Lixeira (falta o gio e o kioclient)", "Couldn't find the Trash (gio and kioclient are missing)")
                                                 : t("Não deu para mover para a Lixeira", "Couldn't move to the Trash"), "erro");
            return;
        }
        tirarDasListas(caminho);
        var nome = info ? info.foto.nome : caminho.split("/").pop();
        if (r.desfazer) {
            avisoRapido(t("“" + nome + "” foi para a Lixeira", "“" + nome + "” moved to the Trash"), "certo", t("Desfazer", "Undo"), function () {
                if (info)
                    restaurando[caminho] = info;
                matsu.rodar("restaurar:" + caminho, comando(["restaurar", caminho]));
            });
        } else {
            avisoRapido(t("“" + nome + "” foi para a Lixeira", "“" + nome + "” moved to the Trash"), "certo");
        }
    }
    property var restaurando: ({})
    function aoRestaurar(caminho, texto) {
        var r = {};
        try {
            r = JSON.parse(texto);
        } catch (e) {}
        var info = restaurando[caminho];
        delete restaurando[caminho];
        if (!r.ok) {
            avisoRapido(t("Não deu para tirar da Lixeira", "Couldn't restore from the Trash"), "erro");
            return;
        }
        if (info)
            visor.devolver(info.foto, info.posicao);
        avisoRapido(t("Foto de volta", "Photo restored"), "certo");
        carregar();
    }

    Connections {
        target: matsu
        function onPronto(chave, saida, codigo) {
            if (chave === "listar") {
                janela.lendo = false;
                janela.receberLista(saida);
                if (janela.lerDeNovo) {
                    janela.lerDeNovo = false;
                    janela.carregar();
                }
            } else if (chave === "vizinhas") {
                try {
                    var d = JSON.parse(saida);
                    if (d.idioma)
                        janela.lingua = d.idioma;
                    visor.receberVizinhas(janela.preparar(d.fotos || []), d.arquivo);
                } catch (e) {}
            } else if (chave === "capas") {
                try {
                    var capas = JSON.parse(saida).capas || {};
                    var lista = janela.videos.slice();
                    var mudou = false;
                    for (var i = 0; i < lista.length; i++) {
                        if (capas[lista[i].caminho] && !lista[i].capa) {
                            lista[i] = Object.assign({}, lista[i], { capa: capas[lista[i].caminho] });
                            mudou = true;
                        }
                    }
                    if (mudou)
                        janela.videos = lista;
                } catch (e) {}
            } else if (chave === "copiar") {
                var r = {};
                try {
                    r = JSON.parse(saida);
                } catch (e) {}
                if (r.ok) {
                    janela.avisoRapido(janela.t("Imagem copiada", "Image copied"), "certo");
                } else {
                    janela.copiarTexto(janela.copiando);
                    janela.avisoRapido(janela.t("Caminho do arquivo copiado", "File path copied"), "certo");
                }
            } else if (chave.indexOf("lixeira:") === 0) {
                janela.aoApagar(chave.substring(8), saida);
            } else if (chave.indexOf("restaurar:") === 0) {
                janela.aoRestaurar(chave.substring(10), saida);
            }
        }
        function onPedido(argumentos) {
            janela.abrirArquivos(argumentos);
        }
    }

    // Voltando para a janela, relê as pastas (fotos novas, capturas que acabaram de tirar).
    onActiveChanged: if (active && lido && Date.now() - ultimaLeitura > 15000) carregar()

    Component.onCompleted: {
        lerGuardados();
        abrirArquivos(matsu.argumentos);
        carregar();
    }

    // F5 relê as pastas.
    Shortcut {
        sequences: [StandardKey.Refresh, "Ctrl+R"]
        enabled: !visor.aberto
        onActivated: janela.carregar()
    }

    // Resumo embaixo da lista de assuntos.
    rodapeLateral: Component {
        ColumnLayout {
            spacing: 2
            visible: janela.lido && janela.fotos.length > 0
            Texto {
                Layout.fillWidth: true
                text: janela.quantas(janela.fotos.length)
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.weight: Font.DemiBold
                opacity: 0.8
                elide: Text.ElideRight
            }
            Texto {
                Layout.fillWidth: true
                text: {
                    var total = 0;
                    for (var i = 0; i < janela.fotos.length; i++)
                        total += janela.fotos[i].tamanho;
                    return janela.bytes(total) + (janela.albuns.length > 0 ? " · " + (janela.albuns.length === 1 ? janela.t("1 álbum", "1 album")
                                                    : janela.num(janela.albuns.length) + janela.t(" álbuns", " albums")) : "");
                }
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.55
                elide: Text.ElideRight
            }
        }
    }

    Dialogo {
        id: dialogo
    }

    // O visualizador, por cima de tudo (menos do aviso embaixo e das bordas da janela).
    Visualizador {
        id: visor
        anchors.fill: parent
        z: 80
    }
}
