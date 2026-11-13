// Localizar e substituir numa barra que desliza embaixo da barra de ferramentas
// (Ctrl+F e Ctrl+H): "3 de 12" dentro do campo, setas (Enter e Shift+Enter),
// diferenciar maiúsculas, palavra inteira, Esc fecha. Os achados à vista
// ficam realçados no texto; o de agora fica selecionado.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"
import "logica.js" as Logica

Item {
    id: busca

    property Item editor: null
    property bool aberta: false
    property bool substituir: false
    property string consulta: ""
    property bool maiusculas: false
    property bool palavra: false
    property var achados: []
    property int indice: -1
    // Onde a busca começou (digitar procura a partir daqui).
    property int inicio: 0
    readonly property int limite: 10000

    readonly property string contagem: {
        if (consulta.length === 0)
            return "";
        if (achados.length === 0)
            return janela.t("Nada encontrado", "No results");
        var total = janela.num(achados.length) + (achados.length >= limite ? "+" : "");
        if (indice >= 0)
            return janela.t("%1 de %2", "%1 of %2").arg(janela.num(indice + 1)).arg(total);
        return achados.length === 1 ? janela.t("1 achado", "1 match") : janela.t("%1 achados", "%1 matches").arg(total);
    }

    clip: true
    implicitHeight: aberta ? conteudo.implicitHeight : 0
    visible: implicitHeight > 0.5
    Behavior on implicitHeight {
        NumberAnimation {
            duration: Kirigami.Units.longDuration
            easing.type: Easing.OutCubic
        }
    }

    function abrir(comTroca) {
        var ed = editor;
        if (ed) {
            var sel = ed.area.selectedText;
            if (sel.length > 0 && sel.length <= 200 && sel.indexOf(" ") < 0 && sel.indexOf("\n") < 0)
                campoBusca.texto = sel;
            inicio = ed.area.selectionStart;
        }
        if (comTroca)
            substituir = true;
        else if (!aberta)
            substituir = false;
        aberta = true;
        consulta = campoBusca.texto;
        recalcular();
        campoBusca.focar();
    }
    function fechar() {
        aberta = false;
        if (editor)
            editor.focar();
    }
    function recalcular() {
        if (!aberta || !editor || consulta.length === 0) {
            achados = [];
            indice = -1;
            return;
        }
        achados = Logica.buscar(editor.area.text, consulta, maiusculas, palavra, limite);
        atualizarIndice();
    }
    function atualizarIndice() {
        var ed = editor;
        indice = -1;
        if (!ed || achados.length === 0)
            return;
        var s = ed.area.selectionStart;
        if (ed.area.selectionEnd - s !== consulta.length)
            return;
        var i = Logica.proximoAchado(achados, s);
        if (i >= 0 && achados[i] === s)
            indice = i;
    }
    function irPara(i) {
        var ed = editor;
        if (!ed || i < 0 || i >= achados.length)
            return;
        ed.area.select(achados[i], achados[i] + consulta.length);
        ed.mostrar(achados[i]);
        indice = i;
    }
    // Digitar no campo procura a partir de onde a busca começou.
    function procurarDoInicio() {
        recalcular();
        if (achados.length > 0)
            irPara(Logica.proximoAchado(achados, inicio));
        else if (editor)
            editor.area.select(inicio, inicio);
    }
    function proximo() {
        if (!editor || achados.length === 0)
            return;
        var de = indice >= 0 ? achados[indice] + 1 : editor.area.selectionEnd;
        if (indice < 0 && editor.area.selectionStart === editor.area.selectionEnd)
            de = editor.area.cursorPosition;
        irPara(Logica.proximoAchado(achados, de));
        inicio = editor.area.selectionStart;
    }
    function anterior() {
        if (!editor || achados.length === 0)
            return;
        irPara(Logica.achadoAnterior(achados, editor.area.selectionStart));
        inicio = editor.area.selectionStart;
    }
    function proximoOuAbrir() {
        if (aberta && consulta.length > 0)
            proximo();
        else
            abrir(false);
    }
    function anteriorOuAbrir() {
        if (aberta && consulta.length > 0)
            anterior();
        else
            abrir(false);
    }
    // Troca o achado selecionado e vai para o próximo (sem nada selecionado, só acha).
    function trocarUm() {
        var ed = editor;
        if (!ed || achados.length === 0)
            return;
        if (indice < 0) {
            proximo();
            return;
        }
        var s = achados[indice];
        var troca = campoTroca.texto;
        ed.trocar(s, s + consulta.length, troca);
        recalcular();
        if (achados.length > 0)
            irPara(Logica.proximoAchado(achados, s + troca.length));
    }
    function trocarTodos() {
        var ed = editor;
        if (!ed || consulta.length === 0)
            return;
        var r = Logica.trocarTudo(ed.area.text, consulta, campoTroca.texto, maiusculas, palavra);
        if (r.n === 0) {
            janela.avisoRapido(janela.t("Nada para substituir", "Nothing to replace"), "");
            return;
        }
        var cursor = ed.area.cursorPosition;
        ed.trocar(r.inicio, r.fim, r.trecho);
        ed.area.cursorPosition = Math.min(cursor, ed.area.length);
        recalcular();
        janela.avisoRapido(r.n === 1 ? janela.t("1 troca feita", "1 replacement made")
                                     : janela.t("%1 trocas feitas", "%1 replacements made").arg(janela.num(r.n)), "certo",
                           janela.t("Desfazer", "Undo"), function () {
                               ed.desfazer();
                               busca.recalcular();
                           });
    }

    onConsultaChanged: if (aberta) procurarDoInicio()
    onMaiusculasChanged: procurarDoInicio()
    onPalavraChanged: procurarDoInicio()
    onEditorChanged: recalcular()
    Connections {
        target: busca.editor ? busca.editor.area : null
        function onTextChanged() {
            if (busca.aberta)
                tempoRecalcular.restart();
        }
        function onSelectionStartChanged() {
            busca.atualizarIndice();
        }
        function onSelectionEndChanged() {
            busca.atualizarIndice();
        }
    }
    Timer {
        id: tempoRecalcular
        interval: 200
        onTriggered: busca.recalcular()
    }

    // Enter, Shift+Enter e Esc dentro dos campos.
    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Escape) {
            busca.fechar();
            e.accepted = true;
        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            if (campoTroca.entrada.activeFocus) {
                if (e.modifiers & Qt.ControlModifier)
                    busca.trocarTodos();
                else
                    busca.trocarUm();
            } else if (e.modifiers & Qt.ShiftModifier) {
                busca.anterior();
            } else {
                busca.proximo();
            }
            e.accepted = true;
        }
    }

    ColumnLayout {
        id: conteudo
        anchors.left: parent.left
        anchors.right: parent.right
        // Desliza de cima, junto com a altura.
        y: busca.aberta ? 0 : -Math.round(janela.gu * 0.8)
        opacity: busca.aberta ? 1 : 0
        spacing: Math.round(janela.gu * 0.3)
        Behavior on y {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }

        Item {
            implicitHeight: Math.round(janela.gu * 0.15)
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(janela.gu * 0.5)
            Layout.rightMargin: Math.round(janela.gu * 0.5)
            spacing: Math.round(janela.gu * 0.2)

            BotaoSimbolo {
                lado: Math.round(janela.gu * 1.85)
                focavel: false
                icone: "matsu-seta-symbolic"
                giro: busca.substituir ? 90 : 0
                dica: busca.substituir ? janela.t("Esconder substituir", "Hide replace") : janela.t("Substituir (Ctrl+H)", "Replace (Ctrl+H)")
                onClicado: busca.substituir = !busca.substituir
            }
            Campo {
                id: campoBusca
                Layout.fillWidth: true
                Layout.maximumWidth: Math.round(janela.gu * 22)
                icone: "matsu-busca-symbolic"
                dica: janela.t("Localizar", "Find")
                podeLimpar: false
                onEditado: (t) => busca.consulta = t
                // "3 de 12" no fim do campo.
                Texto {
                    id: rotuloContagem
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(janela.gu * 0.6)
                    anchors.verticalCenter: parent.verticalCenter
                    text: busca.contagem
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    color: busca.achados.length === 0 && busca.consulta.length > 0 ? (janela.escuro ? "#ff9a9a" : "#c62828") : janela.frente
                    opacity: busca.achados.length === 0 && busca.consulta.length > 0 ? 0.95 : 0.6
                }
                Binding {
                    target: campoBusca.entrada
                    property: "anchors.rightMargin"
                    value: rotuloContagem.implicitWidth + Math.round(janela.gu * 0.9)
                }
            }
            BotaoSimbolo {
                lado: Math.round(janela.gu * 1.85)
                focavel: false
                icone: janela.ic("cima")
                dica: janela.t("Anterior (Shift+Enter)", "Previous (Shift+Enter)")
                ativo: busca.achados.length > 0
                onClicado: busca.anterior()
            }
            BotaoSimbolo {
                lado: Math.round(janela.gu * 1.85)
                focavel: false
                icone: janela.ic("baixo")
                dica: janela.t("Próximo (Enter)", "Next (Enter)")
                ativo: busca.achados.length > 0
                onClicado: busca.proximo()
            }
            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: Math.round(janela.gu * 1.1)
                Layout.leftMargin: Math.round(janela.gu * 0.2)
                Layout.rightMargin: Math.round(janela.gu * 0.2)
                color: janela.tinta(0.12)
            }
            BotaoSimbolo {
                lado: Math.round(janela.gu * 1.85)
                focavel: false
                icone: "matsu-texto-symbolic"
                dica: janela.t("Diferenciar maiúsculas", "Match case")
                ligado: busca.maiusculas
                onClicado: busca.maiusculas = !busca.maiusculas
            }
            BotaoSimbolo {
                lado: Math.round(janela.gu * 1.85)
                focavel: false
                icone: janela.ic("palavra")
                dica: janela.t("Só a palavra inteira", "Whole word")
                ligado: busca.palavra
                onClicado: busca.palavra = !busca.palavra
            }
            Item {
                Layout.fillWidth: true
            }
            BotaoSimbolo {
                lado: Math.round(janela.gu * 1.85)
                focavel: false
                icone: "matsu-fechar-symbolic"
                dica: janela.t("Fechar (Esc)", "Close (Esc)")
                onClicado: busca.fechar()
            }
        }
        // A linha de substituir abre e fecha dentro da barra.
        Item {
            Layout.fillWidth: true
            implicitHeight: busca.substituir ? linhaTroca.implicitHeight : 0
            clip: true
            Behavior on implicitHeight {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutCubic
                }
            }
            RowLayout {
                id: linhaTroca
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Math.round(janela.gu * 0.5)
                anchors.rightMargin: Math.round(janela.gu * 0.5)
                spacing: Math.round(janela.gu * 0.2)
                opacity: busca.substituir ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                    }
                }
                Item {
                    Layout.preferredWidth: Math.round(janela.gu * 1.85)
                }
                Campo {
                    id: campoTroca
                    Layout.fillWidth: true
                    Layout.maximumWidth: Math.round(janela.gu * 22)
                    icone: janela.ic("substituir")
                    dica: janela.t("Substituir por", "Replace with")
                    podeLimpar: false
                }
                Botao {
                    texto: janela.t("Substituir", "Replace")
                    ativo: busca.achados.length > 0
                    dica: janela.t("Troca o achado selecionado (Enter)", "Replace the selected match (Enter)")
                    onClicado: busca.trocarUm()
                }
                Botao {
                    texto: janela.t("Substituir tudo", "Replace all")
                    ativo: busca.achados.length > 0
                    dica: janela.t("Troca todos de uma vez (Ctrl+Enter)", "Replace all at once (Ctrl+Enter)")
                    onClicado: busca.trocarTodos()
                }
                Item {
                    Layout.fillWidth: true
                }
            }
        }
        Item {
            implicitHeight: Math.round(janela.gu * 0.2)
        }
    }
}
