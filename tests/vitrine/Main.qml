// Vitrine do kit de peças dos apps do Matsu (system_files/usr/share/matsu/comum):
// uma página com todas, para conferir o visual e as animações. Só para quem
// mexe no sistema; não vai na imagem.
//   /usr/libexec/matsu/matsu-janela org.matsu.vitrine tests/vitrine/Main.qml
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../system_files/usr/share/matsu/comum"

JanelaMatsu {
    id: janela
    title: t("Vitrine do Matsu", "Matsu showcase")
    icone: "org.matsu.ajustes"
    dicaBusca: t("Buscar", "Search")
    width: gu * 64
    height: gu * 44
    paginas: [
        { id: "pecas", icone: "matsu-apps-symbolic", nome: t("Peças", "Pieces") },
        { id: "mais", icone: "matsu-mais-symbolic", nome: t("Mais", "More") }
    ]
    conteudo: Qt.resolvedUrl("Pagina.qml")
    trocaSuave: true

    property real total: 1284.5
    property int passo: 3
    property bool marcadaA: true
    property bool marcadaB: false
    property var chips: ({ rock: true, jazz: false, pop: true, lofi: false })
    property real volume: 64
    property string estadoBotao: ""
    property string ordem: "nome"
    property string fuso: "America/Sao_Paulo"
    property bool favorita: true
    property bool negrito: true
    property int temporizador: 3
    property int atualAba: 1
    // Números que ganham e perdem casas (o NumeroRolante abre e fecha espaço).
    readonly property var contas: [7, 12, 99, 100, 1284, 9]
    property int conta: 2

    Timer {
        // Para as fotos: o roteiro passa por estados diferentes sozinho.
        interval: 2500
        running: matsu.argumentos.indexOf("--demo") >= 0
        repeat: true
        property int n: 0
        onTriggered: {
            n++;
            janela.total += 731.25;
            janela.passo = (janela.passo % 4) + 1;
            janela.marcadaB = !janela.marcadaB;
            janela.estadoBotao = ["carregando", "feito", ""][n % 3];
            janela.conta = (janela.conta + 1) % janela.contas.length;
        }
    }
}
