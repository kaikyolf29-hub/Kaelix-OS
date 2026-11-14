// Telas, no jeito da página Monitores do Mac e do Windows 11: com mais de uma
// tela, o desenho delas (clicar escolhe, arrastar muda o lugar), estender,
// duplicar ou usar só uma, e qual é a principal. Para a tela escolhida:
// resolução, taxa de atualização, tamanho do texto e dos apps, girar, FreeSync
// e HDR. Depois, o brilho (no notebook) e a luz noturna.
//
// Aqui é só o desenho. Quem lê e muda as telas é /usr/share/matsu/monitores/ajudante.py
// (que usa o kscreen-doctor do KDE e tem teste). O que pode deixar a tela preta
// volta sozinho em 15 s se a pessoa não confirmar na faixa de cima.
// As mudanças aparecem na hora e depois são conferidas com o estado lido.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support

ColumnLayout {
    id: pagina

    spacing: Math.round(Kirigami.Units.gridUnit * 1.1)

    readonly property string ajudante: "/usr/bin/python3 -I -S /usr/share/matsu/monitores/ajudante.py"
    readonly property int gu: Kirigami.Units.gridUnit
    // Quantos segundos a pessoa tem para confirmar (o ajudante diz).
    readonly property real espera: dados.espera > 0 ? dados.espera : 15

    // O último estado lido do ajudante (com as mudanças que ainda estão indo).
    property var dados: ({})
    property bool carregou: false
    property int falhas: 0
    property string escolhidaNome: ""
    // Comandos ainda rodando: enquanto houver, a leitura não troca o desenho.
    property int pendentes: 0
    property int contador: 0
    property var inicioLeitura: ({})
    property double ultimaMudanca: 0
    // Quando a volta sozinha acontece (0 = nada para confirmar).
    property double prazo: 0
    property double agora: Date.now()

    readonly property bool ok: dados.ok === true
    readonly property var telas: ok && dados.telas ? dados.telas : []
    readonly property string modo: dados.modo || "uma"
    readonly property var ligadas: telas.filter(function (t) { return t.ligada; })
    readonly property var principal: {
        for (var i = 0; i < telas.length; i++)
            if (telas[i].principal)
                return telas[i];
        return telas.length > 0 ? telas[0] : null;
    }
    readonly property var tela: {
        for (var i = 0; i < telas.length; i++)
            if (telas[i].nome === escolhidaNome)
                return telas[i];
        return principal;
    }
    readonly property var resolucaoAtual: {
        if (!tela)
            return null;
        for (var i = 0; i < tela.resolucoes.length; i++) {
            var r = tela.resolucoes[i];
            if (r.largura === tela.modo.largura && r.altura === tela.modo.altura)
                return r;
        }
        return null;
    }
    readonly property bool girada: tela !== null && (tela.rotacao === "esquerda" || tela.rotacao === "direita")
    readonly property int segundos: Math.max(0, Math.ceil((prazo - agora) / 1000))
    readonly property bool confirmando: prazo > agora

    // ------------------------------------------------ conversa com o ajudante

    function ler() {
        contador += 1;
        var fonte = ajudante + " estado #" + contador;
        inicioLeitura[fonte] = Date.now();
        executor.connectSource(fonte);
    }

    // "arriscada": pode deixar a tela preta, então a faixa de confirmar aparece já.
    function rodar(argumentos, arriscada) {
        if (arriscada)
            prazo = Date.now() + espera * 1000;
        pendentes += 1;
        ultimaMudanca = Date.now();
        contador += 1;
        executor.connectSource(ajudante + " " + argumentos + " #" + contador);
    }

    function receber(saida, comecou) {
        if (pendentes > 0 || comecou < ultimaMudanca)
            return;
        var novo = null;
        try {
            novo = JSON.parse(String(saida || "").trim());
        } catch (e) {
            novo = null;
        }
        if (!novo || novo.ok !== true) {
            // Uma falha só (o KDE ocupado) não troca a página pelo aviso.
            falhas += 1;
            if (ok && falhas < 3)
                return;
            novo = novo || { ok: false, erro: "sem-resposta", telas: [] };
        } else {
            falhas = 0;
        }
        dados = novo;
        carregou = true;
        prazo = novo.confirmar > 0 ? Date.now() + novo.confirmar * 1000 : 0;
        agora = Date.now();
    }

    P5Support.DataSource {
        id: executor
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, resposta) => {
            disconnectSource(fonte);
            if (fonte.indexOf(pagina.ajudante + " estado") === 0) {
                var comecou = pagina.inicioLeitura[fonte] || 0;
                delete pagina.inicioLeitura[fonte];
                pagina.receber(resposta["stdout"], comecou);
            } else {
                pagina.pendentes = Math.max(0, pagina.pendentes - 1);
                pagina.ultimaMudanca = Date.now();
                if (pagina.pendentes === 0)
                    pagina.ler();
            }
        }
    }

    // Telas ligadas e desligadas no cabo aparecem sozinhas: confere sempre.
    Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: pagina.ler()
    }

    // A contagem da faixa. Passado o prazo, o ajudante já voltou: lê de novo.
    Timer {
        interval: 200
        repeat: true
        running: pagina.prazo > 0
        onTriggered: {
            pagina.agora = Date.now();
            if (pagina.agora > pagina.prazo + 1500) {
                pagina.prazo = 0;
                pagina.ler();
            }
        }
    }

    // --------------------------------------- mudanças (aparecem na hora)

    function copia() {
        return JSON.parse(JSON.stringify(dados));
    }
    function recalcular(t) {
        var w = t.modo.largura, h = t.modo.altura;
        if (t.rotacao === "esquerda" || t.rotacao === "direita") {
            var x = w;
            w = h;
            h = x;
        }
        t.largura = Math.round(w / (t.escala || 1));
        t.altura = Math.round(h / (t.escala || 1));
    }
    function mudar(nome, acao) {
        var d = copia();
        for (var i = 0; i < d.telas.length; i++)
            if (d.telas[i].nome === nome)
                acao(d.telas[i], d);
        dados = d;
    }

    function escolherResolucao(valor) {
        var p = String(valor).split("x");
        var w = parseInt(p[0], 10), h = parseInt(p[1], 10);
        var nome = tela.nome;
        mudar(nome, function (t) {
            var hz = t.modo.hz;
            for (var i = 0; i < t.resolucoes.length; i++) {
                var r = t.resolucoes[i];
                if (r.largura === w && r.altura === h && r.taxas.indexOf(hz) < 0)
                    hz = r.taxa_preferida || r.taxas[0];
            }
            t.modo = { largura: w, altura: h, hz: hz };
            recalcular(t);
        });
        rodar("resolucao " + nome + " " + w + "x" + h, true);
    }
    function escolherTaxa(valor) {
        var hz = parseInt(valor, 10);
        var t = tela;
        mudar(t.nome, function (x) { x.modo.hz = hz; });
        rodar("resolucao " + t.nome + " " + t.modo.largura + "x" + t.modo.altura + " " + hz, true);
    }
    function escolherEscala(escala) {
        var nome = tela.nome;
        mudar(nome, function (t) {
            t.escala = escala;
            recalcular(t);
        });
        rodar("escala " + nome + " " + escala, true);
    }
    function girar(lado) {
        var nome = tela.nome;
        mudar(nome, function (t) {
            t.rotacao = lado;
            recalcular(t);
        });
        rodar("girar " + nome + " " + lado, true);
    }
    function usar(como) {
        var nome = tela.nome;
        var d = copia();
        for (var i = 0; i < d.telas.length; i++) {
            var t = d.telas[i];
            t.ligada = como !== "so" || t.nome === nome;
            if (como === "so")
                t.principal = t.nome === nome;
        }
        d.modo = como === "so" ? "uma" : como;
        dados = d;
        rodar("modo " + (como === "so" ? "so " + nome : como), true);
    }
    function tornarPrincipal() {
        var nome = tela.nome;
        var d = copia();
        for (var i = 0; i < d.telas.length; i++)
            d.telas[i].principal = d.telas[i].nome === nome;
        dados = d;
        rodar("principal " + nome, false);
    }
    function mover(posicoes) {
        var d = copia();
        var lista = [];
        for (var i = 0; i < d.telas.length; i++) {
            var p = posicoes[d.telas[i].nome];
            if (p) {
                d.telas[i].x = p[0];
                d.telas[i].y = p[1];
                lista.push(d.telas[i].nome + ":" + p[0] + "," + p[1]);
            }
        }
        dados = d;
        rodar("posicoes " + lista.join(" "), false);
    }
    function alternarVrr(ligar) {
        var nome = tela.nome;
        mudar(nome, function (t) { t.vrr = ligar; });
        rodar("vrr " + nome + (ligar ? " on" : " off"), false);
    }
    function alternarHdr(ligar) {
        var nome = tela.nome;
        mudar(nome, function (t) { t.hdr = ligar; });
        rodar("hdr " + nome + (ligar ? " on" : " off"), true);
    }
    function manter() {
        prazo = 0;
        rodar("manter", false);
    }
    function voltar() {
        prazo = 0;
        rodar("voltar", false);
    }

    function detalheDaTela(t) {
        if (!t)
            return "";
        var partes = [];
        if (t.polegadas)
            partes.push(String(t.polegadas).replace(".", ajustes.t(",", ".")) + "″");
        // O conector (HDMI-A-1) é o nome que o "Identificar" mostra na tela.
        if (t.interna)
            partes.push(ajustes.t("Interna", "Built-in"));
        else if (t.nome)
            partes.push(t.nome);
        if (!t.ligada)
            partes.push(ajustes.t("Desligada", "Off"));
        else if (t.modo && t.modo.largura)
            partes.push(t.modo.largura + " × " + t.modo.altura + ajustes.t(" a ", " at ") + t.modo.hz + " Hz");
        return partes.join(" · ");
    }

    // ------------------------------------------------------------- desenho

    // A faixa de confirmar fica por cima da página (não rola junto com ela).
    TelasFaixa {
        parent: rolagem
        x: Math.round(pagina.gu * 1.1)
        y: Math.round(pagina.gu * 0.6)
        width: rolagem.width - Math.round(pagina.gu * 2.2)
        aberta: pagina.confirmando
        segundos: pagina.segundos
        total: pagina.espera
        falta: Math.max(0, (pagina.prazo - pagina.agora) / 1000)
        onManter: pagina.manter()
        onVoltar: pagina.voltar()
    }

    // Lendo pela primeira vez (só aparece se demorar).
    PlasmaComponents.Label {
        id: lendo
        property bool demorou: false
        Layout.fillWidth: true
        visible: !pagina.carregou && demorou
        text: ajustes.t("Lendo as telas…", "Reading the displays…")
        opacity: 0.6
        Timer {
            running: !pagina.carregou
            interval: 700
            onTriggered: lendo.demorou = true
        }
    }

    // O kscreen-doctor faltou ou falhou: um aviso gentil e a tela do KDE de reserva.
    Grupo {
        visible: pagina.carregou && !pagina.ok

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Math.round(pagina.gu * 0.8)
            spacing: Math.round(pagina.gu * 0.7)

            Kirigami.Icon {
                Layout.alignment: Qt.AlignTop
                implicitWidth: Kirigami.Units.iconSizes.medium
                implicitHeight: implicitWidth
                source: "matsu-tela-symbolic"
                isMask: true
                color: Kirigami.Theme.textColor
                opacity: 0.7
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Math.round(pagina.gu * 0.2)
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: ajustes.t("Não deu para ler as telas agora", "Couldn't read the displays right now")
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: ajustes.t("Os ajustes de tela do KDE continuam funcionando enquanto isso.",
                                    "The KDE display settings still work in the meantime.")
                    wrapMode: Text.WordWrap
                    opacity: 0.65
                }
                TelasBotao {
                    Layout.topMargin: Math.round(pagina.gu * 0.4)
                    texto: ajustes.t("Abrir os ajustes de tela do KDE", "Open the KDE display settings")
                    onClicked: ajustes.abrir("tela")
                }
            }
        }
    }

    // Com mais de uma tela: o desenho, estender ou duplicar e a principal.
    Grupo {
        visible: pagina.ok && pagina.telas.length > 1

        TelasArranjo {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(pagina.gu * 0.3)
            telas: pagina.telas
            escolhida: pagina.tela ? pagina.tela.nome : ""
            modo: pagina.modo
            onEscolher: nome => pagina.escolhidaNome = nome
            onMover: posicoes => pagina.mover(posicoes)
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(pagina.gu * 0.8)
            Layout.rightMargin: Math.round(pagina.gu * 0.6)
            Layout.bottomMargin: Math.round(pagina.gu * 0.6)
            spacing: Math.round(pagina.gu * 0.6)

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: pagina.modo === "estender"
                      ? ajustes.t("Arraste as telas para ficarem como na sua mesa.", "Drag the displays to match your desk.")
                      : ajustes.t("Clique numa tela para ver os ajustes dela.", "Click a display to see its settings.")
                font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                wrapMode: Text.WordWrap
                opacity: 0.6
            }
            TelasBotao {
                texto: ajustes.t("Identificar", "Identify")
                onClicked: pagina.rodar("identificar", false)
            }
        }

        Linha {
            nome: ajustes.t("Usar as telas", "Use displays")
            detalhe: pagina.modo === "estender" ? ajustes.t("Cada tela mostra uma parte da área de trabalho.", "Each display shows part of the desktop.")
                   : pagina.modo === "duplicar" ? ajustes.t("Todas mostram a mesma coisa.", "All show the same thing.")
                   : ajustes.t("Só uma fica ligada.", "Only one stays on.")
            Segmentado {
                Layout.preferredWidth: pagina.gu * 17
                atual: pagina.modo === "uma" ? (pagina.tela && pagina.tela.ligada ? "so" : "") : pagina.modo
                opcoes: [
                    { valor: "estender", nome: ajustes.t("Estender", "Extend") },
                    { valor: "duplicar", nome: ajustes.t("Duplicar", "Mirror") },
                    { valor: "so", nome: ajustes.t("Só esta tela", "Only this one") }
                ]
                onEscolhido: valor => {
                    if (valor !== atual)
                        pagina.usar(valor);
                }
            }
        }

        Linha {
            visible: pagina.tela !== null && pagina.tela.ligada && pagina.ligadas.length > 1 && pagina.modo !== "duplicar"
            nome: ajustes.t("Tela principal", "Main display")
            detalhe: ajustes.t("A barra com a bandeja e a central fica nela.", "The bar with the tray and control center stays on it.")

            RowLayout {
                visible: pagina.tela !== null && pagina.tela.principal
                spacing: Math.round(pagina.gu * 0.3)
                Kirigami.Icon {
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: implicitWidth
                    source: "matsu-certo-symbolic"
                    isMask: true
                    color: Kirigami.Theme.textColor
                    opacity: 0.75
                }
                PlasmaComponents.Label {
                    text: ajustes.t("Esta é a principal", "This is the main one")
                    opacity: 0.75
                }
            }
            TelasBotao {
                visible: pagina.tela !== null && !pagina.tela.principal
                texto: ajustes.t("Usar como principal", "Use as main")
                onClicked: pagina.tornarPrincipal()
            }
        }
    }

    // Os ajustes da tela escolhida.
    Grupo {
        visible: pagina.ok && pagina.tela !== null
        nota: pagina.tela && pagina.tela.ligada
              ? ajustes.t("Resolução, taxa, tamanho, giro e HDR voltam sozinhos em " + Math.round(pagina.espera) + " s se você não confirmar.",
                          "Resolution, refresh rate, size, rotation and HDR revert after " + Math.round(pagina.espera) + " s unless you confirm.")
              : ""

        // Quem é a tela: o desenho dela, o nome e o resumo.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(pagina.gu * 0.8)
            Layout.rightMargin: Math.round(pagina.gu * 0.8)
            Layout.topMargin: Math.round(pagina.gu * 0.7)
            Layout.bottomMargin: Math.round(pagina.gu * 0.7)
            spacing: Math.round(pagina.gu * 0.75)

            Item {
                id: desenhoTela
                readonly property bool notebook: pagina.tela !== null && pagina.tela.interna
                readonly property real proporcao: pagina.tela && pagina.tela.largura > 0 ? pagina.tela.altura / pagina.tela.largura : 0.5625
                implicitWidth: Math.round(pagina.gu * 2.8)
                implicitHeight: Math.round(pagina.gu * 2.4)

                Rectangle {
                    id: telinha
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round((parent.height - height - Math.round(pagina.gu * 0.45)) / 2)
                    readonly property real lado: pagina.gu * 2.4
                    width: Math.round(desenhoTela.proporcao > 1 ? lado / desenhoTela.proporcao * 0.75 : lado)
                    height: Math.round(desenhoTela.proporcao > 1 ? lado * 0.75 : lado * Math.max(0.42, desenhoTela.proporcao))
                    radius: Math.round(pagina.gu * 0.2)
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
                    border.width: 1.5
                    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.55)
                    Behavior on width {
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }
                    Behavior on height {
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }
                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        visible: pagina.telas.length > 1
                        text: pagina.tela ? pagina.tela.numero : ""
                        font.weight: Font.Bold
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                    }
                }
                // O pé do monitor, ou a base do notebook.
                Rectangle {
                    visible: !desenhoTela.notebook
                    anchors.horizontalCenter: telinha.horizontalCenter
                    anchors.top: telinha.bottom
                    width: 2
                    height: Math.round(pagina.gu * 0.3)
                    color: telinha.border.color
                }
                Rectangle {
                    anchors.horizontalCenter: telinha.horizontalCenter
                    anchors.top: telinha.bottom
                    anchors.topMargin: desenhoTela.notebook ? 1 : Math.round(pagina.gu * 0.3)
                    width: desenhoTela.notebook ? telinha.width + Math.round(pagina.gu * 0.5) : Math.round(telinha.width * 0.42)
                    height: desenhoTela.notebook ? 3 : 2
                    radius: height / 2
                    color: telinha.border.color
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: pagina.tela ? pagina.tela.rotulo : ""
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: pagina.detalheDaTela(pagina.tela)
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                    font.features: ({ "tnum": 1 })
                    elide: Text.ElideRight
                    opacity: 0.6
                }
            }

            // "Principal": uma etiqueta cinza, sem cor de destaque.
            Rectangle {
                visible: pagina.tela !== null && pagina.tela.principal && pagina.ligadas.length > 1
                implicitWidth: etiqueta.implicitWidth + Math.round(pagina.gu * 0.9)
                implicitHeight: etiqueta.implicitHeight + Math.round(pagina.gu * 0.3)
                radius: height / 2
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
                PlasmaComponents.Label {
                    id: etiqueta
                    anchors.centerIn: parent
                    text: ajustes.t("Principal", "Main")
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                }
            }
        }

        // Desligada: o que fazer para usar.
        Linha {
            visible: pagina.tela !== null && !pagina.tela.ligada
            nome: ajustes.t("Esta tela está desligada", "This display is off")
            detalhe: ajustes.t("Escolha Estender, Duplicar ou Só esta tela para usar.", "Choose Extend, Mirror or Only this one to use it.")
        }

        Linha {
            visible: pagina.tela !== null && pagina.tela.ligada
            nome: ajustes.t("Resolução", "Resolution")
            detalhe: {
                var r = pagina.resolucaoAtual;
                if (!r)
                    return "";
                return [r.nome, r.preferida ? ajustes.t("Recomendada", "Recommended") : ""].filter(function (x) { return x; }).join(" · ");
            }

            TelasEscolha {
                nomeAcessivel: ajustes.t("Resolução", "Resolution")
                atual: pagina.tela ? pagina.tela.modo.largura + "x" + pagina.tela.modo.altura : ""
                opcoes: {
                    var lista = [];
                    var rs = pagina.tela ? pagina.tela.resolucoes : [];
                    for (var i = 0; i < rs.length; i++) {
                        var r = rs[i];
                        lista.push({
                            valor: r.largura + "x" + r.altura,
                            nome: r.largura + " × " + r.altura,
                            detalhe: [r.nome, r.preferida ? ajustes.t("Recomendada", "Recommended") : ""].filter(function (x) { return x; }).join(" · ")
                        });
                    }
                    return lista;
                }
                onEscolhido: valor => {
                    if (valor !== atual)
                        pagina.escolherResolucao(valor);
                }
            }
        }

        Linha {
            id: linhaTaxa
            readonly property var taxas: pagina.resolucaoAtual ? pagina.resolucaoAtual.taxas : []
            readonly property var opcoes: taxas.map(function (hz) { return { valor: String(hz), nome: hz + " Hz" }; })
            visible: pagina.tela !== null && pagina.tela.ligada && taxas.length > 0
            nome: ajustes.t("Taxa de atualização", "Refresh rate")
            detalhe: taxas.length > 1 ? ajustes.t("Mais alta deixa o movimento mais suave.", "Higher makes motion smoother.") : ""

            PlasmaComponents.Label {
                visible: linhaTaxa.taxas.length === 1
                text: linhaTaxa.taxas.length > 0 ? linhaTaxa.taxas[0] + " Hz" : ""
                opacity: 0.75
            }
            Segmentado {
                visible: linhaTaxa.taxas.length > 1 && linhaTaxa.taxas.length <= 4
                Layout.preferredWidth: pagina.gu * 4.2 * linhaTaxa.taxas.length
                atual: pagina.tela ? String(pagina.tela.modo.hz) : ""
                opcoes: linhaTaxa.opcoes
                onEscolhido: valor => {
                    if (valor !== atual)
                        pagina.escolherTaxa(valor);
                }
            }
            TelasEscolha {
                visible: linhaTaxa.taxas.length > 4
                nomeAcessivel: ajustes.t("Taxa de atualização", "Refresh rate")
                atual: pagina.tela ? String(pagina.tela.modo.hz) : ""
                opcoes: linhaTaxa.opcoes
                onEscolhido: valor => {
                    if (valor !== atual)
                        pagina.escolherTaxa(valor);
                }
            }
        }

        TelasEscala {
            visible: pagina.tela !== null && pagina.tela.ligada && pagina.tela.escalas.length > 1
            escalas: pagina.tela ? pagina.tela.escalas : []
            atual: pagina.tela ? pagina.tela.escala : 1
            largura: pagina.tela ? pagina.tela.modo.largura : 1920
            altura: pagina.tela ? pagina.tela.modo.altura : 1080
            girada: pagina.girada
            onEscolhida: escala => pagina.escolherEscala(escala)
        }

        Linha {
            visible: pagina.tela !== null && pagina.tela.ligada
            nome: ajustes.t("Girar a tela", "Rotation")
            Segmentado {
                Layout.preferredWidth: pagina.gu * 18
                atual: pagina.tela ? pagina.tela.rotacao : "normal"
                opcoes: [
                    { valor: "normal", nome: ajustes.t("Normal", "Normal") },
                    { valor: "esquerda", nome: ajustes.t("Esquerda", "Left") },
                    { valor: "direita", nome: ajustes.t("Direita", "Right") },
                    { valor: "invertida", nome: ajustes.t("Invertida", "Upside down") }
                ]
                onEscolhido: valor => {
                    if (valor !== atual)
                        pagina.girar(valor);
                }
            }
        }

        Linha {
            visible: pagina.tela !== null && pagina.tela.ligada && pagina.tela.vrr_tem
            nome: ajustes.t("Sincronia adaptativa (FreeSync)", "Adaptive sync (FreeSync)")
            detalhe: ajustes.t("Jogos mais lisos, sem a imagem rasgar.", "Smoother games, without screen tearing.")
            PlasmaComponents.Switch {
                checked: pagina.tela !== null && pagina.tela.vrr
                onToggled: pagina.alternarVrr(checked)
                Accessible.name: ajustes.t("Sincronia adaptativa", "Adaptive sync")
            }
        }

        Linha {
            visible: pagina.tela !== null && pagina.tela.ligada && pagina.tela.hdr_tem
            nome: "HDR"
            detalhe: ajustes.t("Cores e brilho mais vivos em vídeos e jogos com HDR.", "Brighter, richer colors in HDR videos and games.")
            PlasmaComponents.Switch {
                checked: pagina.tela !== null && pagina.tela.hdr
                onToggled: pagina.alternarHdr(checked)
                Accessible.name: "HDR"
            }
        }
    }

    // Brilho (no notebook).
    Grupo {
        visible: ajustes.sim("brilho_tem")
        Linha {
            primeira: true
            nome: ajustes.t("Brilho", "Brightness")
            Regulador {
                valor: ajustes.numero("brilho")
                minimo: 1
                acao: "brilho"
            }
        }
    }

    Grupo {
        nota: ajustes.t("A luz noturna deixa a tela mais amarelada, para cansar menos a vista.",
                        "Night light makes the screen warmer, so it is easier on the eyes.")
        Linha {
            primeira: true
            nome: ajustes.t("Luz noturna", "Night light")
            PlasmaComponents.Switch {
                checked: ajustes.sim("noturna")
                onToggled: ajustes.alternar("noturna", "luz-noturna")
                Accessible.name: ajustes.t("Luz noturna", "Night light")
            }
        }
        Linha {
            abre: true
            nome: ajustes.t("Horários e cor da luz noturna", "Night light schedule and color")
            onAberto: ajustes.abrir("luz-noturna")
        }
    }
}
