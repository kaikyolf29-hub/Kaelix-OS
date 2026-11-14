// A lixeira no fim da doca, como no Mac: o ícone cheio ou vazio, abrir com um
// clique, jogar arquivos soltos em cima e esvaziar pelo botão direito.
// Fica num arquivo à parte (carregado por um Loader): se algo daqui faltar no
// sistema, a doca continua funcionando, só sem a lixeira.
import QtQuick
import QtCore
import Qt.labs.folderlistmodel
import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support

Item {
    id: lixo

    property var doca: null
    readonly property bool cheia: arquivos.count > 0

    Accessible.role: Accessible.Button
    Accessible.name: doca ? doca.t("Lixeira", "Trash") : "Lixeira"

    // Os arquivos da lixeira da pessoa (a pasta avisa sozinha quando algo
    // entra ou sai, sem ficar perguntando).
    FolderListModel {
        id: arquivos
        folder: StandardPaths.writableLocation(StandardPaths.GenericDataLocation) + "/Trash/files"
        showDirs: true
        showDotAndDotDot: false
        showHidden: true
    }

    P5Support.DataSource {
        id: comando
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => disconnectSource(fonte)
    }

    function rodar(linha) {
        comando.connectSource(linha);
    }
    function aspas(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function abrir() {
        Qt.openUrlExternally("trash:/");
    }

    // Arquivos soltos em cima vão para a lixeira (o gio sabe a lixeira certa
    // de cada disco).
    function jogarFora(urls) {
        var lista = [];
        for (var i = 0; i < urls.length; i++) {
            var u = String(urls[i]);
            if (u.indexOf("file://") === 0) {
                lista.push(aspas(decodeURIComponent(u.substring(7))));
            }
        }
        if (lista.length > 0) {
            rodar("gio trash -- " + lista.join(" "));
        }
    }

    function abrirMenu(onde) {
        menu.visualParent = onde;
        menu.openRelative();
    }

    PlasmaExtras.Menu {
        id: menu
        placement: PlasmaExtras.Menu.TopPosedRightAlignedPopup

        PlasmaExtras.MenuItem {
            text: lixo.doca ? lixo.doca.t("Abrir", "Open") : "Abrir"
            icon: "user-trash"
            onClicked: lixo.abrir()
        }
        PlasmaExtras.MenuItem {
            text: lixo.doca ? lixo.doca.t("Esvaziar a lixeira…", "Empty Trash…") : "Esvaziar a lixeira…"
            icon: "trash-empty"
            enabled: lixo.cheia
            // Pergunta antes, como no Mac (o kdialog sai com o tema do Matsu).
            onClicked: {
                var pergunta = lixo.doca.t("Apagar para sempre os itens da lixeira?", "Permanently erase the items in the Trash?");
                var botao = lixo.doca.t("Esvaziar", "Empty");
                lixo.rodar("sh -c " + lixo.aspas("kdialog --title Matsu --warningcontinuecancel " + lixo.aspas(pergunta)
                           + " --continue-label " + lixo.aspas(botao) + " && gio trash --empty"));
            }
        }
    }
}
