// Calendário do Matsu: agenda pessoal na janela de vidro do Matsu (JanelaMatsu, de
// ../comum). À esquerda, "Calendário" e "Próximos", com o mini-calendário embaixo
// (como o cartão do vídeo de referência: a pílula cheia no dia escolhido, o dia de
// hoje marcado de leve e os eventos do dia aparecendo embaixo). No miolo, as visões
// Mês, Semana e Dia, trocadas no Seletor, com o período deslizando para o lado.
//
// Os eventos ficam em ~/.local/share/matsu/calendario/eventos.json (gravado aqui,
// pelo matsu.gravar). Os lembretes de verdade, com o app fechado, são unidades do
// systemd do usuário que o ajudante.py desta pasta cria; ele também lê e escreve .ics.
// As contas de datas (feriados, repetições) estão em datas.js.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"
import "datas.js" as Datas

JanelaMatsu {
    id: janela

    title: t("Calendário", "Calendar")
    icone: "org.matsu.calendario"
    iconeReserva: "office-calendar"
    dicaBusca: t("Buscar eventos", "Search events")
    paginaDaBusca: "proximos"
    width: gu * 66
    height: gu * 42
    paginas: [
        { id: "calendario", icone: "matsu-calendario-symbolic", nome: t("Calendário", "Calendar") },
        { id: "proximos", icone: Qt.resolvedUrl("icones/agenda.svg"), nome: t("Próximos", "Upcoming") }
    ]
    conteudo: Qt.resolvedUrl(pagina === "proximos" ? "PaginaProximos.qml" : "PaginaCalendario.qml")
    rodapeLateral: Component {
        LateralCalendario {}
    }

    readonly property string ajudante: decodeURIComponent(String(Qt.resolvedUrl("ajudante.py")).replace("file://", ""))
    function comando(args) {
        return ["/usr/bin/python3", "-I", "-S", ajudante].concat(args);
    }
    readonly property string arquivo: matsu.pasta("dados") + "/eventos.json"

    // ----- o estado -----
    property var eventos: []
    // Sobe a cada mudança nos eventos: as grades recalculam.
    property int versao: 0
    // O dia escolhido (a pílula cheia). As visões mostram o período dele.
    property var foco: Datas.hoje()
    // O mês que o mini-calendário mostra (as setas dele não mexem no miolo).
    property var mesMini: Datas.inicioMes(foco)
    property string visao: "mes"
    property bool mostrarFeriados: true
    // null enquanto não se sabe; false na prévia (sem systemd do usuário).
    property var systemd: null
    // Quanto a grade de horas está rolada (as visões Semana e Dia lembram).
    property real rolagemHoras: -1
    property var hojeAgora: Datas.hoje()

    onFocoChanged: mesMini = Datas.inicioMes(foco)

    // ----- cores dos eventos: uma paleta suave, nada do azul do KDE -----
    readonly property var paleta: [
        { id: "salvia", nome: t("Sálvia", "Sage"), escuro: "#8fd3ad", claro: "#3b9466" },
        { id: "lavanda", nome: t("Lavanda", "Lavender"), escuro: "#bba9f4", claro: "#7759d2" },
        { id: "coral", nome: t("Coral", "Coral"), escuro: "#f5a393", claro: "#d2604a" },
        { id: "mel", nome: t("Mel", "Honey"), escuro: "#ebc775", claro: "#ad8115" },
        { id: "rosa", nome: t("Rosa", "Rose"), escuro: "#f2a5c9", claro: "#c2538a" },
        { id: "menta", nome: t("Menta", "Mint"), escuro: "#7dd6cb", claro: "#1d9185" }
    ]
    function cor(id) {
        for (var i = 0; i < paleta.length; i++)
            if (paleta[i].id === id)
                return escuro ? paleta[i].escuro : paleta[i].claro;
        return escuro ? paleta[0].escuro : paleta[0].claro;
    }
    function corSuave(id, a) {
        var c = Qt.color(cor(id));
        return Qt.rgba(c.r, c.g, c.b, a);
    }
    // O fundo dos eventos: a cor bem de leve (o texto fica na cor da frente).
    function fundoEvento(id, forte) {
        return corSuave(id, escuro ? (forte ? 0.34 : 0.24) : (forte ? 0.26 : 0.17));
    }
    // A linha da hora de agora.
    readonly property color corAgora: escuro ? "#ff8a7a" : "#e0533f"

    // ----- textos de datas -----
    function nomeFeriado(f) {
        return pt ? f.nome : f.nomeEn;
    }
    function textoLembrete(minutos, diaTodo) {
        if (minutos < 0)
            return t("Sem lembrete", "No reminder");
        if (diaTodo)
            return minutos >= 1440 ? t("Na véspera, às 09:00", "Day before at 09:00") : t("No dia, às 09:00", "On the day at 09:00");
        if (minutos === 0)
            return t("Na hora do evento", "At time of event");
        if (minutos < 60)
            return t(minutos + " min antes", minutos + " min before");
        if (minutos < 1440)
            return t((minutos / 60) + " h antes", (minutos / 60) + " h before");
        return t("1 dia antes", "1 day before");
    }
    function faixaHoras(o) {
        if (o.diaTodo)
            return o.extensao > 0 ? t("Dia todo · até ", "All day · until ") + Datas.dataCurta(o.fim, pt) : t("Dia todo", "All day");
        var a = Datas.hora(o.inicio), b = Datas.hora(o.fim);
        if (!Datas.mesmoDia(o.inicio, o.fim) && o.fim > o.inicio)
            return a + " – " + Datas.dataCurta(o.fim, pt) + ", " + b;
        return a === b ? a : a + " – " + b;
    }

    // ----- guardar -----
    function carregar() {
        var texto = matsu.ler(arquivo);
        if (!texto)
            return;
        try {
            var d = JSON.parse(texto);
            var lista = Array.isArray(d) ? d : (d.eventos || []);
            eventos = lista.filter(function (e) { return e && e.inicio; });
            if (d.ajustes) {
                mostrarFeriados = d.ajustes.feriados !== false;
                if (["mes", "semana", "dia"].indexOf(d.ajustes.visao) >= 0)
                    visao = d.ajustes.visao;
            }
            versao++;
        } catch (e) {
            avisoRapido(t("Não deu para ler os eventos guardados", "Could not read the saved events"), "erro");
        }
    }
    function salvar() {
        var ok = matsu.gravar(arquivo, JSON.stringify({ versao: 1, ajustes: { feriados: mostrarFeriados, visao: visao }, eventos: eventos }, null, 1));
        if (!ok)
            avisoRapido(t("Não deu para guardar os eventos", "Could not save the events"), "erro");
        tempoSincronia.restart();
        return ok;
    }
    onMostrarFeriadosChanged: if (carregado) salvar()
    onVisaoChanged: if (carregado) tempoSalvarAjustes.restart()
    property bool carregado: false
    Timer {
        id: tempoSalvarAjustes
        interval: 800
        onTriggered: janela.salvar()
    }

    // Os lembretes: depois de cada mudança, o ajudante refaz os timers do systemd.
    property bool sincronizando: false
    property bool sincronizarDeNovo: false
    function sincronizar() {
        if (sincronizando) {
            sincronizarDeNovo = true;
            return;
        }
        sincronizando = true;
        matsu.rodar("sincronizar", comando(["sincronizar"]));
    }
    Timer {
        id: tempoSincronia
        interval: 700
        onTriggered: janela.sincronizar()
    }

    // ----- mexer nos eventos (sempre objetos novos: as telas comparam por versão) -----
    function trocarEventos(lista) {
        eventos = lista;
        versao++;
        salvar();
    }
    function guardarEvento(ev) {
        var lista = eventos.slice();
        var achou = false;
        for (var i = 0; i < lista.length; i++) {
            if (lista[i].id === ev.id) {
                lista[i] = ev;
                achou = true;
            }
        }
        if (!achou)
            lista.push(ev);
        trocarEventos(lista);
        return !achou;
    }
    function apagarEvento(ev) {
        var antes = eventos;
        trocarEventos(eventos.filter(function (e) { return e.id !== ev.id; }));
        avisoRapido(t("“" + (ev.titulo || "Evento") + "” apagado", "“" + (ev.titulo || "Event") + "” deleted"), "",
                    t("Desfazer", "Undo"), function () { janela.trocarEventos(antes); });
    }
    function apagarOcorrencia(ev, chave) {
        var antes = eventos;
        var novo = Object.assign({}, ev, { excecoes: (ev.excecoes || []).concat([chave]) });
        guardarEvento(novo);
        avisoRapido(t("Apagado só em " + Datas.dataCurta(Datas.ler(chave), true), "Deleted on " + Datas.dataCurta(Datas.ler(chave), false)), "",
                    t("Desfazer", "Undo"), function () { janela.trocarEventos(antes); });
    }
    // Pede confirmação só para eventos que se repetem; os outros têm o "Desfazer".
    function pedirApagar(ev, chave) {
        if ((ev.repetir || "nunca") === "nunca") {
            apagarEvento(ev);
            return;
        }
        dialogo.perguntar({
            titulo: t("Apagar “" + (ev.titulo || "Evento") + "”?", "Delete “" + (ev.titulo || "Event") + "”?"),
            texto: t("Este evento se repete. Dá para apagar só o dia " + Datas.dataCurta(Datas.ler(chave), true) + " ou a série inteira.",
                     "This event repeats. Delete only " + Datas.dataCurta(Datas.ler(chave), false) + " or the whole series."),
            sim: t("Apagar todos", "Delete all"), perigo: true, terceiro: t("Só este dia", "Only this day")
        }, function () { janela.apagarEvento(ev); }, function () { janela.apagarOcorrencia(ev, chave); });
    }
    // Arrastar no Mês: o evento (ou a série) anda alguns dias.
    function moverEvento(ev, dias) {
        if (dias === 0)
            return;
        var antes = eventos;
        function andar(texto) {
            var d = Datas.somarDias(Datas.ler(texto), dias);
            return ev.diaTodo ? Datas.chave(d) : Datas.momento(d);
        }
        var novo = Object.assign({}, ev, { inicio: andar(ev.inicio), fim: andar(ev.fim || ev.inicio) });
        if (novo.excecoes)
            novo.excecoes = novo.excecoes.map(function (k) { return Datas.chave(Datas.somarDias(Datas.ler(k), dias)); });
        guardarEvento(novo);
        var d = Datas.ler(novo.inicio);
        avisoRapido((ev.repetir || "nunca") !== "nunca"
                    ? t("Série movida para " + Datas.dataCurta(d, true), "Series moved to " + Datas.dataCurta(d, false))
                    : t("Movido para " + Datas.dataCurta(d, true), "Moved to " + Datas.dataCurta(d, false)), "certo",
                    t("Desfazer", "Undo"), function () { janela.trocarEventos(antes); });
    }

    // ----- navegar -----
    function focar(d) {
        foco = Datas.meiaNoite(d);
    }
    function andar(n) {
        if (visao === "mes")
            focar(Datas.somarMeses(foco, n));
        else
            focar(Datas.somarDias(foco, n * (visao === "semana" ? 7 : 1)));
    }
    function irParaHoje() {
        hojeAgora = Datas.hoje();
        focar(hojeAgora);
        if (pagina !== "calendario")
            pagina = "calendario";
    }
    function abrirDia(d) {
        focar(d);
        visao = "dia";
        pagina = "calendario";
    }

    // ----- criar e editar -----
    // Começo sugerido: na próxima hora cheia (hoje) ou às 9h.
    function novoEvento(dia, minutos, diaTodo) {
        var d = Datas.meiaNoite(dia || foco);
        var m = minutos;
        if (m === undefined || m === null) {
            var agora = new Date();
            m = Datas.mesmoDia(d, agora) && agora.getHours() < 23 ? (agora.getHours() + 1) * 60 : 9 * 60;
        }
        var ini = new Date(d.getFullYear(), d.getMonth(), d.getDate(), Math.floor(m / 60), m % 60);
        var fim = new Date(ini.getTime() + 3600000);
        editor.abrir({
            id: Datas.novoId(), titulo: "", diaTodo: !!diaTodo,
            inicio: diaTodo ? Datas.chave(d) : Datas.momento(ini), fim: diaTodo ? Datas.chave(d) : Datas.momento(fim),
            cor: ultimaCor, lembrete: diaTodo ? -1 : 15, repetir: "nunca", ate: "", excecoes: [], local: "", notas: ""
        }, true, Datas.chave(d));
    }
    property string ultimaCor: "salvia"
    function editarEvento(ev, chave) {
        editor.abrir(ev, false, chave || Datas.chave(Datas.ler(ev.inicio)));
    }

    // ----- .ics -----
    function importar(caminho) {
        matsu.rodar("importar", comando(["importar", caminho]));
    }
    function receberImportacao(d) {
        if (!d || !d.ok || !d.eventos || d.eventos.length === 0) {
            avisoRapido(d && d.erro ? t("Não deu para abrir o arquivo: ", "Could not open the file: ") + d.erro
                                    : t("Nenhum evento encontrado no arquivo", "No events found in the file"), "erro");
            return;
        }
        // Os que já estão aqui (mesmo UID e começo, ou mesmo título e horário) ficam de fora.
        var vistos = {};
        for (var i = 0; i < eventos.length; i++) {
            var e = eventos[i];
            vistos[(e.uid || "") + "|" + e.inicio] = true;
            vistos[e.titulo + "|" + e.inicio + "|" + e.fim] = true;
        }
        var novos = d.eventos.filter(function (x) { return !(x.uid && vistos[x.uid + "|" + x.inicio]) && !vistos[x.titulo + "|" + x.inicio + "|" + x.fim]; });
        if (novos.length === 0) {
            avisoRapido(t("Os eventos de “" + d.nome + "” já estão no calendário", "The events from “" + d.nome + "” are already here"), "certo");
            return;
        }
        var repetidos = d.eventos.length - novos.length;
        dialogo.perguntar({
            titulo: novos.length === 1 ? t("Importar 1 evento?", "Import 1 event?") : t("Importar " + novos.length + " eventos?", "Import " + novos.length + " events?"),
            texto: t("Do arquivo “" + d.nome + "”.", "From “" + d.nome + "”.") + (repetidos > 0 ? t(" " + repetidos + " já estavam no calendário e ficam de fora.", " " + repetidos + " were already here and will be skipped.") : ""),
            sim: t("Importar", "Import")
        }, function () {
            var antes = janela.eventos;
            janela.trocarEventos(janela.eventos.concat(novos));
            var primeiro = novos.map(function (x) { return x.inicio; }).sort()[0];
            janela.focar(Datas.ler(primeiro));
            janela.pagina = "calendario";
            janela.avisoRapido(novos.length === 1 ? t("1 evento importado", "1 event imported") : t(novos.length + " eventos importados", novos.length + " events imported"),
                               "certo", t("Desfazer", "Undo"), function () { janela.trocarEventos(antes); });
        });
    }
    function exportar(caminho) {
        matsu.rodar("exportar", comando(["exportar", caminho]));
    }
    function pedirImportar() {
        escolherIcs.open();
    }
    function pedirExportar() {
        if (eventos.length === 0) {
            avisoRapido(t("Ainda não há eventos para exportar", "No events to export yet"));
            return;
        }
        salvarIcs.open();
    }

    // Argumentos: arquivos .ics para importar, "--novo" e "--dia AAAA-MM-DD" (do lembrete).
    function tratarArgumentos(args) {
        for (var i = 0; i < args.length; i++) {
            var a = String(args[i]);
            if (a === "--novo")
                Qt.callLater(novoEvento);
            else if (a === "--proximos")
                pagina = "proximos";
            else if (a === "--dia" && i + 1 < args.length) {
                var d = String(args[++i]);
                if (/^\d{4}-\d{2}-\d{2}$/.test(d))
                    abrirDia(Datas.ler(d));
            } else if (/\.ics$/i.test(a) || a.indexOf("file:") === 0)
                importar(a);
        }
    }

    Connections {
        target: matsu
        function onPronto(chave, saida, codigo) {
            var d = null;
            try {
                d = JSON.parse(saida);
            } catch (e) {
                d = null;
            }
            if (chave === "sincronizar") {
                janela.sincronizando = false;
                if (d) {
                    if (d.idioma)
                        janela.lingua = d.idioma;
                    if (d.vidro && JSON.stringify(d.vidro) !== JSON.stringify(janela.vidroConf))
                        janela.vidroConf = d.vidro;
                    janela.systemd = !!d.systemd;
                } else if (janela.systemd === null) {
                    janela.systemd = false;
                }
                if (janela.sincronizarDeNovo) {
                    janela.sincronizarDeNovo = false;
                    janela.sincronizar();
                }
            } else if (chave === "importar") {
                janela.receberImportacao(d);
            } else if (chave === "exportar") {
                if (d && d.ok)
                    janela.avisoRapido(t("Calendário exportado para “", "Calendar exported to “") + d.arquivo.split("/").pop() + "”", "certo");
                else
                    janela.avisoRapido(t("Não deu para exportar", "Could not export") + (d && d.erro ? ": " + d.erro : ""), "erro");
            }
        }
        function onPedido(argumentos) {
            janela.tratarArgumentos(argumentos);
        }
    }

    Component.onCompleted: {
        carregar();
        carregado = true;
        sincronizar();
        tratarArgumentos(matsu.argumentos);
    }

    // A meia-noite passa com o app aberto: "hoje" muda.
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            var h = Datas.hoje();
            if (!Datas.mesmoDia(h, janela.hojeAgora))
                janela.hojeAgora = h;
        }
    }

    // ----- atalhos -----
    readonly property bool livre: !editor.opened && !dialogo.opened
    Shortcut {
        sequences: [StandardKey.New]
        onActivated: janela.novoEvento()
    }
    Shortcut {
        sequences: ["Ctrl+T"]
        onActivated: janela.irParaHoje()
    }
    Shortcut {
        sequences: [StandardKey.Open]
        onActivated: janela.pedirImportar()
    }
    Shortcut {
        sequences: ["Ctrl+E"]
        onActivated: janela.pedirExportar()
    }
    Shortcut {
        sequences: ["PgUp", "Alt+Left"]
        enabled: janela.livre && janela.pagina === "calendario"
        onActivated: janela.andar(-1)
    }
    Shortcut {
        sequences: ["PgDown", "Alt+Right"]
        enabled: janela.livre && janela.pagina === "calendario"
        onActivated: janela.andar(1)
    }
    // Setas: andam com a pílula de dia em dia (no Mês, para cima e para baixo é uma semana).
    Shortcut {
        sequences: ["Left"]
        enabled: janela.livre && janela.pagina === "calendario"
        onActivated: janela.focar(Datas.somarDias(janela.foco, -1))
    }
    Shortcut {
        sequences: ["Right"]
        enabled: janela.livre && janela.pagina === "calendario"
        onActivated: janela.focar(Datas.somarDias(janela.foco, 1))
    }
    Shortcut {
        sequences: ["Up"]
        enabled: janela.livre && janela.pagina === "calendario" && janela.visao === "mes"
        onActivated: janela.focar(Datas.somarDias(janela.foco, -7))
    }
    Shortcut {
        sequences: ["Down"]
        enabled: janela.livre && janela.pagina === "calendario" && janela.visao === "mes"
        onActivated: janela.focar(Datas.somarDias(janela.foco, 7))
    }
    Shortcut {
        sequences: ["M"]
        enabled: janela.livre && janela.pagina === "calendario"
        onActivated: janela.visao = "mes"
    }
    Shortcut {
        sequences: ["S", "W"]
        enabled: janela.livre && janela.pagina === "calendario"
        onActivated: janela.visao = "semana"
    }
    Shortcut {
        sequences: ["D"]
        enabled: janela.livre && janela.pagina === "calendario"
        onActivated: janela.visao = "dia"
    }

    // ----- menus do botão direito -----
    function abrirMenuEvento(item, x, y, ev, chave) {
        menuEvento.ev = ev;
        menuEvento.chave = chave;
        menuEvento.abrirEm(item, x, y);
    }
    function abrirMenuDia(item, x, y, dia) {
        menuDia.dia = dia;
        menuDia.abrirEm(item, x, y);
    }
    MenuMatsu {
        id: menuEvento
        property var ev: null
        property string chave: ""
        itens: [
            { id: "editar", nome: janela.t("Editar", "Edit"), icone: "matsu-texto-symbolic" },
            { id: "duplicar", nome: janela.t("Duplicar", "Duplicate"), icone: "matsu-mais-symbolic" },
            { id: "apagar", nome: janela.t("Apagar", "Delete"), icone: "matsu-lixeira-symbolic", perigo: true, separador: true }
        ]
        onEscolhido: (id) => {
            if (!ev)
                return;
            if (id === "editar")
                janela.editarEvento(ev, chave);
            else if (id === "apagar")
                janela.pedirApagar(ev, chave);
            else if (id === "duplicar") {
                var copia = Object.assign({}, ev, { id: Datas.novoId(), uid: "", excecoes: [] });
                var antes = janela.eventos;
                janela.guardarEvento(copia);
                janela.avisoRapido(janela.t("Evento duplicado", "Event duplicated"), "certo", janela.t("Desfazer", "Undo"), function () { janela.trocarEventos(antes); });
            }
        }
    }
    MenuMatsu {
        id: menuDia
        property var dia: null
        itens: [
            { id: "novo", nome: janela.t("Novo evento neste dia", "New event on this day"), icone: "matsu-mais-symbolic", atalho: "Ctrl+N" },
            { id: "diaTodo", nome: janela.t("Novo evento de dia todo", "New all-day event"), icone: "matsu-calendario-symbolic" },
            { id: "abrir", nome: janela.t("Ver o dia", "Open day"), icone: Qt.resolvedUrl("icones/agenda.svg"), separador: true }
        ]
        onEscolhido: (id) => {
            if (id === "novo")
                janela.novoEvento(dia);
            else if (id === "diaTodo")
                janela.novoEvento(dia, null, true);
            else if (id === "abrir")
                janela.abrirDia(dia);
        }
    }

    Editor {
        id: editor
    }
    Dialogo {
        id: dialogo
    }
    FileDialog {
        id: escolherIcs
        title: janela.t("Importar calendário", "Import calendar")
        fileMode: FileDialog.OpenFile
        nameFilters: [janela.t("Calendários (*.ics)", "Calendars (*.ics)"), janela.t("Todos os arquivos (*)", "All files (*)")]
        currentFolder: "file://" + matsu.pasta("downloads")
        onAccepted: janela.importar(String(selectedFile))
    }
    FileDialog {
        id: salvarIcs
        title: janela.t("Exportar calendário", "Export calendar")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "ics"
        nameFilters: [janela.t("Calendários (*.ics)", "Calendars (*.ics)")]
        currentFolder: "file://" + matsu.pasta("documentos")
        selectedFile: "file://" + matsu.pasta("documentos") + "/" + janela.t("calendario", "calendar") + ".ics"
        onAccepted: janela.exportar(String(selectedFile))
    }
}
