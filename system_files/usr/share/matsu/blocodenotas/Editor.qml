// O texto de uma aba: cada aba tem o seu (com o próprio desfazer, cursor e
// rolagem). Números de linha opcionais à esquerda, os achados da busca
// realçados em âmbar atrás do texto, Ctrl+rodinha muda o zoom.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import "../comum"
import "logica.js" as Logica

Item {
    id: ed

    required property int index
    required property bool carregando

    property alias area: area
    property alias rolagem: rolagem
    property bool pronto: false
    // Os começos dos achados da busca e o tamanho de cada um.
    property var achados: []
    property int tamanhoAchado: 0

    // As trocas feitas pelo app (substituir, data e hora) viram duas entradas no
    // desfazer do Qt (apagar e escrever); aqui elas são desfeitas de uma vez.
    property var pilhaDesfazer: []
    property var pilhaRefazer: []
    property bool guarda: false

    readonly property bool modificado: area.textDocument.modified
    onModificadoChanged: if (pronto) janela.abas.setProperty(index, "modificado", modificado)
    onCarregandoChanged: if (!carregando && !pronto) aplicar()
    Component.onCompleted: if (!carregando) aplicar()

    // O texto que a aba trouxe (arquivo lido, sessão), o cursor e a rolagem.
    function aplicar() {
        var m = janela.abas.get(index);
        guarda = true;
        area.text = m.textoInicial;
        guarda = false;
        area.textDocument.modified = m.modificadoInicial;
        area.cursorPosition = Math.min(m.cursorInicial, area.length);
        var r = m.rolagemInicial;
        janela.abas.setProperty(index, "textoInicial", "");
        pronto = true;
        janela.abas.setProperty(index, "modificado", area.textDocument.modified);
        if (r > 0)
            Qt.callLater(function () {
                rolagem.contentY = Math.max(0, Math.min(r, rolagem.contentHeight - rolagem.height));
            });
        atualizarNumeros();
    }
    function focar() {
        area.forceActiveFocus();
    }
    function trocar(ini, fim, novo) {
        guarda = true;
        var passos = 0;
        if (fim > ini) {
            area.remove(ini, fim);
            passos++;
        }
        if (novo.length > 0) {
            area.insert(ini, novo);
            passos++;
        }
        guarda = false;
        if (passos > 0)
            pilhaDesfazer.push(passos);
        pilhaRefazer = [];
        janela.mexeu();
    }
    function desfazer() {
        var n = pilhaDesfazer.length > 0 ? pilhaDesfazer.pop() : 1;
        guarda = true;
        for (var k = 0; k < n; k++)
            area.undo();
        guarda = false;
        pilhaRefazer.push(n);
        janela.mexeu();
    }
    function refazer() {
        var n = pilhaRefazer.length > 0 ? pilhaRefazer.pop() : 1;
        guarda = true;
        for (var k = 0; k < n; k++)
            area.redo();
        guarda = false;
        pilhaDesfazer.push(n);
        janela.mexeu();
    }
    // Leva até a posição, com folga em cima e embaixo.
    function mostrar(pos) {
        var r = area.positionToRectangle(pos);
        var folga = r.height * 3;
        if (r.y < rolagem.contentY + r.height)
            rolagem.contentY = Math.max(0, r.y - folga);
        else if (r.y + r.height > rolagem.contentY + rolagem.height - r.height)
            rolagem.contentY = Math.min(Math.max(0, rolagem.contentHeight - rolagem.height), r.y + r.height + folga - rolagem.height);
        if (!janela.quebra) {
            if (r.x < rolagem.contentX + folga)
                rolagem.contentX = Math.max(0, r.x - folga * 2);
            else if (r.x > rolagem.contentX + rolagem.width - folga)
                rolagem.contentX = Math.min(Math.max(0, rolagem.contentWidth - rolagem.width), r.x - rolagem.width + folga * 2);
        }
    }

    FontMetrics {
        id: metricas
        font: area.font
    }

    // ----- números de linha -----
    property var inicios: [0]
    property bool iniciosVelhos: true
    property var linhasVisiveis: []
    readonly property int linhaDoCursor: janela.numeros ? Logica.linhaDaPosicao(inicios, area.cursorPosition) + 1 : 0
    function atualizarNumeros() {
        if (!janela.numeros || !visible) {
            linhasVisiveis = [];
            return;
        }
        if (iniciosVelhos) {
            inicios = Logica.iniciosDasLinhas(area.text);
            iniciosVelhos = false;
        }
        var topo = area.positionAt(0, rolagem.contentY);
        var l = Logica.linhaDaPosicao(inicios, topo);
        var lista = [];
        var baixo = rolagem.contentY + rolagem.height;
        for (; l < inicios.length && lista.length < 500; l++) {
            var r = area.positionToRectangle(inicios[l]);
            if (r.y > baixo)
                break;
            lista.push({ n: l + 1, y: r.y, h: r.height });
        }
        linhasVisiveis = lista;
    }
    Connections {
        target: janela
        function onNumerosChanged() {
            ed.iniciosVelhos = true;
            Qt.callLater(ed.atualizarNumeros);
        }
        function onQuebraChanged() {
            Qt.callLater(ed.atualizarNumeros);
            Qt.callLater(ed.atualizarRealces);
        }
        function onTamanhoNaTelaChanged() {
            Qt.callLater(ed.atualizarNumeros);
            Qt.callLater(ed.atualizarRealces);
        }
        function onFamiliaChanged() {
            Qt.callLater(ed.atualizarNumeros);
            Qt.callLater(ed.atualizarRealces);
        }
    }
    onVisibleChanged: if (visible) {
        Qt.callLater(atualizarNumeros);
        Qt.callLater(atualizarRealces);
    }

    Item {
        id: margem
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        readonly property int digitos: Math.max(2, String(ed.inicios.length).length)
        width: janela.numeros ? Math.round(metricas.advanceWidth("0") * digitos + janela.gu * 1.6) : 0
        clip: true
        visible: width > 0

        Repeater {
            model: ed.linhasVisiveis
            Text {
                required property var modelData
                x: 0
                width: margem.width - Math.round(janela.gu * 0.5)
                y: modelData.y - rolagem.contentY
                height: modelData.h
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
                text: modelData.n
                font.family: area.font.family
                font.pointSize: area.font.pointSize * 0.9
                color: janela.frente
                opacity: modelData.n === ed.linhaDoCursor ? 0.9 : 0.34
            }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: janela.tinta(janela.escuro ? 0.06 : 0.07)
        }
    }

    Flickable {
        id: rolagem
        anchors.left: margem.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // Arrastar com o mouse seleciona texto; a rodinha e as barras rolam.
        interactive: false
        onContentYChanged: {
            Qt.callLater(ed.atualizarNumeros);
            Qt.callLater(ed.atualizarRealces);
        }
        onHeightChanged: {
            Qt.callLater(ed.atualizarNumeros);
            Qt.callLater(ed.atualizarRealces);
        }
        onWidthChanged: {
            Qt.callLater(ed.atualizarNumeros);
            Qt.callLater(ed.atualizarRealces);
        }
        QQC2.ScrollBar.vertical: BarraRolagem {}
        QQC2.ScrollBar.horizontal: BarraRolagem {}

        WheelHandler {
            acceptedModifiers: Qt.NoModifier
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (ev) => {
                var dy = ev.pixelDelta.y !== 0 ? ev.pixelDelta.y : ev.angleDelta.y / 120 * metricas.lineSpacing * 3;
                var dx = ev.pixelDelta.x !== 0 ? ev.pixelDelta.x : ev.angleDelta.x / 120 * metricas.averageCharacterWidth * 6;
                rolagem.contentY = Math.max(0, Math.min(Math.max(0, rolagem.contentHeight - rolagem.height), rolagem.contentY - dy));
                rolagem.contentX = Math.max(0, Math.min(Math.max(0, rolagem.contentWidth - rolagem.width), rolagem.contentX - dx));
            }
        }
        WheelHandler {
            acceptedModifiers: Qt.ShiftModifier
            onWheel: (ev) => {
                var d = ev.angleDelta.y / 120 * metricas.averageCharacterWidth * 8;
                rolagem.contentX = Math.max(0, Math.min(Math.max(0, rolagem.contentWidth - rolagem.width), rolagem.contentX - d));
            }
        }
        // Ctrl+rodinha: zoom, como no Windows.
        WheelHandler {
            acceptedModifiers: Qt.ControlModifier
            onWheel: (ev) => janela.mudarZoom(ev.angleDelta.y > 0 ? 10 : -10)
        }

        // Os achados da busca, atrás do texto.
        Item {
            id: camadaRealces
            z: -1
            x: area.x
            y: area.y
            Repeater {
                model: ed.realces
                Rectangle {
                    required property var modelData
                    x: modelData.x - 1
                    y: modelData.y + 1
                    width: modelData.w + 2
                    height: modelData.h - 2
                    radius: 3
                    color: janela.escuro ? Qt.rgba(0.92, 0.7, 0.3, 0.3) : Qt.rgba(0.96, 0.7, 0.19, 0.36)
                }
            }
        }

        T.TextArea.flickable: T.TextArea {
            id: area
            font.family: janela.familia
            font.pointSize: janela.tamanhoNaTela
            color: janela.frente
            selectionColor: Qt.rgba(janela.destaque.r, janela.destaque.g, janela.destaque.b, janela.escuro ? 0.3 : 0.2)
            selectedTextColor: janela.frente
            placeholderTextColor: janela.tinta(0.35)
            wrapMode: janela.quebra ? TextEdit.Wrap : TextEdit.NoWrap
            textFormat: TextEdit.PlainText
            selectByMouse: true
            persistentSelection: true
            leftPadding: Math.round(janela.gu * (janela.numeros ? 0.6 : 1.0))
            rightPadding: Math.round(janela.gu * 1.0)
            topPadding: Math.round(janela.gu * 0.6)
            bottomPadding: Math.round(janela.gu * 0.8)
            tabStopDistance: metricas.advanceWidth(" ") * 4
            background: null
            Accessible.name: janela.t("Texto do arquivo", "File text")

            cursorDelegate: Rectangle {
                id: cursor
                width: 2
                radius: 1
                color: janela.frente
                visible: area.activeFocus && area.selectionStart === area.selectionEnd
                opacity: 1
                // Pisca como o do sistema, e fica aceso enquanto se digita.
                SequentialAnimation on opacity {
                    id: piscar
                    running: cursor.visible
                    loops: Animation.Infinite
                    PauseAnimation { duration: 500 }
                    NumberAnimation { to: 0; duration: 120 }
                    PauseAnimation { duration: 380 }
                    NumberAnimation { to: 1; duration: 120 }
                }
                Connections {
                    target: area
                    function onCursorPositionChanged() {
                        cursor.opacity = 1;
                        if (piscar.running)
                            piscar.restart();
                    }
                }
            }

            Keys.onPressed: (e) => {
                if (e.matches(StandardKey.Undo)) {
                    ed.desfazer();
                    e.accepted = true;
                } else if (e.matches(StandardKey.Redo) || (e.key === Qt.Key_Y && e.modifiers === Qt.ControlModifier)) {
                    ed.refazer();
                    e.accepted = true;
                }
            }
            onTextChanged: {
                if (!ed.guarda) {
                    ed.pilhaDesfazer = [];
                    ed.pilhaRefazer = [];
                }
                ed.iniciosVelhos = true;
                if (ed.pronto)
                    janela.mexeu();
                Qt.callLater(ed.atualizarNumeros);
            }
            onCursorRectangleChanged: if (activeFocus) Qt.callLater(ed.seguirCursor)

            // Texto de boas-vindas na aba vazia.
            Texto {
                x: area.leftPadding
                y: area.topPadding
                visible: area.length === 0 && ed.pronto && !area.preeditText
                text: janela.t("Escreva aqui…", "Start typing…")
                font: area.font
                color: janela.frente
                opacity: 0.3
            }
        }
    }

    // Com o mouse arrastando para fora, a rolagem acompanha o cursor.
    function seguirCursor() {
        var r = area.cursorRectangle;
        if (r.y < rolagem.contentY)
            rolagem.contentY = Math.max(0, r.y);
        else if (r.y + r.height > rolagem.contentY + rolagem.height)
            rolagem.contentY = Math.min(Math.max(0, rolagem.contentHeight - rolagem.height), r.y + r.height - rolagem.height);
        if (r.x < rolagem.contentX + area.leftPadding)
            rolagem.contentX = Math.max(0, r.x - area.leftPadding);
        else if (r.x + r.width > rolagem.contentX + rolagem.width - area.rightPadding)
            rolagem.contentX = Math.min(Math.max(0, rolagem.contentWidth - rolagem.width), r.x + r.width + area.rightPadding - rolagem.width);
    }

    // ----- realce dos achados (só os que estão à vista) -----
    property var realces: []
    onAchadosChanged: Qt.callLater(atualizarRealces)
    function atualizarRealces() {
        if (achados.length === 0 || tamanhoAchado === 0 || !visible) {
            if (realces.length)
                realces = [];
            return;
        }
        var topo = area.positionAt(rolagem.contentX, rolagem.contentY);
        var fimVista = area.positionAt(rolagem.contentX + rolagem.width, rolagem.contentY + rolagem.height);
        var lista = [];
        var i = Logica.proximoAchado(achados, Math.max(0, topo - tamanhoAchado));
        if (i < 0 || achados[i] < topo - tamanhoAchado)
            i = achados.length;
        var direita = area.width - area.rightPadding;
        for (; i < achados.length && lista.length < 400; i++) {
            var s = achados[i];
            if (s > fimVista + 1)
                break;
            var a = area.positionToRectangle(s);
            var b = area.positionToRectangle(s + tamanhoAchado);
            if (Math.abs(a.y - b.y) < 1) {
                lista.push({ x: a.x, y: a.y, w: Math.max(2, b.x - a.x), h: a.height });
            } else {
                // O achado quebrou de linha: um pedaço em cada.
                lista.push({ x: a.x, y: a.y, w: Math.max(2, direita - a.x), h: a.height });
                lista.push({ x: area.leftPadding, y: b.y, w: Math.max(2, b.x - area.leftPadding), h: b.height });
            }
        }
        realces = lista;
    }

    // Botão direito: o menu do texto (o cursor vai para o clique, fora da seleção).
    MouseArea {
        anchors.fill: rolagem
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.IBeamCursor
        onPressed: (m) => {
            var p = mapToItem(area, m.x, m.y);
            var pos = area.positionAt(p.x, p.y);
            if (pos < area.selectionStart || pos > area.selectionEnd || area.selectionStart === area.selectionEnd)
                area.cursorPosition = pos;
            area.forceActiveFocus();
            janela.abrirMenuTexto(this, m.x, m.y);
        }
    }
}
