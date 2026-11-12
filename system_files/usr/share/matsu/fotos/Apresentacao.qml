// Apresentação de slides: em tela cheia, uma foto depois da outra, passando por
// dissolução e com um zoom bem lento (efeito Ken Burns). O mouse parado esconde
// tudo; mexendo, aparecem os controles e a linha do tempo até a próxima.
// Esc sai, Espaço pausa, as setas passam.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

FocusScope {
    id: apre

    property var lista: []
    property int indice: 0
    property bool pausada: false
    property bool rodando: false
    property int intervalo: 5000
    property bool mexendo: false
    property int visibilidadeAntes: Window.Windowed
    readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    property Item frente: slideA
    property Item tras: slideB

    signal sair(string caminho)

    visible: opacity > 0
    opacity: rodando ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: 320
        }
    }

    function comecar(l, i) {
        lista = l;
        pausada = false;
        visibilidadeAntes = janela.visibility;
        slideA.foto = null;
        slideB.foto = null;
        slideA.opacity = 0;
        slideB.opacity = 0;
        rodando = true;
        janela.showFullScreen();
        forceActiveFocus();
        mostrar(i);
    }
    function parar() {
        if (!rodando)
            return;
        rodando = false;
        relogio.stop();
        if (janela.visibility === Window.FullScreen) {
            if (visibilidadeAntes === Window.Maximized)
                janela.showMaximized();
            else
                janela.showNormal();
        }
        apre.sair(lista.length > 0 ? lista[indice].caminho : "");
    }
    function mostrar(i) {
        if (lista.length === 0)
            return;
        indice = (i % lista.length + lista.length) % lista.length;
        relogio.stop();
        tras.foto = lista[indice];
        if (tras.pronta)
            trocar();
    }
    function trocar() {
        var novo = tras;
        tras = frente;
        frente = novo;
        novo.z = 1;
        tras.z = 0;
        dissolver.restart();
        if (!pausada) {
            relogio.restart();
            correr.restart();
        }
    }
    function aoCarregar(s) {
        if (s === tras && rodando)
            trocar();
    }
    function mexer() {
        mexendo = true;
        sossego.restart();
    }

    Timer {
        id: relogio
        interval: apre.intervalo
        onTriggered: apre.mostrar(apre.indice + 1)
    }
    Timer {
        id: sossego
        interval: 2200
        onTriggered: apre.mexendo = false
    }
    onPausadaChanged: {
        if (pausada) {
            relogio.stop();
            correr.stop();
            progresso.width = 0;
        } else if (rodando) {
            relogio.restart();
            correr.restart();
        }
    }

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Escape || e.key === Qt.Key_F5) {
            apre.parar();
        } else if (e.key === Qt.Key_Space) {
            apre.pausada = !apre.pausada;
            apre.mexer();
        } else if (e.key === Qt.Key_Left) {
            apre.mostrar(apre.indice - 1);
        } else if (e.key === Qt.Key_Right) {
            apre.mostrar(apre.indice + 1);
        } else {
            return;
        }
        e.accepted = true;
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: apre.mexendo ? Qt.ArrowCursor : Qt.BlankCursor
        onPositionChanged: apre.mexer()
        onClicked: apre.pausada = !apre.pausada
        onWheel: (w) => w.accepted = true
    }

    component Slide: Item {
        id: slide
        property var foto: null
        readonly property int giro: foto ? janela.giroDe(foto.caminho) : 0
        readonly property bool pronta: imagem.status === Image.Ready
        readonly property bool falhou: imagem.status === Image.Error
        readonly property int lado: Math.ceil(Math.max(apre.width, apre.height, 1) * apre.dpr / 256) * 256
        anchors.fill: parent
        opacity: 0
        onProntaChanged: if (pronta) apre.aoCarregar(slide)
        onFalhouChanged: if (falhou && slide === apre.tras) apre.mostrar(apre.indice + 1)
        Image {
            id: imagem
            anchors.centerIn: parent
            width: slide.giro % 180 !== 0 ? parent.height : parent.width
            height: slide.giro % 180 !== 0 ? parent.width : parent.height
            rotation: slide.giro
            source: slide.foto ? janela.arquivo(slide.foto.caminho) : ""
            sourceSize: Qt.size(slide.lado, slide.lado)
            fillMode: Image.PreserveAspectFit
            autoTransform: true
            asynchronous: true
            smooth: true
            mipmap: true
        }
    }
    Slide {
        id: slideA
    }
    Slide {
        id: slideB
    }
    ParallelAnimation {
        id: dissolver
        NumberAnimation { target: apre.frente; property: "opacity"; to: 1; duration: 900; easing.type: Easing.InOutQuad }
        NumberAnimation { target: apre.tras; property: "opacity"; to: 0; duration: 900; easing.type: Easing.InOutQuad }
        // O zoom lento, que atravessa a foto inteira até a próxima.
        NumberAnimation { target: apre.frente; property: "scale"; from: 1; to: 1.07; duration: apre.intervalo + 900; easing.type: Easing.Linear }
    }

    // Controles, com o mouse mexendo: anterior, pausar, próxima, sair.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(janela.gu * 2.2)
        width: linhaControles.implicitWidth + 12
        height: Math.round(janela.gu * 2.8)
        radius: height / 2
        color: Qt.rgba(0.08, 0.08, 0.09, 0.8)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        z: 5
        opacity: apre.mexendo || apre.pausada ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 220
            }
        }
        RowLayout {
            id: linhaControles
            anchors.centerIn: parent
            spacing: 2
            BotaoVisor {
                icone: "matsu-voltar-symbolic"
                dica: janela.t("Anterior", "Previous")
                onClicado: apre.mostrar(apre.indice - 1)
            }
            BotaoVisor {
                icone: apre.pausada ? String(Qt.resolvedUrl("icones/tocar.svg")) : String(Qt.resolvedUrl("icones/pausa.svg"))
                dica: apre.pausada ? janela.t("Continuar", "Resume") : janela.t("Pausar", "Pause")
                atalho: janela.t("Espaço", "Space")
                onClicado: apre.pausada = !apre.pausada
            }
            BotaoVisor {
                icone: "matsu-seta-symbolic"
                dica: janela.t("Próxima", "Next")
                onClicado: apre.mostrar(apre.indice + 1)
            }
            Rectangle {
                implicitWidth: 1
                implicitHeight: Math.round(janela.gu * 1.2)
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                color: Qt.rgba(1, 1, 1, 0.16)
            }
            QQC2.Label {
                text: janela.num(apre.indice + 1) + " / " + janela.num(apre.lista.length)
                color: "#ffffff"
                opacity: 0.75
                font.features: { "tnum": 1 }
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
            BotaoVisor {
                Layout.leftMargin: 4
                icone: "matsu-fechar-symbolic"
                texto: janela.t("Sair", "Exit")
                atalho: "Esc"
                onClicado: apre.parar()
            }
        }
    }
    // A linha fininha embaixo: quanto falta para a próxima.
    Rectangle {
        id: progresso
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        height: 3
        z: 5
        color: Qt.rgba(1, 1, 1, 0.55)
        opacity: apre.mexendo ? 1 : 0
        width: 0
        Behavior on opacity {
            NumberAnimation {
                duration: 220
            }
        }
        NumberAnimation on width {
            id: correr
            running: false
            from: 0
            to: apre.width
            duration: apre.intervalo
        }
    }
}
