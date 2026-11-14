/*
 * Tela de sair do Matsu (Desligar, Reiniciar, Sair da conta).
 *
 * Por cima da área de trabalho escurecida:
 *  - pelo botão "Desligar..." do menu: a foto da pessoa, o nome e os botões
 *    redondos (Suspender, Reiniciar, Desligar, Sair), como na tela de bloqueio;
 *  - quando o pedido já é um só (Reiniciar, Desligar ou Sair): um alerta pequeno
 *    de vidro no meio, como os do Mac, com o anel que esvazia até a hora de fazer,
 *    o botão principal branco e o Cancelar.
 *
 * Mesma ligação com o KDE que a tela do KDE (os sinais, sdtype, maysd,
 * spdMethods, canLogout, softwareUpdatePending...): só o desenho é do Matsu.
 * Na montagem, build_files/telas-matsu.py põe este arquivo no lugar do Logout.qml
 * do KDE (no Plasma 6.8, na pasta logout do org.kde.plasma.desktop; antes, no
 * visual do Matsu), com o contagem.js ao lado.
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.coreaddons as KCoreAddons
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.sessions

import "file:///usr/share/matsu/telas" as Matsu
import "contagem.js" as Contagem

Item {
    id: root
    // No Plasma 6.6 a tela diz o próprio tamanho (screenGeometry); no 6.8 a janela
    // de cada monitor estica a tela sozinha.
    Component.onCompleted: {
        if (typeof screenGeometry !== "undefined") {
            width = screenGeometry.width;
            height = screenGeometry.height;
        }
    }

    signal logoutRequested()
    signal haltRequested()
    signal haltUpdateRequested()
    signal suspendRequested(int spdMethod)
    signal rebootRequested()
    signal rebootRequested2(int opt)
    signal rebootUpdateRequested()
    signal cancelRequested()
    signal lockScreenRequested()
    signal cancelSoftwareUpdateRequested()

    function sleepRequested() {
        root.suspendRequested(2);
    }

    function hibernateRequested() {
        root.suspendRequested(4);
    }

    readonly property bool pt: Qt.locale().name.indexOf("pt") === 0
    function t(pt, en) {
        return root.pt ? pt : en;
    }

    readonly property real gu: Kirigami.Units.gridUnit
    readonly property real alturaTela: Math.max(600, height)

    property real timeout: 30
    property real remainingTime: root.timeout

    property var currentAction: {
        switch (sdtype) {
        case ShutdownType.ShutdownTypeReboot:
            return () => softwareUpdatePending ? rebootUpdateRequested() : rebootRequested();
        case ShutdownType.ShutdownTypeHalt:
            return () => softwareUpdatePending ? haltUpdateRequested() : haltRequested();
        default:
            return () => logoutRequested();
        }
    }

    readonly property bool showAllOptions: sdtype === ShutdownType.ShutdownTypeDefault

    KCoreAddons.KUser {
        id: kuser
    }

    // Para o aviso "outras pessoas estão usando o computador".
    SessionsModel {
        id: otherSessionsModel
        includeUnusedSessions: false
        includeOwnSession: false
    }

    QQC2.Action {
        onTriggered: root.cancelRequested()
        shortcut: "Escape"
    }

    onRemainingTimeChanged: {
        if (remainingTime <= 0) {
            (currentAction)();
        }
    }

    Timer {
        id: countDownTimer
        running: !root.showAllOptions
        repeat: true
        interval: 1000
        onTriggered: remainingTime--
        // Com mais de uma tela, uma tecla em qualquer uma para a contagem de todas.
        Component.onCompleted: Contagem.aoParar(function() {
            countDownTimer.running = false;
        })
    }

    // Qualquer tecla para a contagem (a pessoa está decidindo).
    function pararContagem() {
        Contagem.parar();
    }

    // ---- Fundo: a área de trabalho escurecida, e clicar fora cancela. ----
    Rectangle {
        id: fundo
        anchors.fill: parent
        color: "black"
        opacity: 0
        Component.onCompleted: opacity = 0.62
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: root.cancelRequested()
    }

    // ---- Avisos que valem para os dois jeitos. ----
    readonly property var avisos: {
        var lista = [];
        if (otherSessionsModel.count > 0 && (sdtype !== ShutdownType.ShutdownTypeNone || root.showAllOptions)) {
            lista.push(otherSessionsModel.count === 1
                ? root.t("Outra pessoa está usando o computador e pode perder o que não salvou.",
                         "Someone else is using this computer and may lose unsaved work.")
                : root.t(otherSessionsModel.count + " pessoas estão usando o computador e podem perder o que não salvaram.",
                         otherSessionsModel.count + " other people are using this computer and may lose unsaved work."));
        }
        if (rebootToFirmwareSetup) {
            lista.push(root.t("Ao reiniciar, abre o ajuste da placa-mãe (BIOS/UEFI).",
                              "On restart, the firmware setup (BIOS/UEFI) opens."));
        }
        if (rebootToBootLoaderMenu) {
            lista.push(root.t("Ao reiniciar, aparece o menu de início.",
                              "On restart, the boot menu appears."));
        }
        if (rebootToBootLoaderEntry != "") {
            lista.push(root.t("Ao reiniciar, entra em " + rebootToBootLoaderEntry + ".",
                              "On restart, the computer switches to " + rebootToBootLoaderEntry + "."));
        }
        return lista;
    }

    // ======== Jeito 1: todas as opções (o "Desligar..." do menu) ========
    ColumnLayout {
        id: todas
        visible: root.showAllOptions
        anchors.centerIn: parent
        spacing: 0
        opacity: 0
        scale: 0.96
        Component.onCompleted: if (visible) {
            opacity = 1;
            scale = 1;
        }
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
        }

        Matsu.Pessoa {
            Layout.alignment: Qt.AlignHCenter
            lado: Math.round(root.alturaTela * 0.1)
            nome: kuser.fullName || kuser.loginName
            foto: kuser.faceIconUrl
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(root.gu * 0.4)
            text: root.t("O que você quer fazer?", "What would you like to do?")
            color: "white"
            opacity: 0.72
            font.family: Kirigami.Theme.defaultFont.family
            font.pixelSize: Math.max(13, Math.round(root.alturaTela * 0.017))
        }

        Row {
            id: botoes
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(root.alturaTela * 0.045)
            spacing: Math.round(root.gu * 1.4)

            readonly property real lado: Math.round(Math.max(52, root.alturaTela * 0.064))

            Matsu.BotaoRedondo {
                id: suspender
                lado: botoes.lado
                icone: "matsu-lua"
                texto: root.t("Suspender", "Sleep")
                visible: spdMethods.SuspendState
                onClicado: root.sleepRequested()
                KeyNavigation.right: hibernar.visible ? hibernar : reiniciar
            }
            Matsu.BotaoRedondo {
                id: hibernar
                lado: botoes.lado
                icone: "matsu-hibernar"
                texto: root.t("Hibernar", "Hibernate")
                visible: spdMethods.HibernateState
                onClicado: root.hibernateRequested()
                KeyNavigation.left: suspender
                KeyNavigation.right: reiniciar
            }
            Matsu.BotaoRedondo {
                id: reiniciar
                lado: botoes.lado
                icone: "matsu-reiniciar"
                texto: softwareUpdatePending ? root.t("Atualizar e reiniciar", "Update and restart")
                                             : root.t("Reiniciar", "Restart")
                visible: maysd
                onClicado: softwareUpdatePending ? root.rebootUpdateRequested() : root.rebootRequested()
                KeyNavigation.left: hibernar.visible ? hibernar : suspender
                KeyNavigation.right: desligar
            }
            Matsu.BotaoRedondo {
                id: desligar
                lado: botoes.lado
                icone: "matsu-desligar"
                texto: softwareUpdatePending ? root.t("Atualizar e desligar", "Update and shut down")
                                             : root.t("Desligar", "Shut Down")
                visible: maysd
                focus: root.showAllOptions
                onClicado: softwareUpdatePending ? root.haltUpdateRequested() : root.haltRequested()
                KeyNavigation.left: reiniciar
                KeyNavigation.right: sair
            }
            Matsu.BotaoRedondo {
                id: sair
                lado: botoes.lado
                icone: "matsu-sair"
                texto: root.t("Sair", "Log Out")
                visible: canLogout
                onClicado: root.logoutRequested()
                KeyNavigation.left: desligar
                KeyNavigation.right: cancelarTodas
            }
        }

        // Com atualização esperando: reiniciar ou desligar sem instalar.
        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(root.gu * 1.2)
            spacing: root.gu
            visible: softwareUpdatePending && maysd
            LinkTexto {
                texto: root.t("Reiniciar sem atualizar", "Restart without updating")
                onClicado: root.rebootRequested()
            }
            LinkTexto {
                texto: root.t("Desligar sem atualizar", "Shut down without updating")
                onClicado: root.haltRequested()
            }
        }

        Repeater {
            model: root.showAllOptions ? root.avisos : []
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Math.round(root.gu * 0.8)
                Layout.maximumWidth: root.gu * 26
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: modelData
                color: "white"
                opacity: 0.8
                font.family: Kirigami.Theme.defaultFont.family
                font.pixelSize: Math.max(12, Math.round(root.alturaTela * 0.015))
            }
        }

        Matsu.BotaoPilula {
            id: cancelarTodas
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Math.round(root.alturaTela * 0.04)
            altura: Math.round(Math.max(32, root.alturaTela * 0.038))
            texto: root.t("Cancelar", "Cancel")
            focus: root.showAllOptions && !maysd
            onClicado: root.cancelRequested()
            KeyNavigation.left: sair.visible ? sair : desligar
            KeyNavigation.up: desligar
        }
    }

    // ======== Jeito 2: um pedido só (Reiniciar, Desligar ou Sair) ========
    readonly property string acao: sdtype === ShutdownType.ShutdownTypeReboot ? "reiniciar"
                                 : sdtype === ShutdownType.ShutdownTypeHalt ? "desligar" : "sair"

    Rectangle {
        id: alerta
        visible: !root.showAllOptions
        anchors.centerIn: parent
        width: Math.round(root.gu * 17)
        height: coluna.implicitHeight + Math.round(root.gu * 2.6)
        radius: Math.round(root.gu * 1.1)
        color: Qt.rgba(0.13, 0.13, 0.15, 0.9)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        opacity: 0
        scale: 0.94
        Component.onCompleted: if (visible) {
            opacity = 1;
            scale = 1;
        }
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutBack }
        }

        // O toque no alerta não cancela (só fora dele).
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: coluna
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Math.round(root.gu * 1.3)
            }
            spacing: 0

            // O ícone dentro do anel que esvazia até a hora de fazer.
            Item {
                id: relogio
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: Math.round(root.gu * 3.6)
                implicitHeight: implicitWidth

                property real fracao: Math.max(0, root.remainingTime / root.timeout)
                Behavior on fracao {
                    enabled: countDownTimer.running
                    NumberAnimation { duration: 1000 }
                }
                onFracaoChanged: anel.requestPaint()

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Math.round(root.gu * 0.32)
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, 0.1)
                }
                Canvas {
                    id: anel
                    anchors.fill: parent
                    onPaint: {
                        var c = getContext("2d");
                        c.reset();
                        var r = width / 2 - 2;
                        c.lineWidth = 2.5;
                        c.lineCap = "round";
                        c.strokeStyle = Qt.rgba(1, 1, 1, 0.14);
                        c.beginPath();
                        c.arc(width / 2, height / 2, r, 0, Math.PI * 2);
                        c.stroke();
                        if (relogio.fracao > 0) {
                            c.strokeStyle = Qt.rgba(1, 1, 1, 0.92);
                            c.beginPath();
                            c.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * relogio.fracao);
                            c.stroke();
                        }
                    }
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.round(root.gu * 1.5)
                    height: width
                    source: "/usr/share/icons/Matsu/status/symbolic/matsu-" + root.acao + "-symbolic.svg"
                    isMask: true
                    color: "white"
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(root.gu * 0.8)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: {
                    if (root.acao === "reiniciar")
                        return softwareUpdatePending ? root.t("Atualizar e reiniciar agora?", "Update and restart now?")
                                                     : root.t("Reiniciar agora?", "Restart now?");
                    if (root.acao === "desligar")
                        return softwareUpdatePending ? root.t("Atualizar e desligar agora?", "Update and shut down now?")
                                                     : root.t("Desligar agora?", "Shut down now?");
                    return root.t("Sair da sua conta?", "Log out now?");
                }
                color: "white"
                font.family: Kirigami.Theme.defaultFont.family
                font.pixelSize: Math.round(root.gu * 0.95)
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(root.gu * 0.3)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                readonly property int s: Math.max(0, Math.ceil(root.remainingTime))
                text: {
                    if (!countDownTimer.running)
                        return root.t("Os apps abertos vão fechar.", "Open apps will close.");
                    var quando = root.pt ? (s === 1 ? "1 segundo" : s + " segundos")
                                         : (s === 1 ? "1 second" : s + " seconds");
                    if (root.acao === "reiniciar")
                        return root.t("Reinicia sozinho em " + quando + ".", "Restarting in " + quando + ".");
                    if (root.acao === "desligar")
                        return root.t("Desliga sozinho em " + quando + ".", "Shutting down in " + quando + ".");
                    return root.t("Sai sozinho em " + quando + ".", "Logging out in " + quando + ".");
                }
                color: "white"
                opacity: 0.7
                font.family: Kirigami.Theme.defaultFont.family
                font.pixelSize: Math.round(root.gu * 0.72)
            }

            Repeater {
                model: root.showAllOptions ? [] : root.avisos
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: Math.round(root.gu * 0.5)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: modelData
                    color: "#f2c861"
                    font.family: Kirigami.Theme.defaultFont.family
                    font.pixelSize: Math.round(root.gu * 0.68)
                }
            }

            Matsu.BotaoPilula {
                id: confirmar
                Layout.fillWidth: true
                Layout.topMargin: Math.round(root.gu * 1.1)
                altura: Math.round(root.gu * 1.75)
                principal: true
                focus: !root.showAllOptions
                texto: root.acao === "reiniciar" ? root.t("Reiniciar", "Restart")
                     : root.acao === "desligar" ? root.t("Desligar", "Shut Down") : root.t("Sair", "Log Out")
                onClicado: (root.currentAction)()
                KeyNavigation.down: cancelar
                KeyNavigation.tab: cancelar
            }
            Matsu.BotaoPilula {
                id: cancelar
                Layout.fillWidth: true
                Layout.topMargin: Math.round(root.gu * 0.45)
                altura: Math.round(root.gu * 1.75)
                texto: root.t("Cancelar", "Cancel")
                onClicado: root.cancelRequested()
                KeyNavigation.up: confirmar
                KeyNavigation.tab: semAtualizar.visible ? semAtualizar : confirmar
            }
            LinkTexto {
                id: semAtualizar
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Math.round(root.gu * 0.6)
                visible: softwareUpdatePending && root.acao !== "sair"
                texto: root.acao === "reiniciar" ? root.t("Reiniciar sem atualizar", "Restart without updating")
                                                 : root.t("Desligar sem atualizar", "Shut down without updating")
                onClicado: root.acao === "reiniciar" ? root.rebootRequested() : root.haltRequested()
            }
        }
    }

    // Qualquer tecla para a contagem (as teclas que os botões não usam sobem até aqui).
    Keys.onPressed: root.pararContagem()

    // Link discreto (Reiniciar sem atualizar).
    component LinkTexto: Text {
        id: link
        property string texto: ""
        signal clicado()
        text: texto
        color: "white"
        opacity: toqueLink.containsMouse || activeFocus ? 1 : 0.7
        font.family: Kirigami.Theme.defaultFont.family
        font.pixelSize: Math.max(12, Math.round(Kirigami.Units.gridUnit * 0.7))
        font.underline: toqueLink.containsMouse || activeFocus
        activeFocusOnTab: true
        Keys.onReturnPressed: link.clicado()
        Keys.onSpacePressed: link.clicado()
        MouseArea {
            id: toqueLink
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: link.clicado()
        }
    }
}
