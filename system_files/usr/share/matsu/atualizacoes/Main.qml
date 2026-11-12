// Atualizações do Matsu: a versão deste computador (27, 27.1...), se já saiu uma
// nova no canal do sistema (com o botão para atualizar) e o que mudou em cada
// versão. Abre pelo menu, pelos Ajustes (Sobre) e pelos avisos de atualização.
//
// Quem lê as novidades (/usr/share/matsu/novidades.md, vindo do NOVIDADES.md do
// repositório) e procura a versão nova é o ajudante.py desta pasta (o mesmo do
// aviso de atualização, que o matsu-novidades.timer chama).
// Argumentos: "versoes" abre o histórico; um número (27.1) abre aquela versão.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

JanelaMatsu {
    id: janela

    title: t("Atualizações", "Updates")
    icone: "org.matsu.atualizacoes"
    iconeReserva: "matsu-logo"
    width: gu * 54
    height: gu * 38
    paginas: [
        { id: "inicio", icone: "matsu-baixar-symbolic", nome: t("Atualização", "Update") },
        { id: "versoes", icone: "matsu-relogio-symbolic", nome: t("Todas as versões", "All versions") }
    ]
    conteudo: Qt.resolvedUrl(pagina === "versoes" ? "PaginaVersoes.qml" : "PaginaInicio.qml")

    readonly property string programa: decodeURIComponent(String(Qt.resolvedUrl("ajudante.py")).replace("file://", ""))
    function comando(args) {
        return ["/usr/bin/python3", "-I", programa].concat(args);
    }

    property var dados: null
    // lendo, procurando, em-dia, disponivel, baixada, sem-internet
    property string estado: "lendo"
    property string versaoAberta: ""
    property bool terminalAberto: false

    readonly property var versoes: dados ? dados.versoes : []
    readonly property var atual: {
        if (!dados)
            return null;
        for (var i = 0; i < versoes.length; i++)
            if (versoes[i].versao === dados.versao)
                return versoes[i];
        return versoes.length > 0 ? versoes[0] : null;
    }

    function procurar() {
        estado = "procurando";
        matsu.rodar("procurar", comando(["json", "--procurar"]));
    }
    function atualizar() {
        matsu.soltar(["/usr/libexec/matsu/matsu-central", "abrir", "atualizar"]);
        terminalAberto = true;
    }
    function reiniciar() {
        // A pergunta do Plasma ("Reiniciar agora?"), que deixa a pessoa desistir.
        matsu.soltar(["gdbus", "call", "--session", "--dest", "org.kde.LogoutPrompt", "--object-path",
                      "/LogoutPrompt", "--method", "org.kde.LogoutPrompt.promptReboot"]);
    }
    function abrirPedido(args) {
        if (!args || args.length === 0)
            return;
        var a = String(args[0]);
        if (a === "versoes") {
            versaoAberta = "";
            pagina = "versoes";
        } else if (/^\d+(\.\d+)*$/.test(a)) {
            versaoAberta = a;
            pagina = "versoes";
        } else if (a === "inicio") {
            pagina = "inicio";
        }
    }

    // "12 de nov. de 2026", do número da montagem (20261112.42).
    function dataMontagem(build) {
        var m = /^(\d{4})(\d{2})(\d{2})/.exec(String(build || ""));
        if (!m)
            return "";
        var d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
        return d.toLocaleDateString(local, pt ? "d 'de' MMM 'de' yyyy" : "MMM d, yyyy");
    }
    // "hoje às 10:32", "ontem às 18:05" ou "3 de nov. às 09:10".
    function quando(segundos) {
        if (!segundos)
            return "";
        var d = new Date(segundos * 1000);
        var hoje = new Date();
        var ontem = new Date(hoje.getFullYear(), hoje.getMonth(), hoje.getDate() - 1);
        var hora = d.toLocaleTimeString(local, "HH:mm");
        if (d.toDateString() === hoje.toDateString())
            return t("hoje às ", "today at ") + hora;
        if (d.toDateString() === ontem.toDateString())
            return t("ontem às ", "yesterday at ") + hora;
        return d.toLocaleDateString(local, pt ? "d 'de' MMM" : "MMM d") + t(" às ", " at ") + hora;
    }

    Connections {
        target: matsu
        function onPronto(chave, saida, codigo) {
            var r = null;
            try {
                r = JSON.parse(saida);
            } catch (e) {
                r = null;
            }
            if (chave === "ler") {
                if (r && !janela.dados)
                    janela.dados = r;
            } else if (chave === "procurar") {
                if (r)
                    janela.dados = r;
                if (!r || !r.conseguiu)
                    janela.estado = r && r.baixada ? "baixada" : "sem-internet";
                else if (r.baixada)
                    janela.estado = "baixada";
                else
                    janela.estado = r.remota ? "disponivel" : "em-dia";
            }
        }
        function onPedido(argumentos) {
            janela.abrirPedido(argumentos);
        }
    }

    Component.onCompleted: {
        matsu.rodar("ler", comando(["json"]));
        abrirPedido(matsu.argumentos);
        procurar();
    }
}
