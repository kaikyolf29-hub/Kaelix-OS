// O menu do botão direito num app da doca, como no Mac e no Windows: as
// janelas abertas dele, nova janela, fixar ou tirar da barra e fechar.
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.taskmanager as TaskManager

PlasmaExtras.Menu {
    id: menu

    property var doca
    property int alvo: -1
    property var janelas: []
    property bool fixado: false
    property bool lancador: false
    property bool novaPode: true

    placement: {
        switch (doca ? doca.borda : "baixo") {
        case "cima": return PlasmaExtras.Menu.BottomPosedLeftAlignedPopup;
        case "esquerda": return PlasmaExtras.Menu.RightPosedTopAlignedPopup;
        case "direita": return PlasmaExtras.Menu.LeftPosedTopAlignedPopup;
        default: return PlasmaExtras.Menu.TopPosedLeftAlignedPopup;
        }
    }

    function abrirPara(i) {
        var modelo = doca.modelo;
        var idx = modelo.makeModelIndex(i);
        alvo = i;
        lancador = modelo.data(idx, TaskManager.AbstractTasksModel.IsLauncher) === true;
        fixado = lancador || modelo.data(idx, TaskManager.AbstractTasksModel.HasLauncher) === true;
        novaPode = modelo.data(idx, TaskManager.AbstractTasksModel.CanLaunchNewInstance) !== false;
        var lista = [];
        if (!lancador) {
            var n = modelo.data(idx, TaskManager.AbstractTasksModel.ChildCount) || 0;
            if (modelo.data(idx, TaskManager.AbstractTasksModel.IsGroupParent) === true && n > 0) {
                for (var j = 0; j < Math.min(n, 12); j++) {
                    var filho = modelo.makeModelIndex(i, j);
                    lista.push({ titulo: String(modelo.data(filho, Qt.DisplayRole) || ""), linha: i, filho: j });
                }
            } else {
                lista.push({ titulo: String(modelo.data(idx, Qt.DisplayRole) || ""), linha: i, filho: -1 });
            }
        }
        janelas = lista;
        visualParent = doca.itemDoApp(i);
        openRelative();
    }

    // As janelas abertas do app, uma por linha (clicar traz a janela).
    property Instantiator listaDeJanelas: Instantiator {
        model: menu.janelas
        delegate: PlasmaExtras.MenuItem {
            required property var modelData
            text: modelData.titulo.length > 60 ? modelData.titulo.substring(0, 57) + "…" : modelData.titulo
            icon: "window"
            onClicked: {
                var m = menu.doca.modelo;
                m.requestActivate(modelData.filho < 0 ? m.makeModelIndex(modelData.linha) : m.makeModelIndex(modelData.linha, modelData.filho));
            }
        }
        onObjectAdded: (index, object) => menu.addMenuItem(object, separadorJanelas)
        onObjectRemoved: (index, object) => menu.removeMenuItem(object)
    }

    PlasmaExtras.MenuItem {
        id: separadorJanelas
        separator: true
        visible: menu.janelas.length > 0
    }

    PlasmaExtras.MenuItem {
        text: menu.lancador ? menu.doca.t("Abrir", "Open") : menu.doca.t("Nova janela", "New window")
        icon: menu.lancador ? "media-playback-start" : "window-new"
        visible: menu.lancador || menu.novaPode
        onClicked: menu.lancador ? menu.doca.clicar(menu.alvo) : menu.doca.novaJanela(menu.alvo)
    }

    PlasmaExtras.MenuItem {
        text: menu.fixado ? menu.doca.t("Tirar da barra", "Unpin from the bar") : menu.doca.t("Fixar na barra", "Pin to the bar")
        icon: menu.fixado ? "window-unpin" : "window-pin"
        onClicked: menu.fixado ? menu.doca.tirar(menu.alvo) : menu.doca.fixar(menu.alvo)
    }

    PlasmaExtras.MenuItem {
        text: menu.doca.t("Organizar os apps da barra…", "Arrange the bar apps…")
        icon: "matsu-barra-symbolic"
        onClicked: menu.doca.fazer("abrir ajustes barra-apps")
    }

    PlasmaExtras.MenuItem {
        separator: true
        visible: !menu.lancador
    }

    PlasmaExtras.MenuItem {
        text: menu.janelas.length > 1 ? menu.doca.t("Fechar todas as janelas", "Close all windows") : menu.doca.t("Fechar janela", "Close window")
        icon: "window-close"
        visible: !menu.lancador
        onClicked: menu.doca.fechar(menu.alvo)
    }
}
