// Câmera do Matsu (como a Câmera do Windows 11 e o Photo Booth do Mac): o visor
// com a imagem da câmera, de cantos redondos, e a coluna à direita com o seletor
// Foto/Vídeo, o botão de disparar, o temporizador, a grade e a miniatura da
// última foto (que abre no app Fotos). As fotos vão para ~/Imagens/Câmera e os
// vídeos para ~/Vídeos/Câmera.
//
// A janela é a JanelaMatsu (de ../comum), sem a lista de assuntos (sem páginas,
// ela esconde a lista e o miolo ocupa a largura toda): o palco fica em cima do
// miolo, embaixo da barra de título com as bolinhas.
//
// A câmera em si é o QtMultimedia (CaptureSession, Camera, ImageCapture,
// MediaRecorder). O ajudante.py desta pasta diz a língua e o vidro, cria as
// pastas e acha a última foto ou vídeo.
//
// Modo de demonstração (só para as fotos da prévia, onde não há câmera):
//   matsu-janela org.matsu.camera .../Main.qml --demo [imagem]
// mostra uma imagem (o papel de parede do Matsu, se não disser outra) no lugar
// da câmera, com duas câmeras e um microfone de mentira. A foto vira um arquivo
// de verdade (a imagem do visor); o vídeo não é gravado.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtMultimedia
import org.kde.kirigami as Kirigami
import "../comum"

JanelaMatsu {
    id: janela

    title: t("Câmera", "Camera")
    icone: "org.matsu.camera"
    iconeReserva: "camera-photo"
    paginas: []
    // O miolo com os dois cantos de cima redondos, como um palco.
    raioMiolo: Math.round(gu * 0.5)
    width: gu * 62
    height: gu * 40
    minimumHeight: gu * 28

    readonly property string ajudante: decodeURIComponent(String(Qt.resolvedUrl("ajudante.py")).replace("file://", ""))
    function comando(args) {
        return ["/usr/bin/python3", "-I", "-S", ajudante].concat(args);
    }

    // ----- demonstração (prévia sem câmera) -----
    readonly property int argDemo: matsu.argumentos.indexOf("--demo")
    readonly property bool demo: argDemo >= 0
    readonly property string imagemDemoPedida: demo && matsu.argumentos.length > argDemo + 1 && matsu.argumentos[argDemo + 1].indexOf("--") !== 0
                                               ? matsu.argumentos[argDemo + 1] : ""
    readonly property string imagemDemo: imagemDemoPedida !== "" ? urlDe(imagemDemoPedida)
        : Qt.resolvedUrl("../../wallpapers/Matsu/contents/images" + (cameraAtual && cameraAtual.id === "demo-usb" ? "" : "_dark") + "/3840x2160.png")
    readonly property var formatosDemo: [
        { resolution: { width: 1920, height: 1080 }, maxFrameRate: 30, pixelFormat: 1 },
        { resolution: { width: 1280, height: 720 }, maxFrameRate: 30, pixelFormat: 1 },
        { resolution: { width: 640, height: 480 }, maxFrameRate: 30, pixelFormat: 1 }
    ]
    readonly property var camerasDemo: [
        { id: "demo-integrada", nome: t("Câmera integrada", "Built-in camera"), padrao: true, dispositivo: null, formatos: formatosDemo },
        { id: "demo-usb", nome: "Webcam USB", padrao: false, dispositivo: null, formatos: formatosDemo }
    ]

    // ----- ajustes (guardados em ~/.config/matsu/camera.json) -----
    property string modo: "foto"
    property int temporizador: 0
    property bool grade: false
    property bool espelhar: true
    property bool somObturador: true
    property bool gravarSom: true
    property string cameraEscolhida: ""
    property string microfoneEscolhido: ""
    property string resolucao: ""
    property bool ajustesLidos: false

    // ----- pastas e a última foto -----
    property string pastaFotos: ""
    property string pastaVideos: ""
    property string pastaCapas: ""
    property var ultima: null
    property var reservados: ({})

    // ----- o que está acontecendo -----
    property string estado: "parado"        // parado, contando, gravando
    property int contagem: 0
    property bool temImagem: false
    property real ignorarAte: 0
    property string erro: ""                // "", ocupada, permissao, semResposta, falhou
    property string erroTexto: ""
    property bool procurando: false
    property bool painelAberto: false
    property string caminhoGravando: ""
    property real inicioGravacao: 0
    property string tempoGravado: "00:00"
    property bool somNaGravacao: false
    property var idsCameras: []
    property string idLigada: ""
    property var guardaImagem: null         // o resultado do grabToImage, vivo enquanto a imagem aparece
    property string fotoAntes: ""
    property bool fecharDepois: false

    readonly property color fundoPalco: escuro ? Qt.rgba(0.1, 0.1, 0.106, 1) : Qt.rgba(0.979, 0.979, 0.982, 1)

    // ----- câmeras e microfones -----
    function idDe(dispositivo) {
        if (!dispositivo)
            return "";
        var bruto = dispositivo.id;
        if (typeof bruto === "string" && bruto !== "")
            return bruto;
        try {
            var b = new Uint8Array(bruto);
            var s = "";
            for (var i = 0; i < b.length; i++)
                s += String.fromCharCode(b[i]);
            if (s !== "")
                return s;
        } catch (e) {
        }
        return String(dispositivo.description || "");
    }
    function listar(lista, ehCamera) {
        var r = [], nomes = {};
        for (var i = 0; i < lista.length; i++) {
            var d = lista[i];
            var nome = String(d.description || (ehCamera ? t("Câmera", "Camera") : t("Microfone", "Microphone")));
            nomes[nome] = (nomes[nome] || 0) + 1;
            if (nomes[nome] > 1)
                nome += " (" + nomes[nome] + ")";
            r.push({ id: idDe(d), nome: nome, padrao: d.isDefault, dispositivo: d, formatos: null });
        }
        return r;
    }
    function achar(lista, id) {
        var padrao = null;
        for (var i = 0; i < lista.length; i++) {
            if (lista[i].id === id && id !== "")
                return lista[i];
            if (lista[i].padrao && !padrao)
                padrao = lista[i];
        }
        return padrao || (lista.length > 0 ? lista[0] : null);
    }

    MediaDevices {
        id: dispositivos
        onVideoInputsChanged: janela.camerasMudaram()
    }

    readonly property var cameras: demo ? camerasDemo : listar(dispositivos.videoInputs, true)
    readonly property var microfones: demo ? [{ id: "demo-mic", nome: t("Microfone integrado", "Built-in microphone"), padrao: true, dispositivo: null }]
                                           : listar(dispositivos.audioInputs, false)
    readonly property var cameraAtual: achar(cameras, cameraEscolhida)
    readonly property var microfoneAtual: achar(microfones, microfoneEscolhido)

    // ----- resoluções -----
    readonly property var formatos: !cameraAtual ? [] : (cameraAtual.dispositivo ? cameraAtual.dispositivo.videoFormats : cameraAtual.formatos)
    // O melhor formato: o de mais pixels com pelo menos 29 quadros por segundo (o mesmo critério do Qt).
    function melhorFormato(lista, largura, altura) {
        var melhor = null, nota = null;
        for (var i = 0; i < lista.length; i++) {
            var f = lista[i];
            var r = f.resolution;
            if (f.pixelFormat === 0 || r.width <= 0 || (largura && (r.width !== largura || r.height !== altura)))
                continue;
            var n = [Math.min(f.maxFrameRate, 29), r.width * r.height, f.maxFrameRate];
            if (!melhor || n[0] > nota[0] || (n[0] === nota[0] && (n[1] > nota[1] || (n[1] === nota[1] && n[2] > nota[2])))) {
                melhor = f;
                nota = n;
            }
        }
        return melhor;
    }
    function nomeResolucao(f) {
        var w = f.resolution.width, h = f.resolution.height;
        var apelido = ({ "3840x2160": "4K", "2560x1440": "QHD", "1920x1080": "Full HD", "1280x720": "HD" })[w + "x" + h];
        var s = w + " × " + h + (apelido ? " · " + apelido : "");
        if (f.maxFrameRate < 24)
            s += " · " + num(f.maxFrameRate, 0) + " " + t("qps", "fps");
        return s;
    }
    readonly property var resolucoes: {
        var r = [], vistos = {};
        var auto = melhorFormato(formatos);
        r.push({ id: "auto", nome: t("Automática", "Automatic") + (auto ? " (" + auto.resolution.width + " × " + auto.resolution.height + ")" : "") });
        var lista = [];
        for (var i = 0; i < formatos.length; i++) {
            var res = formatos[i].resolution;
            var chave = res.width + "x" + res.height;
            if (vistos[chave] || res.width <= 0)
                continue;
            vistos[chave] = true;
            var f = melhorFormato(formatos, res.width, res.height);
            if (f)
                lista.push(f);
        }
        lista.sort((a, b) => b.resolution.width * b.resolution.height - a.resolution.width * a.resolution.height);
        for (var j = 0; j < Math.min(lista.length, 8); j++)
            r.push({ id: lista[j].resolution.width + "x" + lista[j].resolution.height, nome: nomeResolucao(lista[j]) });
        return r;
    }
    readonly property string resolucaoEscolhida: resolucoes.some(o => o.id === resolucao) ? resolucao : "auto"
    readonly property var formatoAtual: {
        if (resolucaoEscolhida !== "auto") {
            var p = resolucaoEscolhida.split("x");
            var f = melhorFormato(formatos, Number(p[0]), Number(p[1]));
            if (f)
                return f;
        }
        return melhorFormato(formatos);
    }
    readonly property real aspecto: {
        var s = visor.saida.sourceRect;
        if (!demo && temImagem && s.width > 0 && s.height > 0)
            return s.width / s.height;
        if (formatoAtual && formatoAtual.resolution.height > 0)
            return formatoAtual.resolution.width / formatoAtual.resolution.height;
        return 16 / 9;
    }

    function escolherCamera(id) {
        if (estado === "gravando")
            return;
        cameraEscolhida = id;
    }
    function trocarCamera() {
        if (cameras.length < 2 || estado === "gravando")
            return;
        var i = 0;
        for (var k = 0; k < cameras.length; k++)
            if (cameraAtual && cameras[k].id === cameraAtual.id)
                i = k;
        cameraEscolhida = cameras[(i + 1) % cameras.length].id;
    }
    function escolherResolucao(id) {
        resolucao = id === "auto" ? "" : id;
    }

    // ----- a câmera de verdade -----
    readonly property bool cameraLigada: !demo && cameraAtual !== null && erro === "" && (visibility !== Window.Minimized || estado === "gravando")
    readonly property bool abrindo: (cameraLigada || (demo && cameraAtual !== null)) && !temImagem
    readonly property string vazio: demo ? "" : (cameras.length === 0 ? "semCamera" : erro)

    function reiniciarImagem() {
        temImagem = false;
        ignorarAte = Date.now() + 250;
        if (demo)
            demoAbrindo.restart();
    }
    function chegouImagem() {
        if (!temImagem && Date.now() >= ignorarAte)
            temImagem = true;
    }
    function aplicarCamera() {
        var c = cameraAtual;
        if (!c) {
            idLigada = "";
            return;
        }
        if (demo) {
            if (idLigada !== c.id) {
                idLigada = c.id;
                reiniciarImagem();
            }
            return;
        }
        var mudou = false;
        if (idDe(camera.cameraDevice) !== c.id) {
            camera.cameraDevice = c.dispositivo;
            mudou = true;
        }
        idLigada = c.id;
        var f = formatoAtual;
        if (f && (mudou || camera.cameraFormat.resolution.width !== f.resolution.width
                  || camera.cameraFormat.resolution.height !== f.resolution.height
                  || camera.cameraFormat.pixelFormat !== f.pixelFormat)) {
            camera.cameraFormat = f;
            mudou = true;
        }
        if (mudou)
            reiniciarImagem();
    }
    onCameraAtualChanged: Qt.callLater(aplicarCamera)
    onFormatoAtualChanged: Qt.callLater(aplicarCamera)
    onCameraLigadaChanged: {
        if (cameraLigada)
            reiniciarImagem();
        camera.active = cameraLigada;
    }

    function falhaCamera(texto) {
        var s = String(texto || "").toLowerCase();
        erroTexto = String(texto || "");
        if (estado === "contando")
            cancelarContagem();
        if (s.indexOf("in use") >= 0 || s.indexOf("busy") >= 0)
            erro = "ocupada";
        else if (s.indexOf("permission") >= 0 || s.indexOf("denied") >= 0 || s.indexOf("access") >= 0)
            erro = "permissao";
        else
            erro = "falhou";
    }
    function tentarDeNovo() {
        procurando = true;
        fimProcura.restart();
        erro = "";
        erroTexto = "";
        camera.active = false;
        aplicarCamera();
        Qt.callLater(() => camera.active = janela.cameraLigada);
    }
    function camerasMudaram() {
        var novos = cameras.map(c => c.id);
        var entrou = novos.filter(i => idsCameras.indexOf(i) < 0);
        var saiu = idsCameras.filter(i => novos.indexOf(i) < 0);
        if (idLigada !== "" && saiu.indexOf(idLigada) >= 0) {
            if (estado === "gravando")
                pararGravacao();
            else if (estado === "contando")
                cancelarContagem();
            avisoRapido(t("A câmera foi desconectada", "The camera was disconnected"), "");
        }
        if (entrou.length > 0) {
            var nova = achar(cameras, entrou[0]);
            erro = "";
            if (idLigada === "" || saiu.indexOf(idLigada) >= 0)
                cameraEscolhida = nova.id;
            avisoRapido(t("Câmera conectada: ", "Camera connected: ") + nova.nome, "certo");
        }
        idsCameras = novos;
        Qt.callLater(aplicarCamera);
    }

    CaptureSession {
        id: sessao
        camera: Camera {
            id: camera
            onErrorOccurred: (codigo, texto) => {
                if (codigo !== Camera.NoError)
                    janela.falhaCamera(texto);
            }
        }
        imageCapture: ImageCapture {
            id: capturaFoto
            onImageCaptured: (id, previa) => janela.voar(capturaFoto.preview)
            onImageSaved: (id, arquivo) => janela.fotoSalva(arquivo)
            onErrorOccurred: (id, codigo, texto) => janela.falhaFoto(texto)
        }
        recorder: MediaRecorder {
            id: gravador
            mediaFormat {
                fileFormat: MediaFormat.MPEG4
                videoCodec: MediaFormat.VideoCodec.H264
                audioCodec: MediaFormat.AudioCodec.AAC
            }
            quality: MediaRecorder.HighQuality
            onRecorderStateChanged: (s) => janela.gravadorMudou(s)
            onErrorOccurred: (codigo, texto) => janela.falhaVideo(texto)
        }
        audioInput: janela.somNaGravacao ? entradaSom : null
        videoOutput: visor.saida
    }
    AudioInput {
        id: entradaSom
        device: janela.microfoneAtual && janela.microfoneAtual.dispositivo ? janela.microfoneAtual.dispositivo : dispositivos.defaultAudioInput
    }
    Connections {
        target: visor.saida.videoSink
        function onVideoFrameChanged() {
            if (!janela.temImagem)
                janela.chegouImagem();
        }
    }
    SoundEffect {
        id: obturador
        source: Qt.resolvedUrl("sons/obturador.wav")
        volume: 0.7
    }

    // A câmera não mandou imagem nenhuma: pode estar desligada por uma tecla do notebook.
    Timer {
        interval: 10000
        running: janela.cameraLigada && !janela.temImagem
        onTriggered: janela.erro = "semResposta"
    }
    Timer {
        id: fimProcura
        interval: 1200
        onTriggered: janela.procurando = false
    }
    Timer {
        id: demoAbrindo
        interval: 650
        onTriggered: janela.temImagem = true
    }

    // ----- disparar -----
    readonly property bool imagemPronta: temImagem && (demo || camera.active)
    readonly property bool podeDisparar: estado !== "parado"
        || (imagemPronta && pastaFotos !== "" && (modo === "video" || demo || capturaFoto.readyForCapture))

    function disparar() {
        if (estado === "contando")
            cancelarContagem();
        else if (estado === "gravando")
            pararGravacao();
        else if (podeDisparar) {
            if (temporizador > 0)
                iniciarContagem();
            else
                agir();
        }
    }
    function agir() {
        if (modo === "foto")
            tirarFoto();
        else
            iniciarGravacao();
    }
    function iniciarContagem() {
        estado = "contando";
        contagem = temporizador;
        visor.contar(temporizador);
        tique.restart();
    }
    function cancelarContagem() {
        tique.stop();
        if (estado === "contando")
            estado = "parado";
    }
    Timer {
        id: tique
        interval: 1000
        repeat: true
        onTriggered: {
            if (janela.contagem <= 1) {
                stop();
                janela.estado = "parado";
                if (janela.imagemPronta)
                    janela.agir();
            } else {
                janela.contagem--;
                visor.pularNumero();
            }
        }
    }
    function alternarModo() {
        if (estado === "parado")
            modo = modo === "foto" ? "video" : "foto";
    }
    function cicloTemporizador() {
        temporizador = ({ 0: 3, 3: 10, 10: 0 })[temporizador] || 0;
    }

    // ----- nomes e caminhos -----
    function urlDe(caminho) {
        return "file://" + String(caminho).split("/").map(encodeURIComponent).join("/");
    }
    function localDe(url) {
        var s = String(url || "");
        return s.indexOf("file://") === 0 ? decodeURIComponent(s.substring(7)) : s;
    }
    function nomeArquivo(caminho) {
        var s = String(caminho);
        return s.substring(s.lastIndexOf("/") + 1);
    }
    function curto(caminho) {
        var casa = matsu.pasta("casa");
        return casa && String(caminho).indexOf(casa + "/") === 0 ? "~" + String(caminho).substring(casa.length) : String(caminho);
    }
    // "Foto 2026-11-12 03-40-12.jpg"; se já existir (duas no mesmo segundo), "... (2).jpg".
    function nomeLivre(pasta, prefixo, ext) {
        var base = pasta + "/" + prefixo + " " + Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss");
        var c = base + "." + ext;
        for (var n = 2; matsu.existe(c) || reservados[c]; n++)
            c = base + " (" + n + ")." + ext;
        reservados[c] = true;
        return c;
    }
    function duracaoCurta(ms) {
        var s = Math.max(0, Math.floor(ms / 1000));
        var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), r = s % 60;
        function dois(x) { return x < 10 ? "0" + x : String(x); }
        return (h > 0 ? h + ":" + dois(m) : dois(m)) + ":" + dois(r);
    }

    // ----- foto -----
    function tirarFoto() {
        var caminho = nomeLivre(pastaFotos, t("Foto", "Photo"), "jpg");
        visor.piscar();
        if (somObturador)
            obturador.play();
        fotoAntes = miniatura.imediata;
        if (demo) {
            var f = formatoAtual.resolution;
            visor.imagem.grabToImage(function (r) {
                janela.guardaImagem = r;
                janela.voar(r.url);
                if (r.saveToFile(caminho))
                    janela.fotoSalva(caminho);
                else
                    janela.falhaFoto("");
            }, Qt.size(f.width, f.height));
            return;
        }
        capturaFoto.captureToFile(caminho);
    }
    function fotoSalva(arquivo) {
        delete reservados[arquivo];
        ultima = { caminho: arquivo, tipo: "foto", capa: "" };
        avisoRapido(t("Foto salva", "Photo saved"), "certo", t("Abrir", "Open"), () => janela.abrir(arquivo));
    }
    function falhaFoto(texto) {
        miniatura.imediata = fotoAntes;
        avisoRapido(t("Não deu para salvar a foto", "Couldn't save the photo") + (texto ? ": " + texto : ""), "erro");
    }

    // ----- vídeo -----
    function iniciarGravacao() {
        caminhoGravando = nomeLivre(pastaVideos, t("Vídeo", "Video"), "mp4");
        if (demo) {
            inicioGravacao = Date.now();
            estado = "gravando";
            return;
        }
        gravador.outputLocation = urlDe(caminhoGravando);
        somNaGravacao = gravarSom && microfones.length > 0;
        gravador.record();
    }
    function pararGravacao() {
        var caminho = caminhoGravando;
        var capa = pastaCapas !== "" ? pastaCapas + "/" + nomeArquivo(caminho) + ".jpg" : "";
        fotoAntes = miniatura.imediata;
        // A capa é a imagem do visor agora (a câmera ainda manda imagem).
        visor.imagem.grabToImage(function (r) {
            janela.guardaImagem = r;
            janela.voar(r.url);
            if (capa !== "" && !janela.demo)
                r.saveToFile(capa);
        }, Qt.size(Math.round(480 * aspecto), 480));
        if (demo)
            terminarGravacao(caminho, Date.now() - inicioGravacao);
        else
            gravador.stop();
    }
    function gravadorMudou(s) {
        if (s === MediaRecorder.RecordingState) {
            inicioGravacao = Date.now();
            estado = "gravando";
        } else if (s === MediaRecorder.StoppedState && estado === "gravando") {
            terminarGravacao(localDe(gravador.actualLocation) || caminhoGravando, gravador.duration);
        }
    }
    function terminarGravacao(caminho, ms) {
        estado = "parado";
        if (fecharDepois)
            Qt.callLater(janela.close);
        somNaGravacao = false;
        delete reservados[caminhoGravando];
        var capa = pastaCapas !== "" ? pastaCapas + "/" + nomeArquivo(caminho) + ".jpg" : "";
        if (caminho !== caminhoGravando && capa !== "")
            matsu.rodar("capa", comando(["capa", caminho, capa]));
        if (demo) {
            avisoRapido(t("Demonstração: o vídeo não foi gravado", "Demo: the video was not recorded"), "");
            ultima = { caminho: caminho, tipo: "video", capa: "" };
            return;
        }
        ultima = { caminho: caminho, tipo: "video", capa: capa };
        avisoRapido(t("Vídeo salvo", "Video saved") + " · " + duracaoCurta(ms), "certo", t("Abrir", "Open"), () => janela.abrir(caminho));
    }
    function falhaVideo(texto) {
        somNaGravacao = false;
        if (estado === "gravando" && gravador.recorderState === MediaRecorder.StoppedState)
            estado = "parado";
        if (fecharDepois && gravador.recorderState === MediaRecorder.StoppedState)
            Qt.callLater(janela.close);
        avisoRapido(t("Não deu para gravar o vídeo", "Couldn't record the video") + (texto ? ": " + texto : ""), "erro");
    }
    Timer {
        interval: 250
        repeat: true
        running: janela.estado === "gravando"
        triggeredOnStart: true
        onTriggered: janela.tempoGravado = janela.duracaoCurta(janela.demo ? Date.now() - janela.inicioGravacao : gravador.duration)
        onRunningChanged: if (!running) janela.tempoGravado = "00:00"
    }

    // ----- abrir no Fotos -----
    function abrir(caminho) {
        var fotos = "/usr/share/matsu/fotos/Main.qml";
        if (matsu.existe(fotos) && matsu.soltar(["/usr/libexec/matsu/matsu-janela", "org.matsu.fotos", fotos, caminho]))
            return;
        if (!matsu.soltar(["xdg-open", caminho]))
            avisoRapido(t("Não deu para abrir o arquivo", "Couldn't open the file"), "erro");
    }
    function abrirPasta(pasta) {
        if (!matsu.soltar(["xdg-open", pasta]))
            avisoRapido(t("Não deu para abrir a pasta", "Couldn't open the folder"), "erro");
    }

    // ----- a foto que voa até a miniatura -----
    function voar(url) {
        var de = visor.mapToItem(palco, 0, 0, visor.width, visor.height);
        voador.source = url;
        voador.x = de.x;
        voador.y = de.y;
        voador.width = de.width;
        voador.height = de.height;
        voador.raio = visor.raio;
        voador.opacity = 1;
        voador.visible = true;
        var para = miniatura.mapToItem(palco, 0, 0, miniatura.width, miniatura.height);
        vooX.to = para.x;
        vooY.to = para.y;
        vooL.to = para.width;
        vooA.to = para.height;
        vooR.to = miniatura.raio;
        voo.urlFinal = url;
        voo.restart();
    }

    // ----- ajustes guardados -----
    readonly property string arquivoAjustes: matsu.pasta("config") + "/camera.json"
    readonly property string ajustesJson: JSON.stringify({ modo: modo, temporizador: temporizador, grade: grade, espelhar: espelhar,
                                                          somObturador: somObturador, gravarSom: gravarSom, camera: cameraEscolhida,
                                                          microfone: microfoneEscolhido, resolucao: resolucao })
    onAjustesJsonChanged: if (ajustesLidos && !demo) salvarAjustes.restart()
    Timer {
        id: salvarAjustes
        interval: 500
        onTriggered: matsu.gravar(janela.arquivoAjustes, janela.ajustesJson + "\n")
    }
    function lerAjustes() {
        var a = {};
        try {
            a = JSON.parse(matsu.ler(arquivoAjustes) || "{}") || {};
        } catch (e) {
            a = {};
        }
        if (a.modo === "foto" || a.modo === "video")
            modo = a.modo;
        if ([0, 3, 10].indexOf(a.temporizador) >= 0)
            temporizador = a.temporizador;
        if (typeof a.grade === "boolean")
            grade = a.grade;
        if (typeof a.espelhar === "boolean")
            espelhar = a.espelhar;
        if (typeof a.somObturador === "boolean")
            somObturador = a.somObturador;
        if (typeof a.gravarSom === "boolean")
            gravarSom = a.gravarSom;
        if (typeof a.camera === "string")
            cameraEscolhida = a.camera;
        if (typeof a.microfone === "string")
            microfoneEscolhido = a.microfone;
        if (typeof a.resolucao === "string")
            resolucao = a.resolucao;
        ajustesLidos = true;
    }
    function lerArgumentos(args) {
        if (estado !== "parado")
            return;
        if (args.indexOf("video") >= 0 || args.indexOf("--video") >= 0)
            modo = "video";
        else if (args.indexOf("foto") >= 0 || args.indexOf("--foto") >= 0)
            modo = "foto";
    }

    Connections {
        target: matsu
        function onPronto(chave, saida, codigo) {
            if (chave !== "inicio")
                return;
            var d;
            try {
                d = JSON.parse(saida);
            } catch (e) {
                janela.avisoRapido(janela.t("Não deu para preparar as pastas da câmera", "Couldn't prepare the camera folders"), "erro");
                return;
            }
            if (d.idioma)
                janela.lingua = d.idioma;
            if (d.vidro && JSON.stringify(d.vidro) !== JSON.stringify(janela.vidroConf))
                janela.vidroConf = d.vidro;
            janela.pastaFotos = d.fotos || "";
            janela.pastaVideos = d.videos || "";
            janela.pastaCapas = d.capas || "";
            if (d.ultima && !janela.ultima)
                janela.ultima = d.ultima;
            if (!d.pastasOk)
                janela.avisoRapido(janela.t("Não deu para criar as pastas das fotos e dos vídeos", "Couldn't create the photo and video folders"), "erro");
        }
        function onPedido(argumentos) {
            janela.lerArgumentos(argumentos);
        }
    }

    Component.onCompleted: {
        lerAjustes();
        lerArgumentos(matsu.argumentos);
        idsCameras = cameras.map(c => c.id);
        aplicarCamera();
        camera.active = cameraLigada;
        matsu.rodar("inicio", comando(["inicio", matsu.pasta("imagens"), matsu.pasta("videos"), matsu.pasta("dados")]));
    }

    // Fechar gravando: primeiro termina o vídeo (senão o arquivo fica estragado), depois fecha.
    onClosing: (fechamento) => {
        if (estado === "gravando" && !demo) {
            fechamento.accepted = false;
            fecharDepois = true;
            pararGravacao();
        }
    }

    // ----- atalhos -----
    Shortcut {
        sequences: ["Space", "Return", "Enter"]
        enabled: !janela.painelAberto
        onActivated: janela.disparar()
    }
    Shortcut {
        sequence: "F"
        onActivated: janela.alternarModo()
    }
    Shortcut {
        sequence: "T"
        onActivated: janela.cicloTemporizador()
    }
    Shortcut {
        sequence: "G"
        onActivated: janela.grade = !janela.grade
    }
    Shortcut {
        sequence: "Ctrl+,"
        onActivated: janela.painelAberto = !janela.painelAberto
    }
    Shortcut {
        sequence: "Escape"
        enabled: janela.estado === "contando" || janela.painelAberto
        onActivated: {
            if (janela.estado === "contando")
                janela.cancelarContagem();
            else
                janela.painelAberto = false;
        }
    }

    // ===== o palco: em cima do miolo da JanelaMatsu, embaixo da barra de título =====
    Item {
        id: palco
        readonly property int margem: Math.round(janela.gu * 0.9)
        readonly property int larguraColuna: Math.round(janela.gu * 10.5)
        readonly property int larguraPainel: Math.round(janela.gu * 19)
        // Com espaço, o visor encolhe para o painel caber ao lado; sem, o painel vai por cima.
        readonly property bool painelAoLado: width - larguraColuna - larguraPainel - 2 * margem >= janela.gu * 24
        z: 50
        x: janela.cheia ? 0 : 1
        y: Math.round(janela.gu * 2.7)
        width: janela.width - 2 * x
        height: janela.height - y - x

        // ----- a área do visor -----
        Item {
            id: area
            x: palco.margem
            y: palco.margem
            height: palco.height - 2 * palco.margem
            width: palco.width - palco.larguraColuna - palco.margem
                   - (janela.painelAberto && palco.painelAoLado ? palco.larguraPainel : 0)
            Behavior on width {
                NumberAnimation {
                    duration: 320
                    easing.type: Easing.OutCubic
                }
            }

            Visor {
                id: visor
                readonly property real larguraCabe: Math.min(area.width, area.height * janela.aspecto)
                anchors.centerIn: parent
                width: Math.round(larguraCabe)
                height: Math.round(larguraCabe / janela.aspecto)
                opacity: janela.vazio === "" ? 1 : 0
                scale: janela.vazio === "" ? 1 : 0.97
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 300
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 360
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Loader {
                anchors.centerIn: parent
                width: Math.min(parent.width - janela.gu * 2, janela.gu * 24)
                active: janela.vazio !== ""
                sourceComponent: Vazio {
                    readonly property var textos: ({
                        semCamera: [janela.t("Nenhuma câmera encontrada", "No camera found"),
                                    janela.t("Ligue uma webcam e ela aparece aqui.", "Plug in a webcam and it shows up here.")],
                        ocupada: [janela.t("A câmera está ocupada", "The camera is busy"),
                                  janela.t("Outro app está usando a câmera. Feche-o e tente de novo.", "Another app is using the camera. Close it and try again.")],
                        permissao: [janela.t("Sem permissão para usar a câmera", "No permission to use the camera"),
                                    janela.t("O sistema não deixou abrir a câmera. Confira as permissões e tente de novo.", "The system didn't allow opening the camera. Check the permissions and try again.")],
                        semResposta: [janela.t("A câmera não respondeu", "The camera didn't respond"),
                                      janela.t("Ela pode estar desligada por uma tecla ou chave do notebook. Ligue e tente de novo.", "It may be turned off by a key or switch on the laptop. Turn it on and try again.")],
                        falhou: [janela.t("Não deu para abrir a câmera", "Couldn't open the camera"),
                                 janela.t("Tente de novo ou ligue outra câmera.", "Try again or plug in another camera.")]
                    })
                    readonly property var atual: textos[janela.vazio] || textos.falhou
                    width: parent ? parent.width : janela.gu * 24
                    icone: Qt.resolvedUrl("icones/camera-desligada.svg")
                    titulo: atual[0]
                    texto: atual[1]
                    BotaoDestaque {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Math.round(janela.gu * 0.4)
                        texto: janela.t("Tentar de novo", "Try again")
                        estado: janela.procurando ? "carregando" : ""
                        onClicado: janela.tentarDeNovo()
                    }
                    Texto {
                        Layout.fillWidth: true
                        Layout.topMargin: Math.round(janela.gu * 0.2)
                        visible: janela.erroTexto !== "" && janela.vazio === "falhou"
                        text: janela.erroTexto
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.45
                    }
                }
            }
        }

        // ----- painel de ajustes -----
        PainelAjustes {
            id: painel
            width: palco.larguraPainel
            height: palco.height - 2
            y: 1
            x: palco.width - palco.larguraColuna - (janela.painelAberto ? width : width - janela.gu * 2)
            opacity: janela.painelAberto ? 1 : 0
            visible: opacity > 0
            Behavior on x {
                NumberAnimation {
                    duration: 320
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 220
                }
            }
            onFechar: janela.painelAberto = false
        }

        // ----- a coluna de controles, à direita -----
        Item {
            id: coluna
            // Os botões de cima e a miniatura acompanham o alto e o pé do visor.
            readonly property real topoVisor: area.y + visor.y
            readonly property real peVisor: area.y + visor.y + visor.height
            readonly property bool alinhar: janela.vazio === "" && peVisor - topoVisor >= janela.gu * 17
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: palco.larguraColuna

            Row {
                id: botoes
                y: coluna.alinhar ? Math.round(coluna.topoVisor) : palco.margem
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(janela.gu * 0.2)
                BotaoCirculo {
                    icone: Qt.resolvedUrl("icones/temporizador.svg")
                    dica: janela.temporizador > 0 ? janela.t("Temporizador: ", "Timer: ") + janela.temporizador + " s (T)"
                                                  : janela.t("Temporizador desligado (T)", "Timer off (T)")
                    ligado: janela.temporizador > 0
                    selo: janela.temporizador > 0 ? String(janela.temporizador) : ""
                    onClicado: janela.cicloTemporizador()
                }
                BotaoCirculo {
                    icone: Qt.resolvedUrl("icones/grade.svg")
                    dica: janela.t("Grade de terços (G)", "Rule of thirds grid (G)")
                    ligado: janela.grade
                    onClicado: janela.grade = !janela.grade
                }
                BotaoCirculo {
                    visible: janela.cameras.length > 1
                    icone: Qt.resolvedUrl("icones/trocar.svg")
                    dica: janela.t("Trocar de câmera", "Switch camera")
                    ativo: janela.estado !== "gravando"
                    onClicado: janela.trocarCamera()
                }
                BotaoCirculo {
                    icone: "matsu-ajustes-symbolic"
                    dica: janela.t("Ajustes (Ctrl+,)", "Settings (Ctrl+,)")
                    ligado: janela.painelAberto
                    onClicado: janela.painelAberto = !janela.painelAberto
                }
            }

            Seletor {
                id: seletorModo
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: disparador.top
                anchors.bottomMargin: Math.round(janela.gu * 1.1)
                ativo: janela.estado === "parado"
                opcoes: [
                    { id: "foto", nome: janela.t("Foto", "Photo"), icone: Qt.resolvedUrl("icones/camera.svg") },
                    { id: "video", nome: janela.t("Vídeo", "Video"), icone: Qt.resolvedUrl("icones/video.svg") }
                ]
                escolhido: janela.modo
                onEscolher: (id) => janela.modo = id
            }

            Disparador {
                id: disparador
                anchors.horizontalCenter: parent.horizontalCenter
                // Na altura do meio do visor.
                y: Math.max(botoes.y + botoes.height + seletorModo.height + Math.round(janela.gu * 2.2),
                            Math.round(area.y + area.height / 2 - height / 2))
                modo: janela.modo
                estado: janela.estado
                ativo: janela.podeDisparar
                onDisparado: janela.disparar()
            }

            Miniatura {
                id: miniatura
                anchors.horizontalCenter: parent.horizontalCenter
                y: coluna.alinhar ? Math.round(coluna.peVisor - height) : coluna.height - palco.margem - height
                item: janela.ultima
                onAbrir: (caminho) => janela.abrir(caminho)
            }
        }

        // ----- a foto voando até a miniatura -----
        ImagemRedonda {
            id: voador
            z: 10
            visible: false
            fillMode: Image.PreserveAspectCrop
        }
        SequentialAnimation {
            id: voo
            property string urlFinal: ""
            PauseAnimation { duration: 160 }
            ParallelAnimation {
                NumberAnimation { id: vooX; target: voador; property: "x"; duration: 560; easing.type: Easing.InOutCubic }
                NumberAnimation { id: vooY; target: voador; property: "y"; duration: 560; easing.type: Easing.InOutCubic }
                NumberAnimation { id: vooL; target: voador; property: "width"; duration: 560; easing.type: Easing.InOutCubic }
                NumberAnimation { id: vooA; target: voador; property: "height"; duration: 560; easing.type: Easing.InOutCubic }
                NumberAnimation { id: vooR; target: voador; property: "raio"; duration: 560; easing.type: Easing.InOutCubic }
            }
            ScriptAction {
                script: {
                    // Se a imagem da memória não carregou, a miniatura usa o arquivo salvo.
                    miniatura.imediata = voador.pronta ? voo.urlFinal : "";
                    miniatura.pular();
                    voador.visible = false;
                }
            }
        }
    }
}
