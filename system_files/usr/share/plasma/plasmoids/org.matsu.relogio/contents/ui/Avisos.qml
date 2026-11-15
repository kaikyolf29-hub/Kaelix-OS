// Os avisos dos apps (notificações) na hora em que chegam, no jeito do Mac
// (veja Aviso.qml). No estilo Mac ficam no canto de cima, à direita, embaixo
// da barra de cima, com o mais novo em cima; nos outros estilos, no canto de
// baixo, à direita, em cima da barra, com o mais novo embaixo (como no Windows).
//
// No lugar dos balões do KDE: a peça de avisos do KDE sai da bandeja
// (usr/share/matsu/barra/comum.js e central.js). Quem guarda as notificações,
// o "não perturbe" e os ajustes de cada app continua sendo o KDE
// (org.kde.notificationmanager); a lista das que já chegaram fica no balão
// do relógio (Notificacoes.qml). Só o relógio da tela principal cria este.
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import org.kde.taskmanager as TaskManager

Item {
    id: central

    // Onde os avisos podem ficar (a tela sem as barras) e se a barra do
    // relógio está no alto da tela (estilo Mac).
    property rect area: Qt.rect(0, 0, 0, 0)
    property bool emCima: false
    property var tradutor: (portugues, ingles) => portugues

    function t(portugues, ingles) {
        return tradutor(portugues, ingles);
    }

    // "Mostrar notificações" no resumo do "não perturbe": abre o balão do relógio.
    signal mostrarLista()
    // O balão abriu: o resumo do "não perturbe" já não precisa ficar na tela.
    function listaAberta() {
        modelo.hideInhibitionSummary();
    }

    readonly property int distancia: Math.round(Kirigami.Units.gridUnit * 0.6)
    readonly property int espaco: Kirigami.Units.smallSpacing * 2

    // "agora", "há 5 min" ou a hora: troca sozinho a cada meio minuto.
    property double agora: Date.now()
    Timer {
        interval: 30000
        repeat: true
        running: instanciador.count > 0
        onTriggered: central.agora = Date.now()
    }
    function quando(data) {
        var ms = data ? new Date(data).getTime() : NaN;
        if (isNaN(ms)) {
            return "";
        }
        var minutos = Math.floor((central.agora - ms) / 60000);
        if (minutos < 1) {
            return t("agora", "now");
        }
        if (minutos < 60) {
            return t("há " + minutos + " min", minutos + " min ago");
        }
        return new Date(ms).toLocaleTimeString(Qt.locale(), Locale.ShortFormat);
    }

    NotificationManager.Settings {
        id: ajustes
        // O "não perturbe" do relógio é gravado por fora (matsu-central).
        live: true
    }

    TaskManager.TasksModel {
        id: janelas
        groupMode: TaskManager.TasksModel.GroupDisabled
    }

    // "Não perturbe": até a hora marcada, pedido por um app, com um app em tela
    // cheia (jogos, vídeos) ou com as telas duplicadas, como no KDE.
    property double relogioDoSilencio: Date.now()
    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: central.relogioDoSilencio = Date.now()
    }
    readonly property bool silencio: {
        if (!NotificationManager.Server.valid) {
            return false;
        }
        var ate = ajustes.notificationsInhibitedUntil;
        var calado = !isNaN(ate.getTime()) && relogioDoSilencio < ate.getTime();
        calado = calado || ajustes.notificationsInhibitedByApplication;
        calado = calado || (ajustes.inhibitNotificationsWhenFullscreen && ajustes.fullscreenFocused);
        calado = calado || (ajustes.inhibitNotificationsWhenScreensMirrored && ajustes.screensMirrored);
        return calado;
    }
    // Ao desligar o "não perturbe", um aviso resume o que chegou em silêncio.
    onSilencioChanged: {
        if (!silencio) {
            modelo.showInhibitionSummary(ajustes.lowPriorityHistory ? NotificationManager.Notifications.LowUrgency : NotificationManager.Notifications.NormalUrgency,
                                         ajustes.historyBlacklistedApplications, ajustes.historyBlacklistedServices);
        }
    }
    Binding {
        target: NotificationManager.Server
        property: "inhibited"
        value: central.silencio
        restoreMode: Binding.RestoreBinding
    }

    NotificationManager.Notifications {
        id: modelo
        limit: Math.max(1, Math.floor(central.area.height / (Kirigami.Units.gridUnit * 4)))
        showExpired: false
        showDismissed: false
        showAddedDuringInhibition: false
        blacklistedDesktopEntries: ajustes.popupBlacklistedApplications
        blacklistedNotifyRcNames: ajustes.popupBlacklistedServices
        whitelistedDesktopEntries: central.silencio ? ajustes.doNotDisturbPopupWhitelistedApplications : []
        whitelistedNotifyRcNames: central.silencio ? ajustes.doNotDisturbPopupWhitelistedServices : []
        showJobs: ajustes.jobsInNotifications
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
        groupMode: NotificationManager.Notifications.GroupDisabled
        onShowNotificationsRequested: central.mostrarLista()
        urgencies: {
            var u = 0;
            if (!central.silencio || ajustes.criticalPopupsInDoNotDisturbMode) {
                u |= NotificationManager.Notifications.CriticalUrgency;
            }
            if (!central.silencio) {
                u |= NotificationManager.Notifications.NormalUrgency;
                if (ajustes.lowPriorityPopups) {
                    u |= NotificationManager.Notifications.LowUrgency;
                }
            }
            return u;
        }
    }

    function linha(i) {
        return modelo.index(i, 0);
    }

    // A janela do app do aviso, para abrir quando o app não diz o que fazer.
    function janelaDoApp(app) {
        if (!app) {
            return -1;
        }
        for (var i = 0; i < janelas.count; i++) {
            if (janelas.data(janelas.makeModelIndex(i), TaskManager.AbstractTasksModel.AppId) === app + ".desktop") {
                return i;
            }
        }
        return -1;
    }

    Instantiator {
        id: instanciador
        model: modelo

        delegate: Aviso {
            id: este

            required property int index
            required property var model

            property bool abreAJanela: false
            // Guardado na hora: quando a janela some, a linha do modelo já foi.
            property var idDoAviso
            readonly property bool comBotoes: !!model.hasDefaultAction || (model.actionLabels || []).length > 0
                                              || !!model.hasReplyAction

            aviso: model
            avisos: central
            tempoPadrao: ajustes.popupTimeout

            onMouseEntrou: model.read = true
            onAcabouOTempo: {
                if (tarefa) {
                    model.dismissed = true;
                } else if (model.resident || (comBotoes && !model["transient"])) {
                    // Some da tela, mas continua na lista do relógio.
                    model.expired = true;
                } else {
                    modelo.expire(central.linha(index));
                }
            }
            onFechar: {
                if (rodando) {
                    model.dismissed = true;
                } else {
                    modelo.close(central.linha(index));
                }
            }
            onAbrir: {
                if (abreAJanela) {
                    var j = central.janelaDoApp(model.desktopEntry);
                    if (j >= 0) {
                        janelas.requestActivate(janelas.makeModelIndex(j));
                    }
                    if (!model.resident) {
                        modelo.close(central.linha(index));
                    }
                    return;
                }
                modelo.invokeDefaultAction(central.linha(index), model.resident ? NotificationManager.Notifications.None : NotificationManager.Notifications.Close);
            }
            onBotao: nome => modelo.invokeAction(central.linha(index), nome,
                                                  model.resident ? NotificationManager.Notifications.None : NotificationManager.Notifications.Close)
            onCancelarTarefa: modelo.killJob(central.linha(index))
            onHeightChanged: Qt.callLater(central.posicionar)
            onWidthChanged: Qt.callLater(central.posicionar)

            Component.onCompleted: {
                idDoAviso = model.notificationId;
                if (central.silencio) {
                    model.wasAddedDuringInhibition = false;
                }
                if (model.type === NotificationManager.Notifications.NotificationType && model.desktopEntry) {
                    // O app aparece nos ajustes de notificações do sistema.
                    if (!model.notifyRcName) {
                        ajustes.registerKnownApplication(model.desktopEntry);
                        ajustes.save();
                    }
                    // Sem ação padrão: clicar no aviso traz a janela do app para a frente.
                    if (!model.hasDefaultAction && central.janelaDoApp(model.desktopEntry) >= 0) {
                        abreAJanela = true;
                        model.hasDefaultAction = true;
                    }
                }
                // Daqui em diante, quem conta o tempo é a janela.
                modelo.stopTimeout(central.linha(index));
            }
        }

        onObjectAdded: (indice, janela) => {
            central.posicionar();
            modelo.playSoundHint(central.linha(indice));
        }
        onObjectRemoved: (indice, janela) => {
            // A janela sumiu (fechada ou por um filtro): o modelo volta a contar o tempo.
            if (janela.idDoAviso !== undefined) {
                modelo.startTimeout(janela.idDoAviso);
            }
            Qt.callLater(central.posicionar);
        }
    }

    onAreaChanged: Qt.callLater(posicionar)
    onEmCimaChanged: Qt.callLater(posicionar)

    // Empilha os avisos no canto: o mais novo mais perto da barra.
    function posicionar() {
        if (area.width <= 0 || area.height <= 0) {
            return;
        }
        var y = emCima ? area.y + distancia : area.y + area.height - distancia;
        for (var i = 0; i < instanciador.count; i++) {
            var janela = instanciador.objectAt(i);
            if (!janela) {
                continue;
            }
            var x = Math.round(area.x + area.width - janela.width - distancia);
            var topo;
            var cabe;
            if (emCima) {
                topo = Math.round(y);
                cabe = y + janela.height <= area.y + area.height;
                y += janela.height + espaco;
            } else {
                y -= janela.height;
                topo = Math.round(y);
                cabe = y >= area.y;
                y -= espaco;
            }
            if (janela.x !== x || janela.y !== topo) {
                janela.x = x;
                janela.y = topo;
                // No Wayland a janela que já está na tela só muda de lugar no
                // próximo quadro que ela desenhar: pede um, senão o aviso novo
                // fica por cima dos outros.
                janela.requestUpdate();
            }
            janela.visible = cabe;
        }
    }
}
