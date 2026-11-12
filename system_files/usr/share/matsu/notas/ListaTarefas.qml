// A lista de tarefas do editor: os itens a fazer, a linha "Adicionar item" e,
// embaixo, os concluídos (que recolhem). Marcar leva o item para os concluídos
// depois que o risco corre; desmarcar traz de volta. Enter cria o item seguinte,
// Backspace num item vazio tira ele, e o pegador arrasta para mudar a ordem.
// A linha "Adicionar item" é um item especial do modelo (sentinela), que separa
// os a fazer dos concluídos: assim a lista anima tudo de um jeito só.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../comum"

Item {
    id: tarefas

    property string nid: ""
    property bool somenteLer: false
    property bool colapsado: false
    property int pendentes: 0
    property int feitos: 0

    // Ao subir do primeiro item (ou apagar o único), o foco volta para o título.
    signal voltarAoTitulo()

    implicitHeight: lista.contentHeight

    ListModel {
        id: modelo
    }

    function novoId() {
        return "i" + Date.now().toString(36) + Math.floor(Math.random() * 46656).toString(36);
    }
    function carregar(n) {
        modelo.clear();
        colapsado = false;
        if (n && n.tipo === "lista") {
            var i;
            for (i = 0; i < n.itens.length; i++)
                if (!n.itens[i].feito)
                    modelo.append({ iid: n.itens[i].id, texto: n.itens[i].texto, feito: false, sentinela: false, grupo: "a" });
            modelo.append({ iid: "+", texto: "", feito: false, sentinela: true, grupo: "a" });
            for (i = 0; i < n.itens.length; i++)
                if (n.itens[i].feito)
                    modelo.append({ iid: n.itens[i].id, texto: n.itens[i].texto, feito: true, sentinela: false, grupo: "b" });
        }
        contar();
    }
    function itens() {
        var r = [];
        for (var i = 0; i < modelo.count; i++) {
            var m = modelo.get(i);
            if (!m.sentinela)
                r.push({ id: m.iid, texto: m.texto, feito: m.feito });
        }
        return r;
    }
    function contar() {
        var p = 0, f = 0;
        for (var i = 0; i < modelo.count; i++) {
            var m = modelo.get(i);
            if (m.sentinela || (!m.texto.trim() && !m.feito))
                continue;
            if (m.feito)
                f++;
            else
                p++;
        }
        pendentes = p;
        feitos = f;
    }
    function escrever() {
        if (nid)
            janela.mudar(nid, { itens: itens() });
        contar();
    }
    function indiceDe(iid) {
        for (var i = 0; i < modelo.count; i++)
            if (modelo.get(i).iid === iid)
                return i;
        return -1;
    }
    function sentinela() {
        for (var i = 0; i < modelo.count; i++)
            if (modelo.get(i).sentinela)
                return i;
        return modelo.count;
    }
    function focar(i, posicao) {
        Qt.callLater(function () {
            var l = lista.itemAtIndex(i);
            if (l && l.item && l.item.focar)
                l.item.focar(posicao);
        });
    }
    // Para o título: Enter ou seta para baixo vão para o primeiro item (ou criam um).
    function focarPrimeiro() {
        if (somenteLer)
            return;
        if (sentinela() === 0)
            novoItem(0, "");
        else
            focar(0, 0);
    }
    function novoItem(posicao, texto) {
        modelo.insert(posicao, { iid: novoId(), texto: texto || "", feito: false, sentinela: false, grupo: "a" });
        escrever();
        focar(posicao, 0);
    }
    function vizinho(i, passo) {
        var j = i + passo;
        while (j >= 0 && j < modelo.count && modelo.get(j).sentinela)
            j += passo;
        return j >= 0 && j < modelo.count ? j : -1;
    }

    // Marcar: o risco corre, e logo depois o item desce (ou sobe, ao desmarcar).
    property var fila: []
    function marcar(iid, feito) {
        var i = indiceDe(iid);
        if (i < 0)
            return;
        modelo.setProperty(i, "feito", feito);
        escrever();
        fila.push(iid);
        andar.restart();
    }
    Timer {
        id: andar
        interval: 420
        onTriggered: {
            var ids = tarefas.fila;
            tarefas.fila = [];
            for (var k = 0; k < ids.length; k++) {
                var i = tarefas.indiceDe(ids[k]);
                if (i < 0)
                    continue;
                var m = modelo.get(i);
                var s = tarefas.sentinela();
                if (m.feito && i < s) {
                    modelo.move(i, s, 1);
                    modelo.setProperty(s, "grupo", "b");
                } else if (!m.feito && i > s) {
                    modelo.move(i, s, 1);
                    modelo.setProperty(s, "grupo", "a");
                }
            }
            tarefas.escrever();
        }
    }

    ListView {
        id: lista
        anchors.fill: parent
        interactive: false
        model: modelo
        spacing: 0

        delegate: Loader {
            id: carga
            required property int index
            required property string iid
            required property string texto
            required property bool feito
            required property bool sentinela
            required property string grupo
            readonly property bool escondido: grupo === "b" && tarefas.colapsado
            width: lista.width
            height: escondido ? 0 : (item ? item.implicitHeight : 0)
            opacity: escondido ? 0 : 1
            visible: opacity > 0
            z: item && item.arrastando ? 10 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }
            sourceComponent: sentinela ? adicionar : tarefa

            Component {
                id: tarefa
                ItemTarefa {
                    texto: carga.texto
                    feito: carga.feito
                    somenteLer: tarefas.somenteLer
                    onAlternar: (f) => tarefas.marcar(carga.iid, f)
                    onEditado: (t) => {
                        modelo.setProperty(carga.index, "texto", t);
                        tarefas.escrever();
                    }
                    onEnter: (posicao) => {
                        var i = carga.index;
                        if (carga.feito) {
                            tarefas.novoItem(tarefas.sentinela(), "");
                            return;
                        }
                        var t = carga.texto;
                        modelo.setProperty(i, "texto", t.substring(0, posicao));
                        tarefas.novoItem(i + 1, t.substring(posicao));
                    }
                    onApagarVazio: {
                        var i = carga.index;
                        var antes = tarefas.vizinho(i, -1);
                        var depois = tarefas.vizinho(i, 1);
                        modelo.remove(i);
                        tarefas.escrever();
                        if (antes >= 0)
                            tarefas.focar(antes, -1);
                        else if (depois >= 0)
                            tarefas.focar(depois - 1, 0);
                        else
                            tarefas.voltarAoTitulo();
                    }
                    onJuntar: {
                        var i = carga.index;
                        var antes = tarefas.vizinho(i, -1);
                        if (antes < 0 || modelo.get(antes).grupo !== carga.grupo) {
                            if (antes < 0)
                                tarefas.voltarAoTitulo();
                            return;
                        }
                        var t = modelo.get(antes).texto;
                        modelo.setProperty(antes, "texto", t + carga.texto);
                        modelo.remove(i);
                        tarefas.escrever();
                        tarefas.focar(antes, t.length);
                    }
                    onSubir: {
                        var antes = tarefas.vizinho(carga.index, -1);
                        if (antes >= 0)
                            tarefas.focar(antes, -1);
                        else
                            tarefas.voltarAoTitulo();
                    }
                    onDescer: {
                        var depois = tarefas.vizinho(carga.index, 1);
                        if (depois >= 0)
                            tarefas.focar(depois, 0);
                    }
                    onRemover: {
                        modelo.remove(carga.index);
                        tarefas.escrever();
                    }
                    onArrastar: (y) => {
                        // y vem na altura da linha; a lista conta do seu começo.
                        var alvo = lista.indexAt(lista.width / 2, carga.y + y);
                        var limite = tarefas.sentinela();
                        if (alvo >= 0 && alvo < limite && alvo !== carga.index)
                            modelo.move(carga.index, alvo, 1);
                    }
                    onSoltar: tarefas.escrever()
                }
            }
            Component {
                id: adicionar
                Column {
                    spacing: 0
                    MouseArea {
                        id: botaoAdicionar
                        visible: !tarefas.somenteLer
                        width: parent.width
                        height: Math.round(janela.gu * 2.05)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tarefas.novoItem(carga.index, "")
                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: -Math.round(janela.gu * 0.3)
                            radius: Math.round(janela.gu * 0.4)
                            color: janela.tinta(botaoAdicionar.containsMouse ? 0.04 : 0)
                        }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Math.round(janela.gu * 0.6)
                            Item {
                                width: Math.round(janela.gu * 1.15)
                                height: width
                                anchors.verticalCenter: parent.verticalCenter
                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: Kirigami.Units.iconSizes.small
                                    height: width
                                    source: "matsu-mais-symbolic"
                                    isMask: true
                                    color: janela.frente
                                    opacity: botaoAdicionar.containsMouse ? 0.85 : 0.5
                                    rotation: botaoAdicionar.containsMouse ? 90 : 0
                                    Behavior on rotation {
                                        NumberAnimation {
                                            duration: Kirigami.Units.longDuration
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }
                            Texto {
                                anchors.verticalCenter: parent.verticalCenter
                                text: janela.t("Adicionar item", "Add item")
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.08
                                opacity: botaoAdicionar.containsMouse ? 0.8 : 0.5
                            }
                        }
                    }
                    // Os concluídos: a linha fina e o cabeçalho que recolhe.
                    Item {
                        visible: tarefas.feitos > 0
                        width: parent.width
                        height: Math.round(janela.gu * 2.6)
                        Rectangle {
                            anchors.top: parent.top
                            anchors.topMargin: Math.round(janela.gu * 0.4)
                            width: parent.width
                            height: 1
                            color: janela.tinta(janela.escuro ? 0.08 : 0.09)
                        }
                        MouseArea {
                            id: cabeca
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Math.round(janela.gu * 0.2)
                            width: linhaCabeca.implicitWidth + Math.round(janela.gu * 0.8)
                            height: Math.round(janela.gu * 1.7)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tarefas.colapsado = !tarefas.colapsado
                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: -Math.round(janela.gu * 0.3)
                                radius: Math.round(janela.gu * 0.35)
                                color: janela.tinta(cabeca.containsMouse ? 0.05 : 0)
                            }
                            Row {
                                id: linhaCabeca
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Math.round(janela.gu * 0.35)
                                Kirigami.Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.round(Kirigami.Units.iconSizes.small * 0.8)
                                    height: width
                                    source: "matsu-seta-symbolic"
                                    isMask: true
                                    color: janela.frente
                                    opacity: 0.6
                                    rotation: tarefas.colapsado ? 0 : 90
                                    Behavior on rotation {
                                        NumberAnimation {
                                            duration: Kirigami.Units.longDuration
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                                Texto {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tarefas.feitos === 1 ? janela.t("1 concluído", "1 done") : janela.t(tarefas.feitos + " concluídos", tarefas.feitos + " done")
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    font.weight: Font.DemiBold
                                    opacity: 0.6
                                }
                            }
                        }
                    }
                }
            }
        }

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
            NumberAnimation { property: "x"; from: -8; to: 0; duration: 240; easing.type: Easing.OutCubic }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: 160 }
        }
        move: Transition {
            NumberAnimation { property: "y"; duration: 300; easing.type: Easing.OutCubic }
        }
        displaced: Transition {
            NumberAnimation { property: "y"; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { property: "opacity"; to: 1; duration: 120 }
        }
    }
}
