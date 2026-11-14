// Boas-vindas do Matsu: o assistente do primeiro login, no jeito do Mac (uma
// coisa por tela, com o botão Continuar embaixo à direita). Abre sozinho uma vez,
// no primeiro login (matsu-boas-vindas, pelo autostart), e pelo menu.
//
// Fica no lugar da Central de boas-vindas do KDE, que falava do Plasma, do
// Discover e do KDE Connect (o build.sh desliga ela).
//
// Telas: Olá, Aparência (tema e vidro), Barra (Fusão, Mac, Windows), Navegador
// (Brave, Chrome), Seus apps (Loja, Central de jogos, Ajustes) e Tudo pronto.
// Quem muda o sistema é o matsu-central (tema, barra, vidro) e o comando matsu
// (navegador), os mesmos dos Ajustes.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../comum"

JanelaMatsu {
    id: janela

    title: t("Boas-vindas", "Welcome")
    icone: "matsu-logo"
    width: gu * 46
    height: gu * 34
    minimumWidth: gu * 38
    minimumHeight: gu * 29
    conteudo: Qt.resolvedUrl("Assistente.qml")

    // ----- as telas, em ordem -----
    readonly property var telas: ["ola", "aparencia", "barra", "navegador", "apps", "pronto"]
    property int passo: 0
    property int direcao: 1
    function ir(n) {
        if (n < 0 || n >= telas.length || n === passo)
            return;
        direcao = n > passo ? 1 : -1;
        passo = n;
    }
    function seguir() {
        // Saindo do navegador sem escolher: fica o Firefox, e a pergunta do
        // primeiro login (matsu navegador --primeira-vez) não aparece depois.
        if (telas[passo] === "navegador" && navegador === "")
            matsu.soltar(["/usr/bin/matsu", "navegador", "nenhum"]);
        if (passo === telas.length - 1)
            concluir();
        else
            ir(passo + 1);
    }

    // ----- o nome do sistema ("Matsu 27 OS"), do os-release -----
    readonly property string nomeSistema: {
        var texto = matsu.ler("/etc/os-release") || matsu.ler("/usr/lib/os-release");
        var m = /^PRETTY_NAME="?([^"\n]*)"?$/m.exec(texto || "");
        return m && m[1].indexOf("Matsu") === 0 ? m[1] : "Matsu";
    }

    // ----- o que o computador tem agora (matsu-central estado) -----
    property bool temaEscuro: escuro
    property string barra: "fusao"
    property bool vidro: true
    property string vidroCor: "padrao"
    // "tema" ou "barra" enquanto o comando roda (o cartão mostra a rodinha).
    property string mudando: ""

    // ----- navegador: "", "instalando", "feito" ou "erro" -----
    property string navegador: ""
    property string navegadorEscolhido: ""

    readonly property string central: "/usr/libexec/matsu/matsu-central"
    function tema(paraEscuro) {
        if (mudando !== "")
            return;
        temaEscuro = paraEscuro;
        mudando = "tema";
        matsu.rodar("tema", [central, "tema", paraEscuro ? "escuro" : "claro"]);
    }
    function estiloBarra(estilo) {
        if (mudando !== "" || estilo === barra)
            return;
        barra = estilo;
        mudando = "barra";
        matsu.rodar("barra", [central, "barra", estilo]);
    }
    function ligarVidro(ligado) {
        vidro = ligado;
        matsu.rodar("vidro", [central, "vidro", vidroCor, ligado ? "normal" : "sem"]);
    }
    function instalarNavegador(qual) {
        if (navegador === "instalando")
            return;
        navegadorEscolhido = qual;
        navegador = "instalando";
        // Num serviço à parte: a instalação continua se a janela fechar antes, e o
        // --wait devolve o resultado dela para cá.
        matsu.rodar("navegador", ["systemd-run", "--user", "--wait", "--collect", "--quiet",
                                  "--unit=matsu-navegador-" + Date.now(), "/usr/bin/matsu", "navegador", qual]);
    }
    function abrirApp(id) {
        matsu.soltar(["kstart", "--application", id]);
    }

    // Visto uma vez: o autostart não abre de novo (fechando no X também conta).
    readonly property string marca: matsu.pasta("config") + "/boas-vindas-vista"
    function concluir() {
        close();
    }
    onClosing: matsu.gravar(marca, "vista\n")

    Connections {
        target: matsu
        function onPronto(chave, saida, codigo) {
            if (chave === "estado") {
                var linhas = String(saida).split("\n");
                for (var i = 0; i < linhas.length; i++) {
                    var p = linhas[i].indexOf("=");
                    if (p < 0)
                        continue;
                    var k = linhas[i].slice(0, p), v = linhas[i].slice(p + 1);
                    if (k === "escuro")
                        janela.temaEscuro = v === "1" || v === "true" || v === "sim";
                    else if (k === "barra" && ["fusao", "mac", "windows"].indexOf(v) >= 0)
                        janela.barra = v;
                    else if (k === "vidro_transparencia")
                        janela.vidro = v !== "sem";
                    else if (k === "vidro_cor" && v !== "")
                        janela.vidroCor = v;
                }
            } else if (chave === "tema" || chave === "barra") {
                janela.mudando = "";
            } else if (chave === "navegador") {
                janela.navegador = codigo === 0 ? "feito" : "erro";
            }
        }
    }

    Component.onCompleted: matsu.rodar("estado", [central, "estado"])
}
