// Relógio do Matsu (no jeito do Relógio do Windows 11): Alarmes, Temporizador,
// Cronômetro e Relógio mundial, na janela de vidro do Matsu (JanelaMatsu, de ../comum).
//
// As páginas são recriadas a cada troca, então tudo o que precisa continuar vivo
// (o cronômetro correndo, os temporizadores, as cidades) mora aqui, na janela.
// Quem guarda os alarmes e grava os timers do systemd do usuário (para tocar com o
// app fechado e depois de reiniciar) é o ajudante.py; quem toca é o tocar.py.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

JanelaMatsu {
    id: janela

    title: t("Relógio", "Clock")
    icone: "org.matsu.relogio"
    iconeReserva: "matsu-relogio-symbolic"
    paginas: [
        { id: "alarmes", icone: Qt.resolvedUrl("icones/alarme.svg"), nome: t("Alarmes", "Alarms") },
        { id: "temporizador", icone: Qt.resolvedUrl("icones/ampulheta.svg"), nome: t("Temporizador", "Timer") },
        { id: "cronometro", icone: Qt.resolvedUrl("icones/cronometro.svg"), nome: t("Cronômetro", "Stopwatch") },
        { id: "mundo", icone: "matsu-web-symbolic", nome: t("Relógio mundial", "World clock") }
    ]
    conteudo: Qt.resolvedUrl(({ temporizador: "PaginaTemporizador.qml", cronometro: "PaginaCronometro.qml",
                                mundo: "PaginaMundo.qml" })[pagina] || "PaginaAlarmes.qml")
    width: gu * 62
    height: gu * 40

    // Ctrl+N: novo alarme, novo temporizador ou nova cidade, conforme a página.
    signal novo()
    // Pedido de abrir o editor de alarme assim que a página Alarmes abrir (atalho do menu).
    property bool pedirNovoAlarme: false

    readonly property string ajudante: decodeURIComponent(String(Qt.resolvedUrl("ajudante.py")).replace("file://", ""))
    readonly property string tocador: decodeURIComponent(String(Qt.resolvedUrl("tocar.py")).replace("file://", ""))
    readonly property string pastaDados: matsu.pasta("dados")
    function comando(args) {
        return ["/usr/bin/python3", "-I", "-S", ajudante].concat(args);
    }

    // O detalhe do Matsu nos ponteiros e nas marcas: o rosa de cerejeira do logo.
    readonly property color cereja: escuro ? "#f38fb9" : "#c2457f"

    // ----- a hora (uma batida por segundo, no começo de cada segundo) -----
    property date agora: new Date()
    Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: {
            var d = new Date();
            if (Math.floor(d.getTime() / 1000) !== Math.floor(janela.agora.getTime() / 1000))
                janela.agora = d;
        }
    }
    onAgoraChanged: {
        verificarAlarmes();
        verificarTemporizadores();
    }

    // Uma linha de um ListModel como objeto comum (para o Desfazer).
    function copia(modelo, i, chaves) {
        var item = modelo.get(i), r = {};
        for (var k = 0; k < chaves.length; k++)
            r[chaves[k]] = item[chaves[k]];
        return r;
    }
    function dois(n) {
        return n < 10 ? "0" + n : String(n);
    }
    function hhmm(h, m) {
        return dois(h) + ":" + dois(m);
    }
    // Segundos a leste de UTC no fuso do computador agora.
    function desvioLocal() {
        return -new Date().getTimezoneOffset() * 60;
    }
    // "UTC−3", "UTC+5:30".
    function textoUtc(desvio) {
        var s = Math.abs(desvio);
        var h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
        return "UTC" + (desvio < 0 ? "−" : "+") + h + (m ? ":" + dois(m) : "");
    }
    // Quanto falta, do jeito do Windows: "7 h 12 min", "35 min", "2 d 4 h".
    function textoFalta(ms) {
        var min = Math.ceil(ms / 60000);
        if (min < 1)
            return t("menos de 1 min", "less than 1 min");
        var d = Math.floor(min / 1440), h = Math.floor((min % 1440) / 60), m = min % 60;
        if (d > 0)
            return d + " d" + (h > 0 ? " " + h + " h" : "");
        if (h > 0)
            return h + " h" + (m > 0 ? " " + m + " min" : "");
        return m + " min";
    }

    // ----- dias da semana (0 = segunda ... 6 = domingo, como no ajudante) -----
    readonly property var letrasDias: pt ? ["S", "T", "Q", "Q", "S", "S", "D"] : ["M", "T", "W", "T", "F", "S", "S"]
    readonly property var curtosDias: pt ? ["seg", "ter", "qua", "qui", "sex", "sáb", "dom"] : ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    readonly property var nomesDias: pt ? ["segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado", "domingo"]
                                        : ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    function diaDaSemana(d) {
        return (d.getDay() + 6) % 7;
    }
    function resumoDias(dias) {
        if (dias.length === 0)
            return t("Só uma vez", "Once");
        if (dias.length === 7)
            return t("Todos os dias", "Every day");
        if (dias.join(",") === "0,1,2,3,4")
            return t("Dias úteis", "Weekdays");
        if (dias.join(",") === "5,6")
            return t("Fim de semana", "Weekends");
        var nomes = [];
        for (var i = 0; i < dias.length; i++)
            nomes.push(curtosDias[dias[i]] + (pt ? "." : ""));
        return nomes.join(", ");
    }
    // "hoje", "amanhã", "sáb., 14 de nov."
    function quandoDia(alvo, ref) {
        var a = new Date(alvo.getFullYear(), alvo.getMonth(), alvo.getDate());
        var b = new Date(ref.getFullYear(), ref.getMonth(), ref.getDate());
        var dif = Math.round((a - b) / 86400000);
        if (dif === 0)
            return t("hoje", "today");
        if (dif === 1)
            return t("amanhã", "tomorrow");
        return alvo.toLocaleDateString(local, pt ? "ddd., d 'de' MMM" : "ddd, MMM d").toLowerCase().replace("..", ".");
    }

    // ================= Alarmes =================
    ListModel { id: modeloAlarmes }
    property alias alarmes: modeloAlarmes
    property bool carregado: false
    property bool systemd: true
    property var fuso: ({ id: "America/Sao_Paulo", nome: t("Horário de Brasília", "Brasília time") })
    property int pedido: 0
    property string textoArquivo: ""
    property int ultimoMinuto: -1

    // A linha do modelo vira um alarme do jeito do ajudante (dias em lista).
    function alarmeDe(item) {
        return { id: item.id, nome: item.nome, hora: item.hora, minuto: item.minuto, ligado: item.ligado, som: item.som,
                 soneca: item.soneca, data: item.data, dias: item.dias.length ? item.dias.split(",").map(Number) : [] };
    }
    function linhaDe(a) {
        return { id: a.id, nome: a.nome || "", hora: a.hora, minuto: a.minuto, ligado: !!a.ligado, som: a.som || "alarme",
                 soneca: a.soneca === undefined ? 10 : a.soneca, data: a.data || "", dias: (a.dias || []).join(",") };
    }
    function indiceAlarme(id) {
        for (var i = 0; i < modeloAlarmes.count; i++)
            if (modeloAlarmes.get(i).id === id)
                return i;
        return -1;
    }
    function ordenarAlarmes(lista) {
        return lista.slice().sort(function (a, b) {
            return (a.hora * 60 + a.minuto) - (b.hora * 60 + b.minuto) || String(a.nome).localeCompare(String(b.nome)) || (a.id < b.id ? -1 : 1);
        });
    }
    // Deixa o modelo igual à lista, mexendo só no que mudou (os cartões não piscam e
    // a grade anima a entrada, a saída e a troca de lugar).
    function aplicarAlarmes(lista) {
        lista = ordenarAlarmes(lista);
        var ids = {};
        for (var i = 0; i < lista.length; i++)
            ids[lista[i].id] = true;
        for (var j = modeloAlarmes.count - 1; j >= 0; j--)
            if (!ids[modeloAlarmes.get(j).id])
                modeloAlarmes.remove(j);
        for (var k = 0; k < lista.length; k++) {
            var linha = linhaDe(lista[k]);
            var onde = indiceAlarme(linha.id);
            if (onde < 0) {
                modeloAlarmes.insert(k, linha);
            } else {
                if (onde !== k)
                    modeloAlarmes.move(onde, k, 1);
                var atual = modeloAlarmes.get(k);
                for (var chave in linha)
                    if (atual[chave] !== linha[chave])
                        modeloAlarmes.setProperty(k, chave, linha[chave]);
            }
        }
    }
    function listaAlarmes() {
        var l = [];
        for (var i = 0; i < modeloAlarmes.count; i++)
            l.push(alarmeDe(modeloAlarmes.get(i)));
        return l;
    }

    function proximoToque(a, ref) {
        if (!a.ligado)
            return null;
        if (a.dias.length === 0) {
            if (a.data) {
                var p = a.data.split("-");
                var d = new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]), a.hora, a.minuto, 0, 0);
                return d > ref ? d : null;
            }
            var hoje = new Date(ref.getFullYear(), ref.getMonth(), ref.getDate(), a.hora, a.minuto, 0, 0);
            if (hoje <= ref)
                hoje.setDate(hoje.getDate() + 1);
            return hoje;
        }
        for (var k = 0; k < 8; k++) {
            var alvo = new Date(ref.getFullYear(), ref.getMonth(), ref.getDate() + k, a.hora, a.minuto, 0, 0);
            if (a.dias.indexOf(diaDaSemana(alvo)) >= 0 && alvo > ref)
                return alvo;
        }
        return null;
    }
    // O primeiro alarme que vai tocar: { alarme, quando } ou null.
    readonly property var proximo: {
        var _n = modeloAlarmes.count, _a = agora, _m = mudancasAlarmes, melhor = null;
        for (var i = 0; i < modeloAlarmes.count; i++) {
            var a = alarmeDe(modeloAlarmes.get(i));
            var q = proximoToque(a, agora);
            if (q && (!melhor || q < melhor.quando))
                melhor = { alarme: a, quando: q };
        }
        return melhor;
    }
    property int mudancasAlarmes: 0
    Connections {
        target: modeloAlarmes
        function onDataChanged() { janela.mudancasAlarmes++; }
    }

    function chamar(acao, args) {
        pedido++;
        matsu.rodar(acao + ":" + pedido, comando([acao].concat(args)));
    }
    function salvarAlarme(a) {
        // Mostra na hora; o ajudante grava, acerta o systemd e devolve a lista.
        var copia = linhaDe(a);
        if (!a.id) {
            a.id = Math.floor(Math.random() * 0xffffffff).toString(16) + (Date.now() % 4096).toString(16);
            copia.id = a.id;
        }
        if (a.dias.length === 0 && a.ligado)
            copia.data = "";
        var lista = listaAlarmes().filter(function (x) { return x.id !== a.id; });
        lista.push(alarmeDe(copia));
        aplicarAlarmes(lista);
        chamar("salvar-alarme", [JSON.stringify(a)]);
        return a.id;
    }
    function ligarAlarme(id, sim) {
        var i = indiceAlarme(id);
        if (i < 0)
            return;
        modeloAlarmes.setProperty(i, "ligado", sim);
        if (sim && modeloAlarmes.get(i).dias === "")
            modeloAlarmes.setProperty(i, "data", "");
        chamar("ligar-alarme", [id, sim ? "sim" : "nao"]);
    }
    function apagarAlarme(id) {
        var i = indiceAlarme(id);
        if (i < 0)
            return;
        var a = alarmeDe(modeloAlarmes.get(i));
        modeloAlarmes.remove(i);
        chamar("apagar-alarme", [id]);
        avisoRapido(a.nome ? t("Alarme “" + a.nome + "” apagado", "Alarm “" + a.nome + "” deleted") : t("Alarme apagado", "Alarm deleted"),
                    "", t("Desfazer", "Undo"), function () { janela.salvarAlarme(a); });
    }
    function carregarEstado() {
        matsu.rodar("estado", comando(["estado"]));
    }

    // A lista pode mudar com o app aberto (o alarme de uma vez se desliga depois de tocar).
    Timer {
        interval: 4000
        running: janela.carregado
        repeat: true
        onTriggered: {
            var texto = matsu.ler(janela.pastaDados + "/alarmes.json");
            if (texto === janela.textoArquivo || texto.length === 0)
                return;
            janela.textoArquivo = texto;
            try {
                janela.aplicarAlarmes(JSON.parse(texto).alarmes || []);
            } catch (e) {}
        }
    }

    // Na hora do alarme: um aviso aqui dentro também. Sem o systemd (sem os timers),
    // é o app aberto que toca.
    function verificarAlarmes() {
        var chave = ((agora.getFullYear() * 100 + agora.getMonth()) * 100 + agora.getDate()) * 10000 + agora.getHours() * 100 + agora.getMinutes();
        if (chave === ultimoMinuto)
            return;
        var primeira = ultimoMinuto < 0;
        ultimoMinuto = chave;
        if (primeira || !carregado)
            return;
        var hojeIso = agora.getFullYear() + "-" + dois(agora.getMonth() + 1) + "-" + dois(agora.getDate());
        for (var i = 0; i < modeloAlarmes.count; i++) {
            var a = alarmeDe(modeloAlarmes.get(i));
            if (!a.ligado || a.hora !== agora.getHours() || a.minuto !== agora.getMinutes())
                continue;
            var hoje = a.dias.length === 0 ? (!a.data || a.data === hojeIso) : a.dias.indexOf(diaDaSemana(agora)) >= 0;
            if (hoje)
                alarmeTocou(a);
        }
    }
    function alarmeTocou(a) {
        var chave = "tocar-" + a.id;
        if (!systemd)
            matsu.iniciar(chave, ["/usr/bin/python3", "-I", "-S", tocador, "alarme", a.id]);
        avisoRapido((a.nome || t("Alarme", "Alarm")) + " · " + hhmm(a.hora, a.minuto), "", t("Parar", "Stop"), function () {
            matsu.parar(chave);
            if (janela.systemd)
                matsu.rodar("parar", ["systemctl", "--user", "stop", "matsu-alarme-" + a.id + ".service"]);
        });
    }

    // ================= Temporizadores =================
    ListModel { id: modeloTemporizadores }
    property alias temporizadores: modeloTemporizadores
    property int contaTemporizadores: 0

    function idNovo() {
        return (Date.now().toString(36) + Math.floor(Math.random() * 1296).toString(36)).toLowerCase();
    }
    function indiceTemporizador(id) {
        for (var i = 0; i < modeloTemporizadores.count; i++)
            if (modeloTemporizadores.get(i).id === id)
                return i;
        return -1;
    }
    function salvarTemporizadores() {
        var l = [];
        for (var i = 0; i < modeloTemporizadores.count; i++) {
            var x = modeloTemporizadores.get(i);
            l.push({ id: x.id, nome: x.nome, total: x.total, restante: x.restante, fim: x.fim, estado: x.estado });
        }
        matsu.gravar(pastaDados + "/temporizadores.json", JSON.stringify({ versao: 1, temporizadores: l }, null, 1));
    }
    function lerTemporizadores() {
        var texto = matsu.ler(pastaDados + "/temporizadores.json");
        if (!texto)
            return;
        try {
            var l = JSON.parse(texto).temporizadores || [];
            var agoraMs = Date.now();
            for (var i = 0; i < l.length; i++) {
                var x = l[i];
                if (!x.id || !(x.total > 0))
                    continue;
                var estado = ["parado", "rodando", "pausado", "terminado"].indexOf(x.estado) >= 0 ? x.estado : "parado";
                var restante = Number(x.restante) || x.total;
                if (estado === "rodando" && x.fim <= agoraMs) {
                    estado = "terminado";  // terminou com o app fechado (o systemd já tocou)
                    restante = 0;
                }
                modeloTemporizadores.append({ id: String(x.id), nome: String(x.nome || ""), total: x.total, restante: restante,
                                              fim: Number(x.fim) || 0, estado: estado, local: false });
            }
        } catch (e) {}
    }
    function novoTemporizador(nome, segundos, comecar) {
        var id = idNovo();
        if (!nome) {
            var n = modeloTemporizadores.count + 1;
            nome = t("Temporizador " + n, "Timer " + n);
        }
        modeloTemporizadores.append({ id: id, nome: nome, total: segundos, restante: segundos, fim: 0, estado: "parado", local: false });
        if (comecar)
            iniciarTemporizador(id);
        salvarTemporizadores();
        return id;
    }
    function editarTemporizador(id, nome, segundos) {
        var i = indiceTemporizador(id);
        if (i < 0)
            return;
        cancelarAgendado(id);
        modeloTemporizadores.set(i, { nome: nome || modeloTemporizadores.get(i).nome, total: segundos, restante: segundos, fim: 0, estado: "parado" });
        salvarTemporizadores();
    }
    function restanteAgora(x, ms) {
        if (x.estado === "rodando")
            return Math.max(0, (x.fim - ms) / 1000);
        return x.estado === "terminado" ? 0 : x.restante;
    }
    function iniciarTemporizador(id) {
        var i = indiceTemporizador(id);
        if (i < 0)
            return;
        var x = modeloTemporizadores.get(i);
        var restante = x.estado === "terminado" || x.restante <= 0 ? x.total : x.restante;
        var fim = Date.now() + restante * 1000;
        modeloTemporizadores.set(i, { estado: "rodando", restante: restante, fim: fim, local: false });
        agendar(id, fim, x.nome);
        salvarTemporizadores();
    }
    function pausarTemporizador(id) {
        var i = indiceTemporizador(id);
        if (i < 0)
            return;
        var x = modeloTemporizadores.get(i);
        modeloTemporizadores.set(i, { estado: "pausado", restante: Math.max(0, (x.fim - Date.now()) / 1000) });
        cancelarAgendado(id);
        salvarTemporizadores();
    }
    function zerarTemporizador(id) {
        var i = indiceTemporizador(id);
        if (i < 0)
            return;
        modeloTemporizadores.set(i, { estado: "parado", restante: modeloTemporizadores.get(i).total, fim: 0 });
        cancelarAgendado(id);
        salvarTemporizadores();
    }
    function maisUmMinuto(id) {
        var i = indiceTemporizador(id);
        if (i < 0)
            return;
        var x = modeloTemporizadores.get(i);
        if (x.estado === "terminado") {
            cancelarAgendado(id);
            var fim = Date.now() + 60000;
            modeloTemporizadores.set(i, { estado: "rodando", restante: 60, fim: fim, total: Math.max(60, x.total) });
            agendar(id, fim, x.nome);
        } else if (x.estado === "rodando") {
            var novoFim = x.fim + 60000;
            modeloTemporizadores.set(i, { fim: novoFim, total: Math.max(x.total, Math.ceil((novoFim - Date.now()) / 1000)) });
            agendar(id, novoFim, x.nome);
        } else {
            modeloTemporizadores.set(i, { restante: x.restante + 60, total: Math.max(x.total, x.restante + 60) });
        }
        salvarTemporizadores();
    }
    function apagarTemporizador(id) {
        var i = indiceTemporizador(id);
        if (i < 0)
            return;
        var x = copia(modeloTemporizadores, i, ["id", "nome", "total", "restante", "fim", "estado", "local"]);
        cancelarAgendado(id);
        modeloTemporizadores.remove(i);
        salvarTemporizadores();
        avisoRapido(t("Temporizador “" + x.nome + "” apagado", "Timer “" + x.nome + "” deleted"), "", t("Desfazer", "Undo"), function () {
            if (x.estado === "rodando" && x.fim <= Date.now()) {
                x.estado = "terminado";
                x.restante = 0;
            }
            modeloTemporizadores.insert(Math.min(i, modeloTemporizadores.count), x);
            if (x.estado === "rodando")
                janela.agendar(x.id, x.fim, x.nome);
            janela.salvarTemporizadores();
        });
    }
    // O fim vai para o systemd (toca com o app fechado); sem ele, quem toca é o app.
    function agendar(id, fim, nome) {
        if (systemd)
            matsu.rodar("temporizador:" + id, comando(["temporizador", id, String(fim / 1000), nome]));
    }
    function cancelarAgendado(id) {
        matsu.parar("tocar-t-" + id);
        if (systemd)
            matsu.rodar("cancelar:" + id, comando(["cancelar-temporizador", id]));
    }
    function verificarTemporizadores() {
        var ms = agora.getTime();
        for (var i = 0; i < modeloTemporizadores.count; i++) {
            var x = modeloTemporizadores.get(i);
            if (x.estado === "rodando" && x.fim <= ms + 150) {
                modeloTemporizadores.set(i, { estado: "terminado", restante: 0 });
                if (!systemd || x.local)
                    matsu.iniciar("tocar-t-" + x.id, ["/usr/bin/python3", "-I", "-S", tocador, "temporizador", x.id, x.nome]);
                avisoRapido(t("“" + x.nome + "” terminou", "“" + x.nome + "” is done"), "certo");
                salvarTemporizadores();
            }
        }
    }
    readonly property int temporizadoresRodando: {
        var _a = agora, n = 0;
        for (var i = 0; i < modeloTemporizadores.count; i++)
            if (modeloTemporizadores.get(i).estado === "rodando")
                n++;
        return n;
    }

    // ================= Cronômetro =================
    ListModel { id: modeloVoltas }
    property alias voltas: modeloVoltas
    property bool cronoRodando: false
    property real cronoInicio: 0
    property real cronoAcumulado: 0
    function cronoTempo() {
        return cronoAcumulado + (cronoRodando ? Date.now() - cronoInicio : 0);
    }
    function cronoAlternar() {
        if (cronoRodando) {
            cronoAcumulado += Date.now() - cronoInicio;
            cronoRodando = false;
        } else {
            cronoInicio = Date.now();
            cronoRodando = true;
        }
        salvarCronometro();
    }
    function cronoVolta() {
        if (!cronoRodando)
            return;
        var total = cronoTempo();
        var anterior = modeloVoltas.count > 0 ? modeloVoltas.get(0).total : 0;
        modeloVoltas.insert(0, { n: modeloVoltas.count + 1, volta: total - anterior, total: total });
        salvarCronometro();
    }
    function cronoZerar() {
        cronoRodando = false;
        cronoAcumulado = 0;
        cronoInicio = 0;
        modeloVoltas.clear();
        salvarCronometro();
    }
    function salvarCronometro() {
        var v = [];
        for (var i = 0; i < modeloVoltas.count; i++)
            v.push({ n: modeloVoltas.get(i).n, volta: modeloVoltas.get(i).volta, total: modeloVoltas.get(i).total });
        matsu.gravar(pastaDados + "/cronometro.json", JSON.stringify({ rodando: cronoRodando, inicio: cronoInicio,
                                                                       acumulado: cronoAcumulado, voltas: v }));
    }
    function lerCronometro() {
        // O cronômetro continua contando com o app fechado (como no Windows).
        var texto = matsu.ler(pastaDados + "/cronometro.json");
        if (!texto)
            return;
        try {
            var d = JSON.parse(texto);
            cronoAcumulado = Number(d.acumulado) || 0;
            cronoInicio = Number(d.inicio) || 0;
            cronoRodando = !!d.rodando && cronoInicio > 0;
            for (var i = 0; i < (d.voltas || []).length; i++)
                modeloVoltas.append(d.voltas[i]);
        } catch (e) {}
    }
    // "00:01:23" e ",45" (os centésimos ficam à parte: mudam rápido demais para rolar).
    function cronoTexto(ms) {
        var cs = Math.floor(ms / 10);
        var s = Math.floor(cs / 100);
        return { principal: dois(Math.floor(s / 3600)) + ":" + dois(Math.floor(s / 60) % 60) + ":" + dois(s % 60),
                 centesimos: (pt ? "," : ".") + dois(cs % 100) };
    }

    // ================= Relógio mundial =================
    ListModel { id: modeloCidades }
    property alias cidades: modeloCidades
    property var catalogo: []
    property var idsCidades: []

    function cidadeDoCatalogo(id) {
        for (var i = 0; i < catalogo.length; i++)
            if (catalogo[i].id === id)
                return catalogo[i];
        return null;
    }
    function lerCidades() {
        var texto = matsu.ler(pastaDados + "/cidades.json");
        if (!texto) {
            idsCidades = ["lisboa", "nova-york", "toquio"];  // para começar com algo bonito
            return;
        }
        try {
            idsCidades = JSON.parse(texto).cidades || [];
        } catch (e) {
            idsCidades = [];
        }
    }
    function salvarCidades() {
        var l = [];
        for (var i = 0; i < modeloCidades.count; i++)
            l.push(modeloCidades.get(i).id);
        idsCidades = l;
        matsu.gravar(pastaDados + "/cidades.json", JSON.stringify({ cidades: l }));
    }
    function montarCidades() {
        modeloCidades.clear();
        var fusos = [];
        for (var i = 0; i < idsCidades.length; i++) {
            var c = cidadeDoCatalogo(idsCidades[i]);
            if (!c)
                continue;
            modeloCidades.append({ id: c.id, nome: c.nome, pais: c.pais, fuso: c.fuso, desvio: c.desvio, ate: 0, depois: c.desvio });
            if (fusos.indexOf(c.fuso) < 0)
                fusos.push(c.fuso);
        }
        if (fusos.length)
            matsu.rodar("fusos", comando(["fusos"].concat(fusos)));
    }
    function temCidade(id) {
        for (var i = 0; i < modeloCidades.count; i++)
            if (modeloCidades.get(i).id === id)
                return true;
        return false;
    }
    function adicionarCidade(id) {
        var c = cidadeDoCatalogo(id);
        if (!c || temCidade(id))
            return;
        modeloCidades.append({ id: c.id, nome: c.nome, pais: c.pais, fuso: c.fuso, desvio: c.desvio, ate: 0, depois: c.desvio });
        salvarCidades();
        matsu.rodar("fusos", comando(["fusos", c.fuso]));
        avisoRapido(t(c.nome + " entrou no relógio mundial", c.nome + " added to world clock"), "certo");
    }
    function removerCidade(id) {
        for (var i = 0; i < modeloCidades.count; i++) {
            if (modeloCidades.get(i).id === id) {
                var c = copia(modeloCidades, i, ["id", "nome", "pais", "fuso", "desvio", "ate", "depois"]);
                var onde = i;
                modeloCidades.remove(i);
                salvarCidades();
                avisoRapido(t(c.nome + " saiu do relógio mundial", c.nome + " removed"), "", t("Desfazer", "Undo"), function () {
                    if (!janela.temCidade(c.id)) {
                        modeloCidades.insert(Math.min(onde, modeloCidades.count), c);
                        janela.salvarCidades();
                    }
                });
                return;
            }
        }
    }
    // O desvio de uma cidade agora (respeita a troca de horário de verão).
    function desvioCidade(c, ms) {
        return c.ate > 0 && ms / 1000 >= c.ate ? c.depois : c.desvio;
    }

    // ================= Conversa com o ajudante =================
    Connections {
        target: matsu
        function onPronto(chave, saida, codigo) {
            var d = null;
            try {
                d = JSON.parse(saida);
            } catch (e) {}
            if (chave === "estado") {
                if (!d) {
                    janela.carregado = true;
                    janela.systemd = false;
                    return;
                }
                if (d.idioma)
                    janela.lingua = d.idioma;
                if (d.vidro && JSON.stringify(d.vidro) !== JSON.stringify(janela.vidroConf))
                    janela.vidroConf = d.vidro;
                janela.systemd = !!d.systemd;
                if (d.fuso)
                    janela.fuso = d.fuso;
                janela.aplicarAlarmes(d.alarmes || []);
                janela.textoArquivo = matsu.ler(janela.pastaDados + "/alarmes.json");
                janela.carregado = true;
                return;
            }
            var partes = chave.split(":");
            if (["salvar-alarme", "ligar-alarme", "apagar-alarme"].indexOf(partes[0]) >= 0) {
                if (!d || d.ok === false && d.erro && !d.alarmes) {
                    janela.avisoRapido(janela.t("Não deu para guardar o alarme", "Couldn't save the alarm"), "erro");
                    janela.carregarEstado();
                    return;
                }
                if (d.systemd !== undefined)
                    janela.systemd = d.systemd;
                if (Number(partes[1]) === janela.pedido && d.alarmes)
                    janela.aplicarAlarmes(d.alarmes);
                janela.textoArquivo = matsu.ler(janela.pastaDados + "/alarmes.json");
            } else if (partes[0] === "temporizador") {
                // Não deu para agendar no systemd: o app toca quando terminar.
                var i = janela.indiceTemporizador(partes[1]);
                if (i >= 0 && (!d || !d.ok))
                    janela.temporizadores.setProperty(i, "local", true);
            } else if (chave === "cidades") {
                janela.catalogo = d && d.cidades ? d.cidades : [];
                janela.montarCidades();
            } else if (chave === "fusos" && d && d.fusos) {
                for (var f = 0; f < d.fusos.length; f++) {
                    var z = d.fusos[f];
                    for (var c = 0; c < modeloCidades.count; c++)
                        if (modeloCidades.get(c).fuso === z.fuso)
                            modeloCidades.set(c, { desvio: z.desvio, ate: z.ate, depois: z.depois });
                }
            }
        }
        function onPedido(argumentos) {
            janela.abrirPedido(argumentos);
        }
    }

    // Argumentos (das ações do menu): alarmes, novo-alarme, temporizador, cronometro, mundo.
    function abrirPedido(argumentos) {
        if (argumentos.length === 0)
            return;
        if (argumentos[0] === "novo-alarme") {
            pedirNovoAlarme = true;
            if (pagina === "alarmes")
                novo();
            else
                irPara("alarmes");
        } else {
            irPara(argumentos[0]);
        }
    }

    Shortcut {
        sequences: [StandardKey.New]
        onActivated: janela.novo()
    }

    Component.onCompleted: {
        lerTemporizadores();
        lerCronometro();
        lerCidades();
        carregarEstado();
        matsu.rodar("cidades", comando(["cidades"]));
        abrirPedido(matsu.argumentos);
    }

    // Embaixo da lista: o próximo alarme, numa olhada.
    rodapeLateral: Component {
        ColumnLayout {
            spacing: 2
            visible: janela.proximo !== null
            Texto {
                Layout.fillWidth: true
                text: janela.t("Próximo alarme", "Next alarm")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.6
                elide: Text.ElideRight
            }
            Texto {
                Layout.fillWidth: true
                text: janela.proximo ? janela.hhmm(janela.proximo.alarme.hora, janela.proximo.alarme.minuto) : ""
                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 3
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
            Texto {
                Layout.fillWidth: true
                text: janela.proximo ? janela.t("em ", "in ") + janela.textoFalta(janela.proximo.quando - janela.agora) : ""
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
                elide: Text.ElideRight
            }
        }
    }
}
