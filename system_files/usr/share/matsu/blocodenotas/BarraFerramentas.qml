// A barra de ferramentas leve, como a do Bloco de Notas do Windows 11: Arquivo,
// Editar e Exibir (com um menu aberto, passar o mouse troca de menu) e, na
// ponta, localizar e a fonte.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: barra

    property alias botaoArquivo: botaoArquivo
    property alias botaoFonte: botaoFonte

    implicitHeight: Math.round(janela.gu * 2.35)

    component BotaoMenu: MouseArea {
        id: bm
        property string texto: ""
        property var menu: null
        readonly property bool aberto: menu !== null && menu.visible
        property double fechouEm: 0

        implicitWidth: rotulo.implicitWidth + Math.round(janela.gu * 1.3)
        implicitHeight: Math.round(janela.gu * 1.85)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.ButtonMenu
        Accessible.name: texto

        function abrir() {
            if (janela.menuDaBarra && janela.menuDaBarra !== menu)
                janela.menuDaBarra.close();
            menu.abrirEm(bm, 0, bm.height + 3);
        }
        onAbertoChanged: if (!aberto) fechouEm = Date.now()
        // O clique que fechou o menu (fora dele) não abre de novo.
        onClicked: if (!aberto && Date.now() - fechouEm > 250) abrir()
        onContainsMouseChanged: if (containsMouse && janela.menuDaBarra && !aberto) abrir()

        Rectangle {
            anchors.fill: parent
            radius: Math.round(janela.gu * 0.32)
            color: janela.tinta(bm.aberto ? 0.09 : (bm.pressed ? 0.1 : (bm.containsMouse ? 0.065 : 0)))
            border.width: bm.aberto ? 1 : 0
            border.color: janela.tinta(janela.escuro ? 0.12 : 0.14)
            Behavior on color {
                ColorAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }
        }
        Texto {
            id: rotulo
            anchors.centerIn: parent
            text: bm.texto
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.round(janela.gu * 0.45)
        anchors.rightMargin: Math.round(janela.gu * 0.45)
        spacing: 2

        BotaoMenu {
            id: botaoArquivo
            texto: janela.t("Arquivo", "File")
            menu: janela.menus.arquivo
        }
        BotaoMenu {
            texto: janela.t("Editar", "Edit")
            menu: janela.menus.editar
        }
        BotaoMenu {
            texto: janela.t("Exibir", "View")
            menu: janela.menus.exibir
        }
        Item {
            Layout.fillWidth: true
        }
        BotaoIcone {
            icone: "matsu-busca-symbolic"
            dica: janela.t("Localizar (Ctrl+F)", "Find (Ctrl+F)")
            ligado: janela.tela !== null && janela.tela.busca.aberta
            onClicado: {
                if (janela.tela.busca.aberta)
                    janela.tela.busca.fechar();
                else
                    janela.tela.busca.abrir(false);
            }
        }
        BotaoIcone {
            id: botaoFonte
            icone: "matsu-texto-symbolic"
            dica: janela.t("Fonte", "Font")
            ligado: janela.menus.fonte.visible
            onClicado: janela.abrirFonte()
        }
    }
}
