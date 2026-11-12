// A logo oficial de um app: o ícone que veio no catálogo (arquivo ou endereço) ou,
// para o que já está instalado, o do tema. Enquanto chega, um bloco pulsando.
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: icone

    // Caminho do arquivo, endereço (https://...) ou nome de ícone do tema.
    property string fonte: ""
    property string appId: ""
    // Sombra macia embaixo (página do app e destaques).
    property bool sombra: false

    readonly property bool deArquivo: fonte.indexOf("/") === 0 || fonte.indexOf("://") > 0
    readonly property bool pronto: deArquivo ? imagem.status === Image.Ready : tema.valid

    implicitWidth: Math.round(janela.gu * 3)
    implicitHeight: implicitWidth

    Image {
        id: imagem
        anchors.fill: parent
        visible: icone.deArquivo && status === Image.Ready
        source: icone.deArquivo ? janela.arquivo(icone.fonte) : ""
        sourceSize.width: Math.max(64, Math.round(icone.width * 2))
        sourceSize.height: Math.max(64, Math.round(icone.height * 2))
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        smooth: true
        mipmap: true
        layer.enabled: icone.sombra && visible
        layer.effect: SombraIcone {}
    }
    // Sem arquivo (ou o arquivo falhou): o ícone do tema pelo id, que existe
    // para os apps instalados e os que já vêm no Matsu.
    Kirigami.Icon {
        id: tema
        anchors.fill: parent
        visible: !icone.deArquivo || imagem.status === Image.Error
        source: icone.deArquivo ? icone.appId : (icone.fonte || icone.appId)
        fallback: "matsu-loja"
        layer.enabled: icone.sombra && visible
        layer.effect: SombraIcone {}
    }
    Esqueleto {
        anchors.fill: parent
        anchors.margins: Math.round(parent.width * 0.06)
        raio: Math.round(width * 0.24)
        visible: icone.deArquivo && imagem.status !== Image.Ready && imagem.status !== Image.Error
    }
}
